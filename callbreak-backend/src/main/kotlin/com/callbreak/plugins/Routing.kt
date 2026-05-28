package com.callbreak.plugins

import com.callbreak.api.rest.roomRoutes
import com.callbreak.api.ws.ClientMessage
import com.callbreak.api.ws.ServerMessage
import com.callbreak.domain.models.PlayingCard
import com.callbreak.domain.models.Rank
import com.callbreak.domain.models.Suit
import com.callbreak.room.GameRoomManager
import com.callbreak.room.toDto
import io.ktor.server.application.Application
import io.ktor.server.routing.routing
import io.ktor.server.websocket.DefaultWebSocketServerSession
import io.ktor.server.websocket.webSocket
import io.ktor.websocket.CloseReason
import io.ktor.websocket.Frame
import io.ktor.websocket.close
import io.ktor.websocket.readText
import io.ktor.websocket.send
import com.callbreak.config.appJson
import kotlinx.serialization.encodeToString

fun Application.configureRouting() {
    routing {
        // ─── REST Routes ─────────────────────────────────────────────────────
        roomRoutes()

        // ─── WebSocket Route ─────────────────────────────────────────────────
        /**
         * ws://<host>/ws/rooms/{roomId}?playerId={playerId}
         *
         * Lifecycle:
         * 1. Validate roomId + playerId query params.
         * 2. Register the session in the GameRoom.
         * 3. Listen for [ClientMessage] frames and dispatch to GameRoom methods.
         * 4. On disconnect, remove session.
         */
        webSocket("/ws/rooms/{roomId}") {
            val roomId = call.parameters["roomId"]?.uppercase()
            val playerId = call.request.queryParameters["playerId"]
            val sessionToken = call.request.queryParameters["sessionToken"]

            if (roomId == null || playerId == null || sessionToken == null) {
                close(CloseReason(CloseReason.Codes.VIOLATED_POLICY, "Missing roomId, playerId, or sessionToken"))
                return@webSocket
            }

            val room = GameRoomManager.getRoom(roomId)
            if (room == null) {
                close(CloseReason(CloseReason.Codes.NORMAL, "Room not found"))
                return@webSocket
            }

            // Verify player is in the room and validate session token
            if (!room.validateSessionToken(playerId, sessionToken)) {
                close(CloseReason(CloseReason.Codes.VIOLATED_POLICY, "Invalid sessionToken or player not in room"))
                return@webSocket
            }

            // Handle player reconnection (marks online, cancels bot timer)
            room.playerReconnected(playerId)

            room.addSession(playerId, this)

            // Send current state immediately on connect
            val stateMsg = ServerMessage.StateUpdate(toDto(room.getState(), playerId))
            send(appJson.encodeToString<ServerMessage>(stateMsg))

            try {
                for (frame in incoming) {
                    if (frame !is Frame.Text) continue
                    val text = frame.readText()

                    val message: ClientMessage? = try {
                        appJson.decodeFromString<ClientMessage>(text)
                    } catch (_: Exception) {
                        sendError("Invalid message format")
                        null
                    }

                    if (message == null) continue

                    val result = when (message) {
                        is ClientMessage.StartGame -> room.startGame()
                        is ClientMessage.PlaceBid -> room.placeBid(playerId, message.bid)
                        is ClientMessage.PlaceTrumpBid -> {
                            val suitEnum = message.suit?.let { s -> Suit.entries.find { it.displayName == s } }
                            room.placeTrumpBid(playerId, message.bid, suitEnum)
                        }
                        is ClientMessage.PlayCard -> {
                            val suit = Suit.entries.find { it.displayName == message.suit }
                            val rank = Rank.entries.find { it.displayName == message.rank }
                            if (suit == null || rank == null) {
                                sendError("Invalid card: suit=${message.suit}, rank=${message.rank}")
                                null
                            } else {
                                room.playCard(playerId, PlayingCard(suit, rank))
                            }
                        }
                    }

                    result?.onFailure { sendError(it.message ?: "Action failed") }
                }
            } finally {
                room.removeSession(playerId)
            }
        }
    }
}

private suspend fun DefaultWebSocketServerSession.sendError(reason: String) {
    val msg = ServerMessage.Error(reason)
    send(appJson.encodeToString<ServerMessage>(msg))
}

