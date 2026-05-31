package com.callbreak.room

import com.callbreak.api.ws.ServerMessage
import com.callbreak.domain.models.CallbreakState
import com.callbreak.domain.models.CurrentTrick
import com.callbreak.domain.models.GamePhase
import com.callbreak.domain.models.PlayerId
import com.callbreak.domain.models.PlayingCard
import com.callbreak.domain.models.Player
import com.callbreak.domain.models.Suit
import com.callbreak.domain.models.TrickCard
import com.callbreak.domain.models.createDeck
import com.callbreak.domain.rules.evaluateTrickWinner
import com.callbreak.domain.rules.validateMove
import com.callbreak.domain.rules.calculateBotBid
import com.callbreak.domain.rules.selectBotCard
import com.callbreak.domain.rules.startDealPhase1
import com.callbreak.domain.rules.startDealPhase2
import com.callbreak.domain.rules.processTrumpBid
import com.callbreak.domain.rules.resolveRound
import com.callbreak.config.appJson
import com.callbreak.plugins.RedisService
import com.callbreak.services.SupabaseService
import io.ktor.websocket.DefaultWebSocketSession
import io.ktor.websocket.send
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.encodeToString

/**
 * Manages a single active Callbreak game room.
 *
 * Thread-safety: all state mutations are gated behind [mutex].
 * WebSocket sessions are stored in [sessions] (playerId → session).
 */
class GameRoom(initialState: CallbreakState) {

    private val mutex = Mutex()
    private var state: CallbreakState = initialState

    /** Connected WebSocket sessions, keyed by playerId. */
    private val sessions = mutableMapOf<PlayerId, DefaultWebSocketSession>()

    /** Active session tokens generated at room create/join, keyed by playerId. */
    private val sessionTokens = ConcurrentHashMap<PlayerId, String>()

    /** Takeover timers for players who are offline, keyed by playerId. */
    private val offlineTimers = ConcurrentHashMap<PlayerId, Job>()

    /** Active turn timers for human players, keyed by playerId. */
    private val turnTimers = ConcurrentHashMap<PlayerId, Job>()

    private fun cancelTurnTimer(playerId: PlayerId?) {
        if (playerId != null) {
            turnTimers.remove(playerId)?.cancel()
        }
    }

    // ─── Session Management ──────────────────────────────────────────────────

    suspend fun addSession(playerId: PlayerId, session: DefaultWebSocketSession) {
        mutex.withLock { sessions[playerId] = session }
    }

    suspend fun removeSession(playerId: PlayerId) {
        var forceTakeover = false
        mutex.withLock {
            sessions.remove(playerId)

            // If the game is active (not LOBBY and not GAME_OVER), mark player offline
            if (state.phase != GamePhase.LOBBY && state.phase != GamePhase.GAME_OVER) {
                state = state.copy(
                    players = state.players.map { p ->
                        if (p.id == playerId) p.copy(isOnline = false) else p
                    }
                )
                broadcastState()

                // If it is currently this player's turn, start the 60-second timer
                if (state.currentTurn == playerId) {
                    startTakeoverTimer(playerId)
                    cancelTurnTimer(playerId)
                    forceTakeover = true
                }
            }
        }
        if (forceTakeover) {
            triggerBotActionsIfNeeded()
        }
    }

    suspend fun leaveRoom(playerId: PlayerId) {
        mutex.withLock {
            sessionTokens.remove(playerId)
            
            if (state.phase == GamePhase.LOBBY) {
                // Remove player from the lobby to vacate the seat and transfer host
                state = state.copy(
                    players = state.players.filter { it.id != playerId }
                )
            } else if (state.phase != GamePhase.GAME_OVER) {
                // Game active: immediately take over with a bot
                state = state.copy(
                    players = state.players.map { player ->
                        if (player.id == playerId) {
                            player.copy(
                                isOnline = false,
                                isBot = true,
                                name = if (player.name.endsWith(" (Bot)")) player.name else "${player.name} (Bot)"
                            )
                        } else player
                    }
                )
            }
            broadcastState()
        }
        
        var forceTakeover = false
        mutex.withLock {
            if (state.phase != GamePhase.LOBBY && state.phase != GamePhase.GAME_OVER && state.currentTurn == playerId) {
                forceTakeover = true
            }
        }
        if (forceTakeover) {
            triggerBotActionsIfNeeded()
        }
    }

    fun registerSessionToken(playerId: PlayerId, token: String) {
        sessionTokens[playerId] = token
    }

    fun validateSessionToken(playerId: PlayerId, token: String): Boolean {
        val exists = state.players.any { it.id == playerId }
        return exists && sessionTokens[playerId] == token
    }

    fun getSessionToken(playerId: PlayerId): String? {
        return sessionTokens[playerId]
    }

    suspend fun playerReconnected(playerId: PlayerId) = mutex.withLock {
        offlineTimers.remove(playerId)?.cancel()

        state = state.copy(
            players = state.players.map { p ->
                if (p.id == playerId) {
                    var cleanName = p.name
                    if (cleanName.endsWith(" (Bot)")) {
                        cleanName = cleanName.removeSuffix(" (Bot)")
                    }
                    p.copy(
                        isOnline = true,
                        isBot = false, // Hot-swap player back in
                        name = cleanName
                    )
                } else p
            }
        )
        broadcastState()
    }

    fun getState(): CallbreakState = state

    /**
     * Adds a player to the room (used during LOBBY join, pre-game).
     * Modifies state within the mutex and broadcasts the update to existing sessions.
     */
    suspend fun addPlayer(player: Player) {
        mutex.withLock {
            state = state.copy(players = state.players + player)
        }
        broadcastState()
    }

    // ─── Game Lifecycle ──────────────────────────────────────────────────────

    /**
     * Starts the game: deals cards and moves to BIDDING phase.
     * Fills any empty seats with bots to reach 4 players.
     */
    suspend fun startGame(): Result<Unit> {
        val startResult = mutex.withLock {
            if (state.phase != GamePhase.LOBBY) {
                return@withLock Result.failure(Exception("Game already started"))
            }
            val humanCount = state.players.size
            if (humanCount == 0) {
                return@withLock Result.failure(Exception("Need at least 1 player to start"))
            }

            // Fill empty seats with bots to reach 4 players
            val botsNeeded = CallbreakState.PLAYERS_REQUIRED - humanCount
            val updatedPlayers = state.players.toMutableList()
            for (i in 1..botsNeeded) {
                val botId = "bot_$i"
                val bot = Player(
                    id = botId,
                    name = "Bot $i",
                    isBot = true,
                    isOnline = true
                )
                updatedPlayers.add(bot)
                // Register an ephemeral session token for bots
                registerSessionToken(botId, "bot-token-$botId")
            }

            val shuffled = createDeck().shuffled()
            val stateWithBots = state.copy(
                players = updatedPlayers.map { it.copy(cumulativeScore = 0.0) }
            )
            
            state = startDealPhase1(stateWithBots, shuffled)

            broadcastState()
            Result.success(Unit)
        }

        if (startResult.isSuccess) {
            CoroutineScope(Dispatchers.Default).launch {
                triggerBotActionsIfNeeded()
            }
        }
        return startResult
    }

    /**
     * Records a player's bid during BIDDING phase.
     * Once all 4 players have bid, transitions to PLAYING phase.
     */
    suspend fun placeBid(playerId: PlayerId, bid: Int, isAutoPlay: Boolean = false): Result<Unit> {
        val bidResult = mutex.withLock {
            if (state.phase != GamePhase.REGULAR_BIDDING) {
                return@withLock Result.failure(Exception("Not in bidding phase"))
            }
            if (state.currentTurn != playerId) {
                return@withLock Result.failure(Exception("Not $playerId's turn to bid"))
            }
            var minBidAllowed = state.minBid ?: 1
            if (state.trumpBidState.highestBidderId == playerId && state.trumpBidState.highestBid > 0) {
                minBidAllowed = maxOf(minBidAllowed, state.trumpBidState.highestBid)
            }
            if (bid < minBidAllowed || bid > CallbreakState.CARDS_PER_HAND) {
                return@withLock Result.failure(Exception("Bid must be between $minBidAllowed and ${CallbreakState.CARDS_PER_HAND}"))
            }

            val newBids = state.bids + (playerId to bid)
            
            val allBid = newBids.size == state.players.size
            var firstPlayer = state.players[(state.dealerIndex + state.players.size - 1) % state.players.size].id
            if (state.trumpBidState.highestBidderId != null) {
                firstPlayer = state.trumpBidState.highestBidderId!!
            }

            var nextTurn: String? = null
            if (!allBid) {
                var playerIndex = state.players.indexOfFirst { it.id == playerId }
                for (i in 1..4) {
                    playerIndex = (playerIndex + state.players.size - 1) % state.players.size
                    val candidate = state.players[playerIndex].id
                    if (newBids[candidate] == null) {
                        nextTurn = candidate
                        break
                    }
                }
            }

            val oldTurn = state.currentTurn
            state = state.copy(
                bids = newBids,
                phase = if (allBid) GamePhase.PLAYING else GamePhase.REGULAR_BIDDING,
                currentTurn = if (allBid) firstPlayer else nextTurn,
                turnEndTime = null,
                players = state.players.map { p ->
                    if (p.id == playerId) p.copy(
                        bid = bid,
                        consecutiveBotMoves = if (isAutoPlay) p.consecutiveBotMoves + 1 else 0
                    ) else p
                }
            )

            cancelTurnTimer(oldTurn)
            broadcastState()
            Result.success(Unit)
        }

        if (bidResult.isSuccess) {
            CoroutineScope(Dispatchers.Default).launch {
                triggerBotActionsIfNeeded()
            }
        }
        return bidResult
    }

    /**
     * Processes a bid or pass during TRUMP_BIDDING phase.
     */
    suspend fun placeTrumpBid(playerId: PlayerId, bid: Int?, suit: Suit?, isAutoPlay: Boolean = false): Result<Unit> {
        val result = mutex.withLock {
            val nextStateResult = processTrumpBid(state, playerId, bid, suit)
            if (nextStateResult.isFailure) return@withLock nextStateResult.map { Unit }
            
            val oldTurn = state.currentTurn
            var nextState = nextStateResult.getOrThrow()
            if (nextState.phase == GamePhase.DEALING_PHASE_2) {
                nextState = startDealPhase2(nextState)
            }
            state = nextState.copy(
                turnEndTime = null,
                players = nextState.players.map { p ->
                    if (p.id == playerId) p.copy(
                        consecutiveBotMoves = if (isAutoPlay) p.consecutiveBotMoves + 1 else 0
                    ) else p
                }
            )
            cancelTurnTimer(oldTurn)
            broadcastState()
            Result.success(Unit)
        }

        if (result.isSuccess) {
            CoroutineScope(Dispatchers.Default).launch {
                triggerBotActionsIfNeeded()
            }
        }
        return result
    }

    /**
     * Validates and applies a card play. Evaluates trick winner when 4 cards played.
     * Tallies round scores when all 13 tricks are done.
     */
    suspend fun playCard(playerId: PlayerId, card: PlayingCard, isAutoPlay: Boolean = false): Result<Unit> {
        val playResult = mutex.withLock {
            val validation = validateMove(state, playerId, card)
            if (validation.isFailure) return@withLock validation

            val updatedHand = state.hands[playerId]!! - card
            val newTrickCards = state.currentTrick.cards + TrickCard(playerId, card)
            val ledSuit = state.currentTrick.ledSuit ?: card.suit
            val newTrick = CurrentTrick(ledSuit = ledSuit, cards = newTrickCards)

            // Update player card count
            val updatedPlayers = state.players.map { p ->
                if (p.id == playerId) p.copy(
                    cardCount = updatedHand.size,
                    consecutiveBotMoves = if (isAutoPlay) p.consecutiveBotMoves + 1 else 0
                ) else p
            }

            if (newTrickCards.size == CallbreakState.PLAYERS_REQUIRED) {
                // Trick complete — evaluate winner
                val winner = evaluateTrickWinner(newTrick, state.currentTrumpSuit)
                    ?: return@withLock Result.failure(Exception("Could not determine trick winner"))

                val newTricksWon = state.tricksWon + (winner to (state.tricksWon[winner] ?: 0) + 1)
                val totalTricksPlayed = newTricksWon.values.sum()

                val playersWithUpdatedTricks = updatedPlayers.map { p ->
                    p.copy(tricksWon = newTricksWon[p.id] ?: 0)
                }

                if (totalTricksPlayed == CallbreakState.CARDS_PER_HAND) {
                    // Round over — show final trick card first, but pause play (currentTurn = null)
                    val oldTurn = state.currentTurn
                    state = state.copy(
                        hands = state.hands + (playerId to updatedHand),
                        currentTrick = newTrick,
                        currentTurn = null,
                        turnEndTime = null,
                        players = updatedPlayers
                    )
                    cancelTurnTimer(oldTurn)
                    broadcastState()

                    val roundFinishedState = state.copy(
                        tricksWon = newTricksWon,
                        currentTrick = CurrentTrick(),
                        players = playersWithUpdatedTricks
                    )

                    CoroutineScope(Dispatchers.Default).launch {
                        delay(1000)
                        mutex.withLock {
                            state = resolveRound(roundFinishedState)
                            broadcastState()
                            if (state.phase == GamePhase.ROUND_OVER) {
                                startIntermission()
                            } else if (state.phase == GamePhase.GAME_OVER) {
                                saveResultsToSupabase(state)
                            }
                        }
                    }
                } else {
                    // More tricks to play; show final trick card first, pause play
                    val oldTurn = state.currentTurn
                    state = state.copy(
                        hands = state.hands + (playerId to updatedHand),
                        currentTrick = newTrick,
                        currentTurn = null,
                        turnEndTime = null,
                        players = updatedPlayers
                    )
                    cancelTurnTimer(oldTurn)
                    broadcastState()

                    CoroutineScope(Dispatchers.Default).launch {
                        delay(1000)
                        mutex.withLock {
                            state = state.copy(
                                tricksWon = newTricksWon,
                                currentTrick = CurrentTrick(),
                                currentTurn = winner,
                                players = playersWithUpdatedTricks
                            )
                            broadcastState()
                        }
                        triggerBotActionsIfNeeded()
                    }
                }
            } else {
                // Trick still in progress — advance turn
                val playerIndex = state.players.indexOfFirst { it.id == playerId }
                val nextPlayer = state.players[(playerIndex + state.players.size - 1) % state.players.size].id

                val oldTurn = state.currentTurn
                state = state.copy(
                    hands = state.hands + (playerId to updatedHand),
                    currentTrick = newTrick,
                    currentTurn = nextPlayer,
                    turnEndTime = null,
                    players = updatedPlayers,
                )
                cancelTurnTimer(oldTurn)
                broadcastState()
            }

            Result.success(Unit)
        }

        if (playResult.isSuccess) {
            CoroutineScope(Dispatchers.Default).launch {
                triggerBotActionsIfNeeded()
            }
        }
        return playResult
    }

    /**
     * Starts the next round. Called after [GamePhase.ROUND_OVER] intermission.
     */
    suspend fun startNextRound(): Result<Unit> {
        val roundResult = mutex.withLock {
            if (state.phase != GamePhase.ROUND_OVER) {
                return@withLock Result.failure(Exception("Not in ROUND_OVER phase"))
            }
            if (state.currentRound >= state.totalRounds) {
                return@withLock Result.failure(Exception("Game is over after ${state.totalRounds} rounds"))
            }

            val nextDealer = (state.dealerIndex + state.players.size - 1) % state.players.size
            val shuffled = createDeck().shuffled()
            val nextDealerState = state.copy(
                currentRound = state.currentRound + 1,
                dealerIndex = nextDealer
            )
            state = startDealPhase1(nextDealerState, shuffled)

            broadcastState()
            Result.success(Unit)
        }

        if (roundResult.isSuccess) {
            CoroutineScope(Dispatchers.Default).launch {
                triggerBotActionsIfNeeded()
            }
        }
        return roundResult
    }

    // ─── Takeover Timers & Bot Triggers ──────────────────────────────────────

    private fun startTakeoverTimer(playerId: PlayerId) {
        offlineTimers[playerId]?.cancel()
        val job = CoroutineScope(Dispatchers.Default).launch {
            delay(60000) // 60 seconds
            triggerTakeover(playerId)
        }
        offlineTimers[playerId] = job
    }

    private suspend fun triggerTakeover(playerId: PlayerId) {
        var needsAction = false
        mutex.withLock {
            val p = state.players.firstOrNull { it.id == playerId }
            if (p != null && !p.isOnline && state.currentTurn == playerId) {
                state = state.copy(
                    players = state.players.map { player ->
                        if (player.id == playerId) {
                            player.copy(
                                isBot = true,
                                name = if (player.name.endsWith(" (Bot)")) player.name else "${player.name} (Bot)"
                            )
                        } else player
                    }
                )
                broadcastState()
                needsAction = true
            }
        }
        if (needsAction) {
            triggerBotActionsIfNeeded()
        }
    }

    private suspend fun forceBotMove(playerId: PlayerId) {
        var phase: GamePhase = GamePhase.LOBBY
        var stateCopy: CallbreakState = state
        
        mutex.withLock {
            if (state.currentTurn != playerId) return
            phase = state.phase
            stateCopy = state
        }
        
        if (phase == GamePhase.REGULAR_BIDDING) {
            val botHand = stateCopy.hands[playerId] ?: emptyList()
            var minBidAllowed = stateCopy.minBid ?: 1
            if (stateCopy.trumpBidState.highestBidderId == playerId && stateCopy.trumpBidState.highestBid > 0) {
                minBidAllowed = maxOf(minBidAllowed, stateCopy.trumpBidState.highestBid)
            }
            val bid = calculateBotBid(botHand, minBidAllowed, stateCopy.currentTrumpSuit)
            placeBid(playerId, bid, isAutoPlay = true)
        } else if (phase == GamePhase.TRUMP_BIDDING) {
            placeTrumpBid(playerId, null, null, isAutoPlay = true)
        } else if (phase == GamePhase.PLAYING) {
            val card = selectBotCard(stateCopy, playerId)
            playCard(playerId, card, isAutoPlay = true)
        }
    }

    suspend fun triggerBotActionsIfNeeded() {
        var turnPlayer: Player? = null
        var phase: GamePhase = GamePhase.LOBBY

        mutex.withLock {
            phase = state.phase
            val turnId = state.currentTurn
            if (turnId != null) {
                turnPlayer = state.players.firstOrNull { it.id == turnId }
            }
        }

        val player = turnPlayer ?: return
        if (!player.isBot && !player.isOnline) {
            // Human is offline. Keep takeover timer running, but play immediately.
            mutex.withLock {
                if (state.currentTurn == player.id && !offlineTimers.containsKey(player.id)) {
                    startTakeoverTimer(player.id)
                }
            }
        }

        if (!player.isBot && player.isOnline) {
            // Start turn timer for human player
            var startedTimer = false
            mutex.withLock {
                if (state.currentTurn == player.id && !turnTimers.containsKey(player.id)) {
                    val waitTime = if (player.consecutiveBotMoves >= 2) {
                        3_000L
                    } else if (state.phase == GamePhase.TRUMP_BIDDING) {
                        15_000L
                    } else {
                        10_000L
                    }
                    val turnEnd = System.currentTimeMillis() + waitTime
                    state = state.copy(turnEndTime = turnEnd)
                    broadcastState()
                    
                    val job = CoroutineScope(Dispatchers.Default).launch {
                        delay(waitTime)
                        forceBotMove(player.id)
                    }
                    turnTimers[player.id] = job
                    startedTimer = true
                }
            }
            return
        }

        // Player is a bot, or offline human. Execute bot action
        delay(1000)

        // Verify phase and turn have not shifted during delay
        var activeTurnId: PlayerId? = null
        var activePhase: GamePhase = GamePhase.LOBBY
        mutex.withLock {
            activeTurnId = state.currentTurn
            activePhase = state.phase
        }

        if (activeTurnId != player.id || activePhase != phase) return

        if (phase == GamePhase.REGULAR_BIDDING) {
            val botHand = state.hands[player.id] ?: emptyList()
            var minBidAllowed = state.minBid ?: 1
            if (state.trumpBidState.highestBidderId == player.id && state.trumpBidState.highestBid > 0) {
                minBidAllowed = maxOf(minBidAllowed, state.trumpBidState.highestBid)
            }
            val bid = calculateBotBid(botHand, minBidAllowed, state.currentTrumpSuit)
            placeBid(player.id, bid, isAutoPlay = true)
        } else if (phase == GamePhase.TRUMP_BIDDING) {
            // Bots simply pass during custom trump bidding for now
            placeTrumpBid(player.id, null, null, isAutoPlay = true)
        } else if (phase == GamePhase.PLAYING) {
            val card = selectBotCard(state, player.id)
            playCard(player.id, card, isAutoPlay = true)
        }
    }

    /**
     * Launches a background coroutine to wait 5 seconds and start the next round automatically.
     */
    private fun startIntermission() {
        CoroutineScope(Dispatchers.Default).launch {
            delay(5000)
            startNextRound()
        }
    }

    // ─── Broadcast ───────────────────────────────────────────────────────────

    /**
     * Broadcasts the current state to all connected sessions.
     * Each player receives a tailored [GameStateDto] with only their own hand.
     * Also persists state to Redis for crash recovery.
     * Must be called inside [mutex].
     */
    private suspend fun broadcastState() {
        val snapshot = state

        // Persist to Redis after every state change (crash recovery)
        if (snapshot.phase != GamePhase.LOBBY && snapshot.phase != GamePhase.GAME_OVER) {
            RedisService.saveGameState(snapshot.roomId, snapshot)
        } else if (snapshot.phase == GamePhase.GAME_OVER) {
            // Game ended — clean up the Redis entry
            RedisService.deleteGameState(snapshot.roomId)
        }

        sessions.forEach { (playerId, session) ->
            val dto = toDto(snapshot, playerId)
            val message = ServerMessage.StateUpdate(dto)
            try {
                session.send(appJson.encodeToString<ServerMessage>(message))
            } catch (e: Exception) {
                // Session likely disconnected; will be cleaned up on close
            }
        }
    }

    private fun saveResultsToSupabase(finalState: CallbreakState) {
        CoroutineScope(Dispatchers.IO).launch {
            finalState.players.forEach { player ->
                if (!player.isBot) {
                    SupabaseService.saveMatchResult(
                        supabaseUserId = player.id,
                        playerName = player.name,
                        roomId = finalState.roomId,
                        score = player.cumulativeScore,
                        rank = player.rank ?: 4
                    )
                }
            }
        }
    }
}
