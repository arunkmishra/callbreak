package com.callbreak.domain.rules

import com.callbreak.domain.models.*

/**
 * Calculates a bot's bid based on their hand.
 *
 * Rules:
 * 1. Base bid = 1.
 * 2. For Spades (Trump): Add 1 for the Ace, add 1 for the King, add 1 for the Queen.
 * 3. For Other Suits: Add 1 for each Ace.
 */
fun calculateBotBid(hand: List<PlayingCard>, minBid: Int? = null): Int {
    var bid = 1
    for (card in hand) {
        if (card.suit == Suit.SPADE) {
            if (card.rank == Rank.ACE || card.rank == Rank.KING || card.rank == Rank.QUEEN) {
                bid += 1
            }
        } else {
            if (card.rank == Rank.ACE) {
                bid += 1
            }
        }
    }
    return maxOf(bid, minBid ?: 1)
}

/**
 * Selects a card for the bot to play.
 *
 * Rules:
 * 1. Get legal moves: Filter hand using [validateMove].
 * 2. Leading the trick: Play the highest available non-spade. If only Spades, play the lowest Spade.
 * 3. Following (cards on table):
 *    - Divide legalCards into winningCards (which currently win the trick if played) and losingCards.
 *    - If winningCards not empty -> play the lowest ranked card inside winningCards.
 *    - If winningCards empty -> play the lowest ranked card inside losingCards.
 */
fun selectBotCard(state: CallbreakState, botId: PlayerId): PlayingCard {
    val hand = state.hands[botId] ?: emptyList()

    // Step 1: Filter hand for strictly legal moves
    val legalCards = hand.filter { card ->
        validateMove(state, botId, card).isSuccess
    }

    if (legalCards.isEmpty()) {
        // Fallback: if validateMove somehow fails to return anything, play first card in hand
        return hand.firstOrNull() ?: throw Exception("Bot has no cards to play")
    }

    val trick = state.currentTrick

    // Step 2: Leading the Trick (Table is empty)
    if (trick.cards.isEmpty()) {
        val nonSpades = legalCards.filter { it.suit != Suit.SPADE }
        return if (nonSpades.isNotEmpty()) {
            nonSpades.maxByOrNull { it.rank.value }!!
        } else {
            legalCards.filter { it.suit == Suit.SPADE }.minByOrNull { it.rank.value }!!
        }
    }

    // Step 3: Following (Cards are on the table)
    val winningCards = mutableListOf<PlayingCard>()
    val losingCards = mutableListOf<PlayingCard>()

    for (card in legalCards) {
        // Simulate playing this card by creating a temporary trick
        val simulatedTrick = trick.copy(cards = trick.cards + TrickCard(botId, card))
        val winner = evaluateTrickWinner(simulatedTrick)
        if (winner == botId) {
            winningCards.add(card)
        } else {
            losingCards.add(card)
        }
    }

    return if (winningCards.isNotEmpty()) {
        winningCards.minByOrNull { it.rank.value }!!
    } else {
        losingCards.minByOrNull { it.rank.value }!!
    }
}
