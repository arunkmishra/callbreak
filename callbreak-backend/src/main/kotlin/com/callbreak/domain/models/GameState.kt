package com.callbreak.domain.models

import kotlinx.serialization.Serializable

/**
 * The phases a Callbreak game room moves through in order.
 *
 * LOBBY      → Players joining; host can start when 4 players present.
 * BIDDING    → Each player declares how many tricks they will win.
 * PLAYING    → Trick-taking gameplay; Spades are always trump.
 * ROUND_OVER → Scores tallied; host can start the next round.
 */
@Serializable
enum class GamePhase {
    LOBBY,
    DEALING_PHASE_1,
    TRUMP_BIDDING,
    DEALING_PHASE_2,
    REGULAR_BIDDING,
    PLAYING,
    ROUND_OVER,
    GAME_OVER
}

/**
 * State of the trump bidding phase in Custom Mode.
 */
@Serializable
data class TrumpBidState(
    val highestBid: Int = 0,
    val highestBidderId: PlayerId? = null,
    val proposedSuit: Suit? = null,
    val playersPassed: List<PlayerId> = emptyList()
)

/**
 * A single card played to the current trick, paired with who played it.
 */
@Serializable
data class TrickCard(
    val playerId: PlayerId,
    val card: PlayingCard,
)

/**
 * The current trick in progress.
 *
 * @param ledSuit The suit of the first card played (null when trick is empty).
 * @param cards   Cards played so far, in play order (max 4).
 */
@Serializable
data class CurrentTrick(
    val ledSuit: Suit? = null,
    val cards: List<TrickCard> = emptyList(),
)

/**
 * The canonical, immutable server-side state of a Callbreak room.
 *
 * [hands] is NEVER sent to clients directly. Each client receives only their
 * own hand via [GameStateDto], derived from this state.
 *
 * @param roomId       Unique 5-letter uppercase room code.
 * @param phase        Current lifecycle phase.
 * @param players      All players in seat order (index 0 = first to deal).
 * @param hands        Full hands — server-only; key = playerId.
 * @param bids         Bids submitted this round; key = playerId.
 * @param tricksWon    Tricks won this round; key = playerId.
 * @param scores       Cumulative score across all rounds; key = playerId.
 * @param currentTurn  PlayerId whose turn it is (null between tricks/rounds).
 * @param currentTrick Cards played so far in the active trick.
 * @param currentRound Current round (1-indexed, max = [totalRounds]).
 * @param totalRounds  Total number of rounds for this match.
 * @param dealerIndex  Index into [players] for the current dealer (rotates each round).
 */
@Serializable
data class CallbreakState(
    val roomId: String,
    val phase: GamePhase = GamePhase.LOBBY,
    val players: List<Player> = emptyList(),
    val hands: Map<PlayerId, List<PlayingCard>> = emptyMap(),
    val bids: Map<PlayerId, Int> = emptyMap(),
    val tricksWon: Map<PlayerId, Int> = emptyMap(),
    val scores: Map<PlayerId, Double> = emptyMap(),
    val currentTurn: PlayerId? = null,
    val currentTrick: CurrentTrick = CurrentTrick(),
    val currentRound: Int = 1,
    val totalRounds: Int = 5,
    val dealerIndex: Int = 0,
    val minBid: Int? = null,
    val greedPenalty: Boolean = false,
    val allowCustomTrump: Boolean = false,
    val currentTrumpSuit: Suit = Suit.SPADE,
    val trumpBidState: TrumpBidState = TrumpBidState(),
    val deck: List<PlayingCard> = emptyList(),
    val roundScores: List<Map<PlayerId, Double>> = emptyList(),
) {
    companion object {
        const val PLAYERS_REQUIRED = 4
        const val CARDS_PER_HAND = 13
    }
}
