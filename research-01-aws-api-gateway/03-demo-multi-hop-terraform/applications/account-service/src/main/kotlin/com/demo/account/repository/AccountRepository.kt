package com.demo.account.repository

import com.demo.account.model.Account
import org.springframework.stereotype.Repository
import java.util.concurrent.ConcurrentHashMap

@Repository
class AccountRepository {
    private val accounts = ConcurrentHashMap<String, Account>()

    init {
        // Seed with sample data
        listOf(
            Account(id = "123", name = "John Doe", email = "john@example.com", balance = 1000.0),
            Account(id = "456", name = "Jane Smith", email = "jane@example.com", balance = 2500.0),
            Account(id = "789", name = "Bob Wilson", email = "bob@example.com", balance = 500.0)
        ).forEach { accounts[it.id] = it }
    }

    fun findById(id: String): Account? = accounts[id]

    fun findAll(): List<Account> = accounts.values.toList()

    fun save(account: Account): Account {
        accounts[account.id] = account
        return account
    }

    fun delete(id: String): Boolean = accounts.remove(id) != null

    fun existsByEmail(email: String): Boolean =
        accounts.values.any { it.email.equals(email, ignoreCase = true) }
}
