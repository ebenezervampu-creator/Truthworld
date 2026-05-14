import * as admin from "firebase-admin";

/**
 * 🗄️ LAZY FIRESTORE INITIALIZATION
 * 
 * Prevents "App not initialized" errors during cold starts if a module is 
 * imported before admin.initializeApp() is called in the entry point.
 */
export const db = () => admin.firestore();
