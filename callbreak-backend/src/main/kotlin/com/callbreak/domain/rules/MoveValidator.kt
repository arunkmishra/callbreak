package com.callbreak.domain.rules

import com.callbreak.domain.models.CallbreakState
import com.callbreak.domain.models.GamePhase
import com.callbreak.domain.models.PlayerId
import com.callbreak.domain.models.PlayingCard
import com.callbreak.domain.models.Suit

/**
 * Thrown when a player attempts an illegal move.
 */
class IllegalMoveException(message: String) : Exception(message)

/**
 * Validates a card play against the full game state.
 *
 * Rules enforced (in order):
 * 1. Game must be in PLAYING phase.
 * 2. It must be [playerId]'s turn.
 * 3. The [card] must be in the player's hand.
 * 4. If not leading (trick already has cards):
 *    a. Player MUST follow the led suit if they have any card of that suit.
 *    b. If void in led suit, player MAY play any card (including trump).
 * 5. No restriction on when Spades can be led (unlike some variants).
 *
 * @param state    The current immutable game state.
 * @param playerId The player attempting to play.
 * @param card     The card they wish to play.
 * @return [Result.success] with Unit on a legal move,
 *         [Result.failure] wrapping [IllegalMoveException] on an illegal move.
 */
fun validateMove(
    state: CallbreakState,
    playerId: PlayerId,
    card: PlayingCard,
): Result<Unit> {
    // Rule 1: Correct phase
    if (state.phase != GamePhase.PLAYING) {
        return Result.failure(IllegalMoveException("Game is not in PLAYING phase (current: ${state.phase})"))
    }

    // Rule 2: Correct turn
    if (state.currentTurn != playerId) {
        return Result.failure(IllegalMoveException("It is not $playerId's turn (current: ${state.currentTurn})"))
    }

    // Rule 3: Card must be in hand
    val hand = state.hands[playerId] ?: emptyList()
    if (card !in hand) {
        return Result.failure(IllegalMoveException("Card $card is not in $playerId's hand"))
    }

    // Rule 4: Strict traditional validation (only when trick already has cards)
    val trick = state.currentTrick
    if (trick.cards.isNotEmpty()) {
        val ledSuit: Suit = trick.ledSuit
            ?: trick.cards.first().card.suit // fallback (should never be null in PLAYING)
        val trump = state.currentTrumpSuit

        // Determine current winning card of the trick
        val trumpCards = trick.cards.filter { it.card.suit == trump }
        val winningCard = if (trumpCards.isNotEmpty()) {
            trumpCards.maxByOrNull { it.card.rank.value }!!.card
        } else {
            val ledSuitCards = trick.cards.filter { it.card.suit == ledSuit }
            ledSuitCards.maxByOrNull { it.card.rank.value }!!.card
        }

        val hasLedSuit = hand.any { it.suit == ledSuit }
        if (hasLedSuit) {
            if (card.suit != ledSuit) {
                return Result.failure(
                    IllegalMoveException(
                        "Must follow led suit (${ledSuit.displayName}). " +
                            "Attempted to play ${card.suit.displayName}."
                    )
                )
            }
            val hasBeatingLed = hand.any { it.suit == ledSuit && winningCard.suit == ledSuit && it.rank.value > winningCard.rank.value }
            if (hasBeatingLed && card.rank.value <= winningCard.rank.value) {
                return Result.failure(
                    IllegalMoveException(
                        "Must play a card of the led suit (${ledSuit.displayName}) that beats the current winning card."
                    )
                )
            }
        } else {
            val hasTrump = hand.any { it.suit == trump }
            val hasBeatingTrump = hand.any { it.suit == trump && (winningCard.suit != trump || it.rank.value > winningCard.rank.value) }
            
            if (hasBeatingTrump) {
                if (card.suit != trump || (winningCard.suit == trump && card.rank.value <= winningCard.rank.value)) {
                    return Result.failure(
                        IllegalMoveException(
                            "Must play a ${trump?.displayName ?: "Spade"} that beats the current winning card."
                        )
                    )
                }
            }
        }
    }

    return Result.success(Unit)
}
