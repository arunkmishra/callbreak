Role & Goal
You are an expert Flutter developer building a real-time multiplayer card game (Callbreak) for Android and iOS. Your task is to write the complete client-side code based on the architecture and feature requirements below.

1. Tech Stack & Dependencies

Framework: Flutter (latest version)

State Management: flutter_bloc and equatable

Networking: http (for REST API) and web_socket_channel (for real-time gameplay)

Animations: Flutter's native implicit animations (AnimatedPositioned, AnimatedContainer)

2. Core Data Models
   Create immutable Dart classes using equatable and factory methods for JSON serialization:

PlayingCard: string suit (Spade, Heart, Diamond, Club), string rank, int value.

Player: string id, string name, int (nullable) bid, int tricksWon.

GameState: string roomId, string phase (LOBBY, PLAYING, ROUND_OVER), list of Players, list of PlayingCards for myHand, string currentTurn (playerId), and a currentTrick object containing the ledSuit and a list of cards currently on the table.

3. Repository Layer

ApiRepository: Handles HTTP POST requests to /api/rooms/create (returns a 5-letter roomId) and /api/rooms/join (accepts a roomId).

SocketRepository: Manages a WebSocketChannel. Must include a connect(roomId, playerId) method that yields a Stream of decoded JSON, a sendAction(actionType, payload) method, and a disconnect() method.

4. State Management (BLoC)
   Implement a GameBloc that listens to the SocketRepository stream.

Events: ConnectToRoom, ServerStateUpdated (triggered by the socket stream), PlayCardAttempt (triggered by UI).

States: GameInitial, GameLoading, GameLobby (holds connected players list), GameActive (holds the full table GameState).

Rule: The BLoC must NEVER mutate the state locally when a user plays a card. It must send a PLAY_CARD action to the server and wait for the server to broadcast the new state via the WebSocket.

5. UI & Feature Requirements

Screen 1: Matchmaking (Home)

A clean UI with two main actions: "Create Game" and a text field to enter a code and "Join Game".

Screen 2: The Lobby

Displays the large 5-letter Room Code.

Displays a ListView of players currently in the room.

Shows a "Start Game" button only if 4 players are connected (this sends a START_GAME socket event).

Screen 3: The Virtual Table (Core Game)

Use a full-screen green background (Colors.green[800]).

Use a Stack widget for absolute positioning.

Opponents: Render 3 opponent avatars using Align (topCenter, centerLeft, centerRight). Show their name, tricks won / bid, and an indicator of how many cards they have left.

User's Hand: Use Align(bottomCenter). Map over the myHand array to display the cards fanned out.

Trick Zone: A center container where played cards are shown.

Animations: Wrap the PlayingCard widgets in AnimatedPositioned. When a card moves from the myHand array to the currentTrick array (driven by the server state update), it must smoothly slide from the bottom of the screen to the center of the table.

6. Implementation Instructions
   Start by generating the folder structure and the pubspec.yaml. Then, provide the code for the Data Models and the SocketRepository. Wait for my confirmation before generating the BLoC and UI screens.