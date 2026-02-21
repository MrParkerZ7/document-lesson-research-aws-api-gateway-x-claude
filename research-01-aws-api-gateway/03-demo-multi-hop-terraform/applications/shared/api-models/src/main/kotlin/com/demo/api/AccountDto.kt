package com.demo.api

import jakarta.validation.constraints.Email
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.PositiveOrZero
import java.time.Instant

data class AccountDto(
    val id: String,
    val name: String,
    val email: String,
    val balance: Double,
    val currency: String = "USD",
    val status: AccountStatus = AccountStatus.ACTIVE,
    val createdAt: Instant,
    val updatedAt: Instant
)

data class CreateAccountRequest(
    @field:NotBlank(message = "Name is required")
    val name: String,

    @field:NotBlank(message = "Email is required")
    @field:Email(message = "Invalid email format")
    val email: String,

    @field:PositiveOrZero(message = "Initial balance must be zero or positive")
    val initialBalance: Double = 0.0,

    val currency: String = "USD"
)

data class AccountBalanceDto(
    val accountId: String,
    val balance: Double,
    val currency: String,
    val availableBalance: Double,
    val pendingBalance: Double = 0.0,
    val asOf: Instant
)

enum class AccountStatus {
    ACTIVE, SUSPENDED, CLOSED
}
