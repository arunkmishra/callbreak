package com.callbreak.api.ws

import com.callbreak.domain.models.GamePhase
import com.callbreak.domain.models.PlayerId
import com.callbreak.domain.models.PlayingCard
import com.callbreak.domain.models.Suit
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Messages sent FROM the server TO a client over WebSocket.
 */
@Serializable
sealed interface ServerMessage {

    /**
     * Full game state update broadcast to all players after any state change.
     * Each player receives a version with [GameStateDto.myHand] populated only for them.
     */
    @Serializable
    @SerialName("STATE_UPDATE")
    data class StateUpdate(val state: GameStateDto) : ServerMessage

    /** Sent when a client action is rejected (e.g., illegal move, wrong phase). */
    @Serializable
    @SerialName("ERROR")
    data class Error(val reason: String) : ServerMessage
}

// ─── DTO types (sent to clients, hand-filtered per player) ──────────────────

/**
 * Client-facing representation of the game state.
 * Derived from [com.callbreak.domain.models.CallbreakState] by projecting
 * each player's private hand into [myHand].
 */
@Serializable
data class GameStateDto(
    val roomId: String,
    val phase: GamePhase,
    val players: List<PlayerDto>,
    /** Only the receiving player's own cards. Empty for opponents' views. */
    val myHand: List<PlayingCard>,
    val currentTurn: PlayerId?,
    val currentTrick: CurrentTrickDto,
    val scores: Map<PlayerId, Double>,
    val currentRound: Int,
    val totalRounds: Int,
    val minBid: Int?,
    val greedPenalty: Boolean,
    val allowCustomTrump: Boolean,
    val currentTrumpSuit: Suit?,
    val trumpBidState: com.callbreak.domain.models.TrumpBidState?,
    val roundScores: List<Map<PlayerId, Double>>,
    val turnEndTime: Long?,
)

@Serializable
data class PlayerDto(
    val id: PlayerId,
    val name: String,
    val bid: Int?,
    val tricksWon: Int,
    /** How many cards remain in this player's hand (visible to all). */
    val cardCount: Int,
    val cumulativeScore: Double,
    val isOnline: Boolean,
    val isBot: Boolean,
    val rank: Int?,
    val currentRp: Int? = null,
    val rpChange: Int? = null,
)

@Serializable
data class CurrentTrickDto(
    val ledSuit: Suit?,
    val cards: List<TrickCardDto>,
)

@Serializable
data class TrickCardDto(
    val playerId: PlayerId,
    val card: PlayingCard,
)
