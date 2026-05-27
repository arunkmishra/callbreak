package com.callbreak

import com.callbreak.plugins.configureHTTP
import com.callbreak.plugins.configureLogging
import com.callbreak.plugins.configureRouting
import com.callbreak.plugins.configureSerialization
import com.callbreak.plugins.configureWebSockets
import io.ktor.server.application.Application
import io.ktor.server.netty.EngineMain

fun main(args: Array<String>): Unit = EngineMain.main(args)

/**
 * Ktor application entry point.
 *
 * Plugin install order matters:
 * 1. Logging (wraps all requests)
 * 2. Serialization (needed by REST routes)
 * 3. WebSockets (needed by WS route)
 * 4. Routing (registers all routes last)
 */
fun Application.module() {
    configureHTTP()
    configureLogging()
    configureSerialization()
    configureWebSockets()
    configureRouting()
}
