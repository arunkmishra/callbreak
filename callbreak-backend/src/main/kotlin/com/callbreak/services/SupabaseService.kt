package com.callbreak.services

import com.callbreak.config.appJson
import com.callbreak.config.getEnv
import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.header
import io.ktor.client.request.patch
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.slf4j.LoggerFactory

private val logger = LoggerFactory.getLogger("SupabaseService")

/**
 * Server-side Supabase client using the Service Role key.
 *
 * This bypasses Row Level Security and is used exclusively for writes
 * triggered by game events (match results, leaderboard updates).
 * NEVER expose the service role key to Flutter clients.
 */
object SupabaseService {

    private val supabaseUrl by lazy { getEnv("SUPABASE_URL") }
    private val serviceRoleKey by lazy { getEnv("SUPABASE_SERVICE_ROLE_KEY") }

    private val client = HttpClient(CIO) {
        install(ContentNegotiation) {
            json(appJson)
        }
    }

    // ── Match Result ─────────────────────────────────────────────────────────

    /**
     * Saves a single player's match result to the `match_results` table.
     * Also updates aggregate stats on the `profiles` table.
     *
     * @param supabaseUserId The Supabase Auth UUID of the player.
     * @param roomId         The 5-letter Callbreak room code.
     * @param score          Final cumulative score for this match.
     * @param rank           Finishing position (1 = winner, 4 = last).
     */
    suspend fun saveMatchResult(
        supabaseUserId: String,
        roomId: String,
        score: Double,
        rank: Int
    ) {
        try {
            // Insert match result row
            val body = buildJsonObject {
                put("user_id", supabaseUserId)
                put("room_id", roomId)
                put("score", score)
                put("rank", rank)
            }
            client.post("$supabaseUrl/rest/v1/match_results") {
                header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                header("apikey", serviceRoleKey)
                header("Prefer", "return=minimal")
                contentType(ContentType.Application.Json)
                setBody(body.toString())
            }

            // Update profile aggregate stats
            val won = if (rank == 1) 1 else 0
            val profilePatch = buildJsonObject {
                put("total_games", "total_games + 1")
                put("total_wins", "total_wins + $won")
                put("total_score", "total_score + $score")
            }
            client.patch("$supabaseUrl/rest/v1/profiles?id=eq.$supabaseUserId") {
                header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                header("apikey", serviceRoleKey)
                header("Prefer", "return=minimal")
                // Use raw SQL via RPC for atomic increment
                setBody("""{"total_games": total_games + 1, "total_wins": total_wins + $won, "total_score": total_score + $score}""")
                contentType(ContentType.Application.Json)
            }

            logger.info("✅ Saved match result for user $supabaseUserId (rank=$rank, score=$score)")
        } catch (e: Exception) {
            logger.error("❌ Failed to save match result for $supabaseUserId: ${e.message}")
        }
    }
}
