package com.akm.callbreak.services

import com.akm.callbreak.domain.models.CallbreakState
import com.akm.callbreak.domain.models.GamePhase
import com.akm.callbreak.domain.models.Player
import com.akm.callbreak.room.GameRoomManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.slf4j.LoggerFactory
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

private val logger = LoggerFactory.getLogger("MatchmakingService")

/**
 * Handles "shadow bot" backfill for public matchmaking rooms.
 *
 * When a public room is created and doesn't fill with real players fast enough,
 * this service stagers bot joins at random intervals to simulate real players
 * joining, then auto-starts the game.
 */
object MatchmakingService {

    /** Realistic human display names for shadow bots. */
    private val SHADOW_NAMES = listOf(
        "Guest_8492", "RahulK", "CardMaster99", "Aisha", "Priya_M", "DeckSlayer",
        "Guest_1037", "Ankit22", "SnehaP", "TrickKing", "NovaCB", "Ravi_S",
        "Guest_5541", "MeghaR", "SpadeHunter", "Karan77", "Guest_3390", "Divya_K",
        "AceUp", "Guest_7218", "Sameer_B", "Nisha99", "CallPro", "Guest_4455",
        "Vikram_J", "Pooja_L", "WildCard", "Guest_6103", "Deepak_N", "Simran_T"
    )

    /** Active backfill jobs, keyed by roomId. Cancel-safe. */
    private val activeJobs = ConcurrentHashMap<String, Job>()

    /**
     * Starts the staggered shadow-bot backfill coroutine for [roomId].
     *
     * The total fill window is randomised between 40–75 seconds.
     * Within that window, each needed bot is scheduled at a random offset
     * (roughly 30%, 60%, 85% of the fill time) so joins look organic.
     */
    fun startBackfill(roomId: String) {
        val job = CoroutineScope(Dispatchers.Default).launch {
            val totalFillMs = (40_000L..75_000L).random()
            logger.info("🎯 [Room $roomId] Backfill started — fill window ${totalFillMs / 1000}s")

            // Schedule up to 3 bot joins at staggered times
            val joinFractions = listOf(0.30, 0.60, 0.85)

            for (fraction in joinFractions) {
                val targetDelay = (totalFillMs * fraction).toLong() + (-3000L..3000L).random()
                val clampedDelay = targetDelay.coerceIn(5000L, totalFillMs - 2000L)
                delay(clampedDelay)

                val room = GameRoomManager.getRoom(roomId)
                if (room == null) {
                    logger.info("🚫 [Room $roomId] Room gone — stopping backfill")
                    break
                }

                val state = room.getState()
                if (state.phase != GamePhase.LOBBY) {
                    logger.info("🚫 [Room $roomId] Game already started — stopping backfill")
                    break
                }

                val seatsNeeded = CallbreakState.PLAYERS_REQUIRED - state.players.size
                if (seatsNeeded <= 0) {
                    logger.info("✅ [Room $roomId] Room full — stopping backfill")
                    break
                }

                // Pick a unique name not already in the room
                val usedNames = state.players.map { it.name }.toSet()
                val botName = SHADOW_NAMES
                    .filter { it !in usedNames }
                    .randomOrNull() ?: "Guest_${(1000..9999).random()}"

                val botId = "shadow_${UUID.randomUUID()}"
                val shadowBot = Player(
                    id = botId,
                    name = botName,
                    isBot = true,
                    isOnline = true
                )

                room.addPlayer(shadowBot)
                room.registerSessionToken(botId, "shadow-token-$botId")
                logger.info("🤖 [Room $roomId] Shadow bot '$botName' ($botId) joined — ${state.players.size + 1}/${CallbreakState.PLAYERS_REQUIRED}")

                // Check if room is now full and auto-start
                val updatedState = room.getState()
                if (updatedState.players.size >= CallbreakState.PLAYERS_REQUIRED) {
                    logger.info("🚀 [Room $roomId] Room full after shadow bot join — auto-starting in 3s")
                    delay(3000)
                    room.startGame()
                    break
                }
            }

            // Final check: if room still isn't full after all scheduled joins,
            // dump remaining bots and start
            val finalRoom = GameRoomManager.getRoom(roomId)
            if (finalRoom != null) {
                val finalState = finalRoom.getState()
                if (finalState.phase == GamePhase.LOBBY) {
                    val remaining = CallbreakState.PLAYERS_REQUIRED - finalState.players.size
                    if (remaining > 0) {
                        logger.info("⏰ [Room $roomId] Fill window expired — adding $remaining remaining bot(s)")
                        val usedNames = finalState.players.map { it.name }.toMutableSet()
                        for (i in 1..remaining) {
                            val botName = SHADOW_NAMES
                                .filter { it !in usedNames }
                                .randomOrNull() ?: "Guest_${(1000..9999).random()}"
                            usedNames.add(botName)

                            val botId = "shadow_${UUID.randomUUID()}"
                            val bot = Player(
                                id = botId,
                                name = botName,
                                isBot = true,
                                isOnline = true
                            )
                            finalRoom.addPlayer(bot)
                            finalRoom.registerSessionToken(botId, "shadow-token-$botId")
                            logger.info("🤖 [Room $roomId] Final shadow bot '$botName' ($botId) added")
                            delay((1500L..3000L).random()) // Small stagger even at the end
                        }

                        delay(3000)
                        logger.info("🚀 [Room $roomId] Auto-starting game after backfill")
                        finalRoom.startGame()
                    }
                }
            }

            activeJobs.remove(roomId)
        }
        activeJobs[roomId] = job
    }

    /** Cancels backfill for a room (e.g. if room is destroyed). */
    fun cancelBackfill(roomId: String) {
        activeJobs.remove(roomId)?.cancel()
        logger.info("❌ [Room $roomId] Backfill cancelled")
    }
}
