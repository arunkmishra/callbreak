package com.akm.callbreak.domain.rules

import com.akm.callbreak.domain.models.CallbreakState
import com.akm.callbreak.domain.models.CurrentTrick
import com.akm.callbreak.domain.models.GamePhase

/**
 * Resolves the round scoring and transitions the game phase.
 * Called when the 13th trick of a round is completed.
 *
 * Rules:
 * - Calculate score changes for each player:
 *   - tricksWon >= bid: score += bid + (tricksWon - bid) * 0.1
 *   - tricksWon < bid:  score -= bid
 * - Update cumulativeScore for each player.
 * - Transition phase:
 *   - If currentRound < totalRounds -> transition to ROUND_OVER.
 *   - If currentRound == totalRounds -> transition to GAME_OVER and sort players by cumulativeScore descending.
 */
fun resolveRound(state: CallbreakState): CallbreakState {
    val updatedPlayers = state.players.map { player ->
        val bid = state.bids[player.id] ?: player.bid ?: 0
        val tricks = state.tricksWon[player.id] ?: player.tricksWon

        val pointsGained = if (state.allowCustomTrump && (bid == 2 || bid == 3) && tricks >= bid * 2) {
            0.0 // Strict over-trick penalty
        } else if (state.greedPenalty && tricks >= bid * 2) {
            0.0
        } else if (tricks >= bid) {
            bid.toDouble() + ((tricks - bid) * 0.1)
        } else {
            -bid.toDouble()
        }

        val newCumulativeScore = player.cumulativeScore + pointsGained

        player.copy(
            bid = bid,
            tricksWon = tricks,
            cumulativeScore = newCumulativeScore
        )
    }

    val isGameOver = state.currentRound >= state.totalRounds
    val nextPhase = if (isGameOver) GamePhase.GAME_OVER else GamePhase.ROUND_OVER

    // Determine ranks by sorting players temporarily to find their standing
    val sortedByScore = updatedPlayers.sortedByDescending { it.cumulativeScore }
    val finalPlayers = updatedPlayers.map { player ->
        val rank = sortedByScore.indexOfFirst { it.id == player.id } + 1
        player.copy(rank = rank)
    }

    val updatedScores = finalPlayers.associate { it.id to it.cumulativeScore }

    val currentRoundScore = finalPlayers.associate { player ->
        val bid = state.bids[player.id] ?: player.bid ?: 0
        val tricks = state.tricksWon[player.id] ?: player.tricksWon
        val pointsGained = if (state.allowCustomTrump && (bid == 2 || bid == 3) && tricks >= bid * 2) {
            0.0 // Strict over-trick penalty
        } else if (state.greedPenalty && tricks >= bid * 2) {
            0.0
        } else if (tricks >= bid) {
            bid.toDouble() + ((tricks - bid) * 0.1)
        } else {
            -bid.toDouble()
        }
        player.id to pointsGained
    }
    
    val newRoundScores = state.roundScores + currentRoundScore

    return state.copy(
        phase = nextPhase,
        players = finalPlayers,
        scores = updatedScores,
        roundScores = newRoundScores,
        currentTurn = null,
        currentTrick = CurrentTrick()
    )
}
