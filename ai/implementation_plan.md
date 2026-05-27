# Callbreak — Implementation Plan

## Background

Callbreak is a 4-player, trick-taking card game where **Spades are always trump**. Each player bids how many tricks they'll win per round. The server is the single source of truth; the client never mutates state locally.

This plan follows the **Spec-Driven Development** approach defined in `master.md`, progressing through each step with explicit approval gates.

---

## Step 1: Contract Analysis

### REST Endpoints

| Endpoint | Method | Request Body | Response Body |
|---|---|---|---|
| `/api/rooms/create` | POST | `{ playerName: String }` | `{ roomId: String (5-letter), playerId: String }` |
| `/api/rooms/join` | POST | `{ roomId: String, playerName: String }` | `{ roomId: String, playerId: String }` |

### WebSocket Events

**WebSocket URL**: `ws://<host>/ws/rooms/{roomId}?playerId={playerId}`

#### Client → Server (`ClientMessage`)

| Action Type | Payload |
|---|---|
| `START_GAME` | `{}` |
| `PLACE_BID` | `{ bid: Int }` |
| `PLAY_CARD` | `{ suit: String, rank: String }` |

#### Server → Client (`ServerMessage`)

| Event Type | Payload |
|---|---|
| `STATE_UPDATE` | Full `GameState` object (see below) |
| `ERROR` | `{ reason: String }` |

### Shared `GameState` JSON Schema

```json
{
  "roomId": "ABCDE",
  "phase": "LOBBY | BIDDING | PLAYING | ROUND_OVER",
  "players": [
    { "id": "uuid", "name": "Alice", "bid": 3, "tricksWon": 1, "cardCount": 13 }
  ],
  "myHand": [
    { "suit": "Spade", "rank": "A", "value": 14 }
  ],
  "currentTurn": "playerId",
  "currentTrick": {
    "ledSuit": "Heart",
    "cards": [
      { "playerId": "uuid", "card": { "suit": "Heart", "rank": "K", "value": 13 } }
    ]
  },
  "scores": { "playerId": 0 }
}
```

---

### ⚠️ Discrepancies Found Between Backend & Frontend Specs

| # | Issue | Backend Spec | Frontend Spec | Resolution |
|---|---|---|---|---|
| 1 | **Game Phases** | `WAITING, DEALING, BIDDING, PLAYING, ROUND_OVER` | `LOBBY, PLAYING, ROUND_OVER` | **Merge**: Use `LOBBY, BIDDING, PLAYING, ROUND_OVER` — DEALING is transient, WAITING → LOBBY |
| 2 | **Bidding Phase** | `BIDDING` is an explicit phase | Frontend has no `BIDDING` state | **Add** `GameBidding` BLoC state and `BIDDING` phase to Flutter |
| 3 | **Player Model** | No `cardCount` field defined | Frontend shows card count for opponents | **Add** `cardCount: Int` to the `Player` model on both sides |
| 4 | **Room Code** | No explicit format stated | Frontend expects a **5-letter** roomId | **Standardize**: Backend generates exactly a 5-letter uppercase roomId |
| 5 | **WebSocket URL** | Not specified | `connect(roomId, playerId)` implies query param | **Define**: `ws://<host>/ws/rooms/{roomId}?playerId={playerId}` |
| 6 | **Scores field** | Not in specs | Implicit from game rules | **Add**: `scores: Map<String, Int>` to `CallbreakState` and `GameState` |

---

## Step 2: Project Scaffolding

```
callbreak/
├── ai/                                 # Specification files (existing)
│   ├── master.md
│   ├── backend-spec.md
│   ├── frontend-spec.md
│   └── implementation_plan.md
│
├── callbreak-backend/                  # Kotlin/Ktor backend
│   ├── build.gradle.kts
│   ├── settings.gradle.kts
│   └── src/main/kotlin/com/callbreak/
│       ├── Application.kt
│       ├── domain/
│       │   ├── models/
│       │   │   ├── Card.kt             # Suit, Rank, PlayingCard
│       │   │   ├── Player.kt
│       │   │   └── GameState.kt        # CallbreakState, GamePhase, CurrentTrick
│       │   └── rules/
│       │       ├── TrickEvaluator.kt   # evaluateTrickWinner()
│       │       └── MoveValidator.kt    # validateMove()
│       ├── api/
│       │   ├── rest/
│       │   │   ├── RoomController.kt
│       │   │   └── RoomModels.kt
│       │   └── ws/
│       │       ├── ClientMessage.kt
│       │       └── ServerMessage.kt
│       ├── room/
│       │   ├── GameRoomManager.kt      # ConcurrentHashMap + Mutex
│       │   └── GameRoom.kt
│       └── plugins/
│           ├── Routing.kt
│           ├── Serialization.kt
│           └── WebSockets.kt
│
└── callbreak-client/                   # Flutter frontend
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── core/
        │   ├── constants.dart
        │   └── theme.dart
        ├── data/
        │   ├── models/
        │   │   ├── playing_card.dart
        │   │   ├── player.dart
        │   │   └── game_state.dart
        │   └── repositories/
        │       ├── api_repository.dart
        │       └── socket_repository.dart
        ├── bloc/
        │   ├── game_bloc.dart
        │   ├── game_event.dart
        │   └── game_state.dart
        └── ui/
            ├── screens/
            │   ├── home_screen.dart
            │   ├── lobby_screen.dart
            │   ├── bidding_screen.dart
            │   └── game_screen.dart
            └── widgets/
                ├── playing_card_widget.dart
                ├── opponent_widget.dart
                └── trick_zone_widget.dart
```

---

## Step 3: Backend Domain — Phase 1 & 2 Design

### Phase 1: Domain Models & Rule Engine Signatures

**Card.kt**
```kotlin
sealed interface Suit {
    object Spade : Suit   // Trump suit
    object Heart : Suit
    object Diamond : Suit
    object Club : Suit
}

enum class Rank(val value: Int) {
    TWO(2), THREE(3), FOUR(4), FIVE(5), SIX(6), SEVEN(7),
    EIGHT(8), NINE(9), TEN(10), JACK(11), QUEEN(12), KING(13), ACE(14)
}

data class PlayingCard(val suit: Suit, val rank: Rank)
```

**GameState.kt**
```kotlin
typealias PlayerId = String

enum class GamePhase { LOBBY, BIDDING, PLAYING, ROUND_OVER }

data class TrickCard(val playerId: PlayerId, val card: PlayingCard)

data class CurrentTrick(val ledSuit: Suit?, val cards: List<TrickCard>)

data class CallbreakState(
    val roomId: String,
    val phase: GamePhase,
    val players: List<Player>,
    val hands: Map<PlayerId, List<PlayingCard>>,  // server-only; filtered before sending to client
    val bids: Map<PlayerId, Int>,
    val tricksWon: Map<PlayerId, Int>,
    val scores: Map<PlayerId, Int>,
    val currentTurn: PlayerId?,
    val currentTrick: CurrentTrick,
    val roundNumber: Int
)
```

**Pure function signatures**
```kotlin
// Returns winning PlayerId, or null if trick is empty
fun evaluateTrickWinner(trick: CurrentTrick): PlayerId?

// Result.success(Unit) if legal, Result.failure(IllegalMoveException) otherwise
// Rules: correct turn, card in hand, follow-suit if able, Spades as trump
fun validateMove(state: CallbreakState, playerId: PlayerId, card: PlayingCard): Result<Unit>
```

### Phase 2: API & WebSocket Contracts

**REST Models (RoomModels.kt)**
```kotlin
@Serializable data class CreateRoomRequest(val playerName: String)
@Serializable data class CreateRoomResponse(val roomId: String, val playerId: String)
@Serializable data class JoinRoomRequest(val roomId: String, val playerName: String)
@Serializable data class JoinRoomResponse(val roomId: String, val playerId: String)
```

**ClientMessage.kt**
```kotlin
@Serializable
sealed interface ClientMessage {
    @SerialName("START_GAME")  object StartGame : ClientMessage
    @SerialName("PLACE_BID")   data class PlaceBid(val bid: Int) : ClientMessage
    @SerialName("PLAY_CARD")   data class PlayCard(val suit: String, val rank: String) : ClientMessage
}
```

**ServerMessage.kt**
```kotlin
@Serializable
sealed interface ServerMessage {
    @SerialName("STATE_UPDATE") data class StateUpdate(val state: GameStateDto) : ServerMessage
    @SerialName("ERROR")        data class Error(val reason: String) : ServerMessage
}
```

---

## Step 4: Flutter Client — Phased Rollout

| Phase | Deliverable |
|---|---|
| **A** | Data models + ApiRepository + SocketRepository |
| **B** | GameBloc (events, states, stream wiring) |
| **C** | UI Screens: Home → Lobby → Bidding → Game Table |

---

## Execution Roadmap

| Phase | Component | Status |
|---|---|---|
| Step 1 | Contract Analysis | ✅ Done (this doc) |
| Step 2 | Directory Scaffolding | ⏳ Awaiting approval |
| Step 3 | Backend Domain Models (Ph 1 & 2) | ⏳ Awaiting scaffolding approval |
| Step 4 | Backend Infra (Ph 3) | ⏳ Awaiting domain approval |
| Step 5 | Flutter Data Layer (Ph A) | ⏳ Awaiting backend Ph 1 & 2 approval |
| Step 6 | Flutter BLoC (Ph B) | ⏳ Awaiting Flutter Ph A approval |
| Step 7 | Flutter UI (Ph C) | ⏳ Awaiting Flutter Ph B approval |

---

## Open Questions

> [!IMPORTANT]
> **Q1 — Authentication**: Should there be user auth (JWT/sessions), or is the ephemeral `playerId` returned at room creation sufficient?

> [!IMPORTANT]
> **Q2 — Persistence**: Wire up PostgreSQL from the start for long-term stats, or begin with pure in-memory state and add DB later?

> [!IMPORTANT]
> **Q3 — Scoring Rules**: Standard Callbreak: meet bid → earn `bid` points; miss bid → lose `bid` points; each overtrick (break) → +0.1. Is this the variant you want?

> [!NOTE]
> **Q4 — Multi-round**: Standard game = 5 rounds. Should the round count be configurable at room creation?

> [!NOTE]
> **Q5 — Platform**: Flutter targets Android & iOS. Should we also configure Flutter Web?
