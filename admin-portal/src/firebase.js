import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getFunctions } from "firebase/functions";

const firebaseConfig = {
  apiKey: "AIzaSyAHx1SakaXmaPSbE25DOtTdP4Db4m6ES7E",
  authDomain: "www.truthworld.in",
  projectId: "truthworld-1",
  storageBucket: "truthworld-1.firebasestorage.app",
  messagingSenderId: "768266102263",
  appId: "1:768266102263:web:98ca3c36ec8a5038143af2",
  measurementId: "G-2EV456S275"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);
export const functions = getFunctions(app, "asia-south1");
export default app;
