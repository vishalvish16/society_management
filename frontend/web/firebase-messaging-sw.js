importScripts("https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyB6Y7KNrWNXu9YOHLu8KsV9OiC9QIiD94c",
  authDomain: "society-management-syste-15a8e.firebaseapp.com",
  projectId: "society-management-syste-15a8e",
  storageBucket: "society-management-syste-15a8e.firebasestorage.app",
  messagingSenderId: "121234687397",
  appId: "1:121234687397:web:f55036e3aa085f2f2e144c",
  measurementId: "G-90PV4BB011"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
