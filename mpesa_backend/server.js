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

// Logging
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    console.log("Body:", req.body);
    next();
});

// M-Pesa Sandbox Config
const consumerKey = "K7IC57RapWZk1DRfRudx9vrtjorrwch4rthRG0rEK6GoC6aJ";
const consumerSecret = "4mlSkx39UItTGy3wqppv5CITHMgu5eUycqbGkni60n7POzd3xVu5oQ1st6ImuHfh";
const shortcode = "174379";
const passkey = "bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919";
const callbackUrl = "https://your-ngrok-url.ngrok-free.app/mpesa/callback";

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

    // Update payment
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

// STK Push endpoint
app.post("/mpesa/stkpush", async (req, res) => {
    try {
        const { phoneNumber, amount, meterNumber, userId } = req.body;
        if (!phoneNumber || !amount || !meterNumber)
            return res.status(400).json({ success: false, error: "Missing fields" });

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

        const response = await axios.post(
            "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest",
            payload,
            { headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" }, timeout: 15000 }
        );

        if (response.data.ResponseCode === "0") {
            await db.collection("payments").add({
                userId,
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
        return res.status(500).json({ success: false, error: "STK Push failed" });
    }
});

// Callback endpoint
app.post("/mpesa/callback", async (req, res) => {
    try {
        const callbackData = req.body.Body.stkCallback;
        const transactionId = callbackData.CheckoutRequestID;
        const status = callbackData.ResultCode === 0 ? "Success" : "Failed";

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
        }

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
        if (!meterNumber || !waterUsed) return res.status(400).json({ success: false, error: "Missing fields" });

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

// Test
app.get("/test", (req, res) => {
    res.json({ success: true, message: "Water Billing Server running", waterRates: WATER_RATES });
});

// Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, "0.0.0.0", () => console.log(`Server running on port ${PORT}`));
