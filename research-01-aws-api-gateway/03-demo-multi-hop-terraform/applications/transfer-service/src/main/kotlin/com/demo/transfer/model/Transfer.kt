package com.demo.transfer.model

import com.demo.api.TransferStatus
import java.time.Instant
import java.util.UUID

data class Transfer(
    val id: String = UUID.randomUUID().toString(),
    val fromAccountId: String,
    val toAccountId: String,
    val amount: Double,
    val currency: String = "USD",
    var status: TransferStatus = TransferStatus.PENDING,
    val description: String? = null,
    val createdAt: Instant = Instant.now(),
    var completedAt: Instant? = null
)
