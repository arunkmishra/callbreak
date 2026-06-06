package com.akm.callbreak.config

import com.akm.callbreak.api.ws.ClientMessage
import com.akm.callbreak.api.ws.ServerMessage
import kotlinx.serialization.json.Json
import kotlinx.serialization.modules.SerializersModule
import kotlinx.serialization.modules.polymorphic
import kotlinx.serialization.modules.subclass

/**
 * Shared Json instance used across the application for both
 * REST serialization and WebSocket encode/decode.
 */
val appJson = Json {
    encodeDefaults = true
    ignoreUnknownKeys = true
    prettyPrint = false
    classDiscriminator = "type"
    serializersModule = SerializersModule {
        polymorphic(ClientMessage::class) {
            subclass(ClientMessage.StartGame::class)
            subclass(ClientMessage.PlaceBid::class)
            subclass(ClientMessage.PlayCard::class)
        }
        polymorphic(ServerMessage::class) {
            subclass(ServerMessage.StateUpdate::class)
            subclass(ServerMessage.Error::class)
        }
    }
}
