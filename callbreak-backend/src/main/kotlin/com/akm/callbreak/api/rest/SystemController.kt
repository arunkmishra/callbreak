package com.akm.callbreak.api.rest

import io.ktor.http.HttpStatusCode
import io.ktor.server.application.call
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.post
import io.ktor.server.routing.route
import kotlinx.serialization.Serializable
import org.slf4j.LoggerFactory

private val logger = LoggerFactory.getLogger("SystemController")

@Serializable
data class FrontendLogRequest(
    val platform: String,
    val username: String? = null,
    val message: String,
    val stackTrace: String? = null
)

fun Route.systemRoutes() {
    route("/api/logs") {
        
        /**
         * POST /api/logs/frontend
         * 
         * Receives unhandled error logs from the Flutter frontend and prints them 
         * to the backend standard output for debugging.
         */
        post("/frontend") {
            try {
                val request = call.receive<FrontendLogRequest>()
                val formattedLog = buildString {
                    append("FrontEnd(${request.platform})")
                    if (!request.username.isNullOrBlank()) {
                        append("-[${request.username}]")
                    }
                    append("-Log: ${request.message}")
                    if (!request.stackTrace.isNullOrBlank()) {
                        append("\n${request.stackTrace}")
                    }
                }
                
                // Using error level to ensure it stands out in logs
                logger.error(formattedLog)
                
                call.respond(HttpStatusCode.OK)
            } catch (e: Exception) {
                logger.warn("Failed to parse frontend log request: ${e.message}")
                call.respond(HttpStatusCode.BadRequest, "Invalid log payload")
            }
        }
    }
}
