# Callbreak Multiplayer Game

A real-time multiplayer Callbreak card game. It features a Kotlin Ktor backend and a cross-platform Flutter frontend (supporting Web, macOS, iOS, and Android). 

## Features

* **Real-time Multiplayer:** Play against other humans over WebSockets.
* **Cross-Platform:** The frontend is built with Flutter and runs on Web, macOS desktop, iOS, and Android.
* **Bot AI:** 
  * Play against bots if you want a single-player experience.
  * Bots automatically fill empty seats when a game starts.
  * **Mid-Game Bot Takeover:** If a player disconnects, a bot will automatically take over their turn after a 60-second timeout to keep the game moving. The human player can seamlessly hot-swap back in upon reconnecting.

## Architecture

* **Backend**: Kotlin with Ktor, utilizing WebSockets for real-time state synchronization.
* **Frontend**: Flutter using BLoC for state management.

## Prerequisites

* **Java 17+** (Required for compiling the Kotlin backend)
* **Flutter SDK** (Required for the frontend client)
* **Mobile Toolchains (Optional):** Android Studio (for Android emulators) or Xcode (for iOS simulators/devices) if you wish to run the app natively on mobile.

---

## 1. Running the Backend

The backend server manages all game rooms, lobbies, and Bot AI logic via WebSocket synchronization.

Open a terminal and navigate to the backend directory:
```bash
cd callbreak-backend
```

Run the server using Gradle:
```bash
./gradlew run
```

The server will start locally at `http://0.0.0.0:8080`.

---

## 2. Running the Frontend

The frontend is a Flutter app. Open a new terminal and navigate to the client directory:
```bash
cd callbreak-client
```

Run the Flutter app on your preferred platform.

**Run on Web (Chrome):**
```bash
flutter run -d chrome
```

**Run on macOS Desktop:**
```bash
flutter run -d macos
```

**Run on iOS / Android:**
*(Requires Xcode / Android Studio to be installed respectively)*
```bash
flutter run
```
Select the connected device or emulator when prompted.

---

## How to Play/Test Locally

To test a full multiplayer game yourself (e.g., using Chrome):
1. Ensure both the backend and frontend are running.
2. Open **4 separate Google Chrome tabs** pointing to the local Flutter web URL (usually `http://localhost:<random_port>` given by the flutter console).
3. In the first tab, enter a name and click **Create Game**. Note the 5-letter Room Code.
4. In the other tabs, enter different names, type in the Room Code, and click **Join Game**.
5. Once players are in the lobby, the host (tab 1) clicks **Start Game**.
6. Place your bids.
7. During the Playing phase, the player whose name is glowing in **Gold** is the active player whose turn it is to select a card.

**Testing Bot AI:**
You can start a game with fewer than 4 players. Any empty seats will be automatically filled with AI Bots when the host clicks "Start Game". To test Bot Takeover, simply close one of the browser tabs mid-game and wait 60 seconds; a bot will take over for the disconnected player.
