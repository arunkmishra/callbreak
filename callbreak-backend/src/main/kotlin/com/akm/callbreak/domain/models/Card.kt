package com.akm.callbreak.domain.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Represents a card suit. Spade is always the trump suit in Callbreak.
 */
@Serializable
enum class Suit(val displayName: String) {
    @SerialName("Spade")   SPADE("Spade"),     // Trump suit
    @SerialName("Heart")   HEART("Heart"),
    @SerialName("Diamond") DIAMOND("Diamond"),
    @SerialName("Club")    CLUB("Club")
}

/**
 * Represents a card rank with its comparative integer value.
 * ACE is highest (14), TWO is lowest (2).
 */
@Serializable
enum class Rank(val value: Int, val displayName: String) {
    @SerialName("2")  TWO(2, "2"),
    @SerialName("3")  THREE(3, "3"),
    @SerialName("4")  FOUR(4, "4"),
    @SerialName("5")  FIVE(5, "5"),
    @SerialName("6")  SIX(6, "6"),
    @SerialName("7")  SEVEN(7, "7"),
    @SerialName("8")  EIGHT(8, "8"),
    @SerialName("9")  NINE(9, "9"),
    @SerialName("10") TEN(10, "10"),
    @SerialName("J")  JACK(11, "J"),
    @SerialName("Q")  QUEEN(12, "Q"),
    @SerialName("K")  KING(13, "K"),
    @SerialName("A")  ACE(14, "A")
}

/**
 * A single playing card uniquely identified by its suit and rank.
 */
@Serializable
data class PlayingCard(
    val suit: Suit,
    val rank: Rank,
) {
    /** Numeric value used for comparisons within a trick. */
    val value: Int get() = rank.value

    override fun toString(): String = "${rank.displayName}${suit.displayName[0]}"
}

/** Creates a full 52-card deck in a deterministic order. */
fun createDeck(): List<PlayingCard> =
    Suit.entries.flatMap { suit ->
        Rank.entries.map { rank -> PlayingCard(suit, rank) }
    }
