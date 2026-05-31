package com.callbreak.services

import com.callbreak.config.appJson
import com.callbreak.config.getEnv
import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.patch
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.doubleOrNull
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
        playerName: String,
        roomId: String,
        score: Double,
        rank: Int
    ) {
        try {
            // First check if profile exists
            val getResponse = client.get("$supabaseUrl/rest/v1/profiles?id=eq.$supabaseUserId&select=total_games,total_wins,total_score") {
                header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                header("apikey", serviceRoleKey)
            }
            
            if (getResponse.status.value !in 200..299) {
                logger.error("❌ Failed to GET profile: ${getResponse.status} ${getResponse.bodyAsText()}")
                return
            }
            
            val responseText = getResponse.bodyAsText()
            val jsonArray = kotlinx.serialization.json.Json.parseToJsonElement(responseText).jsonArray
            val won = if (rank == 1) 1 else 0
            
            if (jsonArray.isEmpty()) {
                // Profile doesn't exist. Check if they have a valid custom username.
                val isGuest = playerName.lowercase().startsWith("guest") || playerName.startsWith("pending_")
                val isValidUsername = playerName.isNotBlank() && playerName.length >= 3 && !isGuest
                
                if (isValidUsername) {
                    logger.info("ℹ️ Creating new profile for $supabaseUserId with username $playerName")
                    var finalUsername = playerName
                    var newProfile = buildJsonObject {
                        put("id", supabaseUserId)
                        put("username", finalUsername)
                        put("total_games", 1)
                        put("total_wins", won)
                        put("total_score", score)
                    }
                    var postProfileResponse = client.post("$supabaseUrl/rest/v1/profiles") {
                        header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                        header("apikey", serviceRoleKey)
                        header("Prefer", "return=minimal")
                        contentType(ContentType.Application.Json)
                        setBody(newProfile.toString())
                    }

                    // Handle unique constraint violation on username
                    if (postProfileResponse.status.value == 409) {
                        finalUsername = "${playerName}_${supabaseUserId.take(4)}"
                        logger.info("ℹ️ Username $playerName taken, retrying with $finalUsername")
                        newProfile = buildJsonObject {
                            put("id", supabaseUserId)
                            put("username", finalUsername)
                            put("total_games", 1)
                            put("total_wins", won)
                            put("total_score", score)
                        }
                        postProfileResponse = client.post("$supabaseUrl/rest/v1/profiles") {
                            header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                            header("apikey", serviceRoleKey)
                            header("Prefer", "return=minimal")
                            contentType(ContentType.Application.Json)
                            setBody(newProfile.toString())
                        }
                    }

                    if (postProfileResponse.status.value !in 200..299) {
                        logger.error("❌ Failed to POST new profile: ${postProfileResponse.status} ${postProfileResponse.bodyAsText()}")
                        return
                    }
                } else {
                    logger.info("ℹ️ Skipping Supabase update for $supabaseUserId (No profile found and username '$playerName' is not a valid custom name)")
                    return
                }
            } else {
                // Update profile aggregate stats
                val profile = jsonArray[0].jsonObject
                val currentGames = profile["total_games"]?.jsonPrimitive?.intOrNull ?: 0
                val currentWins = profile["total_wins"]?.jsonPrimitive?.intOrNull ?: 0
                val currentScore = profile["total_score"]?.jsonPrimitive?.doubleOrNull ?: 0.0

                val profilePatch = buildJsonObject {
                    put("total_games", currentGames + 1)
                    put("total_wins", currentWins + won)
                    put("total_score", currentScore + score)
                }

                val patchResponse = client.patch("$supabaseUrl/rest/v1/profiles?id=eq.$supabaseUserId") {
                    header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                    header("apikey", serviceRoleKey)
                    header("Prefer", "return=minimal")
                    contentType(ContentType.Application.Json)
                    setBody(profilePatch.toString())
                }
                if (patchResponse.status.value !in 200..299) {
                    logger.error("❌ Failed to PATCH profile: ${patchResponse.status} ${patchResponse.bodyAsText()}")
                }
            }

            // Insert match result row (profile is now guaranteed to exist)
            val body = buildJsonObject {
                put("user_id", supabaseUserId)
                put("room_id", roomId)
                put("score", score)
                put("rank", rank)
            }
            val postResponse = client.post("$supabaseUrl/rest/v1/match_results") {
                header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                header("apikey", serviceRoleKey)
                header("Prefer", "return=minimal")
                contentType(ContentType.Application.Json)
                setBody(body.toString())
            }
            if (postResponse.status.value !in 200..299) {
                logger.error("❌ Failed to POST match_results: ${postResponse.status} ${postResponse.bodyAsText()}")
            }

            logger.info("✅ Finished Supabase update flow for user $supabaseUserId (rank=$rank, score=$score)")
        } catch (e: Exception) {
            logger.error("❌ Exception during saveMatchResult for $supabaseUserId: ${e.message}")
        }
    }
}
