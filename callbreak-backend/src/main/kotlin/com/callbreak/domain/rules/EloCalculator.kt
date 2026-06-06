package com.callbreak.domain.rules

import com.callbreak.domain.models.Player
import kotlin.math.pow

object EloCalculator {
    /**
     * Calculates the Free-For-All (FFA) Elo Rank Points (RP) changes for a match.
     * 
     * @param players The list of players in the match. Their `rank` property must be populated.
     * @param currentRps A map of playerId to their current Rank Points before the match.
     * @return A map of playerId to the calculated RP change (can be positive or negative).
     */
    fun calculateEloChanges(
        players: List<Player>,
        currentRps: Map<String, Int>
    ): Map<String, Int> {
        val kFactor = 16.0
        val rpChanges = mutableMapOf<String, Int>()

        for (p1 in players) {
            val rp1 = currentRps[p1.id] ?: 1000
            var p1Change = 0.0
            
            for (p2 in players) {
                if (p1.id == p2.id) continue
                
                val rp2 = currentRps[p2.id] ?: 1000
                val expectedScore = 1.0 / (1.0 + 10.0.pow((rp2 - rp1) / 400.0))
                
                val p1Rank = p1.rank ?: 4
                val p2Rank = p2.rank ?: 4
                
                val actualScore = when {
                    p1Rank < p2Rank -> 1.0
                    p1Rank == p2Rank -> 0.5
                    else -> 0.0
                }
                
                p1Change += kFactor * (actualScore - expectedScore)
            }
            rpChanges[p1.id] = p1Change.toInt()
        }

        return rpChanges
    }
}
