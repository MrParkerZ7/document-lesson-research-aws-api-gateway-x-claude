package com.demo.account.model

import com.demo.api.AccountStatus
import java.time.Instant
import java.util.UUID

data class Account(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val email: String,
    var balance: Double = 0.0,
    val currency: String = "USD",
    var status: AccountStatus = AccountStatus.ACTIVE,
    val createdAt: Instant = Instant.now(),
    var updatedAt: Instant = Instant.now()
)
