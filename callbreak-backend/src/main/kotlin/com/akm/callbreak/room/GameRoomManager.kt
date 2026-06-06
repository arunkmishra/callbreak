package com.akm.callbreak.room

import com.akm.callbreak.domain.models.CallbreakState
import com.akm.callbreak.domain.models.GamePhase
import com.akm.callbreak.domain.models.Player
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import org.slf4j.LoggerFactory

private val logger = LoggerFactory.getLogger("GameRoomManager")
private const val ROOM_CODE_LENGTH = 5
private val ROOM_CODE_CHARS = ('A'..'Z').toList()

/**
 * Manages all active game rooms in memory.
 *
 * [rooms] is a [ConcurrentHashMap] for safe concurrent reads.
 * Each room's internal mutations are gated by its own [kotlinx.coroutines.sync.Mutex]
 * inside [GameRoom], so no global lock is needed here.
 */
object GameRoomManager {

    private val rooms = ConcurrentHashMap<String, GameRoom>()

    // ─── Room Creation ───────────────────────────────────────────────────────

    /**
     * Creates a new room and registers the creator as the first player.
     *
     * @param playerName Display name of the host player.
     * @return Triple of (roomId, playerId, sessionToken).
     */
    fun createRoom(
        playerName: String,
        totalRounds: Int = 5,
        minBid: Int? = null,
        greedPenalty: Boolean = false,
        allowCustomTrump: Boolean = false,
        playerId: String? = null
    ): Triple<String, String, String> {
        val roomId = generateUniqueRoomId()
        val finalPlayerId = playerId ?: UUID.randomUUID().toString()
        val sessionToken = UUID.randomUUID().toString()
        val host = Player(id = finalPlayerId, name = playerName)
        val initialState = CallbreakState(
            roomId = roomId,
            players = listOf(host),
            totalRounds = totalRounds,
            minBid = minBid,
            greedPenalty = greedPenalty,
            allowCustomTrump = allowCustomTrump
        )
        val room = GameRoom(initialState)
        room.registerSessionToken(finalPlayerId, sessionToken)
        rooms[roomId] = room
        logger.info(
            "🏠 Room '$roomId' created by '$playerName' ($finalPlayerId) — " +
            "rounds=$totalRounds, minBid=$minBid, greedPenalty=$greedPenalty, customTrump=$allowCustomTrump. " +
            "Active rooms: ${rooms.size}"
        )
        return Triple(roomId, finalPlayerId, sessionToken)
    }

    // ─── Room Joining ────────────────────────────────────────────────────────

    /**
     * Adds a player to an existing room.
     *
     * @param roomId     The 5-letter room code.
     * @param playerName Display name for the joining player.
     * @return [Result] of Pair(playerId, sessionToken) on success, or failure with a reason.
     */
    suspend fun joinRoom(
        roomId: String,
        playerName: String,
        playerId: String? = null
    ): Result<Pair<String, String>> {
        val room = rooms[roomId.uppercase()]
            ?: run {
                logger.warn("❌ Join failed — room '$roomId' not found")
                return Result.failure(Exception("Room '$roomId' not found"))
            }

        val state = room.getState()

        // Check if there is an offline player with the same name in this room
        val existingOfflinePlayer = state.players.firstOrNull {
            it.name.equals(playerName, ignoreCase = true) && !it.isOnline
        }

        if (existingOfflinePlayer != null) {
            val token = room.getSessionToken(existingOfflinePlayer.id)
                ?: return Result.failure(Exception("Session token not found for offline player"))
            logger.info("♻️  Room '$roomId' — '$playerName' rejoining as existing offline player ${existingOfflinePlayer.id}")
            return Result.success(existingOfflinePlayer.id to token)
        }

        if (state.phase != GamePhase.LOBBY) {
            logger.warn("❌ Join failed — room '$roomId' game already started (phase=${state.phase})")
            return Result.failure(Exception("Game in room '$roomId' has already started"))
        }
        if (state.players.size >= CallbreakState.PLAYERS_REQUIRED) {
            logger.warn("❌ Join failed — room '$roomId' is full (${state.players.size}/${CallbreakState.PLAYERS_REQUIRED})")
            return Result.failure(Exception("Room '$roomId' is full"))
        }
        if (state.players.any { it.name.equals(playerName, ignoreCase = true) }) {
            logger.warn("❌ Join failed — name '$playerName' already taken in room '$roomId'")
            return Result.failure(Exception("Name '$playerName' is already taken in this room"))
        }

        val finalPlayerId = playerId ?: UUID.randomUUID().toString()
        val sessionToken = UUID.randomUUID().toString()
        val newPlayer = Player(id = finalPlayerId, name = playerName)

        // Since we need to mutate state via the room, we delegate to an internal fn.
        // The room's Mutex guards mutations and broadcasts the updated state.
        room.addPlayer(newPlayer)
        room.registerSessionToken(finalPlayerId, sessionToken)

        logger.info("➕ Room '$roomId' — '$playerName' ($finalPlayerId) joined. Players: ${state.players.size + 1}/${CallbreakState.PLAYERS_REQUIRED}")
        return Result.success(finalPlayerId to sessionToken)
    }

    // ─── Lookup ──────────────────────────────────────────────────────────────

    fun getRoom(roomId: String): GameRoom? = rooms[roomId.uppercase()]

    fun roomExists(roomId: String): Boolean = rooms.containsKey(roomId.uppercase())

    // ─── Cleanup ─────────────────────────────────────────────────────────────

    fun removeRoom(roomId: String) {
        val removed = rooms.remove(roomId.uppercase())
        if (removed != null) {
            logger.info("🗑️  Room '$roomId' removed from manager. Active rooms: ${rooms.size}")
        } else {
            logger.warn("⚠️  removeRoom called for '$roomId' but it was not found in manager")
        }
    }

    /**
     * Restores a previously persisted [GameRoom] into the manager.
     * Called on server startup when rehydrating from Redis.
     */
    fun restoreRoom(roomId: String, room: GameRoom) {
        rooms[roomId.uppercase()] = room
        logger.info("🔄 Room '$roomId' restored from Redis. Active rooms: ${rooms.size}")
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private fun generateUniqueRoomId(): String {
        var id: String
        do {
            id = (1..ROOM_CODE_LENGTH).map { ROOM_CODE_CHARS.random() }.joinToString("")
        } while (rooms.containsKey(id))
        return id
    }
}
