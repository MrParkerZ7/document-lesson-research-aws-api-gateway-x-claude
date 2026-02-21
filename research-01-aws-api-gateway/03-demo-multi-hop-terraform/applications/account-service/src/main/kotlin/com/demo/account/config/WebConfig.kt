package com.demo.account.config

import com.demo.common.exception.ResourceNotFoundException
import com.demo.common.exception.ValidationException
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice
import java.time.Instant

@RestControllerAdvice
class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException::class)
    fun handleResourceNotFound(ex: ResourceNotFoundException): ResponseEntity<ErrorResponse> {
        return ResponseEntity
            .status(HttpStatus.NOT_FOUND)
            .body(ErrorResponse(
                status = HttpStatus.NOT_FOUND.value(),
                error = "Not Found",
                message = ex.message ?: "Resource not found",
                timestamp = Instant.now()
            ))
    }

    @ExceptionHandler(ValidationException::class)
    fun handleValidation(ex: ValidationException): ResponseEntity<ErrorResponse> {
        return ResponseEntity
            .status(HttpStatus.BAD_REQUEST)
            .body(ErrorResponse(
                status = HttpStatus.BAD_REQUEST.value(),
                error = "Bad Request",
                message = ex.message ?: "Validation failed",
                timestamp = Instant.now()
            ))
    }

    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun handleMethodArgumentNotValid(ex: MethodArgumentNotValidException): ResponseEntity<ErrorResponse> {
        val errors = ex.bindingResult.fieldErrors.map { "${it.field}: ${it.defaultMessage}" }
        return ResponseEntity
            .status(HttpStatus.BAD_REQUEST)
            .body(ErrorResponse(
                status = HttpStatus.BAD_REQUEST.value(),
                error = "Validation Failed",
                message = errors.joinToString(", "),
                timestamp = Instant.now()
            ))
    }
}

data class ErrorResponse(
    val status: Int,
    val error: String,
    val message: String,
    val timestamp: Instant
)
