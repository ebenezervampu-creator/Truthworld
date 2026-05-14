/**
 * 🧪 TEST SCRIPT: Pipeline v5.0 Verification
 * 
 * This script injects a test job into Firestore with the specific
 * Ishaan Sharma "Claude Design" transcript to verify that:
 *  1. containsVerifiablePredicate() rescues the launch claim.
 *  2. isLaunchNews is correctly detected.
 *  3. Parallel verification executes.
 *  4. Honest labeling (Unverified vs Unsupported) works.
 */

import * as admin from 'firebase-admin';

// Initialize if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp({
    projectId: 'truthworld-1'
  });
}

const db = admin.firestore();

async function runTest() {
  const jobId = `test_v5_${Date.now()}`;
  const userId = "BIZ2fWCKsIU3f66pp5XROEw87RQ2"; // User from the logs
  
  console.log(`🚀 Starting v5.0 Verification Job: ${jobId}`);

  const transcriptText = `But I know Anthropic just launched Claude Design, and you can now prompt and build beautiful presentations, crazy slides, one-pagers, and even mobile UIs. Hi everyone, I'm Ishaan Sharma, and if you've been using Figma, Adobe apps, or other tools, well, you need to check out Claude Design because now you can just prompt and build amazing interfaces from just a single prompt. So this`;

  // 1. Create the job record
  const jobData = {
    jobId,
    userId,
    status: 'pending',
    progress: 0,
    videoUrl: 'https://storage.googleapis.com/truthworld-test/claude_design_hype.mp4',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    config: {
      languages: ['en'],
      enableFactCheck: true,
      tier: 'enterprise', // Trigger strict/deep processing
      priority: 'high'
    },
    // We inject the transcript directly to bypass STT for this test
    stages: {
      transcription: {
        status: 'completed',
        progress: 100,
        completedAt: Date.now(),
        result: {
          text: transcriptText,
          utterances: [
            { speaker: "Speaker A", text: transcriptText, start: 0, end: 15 }
          ]
        }
      },
      credibility: {
        status: 'pending',
        progress: 0
      }
    }
  };

  await db.collection('video_jobs').doc(jobId).set(jobData);
  console.log(`✅ Job ${jobId} created in Firestore.`);
  
  console.log(`\nNext Steps:`);
  console.log(`1. Ensure functions are deployed.`);
  console.log(`2. The 'processCredibility' function should pick up this job.`);
  console.log(`3. Monitor logs for "[ClaimRouter] Rescued verifiable claim"`);
}

runTest().catch(console.error);
