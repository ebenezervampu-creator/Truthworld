import axios from "axios";
import { DOMAIN } from "../schema/schemaConfig";
import { logSeoEvent } from "../monitor/searchHealth";

const INDEXNOW_KEY = process.env.INDEXNOW_KEY || "truthworld_indexnow_key_2026";
const INDEXNOW_LOCATION = `${DOMAIN}/${INDEXNOW_KEY}.txt`;

export async function submitIndexNow(urlList: string[]): Promise<boolean> {
  if (!urlList || urlList.length === 0) return true;

  const payload = {
    host: "www.truthworld.in",
    key: INDEXNOW_KEY,
    keyLocation: INDEXNOW_LOCATION,
    urlList: urlList.slice(0, 10000)
  };

  try {
    const response = await axios.post("https://api.indexnow.org/IndexNow", payload, {
      headers: { "Content-Type": "application/json; charset=utf-8" },
      timeout: 10000
    });

    const success = response.status === 200 || response.status === 202;
    logSeoEvent({
      eventType: "indexnow_submitted",
      details: `Submitted ${urlList.length} URLs to IndexNow. Status: ${response.status}`
    });
    return success;
  } catch (err: any) {
    console.error("IndexNow submission error:", err?.response?.data || err?.message || err);
    logSeoEvent({
      eventType: "error",
      details: `IndexNow submission failed: ${err?.message}`
    });
    return false;
  }
}
