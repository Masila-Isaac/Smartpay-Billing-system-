// index.js
require("dotenv").config();
const express = require("express");
const axios = require("axios");
const bodyParser = require("body-parser");
const cors = require("cors");
const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

// Initialize Firebase Admin
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const app = express();

// Middleware
app.use(cors({ origin: "*" }));
app.use(bodyParser.json());

// Logging middleware
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    console.log("Body:", req.body);
    next();
});

/**
 * Environment variables expected (create a .env file - see .env.example)
 * MPESA_CONSUMER_KEY
 * MPESA_CONSUMER_SECRET
 * MPESA_SHORTCODE
 * MPESA_PASSKEY
 * CALLBACK_URL  -> PUBLIC URL that Safaricom can call (ngrok/real domain)
 */

// Config (from env)
const consumerKey = process.env.MPESA_CONSUMER_KEY;
const consumerSecret = process.env.MPESA_CONSUMER_SECRET;
const shortcode = process.env.MPESA_SHORTCODE;
const passkey = process.env.MPESA_PASSKEY;
const callbackUrl = process.env.CALLBACK_URL; // must be public

// Water Billing Config
const WATER_RATES = { ratePerUnit: 50, unitSize: 1000, currency: "KES" };

// Generate access token
async function getAccessToken() {
    const auth = Buffer.from(`${consumerKey}:${consumerSecret}`).toString("base64");
    const response = await axios.get(
        "https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials",
        { headers: { Authorization: `Basic ${auth}` }, timeout: 10000 }
    );
    return response.data.access_token;
}

// Convert payment to water units & update client
async function processPaymentToWaterUnits({ amount, meterNumber, phone, transactionId, userId }) {
    const unitsPurchased = (amount / WATER_RATES.ratePerUnit) * WATER_RATES.unitSize;
    console.log(`💧 Payment conversion: ${amount} KES = ${unitsPurchased} liters`);

    // Update payment doc(s)
    const paymentQuery = await db.collection("payments").where("transactionId", "==", transactionId).get();
    if (!paymentQuery.empty) {
        paymentQuery.forEach(async doc => {
            await doc.ref.update({ unitsPurchased, processed: true, conversionRate: WATER_RATES.ratePerUnit, unitSize: WATER_RATES.unitSize });
        });
    }

    // Update clients collection
    const clientRef = db.collection("clients").doc(meterNumber);
    const clientDoc = await clientRef.get();

    if (clientDoc.exists) {
        const currentData = clientDoc.data();
        const updatedUnits = (currentData.remainingUnits || 0) + unitsPurchased;
        await clientRef.update({
            remainingUnits: updatedUnits,
            totalUnitsPurchased: admin.firestore.FieldValue.increment(unitsPurchased),
            lastTopUp: admin.firestore.FieldValue.serverTimestamp(),
            status: updatedUnits > 0 ? "active" : "depleted",
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`✅ Updated client ${meterNumber}: +${unitsPurchased}L, Total: ${updatedUnits}L`);
    } else {
        await clientRef.set({
            userId,
            meterNumber,
            phone,
            waterUsed: 0,
            remainingUnits: unitsPurchased,
            totalUnitsPurchased: unitsPurchased,
            lastTopUp: admin.firestore.FieldValue.serverTimestamp(),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            status: "active"
        });
        console.log(`✅ Created new client ${meterNumber}: ${unitsPurchased}L`);
    }

    return unitsPurchased;
}

// Update water consumption
async function updateWaterConsumption(meterNumber, waterUsed) {
    const clientRef = db.collection("clients").doc(meterNumber);
    const clientDoc = await clientRef.get();
    if (!clientDoc.exists) throw new Error(`Client ${meterNumber} not found`);

    const currentData = clientDoc.data();
    const newRemaining = (currentData.remainingUnits || 0) - waterUsed;
    let status = 'active';

    if (newRemaining <= 0) {
        status = 'depleted';
        await triggerWaterShutoff(meterNumber);
    } else if (newRemaining <= 100) {
        status = 'warning';
        await triggerLowBalanceAlert(meterNumber, newRemaining);
    }

    await clientRef.update({
        waterUsed: admin.firestore.FieldValue.increment(waterUsed),
        remainingUnits: newRemaining,
        status,
        lastConsumption: waterUsed,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });

    return { meterNumber, remainingUnits: newRemaining, status };
}

// Alerts
async function triggerWaterShutoff(meterNumber) {
    await db.collection("alerts").add({
        meterNumber,
        type: 'water_shutoff',
        message: 'Water units depleted - flow stopped',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        resolved: false,
        priority: 'high'
    });
}

async function triggerLowBalanceAlert(meterNumber, remainingUnits) {
    await db.collection("alerts").add({
        meterNumber,
        type: 'low_balance',
        message: `Low water balance: ${remainingUnits}L remaining`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        resolved: false,
        priority: 'medium'
    });
}

// ========== ROUTES ==========

// Root endpoint - FIXED: Added this missing endpoint
app.get("/", (req, res) => {
    res.json({
        success: true,
        message: "Water Billing API Server is running",
        timestamp: new Date().toISOString(),
        endpoints: {
            test: "/test",
            stkPush: "/mpesa/stkpush",
            callback: "/mpesa/callback",
            waterStatus: "/api/water-status/:meterNumber",
            paymentHistory: "/api/payment-history/:meterNumber",
            waterUsage: "/api/water-usage"
        }
    });
});

// Test endpoint
app.get("/test", (req, res) => {
    res.json({
        success: true,
        message: "Water Billing Server running",
        waterRates: WATER_RATES,
        serverTime: new Date().toISOString()
    });
});

// STK Push endpoint
app.post("/mpesa/stkpush", async (req, res) => {
    try {
        // NOTE: expect meterNumber in the body (not accountRef)
        const { phoneNumber, amount, meterNumber, userId } = req.body;
        if (!phoneNumber || !amount || !meterNumber) {
            return res.status(400).json({ success: false, error: "Missing fields: phoneNumber, amount, meterNumber are required" });
        }

        const token = await getAccessToken();
        const timestamp = new Date().toISOString().replace(/[-:.]/g, "").slice(0, 14);
        const password = Buffer.from(shortcode + passkey + timestamp).toString("base64");

        const payload = {
            BusinessShortCode: shortcode,
            Password: password,
            Timestamp: timestamp,
            TransactionType: "CustomerPayBillOnline",
            Amount: Math.round(amount),
            PartyA: phoneNumber,
            PartyB: shortcode,
            PhoneNumber: phoneNumber,
            CallBackURL: callbackUrl,
            AccountReference: meterNumber.substring(0, 12),
            TransactionDesc: "Water Bill Payment",
        };

        console.log('📱 STK Push Payload:', payload);

        const response = await axios.post(
            "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest",
            payload,
            { headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" }, timeout: 15000 }
        );

        console.log('📡 M-Pesa Response:', response.data);

        if (response.data.ResponseCode === "0") {
            await db.collection("payments").add({
                userId: userId || "unknown",
                phone: phoneNumber,
                amount,
                meterNumber,
                status: "Pending",
                transactionId: response.data.CheckoutRequestID,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                unitsPurchased: 0,
                processed: false
            });
            return res.json({ success: true, ...response.data });
        } else {
            return res.status(400).json({ success: false, error: response.data.ResponseDescription });
        }
    } catch (error) {
        console.error("STK Push Error:", error.response?.data || error.message);
        return res.status(500).json({ success: false, error: "STK Push failed: " + (error.response?.data?.errorMessage || error.message) });
    }
});

// Callback endpoint (Safaricom will POST here)
app.post("/mpesa/callback", async (req, res) => {
    try {
        console.log('📞 Callback received:', JSON.stringify(req.body, null, 2));

        // Safaricom sandbox wraps the stkCallback inside Body
        const callbackData = req.body.Body?.stkCallback;
        if (!callbackData) {
            console.warn("Callback missing stkCallback payload:", req.body);
            return res.status(400).json({ ResultCode: 1, ResultDesc: "Missing callback data" });
        }

        const transactionId = callbackData.CheckoutRequestID;
        const status = callbackData.ResultCode === 0 ? "Success" : "Failed";

        console.log(`🔄 Processing callback for transaction: ${transactionId}, Status: ${status}`);

        const querySnapshot = await db.collection("payments").where("transactionId", "==", transactionId).get();
        if (!querySnapshot.empty) {
            querySnapshot.forEach(async doc => {
                const paymentData = doc.data();
                await doc.ref.update({ status, timestamp: admin.firestore.FieldValue.serverTimestamp() });

                if (status === "Success") {
                    await processPaymentToWaterUnits({
                        amount: paymentData.amount,
                        meterNumber: paymentData.meterNumber,
                        phone: paymentData.phone,
                        transactionId,
                        userId: paymentData.userId
                    });
                }
            });
        } else {
            console.warn("No payment record found for transactionId:", transactionId);
        }

        // Reply to Safaricom immediately
        res.json({ ResultCode: 0, ResultDesc: "Success" });
    } catch (error) {
        console.error("Callback Error:", error);
        res.status(500).json({ ResultCode: 1, ResultDesc: "Failed" });
    }
});

// Microcontroller water usage
app.post("/api/water-usage", async (req, res) => {
    try {
        const { meterNumber, waterUsed } = req.body;
        if (!meterNumber || waterUsed === undefined) return res.status(400).json({ success: false, error: "Missing fields" });

        const result = await updateWaterConsumption(meterNumber, parseFloat(waterUsed));
        res.json({ success: true, ...result });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Get client water status
app.get("/api/water-status/:meterNumber", async (req, res) => {
    try {
        const { meterNumber } = req.params;
        const doc = await db.collection("clients").doc(meterNumber).get();
        if (!doc.exists) return res.status(404).json({ success: false, error: "Client not found" });
        res.json({ success: true, ...doc.data() });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Payment history
app.get("/api/payment-history/:meterNumber", async (req, res) => {
    try {
        const { meterNumber } = req.params;
        const paymentsQuery = await db.collection("payments")
            .where("meterNumber", "==", meterNumber)
            .orderBy("timestamp", "desc")
            .limit(10)
            .get();

        const payments = paymentsQuery.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        res.json({ success: true, payments });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Health check endpoint
app.get("/health", (req, res) => {
    res.json({
        status: "OK",
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        memory: process.memoryUsage()
    });
});

// Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📍 Local: http://localhost:${PORT}`);
    console.log(`📍 Network: http://192.168.100.24:${PORT}`);
    console.log(`✅ Test endpoint: http://192.168.100.24:${PORT}/test`);
});