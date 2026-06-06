package com.akm.callbreak.plugins

import com.akm.callbreak.config.getEnv
import com.akm.callbreak.domain.models.CallbreakState
import com.akm.callbreak.config.appJson
import com.akm.callbreak.room.GameRoom
import com.akm.callbreak.room.GameRoomManager
import io.lettuce.core.RedisClient
import io.lettuce.core.api.StatefulRedisConnection
import io.lettuce.core.api.sync.RedisCommands
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.slf4j.LoggerFactory

private val logger = LoggerFactory.getLogger("Redis")

/**
 * Singleton Redis client backed by Upstash.
 *
 * Lettuce is thread-safe. A single [StatefulRedisConnection] is shared across coroutines.
 *
 * Usage:
 *   RedisService.commands.set("key", "value")
 *   val value = RedisService.commands.get("key")
 */
object RedisService {
    private var client: RedisClient? = null
    private var connection: StatefulRedisConnection<String, String>? = null

    val commands: RedisCommands<String, String>
        get() = connection?.sync() ?: error("Redis not initialized. Call RedisService.init() first.")

    fun init() {
        val redisUrl = getEnv("REDIS_URL")
        logger.info("Connecting to Redis at Upstash...")
        client = RedisClient.create(redisUrl)
        connection = client!!.connect()
        logger.info("✅ Redis connected successfully.")
    }

    fun close() {
        connection?.close()
        client?.shutdown()
        logger.info("Redis connection closed.")
    }

    // ── Game State (Crash Recovery) ───────────────────────────────────────────

    /** Saves a JSON-serialized game state for [roomId] with a 2-hour TTL. */
    fun saveGameState(roomId: String, state: CallbreakState) {
        try {
            val json = appJson.encodeToString(state)
            commands.setex("game:$roomId", 7200, json)
        } catch (e: Exception) {
            logger.warn("Failed to save game state for room $roomId: ${e.message}")
        }
    }

    /** Retrieves the saved game state for [roomId], or null if not found/expired. */
    fun getGameState(roomId: String): CallbreakState? {
        return try {
            val json = commands.get("game:$roomId") ?: return null
            appJson.decodeFromString<CallbreakState>(json)
        } catch (e: Exception) {
            logger.warn("Failed to deserialize game state for room $roomId: ${e.message}")
            null
        }
    }

    /** Deletes the saved game state for [roomId] (called when game ends). */
    fun deleteGameState(roomId: String) {
        try {
            commands.del("game:$roomId")
        } catch (e: Exception) {
            logger.warn("Failed to delete game state for room $roomId: ${e.message}")
        }
    }

    // ── Online Status ─────────────────────────────────────────────────────────

    /** Marks [userId] as online with a [ttlSeconds] TTL. */
    fun setOnline(userId: String, status: String = "available", ttlSeconds: Long = 35) {
        try {
            commands.setex("online:$userId", ttlSeconds, status)
        } catch (e: Exception) {
            logger.warn("Failed to set online status for $userId: ${e.message}")
        }
    }

    /** Returns all currently online user IDs and their statuses. */
    fun getOnlineUsers(): Map<String, String> {
        return try {
            val keys = commands.keys("online:*")
            if (keys.isEmpty()) return emptyMap()
            
            val values = commands.mget(*keys.toTypedArray())
            val map = mutableMapOf<String, String>()
            for (i in keys.indices) {
                val userId = keys[i].removePrefix("online:")
                val status = values[i].value ?: "available"
                map[userId] = status
            }
            map
        } catch (e: Exception) {
            emptyMap()
        }
    }
}

/** Initializes the Redis connection on application startup. */
fun initRedis() {
    RedisService.init()
}

/**
 * On startup, scan Redis for all persisted game states and rehydrate
 * them into [GameRoomManager]. This restores games that were in progress
 * when the server last crashed or restarted.
 */
fun restoreAllGames() {
    try {
        val keys = RedisService.commands.keys("game:*")
        if (keys.isEmpty()) {
            logger.info("No active games to restore from Redis.")
            return
        }
        logger.info("🔄 Restoring ${keys.size} active game(s) from Redis...")
        var restored = 0
        for (key in keys) {
            val roomId = key.removePrefix("game:")
            val state = RedisService.getGameState(roomId)
            if (state != null) {
                GameRoomManager.restoreRoom(roomId, GameRoom(state))
                restored++
                logger.info("  ✅ Restored game room: $roomId (phase=${state.phase})")
            }
        }
        logger.info("✅ Restored $restored/${keys.size} game(s) successfully.")
    } catch (e: Exception) {
        logger.error("❌ Failed to restore games from Redis: ${e.message}")
    }
}
