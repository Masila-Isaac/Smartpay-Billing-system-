const express = require("express");
const axios = require("axios");
const bodyParser = require("body-parser");
const cors = require("cors");
const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json"); // Firebase service account

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

// ✅ STK Push endpoint
app.post("/mpesa/stkpush", async (req, res) => {
    try {
        const { phoneNumber, amount, accountRef } = req.body;

        // Validate input
        if (!phoneNumber || !amount || !accountRef) {
            return res.status(400).json({ success: false, error: "Missing required fields" });
        }

        // Validate phone number format
        if (!/^254[17]\d{8}$/.test(phoneNumber)) {
            return res.status(400).json({ success: false, error: "Invalid phone number format" });
        }

        console.log("Initiating STK Push for:", { phoneNumber, amount, accountRef });

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
            Amount: Math.round(amount), // Ensure whole number
            PartyA: phoneNumber,
            PartyB: shortcode,
            PhoneNumber: phoneNumber,
            CallBackURL: callbackUrl,
            AccountReference: accountRef.substring(0, 12), // Max 12 chars
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
                phone: phoneNumber,
                amount,
                accountRef,
                status: "Pending",
                transactionId: response.data.CheckoutRequestID,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
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
            // Safaricom API error
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

// ✅ Callback endpoint
app.post("/mpesa/callback", async (req, res) => {
    console.log("📞 M-Pesa Callback received:", JSON.stringify(req.body, null, 2));

    try {
        const callbackData = req.body.Body.stkCallback;
        const transactionId = callbackData.CheckoutRequestID;
        const resultCode = callbackData.ResultCode;
        const status = resultCode === 0 ? "Success" : "Failed";

        // Update Firestore transaction
        const querySnapshot = await db.collection("payments").where("transactionId", "==", transactionId).get();

        if (!querySnapshot.empty) {
            querySnapshot.forEach(doc => {
                doc.ref.update({ status, timestamp: admin.firestore.FieldValue.serverTimestamp() });
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

// ✅ Test endpoint
app.get("/test", (req, res) => {
    res.json({ success: true, message: "Server is running!", timestamp: new Date().toISOString() });
});

// ✅ Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, "0.0.0.0", () => {
    console.log(`✅ M-Pesa backend running on port ${PORT}`);
    console.log(`📍 Local: http://localhost:${PORT}`);
    console.log(`📍 Network: http://10.10.13.194:${PORT}`);
    console.log(`✅ Server is running and ready for requests!`);
});