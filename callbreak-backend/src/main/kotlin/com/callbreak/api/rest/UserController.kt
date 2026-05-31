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

@Serializable
data class OnlineUsersResponse(val onlineUserIds: List<String>)

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

                // TTL = 35 seconds (slightly more than the 20s heartbeat interval)
                RedisService.commands.setex("online:$userId", 35, "1")
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
            val keys = try {
                RedisService.commands.keys("online:*")
            } catch (e: Exception) {
                emptyList()
            }
            val userIds = keys.map { it.removePrefix("online:") }
            call.respond(OnlineUsersResponse(userIds))
        }
    }
}
