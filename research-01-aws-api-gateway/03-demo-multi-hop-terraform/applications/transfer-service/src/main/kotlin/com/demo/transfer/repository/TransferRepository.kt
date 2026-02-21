package com.demo.transfer.repository

import com.demo.api.TransferStatus
import com.demo.transfer.model.Transfer
import org.springframework.stereotype.Repository
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap

@Repository
class TransferRepository {
    private val transfers = ConcurrentHashMap<String, Transfer>()

    init {
        // Seed with sample data
        listOf(
            Transfer(
                id = "TRF001",
                fromAccountId = "123",
                toAccountId = "456",
                amount = 100.0,
                status = TransferStatus.COMPLETED,
                description = "Payment for services",
                completedAt = Instant.now().minusSeconds(3600)
            ),
            Transfer(
                id = "TRF002",
                fromAccountId = "456",
                toAccountId = "789",
                amount = 250.0,
                status = TransferStatus.COMPLETED,
                description = "Monthly subscription",
                completedAt = Instant.now().minusSeconds(1800)
            )
        ).forEach { transfers[it.id] = it }
    }

    fun findById(id: String): Transfer? = transfers[id]

    fun findAll(): List<Transfer> = transfers.values.toList()

    fun findByAccountId(accountId: String): List<Transfer> =
        transfers.values.filter { it.fromAccountId == accountId || it.toAccountId == accountId }

    fun save(transfer: Transfer): Transfer {
        transfers[transfer.id] = transfer
        return transfer
    }
}
