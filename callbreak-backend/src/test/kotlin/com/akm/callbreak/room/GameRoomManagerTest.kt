package com.akm.callbreak.room

import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlinx.coroutines.runBlocking
import com.akm.callbreak.config.appJson
import kotlinx.serialization.encodeToString

class GameRoomManagerTest {

    @Test
    fun testSessionTokensSurviveRoomRestore() = runBlocking {
        // 1. Create a room
        val (roomId, playerId, originalToken) = GameRoomManager.createRoom(
            playerName = "Alice",
            totalRounds = 5
        )

        val room = GameRoomManager.getRoom(roomId)
        assertNotNull(room, "Room should be created")

        // Validate the original token
        assertTrue(
            room.validateSessionToken(playerId, originalToken),
            "Original room should validate the token"
        )

        // Add another player to verify join works with tokens too
        val joinResult = GameRoomManager.joinRoom(roomId, "Bob")
        assertTrue(joinResult.isSuccess)
        val (bobId, bobToken) = joinResult.getOrThrow()
        assertTrue(room.validateSessionToken(bobId, bobToken))

        // 2. Extract state and simulate Redis serialization/deserialization
        val originalState = room.getState()
        val stateJson = appJson.encodeToString(originalState)
        
        // Clear from manager to simulate server shutdown
        GameRoomManager.removeRoom(roomId)

        // Deserialize state (simulating Redis restore)
        val restoredState = appJson.decodeFromString<com.akm.callbreak.domain.models.CallbreakState>(stateJson)

        // 3. Restore the room
        val restoredRoom = GameRoom(restoredState)
        GameRoomManager.restoreRoom(roomId, restoredRoom)

        val currentRoom = GameRoomManager.getRoom(roomId)
        assertNotNull(currentRoom, "Room should be restored")

        // 4. Validate that tokens survived the restore
        assertTrue(
            currentRoom.validateSessionToken(playerId, originalToken),
            "Restored room should still validate Alice's token"
        )
        assertTrue(
            currentRoom.validateSessionToken(bobId, bobToken),
            "Restored room should still validate Bob's token"
        )
        
        // Invalid tokens should still fail
        assertFalse(currentRoom.validateSessionToken(playerId, "invalid-token"))
    }
}
