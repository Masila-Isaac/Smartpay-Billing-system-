require("dotenv").config();
const express = require("express");
const axios = require("axios");
const bodyParser = require("body-parser");
const cors = require("cors");
const admin = require("firebase-admin");

// Initialize Firebase Admin
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

try {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
    console.log("✅ Firebase Admin initialized successfully");
} catch (error) {
    console.error("❌ Firebase Admin initialization error:", error.message);
    // Fallback: Try to initialize without service account if in development
    if (process.env.NODE_ENV === "development") {
        admin.initializeApp({
            credential: admin.credential.applicationDefault()
        });
        console.log("✅ Firebase Admin initialized with default credentials");
    }
}

const db = admin.firestore();
const app = express();

// ========== MIDDLEWARE ==========
app.use(cors({
    origin: "*", // Allow all origins in development
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "Accept"]
}));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// ========== M-PESA CONFIGURATION ==========
const consumerKey = process.env.MPESA_CONSUMER_KEY;
const consumerSecret = process.env.MPESA_CONSUMER_SECRET;
const shortcode = process.env.MPESA_SHORTCODE || "174379"; // Sandbox default
const passkey = process.env.MPESA_PASSKEY;

// ⚠️ CRITICAL FIX: Use your Render URL for callback
// Get the Render URL from environment or use the one from .env
const renderUrl = process.env.RENDER_EXTERNAL_URL || `https://smartpay-billing.onrender.com`;
const callbackUrl = `${renderUrl}/mpesa/callback`;

console.log("📡 Server Configuration:");
console.log("   Consumer Key:", consumerKey ? "✅ Set" : "❌ Missing");
console.log("   Shortcode:", shortcode);
console.log("   Render URL:", renderUrl);
console.log("   Callback URL:", callbackUrl);

// ========== HELPER FUNCTIONS ==========

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

    // If starts with 0, convert to 254
    if (cleaned.startsWith('0')) {
        return '254' + cleaned.substring(1);
    }

    // If starts with 7 and length is 9, add 254
    if (cleaned.startsWith('7') && cleaned.length === 9) {
        return '254' + cleaned;
    }

    // If starts with 254, return as-is
    if (cleaned.startsWith('254')) {
        return cleaned;
    }

    // If it's already 12 digits (254xxxxxxxxx), return as-is
    if (cleaned.length === 12) {
        return cleaned;
    }

    console.warn(`⚠️ Could not properly format phone: ${phone}`);
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

// Update water usage after successful payment
async function updateWaterAfterPayment(paymentData) {
    try {
        const { amount, meterNumber, phone, transactionId, userId } = paymentData;
        const litresPurchased = parseFloat(amount);

        console.log(`💧 Updating water for meter ${meterNumber}: ${litresPurchased} litres`);

        // 1. Update payment document
        const paymentQuery = await db.collection("payments")
            .where("transactionId", "==", transactionId)
            .get();

        if (!paymentQuery.empty) {
            const paymentDoc = paymentQuery.docs[0];
            await paymentDoc.ref.update({
                litresPurchased: litresPurchased,
                processed: true,
                conversionRate: 1,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
                status: "Completed"
            });
            console.log(`✅ Updated payment: ${paymentDoc.id}`);
        }

        // 2. Update clients collection
        const clientRef = db.collection("clients").doc(meterNumber);
        const clientDoc = await clientRef.get();

        const updateData = {
            phone: phone,
            lastTopUp: admin.firestore.FieldValue.serverTimestamp(),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        };

        if (clientDoc.exists) {
            const currentData = clientDoc.data();
            const currentLitres = parseFloat(currentData.remainingLitres) || 0;
            const totalPurchased = parseFloat(currentData.totalLitresPurchased) || 0;

            updateData.remainingLitres = currentLitres + litresPurchased;
            updateData.totalLitresPurchased = totalPurchased + litresPurchased;
            updateData.status = (currentLitres + litresPurchased) > 0 ? "active" : "depleted";

            await clientRef.update(updateData);
            console.log(`✅ Updated existing client: +${litresPurchased}L`);
        } else {
            updateData.meterNumber = meterNumber;
            updateData.userId = userId || "unknown";
            updateData.remainingLitres = litresPurchased;
            updateData.totalLitresPurchased = litresPurchased;
            updateData.status = "active";
            updateData.createdAt = admin.firestore.FieldValue.serverTimestamp();

            await clientRef.set(updateData);
            console.log(`✅ Created new client record`);
        }

        // 3. Update waterUsage collection (optional but good to have)
        const waterRef = db.collection("waterUsage").doc(meterNumber);
        const waterDoc = await waterRef.get();

        const waterData = {
            meterNumber: meterNumber,
            userId: userId || "unknown",
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        };

        if (waterDoc.exists) {
            const currentWater = waterDoc.data();
            const currentReading = parseFloat(currentWater.currentReading) || 0;
            const remainingUnits = parseFloat(currentWater.remainingUnits) || 0;
            const totalPurchased = parseFloat(currentWater.totalUnitsPurchased) || 0;

            waterData.currentReading = currentReading + litresPurchased;
            waterData.remainingUnits = remainingUnits + litresPurchased;
            waterData.totalUnitsPurchased = totalPurchased + litresPurchased;

            await waterRef.update(waterData);
        } else {
            waterData.currentReading = litresPurchased;
            waterData.previousReading = 0;
            waterData.remainingUnits = litresPurchased;
            waterData.totalUnitsPurchased = litresPurchased;
            waterData.unitsConsumed = 0;
            waterData.status = "active";
            waterData.lastReadingDate = admin.firestore.FieldValue.serverTimestamp();

            await waterRef.set(waterData);
        }

        return { success: true, litres: litresPurchased };
    } catch (error) {
        console.error('❌ Error updating water:', error);
        throw error;
    }
}

// ========== ROUTES ==========

// Root endpoint - health check
app.get("/", (req, res) => {
    res.json({
        success: true,
        message: "🚀 SmartPay Water Billing API",
        version: "2.0.0",
        environment: process.env.NODE_ENV || "development",
        timestamp: new Date().toISOString(),
        endpoints: {
            health: "/health",
            test: "/test",
            stkPush: "POST /mpesa/stkpush",
            callback: "POST /mpesa/callback",
            paymentStatus: "GET /api/payment/:transactionId"
        },
        config: {
            waterRate: "1 KES = 1 litre",
            callbackUrl: callbackUrl,
            mpesaEnvironment: "sandbox"
        }
    });
});

// Health check
app.get("/health", (req, res) => {
    res.json({
        status: "healthy",
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        database: "Firestore",
        mpesa: consumerKey ? "configured" : "not configured"
    });
});

// Test endpoint
app.get("/test", async (req, res) => {
    try {
        // Test database connection
        const testDoc = await db.collection("test").doc("connection").get();

        // Test M-Pesa connection
        let mpesaStatus = "not tested";
        try {
            const token = await getAccessToken();
            mpesaStatus = token ? "connected" : "failed";
        } catch (error) {
            mpesaStatus = "error: " + error.message;
        }

        res.json({
            success: true,
            message: "SmartPay API is operational",
            serverTime: new Date().toISOString(),
            environment: process.env.NODE_ENV || "development",
            tests: {
                database: testDoc.exists ? "connected" : "collection not found",
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

        console.log('📱 Received STK Push Request:');
        console.log('   Phone:', phoneNumber);
        console.log('   Amount:', amount, 'KES');
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

        if (!meterNumber || !meterNumber.trim()) {
            return res.status(400).json({
                success: false,
                error: "Meter number is required"
            });
        }

        const paymentAmount = parseFloat(amount);
        const formattedPhone = formatPhoneNumber(phoneNumber);

        console.log(`📞 Formatted phone: ${formattedPhone} (original: ${phoneNumber})`);

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
            Amount: Math.floor(paymentAmount), // M-Pesa requires whole numbers
            PartyA: formattedPhone,
            PartyB: shortcode,
            PhoneNumber: formattedPhone,
            CallBackURL: callbackUrl, // ⚠️ This must be your Render URL
            AccountReference: meterNumber.substring(0, 12), // Max 12 chars
            TransactionDesc: `Water payment - ${meterNumber}`
        };

        console.log('📤 Sending to M-Pesa Sandbox:');
        console.log('   Amount:', payload.Amount);
        console.log('   Phone:', payload.PhoneNumber);
        console.log('   Callback:', payload.CallBackURL);

        // Send request to M-Pesa
        const response = await axios.post(
            "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest",
            payload,
            {
                headers: {
                    Authorization: `Bearer ${token}`,
                    "Content-Type": "application/json",
                    "Cache-Control": "no-cache"
                },
                timeout: 30000 // 30 seconds timeout
            }
        );

        console.log('📥 M-Pesa Response:', response.data);

        if (response.data.ResponseCode === "0") {
            // Payment initiated successfully
            const merchantRequestId = response.data.MerchantRequestID;
            const checkoutRequestId = response.data.CheckoutRequestID;
            const customerMessage = response.data.CustomerMessage;

            console.log(`✅ STK Push sent! Request ID: ${merchantRequestId}`);
            console.log(`📱 Customer message: ${customerMessage}`);

            // Save payment to Firestore
            const paymentData = {
                userId: userId || "unknown",
                phone: formattedPhone,
                amount: paymentAmount,
                meterNumber: meterNumber,
                status: "Pending",
                transactionId: checkoutRequestId,
                merchantRequestId: merchantRequestId,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                litresPurchased: 0, // Will be updated after callback
                processed: false,
                expectedLitres: paymentAmount, // 1 KES = 1 litre
                environment: "sandbox",
                createdAt: new Date().toISOString()
            };

            await db.collection("payments").add(paymentData);
            console.log(`💾 Payment saved to Firestore`);

            // Return success response
            return res.json({
                success: true,
                message: customerMessage || "STK Push sent successfully",
                MerchantRequestID: merchantRequestId,
                CheckoutRequestID: checkoutRequestId,
                ResponseCode: response.data.ResponseCode,
                CustomerMessage: customerMessage,
                reference: merchantRequestId,
                note: "Check your phone for payment prompt. Sandbox PIN: 1234"
            });
        } else {
            // M-Pesa returned an error
            const errorMsg = response.data.ResponseDescription || "STK Push failed";
            console.log('❌ M-Pesa error:', errorMsg);

            return res.status(400).json({
                success: false,
                error: errorMsg,
                ResponseCode: response.data.ResponseCode,
                note: "For sandbox testing, use phone: 254708374149"
            });
        }
    } catch (error) {
        console.error("❌ STK Push Error:", error.message);

        let errorMessage = "Failed to initiate payment";
        let statusCode = 500;

        if (error.response) {
            console.error("Response status:", error.response.status);
            console.error("Response data:", error.response.data);

            errorMessage = error.response.data.errorMessage ||
                error.response.data.error ||
                error.response.data.ResponseDescription ||
                error.message;
            statusCode = error.response.status;
        } else if (error.code === 'ECONNABORTED') {
            errorMessage = "Request timeout. M-Pesa service might be slow.";
        }

        return res.status(statusCode).json({
            success: false,
            error: errorMessage,
            debug: process.env.NODE_ENV === "development" ? error.message : undefined
        });
    }
});

// M-Pesa Callback endpoint (CRITICAL - This is where M-Pesa sends payment results)
app.post("/mpesa/callback", async (req, res) => {
    console.log('📞 ========== M-PESA CALLBACK RECEIVED ==========');
    console.log('Timestamp:', new Date().toISOString());
    console.log('Callback body:', JSON.stringify(req.body, null, 2));

    try {
        const stkCallback = req.body.Body?.stkCallback;

        if (!stkCallback) {
            console.warn("❌ Invalid callback format - missing stkCallback");
            // Still respond success to avoid M-Pesa retries
            return res.json({
                ResultCode: 0,
                ResultDesc: "Success - Invalid format handled"
            });
        }

        const checkoutRequestId = stkCallback.CheckoutRequestID;
        const resultCode = parseInt(stkCallback.ResultCode);
        const resultDesc = stkCallback.ResultDesc;

        console.log(`🔄 Processing callback for: ${checkoutRequestId}`);
        console.log(`Result Code: ${resultCode} (${resultCode === 0 ? 'Success' : 'Failed'})`);
        console.log(`Result Description: ${resultDesc}`);

        if (!checkoutRequestId) {
            console.warn("⚠️ No CheckoutRequestID in callback");
            return res.json({ ResultCode: 0, ResultDesc: "Success" });
        }

        // Find payment in database
        const paymentsQuery = await db.collection("payments")
            .where("transactionId", "==", checkoutRequestId)
            .get();

        if (paymentsQuery.empty) {
            console.warn(`⚠️ No payment found for CheckoutRequestID: ${checkoutRequestId}`);
            // Still respond success
            return res.json({ ResultCode: 0, ResultDesc: "Success" });
        }

        const paymentDoc = paymentsQuery.docs[0];
        const paymentId = paymentDoc.id;
        const paymentData = paymentDoc.data();

        console.log(`✅ Found payment: ${paymentId}`);
        console.log(`   Amount: ${paymentData.amount} KES`);
        console.log(`   Meter: ${paymentData.meterNumber}`);
        console.log(`   Phone: ${paymentData.phone}`);

        // Prepare update data
        const updateData = {
            callbackReceived: true,
            callbackData: stkCallback,
            resultCode: resultCode,
            resultDescription: resultDesc,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            callbackTimestamp: new Date().toISOString()
        };

        if (resultCode === 0) {
            // ✅ Payment successful
            updateData.status = "Success";
            updateData.processed = true;

            // Extract receipt number and other details from metadata
            const metadata = stkCallback.CallbackMetadata?.Item || [];
            const receiptItem = metadata.find(item => item.Name === "MpesaReceiptNumber");
            const amountItem = metadata.find(item => item.Name === "Amount");
            const phoneItem = metadata.find(item => item.Name === "PhoneNumber");

            if (receiptItem) {
                updateData.mpesaReceiptNumber = receiptItem.Value;
                console.log(`💰 M-Pesa Receipt: ${receiptItem.Value}`);
            }

            if (amountItem) {
                updateData.actualAmount = amountItem.Value;
                console.log(`💰 Actual Amount: ${amountItem.Value}`);
            }

            if (phoneItem) {
                updateData.actualPhone = phoneItem.Value;
                console.log(`📱 Actual Phone: ${phoneItem.Value}`);
            }

            console.log(`🎉 PAYMENT SUCCESSFUL! Receipt: ${updateData.mpesaReceiptNumber || 'N/A'}`);

            // Update water usage
            try {
                await updateWaterAfterPayment({
                    amount: paymentData.amount,
                    meterNumber: paymentData.meterNumber,
                    phone: paymentData.phone,
                    transactionId: checkoutRequestId,
                    userId: paymentData.userId
                });

                console.log(`💧 Water usage updated successfully`);
            } catch (waterError) {
                console.error(`❌ Failed to update water:`, waterError);
                // Don't fail the callback - log error but continue
            }

        } else {
            // ❌ Payment failed
            updateData.status = "Failed";
            updateData.error = resultDesc;
            console.log(`❌ PAYMENT FAILED: ${resultDesc}`);
        }

        // Update payment record
        await paymentDoc.ref.update(updateData);
        console.log(`✅ Payment record updated: ${paymentId}`);

        // ⚠️ IMPORTANT: Always respond with success to M-Pesa
        // If we respond with failure, M-Pesa will keep retrying
        res.json({
            ResultCode: 0,
            ResultDesc: "Callback processed successfully"
        });

    } catch (error) {
        console.error("❌ CALLBACK PROCESSING ERROR:", error);

        // Still respond with success to avoid M-Pesa retries
        res.json({
            ResultCode: 0,
            ResultDesc: "Success - Error logged"
        });
    }
});

// Check payment status
app.get("/api/payment/:transactionId", async (req, res) => {
    try {
        const { transactionId } = req.params;

        if (!transactionId) {
            return res.status(400).json({
                success: false,
                error: "Transaction ID is required"
            });
        }

        const paymentsQuery = await db.collection("payments")
            .where("transactionId", "==", transactionId)
            .get();

        if (paymentsQuery.empty) {
            return res.status(404).json({
                success: false,
                error: "Payment not found"
            });
        }

        const paymentDoc = paymentsQuery.docs[0];
        const paymentData = paymentDoc.data();

        // Format response
        const response = {
            success: true,
            payment: {
                id: paymentDoc.id,
                ...paymentData,
                // Convert timestamps to ISO strings for readability
                timestamp: paymentData.timestamp?.toDate?.()?.toISOString() || paymentData.timestamp,
                updatedAt: paymentData.updatedAt?.toDate?.()?.toISOString() || paymentData.updatedAt,
                processedAt: paymentData.processedAt?.toDate?.()?.toISOString() || paymentData.processedAt
            }
        };

        res.json(response);
    } catch (error) {
        console.error("Payment status error:", error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ========== START SERVER ==========
const PORT = process.env.PORT || 5000;

app.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 ========== SMART PAY API STARTED ==========`);
    console.log(`   Port: ${PORT}`);
    console.log(`   Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`   Render URL: ${renderUrl}`);
    console.log(`   Callback URL: ${callbackUrl}`);
    console.log(`   M-Pesa Environment: Sandbox`);
    console.log(`   Water Rate: 1 KES = 1 litre`);
    console.log(`   Server Time: ${new Date().toISOString()}`);
    console.log(`   Health Check: ${renderUrl}/health`);
    console.log(`   Test Endpoint: ${renderUrl}/test`);
    console.log(``);
    console.log(`💡 SANDBOX TESTING INFORMATION:`);
    console.log(`   Test Phone: 254708374149`);
    console.log(`   Test PIN: 1234`);
    console.log(`   Shortcode: 174379`);
    console.log(`   Business Name: SAFARICOM`);
    console.log(``);
    console.log(`📱 To test payment:`);
    console.log(`   1. Use phone: 254708374149`);
    console.log(`   2. Enter any amount (e.g., 10)`);
    console.log(`   3. Enter PIN: 1234 when prompted`);
    console.log(`===========================================`);
});