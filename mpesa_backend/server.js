require("dotenv").config();
const express = require("express");
const axios = require("axios");
const bodyParser = require("body-parser");
const cors = require("cors");
const admin = require("firebase-admin");

//   ENVIRONMENT CHECK  
console.log("🔧 Environment Check:");
console.log("PORT:", process.env.PORT);
console.log("MPESA_CONSUMER_KEY exists:", !!process.env.MPESA_CONSUMER_KEY);
console.log("FIREBASE_PROJECT_ID exists:", !!process.env.FIREBASE_PROJECT_ID);

//   FIREBASE INITIALIZATION  
let db;
try {
    const serviceAccount = {
        type: "service_account",
        project_id: process.env.FIREBASE_PROJECT_ID,
        private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
        private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
        client_email: process.env.FIREBASE_CLIENT_EMAIL,
        client_id: process.env.FIREBASE_CLIENT_ID,
        auth_uri: "https://accounts.google.com/o/oauth2/auth",
        token_uri: "https://oauth2.googleapis.com/token",
        auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
        client_x509_cert_url: process.env.FIREBASE_CLIENT_X509_CERT_URL
    };

    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });

    db = admin.firestore();
    console.log("✅ Firebase Admin initialized successfully");
} catch (error) {
    console.error("❌ Firebase Admin initialization error:", error.message);
    console.error("Full error:", error);
    // Don't crash, but db will be undefined
}

const app = express();

//   MIDDLEWARE  
app.use(cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "Accept"]
}));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

//   M-PESA CONFIGURATION  
const consumerKey = process.env.MPESA_CONSUMER_KEY;
const consumerSecret = process.env.MPESA_CONSUMER_SECRET;
const shortcode = process.env.MPESA_SHORTCODE || "174379";
const passkey = process.env.MPESA_PASSKEY;
const callbackUrl = process.env.CALLBACK_URL || "https://smartpay-billing.onrender.com/mpesa/callback";

console.log("📡 Server Configuration:");
console.log("   Consumer Key:", consumerKey ? "✅ Set" : "❌ Missing");
console.log("   Shortcode:", shortcode);
console.log("   Callback URL:", callbackUrl);

//   HELPER FUNCTIONS  

// Generate access token
async function getAccessToken() {
    try {
        const auth = Buffer.from(`${consumerKey}:${consumerSecret}`).toString("base64");
        const url = "https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials";

        console.log('🔑 Getting M-Pesa access token...');

        const response = await axios.get(url, {
            headers: {
                Authorization: `Basic ${auth}`,
                "Cache-Control": "no-cache"
            },
            timeout: 15000
        });

        console.log('✅ Access token received');
        return response.data.access_token;
    } catch (error) {
        console.error('❌ Error getting access token:', error.message);
        if (error.response) {
            console.error('Response Status:', error.response.status);
            console.error('Response Data:', error.response.data);
        }
        throw new Error(`Failed to get M-Pesa token: ${error.message}`);
    }
}

// Format phone number for M-Pesa
function formatPhoneNumber(phone) {
    if (!phone) return "";

    // Remove all non-digits
    const cleaned = phone.toString().replace(/\D/g, '');

    if (!cleaned) return "";

    // Convert formats: 07... → 2547..., 7... (9 digits) → 2547...
    if (cleaned.startsWith('0')) {
        return '254' + cleaned.substring(1);
    } else if (cleaned.startsWith('7') && cleaned.length === 9) {
        return '254' + cleaned;
    } else if (cleaned.startsWith('254')) {
        return cleaned;
    } else if (cleaned.length === 12) {
        return cleaned;
    }

    return cleaned;
}

// Generate M-Pesa timestamp and password
function generateTimestampAndPassword() {
    const date = new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');

    const timestamp = `${year}${month}${day}${hours}${minutes}${seconds}`;
    const password = Buffer.from(`${shortcode}${passkey}${timestamp}`).toString('base64');

    return { timestamp, password };
}

// DEBUG ENDPOINT (MUST BE BEFORE OTHER ROUTES)
app.get("/debug", async (req, res) => {
    try {
        console.log("🔍 DEBUG ENDPOINT CALLED");

        // 1. Check Firebase
        let firebaseStatus = "unknown";
        if (db) {
            try {
                const testRef = db.collection("test").doc("debug");
                await testRef.set({ test: new Date().toISOString() });
                await testRef.delete();
                firebaseStatus = "✅ Connected and writeable";
            } catch (fbError) {
                firebaseStatus = `❌ Error: ${fbError.message}`;
            }
        } else {
            firebaseStatus = "❌ Firebase not initialized - check environment variables";
        }

        // 2. Check M-Pesa credentials
        let mpesaStatus = "unknown";
        let accessToken = null;
        try {
            const token = await getAccessToken();
            accessToken = token ? "✅ Received" : "❌ No token";
            mpesaStatus = "✅ Credentials valid";
        } catch (mpesaError) {
            mpesaStatus = `❌ Error: ${mpesaError.message}`;
        }

        // 3. Check environment variables
        const envVars = {
            PORT: process.env.PORT,
            NODE_ENV: process.env.NODE_ENV,
            RENDER_EXTERNAL_URL: process.env.RENDER_EXTERNAL_URL,
            MPESA_CONSUMER_KEY: process.env.MPESA_CONSUMER_KEY ? "✅ Set" : "❌ Missing",
            MPESA_CONSUMER_SECRET: process.env.MPESA_CONSUMER_SECRET ? "✅ Set" : "❌ Missing",
            MPESA_SHORTCODE: process.env.MPESA_SHORTCODE,
            FIREBASE_PROJECT_ID: process.env.FIREBASE_PROJECT_ID ? "✅ Set" : "❌ Missing",
            FIREBASE_CLIENT_EMAIL: process.env.FIREBASE_CLIENT_EMAIL ? "✅ Set" : "❌ Missing",
            FIREBASE_PRIVATE_KEY: process.env.FIREBASE_PRIVATE_KEY ? "✅ Set (length: " + process.env.FIREBASE_PRIVATE_KEY.length + ")" : "❌ Missing",
            CALLBACK_URL: process.env.CALLBACK_URL
        };

        res.json({
            timestamp: new Date().toISOString(),
            status: "diagnostic",
            environmentVariables: envVars,
            services: {
                firebase: firebaseStatus,
                mpesa: mpesaStatus,
                accessToken: accessToken
            },
            serverInfo: {
                nodeVersion: process.version,
                platform: process.platform,
                memory: process.memoryUsage()
            }
        });
    } catch (error) {
        res.status(500).json({
            error: error.message,
            stack: process.env.NODE_ENV === "development" ? error.stack : undefined
        });
    }
});

// ROUTES

// Root endpoint
app.get("/", (req, res) => {
    res.json({
        success: true,
        message: "🚀 SmartPay Water Billing API",
        version: "2.0.0",
        timestamp: new Date().toISOString(),
        endpoints: {
            debug: "/debug",
            health: "/health",
            test: "/test",
            stkPush: "POST /mpesa/stkpush",
            callback: "POST /mpesa/callback",
            paymentStatus: "GET /api/payment/:transactionId"
        }
    });
});

// Health check
app.get("/health", (req, res) => {
    res.json({
        status: "healthy",
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Test endpoint
app.get("/test", async (req, res) => {
    try {
        let dbStatus = "❌ Not connected";
        if (db) {
            try {
                await db.collection("test").doc("test").set({ test: new Date().toISOString() });
                dbStatus = "✅ Connected";
            } catch (error) {
                dbStatus = `❌ Error: ${error.message}`;
            }
        }

        let mpesaStatus = "❌ Not tested";
        try {
            await getAccessToken();
            mpesaStatus = "✅ Connected";
        } catch (error) {
            mpesaStatus = `❌ Error: ${error.message}`;
        }

        res.json({
            success: true,
            message: "SmartPay API Test",
            services: {
                firebase: dbStatus,
                mpesa: mpesaStatus,
                callbackUrl: callbackUrl
            },
            sandboxInfo: {
                testPhone: "254708374149",
                testPin: "1234",
                shortcode: "174379"
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// STK Push endpoint
app.post("/mpesa/stkpush", async (req, res) => {
    try {
        const { phoneNumber, amount, meterNumber, userId } = req.body;

        console.log('📱 STK Push Request:');
        console.log('   Phone:', phoneNumber);
        console.log('   Amount:', amount);
        console.log('   Meter:', meterNumber);
        console.log('   User ID:', userId);

        // Validation
        if (!phoneNumber || !phoneNumber.trim()) {
            return res.status(400).json({
                success: false,
                error: "Phone number is required"
            });
        }

        if (!amount || isNaN(amount) || parseFloat(amount) <= 0) {
            return res.status(400).json({
                success: false,
                error: "Valid amount greater than 0 KES is required"
            });
        }

        const paymentAmount = parseFloat(amount);
        const formattedPhone = formatPhoneNumber(phoneNumber);

        console.log(`📞 Formatted phone: ${formattedPhone}`);

        // Get M-Pesa access token
        const token = await getAccessToken();

        // Generate timestamp and password
        const { timestamp, password } = generateTimestampAndPassword();

        // Prepare STK push payload
        const payload = {
            BusinessShortCode: shortcode,
            Password: password,
            Timestamp: timestamp,
            TransactionType: "CustomerPayBillOnline",
            Amount: Math.floor(paymentAmount),
            PartyA: formattedPhone,
            PartyB: shortcode,
            PhoneNumber: formattedPhone,
            CallBackURL: callbackUrl,
            AccountReference: (meterNumber || "TEST").substring(0, 12),
            TransactionDesc: `Water payment - ${meterNumber || "TEST"}`
        };

        console.log('📤 Sending to M-Pesa...');

        // Send request to M-Pesa
        const response = await axios.post(
            "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest",
            payload,
            {
                headers: {
                    Authorization: `Bearer ${token}`,
                    "Content-Type": "application/json"
                },
                timeout: 30000
            }
        );

        console.log('📥 M-Pesa Response:', response.data);

        if (response.data.ResponseCode === "0") {
            // Save to Firestore if available
            if (db) {
                try {
                    const paymentData = {
                        userId: userId || "unknown",
                        phone: formattedPhone,
                        amount: paymentAmount,
                        meterNumber: meterNumber || "TEST",
                        status: "Pending",
                        transactionId: response.data.CheckoutRequestID,
                        merchantRequestId: response.data.MerchantRequestID,
                        timestamp: new Date().toISOString(),
                        litresPurchased: paymentAmount,
                        processed: false,
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    };

                    await db.collection("payments").add(paymentData);
                    console.log('💾 Payment saved to Firestore');
                } catch (firebaseError) {
                    console.error('Firebase save error:', firebaseError.message);
                }
            }

            // Return success response
            return res.json({
                success: true,
                message: response.data.CustomerMessage || "STK Push sent successfully",
                MerchantRequestID: response.data.MerchantRequestID,
                CheckoutRequestID: response.data.CheckoutRequestID,
                CustomerMessage: response.data.CustomerMessage,
                note: "Check your phone for payment prompt. Sandbox PIN: 1234"
            });
        } else {
            const errorMsg = response.data.ResponseDescription || "STK Push failed";
            console.log('❌ M-Pesa error:', errorMsg);

            return res.status(400).json({
                success: false,
                error: errorMsg,
                note: "For sandbox testing, use phone: 254708374149"
            });
        }
    } catch (error) {
        console.error("❌ STK Push Error:", error.message);

        let errorMessage = "Failed to initiate payment";
        if (error.response) {
            console.error("Response data:", error.response.data);
            errorMessage = error.response.data.errorMessage ||
                error.response.data.error ||
                error.message;
        }

        return res.status(500).json({
            success: false,
            error: errorMessage
        });
    }
});

// M-Pesa Callback endpoint
app.post("/mpesa/callback", async (req, res) => {
    console.log('📞 M-Pesa Callback Received:');
    console.log('Body:', JSON.stringify(req.body, null, 2));

    try {
        const stkCallback = req.body.Body?.stkCallback;

        if (stkCallback) {
            console.log(`Result Code: ${stkCallback.ResultCode}`);
            console.log(`CheckoutRequestID: ${stkCallback.CheckoutRequestID}`);

            // Extract receipt number if payment successful
            let receiptNumber = null;
            let amount = null;
            let phone = null;
            
            if (stkCallback.ResultCode === 0 && stkCallback.CallbackMetadata) {
                const metadata = stkCallback.CallbackMetadata.Item;
                
                // Extract receipt number
                const receiptItem = metadata.find(item => item.Name === "MpesaReceiptNumber");
                if (receiptItem) {
                    receiptNumber = receiptItem.Value;
                    console.log(`Receipt Number: ${receiptNumber}`);
                }
                
                // Extract amount
                const amountItem = metadata.find(item => item.Name === "Amount");
                if (amountItem) {
                    amount = amountItem.Value;
                }
                
                // Extract phone
                const phoneItem = metadata.find(item => item.Name === "PhoneNumber");
                if (phoneItem) {
                    phone = phoneItem.Value;
                }
            }

            // Update Firestore if available
            if (db && stkCallback.CheckoutRequestID) {
                try {
                    const paymentsQuery = await db.collection("payments")
                        .where("transactionId", "==", stkCallback.CheckoutRequestID)
                        .get();

                    if (!paymentsQuery.empty) {
                        const paymentDoc = paymentsQuery.docs[0];
                        const status = stkCallback.ResultCode === 0 ? "Success" : "Failed";

                        const updateData = {
                            status: status,
                            receiptNumber: receiptNumber,
                            callbackData: req.body,
                            updatedAt: new Date().toISOString(),
                            processed: status === "Success"
                        };

                        // Add additional metadata if available
                        if (amount) updateData.actualAmount = amount;
                        if (phone) updateData.actualPhone = phone;

                        await paymentDoc.ref.update(updateData);

                        console.log(`✅ Payment updated: ${status} with receipt: ${receiptNumber}`);
                        
                        // If payment was successful, also update water usage or create a transaction record
                        if (status === "Success" && paymentDoc.data().meterNumber) {
                            const paymentData = paymentDoc.data();
                            
                            // Create a transaction record
                            await db.collection("transactions").add({
                                userId: paymentData.userId,
                                meterNumber: paymentData.meterNumber,
                                amount: amount || paymentData.amount,
                                receiptNumber: receiptNumber,
                                transactionId: stkCallback.CheckoutRequestID,
                                status: "completed",
                                timestamp: admin.firestore.FieldValue.serverTimestamp()
                            });
                            
                            console.log(`✅ Transaction record created for meter: ${paymentData.meterNumber}`);
                        }
                    } else {
                        // Create a new record if not found
                        await db.collection("payments").add({
                            transactionId: stkCallback.CheckoutRequestID,
                            status: stkCallback.ResultCode === 0 ? "Success" : "Failed",
                            receiptNumber: receiptNumber,
                            callbackData: req.body,
                            timestamp: new Date().toISOString(),
                            createdAt: admin.firestore.FieldValue.serverTimestamp()
                        });
                        console.log('💾 New payment record created from callback');
                    }
                } catch (firebaseError) {
                    console.error('Firebase update error:', firebaseError.message);
                }
            }
        }

        // Always respond success to M-Pesa
        res.json({
            ResultCode: 0,
            ResultDesc: "Success"
        });

    } catch (error) {
        console.error('Callback error:', error);
        res.json({
            ResultCode: 0,
            ResultDesc: "Success"
        });
    }
});

// Check payment status endpoint
app.get("/api/payment/:transactionId", async (req, res) => {
    try {
        const { transactionId } = req.params;

        console.log(`🔍 Checking payment status for transaction: ${transactionId}`);

        if (!db) {
            return res.status(500).json({
                success: false,
                error: "Database not connected"
            });
        }

        // Query by transactionId (CheckoutRequestID)
        const paymentsQuery = await db.collection("payments")
            .where("transactionId", "==", transactionId)
            .limit(1)
            .get();

        if (paymentsQuery.empty) {
            // Try querying by merchantRequestId as fallback
            const merchantQuery = await db.collection("payments")
                .where("merchantRequestId", "==", transactionId)
                .limit(1)
                .get();
                
            if (merchantQuery.empty) {
                return res.status(404).json({
                    success: false,
                    error: "Payment not found"
                });
            }
            
            const paymentDoc = merchantQuery.docs[0];
            const paymentData = paymentDoc.data();
            
            // Add status message based on status
            let statusMessage = "Payment pending";
            if (paymentData.status === "Success") {
                statusMessage = "Payment completed successfully";
            } else if (paymentData.status === "Failed") {
                statusMessage = "Payment failed";
            }
            
            return res.json({
                success: true,
                payment: {
                    id: paymentDoc.id,
                    ...paymentData,
                    statusMessage: statusMessage
                }
            });
        }

        const paymentDoc = paymentsQuery.docs[0];
        const paymentData = paymentDoc.data();
        
        // Add status message based on status
        let statusMessage = "Payment pending";
        if (paymentData.status === "Success") {
            statusMessage = "Payment completed successfully";
        } else if (paymentData.status === "Failed") {
            statusMessage = "Payment failed";
        }

        res.json({
            success: true,
            payment: {
                id: paymentDoc.id,
                ...paymentData,
                statusMessage: statusMessage
            }
        });
    } catch (error) {
        console.error("❌ Payment status error:", error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Get all payments for a user
app.get("/api/payments/user/:userId", async (req, res) => {
    try {
        const { userId } = req.params;

        if (!db) {
            return res.status(500).json({
                success: false,
                error: "Database not connected"
            });
        }

        const paymentsQuery = await db.collection("payments")
            .where("userId", "==", userId)
            .orderBy("timestamp", "desc")
            .limit(50)
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
        console.error("❌ Error fetching user payments:", error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

//   START SERVER  
const PORT = process.env.PORT || 5000;

app.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 SmartPay API started on port ${PORT}`);
    console.log(`📡 Callback URL: ${callbackUrl}`);
    console.log(`🔧 Debug endpoint: http://localhost:${PORT}/debug`);
    console.log(`💡 Test phone: 254708374149, PIN: 1234`);
    console.log(`📊 Payment status endpoint: GET /api/payment/:transactionId`);
});