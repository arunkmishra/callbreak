Context & Goal
We are updating our Callbreak Kotlin Backend using Spec-Driven Development. We need to implement configurable multi-round matches, score calculations, and automated round transitions.

1. API & Domain Model Updates
Update the previous specifications with the following changes:

REST API: Modify POST /api/rooms/create to accept a totalRounds: Int property in the request payload (default to 5).

GamePhase: Add a ROUND_OVER phase (used for the 5-second scoreboard intermission).

CallbreakState: Add currentRound: Int (starting at 1) and totalRounds: Int.

PlayerState: Ensure it tracks bid: Int?, tricksWon: Int (for the current round), and cumulativeScore: Double (across all rounds).

2. Game Engine Rules (Pure Logic)
Write a new pure function fun resolveRound(state: CallbreakState): CallbreakState. This function is called when the 13th trick of a round is completed. It must:

Calculate Scores: For each player, apply standard Callbreak scoring:

If tricksWon >= bid: Points gained = bid + ((tricksWon - bid) * 0.1). (e.g., Bid 3, won 4 = 3.1 points).

If tricksWon < bid: Points lost = -bid. (e.g., Bid 3, won 2 = -3.0 points).

Add these points to the player's cumulativeScore.

Transition State: >     * If currentRound < totalRounds, set phase to ROUND_OVER.

If currentRound == totalRounds, set phase to GAME_OVER and sort the players by cumulativeScore descending to determine final rankings.

3. Server/Ktor Infrastructure (Side Effects)
When wiring this to the Ktor WebSocket manager (in Phase 3), you must implement the 5-second intermission gracefully using Coroutines.

When the state transitions to ROUND_OVER, the server must broadcast this state to all clients (so their UI can render the scoreboard).

The server must then launch a Coroutine that calls delay(5000).

After the delay, the server must automatically increment currentRound, reset player hands/bids/tricks, transition the phase to DEALING, shuffle a new deck, deal 13 cards, and broadcast the new state.

Action Required

Output the updated Domain Models (Data Classes) to reflect these new fields.

Output the pure Kotlin code for resolveRound and its corresponding scoring math.

Output the Ktor WebSocket snippet showing how you will handle the delay(5000) side-effect without blocking the main game loop.
Wait for my approval before proceeding.
