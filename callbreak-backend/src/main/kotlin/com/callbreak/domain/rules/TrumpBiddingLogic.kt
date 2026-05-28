package com.callbreak.domain.rules

import com.callbreak.domain.models.*

/**
 * Processes a bid or pass during the Trump Bidding phase.
 */
fun processTrumpBid(state: CallbreakState, playerId: PlayerId, bid: Int?, suit: Suit?): Result<CallbreakState> {
    if (state.phase != GamePhase.TRUMP_BIDDING) return Result.failure(Exception("Not in trump bidding phase"))
    if (state.currentTurn != playerId) return Result.failure(Exception("Not your turn"))

    val bidState = state.trumpBidState
    val nextBidder = getNextBidder(state, playerId, bidState.playersPassed)

    if (bid == null || suit == null) {
        // Player passes
        val passed = bidState.playersPassed + playerId
        
        if (passed.size == 4) {
            val firstBidder = state.players[(state.dealerIndex + state.players.size - 1) % state.players.size].id
            // Fallback: All 4 passed — use the room's configured minBid (floor of 2)
            return Result.success(state.copy(
                currentTrumpSuit = Suit.SPADE,
                minBid = maxOf(2, state.minBid ?: 2),
                trumpBidState = bidState.copy(playersPassed = passed),
                phase = GamePhase.DEALING_PHASE_2, // Move to next phase
                currentTurn = firstBidder
            ))
        } else if (passed.size == 3 && bidState.highestBidderId != null) {
            // 3 passed, 1 winner
            val winner = bidState.highestBidderId
            val winningBid = bidState.highestBid
            val winningSuit = bidState.proposedSuit!!
            
            val newBids = state.bids + (winner to winningBid)
            
            var firstBidder = state.players[(state.dealerIndex + state.players.size - 1) % state.players.size].id
            if (newBids[firstBidder] != null) {
                // First bidder already has a bid, find the next one
                var currentIndex = state.players.indexOfFirst { it.id == firstBidder }
                for (i in 1..4) {
                    currentIndex = (currentIndex + state.players.size - 1) % state.players.size
                    val candidate = state.players[currentIndex].id
                    if (newBids[candidate] == null) {
                        firstBidder = candidate
                        break
                    }
                }
            }
            
            return Result.success(state.copy(
                currentTrumpSuit = winningSuit,
                bids = newBids,
                trumpBidState = bidState.copy(playersPassed = passed),
                phase = GamePhase.DEALING_PHASE_2, // Move to next phase
                currentTurn = firstBidder
            ))
        }
        
        // Pass accepted, turn moves on
        return Result.success(state.copy(
            currentTurn = nextBidder,
            trumpBidState = bidState.copy(playersPassed = passed)
        ))
    } else {
        // Player places a bid
        if (bidState.highestBid == 0 && bid < 5) return Result.failure(Exception("Minimum opening bid is 5"))
        if (bid <= bidState.highestBid) return Result.failure(Exception("Bid must be strictly greater than current highest bid"))
        
        if (bidState.playersPassed.size == 3) {
            // 3 players have already passed, and this player just placed a bid.
            // They are the winner. End the phase.
            val newBids = state.bids + (playerId to bid)
            
            var firstBidder = state.players[(state.dealerIndex + state.players.size - 1) % state.players.size].id
            if (newBids[firstBidder] != null) {
                var currentIndex = state.players.indexOfFirst { it.id == firstBidder }
                for (i in 1..4) {
                    currentIndex = (currentIndex + state.players.size - 1) % state.players.size
                    val candidate = state.players[currentIndex].id
                    if (newBids[candidate] == null) {
                        firstBidder = candidate
                        break
                    }
                }
            }
            
            return Result.success(state.copy(
                currentTrumpSuit = suit,
                bids = newBids,
                trumpBidState = bidState.copy(
                    highestBid = bid,
                    highestBidderId = playerId,
                    proposedSuit = suit
                ),
                phase = GamePhase.DEALING_PHASE_2,
                currentTurn = firstBidder
            ))
        }

        return Result.success(state.copy(
            currentTurn = nextBidder,
            trumpBidState = bidState.copy(
                highestBid = bid,
                highestBidderId = playerId,
                proposedSuit = suit
            )
        ))
    }
}

private fun getNextBidder(state: CallbreakState, currentPlayerId: PlayerId, passedPlayers: List<PlayerId>): PlayerId {
    var currentIndex = state.players.indexOfFirst { it.id == currentPlayerId }
    for (i in 1..4) {
        currentIndex = (currentIndex + state.players.size - 1) % state.players.size
        val candidate = state.players[currentIndex].id
        if (candidate !in passedPlayers) {
            return candidate
        }
    }
    return currentPlayerId // Should theoretically only happen if all passed
}
