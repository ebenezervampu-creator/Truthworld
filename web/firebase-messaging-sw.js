importScripts("https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyAHx1SakaXmaPSbE25DOtTdP4Db4m6ES7E",
  authDomain: "truthworld-1.firebaseapp.com",
  projectId: "truthworld-1",
  storageBucket: "truthworld-1.firebasestorage.app",
  messagingSenderId: "768266102263",
  appId: "1:768266102263:web:98ca3c36ec8a5038143af2"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log("[firebase-messaging-sw.js] Received background message: ", payload);

  const title = payload.notification?.title || payload.data?.title || "Truthworld Notification";
  const body = payload.notification?.body || payload.data?.body || "";
  const icon = payload.notification?.image || payload.data?.image || "/favicon.png";

  const options = {
    body: body,
    icon: icon,
    badge: "/favicon.png",
    data: payload.data
  };

  return self.registration.showNotification(title, options);
});
