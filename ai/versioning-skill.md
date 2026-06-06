# Antigravity AI Versioning Skill

**Context & Architecture:**
This repository uses a custom "Protocol Versioning" architecture designed specifically for the Callbreak multiplayer game. 
Because Callbreak relies heavily on synchronized game state across multiple clients via WebSockets, we **cannot** allow clients with differing game logic to play together (it would cause silent desyncs and crash the game). 

To solve this while keeping backend maintenance extremely simple, we **only ever support exactly one protocol version at a time**. 

When a breaking change is released:
1. The backend increments its minimum supported protocol version.
2. If an old client connects, the Ktor backend instantly rejects the WebSocket connection with `CloseReason.Codes.VIOLATED_POLICY` and a specific string message: `FORCE_UPDATE_REQUIRED`.
3. The Flutter client (`SocketRepository`) intercepts this exact close reason, wraps it in a `ServerError`, and passes it to the `GameBloc`.
4. The Flutter UI (`home_screen.dart`, `game_screen.dart`, `lobby_screen.dart`) listens for this specific error message and displays an un-dismissable, blocking "Update Required" dialog, forcing the user to visit the Google Play Store to download the latest app.

---

**Rule:** Whenever you (Antigravity AI) make a code change to this repository, you MUST evaluate the change and follow these guidelines before pushing code or marking a feature as "done".

## Step 1: Deep Analysis of the Change
Analyze the code you just wrote and classify it as **Breaking** or **Non-Breaking**.

### Examples of Non-Breaking Changes (NO version bump needed):
* **Flutter UI Tweaks:** Changing button colors, padding, adding new screens that don't affect gameplay, fixing local animation glitches.
* **Backend Performance:** Optimizing database queries in Supabase, refactoring Kotlin functions without changing their output.
* **Non-Destructive Database Additions:** Adding a new optional column to a table that doesn't strictly affect the core game loop.

### Examples of Breaking Changes (VERSION BUMP REQUIRED):
* **WebSocket Schema Changes:** Renaming variables, adding required fields, or changing data types in `ClientMessage.kt` or `ServerMessage.kt` (and their Dart equivalents).
* **Game Logic/Rules:** Changing scoring logic (e.g., how the greed penalty is calculated), modifying how trumps are selected, or changing the structure of the `GameState` object.
* **Matchmaking:** Adding new matchmaking parameters or changing the connection URL structure.

## Step 2: Apply the Version Bump (If Breaking)
If the change is **Non-Breaking**, do nothing regarding versioning. Proceed as normal.

If the change is **Breaking**, you MUST execute all of the following steps:

1. **Update the Flutter Client Protocol:**
   - File: `callbreak-client/lib/data/repositories/socket_repository.dart`
   - Action: Find `static const int APP_PROTOCOL_VERSION = <number>;` and increment it by 1.

2. **Update the Ktor Backend Protocol:**
   - File 1: `callbreak-backend/.env`
   - File 2: `callbreak-backend/.env.example`
   - Action: Find `MIN_SUPPORTED_PROTOCOL=<number>` and increment it to match the new client version.
   *(Note: The backend reads this via `getEnvOrNull("MIN_SUPPORTED_PROTOCOL")` in `Routing.kt`).*

3. **Notify the User in your Summary:**
   - Explicitly mention in your final response to the user that your recent changes were **Breaking** and you have bumped the Protocol Version.
   - Remind the user that to deploy these changes successfully, they MUST:
     1. Build and release the new Flutter app version to the Google Play Store.
     2. Update their production environment variables (e.g., on Render or AWS) to reflect the new `MIN_SUPPORTED_PROTOCOL`.
     3. Restart the Ktor backend.

By strictly adhering to this skill, you guarantee that we maintain a single, pristine active version without fragmenting the matchmaking pool or causing invisible game-breaking desyncs between mixed client versions.
