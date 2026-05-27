package com.callbreak.domain.rules

import com.callbreak.domain.models.*
import kotlin.test.Test
import kotlin.test.assertEquals

class RoundResolverTest {

    private val player1 = "player-1"
    private val player2 = "player-2"
    private val player3 = "player-3"
    private val player4 = "player-4"

    private fun createBaseState(
        currentRound: Int = 1,
        totalRounds: Int = 5,
        players: List<Player> = listOf(
            Player(player1, "Alice", cumulativeScore = 0.0),
            Player(player2, "Bob", cumulativeScore = 1.5),
            Player(player3, "Charlie", cumulativeScore = -2.0),
            Player(player4, "Dave", cumulativeScore = 3.0)
        ),
        bids: Map<PlayerId, Int> = mapOf(
            player1 to 3,
            player2 to 2,
            player3 to 4,
            player4 to 1
        ),
        tricksWon: Map<PlayerId, Int> = mapOf(
            player1 to 4,  // met (overtricks) -> score = 3 + 1 * 0.1 = 3.1
            player2 to 2,  // met (exact)      -> score = 2.0
            player3 to 2,  // missed          -> score = -4.0
            player4 to 3   // met (overtricks) -> score = 1 + 2 * 0.1 = 1.2
        )
    ): CallbreakState {
        return CallbreakState(
            roomId = "TEST1",
            phase = GamePhase.PLAYING,
            players = players,
            bids = bids,
            tricksWon = tricksWon,
            currentRound = currentRound,
            totalRounds = totalRounds
        )
    }

    @Test
    fun testScoreCalculationAndRoundOver() {
        val state = createBaseState(currentRound = 1, totalRounds = 3)
        val resolved = resolveRound(state)

        assertEquals(GamePhase.ROUND_OVER, resolved.phase)

        val p1 = resolved.players.first { it.id == player1 }
        val p2 = resolved.players.first { it.id == player2 }
        val p3 = resolved.players.first { it.id == player3 }
        val p4 = resolved.players.first { it.id == player4 }

        // Expected cumulative scores:
        // Alice: 0.0 + 3.1 = 3.1
        // Bob: 1.5 + 2.0 = 3.5
        // Charlie: -2.0 - 4.0 = -6.0
        // Dave: 3.0 + 1.2 = 4.2
        assertEquals(3.1, p1.cumulativeScore)
        assertEquals(3.5, p2.cumulativeScore)
        assertEquals(-6.0, p3.cumulativeScore)
        assertEquals(4.2, p4.cumulativeScore)

        // Verify score map in state is also correct
        assertEquals(3.1, resolved.scores[player1])
        assertEquals(3.5, resolved.scores[player2])
        assertEquals(-6.0, resolved.scores[player3])
        assertEquals(4.2, resolved.scores[player4])
    }

    @Test
    fun testGameOverTransitionAndSorting() {
        val state = createBaseState(currentRound = 3, totalRounds = 3)
        val resolved = resolveRound(state)

        assertEquals(GamePhase.GAME_OVER, resolved.phase)

        // Expected order matches join order (player1, player2, player3, player4)
        assertEquals(4, resolved.players.size)
        assertEquals(player1, resolved.players[0].id) // Alice
        assertEquals(player2, resolved.players[1].id) // Bob
        assertEquals(player3, resolved.players[2].id) // Charlie
        assertEquals(player4, resolved.players[3].id) // Dave

        // Expected cumulative scores:
        // Alice: 3.1
        // Bob: 3.5
        // Charlie: -6.0
        // Dave: 4.2
        assertEquals(3.1, resolved.players[0].cumulativeScore)
        assertEquals(3.5, resolved.players[1].cumulativeScore)
        assertEquals(-6.0, resolved.players[2].cumulativeScore)
        assertEquals(4.2, resolved.players[3].cumulativeScore)

        // Expected ranks:
        // Alice: rank 3
        // Bob: rank 2
        // Charlie: rank 4
        // Dave: rank 1
        assertEquals(3, resolved.players[0].rank)
        assertEquals(2, resolved.players[1].rank)
        assertEquals(4, resolved.players[2].rank)
        assertEquals(1, resolved.players[3].rank)
    }
}
