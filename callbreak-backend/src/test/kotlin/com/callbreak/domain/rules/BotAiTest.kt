package com.akm.callbreak.domain.rules

import com.akm.callbreak.domain.models.*
import kotlin.test.Test
import kotlin.test.assertEquals

class BotAiTest {

    private val botId = "bot_1"
    private val humanId = "player-1"

    private fun createBaseState(
        hand: List<PlayingCard>,
        trickCards: List<TrickCard> = emptyList(),
        ledSuit: Suit? = null
    ): CallbreakState {
        return CallbreakState(
            roomId = "TEST1",
            phase = GamePhase.PLAYING,
            players = listOf(
                Player(botId, "Bot 1", isBot = true),
                Player(humanId, "Alice"),
                Player("player-3", "Charlie"),
                Player("player-4", "Dave")
            ),
            hands = mapOf(
                botId to hand
            ),
            currentTurn = botId,
            currentTrick = CurrentTrick(
                ledSuit = ledSuit,
                cards = trickCards
            )
        )
    }

    @Test
    fun testBotBidding() {
        val hand = listOf(
            PlayingCard(Suit.SPADE, Rank.ACE),   // +1
            PlayingCard(Suit.SPADE, Rank.KING),  // +1
            PlayingCard(Suit.SPADE, Rank.TWO),   // +0
            PlayingCard(Suit.HEART, Rank.ACE),   // +1
            PlayingCard(Suit.DIAMOND, Rank.TEN), // +0
            PlayingCard(Suit.CLUB, Rank.JACK)    // +0
        )
        // Base bid = 1, total should be 1 + 3 = 4
        val bid = calculateBotBid(hand)
        assertEquals(4, bid)
    }

    @Test
    fun testBotPlayLeadHighestNonSpade() {
        val hand = listOf(
            PlayingCard(Suit.SPADE, Rank.TEN),
            PlayingCard(Suit.HEART, Rank.FIVE),
            PlayingCard(Suit.HEART, Rank.ACE),   // Highest non-spade
            PlayingCard(Suit.DIAMOND, Rank.TWO)
        )
        val state = createBaseState(hand)
        val selected = selectBotCard(state, botId)
        assertEquals(PlayingCard(Suit.HEART, Rank.ACE), selected)
    }

    @Test
    fun testBotPlayLeadOnlySpadesPlaysLowest() {
        val hand = listOf(
            PlayingCard(Suit.SPADE, Rank.TEN),
            PlayingCard(Suit.SPADE, Rank.TWO),   // Lowest spade
            PlayingCard(Suit.SPADE, Rank.ACE)
        )
        val state = createBaseState(hand)
        val selected = selectBotCard(state, botId)
        assertEquals(PlayingCard(Suit.SPADE, Rank.TWO), selected)
    }

    @Test
    fun testBotPlayFollowWinWithCheapestCard() {
        val hand = listOf(
            PlayingCard(Suit.HEART, Rank.TWO),
            PlayingCard(Suit.HEART, Rank.JACK),  // Winning card 1 (lower)
            PlayingCard(Suit.HEART, Rank.ACE),   // Winning card 2 (higher)
            PlayingCard(Suit.DIAMOND, Rank.ACE)
        )
        // Heart led, winning card on table is Heart 10
        val trickCards = listOf(
            TrickCard(humanId, PlayingCard(Suit.HEART, Rank.TEN))
        )
        val state = createBaseState(hand, trickCards, Suit.HEART)

        // Bot must follow Heart, J and A are both winning. It should play the lowest winning card (J).
        val selected = selectBotCard(state, botId)
        assertEquals(PlayingCard(Suit.HEART, Rank.JACK), selected)
    }

    @Test
    fun testBotPlayFollowLoseWithCheapestCard() {
        val hand = listOf(
            PlayingCard(Suit.HEART, Rank.TWO),   // Losing card 1 (lower)
            PlayingCard(Suit.HEART, Rank.FIVE),  // Losing card 2 (higher)
            PlayingCard(Suit.DIAMOND, Rank.ACE)
        )
        // Heart led, winning card on table is Heart Ace (14)
        val trickCards = listOf(
            TrickCard(humanId, PlayingCard(Suit.HEART, Rank.ACE))
        )
        val state = createBaseState(hand, trickCards, Suit.HEART)

        // Bot must follow Heart, cannot win. It should throw away its lowest losing card (Heart 2).
        val selected = selectBotCard(state, botId)
        assertEquals(PlayingCard(Suit.HEART, Rank.TWO), selected)
    }
}
