# Firebase Cloud Function for call notifications

The Flutter app calls an HTTPS callable function named `sendCallNotification`.
Create it in your Firebase backend with the Admin SDK so FCM server credentials
stay off the phone.

```js
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendCallNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }

  const receiverId = data.receiverId;
  const userSnap = await admin.firestore().collection("users").doc(receiverId).get();
  const token = userSnap.get("fcmToken");
  if (!token) return { sent: false };

  await admin.messaging().send({
    token,
    notification: {
      title: data.callerName || "Incoming call",
      body: `Incoming ${data.callKind || "audio"} call`,
    },
    data: {
      type: "call",
      callId: String(data.callId),
      callDocId: String(data.callDocId),
      callKind: String(data.callKind || "audio"),
      callerName: String(data.callerName || ""),
    },
    android: {
      priority: "high",
      notification: {
        channelId: "calls",
        sound: "default",
      },
    },
  });

  return { sent: true };
});
```

Also add the real Firebase configuration with:

```bash
flutterfire configure
```

Then replace `lib/firebase_options.dart` or let FlutterFire regenerate it.
