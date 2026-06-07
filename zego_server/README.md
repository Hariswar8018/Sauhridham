# ZegoCloud Token Server

This folder contains a lightweight Node.js/Express server that generates secure ZEGOCLOUD `Token04` credentials for RTC (calls) and RTM (chat) features.

Deploying this token server prevents exposing your sensitive ZEGOCLOUD `ServerSecret` inside client-side applications.

## Getting Started Locally

1. **Navigate to this folder**:
   ```bash
   cd zego_server
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **Configure environment variables**:
   Copy `.env.example` to `.env` and fill in your details from the [ZEGOCLOUD Admin Console](https://console.zegocloud.com/):
   ```bash
   cp .env.example .env
   ```
   Open `.env` and edit:
   ```env
   ZEGO_APP_ID=1234567890
   ZEGO_SERVER_SECRET=abcdef0123456789abcdef0123456789
   ```

4. **Start the server**:
   ```bash
   npm start
   ```
   The server will start on `http://localhost:3000`.

---

## API Endpoints

### 1. Get Token
Generates a Version 04 ZEGOCLOUD token.

*   **URL**: `/api/token`
*   **Method**: `GET`
*   **Query Parameters**:
    *   `userID` [Required]: The unique user identifier.
    *   `effectiveTimeInSeconds` [Optional]: Expiration length of the token (default: `3600` seconds / 1 hour).
    *   `payload` [Optional]: JSON privilege control string (default: empty).
*   **Success Response**:
    *   **Code**: 200
    *   **Content**: `{ "token": "04SGVsbG8gV29ybGQ..." }`
*   **Error Response**:
    *   **Code**: 400 or 500
    *   **Content**: `{ "error": "Detailed error message" }`

### 2. Health Check
*   **URL**: `/health`
*   **Method**: `GET`
*   **Success Response**: `{ "status": "healthy", "timestamp": "..." }`

---

## Deploying to Railway

Railway automatically detects this folder as a Node.js project if you configure a repository with just this folder or use the Railway CLI to deploy it.

### Option A: Using Git & GitHub (Recommended)
1. Push this workspace to your GitHub repository.
2. Log in to [Railway](https://railway.app/).
3. Click **New Project** -> **Deploy from GitHub repo** and select your repository.
4. If this folder is a subdirectory in your monorepo, in the service settings on Railway set **Root Directory** to `/zego_server`.
5. Under the service's **Variables** tab, add:
    *   `ZEGO_APP_ID` = `[Your Zego App ID]`
    *   `ZEGO_SERVER_SECRET` = `[Your 32-byte Zego Server Secret]`
6. Railway will automatically build and deploy the Node.js server and provide a public URL.

### Option B: Deploying Directly via Railway CLI
1. Install the Railway CLI:
   ```bash
   npm i -g @railway/cli
   ```
2. Log in to your Railway account:
   ```bash
   railway login
   ```
3. Navigate into this directory and link it:
   ```bash
   cd zego_server
   railway link
   ```
4. Deploy:
   ```bash
   railway up
   ```
5. Set environment variables on the Railway Dashboard.
