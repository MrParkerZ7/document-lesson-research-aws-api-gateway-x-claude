# Build stage
FROM gradle:8.5-jdk17 AS build
WORKDIR /app

# Copy gradle files first for better caching
COPY settings.gradle.kts gradle.properties build.gradle.kts ./
COPY shared ./shared
COPY account-service ./account-service

# Build the application
RUN gradle :account-service:bootJar --no-daemon

# Runtime stage
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Add non-root user for security
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Copy the built jar
COPY --from=build /app/account-service/build/libs/account-service.jar app.jar

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080${SERVER_SERVLET_CONTEXT_PATH}/actuator/health || exit 1

# Expose port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
