package com.demo.transfer.controller

import com.demo.api.CreateTransferRequest
import com.demo.api.TransferDto
import com.demo.transfer.service.TransferService
import jakarta.validation.Valid
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

/**
 * Transfer Controller
 *
 * NOTE: This controller uses clean REST paths (/api/v1/transfers/*)
 * The service prefix (/transfer-svc) is handled by the servlet context-path
 * configured via SERVER_SERVLET_CONTEXT_PATH environment variable.
 *
 * Path flow:
 * 1. API Gateway receives: POST /transfers
 * 2. API Gateway rewrites to: POST /transfer-svc/api/v1/transfers
 * 3. ALB routes based on: /transfer-svc/*
 * 4. Spring Boot (with context-path=/transfer-svc) handles: /api/v1/transfers
 */
@RestController
@RequestMapping("/api/v1/transfers")
class TransferController(
    private val transferService: TransferService
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    @GetMapping
    fun getAllTransfers(): ResponseEntity<List<TransferDto>> {
        logger.info("GET /api/v1/transfers - Fetching all transfers")
        return ResponseEntity.ok(transferService.getAllTransfers())
    }

    @GetMapping("/{transferId}")
    fun getTransfer(@PathVariable transferId: String): ResponseEntity<TransferDto> {
        logger.info("GET /api/v1/transfers/{} - Fetching transfer", transferId)
        return ResponseEntity.ok(transferService.getTransfer(transferId))
    }

    @PostMapping
    fun createTransfer(
        @Valid @RequestBody request: CreateTransferRequest
    ): ResponseEntity<TransferDto> {
        logger.info(
            "POST /api/v1/transfers - Creating transfer from {} to {} for {} {}",
            request.fromAccountId, request.toAccountId, request.amount, request.currency
        )
        val transfer = transferService.createTransfer(request)
        return ResponseEntity.status(HttpStatus.CREATED).body(transfer)
    }

    @GetMapping("/account/{accountId}")
    fun getTransfersByAccount(@PathVariable accountId: String): ResponseEntity<List<TransferDto>> {
        logger.info("GET /api/v1/transfers/account/{} - Fetching transfers for account", accountId)
        return ResponseEntity.ok(transferService.getTransfersByAccount(accountId))
    }
}
