package com.callbreak

import com.auth0.jwk.JwkProviderBuilder
import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import com.auth0.jwt.interfaces.ECDSAKeyProvider
import java.net.URL
import java.security.interfaces.ECPrivateKey
import java.security.interfaces.ECPublicKey
import java.util.concurrent.TimeUnit

fun testES256() {
    val jwkProvider = JwkProviderBuilder(URL("https://example.com"))
        .cached(10, 24, TimeUnit.HOURS)
        .rateLimited(10, 1, TimeUnit.MINUTES)
        .build()

    val provider = object : ECDSAKeyProvider {
        override fun getPublicKeyById(keyId: String): ECPublicKey {
            return jwkProvider.get(keyId).publicKey as ECPublicKey
        }
        override fun getPrivateKey(): ECPrivateKey? = null
        override fun getPrivateKeyId(): String? = null
    }
    
    val algorithm = Algorithm.ECDSA256(provider)
    val verifier = JWT.require(algorithm).build()
}
