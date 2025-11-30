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

// Water Billing Config - 1 KES = 1 litre (NO LIMITS)
const WATER_RATES = {
    ratePerUnit: 1,      // 1 KES per unit
    unitSize: 1,         // 1 unit = 1 litre
    currency: "KES"
};

// Generate access token
async function getAccessToken() {
    const auth = Buffer.from(`${consumerKey}:${consumerSecret}`).toString("base64");
    const response = await axios.get(
        "https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials",
        { headers: { Authorization: `Basic ${auth}` }, timeout: 10000 }
    );
    return response.data.access_token;
}

// Convert payment to water litres & update client - ANY AMOUNT ACCEPTED
async function processPaymentToWaterLitres({ amount, meterNumber, phone, transactionId, userId }) {
    // Simple calculation: amount KES = amount litres (1:1 ratio) - ANY AMOUNT
    const litresPurchased = parseFloat(amount);

    console.log(`💧 Payment conversion: ${amount} KES = ${litresPurchased} litres`);

    // Update payment doc(s) with CORRECT field name
    const paymentQuery = await db.collection("payments").where("transactionId", "==", transactionId).get();

    if (!paymentQuery.empty) {
        paymentQuery.forEach(async doc => {
            await doc.ref.update({
                litresPurchased: litresPurchased, // CORRECT FIELD NAME
                processed: true,
                conversionRate: WATER_RATES.ratePerUnit,
                unitSize: WATER_RATES.unitSize,
                processedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log(`✅ Updated payment record: ${litresPurchased} litres for ${meterNumber}`);
        });
    } else {
        console.warn(`❌ No payment record found for transaction: ${transactionId}`);
    }

    // Update clients collection
    const clientRef = db.collection("clients").doc(meterNumber);
    const clientDoc = await clientRef.get();

    if (clientDoc.exists) {
        const currentData = clientDoc.data();
        const updatedLitres = (currentData.remainingLitres || 0) + litresPurchased;

        await clientRef.update({
            remainingLitres: updatedLitres,
            totalLitresPurchased: admin.firestore.FieldValue.increment(litresPurchased),
            lastTopUp: admin.firestore.FieldValue.serverTimestamp(),
            status: updatedLitres > 0 ? "active" : "depleted",
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            phone: phone // Update phone if not exists
        });
        console.log(`✅ Updated client ${meterNumber}: +${litresPurchased}L, Total: ${updatedLitres}L`);
    } else {
        // Create new client with CORRECT field names
        await clientRef.set({
            userId: userId || "unknown",
            meterNumber: meterNumber,
            phone: phone,
            waterUsed: 0,
            remainingLitres: litresPurchased, // CORRECT FIELD NAME
            totalLitresPurchased: litresPurchased, // CORRECT FIELD NAME
            lastTopUp: admin.firestore.FieldValue.serverTimestamp(),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            status: "active",
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`✅ Created new client ${meterNumber}: ${litresPurchased}L`);
    }

    return litresPurchased;
}

// Update water consumption
async function updateWaterConsumption(meterNumber, waterUsed) {
    const clientRef = db.collection("clients").doc(meterNumber);
    const clientDoc = await clientRef.get();
    if (!clientDoc.exists) throw new Error(`Client ${meterNumber} not found`);

    const currentData = clientDoc.data();
    const newRemaining = (currentData.remainingLitres || 0) - waterUsed; // UPDATED FIELD NAME
    let status = 'active';

    if (newRemaining <= 0) {
        status = 'depleted';
        await triggerWaterShutoff(meterNumber);
    } else if (newRemaining <= 10) { // Low balance warning at 10 litres
        status = 'warning';
        await triggerLowBalanceAlert(meterNumber, newRemaining);
    }

    await clientRef.update({
        waterUsed: admin.firestore.FieldValue.increment(waterUsed),
        remainingLitres: newRemaining, // UPDATED FIELD NAME
        status,
        lastConsumption: waterUsed,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });

    return { meterNumber, remainingLitres: newRemaining, status }; // UPDATED FIELD NAME
}

// Alerts
async function triggerWaterShutoff(meterNumber) {
    await db.collection("alerts").add({
        meterNumber,
        type: 'water_shutoff',
        message: 'Water litres depleted - flow stopped',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        resolved: false,
        priority: 'high'
    });
}

async function triggerLowBalanceAlert(meterNumber, remainingLitres) { // UPDATED FIELD NAME
    await db.collection("alerts").add({
        meterNumber,
        type: 'low_balance',
        message: `Low water balance: ${remainingLitres} litres remaining`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        resolved: false,
        priority: 'medium'
    });
}

// ========== ROUTES ==========

// Root endpoint - API info
app.get("/", (req, res) => {
    res.json({
        success: true,
        message: "Water Billing API Server is running",
        timestamp: new Date().toISOString(),
        waterRates: WATER_RATES,
        note: "ANY amount accepted - 1 KES = 1 litre",
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
        conversion: "1 KES = 1 litre of water - ANY AMOUNT ACCEPTED",
        examples: {
            "1 KES": "1 litre",
            "10 KES": "10 litres",
            "50 KES": "50 litres",
            "100 KES": "100 litres",
            "1000 KES": "1000 litres"
        },
        serverTime: new Date().toISOString()
    });
});

// STK Push endpoint - NO AMOUNT RESTRICTIONS
app.post("/mpesa/stkpush", async (req, res) => {
    try {
        const { phoneNumber, amount, meterNumber, userId } = req.body;

        // Basic validation only - no amount restrictions
        if (!phoneNumber || !amount || !meterNumber) {
            return res.status(400).json({
                success: false,
                error: "Missing fields: phoneNumber, amount, meterNumber are required"
            });
        }

        // Convert amount to number (accept any positive amount)
        const paymentAmount = parseFloat(amount);

        // Only check if amount is positive
        if (paymentAmount <= 0) {
            return res.status(400).json({
                success: false,
                error: "Amount must be greater than 0 KES"
            });
        }

        const token = await getAccessToken();
        const timestamp = new Date().toISOString().replace(/[-:.]/g, "").slice(0, 14);
        const password = Buffer.from(shortcode + passkey + timestamp).toString("base64");

        const payload = {
            BusinessShortCode: shortcode,
            Password: password,
            Timestamp: timestamp,
            TransactionType: "CustomerPayBillOnline",
            Amount: Math.round(paymentAmount), // Round to nearest whole number for MPesa
            PartyA: phoneNumber,
            PartyB: shortcode,
            PhoneNumber: phoneNumber,
            CallBackURL: callbackUrl,
            AccountReference: meterNumber.substring(0, 12),
            TransactionDesc: "Water Bill Payment",
        };

        console.log('📱 STK Push Payload:', payload);
        console.log(`💧 Expected water purchase: ${paymentAmount} KES = ${paymentAmount} litres`);

        const response = await axios.post(
            "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest",
            payload,
            {
                headers: {
                    Authorization: `Bearer ${token}`,
                    "Content-Type": "application/json"
                },
                timeout: 15000
            }
        );

        console.log('📡 M-Pesa Response:', response.data);

        if (response.data.ResponseCode === "0") {
            // Create payment record with CORRECT field names
            await db.collection("payments").add({
                userId: userId || "unknown",
                phone: phoneNumber,
                amount: paymentAmount,
                meterNumber: meterNumber,
                status: "Pending",
                transactionId: response.data.CheckoutRequestID,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                litresPurchased: 0, // CORRECT FIELD NAME - initialized to 0
                processed: false,
                expectedLitres: paymentAmount // Store expected litres for reference
            });

            console.log(`📝 Created payment record for transaction: ${response.data.CheckoutRequestID}`);

            return res.json({
                success: true,
                ...response.data,
                expectedLitres: paymentAmount,
                message: `${paymentAmount} KES will purchase ${paymentAmount} litres of water`
            });
        } else {
            return res.status(400).json({
                success: false,
                error: response.data.ResponseDescription
            });
        }
    } catch (error) {
        console.error("STK Push Error:", error.response?.data || error.message);
        return res.status(500).json({
            success: false,
            error: "STK Push failed: " + (error.response?.data?.errorMessage || error.message)
        });
    }
});

// Callback endpoint (Safaricom will POST here) - FIXED WITH BETTER DEBUGGING
app.post("/mpesa/callback", async (req, res) => {
    try {
        console.log('📞 Callback received:', JSON.stringify(req.body, null, 2));

        // Safaricom sandbox wraps the stkCallback inside Body
        const callbackData = req.body.Body?.stkCallback;
        if (!callbackData) {
            console.warn("❌ Callback missing stkCallback payload:", req.body);
            return res.status(400).json({ ResultCode: 1, ResultDesc: "Missing callback data" });
        }

        const transactionId = callbackData.CheckoutRequestID;
        const resultCode = callbackData.ResultCode;
        const status = resultCode === 0 ? "Success" : "Failed";

        console.log(`🔄 Processing callback for transaction: ${transactionId}, Status: ${status}, ResultCode: ${resultCode}`);

        // Log callback details for debugging
        if (callbackData.CallbackMetadata && callbackData.CallbackMetadata.Item) {
            console.log('📋 Callback metadata:', callbackData.CallbackMetadata.Item);
        }

        // Find payment record
        const querySnapshot = await db.collection("payments").where("transactionId", "==", transactionId).get();

        if (!querySnapshot.empty) {
            console.log(`✅ Found ${querySnapshot.size} payment record(s) for transaction: ${transactionId}`);

            querySnapshot.forEach(async doc => {
                const paymentData = doc.data();
                console.log(`📄 Processing payment: ${doc.id}`, paymentData);

                // Update payment status
                await doc.ref.update({
                    status: status,
                    callbackReceived: admin.firestore.FieldValue.serverTimestamp(),
                    resultCode: resultCode,
                    callbackData: callbackData // Store full callback for debugging
                });

                if (status === "Success") {
                    console.log(`💰 Payment successful, processing water allocation...`);

                    try {
                        const litresPurchased = await processPaymentToWaterLitres({
                            amount: paymentData.amount,
                            meterNumber: paymentData.meterNumber,
                            phone: paymentData.phone,
                            transactionId: transactionId,
                            userId: paymentData.userId
                        });

                        console.log(`✅ Payment processing completed: ${paymentData.amount} KES → ${litresPurchased} litres for ${paymentData.meterNumber}`);
                    } catch (processingError) {
                        console.error(`❌ Error processing payment:`, processingError);
                    }
                } else {
                    console.log(`❌ Payment failed for transaction: ${transactionId}, Reason: ${callbackData.ResultDesc}`);
                }
            });
        } else {
            console.warn(`❌ No payment record found for transactionId: ${transactionId}`);
            // Create a failed payment record for tracking
            await db.collection("failed_callbacks").add({
                transactionId: transactionId,
                callbackData: req.body,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                reason: "No matching payment record found"
            });
        }

        // Always reply to Safaricom immediately
        console.log(`📤 Replying to Safaricom with ResultCode: 0`);
        res.json({ ResultCode: 0, ResultDesc: "Success" });

    } catch (error) {
        console.error("❌ Callback Processing Error:", error);
        res.status(500).json({ ResultCode: 1, ResultDesc: "Failed" });
    }
});

// Microcontroller water usage
app.post("/api/water-usage", async (req, res) => {
    try {
        const { meterNumber, waterUsed } = req.body;
        if (!meterNumber || waterUsed === undefined) {
            return res.status(400).json({
                success: false,
                error: "Missing fields: meterNumber and waterUsed are required"
            });
        }

        const result = await updateWaterConsumption(meterNumber, parseFloat(waterUsed));
        res.json({
            success: true,
            ...result,
            message: `Water usage recorded: ${waterUsed} litres consumed`
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Get client water status
app.get("/api/water-status/:meterNumber", async (req, res) => {
    try {
        const { meterNumber } = req.params;
        const doc = await db.collection("clients").doc(meterNumber).get();

        if (!doc.exists) {
            return res.status(404).json({
                success: false,
                error: "Client not found"
            });
        }

        const clientData = doc.data();
        res.json({
            success: true,
            ...clientData,
            rateInfo: "1 KES = 1 litre of water - ANY AMOUNT"
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
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

        const payments = paymentsQuery.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
            conversionRate: "1 KES = 1 litre"
        }));

        res.json({
            success: true,
            payments,
            totalPayments: payments.length
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Debug endpoint to check payment status
app.get("/api/debug-payment/:transactionId", async (req, res) => {
    try {
        const { transactionId } = req.params;
        const paymentsQuery = await db.collection("payments").where("transactionId", "==", transactionId).get();

        if (paymentsQuery.empty) {
            return res.json({ success: false, error: "Payment not found" });
        }

        const payment = paymentsQuery.docs[0].data();
        res.json({
            success: true,
            payment: {
                id: paymentsQuery.docs[0].id,
                ...payment
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Health check endpoint
app.get("/health", (req, res) => {
    res.json({
        status: "OK",
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        waterRates: WATER_RATES,
        note: "Any amount accepted - no restrictions"
    });
});

// Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`💧 Water Rate: 1 KES = 1 litre`);
    console.log(`💰 ANY AMOUNT ACCEPTED - No restrictions`);
    console.log(`📍 Local: http://localhost:${PORT}`);
    console.log(`📍 Network: http://192.168.100.24:${PORT}`);
    console.log(`✅ Test endpoint: http://192.168.100.24:${PORT}/test`);
    console.log(`💧 Health check: http://192.168.100.24:${PORT}/health`);
    console.log(`🐛 Debug payment: http://192.168.100.24:${PORT}/api/debug-payment/{transactionId}`);
});