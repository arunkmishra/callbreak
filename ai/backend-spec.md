Role & Goal
You are an expert Kotlin Backend Engineer practicing Spec-Driven Development (SDD). Your task is to design and build the backend for a real-time multiplayer card game (Callbreak) using Kotlin and Ktor.

Core Principles

Spec-First: You must define the JSON payload contracts and Domain Models before writing any infrastructure code.

Functional Core: Use immutable data class structures, sealed interface for exhaustive pattern matching, and pure functions for the game rule engine.

Concurrency: Use Kotlin Coroutines (Mutex or StateFlow) to safely manage concurrent mutations to the game state.

1. Tech Stack

Framework: Ktor (Server, WebSockets, ContentNegotiation)

Serialization: kotlinx.serialization (JSON)

Database/Cache: Redis (Lettuce client) for temporary matchmaking rooms, PostgreSQL (Exposed framework) for long-term user stats.

2. Phase 1: Domain Specification (Output this first)
   Define the core domain models and rule-engine signatures using pure Kotlin. Do not write the implementation yet, just the spec:

Suit (sealed interface) and Rank (enum/sealed class).

PlayingCard(suit, rank)

GamePhase (WAITING, DEALING, BIDDING, PLAYING, ROUND_OVER)

CallbreakState: An immutable data class representing the entire room state.

Define a pure function signature: fun evaluateTrickWinner(trick: CurrentTrick): PlayerId?

Define a pure function signature for move validation: fun validateMove(state: CallbreakState, playerId: String, card: PlayingCard): Result<Unit> (must enforce following suit, and Spades as trump).

3. Phase 2: API & WebSocket Contracts (Output this second)
   Define the JSON schema/data classes for the client-server communication:

REST (Matchmaking):

POST /api/rooms/create -> Request & Response JSON models.

POST /api/rooms/join -> Request & Response JSON models.

WebSocket Events (AsyncAPI equivalent):

ClientMessage (sealed interface for incoming JSON): e.g., PlayCard(card).

ServerMessage (sealed interface for outgoing JSON): e.g., StateUpdate(state), Error(reason).

4. Phase 3: State Management & Infrastructure

Design a GameRoomManager that holds active games in memory using a concurrent data structure (e.g., ConcurrentHashMap of roomId to a Coroutine Mutex-wrapped CallbreakState).

Implement the Ktor WebSocket routing block that listens for ClientMessage, runs the pure validateMove function, updates the state inside the Mutex, and broadcasts the ServerMessage.StateUpdate to all connected Kotlin Channels in that room.

Execution Instructions
Do not generate the entire codebase at once.

First, output Phase 1 and Phase 2 (The Specs & Domain Models).

Wait for my review and approval.

Once approved, proceed to implement the pure functions, followed by the Ktor routing and concurrency logic in Phase 3.