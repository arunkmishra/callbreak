package com.akm.callbreak.plugins

import com.akm.callbreak.api.rest.roomRoutes
import com.akm.callbreak.api.rest.userRoutes
import com.akm.callbreak.api.ws.ClientMessage
import com.akm.callbreak.api.ws.ServerMessage
import com.akm.callbreak.domain.models.PlayingCard
import com.akm.callbreak.domain.models.Rank
import com.akm.callbreak.domain.models.Suit
import com.akm.callbreak.room.GameRoomManager
import com.akm.callbreak.room.toDto
import io.ktor.server.application.Application
import io.ktor.server.routing.routing
import io.ktor.server.websocket.DefaultWebSocketServerSession
import io.ktor.server.websocket.webSocket
import io.ktor.websocket.CloseReason
import io.ktor.websocket.Frame
import io.ktor.websocket.close
import io.ktor.websocket.readText
import io.ktor.websocket.send
import com.akm.callbreak.config.appJson
import com.akm.callbreak.config.getEnvOrNull
import kotlinx.serialization.encodeToString
import org.slf4j.LoggerFactory

private val logger = LoggerFactory.getLogger("Routing")

fun Application.configureRouting() {
    routing {
        // ─── REST Routes ─────────────────────────────────────────────────────
        roomRoutes()
        userRoutes()

        // ─── WebSocket Route ─────────────────────────────────────────────────
        /**
         * ws://<host>/ws/rooms/{roomId}?playerId={playerId}&sessionToken={token}
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
            val clientProtocol = call.request.queryParameters["protocol"]?.toIntOrNull() ?: 1

            if (roomId == null || playerId == null || sessionToken == null) {
                logger.warn("🚫 WS connect rejected — missing params: roomId=$roomId, playerId=$playerId, hasToken=${sessionToken != null}")
                close(CloseReason(CloseReason.Codes.VIOLATED_POLICY, "Missing roomId, playerId, or sessionToken"))
                return@webSocket
            }

            val minProtocol = getEnvOrNull("MIN_SUPPORTED_PROTOCOL")?.toIntOrNull() ?: 1
            if (clientProtocol < minProtocol) {
                logger.warn("🚫 WS connect rejected — client protocol $clientProtocol < min $minProtocol (playerId=$playerId)")
                // Send specific close reason for client to force update
                close(CloseReason(CloseReason.Codes.VIOLATED_POLICY, "FORCE_UPDATE_REQUIRED"))
                return@webSocket
            }

            val room = GameRoomManager.getRoom(roomId)
            if (room == null) {
                logger.warn("🚫 WS connect rejected — room '$roomId' not found (playerId=$playerId)")
                close(CloseReason(CloseReason.Codes.NORMAL, "Room not found"))
                return@webSocket
            }

            // Verify player is in the room and validate session token
            if (!room.validateSessionToken(playerId, sessionToken)) {
                logger.warn("🚫 WS connect rejected — invalid session token for playerId=$playerId in room '$roomId'")
                close(CloseReason(CloseReason.Codes.VIOLATED_POLICY, "Invalid sessionToken or player not in room"))
                return@webSocket
            }

            val playerName = room.getState().players.firstOrNull { it.id == playerId }?.name ?: playerId
            logger.info("🔗 WS connected — '$playerName' ($playerId) joined room '$roomId'")

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
                        logger.warn("⚠️  [Room $roomId] Invalid message from '$playerName' ($playerId): $text")
                        sendError("Invalid message format")
                        null
                    }

                    if (message == null) continue

                    logger.info("📨 [Room $roomId] Message from '$playerName' ($playerId): ${message::class.simpleName}")

                    val result = when (message) {
                        is ClientMessage.StartGame -> {
                            logger.info("▶️  [Room $roomId] '$playerName' requested START_GAME")
                            room.startGame()
                        }
                        is ClientMessage.PlaceBid -> {
                            logger.info("🎯 [Room $roomId] '$playerName' placing bid=${message.bid}")
                            room.placeBid(playerId, message.bid)
                        }
                        is ClientMessage.PlaceTrumpBid -> {
                            val suitEnum = message.suit?.let { s -> Suit.entries.find { it.displayName == s } }
                            logger.info("🎴 [Room $roomId] '$playerName' placing trump bid=${message.bid}, suit=${message.suit}")
                            room.placeTrumpBid(playerId, message.bid, suitEnum)
                        }
                        is ClientMessage.PlayCard -> {
                            val suit = Suit.entries.find { it.displayName == message.suit }
                            val rank = Rank.entries.find { it.displayName == message.rank }
                            if (suit == null || rank == null) {
                                logger.warn("⚠️  [Room $roomId] '$playerName' played invalid card: suit=${message.suit}, rank=${message.rank}")
                                sendError("Invalid card: suit=${message.suit}, rank=${message.rank}")
                                null
                            } else {
                                logger.info("🃏 [Room $roomId] '$playerName' playing ${message.suit} ${message.rank}")
                                room.playCard(playerId, PlayingCard(suit, rank))
                            }
                        }
                        is ClientMessage.LeaveRoom -> {
                            logger.info("🚪 [Room $roomId] '$playerName' sent LEAVE_ROOM")
                            room.leaveRoom(playerId)
                            null
                        }
                    }

                    result?.onFailure { err ->
                        logger.warn("❌ [Room $roomId] Action failed for '$playerName': ${err.message}")
                        sendError(err.message ?: "Action failed")
                    }
                }
            } finally {
                logger.info("🔌 WS disconnected — '$playerName' ($playerId) from room '$roomId'")
                room.removeSession(playerId, this)
            }
        }
    }
}

private suspend fun DefaultWebSocketServerSession.sendError(reason: String) {
    val msg = ServerMessage.Error(reason)
    send(appJson.encodeToString<ServerMessage>(msg))
}
