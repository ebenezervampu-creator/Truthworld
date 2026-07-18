import * as admin from 'firebase-admin';
import { logger } from '../utils/logger';

export interface PersistentSpeaker {
  id: string;               // spk_uuid
  displayName: string;
  normalizedName: string;
  channelId: string;        // The "home" channel where they first appeared
  aliases: string[];
  firstSeen: number;
  lastSeen: number;
  role: string;             // primary role detected (e.g. host, guest)
  confidence: number;       // system confidence in this identity (0-1)
}

/**
 * 📇 SPEAKER REGISTRY SERVICE (v7)
 * 
 * Manages persistent speaker identities using a Composite Identity Model.
 */
export class SpeakerRegistryService {
  private get db() {
    return admin.firestore();
  }

  /**
   * Resolve a temporary speaker label to a persistent ID.
   * Uses composite lookup: channelId + name + role.
   */
  async resolveIdentity(channelId: string, name: string, role: string): Promise<{ id: string, confidence: number }> {
    const normalized = name.toLowerCase().trim();
    if (!normalized || normalized === "unknown" || normalized.includes("speaker")) {
       return { id: `temp_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`, confidence: 0.1 };
    }

    try {
      // 1. Exact match on normalized name and channel
      const snap = await this.db.collection('speaker_registry')
        .where('channelId', '==', channelId)
        .where('normalizedName', '==', normalized)
        .limit(1)
        .get();

      if (!snap.empty) {
        const data = snap.docs[0].data() as PersistentSpeaker;
        return { id: data.id, confidence: 0.95 };
      }

      // 2. Global match (Cross-channel guest detection)
      const globalSnap = await this.db.collection('speaker_registry')
        .where('normalizedName', '==', normalized)
        .limit(3)
        .get();

      if (!globalSnap.empty) {
        // If we find a global match with the same name, we return it with lower confidence
        // unless they have a very unique name.
        const bestMatch = globalSnap.docs[0].data() as PersistentSpeaker;
        return { id: bestMatch.id, confidence: 0.75 };
      }

      // 3. Register new identity
      const newId = `spk_${admin.firestore().collection('speaker_registry').doc().id}`;
      const newSpeaker: PersistentSpeaker = {
        id: newId,
        displayName: name,
        normalizedName: normalized,
        channelId,
        aliases: [name],
        firstSeen: Date.now(),
        lastSeen: Date.now(),
        role,
        confidence: 0.9,
      };

      await this.db.collection('speaker_registry').doc(newId).set(newSpeaker);
      return { id: newId, confidence: 0.9 };

    } catch (err) {
      logger.error("[SpeakerRegistry] Identity resolution failure", { channelId, name, err });
      return { id: `err_${Date.now()}`, confidence: 0 };
    }
  }

  async getSpeaker(id: string): Promise<PersistentSpeaker | null> {
    const doc = await this.db.collection('speaker_registry').doc(id).get();
    return doc.exists ? (doc.data() as PersistentSpeaker) : null;
  }
}

export const speakerRegistryService = new SpeakerRegistryService();
