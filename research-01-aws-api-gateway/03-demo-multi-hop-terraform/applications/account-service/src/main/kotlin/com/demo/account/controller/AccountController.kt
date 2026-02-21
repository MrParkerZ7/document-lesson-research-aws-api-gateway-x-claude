package com.demo.account.controller

import com.demo.account.service.AccountService
import com.demo.api.AccountBalanceDto
import com.demo.api.AccountDto
import com.demo.api.CreateAccountRequest
import jakarta.validation.Valid
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

/**
 * Account Controller
 *
 * NOTE: This controller uses clean REST paths (/api/v1/accounts/*)
 * The service prefix (/account-svc) is handled by the servlet context-path
 * configured via SERVER_SERVLET_CONTEXT_PATH environment variable.
 *
 * Path flow:
 * 1. API Gateway receives: GET /accounts/123
 * 2. API Gateway rewrites to: GET /account-svc/api/v1/accounts/123
 * 3. ALB routes based on: /account-svc/*
 * 4. Spring Boot (with context-path=/account-svc) handles: /api/v1/accounts/123
 */
@RestController
@RequestMapping("/api/v1/accounts")
class AccountController(
    private val accountService: AccountService
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    @GetMapping
    fun getAllAccounts(): ResponseEntity<List<AccountDto>> {
        logger.info("GET /api/v1/accounts - Fetching all accounts")
        return ResponseEntity.ok(accountService.getAllAccounts())
    }

    @GetMapping("/{accountId}")
    fun getAccount(@PathVariable accountId: String): ResponseEntity<AccountDto> {
        logger.info("GET /api/v1/accounts/{} - Fetching account", accountId)
        return ResponseEntity.ok(accountService.getAccount(accountId))
    }

    @PostMapping
    fun createAccount(
        @Valid @RequestBody request: CreateAccountRequest
    ): ResponseEntity<AccountDto> {
        logger.info("POST /api/v1/accounts - Creating account for: {}", request.email)
        val account = accountService.createAccount(request)
        return ResponseEntity.status(HttpStatus.CREATED).body(account)
    }

    @GetMapping("/{accountId}/balance")
    fun getAccountBalance(@PathVariable accountId: String): ResponseEntity<AccountBalanceDto> {
        logger.info("GET /api/v1/accounts/{}/balance - Fetching balance", accountId)
        return ResponseEntity.ok(accountService.getAccountBalance(accountId))
    }
}
