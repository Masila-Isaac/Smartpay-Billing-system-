const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();
const firestore = admin.firestore();

exports.syncRtdbToFirestore = functions.database
    .ref("/live/{userId}")   // ✅ userId = RTDB key AND Firestore doc ID
    .onWrite(async (change, context) => {

        const userId = context.params.userId;
        const rtdbData = change.after.val();

        if (!rtdbData) {
            console.log("Data deleted for user:", userId);
            return null;
        }

        try {
            // ✅ STEP 1: Read the matching account directly
            const accountRef = firestore
                .collection("account_details")
                .doc(userId);

            const accountSnap = await accountRef.get();

            if (!accountSnap.exists) {
                console.error("No account_details found for userId:", userId);
                return null;
            }

            const { meterNumber } = accountSnap.data();

            if (!meterNumber) {
                console.error("meterNumber missing for userId:", userId);
                return null;
            }

            // ✅ STEP 2: Save RTDB data into Firestore
            await firestore
                .collection("microcontroller_data")
                .doc(meterNumber)
                .collection("logs")
                .add({
                    ...rtdbData,
                    meterNumber: meterNumber,
                    userId: userId,
                    syncedAt: admin.firestore.FieldValue.serverTimestamp()
                });

            console.log("✅ Data synced for meter:", meterNumber);

        } catch (error) {
            console.error("❌ Sync failed:", error);
        }

        return null;
    });
