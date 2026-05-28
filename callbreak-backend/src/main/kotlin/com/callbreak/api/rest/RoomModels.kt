package com.callbreak.api.rest

import kotlinx.serialization.Serializable

// ─── Create Room ────────────────────────────────────────────────────────────

/**
 * POST /api/rooms/create
 *
 * Body: { "playerName": "Alice" }
 */
@Serializable
data class CreateRoomRequest(
    val playerName: String,
    val totalRounds: Int = 5,
    val minBid: Int? = null,
    val greedPenalty: Boolean = false,
    val allowCustomTrump: Boolean = false,
)

/**
 * Response: { "roomId": "ABCDE", "playerId": "uuid" }
 *
 * [roomId] is always a 5-letter uppercase alpha-numeric code.
 * [playerId] is a UUID string; the creator is also the initial host.
 */
@Serializable
data class CreateRoomResponse(
    val roomId: String,
    val playerId: String,
    val sessionToken: String,
)

// ─── Join Room ───────────────────────────────────────────────────────────────

/**
 * POST /api/rooms/join
 *
 * Body: { "roomId": "ABCDE", "playerName": "Bob" }
 */
@Serializable
data class JoinRoomRequest(
    val roomId: String,
    val playerName: String,
)

/**
 * Response: { "roomId": "ABCDE", "playerId": "uuid", "sessionToken": "uuid" }
 */
@Serializable
data class JoinRoomResponse(
    val roomId: String,
    val playerId: String,
    val sessionToken: String,
)

// ─── Error ───────────────────────────────────────────────────────────────────

/** Generic REST error body. */
@Serializable
data class ApiError(
    val error: String,
)
