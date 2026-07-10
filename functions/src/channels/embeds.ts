import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { BADGE_TIERS, ChannelV2 } from "./types";

const db = () => admin.firestore();

/**
 * 🎫 GET TRUST BADGE (HTTPS/GET)
 * Returns a dynamic SVG badge for a channel.
 * Tier colors: Platinum (9+), Gold (8+), Silver (7+).
 */
export const getTrustBadge = onRequest(
  { region: "asia-south1", cors: true, memory: "256MiB" },
  async (req, res) => {
    try {
      const slug = (req.query.slug as string)?.toLowerCase();
      if (!slug) {
        res.status(400).send("Missing slug");
        return;
      }

      // 1. Resolve slug to channel
      const slugSnap = await db().collection("channel_slugs").doc(slug).get();
      if (!slugSnap.exists) {
        res.status(404).send("Channel not found");
        return;
      }
      const { channelId } = slugSnap.data() as { channelId: string };
      const channelSnap = await db().collection("channels").doc(channelId).get();
      if (!channelSnap.exists) {
        res.status(404).send("Document missing");
        return;
      }

      const data = channelSnap.data() as ChannelV2;
      const ti = data.reputation.avgTrustIndex;
      const verified = data.verification !== "unverified";

      // 2. Determine Tier
      let tier = BADGE_TIERS.BASIC;
      if (ti >= BADGE_TIERS.ELITE.minTrust) tier = BADGE_TIERS.ELITE;
      else if (ti >= BADGE_TIERS.ADVANCED.minTrust) tier = BADGE_TIERS.ADVANCED;
      else if (ti >= BADGE_TIERS.CREATOR.minTrust) tier = BADGE_TIERS.CREATOR;

      // 3. Generate SVG
      const badgeColor = tier.color;
      const textColor = (tier === BADGE_TIERS.ELITE || tier === BADGE_TIERS.ADVANCED) ? "#0f172a" : "#ffffff";
      
      const svg = `
        <svg width="220" height="40" viewBox="0 0 220 40" fill="none" xmlns="http://www.w3.org/2000/svg">
          <rect width="220" height="40" rx="8" fill="#1e293b"/>
          <path d="M0 8C0 3.58172 3.58172 0 8 0H140V40H8C3.58172 40 0 36.4183 0 32V8Z" fill="#0f172a"/>
          <rect x="140" width="80" height="40" rx="0 8 8 0" fill="${badgeColor}"/>
          
          <text x="12" y="24" fill="#f1f5f9" font-family="'TruthWorld Sans', Outfit, sans-serif" font-size="14" font-weight="700" letter-spacing="-0.5">TRUTHWORLD</text>
          <text x="148" y="25" fill="${textColor}" font-family="Roboto, sans-serif" font-size="16" font-weight="700">${ti.toFixed(1)}</text>
          
          ${verified ? `
            <circle cx="108" cy="20" r="6" fill="#38bdf8"/>
            <path d="M105.5 20L107.5 22L110.5 18" stroke="#0f172a" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
          ` : ""}
          
          <text x="12" y="32" fill="#94a3b8" font-family="Roboto, sans-serif" font-size="7" font-weight="500">CREDIBILITY ENGINE</text>
        </svg>
      `.trim();

      res.setHeader("Content-Type", "image/svg+xml");
      res.setHeader("Cache-Control", "public, max-age=3600"); // Cache for 1 hour
      res.status(200).send(svg);
    } catch (err) {
      logger.error("[getTrustBadge] Error:", err);
      res.status(500).send("Error generating badge");
    }
  }
);
