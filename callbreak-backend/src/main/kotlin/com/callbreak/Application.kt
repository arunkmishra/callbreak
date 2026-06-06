package com.callbreak

import com.callbreak.plugins.configureHTTP
import com.callbreak.plugins.configureLogging
import com.callbreak.plugins.configureRouting
import com.callbreak.plugins.configureSecurity
import com.callbreak.plugins.configureSerialization
import com.callbreak.plugins.configureWebSockets
import com.callbreak.plugins.initRedis
import com.callbreak.plugins.restoreAllGames
import com.callbreak.config.getEnvOrNull
import io.ktor.server.application.Application
import io.ktor.server.netty.EngineMain
import org.slf4j.LoggerFactory

fun main(args: Array<String>): Unit = EngineMain.main(args)

/**
 * Ktor application entry point.
 *
 * Plugin install order matters:
 * 1. Logging (wraps all requests)
 * 2. Serialization (needed by REST routes)
 * 3. WebSockets (needed by WS route)
 * 4. Security (JWT auth — must be before Routing)
 * 5. Routing (registers all routes last)
 * 6. Redis (initialized on startup for game state persistence)
 */
fun Application.module() {
    val logger = LoggerFactory.getLogger("Application")
    val minProtocol = getEnvOrNull("MIN_SUPPORTED_PROTOCOL") ?: "1 (default)"
    logger.info("🚀 Backend starting... MIN_SUPPORTED_PROTOCOL is set to $minProtocol")

    configureHTTP()
    configureLogging()
    configureSerialization()
    configureWebSockets()
    configureSecurity()
    configureRouting()
    initRedis()
    restoreAllGames()  // Rehydrate any in-progress games after crash/restart
}
