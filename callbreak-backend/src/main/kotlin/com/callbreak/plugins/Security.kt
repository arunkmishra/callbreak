package com.callbreak.plugins

import com.auth0.jwk.JwkProviderBuilder
import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import com.auth0.jwt.interfaces.ECDSAKeyProvider
import com.callbreak.config.getEnv
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.auth.Authentication
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.jwt.jwt
import io.ktor.server.response.respondText
import java.net.URL
import java.security.interfaces.ECPrivateKey
import java.security.interfaces.ECPublicKey
import java.util.concurrent.TimeUnit

fun Application.configureSecurity() {
    val supabaseUrl = getEnv("SUPABASE_URL").removeSuffix("/")
    val jwkProvider = JwkProviderBuilder(URL("$supabaseUrl/auth/v1/.well-known/jwks.json"))
        .cached(10, 24, TimeUnit.HOURS)
        .rateLimited(10, 1, TimeUnit.MINUTES)
        .build()

    val provider = object : ECDSAKeyProvider {
        override fun getPublicKeyById(keyId: String?): ECPublicKey {
            val kid = keyId ?: jwkProvider.get(null).id
            val jwk = jwkProvider.get(kid)
            return jwk.publicKey as ECPublicKey
        }
        override fun getPrivateKey(): ECPrivateKey? = null
        override fun getPrivateKeyId(): String? = null
    }
    
    val algorithm = Algorithm.ECDSA256(provider)

    install(Authentication) {
        jwt("auth-jwt") {
            verifier(
                JWT.require(algorithm)
                    .acceptLeeway(60)
                    .build()
            )
            validate { credential ->
                if (credential.payload.subject != null) {
                    JWTPrincipal(credential.payload)
                } else null
            }
            challenge { defaultScheme, realm ->
                call.respondText("Token is not valid or has expired", status = io.ktor.http.HttpStatusCode.Unauthorized)
            }
        }
    }
}

fun JWTPrincipal.supabaseUserId(): String? = payload.subject
