package com.akm.callbreak.domain.rules

import com.akm.callbreak.domain.models.Player
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class EloCalculatorTest {

    @Test
    fun `test Elo calculation for equal rank points`() {
        // 4 players, all 1000 RP. 
        // P1: rank 1, P2: rank 2, P3: rank 3, P4: rank 4
        val players = listOf(
            Player(id = "p1", name = "P1", rank = 1, isOnline = true),
            Player(id = "p2", name = "P2", rank = 2, isOnline = true),
            Player(id = "p3", name = "P3", rank = 3, isOnline = true),
            Player(id = "p4", name = "P4", rank = 4, isOnline = true)
        )
        val currentRps = mapOf(
            "p1" to 1000,
            "p2" to 1000,
            "p3" to 1000,
            "p4" to 1000
        )

        val changes = EloCalculator.calculateEloChanges(players, currentRps)
        
        // P1 beats 3 players. Expected score vs each is 0.5. Actual score vs each is 1.0. 
        // change = 16 * 3 * (1 - 0.5) = +24
        assertEquals(24, changes["p1"])
        
        // P2 beats 2, loses 1. Actual vs 3 players = 2.0. Expected = 1.5. 
        // change = 16 * (2.0 - 1.5) = +8
        assertEquals(8, changes["p2"])

        // P3 beats 1, loses 2. Actual = 1.0. Expected = 1.5.
        // change = 16 * (1.0 - 1.5) = -8
        assertEquals(-8, changes["p3"])

        // P4 loses 3. Actual = 0.0. Expected = 1.5.
        // change = 16 * (0.0 - 1.5) = -24
        assertEquals(-24, changes["p4"])
    }

    @Test
    fun `test Elo calculation with high RP player losing to low RP player`() {
        val players = listOf(
            Player(id = "bronze", name = "Bronze", rank = 1, isOnline = true),
            Player(id = "diamond", name = "Diamond", rank = 4, isOnline = true),
            Player(id = "gold1", name = "Gold1", rank = 2, isOnline = true),
            Player(id = "gold2", name = "Gold2", rank = 3, isOnline = true)
        )
        val currentRps = mapOf(
            "bronze" to 1000,
            "diamond" to 1900,
            "gold1" to 1500,
            "gold2" to 1500
        )

        val changes = EloCalculator.calculateEloChanges(players, currentRps)

        // Bronze won against everyone, including Diamond. They should gain massive RP.
        assertTrue(changes["bronze"]!! > 35)

        // Diamond lost to everyone, including Bronze. They should lose massive RP.
        assertTrue(changes["diamond"]!! < -35)
    }

    @Test
    fun `test Elo calculation with ties`() {
        val players = listOf(
            Player(id = "p1", name = "P1", rank = 1, isOnline = true),
            Player(id = "p2", name = "P2", rank = 1, isOnline = true),
            Player(id = "p3", name = "P3", rank = 3, isOnline = true),
            Player(id = "p4", name = "P4", rank = 4, isOnline = true)
        )
        val currentRps = mapOf("p1" to 1000, "p2" to 1000, "p3" to 1000, "p4" to 1000)

        val changes = EloCalculator.calculateEloChanges(players, currentRps)

        // P1 vs P2: tie (0.5 actual, 0.5 expected -> 0 change)
        // P1 vs P3, P4: win (1 actual, 0.5 expected -> 0.5 * 16 = 8 change each)
        // Total P1 change: 16
        assertEquals(16, changes["p1"])
        assertEquals(16, changes["p2"])
    }
}
