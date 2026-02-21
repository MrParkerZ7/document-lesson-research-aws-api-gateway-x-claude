package com.demo.common.exception

open class DomainException(
    message: String,
    cause: Throwable? = null
) : RuntimeException(message, cause)

class ResourceNotFoundException(
    resourceType: String,
    resourceId: String
) : DomainException("$resourceType not found with id: $resourceId")

class ValidationException(
    message: String
) : DomainException(message)

class InsufficientBalanceException(
    accountId: String,
    required: Double,
    available: Double
) : DomainException("Account $accountId has insufficient balance. Required: $required, Available: $available")
