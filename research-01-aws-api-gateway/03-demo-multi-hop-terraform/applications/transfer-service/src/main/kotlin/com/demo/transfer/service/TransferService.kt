package com.demo.transfer.service

import com.demo.api.CreateTransferRequest
import com.demo.api.TransferDto
import com.demo.api.TransferStatus
import com.demo.common.exception.ResourceNotFoundException
import com.demo.common.exception.ValidationException
import com.demo.transfer.model.Transfer
import com.demo.transfer.repository.TransferRepository
import org.springframework.stereotype.Service
import java.time.Instant

@Service
class TransferService(
    private val transferRepository: TransferRepository
) {
    fun getTransfer(id: String): TransferDto {
        val transfer = transferRepository.findById(id)
            ?: throw ResourceNotFoundException("Transfer", id)
        return transfer.toDto()
    }

    fun getAllTransfers(): List<TransferDto> {
        return transferRepository.findAll().map { it.toDto() }
    }

    fun createTransfer(request: CreateTransferRequest): TransferDto {
        if (request.fromAccountId == request.toAccountId) {
            throw ValidationException("Source and destination accounts cannot be the same")
        }

        val transfer = Transfer(
            fromAccountId = request.fromAccountId,
            toAccountId = request.toAccountId,
            amount = request.amount,
            currency = request.currency,
            description = request.description,
            status = TransferStatus.COMPLETED, // Simplified - in reality would be async
            completedAt = Instant.now()
        )

        return transferRepository.save(transfer).toDto()
    }

    fun getTransfersByAccount(accountId: String): List<TransferDto> {
        return transferRepository.findByAccountId(accountId).map { it.toDto() }
    }

    private fun Transfer.toDto() = TransferDto(
        id = id,
        fromAccountId = fromAccountId,
        toAccountId = toAccountId,
        amount = amount,
        currency = currency,
        status = status,
        description = description,
        createdAt = createdAt,
        completedAt = completedAt
    )
}
