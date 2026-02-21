package com.demo.api

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Positive
import java.time.Instant

data class TransferDto(
    val id: String,
    val fromAccountId: String,
    val toAccountId: String,
    val amount: Double,
    val currency: String,
    val status: TransferStatus,
    val description: String?,
    val createdAt: Instant,
    val completedAt: Instant?
)

data class CreateTransferRequest(
    @field:NotBlank(message = "Source account ID is required")
    val fromAccountId: String,

    @field:NotBlank(message = "Destination account ID is required")
    val toAccountId: String,

    @field:Positive(message = "Amount must be positive")
    val amount: Double,

    val currency: String = "USD",

    val description: String? = null
)

enum class TransferStatus {
    PENDING, PROCESSING, COMPLETED, FAILED, CANCELLED
}
