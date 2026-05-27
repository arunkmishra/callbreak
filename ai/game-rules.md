Context & Goal
We are building the pure Kotlin game engine for Callbreak using Spec-Driven Development. You need to implement the validateMove and evaluateTrickWinner functions.

We are using the Strict Traditional Rules. This means a player is not just forced to follow suit, they are forced to try and win the trick if they have the cards to do so.

Definitions

Trick: A single round where 4 players drop one card.

Led Suit: The suit of the first card played in the trick.

Trump Suit: Spades (♠).

Rank Order: Ace (high) > K > Q > J > 10 > 9 > 8 > 7 > 6 > 5 > 4 > 3 > 2 (low).

Winning Card: The card currently on the table that would win the trick if no more cards were played.

Rule 1: Move Validation (validateMove logic)
You must enforce this exact priority order. The first condition a player meets dictates their legal moves:

Priority 1: Follow Suit & Win: If the player has cards of the Led Suit, they MUST play one. Crucially: If they hold a card of the Led Suit that is ranked higher than the current Winning Card on the table, they MUST play a card that beats it.

Priority 2: Follow Suit (Forced Loss): If they have the Led Suit, but none of their cards are high enough to beat the current Winning Card, they must still play a card of the Led Suit (effectively throwing away a low card).

Priority 3: Trump & Win: If the player has NO cards of the Led Suit, they MUST play a Spade. Crucially: If another player has already played a Spade, and this player holds a higher Spade, they MUST play it to beat them.

Priority 4: Trump (Forced Loss): If they have NO cards of the Led Suit, they must play a Spade even if their Spade is lower than a Spade already on the table.

Priority 5: Discard: If and ONLY if the player has NO cards of the Led Suit AND NO Spades, they may play any card of their choice.

Rule 2: Determining the Winner (evaluateTrickWinner logic)

Only two suits can win a trick: The Led Suit or Spades.

If any Spades were played, the highest-ranked Spade wins.

If no Spades were played, the highest-ranked card matching the Led Suit wins.
