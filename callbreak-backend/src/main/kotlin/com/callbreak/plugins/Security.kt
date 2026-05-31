package com.callbreak.plugins

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import com.callbreak.config.getEnv
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.auth.Authentication
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.jwt.jwt

/**
 * Configures JWT authentication using the Supabase JWT secret.
 *
 * Supabase signs all user access tokens with the project's JWT secret (HS256).
 * The Flutter client sends this token either as a query param or in the
 * Authorization header. The verifier checks signature + expiry automatically.
 */
fun Application.configureSecurity() {
    val jwtSecret = getEnv("SUPABASE_JWT_SECRET")
    val algorithm = Algorithm.HMAC256(jwtSecret)

    install(Authentication) {
        jwt("auth-jwt") {
            verifier(
                JWT.require(algorithm)
                    // Supabase tokens often have "supabase" as the issuer, not the full URL.
                    // The HMAC256 signature verification is what provides the actual security.
                    .build()
            )
            validate { credential ->
                // Ensure the token has a subject (user ID)
                if (credential.payload.subject != null) {
                    JWTPrincipal(credential.payload)
                } else {
                    null
                }
            }
        }
    }
}

/** Extension helper: safely get the authenticated Supabase user ID from the JWT. */
fun JWTPrincipal.supabaseUserId(): String? = payload.subject
