package com.callbreak.domain.rules

import com.callbreak.domain.models.*

/**
 * Handles the initial deal for either classic or custom mode.
 */
fun startDealPhase1(state: CallbreakState, shuffledDeck: List<PlayingCard>): CallbreakState {
    if (!state.allowCustomTrump) {
        // Classic mode: Deal all 13 cards immediately
        return startClassicDeal(state, shuffledDeck)
    }

    // Custom mode Phase 1: Deal 5 cards each
    val hands = state.players.mapIndexed { index, player ->
        player.id to shuffledDeck.subList(index * 5, (index + 1) * 5)
    }.toMap()

    val firstBidder = state.players[(state.dealerIndex + state.players.size - 1) % state.players.size].id

    return state.copy(
        phase = GamePhase.TRUMP_BIDDING,
        hands = hands,
        currentTurn = firstBidder,
        trumpBidState = TrumpBidState(),
        currentTrumpSuit = Suit.SPADE,
        bids = emptyMap(),
        tricksWon = state.players.associate { it.id to 0 },
        players = state.players.map { it.copy(bid = null, tricksWon = 0, cardCount = 5) },
        deck = shuffledDeck // Store the deck for Phase 2
    )
}

/**
 * Handles the second deal (remaining 8 cards) after Trump Bidding concludes.
 */
fun startDealPhase2(state: CallbreakState): CallbreakState {
    val hands = state.hands.toMutableMap()
    val startingIndex = 20 // 4 players * 5 cards already dealt
    
    state.players.forEachIndexed { index, player ->
        val existingHand = hands[player.id] ?: emptyList()
        val newCards = state.deck.subList(startingIndex + (index * 8), startingIndex + ((index + 1) * 8))
        hands[player.id] = existingHand + newCards
    }

    return state.copy(
        phase = GamePhase.REGULAR_BIDDING,
        hands = hands,
        players = state.players.map { it.copy(cardCount = 13) },
        deck = emptyList() // Clear deck from state as dealing is done
    )
}

fun startClassicDeal(state: CallbreakState, shuffledDeck: List<PlayingCard>): CallbreakState {
    val hands = state.players.mapIndexed { index, player ->
        player.id to shuffledDeck.subList(index * 13, (index + 1) * 13)
    }.toMap()

    val firstBidder = state.players[(state.dealerIndex + state.players.size - 1) % state.players.size].id

    return state.copy(
        phase = GamePhase.REGULAR_BIDDING,
        hands = hands,
        bids = emptyMap(),
        tricksWon = state.players.associate { it.id to 0 },
        currentTurn = firstBidder,
        currentTrick = CurrentTrick(),
        players = state.players.map { it.copy(bid = null, tricksWon = 0, cardCount = 13) },
        currentTrumpSuit = Suit.SPADE,
        deck = emptyList()
    )
}
