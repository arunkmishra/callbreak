package com.callbreak.domain.rules

import com.callbreak.domain.models.*
import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertFalse

class MoveValidatorTest {

    private val player1 = "player-1"
    private val player2 = "player-2"

    private fun createBaseState(
        currentTurn: PlayerId,
        hand: List<PlayingCard>,
        trickCards: List<TrickCard> = emptyList(),
        ledSuit: Suit? = null
    ): CallbreakState {
        return CallbreakState(
            roomId = "TEST1",
            phase = GamePhase.PLAYING,
            players = listOf(
                Player(player1, "Alice"),
                Player(player2, "Bob"),
                Player("player-3", "Charlie"),
                Player("player-4", "Dave")
            ),
            hands = mapOf(
                player1 to hand
            ),
            currentTurn = currentTurn,
            currentTrick = CurrentTrick(
                ledSuit = ledSuit,
                cards = trickCards
            )
        )
    }

    @Test
    fun testLeadingCardAnyCardAllowed() {
        val hand = listOf(
            PlayingCard(Suit.DIAMOND, Rank.EIGHT),
            PlayingCard(Suit.HEART, Rank.FIVE),
            PlayingCard(Suit.SPADE, Rank.TEN)
        )
        val state = createBaseState(currentTurn = player1, hand = hand)

        // Any card from the hand should be allowed to be led
        assertTrue(validateMove(state, player1, hand[0]).isSuccess)
        assertTrue(validateMove(state, player1, hand[1]).isSuccess)
        assertTrue(validateMove(state, player1, hand[2]).isSuccess)
    }

    @Test
    fun testFollowSuitAndWinRequired() {
        val hand = listOf(
            PlayingCard(Suit.DIAMOND, Rank.EIGHT),
            PlayingCard(Suit.DIAMOND, Rank.JACK),
            PlayingCard(Suit.HEART, Rank.FIVE)
        )
        // Diamond led, winning card is Diamond 10
        val trickCards = listOf(
            TrickCard(player2, PlayingCard(Suit.DIAMOND, Rank.TEN))
        )
        val state = createBaseState(
            currentTurn = player1,
            hand = hand,
            trickCards = trickCards,
            ledSuit = Suit.DIAMOND
        )

        // Diamond J beats Diamond 10 -> allowed
        assertTrue(validateMove(state, player1, hand[1]).isSuccess)

        // Diamond 8 does not beat Diamond 10 -> rejected (since they have J)
        val resLow = validateMove(state, player1, hand[0])
        assertTrue(resLow.isFailure)
        assertTrue(resLow.exceptionOrNull()?.message!!.contains("beats"))

        // Heart 5 does not follow suit -> rejected
        val resWrongSuit = validateMove(state, player1, hand[2])
        assertTrue(resWrongSuit.isFailure)
        assertTrue(resWrongSuit.exceptionOrNull()?.message!!.contains("follow led suit"))
    }

    @Test
    fun testFollowSuitForcedLoss() {
        val hand = listOf(
            PlayingCard(Suit.DIAMOND, Rank.EIGHT),
            PlayingCard(Suit.DIAMOND, Rank.TEN),
            PlayingCard(Suit.HEART, Rank.FIVE)
        )
        // Diamond led, winning card is Diamond Queen (12)
        val trickCards = listOf(
            TrickCard(player2, PlayingCard(Suit.DIAMOND, Rank.QUEEN))
        )
        val state = createBaseState(
            currentTurn = player1,
            hand = hand,
            trickCards = trickCards,
            ledSuit = Suit.DIAMOND
        )

        // Player cannot beat Q (since hand has 8 and 10), but must still play Diamond
        assertTrue(validateMove(state, player1, hand[0]).isSuccess)
        assertTrue(validateMove(state, player1, hand[1]).isSuccess)

        // Heart 5 does not follow suit -> rejected
        val resWrongSuit = validateMove(state, player1, hand[2])
        assertTrue(resWrongSuit.isFailure)
        assertTrue(resWrongSuit.exceptionOrNull()?.message!!.contains("follow led suit"))
    }

    @Test
    fun testTrumpAndWinRequired() {
        // Player has no Diamonds (void in led suit), but has Spades and Hearts
        val hand = listOf(
            PlayingCard(Suit.SPADE, Rank.FIVE),
            PlayingCard(Suit.SPADE, Rank.TEN),
            PlayingCard(Suit.HEART, Rank.FIVE)
        )
        
        // Scenario A: Diamond led, winning card is Diamond 10. No Spades played yet.
        val trickCardsA = listOf(
            TrickCard(player2, PlayingCard(Suit.DIAMOND, Rank.TEN))
        )
        val stateA = createBaseState(
            currentTurn = player1,
            hand = hand,
            trickCards = trickCardsA,
            ledSuit = Suit.DIAMOND
        )

        // Any Spade beats the Diamond -> both 5 and 10 are allowed
        assertTrue(validateMove(stateA, player1, hand[0]).isSuccess)
        assertTrue(validateMove(stateA, player1, hand[1]).isSuccess)
        // Heart 5 is a discard, but player has Spades -> rejected
        assertTrue(validateMove(stateA, player1, hand[2]).isFailure)

        // Scenario B: Diamond led, another player already trumped with Spade 7
        val trickCardsB = listOf(
            TrickCard(player2, PlayingCard(Suit.DIAMOND, Rank.ACE)),
            TrickCard("player-3", PlayingCard(Suit.SPADE, Rank.SEVEN))
        )
        val stateB = createBaseState(
            currentTurn = player1,
            hand = hand,
            trickCards = trickCardsB,
            ledSuit = Suit.DIAMOND
        )

        // Spade 10 beats Spade 7 -> allowed
        assertTrue(validateMove(stateB, player1, hand[1]).isSuccess)
        // Spade 5 does not beat Spade 7 -> rejected
        assertTrue(validateMove(stateB, player1, hand[0]).isFailure)
        // Heart 5 -> rejected
        assertTrue(validateMove(stateB, player1, hand[2]).isFailure)
    }

    @Test
    fun testTrumpLossNotForced() {
        // Player is void in Diamond, but has Spades and Hearts.
        val hand = listOf(
            PlayingCard(Suit.SPADE, Rank.FIVE),
            PlayingCard(Suit.SPADE, Rank.EIGHT),
            PlayingCard(Suit.HEART, Rank.FIVE)
        )
        // Diamond led, another player trumped with Spade Jack
        val trickCards = listOf(
            TrickCard(player2, PlayingCard(Suit.DIAMOND, Rank.ACE)),
            TrickCard("player-3", PlayingCard(Suit.SPADE, Rank.JACK))
        )
        val state = createBaseState(
            currentTurn = player1,
            hand = hand,
            trickCards = trickCards,
            ledSuit = Suit.DIAMOND
        )

        // Player cannot beat Spade Jack, so they can play ANY card.
        assertTrue(validateMove(state, player1, hand[0]).isSuccess)
        assertTrue(validateMove(state, player1, hand[1]).isSuccess)
        assertTrue(validateMove(state, player1, hand[2]).isSuccess)
    }

    @Test
    fun testDiscard() {
        // Player is void in Diamond AND Spades
        val hand = listOf(
            PlayingCard(Suit.HEART, Rank.FIVE),
            PlayingCard(Suit.CLUB, Rank.ACE)
        )
        // Diamond led, winning card is Spade 10
        val trickCards = listOf(
            TrickCard(player2, PlayingCard(Suit.DIAMOND, Rank.ACE)),
            TrickCard("player-3", PlayingCard(Suit.SPADE, Rank.TEN))
        )
        val state = createBaseState(
            currentTurn = player1,
            hand = hand,
            trickCards = trickCards,
            ledSuit = Suit.DIAMOND
        )

        // Since player has no Diamonds and no Spades, they can discard any card
        assertTrue(validateMove(state, player1, hand[0]).isSuccess)
        assertTrue(validateMove(state, player1, hand[1]).isSuccess)
    }
}
