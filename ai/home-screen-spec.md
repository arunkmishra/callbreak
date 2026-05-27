Context & Goal
We are expanding our Flutter client (03-frontend-fl.md) to include a polished navigation system, a feature-rich HomeScreen, and in-game safety controls.

1. Architectural Update: Navigation

Please implement go_router (or Flutter's standard Navigator) to manage screen transitions cleanly.

Routes: / (Home), /lobby/:roomId (Waiting Room), /table/:roomId (Active Game), /post-match (Final Scoreboard).

2. Feature: The HomeScreen UI
Design a modern, engaging HomeScreen widget with the following layout:

Header: A sleek Callbreak logo/typography.

Primary Action 1: "Practice vs Bots" >   * Logic: Tapping this hits the API to create a room, joins it, and immediately sends a START_GAME socket event. The server will automatically fill the empty seats with bots, bypassing the lobby and dropping the user straight onto the table.

Primary Action 2: "Host Multiplayer"

Logic: Creates a room and pushes to the /lobby route so the user can see the room code and wait for friends.

Primary Action 3: "Join Game"

Logic: A text field for a 5-letter code and a "Join" button.

Bottom Action Bar (Creative Polish): Add small icon buttons for "Profile/Stats" (showing total wins), "How to Play" (a simple rules popup), and "Settings".

3. Feature: In-Game Navigation & Safe Exits
We must never trap the user on the game table.

Add a small AppBar or a floating hamburger menu on the TableScreen.

Include a "Leave Match" button.

UX Safety: Tapping it must show an AlertDialog: "Are you sure you want to leave? A bot will take over your seat, and you may lose points."

Exit Logic: If confirmed, the app must call socketRepository.disconnect(), reset the GameBloc state to GameInitial, and route the user back to / (Home).

4. Feature: Settings & Customization (Creative Polish)

Create a simple SettingsSheet (a bottom sheet) accessible from the Home screen.

Include a toggle for "Sound Effects" (Card sliding/flipping sounds).

Include a "Table Felt Color" picker (Classic Green, Casino Red, Midnight Blue). The TableScreen should read this preference and update its background color accordingly.

Action Required:

Write the Dart code for the Router configuration.

Write the Dart code for the HomeScreen UI, wiring up the buttons to the existing GameBloc.

Write the Dart code for the Leave Match Dialog and the updated TableScreen AppBar.

Wait for my approval before modifying the GameBloc to support these new transitions.

Why these creative additions matter:
The "Practice vs Bots" Flow: By routing this through your server instead of building a separate "offline mode," you ensure the user is playing against the exact same AI and game engine rules as your multiplayer mode. It saves you from writing the game engine twice (once in Kotlin, once in Dart).

The Confirmation Dialog: Mobile users swipe and tap accidentally all the time. Warning them that a bot will take over their seat prevents rage-quitting by accident.

Table Customization: Letting a user change the felt color to "Midnight Blue" takes 10 minutes to code in Flutter, but instantly makes the app feel premium and personalized.
