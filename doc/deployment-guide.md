# Callbreak Deployment Guide

This document outlines how the Callbreak application is deployed for production. 

The application consists of three main components:
1. **Backend:** A Kotlin Ktor WebSocket server deployed on [Render](https://render.com).
2. **Frontend:** A Flutter Web application deployed on [GitHub Pages](https://pages.github.com).
3. **Database Layer:** Fully managed cloud databases via Supabase (PostgreSQL) and Upstash (Redis).

---

## 1. Database Dependencies

Before deploying the backend, you must configure the cloud database providers:

### PostgreSQL (via Supabase)
Supabase provides the core database and authentication layer.
* **Usage:** Handles user registration, JWT minting (ECDSA256), global leaderboards (`profiles` table), and social features (`friendships` table).
* **Setup:** Create a new project on Supabase and run the provided `supabase_migration.sql` in the SQL Editor to generate the tables.
* **Keys Required:** `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

### Redis (via Upstash)
Upstash provides serverless Redis for active game state persistence.
* **Usage:** The backend pushes the live `CallbreakState` for every active game room to Redis on every move. Because Render Web Services can go to sleep, storing state in-memory would result in abrupt match cancellations on spin-down. Redis ensures that any active game is instantly restored back to memory upon server boot.
* **Keys Required:** `REDIS_URL` (in the `rediss://...` format).

---

## 2. Backend Deployment (Render)

The backend is containerized using Docker and hosted as a Web Service on Render's free tier. 

### Configuration Details
* **Provider:** Render
* **Service Type:** Web Service
* **Environment:** Docker
* **Root Directory:** `callbreak-backend`
* **Dockerfile Path:** `./Dockerfile`
* **Port:** `8080` (Render dynamically maps this via the `PORT` environment variable)

### Important Render Settings
To ensure the backend deploys correctly on Render, the following settings must be strictly adhered to in the Render Dashboard -> Settings:
* **Environment:** Must be set to **Docker** (Do NOT use `Ruby/Node/Java` native mode).
* **Docker Command:** This field **must be completely empty**. If Render auto-populates it with an override (like `/app/bin/callbreak-backend`), you must delete the text. Leaving it blank forces Render to use the `CMD` correctly defined in our single-stage `Dockerfile`.

### Testing the Backend Locally via Docker
If you need to verify the backend Docker image locally before deploying:
```bash
cd callbreak-backend
docker build -t callbreak-api .
docker run --rm -p 8081:8080 callbreak-api
```
*(Port `8081` is used locally to avoid conflicts if `8080` is already in use by a local development server).*

---

## 2. Frontend Deployment (GitHub Pages)

The Flutter web client is automatically compiled and published using a GitHub Actions CI/CD pipeline.

### GitHub Actions Workflow
The workflow is defined in `.github/workflows/deploy.yml`. 
* **Trigger:** Pushing to the `main` branch.
* **Process:** It checks out the code, installs the latest stable Flutter SDK, runs `flutter build web --release --base-href /callbreak/`, and pushes the compiled assets to an isolated `gh-pages` branch.

### GitHub Pages Configuration
To ensure the frontend is accessible to players:
1. Go to the repository **Settings** on GitHub.
2. Navigate to **Pages** on the left sidebar.
3. Under **Build and deployment**, set the Source to **Deploy from a branch**.
4. Select the **`gh-pages`** branch and `/ (root)` folder.
5. Click **Save**.

The live game is permanently available at: 
`https://arunkmishra.github.io/callbreak/`

### Connecting Frontend to Backend
The frontend connects to the backend via the `lib/core/constants.dart` file. 
For production, the URLs are securely set to:
```dart
const String kHttpBaseUrl = 'https://callbreak-1.onrender.com';
const String kWsBaseUrl = 'wss://callbreak-1.onrender.com';
```
If the backend URL ever changes, simply update `constants.dart` and push the changes to `main` to trigger an automatic frontend redeploy.
