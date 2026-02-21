package com.demo.account.service

import com.demo.account.model.Account
import com.demo.account.repository.AccountRepository
import com.demo.api.AccountBalanceDto
import com.demo.api.AccountDto
import com.demo.api.CreateAccountRequest
import com.demo.common.exception.ResourceNotFoundException
import com.demo.common.exception.ValidationException
import org.springframework.stereotype.Service
import java.time.Instant

@Service
class AccountService(
    private val accountRepository: AccountRepository
) {
    fun getAccount(id: String): AccountDto {
        val account = accountRepository.findById(id)
            ?: throw ResourceNotFoundException("Account", id)
        return account.toDto()
    }

    fun getAllAccounts(): List<AccountDto> {
        return accountRepository.findAll().map { it.toDto() }
    }

    fun createAccount(request: CreateAccountRequest): AccountDto {
        if (accountRepository.existsByEmail(request.email)) {
            throw ValidationException("Account with email ${request.email} already exists")
        }

        val account = Account(
            name = request.name,
            email = request.email,
            balance = request.initialBalance,
            currency = request.currency
        )

        return accountRepository.save(account).toDto()
    }

    fun getAccountBalance(id: String): AccountBalanceDto {
        val account = accountRepository.findById(id)
            ?: throw ResourceNotFoundException("Account", id)

        return AccountBalanceDto(
            accountId = account.id,
            balance = account.balance,
            currency = account.currency,
            availableBalance = account.balance,
            pendingBalance = 0.0,
            asOf = Instant.now()
        )
    }

    private fun Account.toDto() = AccountDto(
        id = id,
        name = name,
        email = email,
        balance = balance,
        currency = currency,
        status = status,
        createdAt = createdAt,
        updatedAt = updatedAt
    )
}
