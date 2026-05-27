package com.callbreak.api.ws

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Messages sent FROM the client TO the server over WebSocket.
 *
 * Every message carries a "type" discriminator so the server
 * can deserialize with kotlinx.serialization polymorphism.
 *
 * Possible messages:
 * - [StartGame]  – Host requests to start the game (requires 4 players in LOBBY).
 * - [PlaceBid]   – Player submits their bid during BIDDING phase.
 * - [PlayCard]   – Player plays a card during PLAYING phase.
 */
@Serializable
sealed interface ClientMessage {

    @Serializable
    @SerialName("START_GAME")
    object StartGame : ClientMessage

    @Serializable
    @SerialName("PLACE_BID")
    data class PlaceBid(
        /** Number of tricks the player bids (1–13). */
        val bid: Int,
    ) : ClientMessage

    @Serializable
    @SerialName("PLAY_CARD")
    data class PlayCard(
        /** Serialized suit name, e.g. "Spade", "Heart". */
        val suit: String,
        /** Serialized rank name, e.g. "A", "K", "7". */
        val rank: String,
    ) : ClientMessage
}
