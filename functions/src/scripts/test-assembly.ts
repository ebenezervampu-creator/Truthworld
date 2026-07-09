import axios from "axios";
import { PIPELINE_CONFIG } from "../pipeline/config";

async function run() {
  // Allow passing the key via environment variable, CLI argument, or fall back to PIPELINE_CONFIG
  const apiKey = process.env.ASSEMBLYAI_KEY || process.argv[2] || PIPELINE_CONFIG.ASSEMBLYAI_KEY;
  
  if (!apiKey) {
    console.error("❌ Error: No AssemblyAI API key found! Please specify one via the ASSEMBLYAI_KEY environment variable, as a command line argument, or in the PIPELINE_CONFIG.");
    console.log("Usage examples:");
    console.log("  npx ts-node src/scripts/test-assembly.ts <API_KEY>");
    console.log("  $env:ASSEMBLYAI_KEY=\"<API_KEY>\"; npx ts-node src/scripts/test-assembly.ts");
    return;
  }

  console.log("Using AssemblyAI API Key:", `${apiKey.substring(0, 5)}...${apiKey.substring(apiKey.length - 5)}`);
  
  const audioUrl = "https://assembly.ai/wildfires.mp3";
  console.log("Submitting audio URL:", audioUrl);
  
  const headers = {
    authorization: apiKey,
    "content-type": "application/json",
  };
  
  try {
    const sub = await axios.post(
      "https://api.assemblyai.com/v2/transcript",
      {
        audio_url: audioUrl,
        speech_models: ["universal-3-pro"],
      },
      { headers }
    );
    
    const transcriptId = sub.data.id;
    console.log("Job submitted successfully. Transcript ID:", transcriptId);
    
    let attempts = 0;
    while (attempts < 60) {
      attempts++;
      const poll = await axios.get(`https://api.assemblyai.com/v2/transcript/${transcriptId}`, { headers });
      const res = poll.data;
      console.log(`[Attempt ${attempts}] Status: ${res.status}`);
      
      if (res.status === "completed") {
        console.log("\n✅ Transcription Completed!");
        console.log("------------------------");
        console.log("Text:\n", res.text);
        console.log("------------------------");
        break;
      } else if (res.status === "error") {
        console.error("❌ Transcription failed:", res.error);
        break;
      }
      
      await new Promise(resolve => setTimeout(resolve, 3000));
    }
  } catch (error: any) {
    if (axios.isAxiosError(error)) {
      console.error("❌ Axios Error details:", JSON.stringify(error.response?.data, null, 2) || error.message);
    } else {
      console.error("❌ Error:", error);
    }
  }
}

run().catch(console.error);
