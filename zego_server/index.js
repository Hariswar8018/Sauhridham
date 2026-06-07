// zego_server/index.js
const express = require('express');
const cors = require('cors');
require('dotenv').config();
const { generateToken04 } = require('./zegoServerAssistant');

const app = express();
app.use(cors());
app.use(express.json());

// Main endpoint to get token
app.get('/api/token', (req, res) => {
    const { userID, effectiveTimeInSeconds, payload } = req.query;
    
    if (!userID) {
        return res.status(400).json({ error: 'userID query parameter is required' });
    }

    const appIdStr = process.env.ZEGO_APP_ID;
    const serverSecret = process.env.ZEGO_SERVER_SECRET;

    if (!appIdStr || !serverSecret) {
        return res.status(500).json({ 
            error: 'ZEGO_APP_ID and ZEGO_SERVER_SECRET environment variables must be configured on the server.' 
        });
    }

    const appId = parseInt(appIdStr, 10);
    if (isNaN(appId)) {
        return res.status(500).json({ error: 'ZEGO_APP_ID must be a valid integer' });
    }

    const expiry = effectiveTimeInSeconds ? parseInt(effectiveTimeInSeconds, 10) : 3600;
    const payStr = payload || '';

    try {
        const token = generateToken04(appId, userID, serverSecret, expiry, payStr);
        return res.json({ token });
    } catch (err) {
        return res.status(500).json({ error: err.message });
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date() });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`ZegoCloud Token Server is running on port ${PORT}`);
});
