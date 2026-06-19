package com.akm.callbreak.api.rest

import com.akm.callbreak.services.SupabaseService
import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.authenticate
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.principal
import io.ktor.server.application.call
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.route
import io.ktor.server.request.receive
import kotlinx.serialization.Serializable

@Serializable
data class PurchaseRequest(val itemId: String)

@Serializable
data class RewardRequest(val amount: Int)

fun Route.storeRoutes() {
    route("/api/store") {

        // GET /api/store/items
        get("/items") {
            val items = SupabaseService.getStoreItems()
            call.respond(HttpStatusCode.OK, items)
        }

        authenticate("auth-jwt") {
            // POST /api/store/purchase
            post("/purchase") {
                val principal = call.principal<JWTPrincipal>()
                val userId = principal?.payload?.subject
                    ?: return@post call.respond(HttpStatusCode.Unauthorized)

                val request = try {
                    call.receive<PurchaseRequest>()
                } catch (e: Exception) {
                    return@post call.respond(HttpStatusCode.BadRequest, "Invalid request format")
                }

                val newWallet = SupabaseService.purchaseItem(userId, request.itemId)
                if (newWallet != null) {
                    call.respond(HttpStatusCode.OK, newWallet)
                } else {
                    call.respond(HttpStatusCode.BadRequest, "Purchase failed: Insufficient coins or item not found")
                }
            }

            // POST /api/store/reward-ad
            post("/reward-ad") {
                val principal = call.principal<JWTPrincipal>()
                val userId = principal?.payload?.subject
                    ?: return@post call.respond(HttpStatusCode.Unauthorized)

                val req = try {
                    call.receive<RewardRequest>()
                } catch (e: Exception) {
                    RewardRequest(10) // default to 10 if missing
                }

                val newWallet = SupabaseService.rewardAd(userId, req.amount)
                if (newWallet != null) {
                    call.respond(HttpStatusCode.OK, newWallet)
                } else {
                    call.respond(HttpStatusCode.InternalServerError, "Reward failed")
                }
            }
        }
    }
}
