# Cloud Function: config.ts

**Location:** `functions/src/pipeline/config.ts`

## 📖 What it does & How it works
🛠️ PIPELINE CONFIGURATION (HARDCODED FOR DEPLOYMENT STABILITY)
 
 NOTE: These keys are added directly to bypass Secret Manager cold-start 
 issues or health check failures. We will move these back to secrets
 once the deployment is stable.

## ⚙️ Exports / Primary Functions
- **PIPELINE_CONFIG**
- **DEEP_RESEARCH_CONFIG**
- **isDeepResearchEnabled**

## 🔗 Dependencies (What it depends on to work)
*No dependencies detected.*
