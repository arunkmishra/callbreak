package com.callbreak.api.rest

import com.callbreak.plugins.RedisService
import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.authenticate
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.principal
import io.ktor.server.application.call
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.route
import kotlinx.serialization.Serializable

import io.ktor.server.request.receive

@Serializable
data class HeartbeatRequest(val status: String = "available")

@Serializable
data class OnlineUsersResponse(
    val onlineUserIds: List<String>,
    val userStatuses: Map<String, String>? = null
)

fun Route.userRoutes() {
    route("/api/users") {

        /**
         * POST /api/users/heartbeat
         *
         * Called every 20 seconds by the Flutter client when the app is open.
         * Sets a Redis key with a 30-second TTL so the user appears online.
         * Requires a valid Supabase JWT in the Authorization header.
         */
        authenticate("auth-jwt") {
            post("/heartbeat") {
                val principal = call.principal<JWTPrincipal>()
                val userId = principal?.payload?.subject
                    ?: return@post call.respond(HttpStatusCode.Unauthorized)

                val request = try {
                    call.receive<HeartbeatRequest>()
                } catch (e: Exception) {
                    HeartbeatRequest()
                }
                // TTL = 35 seconds (slightly more than the 20s heartbeat interval)
                RedisService.setOnline(userId, request.status, 35)
                call.respond(HttpStatusCode.OK)
            }
        }

        /**
         * GET /api/users/online
         *
         * Returns a list of Supabase user IDs currently marked as online in Redis.
         * The Flutter client uses this to show green dots next to friends.
         */
        get("/online") {
            val statuses = RedisService.getOnlineUsers()
            val userIds = statuses.keys.toList()
            call.respond(OnlineUsersResponse(userIds, statuses))
        }
    }
}
