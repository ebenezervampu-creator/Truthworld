# TruthWorld Evidentiary Chain of Custody & Forensic Dossier Specification

**Applicable Legislation:**  
- **Bharatiya Sakshya Adhiniyam, 2023 (BSA):** Section 63 (Admissibility of Electronic Records, replacing Section 65B Indian Evidence Act, 1872)  
- **Information Technology Act, 2000:** Sections 79, 67C (Preservation and Retention of Information)  
- **Bharatiya Nagarik Suraksha Sanhita, 2023 (BNSS):** Section 94 (Production of Documents)

---

## 1. Overview & Purpose

Whenever a video hosted on TruthWorld becomes the subject of a legal dispute, viral misinformation controversy, police investigation, or FIR, TruthWorld's backend must generate an immutable, tamper-evident **Forensic Evidence Dossier (`evidence_dossier.json`)**.

This document proves:
1. **Source Authenticity:** The exact raw video bytes uploaded by the user, hashed using cryptographic SHA-256 prior to any processing.
2. **Epistemic Objectivity:** The exact algorithmic inputs, prompts, temperature settings, and ground-truth citations used by Vertex AI / Gemini models.
3. **Absence of Tampering:** Verifiable timestamps from Cloud Storage, Firestore, and Cloud Functions.
4. **Legal Admissibility:** Full compliance with the mandatory certificate requirements under **Section 63 of BSA, 2023**.

---

## 2. Evidence Dossier Schema (`evidence_dossier.json`)

The following JSON structure must be exported by the platform when responding to a statutory authority notice:

```json
{
  "$schema": "https://truthworld.in/schemas/v1/evidence-dossier.json",
  "dossierId": "dossier_tw_20261009_v897621",
  "generatedAt": "2026-10-09T09:23:45.120Z",
  "statutoryEntity": {
    "companyName": "TOWERVSP SERVICES (OPC) PRIVATE LIMITED",
    "cin": "U63111TS2025OPC207488",
    "jurisdiction": "RoC Hyderabad, Telangana, India",
    "grievanceOfficer": "Vampu Ebenezer"
  },
  "contentMetadata": {
    "videoId": "v_abc123xyz",
    "videoTitle": "Original Upload Title",
    "storageUri": "gs://truthworld-production-videos/raw/v_abc123xyz.mp4",
    "sha256Checksum": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "fileSizeBytes": 52428800,
    "durationSeconds": 182.4,
    "uploader": {
      "userId": "usr_998877",
      "channelHandle": "@creator_handle",
      "registeredEmail": "creator@example.com",
      "signupIp": "203.0.113.195",
      "uploadIp": "203.0.113.195",
      "uploadTimestamp": "2026-10-08T14:22:10.000Z"
    }
  },
  "factCheckAuditTrail": {
    "pipelineRunId": "run_fact_987654321",
    "pipelineVersion": "v11.0-path1",
    "engine": "Vertex AI Gemini 3.5 Flash Lite / Pro",
    "triageResult": {
      "provisionalScore": 42.5,
      "triageDurationMs": 48200,
      "isClickbaitDetected": false
    },
    "extractedClaims": [
      {
        "claimId": "claim_001",
        "timestampMs": 14200,
        "rawSpeakerUtterance": "Exact spoken words from video transcript",
        "verifiableProposition": "Atomic normalized claim statement",
        "nature": "empirical",
        "verdict": "incorrect",
        "confidence": 0.94,
        "groundingSources": [
          {
            "name": "Press Information Bureau (PIB) Fact Check / Official Gazette",
            "url": "https://pib.gov.in/FactCheck/detail/12345",
            "retrievedAt": "2026-10-08T14:23:15.000Z",
            "httpStatus": 200
          }
        ]
      }
    ],
    "subjectiveClaimsIsolated": [
      {
        "claimId": "claim_002",
        "timestampMs": 45000,
        "text": "Theological or philosophical assertion",
        "nature": "religious_belief",
        "action": "bypassed_empirical_penalty"
      }
    ]
  },
  "creatorDisputeLog": {
    "disputeSubmitted": true,
    "disputeTimestamp": "2026-10-08T18:30:00.000Z",
    "creatorReason": "Creator's counter-claim statement",
    "creatorSubmittedUrls": [
      "https://example-source.org/study"
    ],
    "reviewStatus": "pending_cross_perspective"
  }
}
```

---

## 3. Statutory Electronic Records Certificate (Section 63 BSA, 2023)

In any court or police proceeding in India, computer-generated printouts and JSON files are inadmissible without a signed certificate under Section 63 of Bharatiya Sakshya Adhiniyam, 2023.

### Mandatory Certificate Text:

```
                  CERTIFICATE UNDER SECTION 63 OF THE
                 BHARATIYA SAKSHYA ADHINIYAM, 2023 (BSA)
      (Corresponding to Section 65B of the Indian Evidence Act, 1872)

I, Vampu Ebenezer, Director of TOWERVSP SERVICES (OPC) PRIVATE LIMITED, 
having registered office at Ramaram, Yadadri Bhuvanagiri, Telangana – 508116, 
do hereby state and certify as follows:

1. I am in lawful control and management of the computer systems, servers, 
   and cloud database instances operated by TruthWorld (truthworld.in).
2. The electronic records, metadata logs, video files, and audit trails 
   referenced in Annexure A were generated by computers and cloud infrastructure 
   operating regularly in the ordinary course of the platform's lawful business.
3. During the relevant period, the said computers and databases were operating 
   properly without any malfunction or unauthorized interference that would 
   affect the integrity or truth of the contents.
4. The cryptographic hash (SHA-256) and audit logs accurately reflect the 
   exact state of the electronic records stored on the platform servers.

Certified at Hyderabad, Telangana on this _____ day of ____________, 2026.


________________________________________
(VAMPU EBENEZER)
Director & Authorized Signatory
TOWERVSP SERVICES (OPC) PRIVATE LIMITED
```

---

## 4. Operational Readiness Checklist

When an FIR or Cyber Cell inquiry is initiated:
- [ ] Run `exportEvidenceDossier(videoId)` Cloud Function.
- [ ] Verify SHA-256 checksum of raw GCS video object.
- [ ] Attach `evidence_dossier.json` to `STATUTORY_REPLY_NOTICE_TEMPLATE.md`.
- [ ] Sign Section 63 BSA Certificate.
- [ ] Dispatch via registered email (`hello@truthworld.in`) and physical speed post to the Investigating Officer within statutory deadline (maximum 72 hours).
