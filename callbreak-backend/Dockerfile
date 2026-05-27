# Stage 1: Build the application
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app

# Copy gradle wrapper and files
COPY gradlew .
COPY gradle gradle
COPY build.gradle.kts .
COPY settings.gradle.kts .
COPY gradle.properties* ./

# Give execute permission to gradlew
RUN chmod +x gradlew

# Download dependencies (this step is cached if build files don't change)
# Some projects might not have gradle.properties, so we ignore errors here
RUN ./gradlew dependencies || true

# Copy source code
COPY src src

# Build the application
RUN ./gradlew installDist

# Stage 2: Create the runtime image
FROM eclipse-temurin:21-jre
WORKDIR /app

# Copy the built application from the build stage
COPY --from=build /app/build/install/callbreak-backend /app/

# Expose the default port (optional, mostly for documentation)
EXPOSE 8080

# Run the application
CMD ["/app/bin/callbreak-backend"]
