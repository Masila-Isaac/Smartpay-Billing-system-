const express = require("express");
const axios = require("axios");
const bodyParser = require("body-parser");
const cors = require("cors");

const app = express();

// ✅ Enable CORS for all requests
app.use(cors({ origin: "*" }));
app.use(bodyParser.json());

// ✅ M-Pesa sandbox credentials
const consumerKey = "K7IC57RapWZk1DRfRudx9vrtjorrwch4rthRG0rEK6GoC6aJ";
const consumerSecret = "4mlSkx39UItTGy3wqppv5CITHMgu5eUycqbGkni60n7POzd3xVu5oQ1st6ImuHfh";
const shortcode = "174379";
const passkey = "bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919";
const callbackUrl = "https://mydomain.com/mpesa/callback";

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
        console.error("Token Error:", error.response?.data || error.message);
        throw new Error("Failed to get access token");
    }
}

// ✅ STK Push endpoint
app.post("/mpesa/stkpush", async (req, res) => {
    try {
        const { phoneNumber, amount, accountRef } = req.body;

        // Validate input
        if (!phoneNumber || !amount || !accountRef) {
            return res.status(400).json({ error: "Missing required fields" });
        }

        // Validate phone number format
        if (!/^254[17]\d{8}$/.test(phoneNumber)) {
            return res.status(400).json({ error: "Invalid phone number format" });
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
            CallBackURL: "https://webhook.site/4c7e1616-8a14-4a5e-b91a-10486b2a5f8d", // Use a test webhook
            AccountReference: accountRef.substring(0, 12), // Max 12 chars
            TransactionDesc: "Water Bill",
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
                error: "Safaricom API Error",
                details: error.response.data
            });
        } else if (error.code === 'ECONNREFUSED') {
            res.status(500).json({ error: "Cannot connect to Safaricom API" });
        } else {
            res.status(500).json({
                error: "Failed to initiate STK Push",
                message: error.message
            });
        }
    }
});

// ✅ Test endpoint
app.get("/test", (req, res) => {
    res.json({ message: "Server is running!" });
});

// ✅ Callback route
app.post("/mpesa/callback", (req, res) => {
    console.log("📞 Callback received:", JSON.stringify(req.body, null, 2));
    res.json({ ResultCode: 0, ResultDesc: "Success" });
});

// ✅ Start the server
const PORT = 5000;
app.listen(PORT, "0.0.0.0", () => {
    console.log(`✅ M-Pesa backend running on port ${PORT}`);
    console.log(`📍 Local: http://localhost:${PORT}`);
    console.log(`📍 Network: http://10.10.13.194:${PORT}`);
});