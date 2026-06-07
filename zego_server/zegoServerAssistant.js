// zego_server/zegoServerAssistant.js
const crypto = require('crypto');

// Generate random number in range
function RndNum(a, b) {
    return Math.ceil((a + (b - a)) * Math.random());
}

// Generate random nonce (32-bit signed integer)
function makeNonce() {
    return RndNum(-2147483648, 2147483647);
}

// Generate a random 16-character string for IV
function makeRandomIv() {
    const str = '0123456789abcdefghijklmnopqrstuvwxyz';
    const result = [];
    for (let i = 0; i < 16; i++) {
        const r = Math.floor(Math.random() * str.length);
        result.push(str.charAt(r));
    }
    return result.join('');
}

// Determine algorithm from secret key length (16, 24, or 32 bytes)
function getAlgorithm(key) {
    switch (key.length) {
        case 16:
            return 'aes-128-cbc';
        case 24:
            return 'aes-192-cbc';
        case 32:
            return 'aes-256-cbc';
        default:
            throw new Error('Invalid key length: ' + key.length);
    }
}

// Encrypt plaintext using AES CBC mode with PKCS5/PKCS7 padding
function aesEncrypt(plainText, key, iv) {
    const cipher = crypto.createCipheriv(getAlgorithm(key), key, iv);
    cipher.setAutoPadding(true);
    let encrypted = cipher.update(plainText, 'utf8', 'binary');
    encrypted += cipher.final('binary');
    return Buffer.from(encrypted, 'binary');
}

/**
 * Generates Zego Version 04 Token
 * @param {number} appId - Zego App ID
 * @param {string} userId - Unique User ID
 * @param {string} serverSecret - Zego Server Secret (32-character hex)
 * @param {number} effectiveTimeInSeconds - Validity period in seconds
 * @param {string} [payload] - Optional JSON string for privilege control
 * @returns {string} Base64 encoded token prefixed with '04'
 */
function generateToken04(appId, userId, serverSecret, effectiveTimeInSeconds, payload) {
    if (!appId || typeof appId !== 'number') {
        throw new Error('appID invalid');
    }
    if (!userId || typeof userId !== 'string') {
        throw new Error('userID invalid');
    }
    if (!serverSecret || typeof serverSecret !== 'string' || serverSecret.length !== 32) {
        throw new Error('secret must be a 32 byte string');
    }
    if (!effectiveTimeInSeconds || typeof effectiveTimeInSeconds !== 'number') {
        throw new Error('effectiveTimeInSeconds invalid');
    }

    const createTime = Math.floor(Date.now() / 1000);
    const expireTime = createTime + effectiveTimeInSeconds;
    const nonce = makeNonce();

    // Plaintext payload to encrypt
    const tokenInfo = {
        app_id: appId,
        user_id: userId,
        nonce: nonce,
        ctime: createTime,
        expire: expireTime,
        payload: payload || ""
    };

    const plainText = JSON.stringify(tokenInfo);
    const key = Buffer.from(serverSecret, 'utf8');
    const ivStr = makeRandomIv();
    const iv = Buffer.from(ivStr, 'utf8');

    // Perform AES CBC Encryption
    const ciphertext = aesEncrypt(plainText, key, iv);

    // Pack binary representation:
    // - expire time (8 bytes, Int64BE)
    // - IV length (2 bytes, UInt16BE)
    // - IV bytes
    // - ciphertext length (2 bytes, UInt16BE)
    // - ciphertext bytes
    const expireBuf = Buffer.alloc(8);
    expireBuf.writeBigInt64BE(BigInt(expireTime));

    const ivLenBuf = Buffer.alloc(2);
    ivLenBuf.writeUInt16BE(iv.length);

    const cipherLenBuf = Buffer.alloc(2);
    cipherLenBuf.writeUInt16BE(ciphertext.length);

    const finalBuffer = Buffer.concat([
        expireBuf,
        ivLenBuf,
        iv,
        cipherLenBuf,
        ciphertext
    ]);

    return '04' + finalBuffer.toString('base64');
}

module.exports = {
    generateToken04
};
