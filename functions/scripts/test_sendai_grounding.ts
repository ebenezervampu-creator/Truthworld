import { getVertexClient } from "../src/pipeline/utils/ai-client";

async function main() {
  const ai = getVertexClient();
  const resp = await ai.models.generateContent({
    model: "gemini-3.8-flash",
    contents: 'Search Google and verify this exact claim: "Japan Meteorological Agency issued a tsunami warning following a 7.1 magnitude earthquake off Sendai." Return a JSON with { "verified": true, "urls": ["..."] } listing 3 live news article URLs from Reuters, BBC, AP, or JMA that confirm this.',
    config: {
      tools: [{ googleSearch: {} }],
    },
  });
  console.log("Queries:", resp.candidates?.[0]?.groundingMetadata?.webSearchQueries);
  console.log("GroundingChunks:", resp.candidates?.[0]?.groundingMetadata?.groundingChunks);
  console.log("Text:", resp.text);
}

main().catch(console.error);
