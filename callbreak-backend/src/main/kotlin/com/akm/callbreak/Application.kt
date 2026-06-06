package com.akm.callbreak

import com.akm.callbreak.plugins.configureHTTP
import com.akm.callbreak.plugins.configureLogging
import com.akm.callbreak.plugins.configureRouting
import com.akm.callbreak.plugins.configureSecurity
import com.akm.callbreak.plugins.configureSerialization
import com.akm.callbreak.plugins.configureWebSockets
import com.akm.callbreak.plugins.initRedis
import com.akm.callbreak.plugins.restoreAllGames
import com.akm.callbreak.config.getEnvOrNull
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
