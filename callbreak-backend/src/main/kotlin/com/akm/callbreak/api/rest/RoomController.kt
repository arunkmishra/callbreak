package com.akm.callbreak.api.rest

import com.akm.callbreak.room.GameRoomManager
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.call
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.post
import io.ktor.server.routing.route
import org.slf4j.LoggerFactory

private val logger = LoggerFactory.getLogger("RoomController")

fun Route.roomRoutes() {
    route("/api/rooms") {

        /**
         * POST /api/rooms/create
         * Creates a new room and returns the room code + host player ID.
         */
        post("/create") {
            val request = runCatching { call.receive<CreateRoomRequest>() }.getOrElse {
                logger.warn("❌ POST /api/rooms/create — invalid request body")
                call.respond(HttpStatusCode.BadRequest, ApiError("Invalid request body"))
                return@post
            }
            if (request.playerName.isBlank()) {
                logger.warn("❌ POST /api/rooms/create — blank playerName")
                call.respond(HttpStatusCode.BadRequest, ApiError("playerName must not be blank"))
                return@post
            }
            val (roomId, playerId, sessionToken) = GameRoomManager.createRoom(
                playerName = request.playerName.trim(),
                totalRounds = request.totalRounds,
                minBid = request.minBid,
                greedPenalty = request.greedPenalty,
                allowCustomTrump = request.allowCustomTrump,
                playerId = request.playerId
            )
            logger.info("✅ POST /api/rooms/create — room '$roomId' created by '${request.playerName.trim()}' ($playerId)")
            call.respond(HttpStatusCode.Created, CreateRoomResponse(roomId, playerId, sessionToken))
        }

        /**
         * POST /api/rooms/join
         * Joins an existing room (must be in LOBBY with < 4 players).
         */
        post("/join") {
            val request = runCatching { call.receive<JoinRoomRequest>() }.getOrElse {
                logger.warn("❌ POST /api/rooms/join — invalid request body")
                call.respond(HttpStatusCode.BadRequest, ApiError("Invalid request body"))
                return@post
            }
            if (request.roomId.isBlank() || request.playerName.isBlank()) {
                logger.warn("❌ POST /api/rooms/join — blank roomId or playerName")
                call.respond(HttpStatusCode.BadRequest, ApiError("roomId and playerName must not be blank"))
                return@post
            }
            logger.info("📥 POST /api/rooms/join — '${request.playerName.trim()}' attempting to join room '${request.roomId.trim().uppercase()}'")
            GameRoomManager.joinRoom(request.roomId.trim().uppercase(), request.playerName.trim(), request.playerId)
                .fold(
                    onSuccess = { (playerId, sessionToken) ->
                        logger.info("✅ POST /api/rooms/join — '${request.playerName.trim()}' ($playerId) joined room '${request.roomId.uppercase()}'")
                        call.respond(HttpStatusCode.OK, JoinRoomResponse(request.roomId.uppercase(), playerId, sessionToken))
                    },
                    onFailure = { error ->
                        logger.warn("❌ POST /api/rooms/join — '${request.playerName.trim()}' failed to join '${request.roomId.uppercase()}': ${error.message}")
                        call.respond(HttpStatusCode.BadRequest, ApiError(error.message ?: "Join failed"))
                    }
                )
        }
    }
}
