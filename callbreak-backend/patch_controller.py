with open('/Users/arunkumarmishra/Workspace/callbreak/callbreak-backend/src/main/kotlin/com/akm/callbreak/api/rest/RoomController.kt', 'r') as f:
    content = f.read()

import_statement = "import com.akm.callbreak.services.MatchmakingService\n"
if import_statement not in content:
    content = content.replace("import com.akm.callbreak.room.GameRoomManager\n", import_statement + "import com.akm.callbreak.room.GameRoomManager\n")

find_match_route = """        /**
         * POST /api/rooms/find-match
         */
        post("/find-match") {
            val request = runCatching { call.receive<FindMatchRequest>() }.getOrElse {
                call.respond(HttpStatusCode.BadRequest, ApiError("Invalid request body"))
                return@post
            }
            if (request.playerName.isBlank()) {
                call.respond(HttpStatusCode.BadRequest, ApiError("playerName must not be blank"))
                return@post
            }

            val existingRoom = GameRoomManager.findPublicLobby()
            if (existingRoom != null) {
                // Join existing public lobby
                val state = existingRoom.getState()
                GameRoomManager.joinRoom(state.roomId, request.playerName.trim(), request.playerId)
                    .fold(
                        onSuccess = { (playerId, sessionToken) ->
                            logger.info("✅ POST /api/rooms/find-match — '${request.playerName.trim()}' joined existing room '${state.roomId}'")
                            call.respond(HttpStatusCode.OK, FindMatchResponse(state.roomId, playerId, sessionToken))
                        },
                        onFailure = { error ->
                            logger.info("⚠️ POST /api/rooms/find-match — join failed (${error.message}), creating new room")
                            val (roomId, playerId, sessionToken) = GameRoomManager.createRoom(
                                playerName = request.playerName.trim(),
                                playerId = request.playerId,
                                isPublic = true,
                            )
                            MatchmakingService.startBackfill(roomId)
                            call.respond(HttpStatusCode.Created, FindMatchResponse(roomId, playerId, sessionToken))
                        }
                    )
            } else {
                // No public lobby available — create a new one
                val (roomId, playerId, sessionToken) = GameRoomManager.createRoom(
                    playerName = request.playerName.trim(),
                    playerId = request.playerId,
                    isPublic = true,
                )
                logger.info("✅ POST /api/rooms/find-match — '${request.playerName.trim()}' created new public room '$roomId'")
                MatchmakingService.startBackfill(roomId)
                call.respond(HttpStatusCode.Created, FindMatchResponse(roomId, playerId, sessionToken))
            }
        }
    }
}"""

content = content.replace("    }\n}", find_match_route)

with open('/Users/arunkumarmishra/Workspace/callbreak/callbreak-backend/src/main/kotlin/com/akm/callbreak/api/rest/RoomController.kt', 'w') as f:
    f.write(content)

