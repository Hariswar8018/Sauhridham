// zego_server/index.js
const express = require('express');
const cors = require('cors');
require('dotenv').config();
const { generateToken04 } = require('./zegoServerAssistant');

const app = express();
app.use(cors());
app.use(express.json());

// Log every incoming request
app.use((req, res, next) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Incoming Request: ${req.method} ${req.url} (IP: ${req.ip})`);
    next();
});

// Main endpoint to get token
app.get('/api/token', (req, res) => {
    const { userID, effectiveTimeInSeconds, payload } = req.query;
    const timestamp = new Date().toISOString();
    
    if (!userID) {
        console.warn(`[${timestamp}] WARNING: Missing userID query parameter in request.`);
        return res.status(400).json({ 
            error: 'userID query parameter is required',
            diagnostic: 'Please provide a valid userID as a string query parameter, e.g. /api/token?userID=user_123'
        });
    }

    const appIdStr = process.env.ZEGO_APP_ID;
    const serverSecret = process.env.ZEGO_SERVER_SECRET;

    if (!appIdStr || !serverSecret) {
        console.error(`[${timestamp}] CRITICAL ERROR: ZEGO_APP_ID or ZEGO_SERVER_SECRET environment variables are missing.`);
        return res.status(500).json({ 
            error: 'Server credentials are not configured.', 
            diagnostic: 'The ZEGO_APP_ID and ZEGO_SERVER_SECRET environment variables must be defined on your hosting provider (e.g. Railway, Heroku) or in a local .env file.'
        });
    }

    const appId = parseInt(appIdStr, 10);
    if (isNaN(appId)) {
        console.error(`[${timestamp}] ERROR: ZEGO_APP_ID environment variable is not a valid integer. Value: "${appIdStr}"`);
        return res.status(500).json({ 
            error: 'Server credential configuration error.',
            diagnostic: 'ZEGO_APP_ID environment variable must be a valid integer.'
        });
    }

    const expiry = effectiveTimeInSeconds ? parseInt(effectiveTimeInSeconds, 10) : 3600;
    const payStr = payload || '';

    try {
        const token = generateToken04(appId, userID, serverSecret, expiry, payStr);
        console.log(`[${timestamp}] SUCCESS: Token generated successfully for userID: "${userID}" (Expiry: ${expiry}s)`);
        return res.json({ token, appId });
    } catch (err) {
        console.error(`[${timestamp}] ERROR: Token generation library failed for userID: "${userID}". Error: "${err.message}"`);
        return res.status(500).json({ 
            error: 'Failed to generate access token.',
            diagnostic: `Library error details: ${err.message}. Please check if ZEGO_SERVER_SECRET matches the 32-character hexadecimal secret in the Zego console.`
        });
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy', 
        timestamp: new Date(),
        config: {
            hasAppId: !!process.env.ZEGO_APP_ID,
            hasServerSecret: !!process.env.ZEGO_SERVER_SECRET
        }
    });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`====================================================`);
    console.log(`  ZegoCloud Token Server is running on port ${PORT}`);
    console.log(`  ZEGO_APP_ID: ${process.env.ZEGO_APP_ID ? 'CONFIGURED ✓' : 'MISSING ✗'}`);
    console.log(`  ZEGO_SERVER_SECRET: ${process.env.ZEGO_SERVER_SECRET ? 'CONFIGURED ✓' : 'MISSING ✗'}`);
    console.log(`====================================================`);
});
