package com.callbreak.config

import io.github.cdimascio.dotenv.dotenv

/**
 * Loads environment variables from the .env file (for local development).
 * On production (e.g. Render), system environment variables take precedence automatically.
 */
val env = dotenv {
    ignoreIfMissing = true // Don't crash if .env is absent (production uses system env vars)
}

/** Returns the value for [key] from .env or system environment. */
fun getEnv(key: String): String =
    env[key] ?: System.getenv(key) ?: error("Missing required environment variable: $key")

/** Returns the value for [key] from .env or system environment, or null if missing. */
fun getEnvOrNull(key: String): String? =
    env[key] ?: System.getenv(key)
