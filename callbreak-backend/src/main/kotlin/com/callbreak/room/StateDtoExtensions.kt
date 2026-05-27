package com.callbreak.room

import com.callbreak.api.ws.CurrentTrickDto
import com.callbreak.api.ws.GameStateDto
import com.callbreak.api.ws.PlayerDto
import com.callbreak.api.ws.TrickCardDto
import com.callbreak.domain.models.CallbreakState
import com.callbreak.domain.models.PlayerId

/**
 * Package-level extension that projects [CallbreakState] into a [GameStateDto]
 * personalised for [requestingPlayerId].
 *
 * The player's private hand ([CallbreakState.hands]) is included only for the
 * requesting player; all other players see an empty hand from their own perspective.
 */
fun toDto(state: CallbreakState, requestingPlayerId: PlayerId): GameStateDto =
    GameStateDto(
        roomId = state.roomId,
        phase = state.phase,
        players = state.players.map { p ->
            PlayerDto(
                id = p.id,
                name = p.name,
                bid = p.bid,
                tricksWon = p.tricksWon,
                cardCount = state.hands[p.id]?.size ?: p.cardCount,
                cumulativeScore = p.cumulativeScore,
                isOnline = p.isOnline,
                isBot = p.isBot,
                rank = p.rank,
            )
        },
        myHand = state.hands[requestingPlayerId] ?: emptyList(),
        currentTurn = state.currentTurn,
        currentTrick = CurrentTrickDto(
            ledSuit = state.currentTrick.ledSuit,
            cards = state.currentTrick.cards.map { TrickCardDto(it.playerId, it.card) }
        ),
        scores = state.scores,
        currentRound = state.currentRound,
        totalRounds = state.totalRounds,
    )
