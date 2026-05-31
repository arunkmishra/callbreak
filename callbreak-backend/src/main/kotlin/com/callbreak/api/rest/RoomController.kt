package com.callbreak.api.rest

import com.callbreak.room.GameRoomManager
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.call
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.post
import io.ktor.server.routing.route

fun Route.roomRoutes() {
    route("/api/rooms") {

        /**
         * POST /api/rooms/create
         * Creates a new room and returns the room code + host player ID.
         */
        post("/create") {
            val request = runCatching { call.receive<CreateRoomRequest>() }.getOrElse {
                call.respond(HttpStatusCode.BadRequest, ApiError("Invalid request body"))
                return@post
            }
            if (request.playerName.isBlank()) {
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
            call.respond(HttpStatusCode.Created, CreateRoomResponse(roomId, playerId, sessionToken))
        }

        /**
         * POST /api/rooms/join
         * Joins an existing room (must be in LOBBY with < 4 players).
         */
        post("/join") {
            val request = runCatching { call.receive<JoinRoomRequest>() }.getOrElse {
                call.respond(HttpStatusCode.BadRequest, ApiError("Invalid request body"))
                return@post
            }
            if (request.roomId.isBlank() || request.playerName.isBlank()) {
                call.respond(HttpStatusCode.BadRequest, ApiError("roomId and playerName must not be blank"))
                return@post
            }
            GameRoomManager.joinRoom(request.roomId.trim().uppercase(), request.playerName.trim(), request.playerId)
                .fold(
                    onSuccess = { (playerId, sessionToken) ->
                        call.respond(HttpStatusCode.OK, JoinRoomResponse(request.roomId.uppercase(), playerId, sessionToken))
                    },
                    onFailure = { error ->
                        call.respond(HttpStatusCode.BadRequest, ApiError(error.message ?: "Join failed"))
                    }
                )
        }
    }
}
