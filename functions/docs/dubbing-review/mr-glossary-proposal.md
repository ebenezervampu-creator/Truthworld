# Marathi Terminology Glossary Proposal (`mr-glossary-proposal.md`)

> [!WARNING]
> **PROPOSAL ONLY — Nothing in this document is in the product yet.**
> The current codebase (`functions/src/pipeline/services/terminology_glossary.ts`) has translations for Telugu (`te`), Hindi (`hi`), Tamil (`ta`), and Malayalam (`ml`), but lacks Marathi (`mr`) entries for all 29 domain terms.
> Every Marathi translation below is **PROPOSED** and requires native speaker approval. After approval, an engineer will add the validated entries to `terminology_glossary.ts`. **Do not edit `terminology_glossary.ts` directly.**

> [!IMPORTANT]
> **Sources were suggested by an AI and have not been checked. A term counts as verified only after the reviewer fills in 'Checked by reviewer'.**

---

## 🔍 Terms Where My Confidence is Lowest — Check These First

These terms are ordered **Low first, then Medium**, where digital dubbing practice often diverges between formal textbook Marathi and English spoken loan words:

### Low Confidence (Check First)
1. **`capacity_factor` (#9 - Low)**:
   - Proposed: **क्षमता घटक** | Spoken loan: **कॅपॅसिटी फॅक्टर**
   - *Why check:* Electricity regulations and engineering discussions often retain the English loan **"कॅपॅसिटी फॅक्टर"** or **"PLF"**. Does *"क्षमता घटक"* sound natural to Marathi listeners, or should the spoken loan term be preferred?
2. **`peer_review` (#23 - Low)**:
   - Proposed: **तज्ज्ञ पुनरावलोकन** | Spoken loan: **पीअर रिव्ह्यू** | Alternative: **समकक्ष समीक्षा**
   - *Why check:* Formal Marathi reference texts use *"समकक्ष पुनरावलोकन"*, but science and educational YouTube channels predominantly say **"पीअर रिव्ह्यू"**. Which should be preferred for voice dubbing?
3. **`confidence_interval` (#25 - Low)**:
   - Proposed: **विश्वासार्हता अंतर** | Spoken loan: **कॉन्फिडन्स इंटरव्हल** | Alternative: **विश्वास मर्यादा**
   - *Why check:* College statistics textbooks use *"विश्वास मर्यादा"*, whereas conversational video explainers frequently say **"कॉन्फिडन्स इंटरव्हल"**.
4. **`creator_monetization` (#3 - Low)**:
   - Proposed: **क्रिएटर कमाई** | Spoken loan: **क्रिएटर मॉनेटायझेशन**
   - *Why check:* *"कमाई"* is natural in spoken video, but *"मॉनेटायझेशन"* is the established YouTube creator interface term.
5. **`grid_batteries` (#6 - Low)**:
   - Proposed: **ग्रिड बॅटऱ्या** | Alternative: **पॉवर ग्रिड बॅटऱ्या**
   - *Why check:* *"बॅटऱ्या"* is the conversational plural; verify whether utility-scale discussions prefer a formal compound.
6. **`credibility_score` (#20 - Low)**:
   - Proposed: **विश्वसनीयता गुण** | Spoken loan: **विश्वसनीयता स्कोर**
   - *Why check:* In digital product ratings, confirm whether *"गुण"* is preferred over the common loan word *"स्कोर"*.

### Medium Confidence (Check Next)
7. **`deepfake` (#17 - Medium)**:
   - Proposed: **डीपफेक** | Alternative: **कृत्रिम बनावट व्हिडिओ**
   - *Why check:* Marathi media universally uses the loan term *"डीपफेक"*. Confirm whether a descriptive alternative is needed.
8. **`gospel` (#11 - Medium)**:
   - Proposed: **शुभवर्तमान** | Alternative: **सुवार्ता**
   - *Why check:* Traditional Marathi Bible book titles use *"शुभवर्तमान"*, while liturgical and Catholic usage often uses *"सुवार्ता"*.
9. **`prophet` (#12 - Medium)**:
   - Proposed: **संदेष्टा** | Alternatives: **भविष्यवक्ता**, **संदेशवाहक**
   - *Why check:* The Marathi Bible uses *"संदेष्टा"* (e.g. यशया संदेष्टा), while general discourse often uses *"भविष्यवक्ता"*.
10. **`salvation` (#15 - Medium)**:
    - Proposed: **तारण** | Alternatives: **मुक्ती**, **उद्धार**
    - *Why check:* *"तारण"* is standard in Christian theology, while *"मुक्ती"* is the general interfaith term.

---

## 📖 Instructions for the Marathi Reviewer

1. Review each of the **29 terms** below.
2. For each term, check the proposed translation against the suggested **source type** (e.g. Marathi Bible, Constitution preamble, Shasan Vyavahar Kosh, or Marathi newspapers).
3. Fill in the **Checked by reviewer** column (e.g. mark ✅ and write the specific source you consulted).
4. Mark your verdict in the **Verdict** column:
   - ✅ **Correct** — Approved for production dubbing and subtitles.
   - ✏️ **Fix: [Word]** — Suggest a better, more natural, or more accurate term.
   - ❌ **Wrong** — Inaccurate or unnatural; must not be used.

---

## 1. Domain Terminology Proposals (29 Terms)

| # | Term ID (`terminology_glossary.ts`) | English Source | Hindi Preferred (from code) | PROPOSED Marathi Preferred | Proposed Alternatives | Proposed Disallowed Literal | AI Confidence (unverified) | Where the Reviewer Can Check (source type) | Checked by Reviewer | Verdict | Reviewer's Correction |
| :- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `lord_theological_historical`<br>(line 74) | "Lord" | "प्रभु" | **प्रभू** | परमेश्वर, प्रभु, देव | लॉर्ड | **Medium** | Marathi Bible (BSI, Catholic), e.g. "प्रभू येशू" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 2 | `fact_checking`<br>(line 149) | "Fact-Checking" | "फैक्ट-चेकिंग" | **तथ्य-पडताळणी** | फॅक्ट-चेकिंग, सत्यता पडताळणी, तथ्य-तपासणी | तथ्यांची चेकिंग, सत्य चेक करणे | **Medium** | Marathi news media, fact-checking desks, e.g. "तथ्य-पडताळणी" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 3 | `creator_monetization`<br>(line 226) | "creator monetization" | "क्रिएटर कमाई" | **क्रिएटर कमाई** | क्रिएटर मॉनेटायझेशन, सामग्री मुद्रीकरण, कंटेंट कमाई | निर्मात्याची कमाई | **Low** | YouTube creator resources in Marathi, digital media blogs | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 4 | `misinformation`<br>(line 288) | "misinformation" | "भ्रामक जानकारी" | **दिशाभूल करणारी माहिती** | भ्रामक माहिती, चुकीची माहिती, फेक न्यूज | वाईट माहिती, खराब माहिती | **Medium** | Cyber awareness advisories, Marathi fact-check articles, e.g. "दिशाभूल करणारी माहिती" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 5 | `evidence_based`<br>(line 350) | "evidence-based claims" | "साक्ष्य-आधारित दावे" | **पुराव्यांवर आधारित दावे** | पुरावा-आधारित दावे, प्रमाण-आधारित दावे | पुराव्याचे दावे, सबूत असलेले दावे | **Medium** | Shasan Vyavahar Kosh, court/legal reporting, e.g. "पुरावा" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 6 | `grid_batteries`<br>(line 412) | "grid batteries" | "ग्रिड बैटरियां" | **ग्रिड बॅटऱ्या** | पॉवर ग्रिड बॅटऱ्या, विद्युत ग्रिड बॅटरी प्रणाली | जाळीदार बॅटऱ्या | **Low** | Electrical engineering articles, Marathi science reporting | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 7 | `renewable_energy`<br>(line 475) | "renewable energy" | "नवीकरणीय ऊर्जा" | **अक्षय ऊर्जा** | नवीकरणीय ऊर्जा, पुनरुत्पादक ऊर्जा | नवीन करता येण्याजोगी ऊर्जा | **Medium** | State energy agency publications, Marathi newspapers, e.g. "अक्षय ऊर्जा" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 8 | `solar_efficiency`<br>(line 537) | "solar efficiency" | "सौर ऊर्जा दक्षता" | **सौर कार्यक्षमता** | सौर ऊर्जा कार्यक्षमता, सौर क्षमता | सूर्याची क्षमता, उन्हाची कार्यक्षमता | **Medium** | School science textbooks, renewable energy reports | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 9 | `capacity_factor`<br>(line 599) | "capacity factor" | "क्षमता कारक" | **क्षमता घटक** | कॅपॅसिटी फॅक्टर, क्षमता गुणक, प्लांट लोड फॅक्टर | क्षमतेचे फॅक्टर | **Low** | Electricity regulatory orders, power engineering texts | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 10 | `scripture_holy`<br>(line 664) | "Scripture" | "धर्मग्रंथ" | **पवित्र शास्त्र** | धर्मग्रंथ, शास्त्रवचन, बायबल | स्क्रिप्चर | **Medium** | Marathi Bible (BSI title: "पवित्र शास्त्र") *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 11 | `gospel`<br>(line 759) | "Gospel" | "सुसमाचार" | **शुभवर्तमान** | सुवार्ता, सुसमाचार, आनंदाची बातमी | गॉस्पेल | **Medium** | Marathi Bible book titles, e.g. "मत्तयकृत शुभवर्तमान", Catholic liturgy "सुवार्ता" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 12 | `prophet`<br>(line 854) | "Prophet" | "नबी" | **संदेष्टा** | भविष्यवक्ता, संदेशवाहक, प्रेषित, पैगंबर | प्रॉफेट | **Medium** | Marathi Bible Old Testament, e.g. "यशया संदेष्टा", standard dictionaries *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 13 | `resurrection`<br>(line 909) | "Resurrection" | "पुनरुत्थान" | **पुनरुत्थान** | मृतांतून उठणे, पुन्हा जिवंत होणे | रिझरेक्शन | **Medium** | Marathi Bible, e.g. "पुनरुत्थान" *(reviewer: please confirm)*, standard Marathi dictionaries | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 14 | `crucifixion`<br>(line 964) | "Crucifixion" | "सूली पर चढ़ाना" | **क्रूसावर खिळणे** | क्रूसावरील मृत्यू, क्रुसावर चढवणे, सुळावर चढवणे | क्रूसीफिक्शन | **Medium** | Marathi Bible Gospels, e.g. "क्रूसावर खिळणे" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 15 | `salvation`<br>(line 1019) | "Salvation" | "मुक्ति" | **तारण** | मुक्ती, उद्धार, मोक्ष | सॅल्व्हेशन | **Medium** | Marathi Bible, e.g. "तारण" *(reviewer: please confirm)*, standard Marathi dictionaries | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 16 | `disinformation`<br>(line 1077) | "disinformation" | "दुष्प्रचार" | **दुष्प्रचार** | हेतुपुरस्सर खोटी माहिती, अपप्रचार | डिसइन्फॉर्मेशन | **Medium** | Shasan Vyavahar Kosh, Marathi newspaper editorials, e.g. "दुष्प्रचार" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 17 | `deepfake`<br>(line 1133) | "deepfake" | "डीपफेक" | **डीपफेक** | कृत्रिम बनावट व्हिडिओ, डीपफेक व्हिडिओ | खोल खोटे | **Medium** | Marathi technology news, cyber crime coverage | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 18 | `source_verification`<br>(line 1188) | "source verification" | "स्रोत सत्यापन" | **स्रोत पडताळणी** | संदर्भ पडताळणी, मूळ तपासणी, सोर्स व्हेरिफिकेशन | सोर्स चेकिंग | **Medium** | Journalism style guides, Shasan Vyavahar Kosh | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 19 | `propaganda`<br>(line 1243) | "propaganda" | "प्रोपेगैंडा" | **अपप्रचार** | प्रोपागंडा, दुष्प्रचार, एकतर्फी प्रचार | प्रमोशन, जाहिरात | **Medium** | Shasan Vyavahar Kosh, Marathi political reporting, e.g. "अपप्रचार" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 20 | `credibility_score`<br>(line 1298) | "credibility score" | "विश्वसनीयता स्कोर" | **विश्वसनीयता गुण** | विश्वसनीयता स्कोर, विश्वासार्हता निर्देशांक | विश्वास गुण | **Low** | Digital fact-checking portals, journalism rubrics | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 21 | `climate_change`<br>(line 1356) | "climate change" | "जलवायु परिवर्तन" | **हवामान बदल** | वातावरणीय बदल, क्लायमेट चेंज | हवा बदलणे | **Medium** | Environment reporting, Marathi newspapers, e.g. "हवामान बदल" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 22 | `vaccine`<br>(line 1411) | "vaccine" | "टीका" | **लस** | व्हॅक्सिन, टोचणी | टिका | **Medium** | Public health announcements, health reporting, e.g. "लस" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 23 | `peer_review`<br>(line 1466) | "peer review" | "पीयर रिव्यू" | **तज्ज्ञ पुनरावलोकन** | पीअर रिव्ह्यू, समकक्ष समीक्षा, समकक्ष पुनरावलोकन | मित्रांची समीक्षा, सोबत्यांची तपासणी | **Low** | Academic journals, Marathi Vishwakosh | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 24 | `carbon_emissions`<br>(line 1521) | "carbon emissions" | "कार्बन उत्सर्जन" | **कार्बन उत्सर्जन** | कार्बन वायू उत्सर्जन, CO2 उत्सर्जन | कोळसा उत्सर्जन | **Medium** | Environmental reporting, pollution control reports, e.g. "कार्बन उत्सर्जन" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 25 | `confidence_interval`<br>(line 1580) | "confidence interval" | "विश्वास अंतराल" | **विश्वासार्हता अंतर** | कॉन्फिडन्स इंटरव्हल, विश्वास मर्यादा, सांख्यिकी अंतर | भरोसा अंतर | **Low** | College statistics textbooks, research papers | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 26 | `correlation_causation`<br>(line 1635) | "correlation does not imply causation" | "सहसंबंध कारण नहीं है" | **सहसंबंध म्हणजे कार्यकारणभाव नव्हे** | सहसंबंध म्हणजे कारण नाही, सहसंबंधाचा अर्थ कार्यकारणभाव नाही | संबंधाचा अर्थ कारण | **Medium** | Logic and statistics textbooks, Marathi Vishwakosh, e.g. "कार्यकारणभाव" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 27 | `revenue_share`<br>(line 1693) | "revenue share" | "राजस्व हिस्सेदारी" | **महसूल वाटप** | रेव्हेन्यू शेअर, उत्पन्नातील वाटा, कमाईची विभागणी | महसूल शेअर | **Medium** | Business news, commercial contracts, Shasan Vyavahar Kosh | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 28 | `sovereignty`<br>(line 1751) | "sovereignty" | "संप्रभुता" | **सार्वभौमत्व** | सार्वभौम सत्ता, स्वायत्तता | सोव्हरिनिटी | **Medium** | Constitution of India (Marathi preamble), e.g. "सार्वभौम" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |
| 29 | `democracy`<br>(line 1806) | "democracy" | "लोकतंत्र" | **लोकशाही** | प्रजासत्ताक | डेमोक्रसी | **Medium** | Constitution of India (Marathi preamble), e.g. "लोकशाही गणराज्य" *(reviewer: please confirm)* | [ ] Checked:<br>`____________` | [ ] ✅ Correct<br>[ ] ✏️ Fix<br>[ ] ❌ Wrong | |

---

## 2. Special Review Section: Religious & Theological Terms

For terms **#1, #10, #11, #12, #13, #14, and #15**, the proposed translations assume standard **Marathi Christian theological tradition**, aligned with the **Marathi Bible (पवित्र शास्त्र - BSI / Catholic)**:

1. **`lord_theological_historical` ("Lord")**:
   - Assumed: Biblical address referring to God or Jesus Christ.
   - Proposed: **"प्रभू"** (Vocative: "हे प्रभू", Formal: "परमेश्वर").
   - Source Type: Marathi Bible (BSI, Catholic), e.g. "प्रभू येशू" *(reviewer: please confirm)*.
   - *Reviewer question:* Is "प्रभू" preferred over "परमेश्वर" when dubbing direct character dialogue?
2. **`scripture_holy` ("Scripture")**:
   - Assumed: Sacred biblical text.
   - Proposed: **"पवित्र शास्त्र"** (preferred in Marathi Christian Bibles) or general **"धर्मग्रंथ"**.
   - Source Type: Marathi Bible title ("पवित्र शास्त्र") *(reviewer: please confirm)*.
   - *Reviewer question:* Should "पवित्र शास्त्र" be preferred when the source is Christian, with "धर्मग्रंथ" as fallback for interfaith content?
3. **`gospel` ("Gospel")**:
   - Assumed: The Christian Gospel / Evangelion.
   - Proposed: **"शुभवर्तमान"** (canonical Bible title) with **"सुवार्ता"** as liturgical/spoken alternative.
   - Source Type: Marathi Bible book titles, e.g. "मत्तयकृत शुभवर्तमान", Catholic liturgy "सुवार्ता" *(reviewer: please confirm)*.
   - *Reviewer question:* Please confirm whether "शुभवर्तमान" (traditional Protestant Bible title) or "सुवार्ता" (contemporary Catholic and spoken usage) is preferred for online video dubbing.
4. **`prophet` ("Prophet")**:
   - Assumed: Biblical prophet (e.g. Moses, Isaiah).
   - Proposed: **"संदेष्टा"** with **"भविष्यवक्ता"** and **"संदेशवाहक"** as alternatives.
   - Source Type: Marathi Bible Old Testament, e.g. "यशया संदेष्टा" *(reviewer: please confirm)*.
   - *Reviewer question:* In the Marathi Bible, Old Testament prophets are titled "संदेष्टा" (e.g. यशया संदेष्टा). Please confirm whether "संदेष्टा" is preferred over "भविष्यवक्ता" in spoken dubbing.
5. **`resurrection` ("Resurrection")**:
   - Assumed: The resurrection of Jesus Christ.
   - Proposed: **"पुनरुत्थान"** (conversational alternative: "मृतांतून उठणे").
   - Source Type: Marathi Bible, e.g. "पुनरुत्थान" *(reviewer: please confirm)*, standard Marathi dictionaries.
   - *Reviewer question:* Is "पुनरुत्थान" natural for voice dubbing, or is "मृतांतून पुन्हा जिवंत होणे" preferred for video audiences?
6. **`crucifixion` ("Crucifixion")**:
   - Assumed: The crucifixion of Christ on the cross.
   - Proposed: **"क्रूसावर खिळणे"** (alternatively "क्रूसावरील मृत्यू").
   - Source Type: Marathi Bible Gospels, e.g. "क्रूसावर खिळणे" *(reviewer: please confirm)*.
   - *Reviewer question:* Please verify whether "क्रूसावर खिळणे" or "क्रुसावर चढवणे" is the standard ecclesiastical phrasing.
7. **`salvation` ("Salvation")**:
   - Assumed: Christian doctrine of soteriology / salvation through Christ.
   - Proposed: **"तारण"** (Jesus as "तारणहारा"; general alternative: "मुक्ती").
   - Source Type: Marathi Bible, e.g. "तारण" *(reviewer: please confirm)*, standard Marathi dictionaries.
   - *Reviewer question:* "तारण" is the standard theological term in the Marathi Bible. For secular or general moral context, should "मुक्ती" be the alternative?
