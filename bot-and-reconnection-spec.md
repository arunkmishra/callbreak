# Spec 04: Bot AI Logic & Session Reconnection

## 1. Session Reconnection Flow
* **REST API Update:** The `POST /api/rooms/join` endpoint must return a `sessionToken` (UUID) alongside the `roomId` and `playerId`.
* **WebSocket Handshake:** When the client opens the WebSocket, they must pass the `sessionToken` for authentication.
* **Disconnection Handling:** If a WebSocket drops, the Ktor server must catch the exception. The `GameRoomManager` must NOT remove the player from the `CallbreakState`. Instead, mark `PlayerState.isOnline = false`.
* **Reconnection:** If a client reconnects with a valid `sessionToken`, the server marks `isOnline = true` and immediately broadcasts a `StateUpdate` to them so their UI resyncs.

## 2. Filling Empty Seats with Bots (Lobby)
* When the host clicks "Start Game", if the room has fewer than 4 human players, the server must automatically generate Bot players to fill the remaining seats.
* Bots have an ID prefixed with `bot_` (e.g., `bot_1`, `bot_2`) and `PlayerState.isBot = true`.

## 3. Mid-Game Bot Takeover
* **The Timer:** If `PlayerState.isOnline == false` during their active turn, the server starts a 60-second asynchronous coroutine timer.
* **The Takeover:** Upon expiration, the server updates `PlayerState.isBot = true` and suffixes `(Bot)` to their display name. It then instantly runs the Bot AI play logic for the current turn.
* **Hot-Swapping:** If a human reconnects post-takeover using their `sessionToken`, the server allows them to hot-swap back into control, setting `isBot = false`, removing the `(Bot)` tag, and giving them control at the start of the next trick.

## 4. Bot AI: Bidding Algorithm
When it is a bot's turn to bid, use this pure function logic to calculate their bid:
1. Base bid = `1` (Minimum bid in Callbreak).
2. For Spades (Trump): Add `1` for the Ace, add `1` for the King, add `1` for the Queen.
3. For Other Suits: Add `1` for each Ace.
4. Total these up and submit the bid. *(Example: Bot holds Ace of Spades, King of Spades, and Ace of Hearts -> Bid is 3 + 1 base = 4).*

## 5. Bot AI: Play Card Algorithm (Greedy "Play to Win")
When it is a bot's turn to play a card, the server must calculate the optimal move using this algorithm:

**Step 1: Get Legal Moves**
* Filter the bot's hand using the `validateMove` function. This gives a list of strictly legal cards they are allowed to play.

**Step 2: Leading the Trick (Table is empty)**
* If the trick is empty, the bot must lead. 
* *Logic:* Play the highest available card in their hand that is NOT a Spade (e.g., an Ace of Hearts). If they only have Spades, play the lowest Spade.

**Step 3: Following (Cards are on the table)**
* Divide the `legalCards` into two groups based on the `evaluateTrickWinner` function: 
  * `winningCards`: Cards that, if played, would currently win the trick.
  * `losingCards`: Cards that cannot win the trick.
* **The Decision:**
  * If `winningCards` is NOT empty: The bot must play the **lowest ranked** card inside the `winningCards` list. *(Why: Win the trick as cheaply as possible, saving high cards for later).*
  * If `winningCards` IS empty: The bot must play the **lowest ranked** card inside the `losingCards` list. *(Why: If you are going to lose anyway, throw away your worst card).*

## 6. Execution Trigger
* The server must detect when `state.currentTurn` points to a player where `isBot == true`. 
* When it does, the server pauses for `1000ms` (using a non-blocking Coroutine `delay`) to simulate human "thinking" time so the UI isn't instantaneous, executes the Bot AI algorithms above, and processes the move.
