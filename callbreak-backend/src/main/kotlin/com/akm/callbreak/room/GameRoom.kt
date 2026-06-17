package com.akm.callbreak.room

import com.akm.callbreak.api.ws.ServerMessage
import com.akm.callbreak.domain.models.CallbreakState
import com.akm.callbreak.domain.models.CurrentTrick
import com.akm.callbreak.domain.models.GamePhase
import com.akm.callbreak.domain.models.PlayerId
import com.akm.callbreak.domain.models.PlayingCard
import com.akm.callbreak.domain.models.Player
import com.akm.callbreak.domain.models.Suit
import com.akm.callbreak.domain.models.TrickCard
import com.akm.callbreak.domain.models.createDeck
import com.akm.callbreak.domain.rules.evaluateTrickWinner
import com.akm.callbreak.domain.rules.validateMove
import com.akm.callbreak.domain.rules.calculateBotBid
import com.akm.callbreak.domain.rules.selectBotCard
import com.akm.callbreak.domain.rules.startDealPhase1
import com.akm.callbreak.domain.rules.startDealPhase2
import com.akm.callbreak.domain.rules.processTrumpBid
import com.akm.callbreak.domain.rules.resolveRound
import com.akm.callbreak.config.appJson
import com.akm.callbreak.plugins.RedisService
import com.akm.callbreak.services.SupabaseService
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
import org.slf4j.LoggerFactory

private val logger = LoggerFactory.getLogger("GameRoom")

/**
 * Manages a single active Callbreak game room.
 *
 * Thread-safety: all state mutations are gated behind [mutex].
 * WebSocket sessions are stored in [sessions] (playerId → session).
 *
 * Leaderboard scoring policy:
 * - A match result is only saved to Supabase if at least 2 original real (non-bot)
 *   players participated (i.e., [originalRealPlayerIds] has ≥ 2 entries).
 * - If all real players disconnect mid-game the room is torn down immediately.
 */
class GameRoom(initialState: CallbreakState) {

    private val mutex = Mutex()
    private var state: CallbreakState = initialState

    /** Connected WebSocket sessions, keyed by playerId. */
    private val sessions = mutableMapOf<PlayerId, DefaultWebSocketSession>()

    /** Active session tokens are stored in the state itself to persist across server restarts. */

    /** Takeover timers for players who are offline, keyed by playerId. */
    private val offlineTimers = ConcurrentHashMap<PlayerId, Job>()

    /** Active turn timers for human players, keyed by playerId. */
    private val turnTimers = ConcurrentHashMap<PlayerId, Job>()

    /** Timestamp (ms) of last emoticon sent per player — used for rate limiting. */
    private val emoticonTimestamps = ConcurrentHashMap<PlayerId, Long>()

    /**
     * IDs of players that were real humans at game-start.
     * Populated in [startGame] and never modified afterwards.
     * Used to decide whether a completed match should count for the leaderboard.
     */
    private val originalRealPlayerIds = mutableSetOf<PlayerId>()

    private var emptyRoomTeardownJob: Job? = null

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private fun cancelTurnTimer(playerId: PlayerId?) {
        if (playerId != null) {
            turnTimers.remove(playerId)?.cancel()
        }
    }

    /**
     * Returns true when at least one real (non-bot) player is still online.
     * Must be called inside [mutex].
     */
    private fun hasOnlineRealPlayers(): Boolean =
        state.players.any { !it.isBot && it.isOnline }

    /**
     * Tears the room down: transitions to GAME_OVER, broadcasts, deletes from Redis,
     * and removes the room from [GameRoomManager].
     * Must be called inside [mutex].
     */
    private suspend fun tearDownRoom(reason: String) {
        logger.warn("🔴 [Room ${state.roomId}] Tearing down room — $reason")
        
        if (state.phase != GamePhase.LOBBY && state.phase != GamePhase.GAME_OVER) {
            saveResultsToSupabase(state)
        }
        
        state = state.copy(phase = GamePhase.GAME_OVER)
        broadcastState()
        GameRoomManager.removeRoom(state.roomId)
        logger.info("🗑️  [Room ${state.roomId}] Room removed from GameRoomManager")
    }

    // ─── Session Management ──────────────────────────────────────────────────

    suspend fun addSession(playerId: PlayerId, session: DefaultWebSocketSession) {
        mutex.withLock { sessions[playerId] = session }
        logger.info("🔗 [Room ${state.roomId}] Session added for player $playerId")
    }

    suspend fun removeSession(playerId: PlayerId, sessionToRemove: DefaultWebSocketSession) {
        var forceTakeover = false
        var shouldTearDown = false
        mutex.withLock {
            val currentSession = sessions[playerId]
            if (currentSession != null && currentSession != sessionToRemove) {
                logger.info("🔌 [Room ${state.roomId}] Old session disconnected for player $playerId, but a new session is active. Ignoring.")
                return@withLock
            }

            sessions.remove(playerId)
            logger.info("🔌 [Room ${state.roomId}] Session removed for player $playerId (phase=${state.phase})")

            // If the game is active (not LOBBY and not GAME_OVER), mark player offline and abandoned (if public)
            if (state.phase != GamePhase.LOBBY && state.phase != GamePhase.GAME_OVER) {
                state = state.copy(
                    players = state.players.map { p ->
                        if (p.id == playerId) p.copy(isOnline = false, hasAbandoned = state.isPublic) else p
                    }
                )

                val playerName = state.players.firstOrNull { it.id == playerId }?.name ?: playerId
                logger.info("📴 [Room ${state.roomId}] Player '$playerName' ($playerId) went offline")

                // Check if all real players are now gone
                if (!hasOnlineRealPlayers()) {
                    logger.warn("⚠️  [Room ${state.roomId}] No real players remaining online — scheduling room teardown in 15 seconds")
                    emptyRoomTeardownJob?.cancel()
                    emptyRoomTeardownJob = CoroutineScope(Dispatchers.Default).launch {
                        delay(15000)
                        mutex.withLock {
                            if (!hasOnlineRealPlayers() && state.phase != GamePhase.GAME_OVER) {
                                tearDownRoom("all real players disconnected and 15s timer expired")
                            }
                        }
                    }
                } else {
                    broadcastState()
                    // If it is currently this player's turn, start the 60-second timer
                    if (state.currentTurn == playerId) {
                        logger.info("⏱️  [Room ${state.roomId}] Starting takeover timer for offline player $playerId (their turn)")
                        startTakeoverTimer(playerId)
                        cancelTurnTimer(playerId)
                        forceTakeover = true
                    }
                }
            }
        }

        if (shouldTearDown) {
            mutex.withLock { tearDownRoom("all real players disconnected") }
        } else if (forceTakeover) {
            triggerBotActionsIfNeeded()
        }
    }

    suspend fun leaveRoom(playerId: PlayerId) {
        var shouldTearDown = false
        mutex.withLock {
            state = state.copy(sessionTokens = state.sessionTokens - playerId)
            val playerName = state.players.firstOrNull { it.id == playerId }?.name ?: playerId
            logger.info("🚪 [Room ${state.roomId}] Player '$playerName' ($playerId) explicitly left the room (phase=${state.phase})")

            if (state.phase == GamePhase.LOBBY) {
                // Remove player from the lobby to vacate the seat and transfer host
                state = state.copy(
                    players = state.players.filter { it.id != playerId }
                )
                logger.info("🧹 [Room ${state.roomId}] Player removed from lobby. Remaining: ${state.players.size}")
            } else if (state.phase != GamePhase.GAME_OVER) {
                // Game active: immediately take over with a bot
                state = state.copy(
                    players = state.players.map { player ->
                        if (player.id == playerId) {
                            val botName = if (player.name.endsWith(" (Bot)")) player.name else "${player.name} (Bot)"
                            logger.info("🤖 [Room ${state.roomId}] Player '$playerName' replaced by bot '$botName'")
                            player.copy(
                                isOnline = false,
                                isBot = true,
                                hasAbandoned = state.isPublic,
                                name = botName
                            )
                        } else player
                    }
                )

                // Check if all real players are now gone
                if (!hasOnlineRealPlayers()) {
                    logger.warn("⚠️  [Room ${state.roomId}] Last real player left — scheduling room teardown")
                    shouldTearDown = true
                }
            }

            if (!shouldTearDown) broadcastState()
        }

        if (shouldTearDown) {
            mutex.withLock { tearDownRoom("last real player left") }
            return
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

    suspend fun registerSessionToken(playerId: PlayerId, token: String) {
        mutex.withLock {
            state = state.copy(sessionTokens = state.sessionTokens + (playerId to token))
        }
    }

    fun validateSessionToken(playerId: PlayerId, token: String): Boolean {
        val exists = state.players.any { it.id == playerId }
        return exists && state.sessionTokens[playerId] == token
    }

    fun getSessionToken(playerId: PlayerId): String? {
        return state.sessionTokens[playerId]
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
                    val wasBot = p.isBot
                    val updated = p.copy(
                        isOnline = true,
                        isBot = false, // Hot-swap player back in
                        name = cleanName
                    )
                    if (wasBot) {
                        logger.info("♻️  [Room ${state.roomId}] Player '${cleanName}' ($playerId) reconnected and reclaimed seat from bot")
                    } else {
                        logger.info("✅ [Room ${state.roomId}] Player '${cleanName}' ($playerId) reconnected")
                    }
                    updated
                } else p
            }
        )
        if (hasOnlineRealPlayers()) {
            emptyRoomTeardownJob?.cancel()
        }
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
            logger.info("➕ [Room ${state.roomId}] Player '${player.name}' (${player.id}) joined lobby. Total: ${state.players.size}")
        }
        broadcastState()
    }

    // ─── Game Lifecycle ──────────────────────────────────────────────────────

    /**
     * Starts the game: deals cards and moves to BIDDING phase.
     * Fills any empty seats with bots to reach 4 players.
     * Records all human players in [originalRealPlayerIds] for leaderboard eligibility.
     */
    suspend fun startGame(): Result<Unit> {
        val startResult = mutex.withLock {
            if (state.phase != GamePhase.LOBBY) {
                logger.warn("⚠️  [Room ${state.roomId}] startGame called but phase=${state.phase}")
                return@withLock Result.failure(Exception("Game already started"))
            }
            val humanCount = state.players.size
            if (humanCount == 0) {
                return@withLock Result.failure(Exception("Need at least 1 player to start"))
            }

            // Record original real players before any bots are added
            originalRealPlayerIds.clear()
            state.players.filterNot { it.isBot }.forEach { originalRealPlayerIds.add(it.id) }
            logger.info(
                "🎮 [Room ${state.roomId}] Game starting — real players: " +
                "${state.players.filterNot { it.isBot }.map { it.name }}, " +
                "bots needed: ${CallbreakState.PLAYERS_REQUIRED - humanCount}"
            )

            // Fill empty seats with bots to reach 4 players
            val botsNeeded = CallbreakState.PLAYERS_REQUIRED - humanCount
            val updatedPlayers = state.players.toMutableList()
            var newTokens = state.sessionTokens
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
                newTokens = newTokens + (botId to "bot-token-$botId")
                logger.debug("🤖 [Room ${state.roomId}] Added bot: ${bot.name} (${bot.id})")
            }

            val shuffled = createDeck().shuffled()
            val stateWithBots = state.copy(
                players = updatedPlayers.map { it.copy(cumulativeScore = 0.0) },
                sessionTokens = newTokens
            )

            state = startDealPhase1(stateWithBots, shuffled)
            logger.info("🃏 [Room ${state.roomId}] Cards dealt — phase=${state.phase}, dealer index=${state.dealerIndex}")

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

            val playerName = state.players.firstOrNull { it.id == playerId }?.name ?: playerId
            val bidType = if (isAutoPlay) "auto" else "manual"
            logger.info("🃏 [Room ${state.roomId}] Player '$playerName' bid $bid ($bidType)")

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

            if (allBid) {
                logger.info(
                    "✅ [Room ${state.roomId}] All bids placed: " +
                    "${newBids.entries.joinToString { (id, b) -> "${state.players.firstOrNull { it.id == id }?.name ?: id}=$b" }}. " +
                    "First player: $firstPlayer"
                )
            }

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

            val playerName = state.players.firstOrNull { it.id == playerId }?.name ?: playerId
            val action = if (bid == null) "passed trump bid" else "bid trump suit=${suit?.displayName} with $bid"
            val bidType = if (isAutoPlay) "auto" else "manual"
            logger.info("🎴 [Room ${state.roomId}] Player '$playerName' $action ($bidType)")

            val oldTurn = state.currentTurn
            var nextState = nextStateResult.getOrThrow()
            if (nextState.phase == GamePhase.DEALING_PHASE_2) {
                nextState = startDealPhase2(nextState)
                logger.info("🃏 [Room ${state.roomId}] Trump bidding ended — trump suit=${nextState.currentTrumpSuit}. Phase 2 dealing done.")
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

            val playerName = state.players.firstOrNull { it.id == playerId }?.name ?: playerId
            val cardType = if (isAutoPlay) "auto" else "manual"
            logger.debug("🎴 [Room ${state.roomId}] Player '$playerName' played ${card.suit.displayName} ${card.rank.displayName} ($cardType)")

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

                val winnerName = state.players.firstOrNull { it.id == winner }?.name ?: winner
                val newTricksWon = state.tricksWon + (winner to (state.tricksWon[winner] ?: 0) + 1)
                val totalTricksPlayed = newTricksWon.values.sum()
                logger.debug("🏆 [Room ${state.roomId}] Trick won by '$winnerName'. Total tricks this round: $totalTricksPlayed")

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
                            var tempState = resolveRound(roundFinishedState)
                            if (tempState.phase == GamePhase.GAME_OVER) {
                                tempState = SupabaseService.calculateEloChangesForState(tempState, originalRealPlayerIds)
                            }
                            state = tempState
                            broadcastState()
                            when (state.phase) {
                                GamePhase.ROUND_OVER -> {
                                    logger.info(
                                        "📊 [Room ${state.roomId}] Round ${state.currentRound} over. Scores: " +
                                        state.players.joinToString { "${it.name}=${it.cumulativeScore}" }
                                    )
                                    startIntermission()
                                }
                                GamePhase.GAME_OVER -> {
                                    logger.info(
                                        "🏁 [Room ${state.roomId}] Game over after ${state.totalRounds} rounds. " +
                                        "Final scores: ${state.players.joinToString { "${it.name}=${it.cumulativeScore} (rank=${it.rank})" }}"
                                    )
                                    saveResultsToSupabase(state)
                                }
                                else -> {}
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

            logger.info("🔄 [Room ${state.roomId}] Round ${state.currentRound} started — dealer index=$nextDealer, phase=${state.phase}")
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
        logger.info("⏳ [Room ${state.roomId}] 60s takeover timer started for player $playerId")
    }

    private suspend fun triggerTakeover(playerId: PlayerId) {
        var needsAction = false
        var shouldTearDown = false
        mutex.withLock {
            val p = state.players.firstOrNull { it.id == playerId }
            if (p != null && !p.isOnline && state.currentTurn == playerId) {
                val botName = if (p.name.endsWith(" (Bot)")) p.name else "${p.name} (Bot)"
                logger.info("🤖 [Room ${state.roomId}] Takeover timer expired — converting '${p.name}' to bot '$botName'")
                state = state.copy(
                    players = state.players.map { player ->
                        if (player.id == playerId) {
                            player.copy(
                                isBot = true,
                                name = botName
                            )
                        } else player
                    }
                )
                broadcastState()
                needsAction = true

                // After takeover, check if any real players remain
                if (!hasOnlineRealPlayers()) {
                    logger.warn("⚠️  [Room ${state.roomId}] No real players left after takeover — tearing down room")
                    shouldTearDown = true
                }
            }
        }

        if (shouldTearDown) {
            mutex.withLock { tearDownRoom("all real players gone after takeover") }
        } else if (needsAction) {
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
            logger.debug("⏰ [Room ${state.roomId}] Force-bidding for timed-out player $playerId: bid=$bid")
            placeBid(playerId, bid, isAutoPlay = true)
        } else if (phase == GamePhase.TRUMP_BIDDING) {
            logger.debug("⏰ [Room ${state.roomId}] Force-passing trump bid for timed-out player $playerId")
            placeTrumpBid(playerId, null, null, isAutoPlay = true)
        } else if (phase == GamePhase.PLAYING) {
            val card = selectBotCard(stateCopy, playerId)
            logger.debug("⏰ [Room ${state.roomId}] Force-playing card for timed-out player $playerId: ${card.suit.displayName} ${card.rank.displayName}")
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
                    logger.info("⏱️  [Room ${state.roomId}] Offline player ${player.id} is current turn — starting takeover timer")
                    startTakeoverTimer(player.id)
                }
            }
        }

        if (!player.isBot && player.isOnline) {
            // Start turn timer for human player
            mutex.withLock {
                if (state.currentTurn == player.id && !turnTimers.containsKey(player.id)) {
                    val waitTime = if (player.consecutiveBotMoves >= 2) {
                        3_000L
                    } else if (state.phase == GamePhase.TRUMP_BIDDING || state.phase == GamePhase.REGULAR_BIDDING) {
                        15_000L
                    } else {
                        10_000L
                    }
                    val turnEnd = System.currentTimeMillis() + waitTime
                    state = state.copy(turnEndTime = turnEnd)
                    broadcastState()
                    logger.debug("⏱️  [Room ${state.roomId}] Turn timer started for '${player.name}' (${player.id}) — ${waitTime}ms (phase=$phase)")

                    val job = CoroutineScope(Dispatchers.Default).launch {
                        // Add 2000ms grace period to factor in network delays from clients
                        delay(waitTime + 2000L)
                        forceBotMove(player.id)
                    }
                    turnTimers[player.id] = job
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
            logger.debug("🤖 [Room ${state.roomId}] Bot '${player.name}' bidding $bid")
            placeBid(player.id, bid, isAutoPlay = true)
        } else if (phase == GamePhase.TRUMP_BIDDING) {
            logger.debug("🤖 [Room ${state.roomId}] Bot '${player.name}' passing trump bid")
            // Bots simply pass during custom trump bidding for now
            placeTrumpBid(player.id, null, null, isAutoPlay = true)
        } else if (phase == GamePhase.PLAYING) {
            val card = selectBotCard(state, player.id)
            logger.debug("🤖 [Room ${state.roomId}] Bot '${player.name}' playing ${card.suit.displayName} ${card.rank.displayName}")
            playCard(player.id, card, isAutoPlay = true)
        }
    }

    /**
     * Launches a background coroutine to wait 5 seconds and start the next round automatically.
     */
    private fun startIntermission() {
        logger.info("⏸️  [Room ${state.roomId}] Round intermission — next round starts in 5s")
        CoroutineScope(Dispatchers.Default).launch {
            delay(5000)
            startNextRound()
        }
    }

    // ─── Emoticons ────────────────────────────────────────────────────────────

    /**
     * Handles an incoming emoticon from a player.
     *
     * - Validates the emoticon (non-empty, max 8 chars, allowlisted set).
     * - Enforces a 3-second per-player cooldown.
     * - Broadcasts [ServerMessage.EmoticonReceived] to all sessions in the room.
     */
    suspend fun handleEmoticon(playerId: PlayerId, emoticon: String) {
        // Basic validation
        val trimmed = emoticon.trim()
        if (trimmed.isEmpty() || trimmed.length > 8) {
            logger.warn("⚠️  [Room ${state.roomId}] Invalid emoticon from $playerId: '$trimmed'")
            return
        }

        // Allowlist: only the known catalog entries are accepted
        val allowed = setOf("😂", "😤", "😭", "🤯", "😎", "🤬",
                            "🎯", "👑", "💎", "🦁", "⚡", "🌪️", "🏆", "🤑", "🔥", "👏", "💀")
        if (trimmed !in allowed) {
            logger.warn("⚠️  [Room ${state.roomId}] Emoticon not in allowlist from $playerId: '$trimmed'")
            return
        }

        // Rate limit: one emoticon per player per 3 seconds
        val now = System.currentTimeMillis()
        val last = emoticonTimestamps[playerId] ?: 0L
        if (now - last < 3000L) {
            logger.debug("🚫 [Room ${state.roomId}] Emoticon rate-limited for $playerId")
            return
        }
        emoticonTimestamps[playerId] = now

        val playerName = state.players.firstOrNull { it.id == playerId }?.name ?: playerId
        logger.info("😊 [Room ${state.roomId}] '$playerName' sent emoticon: $trimmed")

        broadcastEmoticon(playerId, trimmed)
    }

    /** Sends an EMOTICON_RECEIVED message to all connected sessions. */
    private suspend fun broadcastEmoticon(playerId: PlayerId, emoticon: String) {
        val message = ServerMessage.EmoticonReceived(playerId = playerId, emoticon = emoticon)
        val encoded = appJson.encodeToString<ServerMessage>(message)
        mutex.withLock {
            sessions.values.forEach { session ->
                try {
                    session.send(encoded)
                } catch (_: Exception) { /* session likely disconnected */ }
            }
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

    /**
     * Saves match results to Supabase **only if** the game had at least 2 original real players.
     *
     * Scoring rules:
     * - We only count the game if [originalRealPlayerIds] contains ≥ 2 entries, meaning the
     *   game was played between at least 2 real humans (bot-only or 1-human games are excluded).
     * - We save results only for players who are still real (non-bot) at game end.
     */
    private fun saveResultsToSupabase(finalState: CallbreakState) {
        val realPlayerCount = originalRealPlayerIds.size
        if (realPlayerCount == 0) return

        CoroutineScope(Dispatchers.IO).launch {
            // Save the full match scorecard for history view (includes practice matches)
            logger.info("💾 [Room ${finalState.roomId}] Saving full match scorecard")
            SupabaseService.saveMatchScorecard(finalState, originalRealPlayerIds)

            if (realPlayerCount < 2) {
                logger.info(
                    "⏭️  [Room ${finalState.roomId}] Saving offline match results — only $realPlayerCount real player(s) " +
                    "participated. originalRealPlayerIds=$originalRealPlayerIds"
                )
                SupabaseService.saveOfflineMatchResults(finalState, originalRealPlayerIds)
                return@launch
            }

            logger.info("📈 [Room ${finalState.roomId}] Saving leaderboard results with Elo calculation")
            val stateToSave = if (finalState.players.any { it.rpChange == null }) {
                SupabaseService.calculateEloChangesForState(finalState, originalRealPlayerIds.map { it }.toSet())
            } else finalState
            SupabaseService.saveMatchResultsWithElo(stateToSave, originalRealPlayerIds)
        }
    }
}
