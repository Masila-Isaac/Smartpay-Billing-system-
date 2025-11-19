const express = require("express");
const axios = require("axios");
const bodyParser = require("body-parser");
const cors = require("cors");
const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

// ✅ Initialize Firebase Admin
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const app = express();

// ✅ Middleware
app.use(cors({ origin: "*" }));
app.use(bodyParser.json());

// ✅ Request logging
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    console.log("Body:", req.body);
    next();
});

// ✅ M-Pesa sandbox credentials
const consumerKey = "K7IC57RapWZk1DRfRudx9vrtjorrwch4rthRG0rEK6GoC6aJ";
const consumerSecret = "4mlSkx39UItTGy3wqppv5CITHMgu5eUycqbGkni60n7POzd3xVu5oQ1st6ImuHfh";
const shortcode = "174379";
const passkey = "bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919";
const callbackUrl = "https://unlaudable-samual-overconstantly.ngrok-free.dev/mpesa/callback";

// ✅ Water Billing Configuration
const WATER_RATES = {
    ratePerUnit: 50, // 1 unit = 50 KES
    unitSize: 1000,  // 1 unit = 1000 liters
    currency: "KES"
};

// ✅ Generate access token
async function getAccessToken() {
    try {
        const auth = Buffer.from(`${consumerKey}:${consumerSecret}`).toString("base64");
        const response = await axios.get(
            "https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials",
            {
                headers: { Authorization: `Basic ${auth}` },
                timeout: 10000
            }
        );
        return response.data.access_token;
    } catch (error) {
        console.error("Access token error:", error.response?.data || error.message);
        throw new Error("Failed to generate access token");
    }
}

// ✅ Convert payment amount to water units
async function processPaymentToWaterUnits(paymentData) {
    try {
        const { amount, accountRef, phone, transactionId, userId } = paymentData;

        // Calculate units purchased
        const unitsPurchased = (amount / WATER_RATES.ratePerUnit) * WATER_RATES.unitSize;

        console.log(`💧 Payment conversion: ${amount} KES = ${unitsPurchased} liters`);

        // Update payment with units purchased
        const paymentQuery = await db.collection("payments")
            .where("transactionId", "==", transactionId)
            .get();

        if (!paymentQuery.empty) {
            paymentQuery.forEach(async (doc) => {
                await doc.ref.update({
                    unitsPurchased: unitsPurchased,
                    processed: true,
                    conversionRate: WATER_RATES.ratePerUnit,
                    unitSize: WATER_RATES.unitSize
                });
            });
        }

        // Update or create water usage document
        await updateWaterUsage(accountRef, unitsPurchased, phone, userId);

        return unitsPurchased;

    } catch (error) {
        console.error("Error processing payment to units:", error);
        throw error;
    }
}

// ✅ Update water usage with new units
async function updateWaterUsage(meterNumber, newUnits, phone, userId) {
    const usageRef = db.collection("waterUsage").doc(meterNumber);

    try {
        const usageDoc = await usageRef.get();

        if (usageDoc.exists) {
            // Update existing usage
            const currentUsage = usageDoc.data();
            const updatedRemaining = (currentUsage.remainingUnits || 0) + newUnits;

            await usageRef.update({
                remainingUnits: updatedRemaining,
                lastTopUp: admin.firestore.FieldValue.serverTimestamp(),
                totalUnitsPurchased: admin.firestore.FieldValue.increment(newUnits),
                status: updatedRemaining > 0 ? 'active' : 'depleted',
                lastUpdated: admin.firestore.FieldValue.serverTimestamp()
            });

            console.log(`✅ Updated water usage for ${meterNumber}: +${newUnits}L, Total: ${updatedRemaining}L`);
        } else {
            // Create new usage document
            await usageRef.set({
                userId: userId,
                meterNumber: meterNumber,
                phone: phone,
                waterUsed: 0,
                remainingUnits: newUnits,
                totalUnitsPurchased: newUnits,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
                status: 'active'
            });

            console.log(`✅ Created new water usage for ${meterNumber}: ${newUnits}L`);
        }

    } catch (error) {
        console.error("Error updating water usage:", error);
        throw error;
    }
}

// ✅ Handle water consumption from microcontroller
async function updateWaterConsumption(meterNumber, waterUsed) {
    try {
        const usageRef = db.collection("waterUsage").doc(meterNumber);
        const usageDoc = await usageRef.get();

        if (!usageDoc.exists) {
            throw new Error(`Meter ${meterNumber} not found in waterUsage collection`);
        }

        const currentUsage = usageDoc.data();
        const newRemaining = (currentUsage.remainingUnits || 0) - waterUsed;

        let status = 'active';
        if (newRemaining <= 0) {
            status = 'depleted';
            // Trigger alert to microcontroller
            await triggerWaterShutoff(meterNumber);
        } else if (newRemaining <= 100) { // Warning at 100 liters remaining
            status = 'warning';
            await triggerLowBalanceAlert(meterNumber, newRemaining);
        }

        await usageRef.update({
            waterUsed: admin.firestore.FieldValue.increment(waterUsed),
            remainingUnits: newRemaining,
            status: status,
            lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
            lastConsumption: waterUsed
        });

        console.log(`💧 Water consumption: ${waterUsed}L used, ${newRemaining}L remaining, Status: ${status}`);

        return {
            remainingUnits: newRemaining,
            status: status,
            meterNumber: meterNumber
        };

    } catch (error) {
        console.error("Error updating water consumption:", error);
        throw error;
    }
}

// ✅ Trigger water shutoff to microcontroller
async function triggerWaterShutoff(meterNumber) {
    try {
        console.log(`🚨 ALERT: Water shutoff triggered for meter: ${meterNumber}`);

        // Create alert in Firestore
        const alertRef = db.collection("alerts").doc();
        await alertRef.set({
            meterNumber: meterNumber,
            type: 'water_shutoff',
            message: 'Water units depleted - flow stopped',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            resolved: false,
            priority: 'high'
        });

        // Here you would typically send a signal to your IoT device
        // For example: send MQTT message or HTTP request to microcontroller

    } catch (error) {
        console.error("Error triggering water shutoff:", error);
    }
}

// ✅ Trigger low balance alert
async function triggerLowBalanceAlert(meterNumber, remainingUnits) {
    try {
        console.log(`⚠️ Low balance alert for meter: ${meterNumber} - ${remainingUnits}L remaining`);

        const alertRef = db.collection("alerts").doc();
        await alertRef.set({
            meterNumber: meterNumber,
            type: 'low_balance',
            message: `Low water balance: ${remainingUnits}L remaining`,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            resolved: false,
            priority: 'medium'
        });

    } catch (error) {
        console.error("Error triggering low balance alert:", error);
    }
}

// ✅ STK Push endpoint
app.post("/mpesa/stkpush", async (req, res) => {
    try {
        const { phoneNumber, amount, accountRef, userId } = req.body;

        // Validate input
        if (!phoneNumber || !amount || !accountRef) {
            return res.status(400).json({ success: false, error: "Missing required fields" });
        }

        // Validate phone number format
        if (!/^254[17]\d{8}$/.test(phoneNumber)) {
            return res.status(400).json({ success: false, error: "Invalid phone number format" });
        }

        console.log("Initiating STK Push for:", { phoneNumber, amount, accountRef, userId });

        const token = await getAccessToken();
        console.log("Access token received");

        const timestamp = new Date()
            .toISOString()
            .replace(/[-:.]/g, "")
            .slice(0, 14);

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
            AccountReference: accountRef.substring(0, 12),
            TransactionDesc: "Water Bill Payment",
        };

        console.log("Sending STK Push request:", payload);

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

        console.log("STK Push Response:", response.data);

        if (response.data.ResponseCode === "0") {
            // Save initial pending transaction to Firestore
            await db.collection("payments").add({
                userId: userId,
                phone: phoneNumber,
                amount: amount,
                accountRef: accountRef,
                status: "Pending",
                transactionId: response.data.CheckoutRequestID,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                unitsPurchased: 0,
                processed: false
            });

            res.json({
                success: true,
                ResponseCode: response.data.ResponseCode,
                ResponseDescription: response.data.ResponseDescription,
                CustomerMessage: response.data.CustomerMessage,
                CheckoutRequestID: response.data.CheckoutRequestID
            });
        } else {
            res.status(400).json({
                success: false,
                error: response.data.ResponseDescription || "STK Push failed"
            });
        }

    } catch (error) {
        console.error("STK Push Error:", error.response?.data || error.message);

        if (error.response) {
            res.status(500).json({
                success: false,
                error: "Safaricom API Error",
                details: error.response.data
            });
        } else if (error.code === 'ECONNREFUSED') {
            res.status(500).json({ success: false, error: "Cannot connect to Safaricom API" });
        } else {
            res.status(500).json({
                success: false,
                error: "Failed to initiate STK Push",
                message: error.message
            });
        }
    }
});

// ✅ Callback endpoint - UPDATED with water unit conversion
app.post("/mpesa/callback", async (req, res) => {
    console.log("📞 M-Pesa Callback received:", JSON.stringify(req.body, null, 2));

    try {
        const callbackData = req.body.Body.stkCallback;
        const transactionId = callbackData.CheckoutRequestID;
        const resultCode = callbackData.ResultCode;
        const status = resultCode === 0 ? "Success" : "Failed";

        // Find and update the payment
        const querySnapshot = await db.collection("payments").where("transactionId", "==", transactionId).get();

        if (!querySnapshot.empty) {
            querySnapshot.forEach(async (doc) => {
                const paymentData = doc.data();
                await doc.ref.update({
                    status: status,
                    timestamp: admin.firestore.FieldValue.serverTimestamp()
                });

                // If payment successful, convert to water units
                if (status === "Success") {
                    try {
                        const units = await processPaymentToWaterUnits({
                            amount: paymentData.amount,
                            accountRef: paymentData.accountRef,
                            phone: paymentData.phone,
                            transactionId: transactionId,
                            userId: paymentData.userId
                        });
                        console.log(`✅ Payment converted to ${units} liters`);
                    } catch (conversionError) {
                        console.error("Error converting payment to units:", conversionError);
                    }
                }
            });
            console.log(`✅ Transaction ${transactionId} updated to ${status}`);
        } else {
            console.log(`⚠️ Transaction ${transactionId} not found, creating new record`);
            await db.collection("payments").add({
                transactionId,
                status,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        res.json({ ResultCode: 0, ResultDesc: "Success" });
    } catch (e) {
        console.error("Callback Processing Error:", e);
        res.status(500).json({ ResultCode: 1, ResultDesc: "Failed" });
    }
});

// ✅ Water Consumption API for Microcontroller
app.post("/api/water-usage", async (req, res) => {
    try {
        const { meterNumber, waterUsed } = req.body;

        if (!meterNumber || !waterUsed) {
            return res.status(400).json({
                success: false,
                error: "Meter number and water used are required"
            });
        }

        const result = await updateWaterConsumption(meterNumber, parseFloat(waterUsed));
        res.json({
            success: true,
            ...result
        });

    } catch (error) {
        console.error("Water usage API error:", error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ✅ Get Water Status API
app.get("/api/water-status/:meterNumber", async (req, res) => {
    try {
        const { meterNumber } = req.params;

        const usageDoc = await db.collection("waterUsage").doc(meterNumber).get();

        if (!usageDoc.exists) {
            return res.status(404).json({
                success: false,
                error: "Meter not found"
            });
        }

        res.json({
            success: true,
            ...usageDoc.data()
        });

    } catch (error) {
        console.error("Water status API error:", error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ✅ Get Payment History for a Meter
app.get("/api/payment-history/:meterNumber", async (req, res) => {
    try {
        const { meterNumber } = req.params;

        const paymentsQuery = await db.collection("payments")
            .where("accountRef", "==", meterNumber)
            .orderBy("timestamp", "desc")
            .limit(10)
            .get();

        const payments = [];
        paymentsQuery.forEach(doc => {
            payments.push({
                id: doc.id,
                ...doc.data()
            });
        });

        res.json({
            success: true,
            payments: payments
        });

    } catch (error) {
        console.error("Payment history API error:", error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ✅ Test endpoint
app.get("/test", (req, res) => {
    res.json({
        success: true,
        message: "Water Billing Server is running!",
        timestamp: new Date().toISOString(),
        waterRates: WATER_RATES
    });
});

// ✅ Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, "0.0.0.0", () => {
    console.log(`✅ Water Billing System running on port ${PORT}`);
    console.log(`📍 Local: http://localhost:${PORT}`);
    console.log(`📍 Network: http://10.10.13.194:${PORT}`);
    console.log(`💧 Water Rates: ${WATER_RATES.ratePerUnit} KES per ${WATER_RATES.unitSize} liters`);
    console.log(`✅ Server is running and ready for requests!`);
});