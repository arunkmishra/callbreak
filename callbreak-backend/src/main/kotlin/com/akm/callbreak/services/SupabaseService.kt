package com.akm.callbreak.services

import com.akm.callbreak.config.appJson
import com.akm.callbreak.config.getEnv
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
import com.akm.callbreak.domain.models.GamePhase
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.buildJsonArray
import com.akm.callbreak.domain.models.CallbreakState
import com.akm.callbreak.domain.models.PlayerId
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

    // ── Wallet and Store ─────────────────────────────────────────────────────

    @Serializable
    data class WalletState(
        val coinBalance: Int,
        val isPremiumSubscriber: Boolean,
        val unlockedSkins: List<String>
    )

    suspend fun getWallet(userId: String): WalletState? {
        try {
            val response = client.get("$supabaseUrl/rest/v1/profiles?id=eq.$userId&select=coin_balance,premium_until,unlocked_skins") {
                header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                header("apikey", serviceRoleKey)
            }
            if (response.status.value in 200..299) {
                val array = kotlinx.serialization.json.Json.parseToJsonElement(response.bodyAsText()).jsonArray
                if (array.isNotEmpty()) {
                    val obj = array[0].jsonObject
                    val coins = obj["coin_balance"]?.jsonPrimitive?.intOrNull ?: 0
                    
                    val p = obj["premium_until"]
                    val premiumUntilStr = if (p == null || p is kotlinx.serialization.json.JsonNull) null else p.jsonPrimitive.content
                    
                    var isPremium = false
                    if (premiumUntilStr != null) {
                        try {
                            isPremium = java.time.OffsetDateTime.parse(premiumUntilStr).toInstant().isAfter(java.time.Instant.now())
                        } catch (e: Exception) {
                            // ignore or fallback
                        }
                    }

                    val skinsArray = obj["unlocked_skins"]?.jsonArray
                    val skins = skinsArray?.mapNotNull { it.jsonPrimitive.content } ?: emptyList()
                    return WalletState(coins, isPremium, skins)
                }
            }
            logger.error("Failed to get wallet for $userId: ${response.status} ${response.bodyAsText()}")
        } catch (e: Exception) {
            logger.error("Exception in getWallet", e)
        }
        return null
    }

    @Serializable
    data class StoreItem(
        val id: String,
        val category: String,
        val name: String,
        val price: Int,
        val previewUrl: String? = null
    )

    suspend fun getStoreItems(): List<StoreItem> {
        try {
            val response = client.get("$supabaseUrl/rest/v1/store_items?select=*") {
                header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                header("apikey", serviceRoleKey)
            }
            if (response.status.value in 200..299) {
                val array = kotlinx.serialization.json.Json.parseToJsonElement(response.bodyAsText()).jsonArray
                return array.map { 
                    val obj = it.jsonObject
                    StoreItem(
                        id = obj["id"]?.jsonPrimitive?.content ?: "",
                        category = obj["category"]?.jsonPrimitive?.content ?: "",
                        name = obj["name"]?.jsonPrimitive?.content ?: "",
                        price = obj["price"]?.jsonPrimitive?.intOrNull ?: 0,
                        previewUrl = obj["preview_url"]?.jsonPrimitive?.content
                    )
                }
            }
            logger.error("Failed to get store items: ${response.status} ${response.bodyAsText()}")
        } catch (e: Exception) {
            logger.error("Exception in getStoreItems", e)
        }
        return emptyList()
    }

    suspend fun purchaseItem(userId: String, itemId: String): WalletState? {
        try {
            // 1. Get Wallet
            val wallet = getWallet(userId) ?: return null
            
            // 2. Get Item
            val items = getStoreItems()
            val item = items.find { it.id == itemId } ?: return null
            
            // 3. Check Balance
            if (wallet.coinBalance < item.price) return null
            
            // 4. Check if already owned
            if (item.category != "subscription" && item.id in wallet.unlockedSkins) return wallet
            
            // 5. Deduct and update
            val newCoins = wallet.coinBalance - item.price
            val patchObj = if (item.category == "subscription") {
                var currentPremiumUntilStr: String? = null
                val profileResponse = client.get("$supabaseUrl/rest/v1/profiles?id=eq.$userId&select=premium_until") {
                    header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                    header("apikey", serviceRoleKey)
                }
                if (profileResponse.status.value in 200..299) {
                    val array = kotlinx.serialization.json.Json.parseToJsonElement(profileResponse.bodyAsText()).jsonArray
                    if (array.isNotEmpty()) {
                        val p = array[0].jsonObject["premium_until"]
                        currentPremiumUntilStr = if (p == null || p is kotlinx.serialization.json.JsonNull) null else p.jsonPrimitive.content
                    }
                }
                
                var baseDate = java.time.Instant.now()
                if (currentPremiumUntilStr != null) {
                    try {
                        val parsed = java.time.OffsetDateTime.parse(currentPremiumUntilStr).toInstant()
                        if (parsed.isAfter(baseDate)) {
                            baseDate = parsed
                        }
                    } catch (e: Exception) {}
                }
                
                val newPremiumUntil = when (itemId) {
                    "premium_1_week" -> baseDate.plus(7, java.time.temporal.ChronoUnit.DAYS)
                    "premium_1_month" -> baseDate.plus(30, java.time.temporal.ChronoUnit.DAYS)
                    "premium_1_year" -> baseDate.plus(365, java.time.temporal.ChronoUnit.DAYS)
                    else -> baseDate.plus(7, java.time.temporal.ChronoUnit.DAYS)
                }
                val newStr = java.time.OffsetDateTime.ofInstant(newPremiumUntil, java.time.ZoneOffset.UTC).toString()
                
                buildJsonObject {
                    put("coin_balance", newCoins)
                    put("premium_until", newStr)
                }
            } else {
                val newSkins = wallet.unlockedSkins + item.id
                buildJsonObject {
                    put("coin_balance", newCoins)
                    put("unlocked_skins", kotlinx.serialization.json.buildJsonArray {
                        newSkins.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) }
                    })
                }
            }
            
            val patchResponse = client.patch("$supabaseUrl/rest/v1/profiles?id=eq.$userId") {
                header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                header("apikey", serviceRoleKey)
                header("Prefer", "return=minimal")
                contentType(ContentType.Application.Json)
                setBody(patchObj.toString())
            }
            
            if (patchResponse.status.value in 200..299) {
                return getWallet(userId) // Return updated wallet
            }
            logger.error("Failed to patch profile for purchase: ${patchResponse.status} ${patchResponse.bodyAsText()}")
        } catch (e: Exception) {
            logger.error("Exception in purchaseItem", e)
        }
        return null
    }

    suspend fun rewardAd(userId: String, amount: Int = 10): WalletState? {
        try {
            val wallet = getWallet(userId) ?: return null
            val newCoins = wallet.coinBalance + amount
            
            val patchObj = buildJsonObject {
                put("coin_balance", newCoins)
            }
            
            val patchResponse = client.patch("$supabaseUrl/rest/v1/profiles?id=eq.$userId") {
                header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                header("apikey", serviceRoleKey)
                header("Prefer", "return=minimal")
                contentType(ContentType.Application.Json)
                setBody(patchObj.toString())
            }
            
            if (patchResponse.status.value in 200..299) {
                return getWallet(userId)
            }
        } catch (e: Exception) {
            logger.error("Exception in rewardAd", e)
        }
        return null
    }

    // ── Match Result ─────────────────────────────────────────────────────────

    /**
     * Saves all eligible players' match results and calculates Free-For-All Elo Rank Points (RP).
     *
     * @param state The final game state containing all players and scores.
     * @param originalRealPlayerIds The players who are eligible for leaderboard updates.
     */
    suspend fun calculateEloChangesForState(state: CallbreakState, originalRealPlayerIds: Set<String>): CallbreakState {
        if (originalRealPlayerIds.size < 2) {
            return state.copy(players = state.players.map { p ->
                if (p.id in originalRealPlayerIds) {
                    val earnedRp = if (!state.isPublic && state.totalRounds < 3) 0 else 2
                    p.copy(rpChange = earnedRp)
                } else {
                    p.copy(rpChange = 0)
                }
            })
        }
        
        try {
            val idsQuery = originalRealPlayerIds.joinToString(",") { "\"$it\"" }
            val getResponse = client.get("$supabaseUrl/rest/v1/profiles?id=in.($idsQuery)&select=id,rank_points") {
                header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                header("apikey", serviceRoleKey)
            }
            
            val currentProfiles = mutableMapOf<String, kotlinx.serialization.json.JsonObject>()
            if (getResponse.status.value in 200..299) {
                val jsonArray = kotlinx.serialization.json.Json.parseToJsonElement(getResponse.bodyAsText()).jsonArray
                for (element in jsonArray) {
                    val obj = element.jsonObject
                    val id = obj["id"]?.jsonPrimitive?.content ?: continue
                    currentProfiles[id] = obj
                }
            } else {
                logger.error("❌ Failed to GET profiles for Elo calculation: ${getResponse.status} ${getResponse.bodyAsText()}")
                return state
            }
            
            val currentRps = state.players.associate { p -> 
                val rp = currentProfiles[p.id]?.get("rank_points")?.jsonPrimitive?.intOrNull ?: 1000
                p.id to rp
            }
            
            val rpChanges = com.akm.callbreak.domain.rules.EloCalculator.calculateEloChanges(state.players, currentRps)
            
            return state.copy(players = state.players.map { p ->
                val baseChange = rpChanges[p.id] ?: 0
                
                var finalChange = baseChange
                if (p.hasAbandoned) {
                    finalChange = -5
                } else {
                    if (!state.isPublic && state.totalRounds < 3) {
                        finalChange = 0
                    } else {
                        val staticBonus = if (p.rank == 1 || p.rank == 2) 2 else 1
                        finalChange += staticBonus
                        
                        if (p.rank == 1 || p.rank == 2) {
                            finalChange = maxOf(0, finalChange)
                        }

                        // Completed online game gets +4 RP flat addition
                        finalChange += 4
                    }
                }

                p.copy(
                    currentRp = currentRps[p.id] ?: 1000,
                    rpChange = finalChange
                )
            })
            
        } catch (e: Exception) {
            logger.error("❌ Error calculating Elo changes", e)
            return state
        }
    }

    suspend fun saveOfflineMatchResults(
        state: CallbreakState,
        originalRealPlayerIds: Set<PlayerId>
    ) {
        val updatedState = state.copy(players = state.players.map { p ->
            if (p.id in originalRealPlayerIds) {
                if (p.hasAbandoned) {
                    p.copy(rpChange = -2)
                } else if (state.phase != GamePhase.GAME_OVER) {
                    p.copy(rpChange = 0)
                } else {
                    p.copy(rpChange = 2)
                }
            } else {
                p.copy(rpChange = 0)
            }
        })
        saveMatchResultsWithElo(updatedState, originalRealPlayerIds, skipEloCalc = true)
    }

    suspend fun saveMatchResultsWithElo(
        state: CallbreakState,
        originalRealPlayerIds: Set<PlayerId>,
        skipEloCalc: Boolean = false
    ) {
        try {
            // 1. Fetch current profiles for real players to check existence
            val idsQuery = originalRealPlayerIds.joinToString(",") { "\"$it\"" }
            val getResponse = client.get("$supabaseUrl/rest/v1/profiles?id=in.($idsQuery)&select=id,username,total_games,total_wins,total_score,rank_points,coin_balance") {
                header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                header("apikey", serviceRoleKey)
            }
            
            val currentProfiles = mutableMapOf<String, kotlinx.serialization.json.JsonObject>()
            if (getResponse.status.value in 200..299) {
                val jsonArray = kotlinx.serialization.json.Json.parseToJsonElement(getResponse.bodyAsText()).jsonArray
                for (element in jsonArray) {
                    val obj = element.jsonObject
                    val id = obj["id"]?.jsonPrimitive?.content ?: continue
                    currentProfiles[id] = obj
                }
            } else {
                logger.error("❌ Failed to GET profiles: ${getResponse.status} ${getResponse.bodyAsText()}")
                return
            }
            
            // 2. Update Supabase for originalRealPlayerIds
            for (player in state.players) {
                if (player.id !in originalRealPlayerIds) continue
                val rpChange = player.rpChange ?: 0
                val won = if ((player.rank ?: 4) == 1) 1 else 0
                val score = player.cumulativeScore
                val rank = player.rank ?: 4
                
                val existingProfile = currentProfiles[player.id]
                if (existingProfile == null) {
                    val isGuest = player.name.lowercase().startsWith("guest") || player.name.startsWith("pending_")
                    val isValidUsername = player.name.isNotBlank() && player.name.length >= 3 && !isGuest
                    if (isValidUsername) {
                        logger.info("ℹ️ Creating new profile for ${player.id} with username ${player.name}")
                        var finalUsername = player.name
                        val coinsEarned = if (!player.hasAbandoned) {
                            if (originalRealPlayerIds.size < 2) 2 else 10
                        } else 0

                        var newProfile = buildJsonObject {
                            put("id", player.id)
                            put("username", finalUsername)
                            put("total_games", 1)
                            put("total_wins", won)
                            put("total_score", score)
                            put("rank_points", 1000 + rpChange)
                            put("coin_balance", coinsEarned)
                        }
                        var postProfileResponse = client.post("$supabaseUrl/rest/v1/profiles") {
                            header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                            header("apikey", serviceRoleKey)
                            header("Prefer", "return=minimal")
                            contentType(ContentType.Application.Json)
                            setBody(newProfile.toString())
                        }
                        
                        if (postProfileResponse.status.value == 409) {
                            finalUsername = "${player.name}_${player.id.take(4)}"
                            logger.info("ℹ️ Username ${player.name} taken, retrying with $finalUsername")
                            newProfile = buildJsonObject {
                                put("id", player.id)
                                put("username", finalUsername)
                                put("total_games", 1)
                                put("total_wins", won)
                                put("total_score", score)
                                put("rank_points", 1000 + rpChange)
                                put("coin_balance", coinsEarned)
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
                        }
                    } else {
                        logger.info("ℹ️ Skipping Supabase update for ${player.id} (No profile found and username '${player.name}' is not a valid custom name)")
                        continue
                    }
                } else {
                    // Update profile aggregate stats
                    val currentGames = existingProfile["total_games"]?.jsonPrimitive?.intOrNull ?: 0
                    val currentWins = existingProfile["total_wins"]?.jsonPrimitive?.intOrNull ?: 0
                    val currentScore = existingProfile["total_score"]?.jsonPrimitive?.doubleOrNull ?: 0.0
                    val currentRp = existingProfile["rank_points"]?.jsonPrimitive?.intOrNull ?: 1000
                    val currentCoins = existingProfile["coin_balance"]?.jsonPrimitive?.intOrNull ?: 0
                    
                    val newRp = (currentRp + rpChange).coerceAtLeast(0) // don't let RP go below 0
                    
                    val coinsEarned = if (!player.hasAbandoned) {
                        if (originalRealPlayerIds.size < 2) 2 else 10
                    } else 0
                    val newCoins = currentCoins + coinsEarned
                    
                    val profilePatch = buildJsonObject {
                        put("total_games", currentGames + 1)
                        put("total_wins", currentWins + won)
                        put("total_score", currentScore + score)
                        put("rank_points", newRp)
                        put("coin_balance", newCoins)
                    }
                    
                    val patchResponse = client.patch("$supabaseUrl/rest/v1/profiles?id=eq.${player.id}") {
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
                
                // Insert match result row
                val body = buildJsonObject {
                    put("user_id", player.id)
                    put("room_id", state.roomId)
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
                
                logger.info("✅ Finished Supabase update for user ${player.id} (rank=$rank, score=$score, rpChange=${if(rpChange >= 0) "+$rpChange" else rpChange})")
            }
        } catch (e: Exception) {
            logger.error("❌ Exception during saveMatchResultsWithElo: ${e.message}", e)
        }
    }

    /**
     * Saves the full match scorecard to Supabase for the history view.
     */
    suspend fun saveMatchScorecard(state: CallbreakState, originalRealPlayerIds: Set<PlayerId>) {
        try {
            // 1. Insert into match_scorecards
            val participantsJson = buildJsonArray {
                for (p in state.players) {
                    add(buildJsonObject {
                        put("id", p.id)
                        put("name", p.name)
                        put("is_bot", p.isBot)
                        put("total_score", p.cumulativeScore)
                        put("rank", p.rank ?: 4)
                    })
                }
            }
            
            val roundScoresJson = buildJsonArray {
                for (rs in state.roundScores) {
                    add(buildJsonObject {
                        for ((pid, score) in rs) {
                            put(pid, score)
                        }
                    })
                }
            }

            val scorecardBody = buildJsonObject {
                put("room_id", state.roomId)
                put("participants", participantsJson)
                put("round_scores", roundScoresJson)
            }

            val postScorecardResponse = client.post("$supabaseUrl/rest/v1/match_scorecards") {
                header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                header("apikey", serviceRoleKey)
                header("Prefer", "return=representation") // So we get the ID back
                contentType(ContentType.Application.Json)
                setBody(scorecardBody.toString())
            }

            if (postScorecardResponse.status.value !in 200..299) {
                logger.error("❌ Failed to POST match_scorecards: ${postScorecardResponse.status} ${postScorecardResponse.bodyAsText()}")
                return
            }

            // Extract the generated match_id
            val scorecardResponseText = postScorecardResponse.bodyAsText()
            val scorecardJsonArray = kotlinx.serialization.json.Json.parseToJsonElement(scorecardResponseText).jsonArray
            if (scorecardJsonArray.isEmpty()) return
            val matchId = scorecardJsonArray[0].jsonObject["id"]?.jsonPrimitive?.content ?: return

            // 2. Insert into user_match_records for real players
            val userRecordsBody = buildJsonArray {
                for (playerId in originalRealPlayerIds) {
                    add(buildJsonObject {
                        put("user_id", playerId)
                        put("match_id", matchId)
                    })
                }
            }

            if (userRecordsBody.isEmpty()) return

            val postUserRecordsResponse = client.post("$supabaseUrl/rest/v1/user_match_records") {
                header(HttpHeaders.Authorization, "Bearer $serviceRoleKey")
                header("apikey", serviceRoleKey)
                header("Prefer", "return=minimal")
                contentType(ContentType.Application.Json)
                setBody(userRecordsBody.toString())
            }

            if (postUserRecordsResponse.status.value !in 200..299) {
                logger.error("❌ Failed to POST user_match_records: ${postUserRecordsResponse.status} ${postUserRecordsResponse.bodyAsText()}")
            } else {
                logger.info("✅ Saved full match scorecard for room ${state.roomId}")
            }

        } catch (e: Exception) {
            logger.error("❌ Exception during saveMatchScorecard for room ${state.roomId}: ${e.message}")
        }
    }
}
