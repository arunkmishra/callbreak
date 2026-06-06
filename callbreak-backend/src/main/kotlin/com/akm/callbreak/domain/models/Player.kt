package com.akm.callbreak.domain.models

import kotlinx.serialization.Serializable

typealias PlayerId = String

/**
 * Represents a player in the game room.
 *
 * @param id       Unique player identifier (UUID), stable for the session.
 * @param name     Display name chosen at room creation/joining.
 * @param bid      Number of tricks the player has bid. Null during LOBBY phase.
 * @param tricksWon Number of tricks won in the current round.
 * @param cardCount Number of cards remaining in the player's hand (visible to all).
 */
@Serializable
data class Player(
    val id: PlayerId,
    val name: String,
    val bid: Int? = null,
    val tricksWon: Int = 0,
    val cardCount: Int = 0,
    val cumulativeScore: Double = 0.0,
    val isOnline: Boolean = true,
    val isBot: Boolean = false,
    val rank: Int? = null,
    val consecutiveBotMoves: Int = 0,
    val currentRp: Int? = null,
    val rpChange: Int? = null,
)
