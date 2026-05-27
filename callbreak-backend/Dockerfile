# --- Build Stage ---
FROM gradle:8-jdk21 AS build
WORKDIR /app

# Copy EVERYTHING from the callbreak-backend folder into the Docker /app folder
COPY . .

# Force a clean build. This ensures no cached empty folders are used.
RUN gradle clean installDist --no-daemon

# --- Run Stage ---
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Copy the compiled output from the build stage.
# (If your project name in settings.gradle.kts is different, change 'callbreak-backend' below)
COPY --from=build /app/build/install/callbreak-backend /app/

EXPOSE 8080

# Run the Ktor executable
CMD ["/app/bin/callbreak-backend"]