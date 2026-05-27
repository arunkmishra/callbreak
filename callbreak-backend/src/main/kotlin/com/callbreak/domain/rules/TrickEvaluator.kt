package com.callbreak.domain.rules

import com.callbreak.domain.models.CurrentTrick
import com.callbreak.domain.models.PlayerId
import com.callbreak.domain.models.Suit

/**
 * Determines the winner of a completed trick.
 *
 * Rules (standard Callbreak):
 * 1. Spades (trump) beat all other suits.
 * 2. If any Spades were played, the highest Spade wins.
 * 3. Otherwise, the highest card of the led suit wins.
 * 4. Cards of non-led, non-trump suits have no winning power.
 *
 * @param trick A trick containing 1–4 [TrickCard]s. Returns null if empty.
 * @return The [PlayerId] of the winning player, or null if [trick] is empty.
 */
fun evaluateTrickWinner(trick: CurrentTrick): PlayerId? {
    if (trick.cards.isEmpty()) return null

    val ledSuit = trick.ledSuit ?: trick.cards.first().card.suit
    val trump = Suit.SPADE

    // Separate trump cards from led-suit cards
    val trumpCards = trick.cards.filter { it.card.suit == trump }
    val ledSuitCards = trick.cards.filter { it.card.suit == ledSuit }

    return if (trumpCards.isNotEmpty()) {
        // Highest trump wins
        trumpCards.maxByOrNull { it.card.rank.value }?.playerId
    } else {
        // Highest card of the led suit wins
        ledSuitCards.maxByOrNull { it.card.rank.value }?.playerId
    }
}
