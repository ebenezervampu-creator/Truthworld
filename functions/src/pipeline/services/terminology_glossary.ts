/**
 * 📚 TRUTHWORLD DOMAIN TERMINOLOGY GLOSSARY
 *
 * Ensures consistent, contextually accurate translations for core domain terms
 * across Fact-Checking, Renewable Energy, Science, Monetization, and Public Policy.
 * Prevents awkward literal translations of established technical concepts.
 *
 * Supports four distinct Terminology Profiles:
 *   - neutral: Balanced standard digital journalism terminology
 *   - colloquial: Natural, conversational, relatable spoken vocabulary
 *   - formal: Authoritative, institutional, broadcast-grade terminology
 *   - technical: Exact engineering, scientific, and regulatory nomenclature
 */

export type TerminologyProfile = "neutral" | "colloquial" | "formal" | "technical";

export interface TermTranslation {
  preferred: string;
  acceptableAlternatives: string[];
  disallowedLiteral: string[];
  profiles?: Record<TerminologyProfile, string>;
  example?: {
    sourceSentence: string;
    targetSentence: string;
  };
  notes?: string;
}

/**
 * Escapes regex special characters safely for word-boundary matching
 */
export function escapeRegex(str: string): string {
  return str.replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&");
}

/**
 * Resolves the appropriate TerminologyProfile from pipeline tone & style options
 */
export function resolveTerminologyProfile(options?: {
  tone?: "casual" | "formal";
  localeStyle?: string;
  isCinemaGrade?: boolean;
}): TerminologyProfile {
  if (options?.localeStyle === "slang" || options?.tone === "casual") {
    return "colloquial";
  }
  if (options?.tone === "formal" || options?.isCinemaGrade) {
    return "formal";
  }
  if (options?.localeStyle === "technical") {
    return "technical";
  }
  return "neutral";
}

export type GlossaryCategory =
  | "fact_checking"
  | "energy_policy"
  | "science"
  | "statistics"
  | "monetization"
  | "theology"
  | "historical";

export interface GlossaryTerm {
  termId: string;
  sourceEn: string;
  category: GlossaryCategory;
  translations: Record<string, TermTranslation>;
}

export const DOMAIN_GLOSSARY: GlossaryTerm[] = [
  {
    termId: "lord_theological_historical",
    sourceEn: "Lord",
    category: "theology",
    translations: {
      es: {
        preferred: "Señor",
        acceptableAlternatives: ["Dios"],
        disallowedLiteral: ["Lord"],
        profiles: {
          neutral: "Señor",
          colloquial: "Señor",
          formal: "Señor",
          technical: "Señor",
        },
        example: {
          sourceSentence: "The Lord delivered them from bondage.",
          targetSentence: "El Señor los libró de la esclavitud.",
        },
      },
      te: {
        preferred: "ప్రభువా",
        acceptableAlternatives: ["ప్రభువు", "దేవా", "ప్రభూ"],
        disallowedLiteral: ["లార్డ్"],
        profiles: {
          neutral: "ప్రభువు",
          colloquial: "ప్రభువా",
          formal: "ప్రభువు వారు",
          technical: "ప్రభువు",
        },
        example: {
          sourceSentence: "The Lord delivered them from bondage.",
          targetSentence: "ప్రభువు వారిని బానిసత్వం నుండి విడిపించారు.",
        },
        notes: "Vocative prayer address or biblical/historical drama title must be localized as 'ప్రభువా'. Raw transliteration 'లార్డ్' is disallowed.",
      },
      hi: {
        preferred: "प्रभु",
        acceptableAlternatives: ["हे प्रभु", "परमेश्वर"],
        disallowedLiteral: ["लॉर्ड"],
        profiles: {
          neutral: "प्रभु",
          colloquial: "हे प्रभु",
          formal: "परमेश्वर",
          technical: "प्रभु",
        },
        example: {
          sourceSentence: "The Lord delivered them from bondage.",
          targetSentence: "प्रभु ने उन्हें दासत्व से छुड़ाया।",
        },
      },
      ta: {
        preferred: "ஆண்டவரே",
        acceptableAlternatives: ["கர்த்தரே", "இறைவா"],
        disallowedLiteral: ["லார்ட்"],
        profiles: {
          neutral: "ஆண்டவர்",
          colloquial: "ஆண்டவரே",
          formal: "இறைவன்",
          technical: "ஆண்டவர்",
        },
      },
      ml: {
        preferred: "കർത്താവേ",
        acceptableAlternatives: ["ദൈവമേ", "നാഥാ"],
        disallowedLiteral: ["ലോർഡ്"],
        profiles: {
          neutral: "കർത്താവ്",
          colloquial: "കർത്താവേ",
          formal: "സർവ്വേശ്വരൻ",
          technical: "കർത്താവ്",
        },
      },
    },
  },
  {
    termId: "fact_checking",
    sourceEn: "Fact-Checking",
    category: "fact_checking",
    translations: {
      es: {
        preferred: "Verificación de Hechos",
        acceptableAlternatives: ["Verificación de Datos", "Fact-Checking"],
        disallowedLiteral: ["Comprobación de Hechos"],
        profiles: {
          neutral: "Verificación de Hechos",
          colloquial: "Fact-Checking",
          formal: "Verificación y Validación de Hechos",
          technical: "Protocolo de Verificación de Hechos",
        },
        example: {
          sourceSentence: "Fact-checking ensures every report is verified.",
          targetSentence: "La verificación de hechos garantiza que cada informe esté verificado.",
        },
        notes: "Capitalized when referring to TruthWorld's network or formal methodology.",
      },
      te: {
        preferred: "ఫాక్ట్-చెకింగ్",
        acceptableAlternatives: ["వాస్తవ పరిశీలన", "వాస్తవ నిర్ధారణ"],
        disallowedLiteral: ["నిజాలు తనిఖీ చేయడం", "నిజాల చెకింగ్"],
        profiles: {
          neutral: "వాస్తవ పరిశీలన",
          colloquial: "ఫాక్ట్-చెకింగ్",
          formal: "వాస్తవ నిర్ధారణ మరియు ధ్రువీకరణ",
          technical: "ఫ్యాక్ట్ చెకింగ్ (వాస్తవ నిర్ధారణ)",
        },
        example: {
          sourceSentence: "Fact-checking ensures every report is verified.",
          targetSentence: "వాస్తవ పరిశీలన ప్రతి నివేదికను ధ్రువీకరించేలా చేస్తుంది.",
        },
        notes: "Transliterated 'ఫాక్ట్-చెకింగ్' is standard across Telugu news media.",
      },
      hi: {
        preferred: "फैक्ट-चेकिंग",
        acceptableAlternatives: ["तथ्य-जांच", "सत्यता-परख", "तथ्य-सत्यापन"],
        disallowedLiteral: ["तथ्यों की चेकिंग", "सच्चाई चेक करना"],
        profiles: {
          neutral: "तथ्य-जांच",
          colloquial: "फैक्ट-चेकिंग",
          formal: "तथ्य-सत्यापन एवं प्रमाणीकरण",
          technical: "फैक्ट-चेकिंग (तथ्य सत्यापन)",
        },
        example: {
          sourceSentence: "Fact-checking ensures every report is verified.",
          targetSentence: "तथ्य-जांच यह सुनिश्चित करती है कि हर रिपोर्ट सत्यापित हो।",
        },
        notes: "Standard industry nomenclature in Indian digital journalism.",
      },
      ta: {
        preferred: "உண்மை சரிபார்ப்பு",
        acceptableAlternatives: ["பேக்ட்-செக்கிங்", "தகவல் சரிபார்த்தல்"],
        disallowedLiteral: ["உண்மைகளை சோதித்தல்"],
        profiles: {
          neutral: "உண்மை சரிபார்ப்பு",
          colloquial: "பேக்ட்-செக்கிங்",
          formal: "உண்மைத்தன்மை உறுதிப்படுத்தல் மற்றும் சரிபார்த்தல்",
          technical: "உண்மை சரிபார்ப்பு நெறிமுறை",
        },
      },
      ml: {
        preferred: "വസ്തുതാ പരിശോധന",
        acceptableAlternatives: ["ഫാക്ട്-ചെക്കിംഗ്", "സത്യതാ പരിശോധന"],
        disallowedLiteral: ["കാര്യങ്ങൾ പരിശോധിക്കൽ"],
        profiles: {
          neutral: "വസ്തുതാ പരിശോധന",
          colloquial: "ഫാക്ട്-ചെക്കിംഗ്",
          formal: "വസ്തുതാ സ്ഥിരീകരണവും സാധൂകരണവും",
          technical: "വസ്തുതാ പരിശോധന പ്രോട്ടോക്കോൾ",
        },
      },
    },
  },
  {
    termId: "creator_monetization",
    sourceEn: "creator monetization",
    category: "monetization",
    translations: {
      es: {
        preferred: "monetización para creadores",
        acceptableAlternatives: ["ingresos de creadores", "monetización de contenido"],
        disallowedLiteral: ["hacer dinero de creador"],
        profiles: {
          neutral: "monetización para creadores",
          colloquial: "ganancias de creadores",
          formal: "monetización y retribución a creadores",
          technical: "arquitectura de monetización de contenido",
        },
      },
      te: {
        preferred: "క్రియేటర్ ఆదాయం",
        acceptableAlternatives: ["క్రియేటర్ మానిటైజేషన్", "కంటెంట్ ఆదాయం"],
        disallowedLiteral: ["క్రియేటర్ డబ్బు సంపాదన"],
        profiles: {
          neutral: "క్రియేటర్ ఆదాయం",
          colloquial: "క్రియేటర్ మానిటైజేషన్",
          formal: "సృష్టికర్తల ఆర్థిక ఆదాయ మార్గాలు",
          technical: "కంటెంట్ మానిటైజేషన్ వ్యవస్థ",
        },
      },
      hi: {
        preferred: "क्रिएटर कमाई",
        acceptableAlternatives: ["क्रिएटर मोनेटाइजेशन", "कंटेंट मुद्रीकरण"],
        disallowedLiteral: ["निर्माता की कमाई"],
        profiles: {
          neutral: "क्रिएटर कमाई",
          colloquial: "क्रिएटर मोनेटाइजेशन",
          formal: "रचनाकारों का वित्तीय मुद्रीकरण",
          technical: "कंटेंट मोनेटाइजेशन सिस्टम",
        },
      },
      ta: {
        preferred: "படைப்பாளர் வருமானம்",
        acceptableAlternatives: ["கிரியேட்டர் மானிடைசேஷன்", "உள்ளடக்க வருவாய்"],
        disallowedLiteral: ["படைப்பாளர் பணம் பண்ணுதல்"],
        profiles: {
          neutral: "படைப்பாளர் வருமானம்",
          colloquial: "கிரியேட்டர் மானிடைசேஷன்",
          formal: "உள்ளடக்க உருவாக்குநர் நிதி ஈட்டல்",
          technical: "உள்ளடக்க பணமாக்குதல் கட்டமைப்பு",
        },
      },
      ml: {
        preferred: "ക്രിയേറ്റർ വരുമാനം",
        acceptableAlternatives: ["ക്രിയേറ്റർ മോണിറ്റൈസേഷൻ", "കണ്ടന്റ് വരുമാനം"],
        disallowedLiteral: ["ക്രിയേറ്റർ പണമുണ്ടാക്കൽ"],
        profiles: {
          neutral: "ക്രിയേറ്റർ വരുമാനം",
          colloquial: "ക്രിയേറ്റർ മോണിറ്റൈസേഷൻ",
          formal: "ഉള്ളടക്ക സ്രഷ്ടാക്കളുടെ ധനസമ്പാദനം",
          technical: "കണ്ടന്റ് മോണിറ്റൈസേഷൻ സിസ്റ്റം",
        },
      },
    },
  },
  {
    termId: "misinformation",
    sourceEn: "misinformation",
    category: "fact_checking",
    translations: {
      es: {
        preferred: "desinformación",
        acceptableAlternatives: ["información errónea", "noticias falsas"],
        disallowedLiteral: ["mala información"],
        profiles: {
          neutral: "información errónea",
          colloquial: "noticias falsas",
          formal: "desinformación y falsedad documental",
          technical: "propagación de desinformación",
        },
      },
      te: {
        preferred: "తప్పుదోవ పట్టించే సమాచారం",
        acceptableAlternatives: ["తప్పుడు సమాచారం", "ఫేక్ న్యూస్"],
        disallowedLiteral: ["చెడు సమాచారం"],
        profiles: {
          neutral: "తప్పుదోవ పట్టించే సమాచారం",
          colloquial: "ఫేక్ న్యూస్",
          formal: "అసత్య ప్రచారం మరియు తప్పుడు సమాచారం",
          technical: "మిస్-ఇన్ఫర్మేషన్ (తప్పుడు సమాచార వ్యాప్తి)",
        },
      },
      hi: {
        preferred: "भ्रामक जानकारी",
        acceptableAlternatives: ["गलत सूचना", "फेक न्यूज़"],
        disallowedLiteral: ["बुरी सूचना"],
        profiles: {
          neutral: "भ्रामक जानकारी",
          colloquial: "फेक न्यूज़",
          formal: "असत्य एवं भ्रामक सूचना",
          technical: "मिस-इन्फॉर्मेशन (गलत सूचना प्रसार)",
        },
      },
      ta: {
        preferred: "தவறான தகவல்",
        acceptableAlternatives: ["போலி செய்தி", "திசைதிருப்பும் தகவல்"],
        disallowedLiteral: ["கெட்ட தகவல்"],
        profiles: {
          neutral: "தவறான தகவல்",
          colloquial: "போலி செய்தி",
          formal: "தவறாக வழிநடத்தும் தகவல் பரப்புரை",
          technical: "மிஸ்-இன்பர்மேஷன் (தகவல் பிழை)",
        },
      },
      ml: {
        preferred: "തെറ്റായ വിവരങ്ങൾ",
        acceptableAlternatives: ["വ്യാജ വാർത്ത", "തെറ്റിദ്ധാരണ ഉണ്ടാക്കുന്ന വിവരങ്ങൾ"],
        disallowedLiteral: ["മോശം വിവരം"],
        profiles: {
          neutral: "തെറ്റായ വിവരങ്ങൾ",
          colloquial: "വ്യാജ വാർത്ത",
          formal: "തെറ്റിദ്ധരിപ്പിക്കുന്ന വിവരങ്ങളുടെ പ്രചാരണം",
          technical: "മിസ്-ഇൻഫർമേഷൻ",
        },
      },
    },
  },
  {
    termId: "evidence_based",
    sourceEn: "evidence-based claims",
    category: "fact_checking",
    translations: {
      es: {
        preferred: "afirmaciones basadas en evidencia",
        acceptableAlternatives: ["afirmaciones sustentadas en pruebas"],
        disallowedLiteral: ["declaraciones con evidencia"],
        profiles: {
          neutral: "afirmaciones basadas en evidencia",
          colloquial: "afirmaciones comprobadas",
          formal: "declaraciones fundadas en evidencia documental",
          technical: "evaluación de afirmaciones basada en evidencia",
        },
      },
      te: {
        preferred: "ఆధారిత వాదనలు",
        acceptableAlternatives: ["సాక్ష్యాధారాలతో కూడిన వాదనలు", "రుజువున్న వివరాలు", "ఆధారిత వాదనల", "సాక్ష్యాల ఆధారిత వాదనల"],
        disallowedLiteral: ["రుజువు క్లెయిమ్‌లు"],
        profiles: {
          neutral: "ఆధారిత వాదనలు",
          colloquial: "ప్రూఫ్ ఉన్న వివరాలు",
          formal: "సాక్ష్యాధారాలతో కూడిన వాదనలు",
          technical: "ఎవిడెన్స్-బేస్డ్ అసెస్‌మెంట్",
        },
      },
      hi: {
        preferred: "साक्ष्य-आधारित दावे",
        acceptableAlternatives: ["प्रमाण-आधारित दावे", "साक्ष्य-आधारित दावों"],
        disallowedLiteral: ["सबूत वाले दावे"],
        profiles: {
          neutral: "साक्ष्य-आधारित दावे",
          colloquial: "सबूत वाले तथ्य",
          formal: "प्रमाण-आधारित सत्यापन",
          technical: "साक्ष्य-समर्थित निष्कर्ष",
        },
      },
      ta: {
        preferred: "ஆதாரப்பூர்வமான கூற்றுகள்",
        acceptableAlternatives: ["சான்றுடைய கூற்றுகள்", "ஆதாரங்களின் அடிப்படையிலான கூற்றுகள்", "ஆதாரங்களின் அடிப்படையிலான கூற்றுகளுக்காக"],
        disallowedLiteral: ["சாட்சி கிளைம்கள்"],
        profiles: {
          neutral: "ஆதாரப்பூர்வமான கூற்றுகள்",
          colloquial: "சான்றுள்ள தகவல்",
          formal: "சான்றுகளின் அடிப்படையிலான கூற்றுகள்",
          technical: "சான்றாதார மதிப்பீடு",
        },
      },
      ml: {
        preferred: "തെളിവ് അടിസ്ഥാനമാക്കിയുള്ള വാദങ്ങൾ",
        acceptableAlternatives: ["തെളിവുകളോടെയുള്ള വാദങ്ങൾ", "തെളിവുകളുടെ അടിസ്ഥാനത്തിലുള്ള അവകാശവാദങ്ങൾ", "തെളിവുകളുടെ അടിസ്ഥാനത്തിലുള്ള അവകാശവാദങ്ങൾക്കായി"],
        disallowedLiteral: ["തെളിവ് ക്ലെയിമുകൾ"],
        profiles: {
          neutral: "തെളിവ് അടിസ്ഥാനമാക്കിയുള്ള വാദങ്ങൾ",
          colloquial: "തെളിവുള്ള കാര്യം",
          formal: "തെളിവുകളാൽ സ്ഥിരീകരിച്ച നിഗമനങ്ങൾ",
          technical: "എവിഡൻസ്-ബേസ്ഡ് അനാലിസിസ്",
        },
      },
    },
  },
  {
    termId: "grid_batteries",
    sourceEn: "grid batteries",
    category: "energy_policy",
    translations: {
      es: {
        preferred: "baterías de red",
        acceptableAlternatives: ["sistemas de almacenamiento de red", "baterías de la red eléctrica"],
        disallowedLiteral: ["baterías de cuadrícula"],
        profiles: {
          neutral: "baterías de red",
          colloquial: "almacenamiento en baterías",
          formal: "sistemas de almacenamiento en red eléctrica",
          technical: "sistemas de almacenamiento BESS para red",
        },
        notes: "Never translate 'grid' as 'cuadrícula' in electrical utility context.",
      },
      te: {
        preferred: "గ్రిడ్ బ్యాటరీలు",
        acceptableAlternatives: ["విద్యుత్ గ్రిడ్ బ్యాటరీలు"],
        disallowedLiteral: ["గ్రిడ్ కణాలు", "వల బ్యాటరీలు"],
        profiles: {
          neutral: "గ్రిడ్ బ్యాటరీలు",
          colloquial: "బ్యాటరీ స్టోరేజ్",
          formal: "విద్యుత్ గ్రిడ్ నిల్వ వ్యవస్థలు",
          technical: "గ్రిడ్ స్థాయి బ్యాటరీ ఎనర్జీ స్టోరేజ్ (BESS)",
        },
      },
      hi: {
        preferred: "ग्रिड बैटरियां",
        acceptableAlternatives: ["पावर ग्रिड बैटरियां", "विद्युत ग्रिड स्टोरेज"],
        disallowedLiteral: ["जालीदार बैटरियां"],
        profiles: {
          neutral: "ग्रिड बैटरियां",
          colloquial: "बैटरी स्टोरेज",
          formal: "विद्युत ग्रिड भंडारण प्रणालियां",
          technical: "ग्रिड-स्तरीय ऊर्जा भंडारण प्रणाली",
        },
      },
      ta: {
        preferred: "மின்கட்டமைப்பு பேட்டரிகள்",
        acceptableAlternatives: ["கிரிட் பேட்டரிகள்", "மின் கட்டமைப்பு சேமிப்பு"],
        disallowedLiteral: ["வலை பேட்டரிகள்"],
        profiles: {
          neutral: "மின்கட்டமைப்பு பேட்டரிகள்",
          colloquial: "பேட்டரி சேமிப்பு",
          formal: "மின் விநியோக கட்டமைப்பு மின்கலங்கள்",
          technical: "கிரிட் பேட்டரி சேமிப்பு அமைப்பு",
        },
      },
      ml: {
        preferred: "ഗ്രിഡ് ബാറ്ററികൾ",
        acceptableAlternatives: ["വൈദ്യുതി ഗ്രിഡ് ബാറ്ററികൾ"],
        disallowedLiteral: ["വല ബാറ്ററികൾ"],
        profiles: {
          neutral: "ഗ്രിഡ് ബാറ്ററികൾ",
          colloquial: "ബാറ്ററി സ്റ്റോറേജ്",
          formal: "വൈദ്യുതി ഗ്രിഡ് സംഭരണ സംവിധാനങ്ങൾ",
          technical: "ഗ്രിഡ് എനർജി സ്റ്റോറേജ് സിസ്റ്റം",
        },
      },
    },
  },
  {
    termId: "renewable_energy",
    sourceEn: "renewable energy",
    category: "energy_policy",
    translations: {
      es: {
        preferred: "energía renovable",
        acceptableAlternatives: ["energías renovables"],
        disallowedLiteral: ["energía renovadora"],
        profiles: {
          neutral: "energía renovable",
          colloquial: "energía verde",
          formal: "fuentes de energía renovable",
          technical: "sistemas de generación de energía renovable",
        },
      },
      te: {
        preferred: "పునరుత్పాదక శక్తి",
        acceptableAlternatives: ["పునరుత్పాదక ఇంధనం"],
        disallowedLiteral: ["తిరిగి చేయదగిన శక్తి"],
        profiles: {
          neutral: "పునరుత్పాదక శక్తి",
          colloquial: "గ్రీన్ ఎనర్జీ",
          formal: "పునరుత్పాదక ఇంధన వనరులు",
          technical: "పునరుత్పాదక ఇంధన సాంకేతికత",
        },
      },
      hi: {
        preferred: "नवीकरणीय ऊर्जा",
        acceptableAlternatives: ["अक्षय ऊर्जा"],
        disallowedLiteral: ["नया करने योग्य ऊर्जा"],
        profiles: {
          neutral: "नवीकरणीय ऊर्जा",
          colloquial: "ग्रीन एनर्जी",
          formal: "अक्षय ऊर्जा संसाधन",
          technical: "नवीकरणीय ऊर्जा तंत्रज्ञान",
        },
      },
      ta: {
        preferred: "புதுப்பிக்கத்தக்க ஆற்றல்",
        acceptableAlternatives: ["புதுப்பிக்கத்தக்க எரிசக்தி"],
        disallowedLiteral: ["மீண்டும் செய்யக்கூடிய ஆற்றல்"],
        profiles: {
          neutral: "புதுப்பிக்கத்தக்க ஆற்றல்",
          colloquial: "பசுமை ஆற்றல்",
          formal: "புதுப்பிக்கத்தக்க எரிசக்தி வளங்கள்",
          technical: "மறுசுழற்சி ஆற்றல் தொழில்நுட்பம்",
        },
      },
      ml: {
        preferred: "പുനരുപയോഗ ഊർജ്ജം",
        acceptableAlternatives: ["പുനരുപയോഗ ഊർജ്ജ സ്രോതസ്സുകൾ"],
        disallowedLiteral: ["വീണ്ടും നിർമ്മിക്കാവുന്ന ഊർജ്ജം"],
        profiles: {
          neutral: "പുനരുപയോഗ ഊർജ്ജം",
          colloquial: "ഗ്രീൻ എനർജി",
          formal: "പുനരുപയോഗ ഊർജ്ജ സ്രോതസ്സുകൾ",
          technical: "റിന്യൂവബിൾ എനർജി സിസ്റ്റം",
        },
      },
    },
  },
  {
    termId: "solar_efficiency",
    sourceEn: "solar efficiency",
    category: "energy_policy",
    translations: {
      es: {
        preferred: "eficiencia solar",
        acceptableAlternatives: ["eficiencia de los paneles solares"],
        disallowedLiteral: ["eficacia solar"],
        profiles: {
          neutral: "eficiencia solar",
          colloquial: "rendimiento solar",
          formal: "eficiencia de conversión fotovoltaica",
          technical: "coeficiente de eficiencia fotovoltaica",
        },
      },
      te: {
        preferred: "సౌర సామర్థ్యం",
        acceptableAlternatives: ["సోలార్ సామర్థ్యం"],
        disallowedLiteral: ["సూర్య పనితీరు"],
        profiles: {
          neutral: "సౌర సామర్థ్యం",
          colloquial: "సోలార్ పవర్ రేటింగ్",
          formal: "సౌర విద్యుత్ ఉత్పాదక సామర్థ్యం",
          technical: "ఫోటోవోల్టాయిక్ సామర్థ్య గుణకం",
        },
      },
      hi: {
        preferred: "सौर ऊर्जा दक्षता",
        acceptableAlternatives: ["सौर दक्षता"],
        disallowedLiteral: ["सूरज की क्षमता"],
        profiles: {
          neutral: "सौर ऊर्जा दक्षता",
          colloquial: "सोलर पावर क्षमता",
          formal: "सौर रूपांतरण दक्षता",
          technical: "फोटोवोल्टाइक रूपांतरण दक्षता",
        },
      },
      ta: {
        preferred: "சூரிய ஆற்றல் திறன்",
        acceptableAlternatives: ["சோலார் திறன்"],
        disallowedLiteral: ["சூரிய சக்தி பலன்"],
        profiles: {
          neutral: "சூரிய ஆற்றல் திறன்",
          colloquial: "சோலார் பவர்",
          formal: "சூரிய ஒளிமின்னழுத்த திறன்",
          technical: "போட்டோவோல்டாயிக் திறன் விகிதம்",
        },
      },
      ml: {
        preferred: "സൗരോർജ്ജ കാര്യക്ഷമത",
        acceptableAlternatives: ["സോളാർ ശേഷി"],
        disallowedLiteral: ["സൂര്യന്റെ ശക്തി"],
        profiles: {
          neutral: "സൗരോർജ്ജ കാര്യക്ഷമത",
          colloquial: "സോളാർ പവർ",
          formal: "സൗരോർജ്ജ പരിവർത്തന കാര്യക്ഷമത",
          technical: "ഫോട്ടോവോൾട്ടായിക് എഫിഷ്യൻസി",
        },
      },
    },
  },
  {
    termId: "capacity_factor",
    sourceEn: "capacity factor",
    category: "energy_policy",
    translations: {
      es: {
        preferred: "factor de capacidad",
        acceptableAlternatives: ["factor de planta"],
        disallowedLiteral: ["factor de tamaño"],
        profiles: {
          neutral: "factor de capacidad",
          colloquial: "capacidad real de generación",
          formal: "factor de capacidad de la central",
          technical: "factor de carga y capacidad operativa",
        },
      },
      te: {
        preferred: "సామర్థ్య గుణకం",
        acceptableAlternatives: ["ప్లాంట్ సామర్థ్య నిష్పత్తి"],
        disallowedLiteral: ["సామర్థ్య అంశం"],
        profiles: {
          neutral: "సామర్థ్య గుణకం",
          colloquial: "నికర ఉత్పత్తి సామర్థ్యం",
          formal: "ఉత్పాదక కేంద్ర సామర్థ్య గుణకం",
          technical: "ప్లాంట్ కెపాసిటీ ఫ్యాక్టర్ (PCF)",
        },
      },
      hi: {
        preferred: "क्षमता कारक",
        acceptableAlternatives: ["प्लांट लोड फैक्टर"],
        disallowedLiteral: ["क्षमता का तथ्य"],
        profiles: {
          neutral: "क्षमता कारक",
          colloquial: "वास्तविक उत्पादन क्षमता",
          formal: "संयंत्र क्षमता गुणांक",
          technical: "प्लांट लोड व कैपेसिटी फैक्टर",
        },
      },
      ta: {
        preferred: "திறன் காரணி",
        acceptableAlternatives: ["மின் உற்பத்தி திறன் விகிதம்"],
        disallowedLiteral: ["திறன் அளவு"],
        profiles: {
          neutral: "திறன் காரணி",
          colloquial: "உற்பத்தி திறன்",
          formal: "மின் நிலைய திறன் காரணி",
          technical: "திறன் பயன்பாட்டு காரணி",
        },
      },
      ml: {
        preferred: "ശേഷി ഘടകം",
        acceptableAlternatives: ["പ്ലാന്റ് ശേഷി നിരക്ക്"],
        disallowedLiteral: ["ശേഷിയുടെ വസ്തുത"],
        profiles: {
          neutral: "ശേഷി ഘടകം",
          colloquial: "ഉത്പാദന ശേഷി",
          formal: "വൈദ്യുത നിലയ ശേഷി ഘടകം",
          technical: "പ്ലാന്റ് കപ്പാസിറ്റി ഫാക്ടർ",
        },
      },
    },
  },

  // ─── THEOLOGY (expanded) ──────────────────────────────────────────────────

  {
    termId: "scripture_holy",
    sourceEn: "Scripture",
    category: "theology",
    translations: {
      es: {
        preferred: "Escritura",
        acceptableAlternatives: ["Escritura Sagrada", "las Escrituras"],
        disallowedLiteral: ["Escriptura"],
        profiles: {
          neutral: "Escritura",
          colloquial: "la Biblia",
          formal: "Sagrada Escritura",
          technical: "Escritura canónica",
        },
      },
      te: {
        preferred: "లేఖనం",
        acceptableAlternatives: ["పవిత్ర గ్రంథం", "లేఖనాలు"],
        disallowedLiteral: ["స్క్రిప్చర్"],
        profiles: {
          neutral: "లేఖనం",
          colloquial: "పవిత్ర గ్రంథం",
          formal: "పరిశుద్ధ లేఖనం",
          technical: "లేఖనం (కానన్)",
        },
      },
      hi: {
        preferred: "धर्मग्रंथ",
        acceptableAlternatives: ["पवित्र शास्त्र", "शास्त्र"],
        disallowedLiteral: ["स्क्रिप्चर"],
        profiles: {
          neutral: "धर्मग्रंथ",
          colloquial: "पवित्र किताब",
          formal: "पवित्र शास्त्र",
          technical: "धर्मशास्त्र",
        },
      },
      ta: {
        preferred: "வேதாகமம்",
        acceptableAlternatives: ["திருவேதம்", "வேதம்"],
        disallowedLiteral: ["ஸ்கிரிப்சர்"],
        profiles: {
          neutral: "வேதாகமம்",
          colloquial: "திருவேதம்",
          formal: "பரிசுத்த வேதாகமம்",
          technical: "வேதாகமம் (நியதி)",
        },
      },
      ml: {
        preferred: "തിരുവെഴുത്ത്",
        acceptableAlternatives: ["വേദപുസ്തകം", "വിശുദ്ധ ഗ്രന്ഥം"],
        disallowedLiteral: ["സ്ക്രിപ്ചർ"],
        profiles: {
          neutral: "തിരുവെഴുത്ത്",
          colloquial: "വേദപുസ്തകം",
          formal: "വിശുദ്ധ തിരുവെഴുത്ത്",
          technical: "തിരുവെഴുത്ത് (കാനോൻ)",
        },
      },
      ar: {
        preferred: "الكتاب المقدس",
        acceptableAlternatives: ["الكتب المقدسة", "النصوص المقدسة"],
        disallowedLiteral: ["سكربتشر"],
        profiles: {
          neutral: "الكتاب المقدس",
          colloquial: "الكتاب",
          formal: "الكتاب المقدس",
          technical: "النص الكتابي القانوني",
        },
      },
      pt: {
        preferred: "Escritura",
        acceptableAlternatives: ["Escritura Sagrada", "as Escrituras"],
        disallowedLiteral: ["Escriptura"],
        profiles: {
          neutral: "Escritura",
          colloquial: "a Bíblia",
          formal: "Sagrada Escritura",
          technical: "Escritura canônica",
        },
      },
      fr: {
        preferred: "Écriture",
        acceptableAlternatives: ["Sainte Écriture", "les Écritures"],
        disallowedLiteral: ["Scriptur"],
        profiles: {
          neutral: "Écriture",
          colloquial: "la Bible",
          formal: "Sainte Écriture",
          technical: "Écriture canonique",
        },
      },
    },
  },
  {
    termId: "gospel",
    sourceEn: "Gospel",
    category: "theology",
    translations: {
      es: {
        preferred: "Evangelio",
        acceptableAlternatives: ["Buena Nueva"],
        disallowedLiteral: ["Gáspel"],
        profiles: {
          neutral: "Evangelio",
          colloquial: "Buena Nueva",
          formal: "Santo Evangelio",
          technical: "Evangelio sinóptico",
        },
      },
      te: {
        preferred: "సువార్త",
        acceptableAlternatives: ["శుభవార్త", "సుసమాచారం"],
        disallowedLiteral: ["గాస్పెల్"],
        profiles: {
          neutral: "సువార్త",
          colloquial: "శుభవార్త",
          formal: "పవిత్ర సువార్త",
          technical: "సువార్త (సినోప్టిక్)",
        },
      },
      hi: {
        preferred: "सुसमाचार",
        acceptableAlternatives: ["इंजील", "शुभ संदेश"],
        disallowedLiteral: ["गॉस्पेल"],
        profiles: {
          neutral: "सुसमाचार",
          colloquial: "शुभ संदेश",
          formal: "पवित्र सुसमाचार",
          technical: "सुसमाचार (सिनॉप्टिक)",
        },
      },
      ta: {
        preferred: "நற்செய்தி",
        acceptableAlternatives: ["சுவிசேஷம்", "நல்ல செய்தி"],
        disallowedLiteral: ["காஸ்பெல்"],
        profiles: {
          neutral: "நற்செய்தி",
          colloquial: "நல்ல செய்தி",
          formal: "திரு நற்செய்தி",
          technical: "சுவிசேஷம்",
        },
      },
      ml: {
        preferred: "സുവിശേഷം",
        acceptableAlternatives: ["ശുഭവാർത്ത", "നല്ല വാർത്ത"],
        disallowedLiteral: ["ഗോസ്പൽ"],
        profiles: {
          neutral: "സുവിശേഷം",
          colloquial: "ശുഭവാർത്ത",
          formal: "വിശുദ്ധ സുവിശേഷം",
          technical: "സുവിശേഷം (സിനോപ്റ്റിക്)",
        },
      },
      ar: {
        preferred: "الإنجيل",
        acceptableAlternatives: ["البشارة"],
        disallowedLiteral: ["غوسبل"],
        profiles: {
          neutral: "الإنجيل",
          colloquial: "البشارة",
          formal: "الإنجيل المقدس",
          technical: "الأناجيل الإزائية",
        },
      },
      pt: {
        preferred: "Evangelho",
        acceptableAlternatives: ["Boa Nova"],
        disallowedLiteral: ["Góspel"],
        profiles: {
          neutral: "Evangelho",
          colloquial: "Boa Nova",
          formal: "Santo Evangelho",
          technical: "Evangelho sinótico",
        },
      },
      fr: {
        preferred: "Évangile",
        acceptableAlternatives: ["Bonne Nouvelle"],
        disallowedLiteral: ["Gospel"],
        profiles: {
          neutral: "Évangile",
          colloquial: "Bonne Nouvelle",
          formal: "Saint Évangile",
          technical: "Évangile synoptique",
        },
      },
    },
  },
  {
    termId: "prophet",
    sourceEn: "Prophet",
    category: "theology",
    translations: {
      es: {
        preferred: "Profeta",
        acceptableAlternatives: ["el Profeta"],
        disallowedLiteral: ["Proféta"],
        profiles: { neutral: "Profeta", colloquial: "Profeta", formal: "el Profeta", technical: "Profeta" },
      },
      te: {
        preferred: "ప్రవక్త",
        acceptableAlternatives: ["దైవ ప్రవక్త", "ప్రవచనకర్త"],
        disallowedLiteral: ["ప్రాఫెట్"],
        profiles: { neutral: "ప్రవక్త", colloquial: "ప్రవక్త", formal: "దైవ ప్రవక్త", technical: "ప్రవచనకర్త" },
      },
      hi: {
        preferred: "नबी",
        acceptableAlternatives: ["भविष्यवक्ता", "पैगंबर"],
        disallowedLiteral: ["प्रॉफेट"],
        profiles: { neutral: "नबी", colloquial: "पैगंबर", formal: "भविष्यवक्ता", technical: "नबी" },
      },
      ta: {
        preferred: "தீர்க்கதரிசி",
        acceptableAlternatives: ["இறைவாக்கினர்", "நபி"],
        disallowedLiteral: ["புரோபெட்"],
        profiles: { neutral: "தீர்க்கதரிசி", colloquial: "நபி", formal: "இறைவாக்கினர்", technical: "தீர்க்கதரிசி" },
      },
      ml: {
        preferred: "പ്രവാചകൻ",
        acceptableAlternatives: ["ദൈവദൂതൻ", "നബി"],
        disallowedLiteral: ["പ്രോഫറ്റ്"],
        profiles: { neutral: "പ്രവാചകൻ", colloquial: "നബി", formal: "ദൈവപ്രവാചകൻ", technical: "പ്രവാചകൻ" },
      },
      ar: {
        preferred: "النبي",
        acceptableAlternatives: ["الرسول", "نبي الله"],
        disallowedLiteral: ["بروفيت"],
        profiles: { neutral: "النبي", colloquial: "النبي", formal: "نبي الله", technical: "النبي" },
      },
      pt: {
        preferred: "Profeta",
        acceptableAlternatives: ["o Profeta"],
        disallowedLiteral: ["Profêta"],
        profiles: { neutral: "Profeta", colloquial: "Profeta", formal: "o Profeta", technical: "Profeta" },
      },
      fr: {
        preferred: "Prophète",
        acceptableAlternatives: ["le Prophète"],
        disallowedLiteral: ["Prophet"],
        profiles: { neutral: "Prophète", colloquial: "Prophète", formal: "le Prophète", technical: "Prophète" },
      },
    },
  },
  {
    termId: "resurrection",
    sourceEn: "Resurrection",
    category: "theology",
    translations: {
      es: {
        preferred: "Resurrección",
        acceptableAlternatives: ["la Resurrección"],
        disallowedLiteral: ["Resurección"],
        profiles: { neutral: "Resurrección", colloquial: "Resurrección", formal: "la Santa Resurrección", technical: "Resurrección" },
      },
      te: {
        preferred: "పునరుత్థానం",
        acceptableAlternatives: ["మరణం నుండి లేచుట"],
        disallowedLiteral: ["రిజరెక్షన్"],
        profiles: { neutral: "పునరుత్థానం", colloquial: "మరణం నుండి లేచుట", formal: "పునరుత్థానం", technical: "పునరుత్థానం" },
      },
      hi: {
        preferred: "पुनरुत्थान",
        acceptableAlternatives: ["जी उठना", "मृतकों में से जी उठना"],
        disallowedLiteral: ["रिज़रेक्शन"],
        profiles: { neutral: "पुनरुत्थान", colloquial: "जी उठना", formal: "पवित्र पुनरुत्थान", technical: "पुनरुत्थान" },
      },
      ta: {
        preferred: "உயிர்த்தெழுதல்",
        acceptableAlternatives: ["உயிர்ப்பு"],
        disallowedLiteral: ["ரிசரக்ஷன்"],
        profiles: { neutral: "உயிர்த்தெழுதல்", colloquial: "உயிர்ப்பு", formal: "பரிசுத்த உயிர்த்தெழுதல்", technical: "உயிர்த்தெழுதல்" },
      },
      ml: {
        preferred: "ഉയിർപ്പ്",
        acceptableAlternatives: ["പുനരുത്ഥാനം"],
        disallowedLiteral: ["റിസറക്ഷൻ"],
        profiles: { neutral: "ഉയിർപ്പ്", colloquial: "ഉയിർപ്പ്", formal: "വിശുദ്ധ ഉയിർപ്പ്", technical: "പുനരുത്ഥാനം" },
      },
      ar: {
        preferred: "القيامة",
        acceptableAlternatives: ["البعث", "القيام من الموت"],
        disallowedLiteral: ["ريزاريكشن"],
        profiles: { neutral: "القيامة", colloquial: "البعث", formal: "القيامة المقدسة", technical: "القيامة" },
      },
      pt: {
        preferred: "Ressurreição",
        acceptableAlternatives: ["a Ressurreição"],
        disallowedLiteral: ["Resureiçao"],
        profiles: { neutral: "Ressurreição", colloquial: "Ressurreição", formal: "a Santa Ressurreição", technical: "Ressurreição" },
      },
      fr: {
        preferred: "Résurrection",
        acceptableAlternatives: ["la Résurrection"],
        disallowedLiteral: ["Resurection"],
        profiles: { neutral: "Résurrection", colloquial: "Résurrection", formal: "la Sainte Résurrection", technical: "Résurrection" },
      },
    },
  },
  {
    termId: "crucifixion",
    sourceEn: "Crucifixion",
    category: "theology",
    translations: {
      es: {
        preferred: "Crucifixión",
        acceptableAlternatives: ["la Cruz"],
        disallowedLiteral: ["Crucificción"],
        profiles: { neutral: "Crucifixión", colloquial: "la Cruz", formal: "la Santa Crucifixión", technical: "Crucifixión" },
      },
      te: {
        preferred: "సిలువ మరణం",
        acceptableAlternatives: ["సిలువ వేయడం", "క్రూసిఫిక్షన్"],
        disallowedLiteral: ["సిలువ చేయడం"],
        profiles: { neutral: "సిలువ మరణం", colloquial: "సిలువ వేయడం", formal: "సిలువ మరణం", technical: "క్రూసిఫిక్షన్" },
      },
      hi: {
        preferred: "सूली पर चढ़ाना",
        acceptableAlternatives: ["क्रूस पर मृत्यु", "सलीब"],
        disallowedLiteral: ["क्रूसीफिक्शन"],
        profiles: { neutral: "सूली पर चढ़ाना", colloquial: "सूली", formal: "क्रूस पर मृत्यु", technical: "क्रूसीकरण" },
      },
      ta: {
        preferred: "சிலுவை மரணம்",
        acceptableAlternatives: ["சிலுவையில் அறையப்படுதல்"],
        disallowedLiteral: ["க்ரூசிபிக்ஷன்"],
        profiles: { neutral: "சிலுவை மரணம்", colloquial: "சிலுவை", formal: "பரிசுத்த சிலுவை மரணம்", technical: "சிலுவையில் அறையப்படுதல்" },
      },
      ml: {
        preferred: "കുരിശുമരണം",
        acceptableAlternatives: ["ക്രൂശീകരണം"],
        disallowedLiteral: ["ക്രൂസിഫിക്ഷൻ"],
        profiles: { neutral: "കുരിശുമരണം", colloquial: "കുരിശ്", formal: "വിശുദ്ധ കുരിശുമരണം", technical: "ക്രൂശീകരണം" },
      },
      ar: {
        preferred: "الصلب",
        acceptableAlternatives: ["صلب المسيح"],
        disallowedLiteral: ["كروسيفيكشن"],
        profiles: { neutral: "الصلب", colloquial: "الصلب", formal: "صلب المسيح", technical: "الصلب" },
      },
      pt: {
        preferred: "Crucificação",
        acceptableAlternatives: ["a Cruz"],
        disallowedLiteral: ["Crucifição"],
        profiles: { neutral: "Crucificação", colloquial: "a Cruz", formal: "a Santa Crucificação", technical: "Crucificação" },
      },
      fr: {
        preferred: "Crucifixion",
        acceptableAlternatives: ["la Croix"],
        disallowedLiteral: ["Crucifiction"],
        profiles: { neutral: "Crucifixion", colloquial: "la Croix", formal: "la Sainte Crucifixion", technical: "Crucifixion" },
      },
    },
  },
  {
    termId: "salvation",
    sourceEn: "Salvation",
    category: "theology",
    translations: {
      es: {
        preferred: "Salvación",
        acceptableAlternatives: ["la Salvación"],
        disallowedLiteral: ["Salvamento"],
        profiles: { neutral: "Salvación", colloquial: "Salvación", formal: "la Santa Salvación", technical: "Soteriología" },
      },
      te: {
        preferred: "రక్షణ",
        acceptableAlternatives: ["మోక్షం", "విముక్తి"],
        disallowedLiteral: ["సాల్వేషన్"],
        profiles: { neutral: "రక్షణ", colloquial: "రక్షణ", formal: "ఆత్మ రక్షణ", technical: "రక్షణ శాస్త్రం" },
      },
      hi: {
        preferred: "मुक्ति",
        acceptableAlternatives: ["उद्धार", "मोक्ष"],
        disallowedLiteral: ["सैल्वेशन"],
        profiles: { neutral: "मुक्ति", colloquial: "उद्धार", formal: "आत्मिक मुक्ति", technical: "मुक्तिशास्त्र" },
      },
      ta: {
        preferred: "இரட்சிப்பு",
        acceptableAlternatives: ["மீட்பு", "முக்தி"],
        disallowedLiteral: ["சால்வேஷன்"],
        profiles: { neutral: "இரட்சிப்பு", colloquial: "மீட்பு", formal: "ஆன்ம இரட்சிப்பு", technical: "இரட்சிப்பு இறையியல்" },
      },
      ml: {
        preferred: "രക്ഷ",
        acceptableAlternatives: ["മോക്ഷം", "വിമോചനം"],
        disallowedLiteral: ["സാൽവേഷൻ"],
        profiles: { neutral: "രക്ഷ", colloquial: "രക്ഷ", formal: "ആത്മരക്ഷ", technical: "രക്ഷാശാസ്ത്രം" },
      },
      ar: {
        preferred: "الخلاص",
        acceptableAlternatives: ["النجاة", "الفداء"],
        disallowedLiteral: ["سالفيشن"],
        profiles: { neutral: "الخلاص", colloquial: "النجاة", formal: "الخلاص الإلهي", technical: "علم الخلاص" },
      },
      pt: {
        preferred: "Salvação",
        acceptableAlternatives: ["a Salvação", "Redenção"],
        disallowedLiteral: ["Salvamento"],
        profiles: { neutral: "Salvação", colloquial: "Salvação", formal: "a Santa Salvação", technical: "Soteriologia" },
      },
      fr: {
        preferred: "Salut",
        acceptableAlternatives: ["le Salut", "Rédemption"],
        disallowedLiteral: ["Salvation"],
        profiles: { neutral: "Salut", colloquial: "Salut", formal: "le Saint Salut", technical: "Sotériologie" },
      },
    },
  },

  // ─── FACT-CHECKING (expanded) ─────────────────────────────────────────────

  {
    termId: "disinformation",
    sourceEn: "disinformation",
    category: "fact_checking",
    translations: {
      es: {
        preferred: "desinformación intencionada",
        acceptableAlternatives: ["desinformación deliberada"],
        disallowedLiteral: ["des-información"],
        profiles: { neutral: "desinformación intencionada", colloquial: "mentiras organizadas", formal: "desinformación deliberada y orquestada", technical: "campaña de desinformación" },
        notes: "Distinct from 'misinformation' (unintentional). Disinformation implies deliberate intent.",
      },
      te: {
        preferred: "ఉద్దేశపూర్వక తప్పుడు సమాచారం",
        acceptableAlternatives: ["ఉద్దేశపూర్వక అపోహలు", "డిస్ఇన్ఫర్మేషన్"],
        disallowedLiteral: ["చెడు ఇన్ఫర్మేషన్"],
        profiles: { neutral: "ఉద్దేశపూర్వక తప్పుడు సమాచారం", colloquial: "కావాలని వ్యాపించే అబద్ధాలు", formal: "ఉద్దేశపూర్వక అసత్య ప్రచారం", technical: "డిస్-ఇన్ఫర్మేషన్ (ఉద్దేశపూర్వక)" },
      },
      hi: {
        preferred: "दुष्प्रचार",
        acceptableAlternatives: ["जानबूझकर गलत सूचना", "प्रोपेगैंडा"],
        disallowedLiteral: ["डिसइन्फॉर्मेशन"],
        profiles: { neutral: "दुष्प्रचार", colloquial: "जानबूझकर फैलाया गया झूठ", formal: "संगठित दुष्प्रचार", technical: "डिस-इन्फॉर्मेशन (जानबूझकर)" },
      },
      ta: {
        preferred: "திட்டமிட்ட தவறான தகவல்",
        acceptableAlternatives: ["வேண்டுமென்றே பரப்பும் தகவல்"],
        disallowedLiteral: ["கெட்ட இன்பர்மேஷன்"],
        profiles: { neutral: "திட்டமிட்ட தவறான தகவல்", colloquial: "வேண்டுமென்றே பரப்பும் பொய்", formal: "திட்டமிட்ட தகவல் திரிபு", technical: "டிஸ்-இன்பர்மேஷன்" },
      },
      ml: {
        preferred: "ബോധപൂർവ്വമായ തെറ്റായ വിവരം",
        acceptableAlternatives: ["ആസൂത്രിത തെറ്റായ പ്രചാരണം"],
        disallowedLiteral: ["ഡിസ്ഇൻഫർമേഷൻ"],
        profiles: { neutral: "ബോധപൂർവ്വമായ തെറ്റായ വിവരം", colloquial: "മനഃപൂർവ്വം പരത്തുന്ന നുണ", formal: "ആസൂത്രിത ദുഷ്പ്രചാരണം", technical: "ഡിസ്-ഇൻഫർമേഷൻ" },
      },
      ar: {
        preferred: "تضليل إعلامي",
        acceptableAlternatives: ["معلومات مضللة متعمدة"],
        disallowedLiteral: ["ديسانفورميشن"],
        profiles: { neutral: "تضليل إعلامي", colloquial: "أكاذيب منظمة", formal: "حملة تضليل إعلامي متعمد", technical: "تضليل معلوماتي" },
      },
      pt: {
        preferred: "desinformação",
        acceptableAlternatives: ["desinformação deliberada"],
        disallowedLiteral: ["des-informação"],
        profiles: { neutral: "desinformação", colloquial: "mentiras organizadas", formal: "desinformação deliberada e orquestrada", technical: "campanha de desinformação" },
      },
      fr: {
        preferred: "désinformation",
        acceptableAlternatives: ["désinformation délibérée"],
        disallowedLiteral: ["des-information"],
        profiles: { neutral: "désinformation", colloquial: "intox", formal: "désinformation délibérée et orchestrée", technical: "campagne de désinformation" },
      },
    },
  },
  {
    termId: "deepfake",
    sourceEn: "deepfake",
    category: "fact_checking",
    translations: {
      es: {
        preferred: "deepfake",
        acceptableAlternatives: ["ultrafalso", "falsificación profunda"],
        disallowedLiteral: ["falso profundo"],
        profiles: { neutral: "deepfake", colloquial: "deepfake", formal: "contenido sintético deepfake", technical: "deepfake (síntesis generativa adversarial)" },
      },
      te: {
        preferred: "డీప్‌ఫేక్",
        acceptableAlternatives: ["కృత్రిమ వీడియో"],
        disallowedLiteral: ["లోతైన నకిలీ"],
        profiles: { neutral: "డీప్‌ఫేక్", colloquial: "డీప్‌ఫేక్", formal: "కృత్రిమ సింథటిక్ మీడియా", technical: "డీప్‌ఫేక్ (GAN ఆధారిత)" },
      },
      hi: {
        preferred: "डीपफेक",
        acceptableAlternatives: ["कृत्रिम वीडियो"],
        disallowedLiteral: ["गहरा नकली"],
        profiles: { neutral: "डीपफेक", colloquial: "डीपफेक", formal: "कृत्रिम सिंथेटिक मीडिया", technical: "डीपफेक (GAN-आधारित)" },
      },
      ta: {
        preferred: "டீப்ஃபேக்",
        acceptableAlternatives: ["செயற்கை வீடியோ"],
        disallowedLiteral: ["ஆழமான போலி"],
        profiles: { neutral: "டீப்ஃபேக்", colloquial: "டீப்ஃபேக்", formal: "செயற்கை ஊடகம்", technical: "டீப்ஃபேக் (GAN அடிப்படையிலான)" },
      },
      ml: {
        preferred: "ഡീപ്ഫേക്ക്",
        acceptableAlternatives: ["കൃത്രിമ വീഡിയോ"],
        disallowedLiteral: ["ആഴത്തിലുള്ള വ്യാജം"],
        profiles: { neutral: "ഡീപ്ഫേക്ക്", colloquial: "ഡീപ്ഫേക്ക്", formal: "കൃത്രിമ സിന്തറ്റിക് മീഡിയ", technical: "ഡീപ്ഫേക്ക് (GAN അധിഷ്ഠിത)" },
      },
      ar: {
        preferred: "التزييف العميق",
        acceptableAlternatives: ["ديبفيك", "فيديو مزيف بالذكاء الاصطناعي"],
        disallowedLiteral: ["مزيف عميق"],
        profiles: { neutral: "التزييف العميق", colloquial: "ديبفيك", formal: "وسائط اصطناعية مزيفة", technical: "التزييف العميق (GAN)" },
      },
      pt: {
        preferred: "deepfake",
        acceptableAlternatives: ["vídeo sintético"],
        disallowedLiteral: ["falso profundo"],
        profiles: { neutral: "deepfake", colloquial: "deepfake", formal: "conteúdo sintético deepfake", technical: "deepfake (síntese adversarial generativa)" },
      },
      fr: {
        preferred: "deepfake",
        acceptableAlternatives: ["hypertrucage", "vidéo synthétique"],
        disallowedLiteral: ["faux profond"],
        profiles: { neutral: "deepfake", colloquial: "deepfake", formal: "hypertrucage synthétique", technical: "deepfake (réseau antagoniste génératif)" },
      },
    },
  },
  {
    termId: "source_verification",
    sourceEn: "source verification",
    category: "fact_checking",
    translations: {
      es: {
        preferred: "verificación de fuentes",
        acceptableAlternatives: ["comprobación de fuentes"],
        disallowedLiteral: ["verificación de origen"],
        profiles: { neutral: "verificación de fuentes", colloquial: "comprobar las fuentes", formal: "verificación y autenticación de fuentes", technical: "protocolo de verificación de fuentes" },
      },
      te: {
        preferred: "మూలం ధ్రువీకరణ",
        acceptableAlternatives: ["సోర్స్ వెరిఫికేషన్", "ఆధారాల ధ్రువీకరణ"],
        disallowedLiteral: ["మూలం చెకింగ్"],
        profiles: { neutral: "మూలం ధ్రువీకరణ", colloquial: "సోర్స్ చెక్", formal: "ఆధారాల ధ్రువీకరణ మరియు ప్రమాణీకరణ", technical: "సోర్స్ వెరిఫికేషన్ ప్రోటోకాల్" },
      },
      hi: {
        preferred: "स्रोत सत्यापन",
        acceptableAlternatives: ["सोर्स वेरिफिकेशन", "मूल जांच"],
        disallowedLiteral: ["सोर्स चेकिंग"],
        profiles: { neutral: "स्रोत सत्यापन", colloquial: "सोर्स चेक", formal: "स्रोत प्रमाणीकरण एवं सत्यापन", technical: "सोर्स वेरिफिकेशन प्रोटोकॉल" },
      },
      ta: {
        preferred: "ஆதார சரிபார்ப்பு",
        acceptableAlternatives: ["மூல ஆய்வு"],
        disallowedLiteral: ["சோர்ஸ் செக்கிங்"],
        profiles: { neutral: "ஆதார சரிபார்ப்பு", colloquial: "மூல சோதனை", formal: "ஆதார சரிபார்ப்பு மற்றும் உறுதிப்படுத்தல்", technical: "மூல சரிபார்ப்பு நெறிமுறை" },
      },
      ml: {
        preferred: "ഉറവിട പരിശോധന",
        acceptableAlternatives: ["സോഴ്സ് വെരിഫിക്കേഷൻ"],
        disallowedLiteral: ["സോഴ്സ് ചെക്കിംഗ്"],
        profiles: { neutral: "ഉറവിട പരിശോധന", colloquial: "സോഴ്സ് ചെക്ക്", formal: "ഉറവിട പരിശോധനയും സ്ഥിരീകരണവും", technical: "സോഴ്സ് വെരിഫിക്കേഷൻ പ്രോട്ടോക്കോൾ" },
      },
      ar: {
        preferred: "التحقق من المصادر",
        acceptableAlternatives: ["مراجعة المصادر"],
        disallowedLiteral: ["فحص السورس"],
        profiles: { neutral: "التحقق من المصادر", colloquial: "مراجعة المصادر", formal: "التحقق من مصداقية المصادر", technical: "بروتوكول التحقق من المصادر" },
      },
      pt: {
        preferred: "verificação de fontes",
        acceptableAlternatives: ["checagem de fontes"],
        disallowedLiteral: ["verificação de origem"],
        profiles: { neutral: "verificação de fontes", colloquial: "checar fontes", formal: "verificação e autenticação de fontes", technical: "protocolo de verificação de fontes" },
      },
      fr: {
        preferred: "vérification des sources",
        acceptableAlternatives: ["contrôle des sources"],
        disallowedLiteral: ["vérification d'origine"],
        profiles: { neutral: "vérification des sources", colloquial: "vérifier les sources", formal: "vérification et authentification des sources", technical: "protocole de vérification des sources" },
      },
    },
  },
  {
    termId: "propaganda",
    sourceEn: "propaganda",
    category: "fact_checking",
    translations: {
      es: {
        preferred: "propaganda",
        acceptableAlternatives: ["propaganda política"],
        disallowedLiteral: ["publicidad política"],
        profiles: { neutral: "propaganda", colloquial: "propaganda", formal: "propaganda y manipulación informativa", technical: "propaganda sistemática" },
      },
      te: {
        preferred: "ప్రచారం",
        acceptableAlternatives: ["ప్రొపగాండా", "దుష్ప్రచారం"],
        disallowedLiteral: ["ప్రమోషన్"],
        profiles: { neutral: "ప్రచారం", colloquial: "ప్రొపగాండా", formal: "దుష్ప్రచారం", technical: "ప్రొపగాండా (వ్యవస్థీకృత)" },
      },
      hi: {
        preferred: "प्रोपेगैंडा",
        acceptableAlternatives: ["प्रचार", "दुष्प्रचार"],
        disallowedLiteral: ["प्रमोशन"],
        profiles: { neutral: "प्रोपेगैंडा", colloquial: "प्रोपेगैंडा", formal: "संगठित दुष्प्रचार", technical: "प्रोपेगैंडा (व्यवस्थित)" },
      },
      ta: {
        preferred: "பிரச்சாரம்",
        acceptableAlternatives: ["புரொபகாண்டா", "தீவிர பிரச்சாரம்"],
        disallowedLiteral: ["விளம்பரம்"],
        profiles: { neutral: "பிரச்சாரம்", colloquial: "புரொபகாண்டா", formal: "திட்டமிட்ட பிரச்சாரம்", technical: "புரொபகாண்டா (முறையான)" },
      },
      ml: {
        preferred: "പ്രചാരണം",
        acceptableAlternatives: ["പ്രൊപഗാണ്ട", "ദുഷ്പ്രചാരണം"],
        disallowedLiteral: ["പ്രമോഷൻ"],
        profiles: { neutral: "പ്രചാരണം", colloquial: "പ്രൊപഗാണ്ട", formal: "ആസൂത്രിത ദുഷ്പ്രചാരണം", technical: "പ്രൊപഗാണ്ട (ഘടനാപരമായ)" },
      },
      ar: {
        preferred: "بروباغندا",
        acceptableAlternatives: ["دعاية", "إعلام موجه"],
        disallowedLiteral: ["إعلان سياسي"],
        profiles: { neutral: "بروباغندا", colloquial: "بروباغندا", formal: "دعاية منظمة وموجهة", technical: "بروباغندا منهجية" },
      },
      pt: {
        preferred: "propaganda",
        acceptableAlternatives: ["propaganda política"],
        disallowedLiteral: ["publicidade política"],
        profiles: { neutral: "propaganda", colloquial: "propaganda", formal: "propaganda e manipulação informativa", technical: "propaganda sistemática" },
      },
      fr: {
        preferred: "propagande",
        acceptableAlternatives: ["propagande politique"],
        disallowedLiteral: ["publicité politique"],
        profiles: { neutral: "propagande", colloquial: "propagande", formal: "propagande et manipulation de l'information", technical: "propagande systématique" },
      },
    },
  },
  {
    termId: "credibility_score",
    sourceEn: "credibility score",
    category: "fact_checking",
    translations: {
      es: {
        preferred: "puntuación de credibilidad",
        acceptableAlternatives: ["índice de credibilidad"],
        disallowedLiteral: ["puntaje de creencia"],
        profiles: { neutral: "puntuación de credibilidad", colloquial: "puntuación de confianza", formal: "índice de credibilidad informativa", technical: "métrica de credibilidad" },
      },
      te: {
        preferred: "విశ్వసనీయత స్కోరు",
        acceptableAlternatives: ["క్రెడిబిలిటీ స్కోర్"],
        disallowedLiteral: ["నమ్మకం పాయింట్లు"],
        profiles: { neutral: "విశ్వసనీయత స్కోరు", colloquial: "క్రెడిబిలిటీ స్కోర్", formal: "విశ్వసనీయత సూచిక", technical: "క్రెడిబిలిటీ మెట్రిక్" },
      },
      hi: {
        preferred: "विश्वसनीयता स्कोर",
        acceptableAlternatives: ["क्रेडिबिलिटी स्कोर"],
        disallowedLiteral: ["भरोसा अंक"],
        profiles: { neutral: "विश्वसनीयता स्कोर", colloquial: "क्रेडिबिलिटी स्कोर", formal: "विश्वसनीयता सूचकांक", technical: "क्रेडिबिलिटी मेट्रिक" },
      },
      ta: {
        preferred: "நம்பகத்தன்மை மதிப்பெண்",
        acceptableAlternatives: ["கிரெடிபிலிட்டி ஸ்கோர்"],
        disallowedLiteral: ["நம்பிக்கை புள்ளிகள்"],
        profiles: { neutral: "நம்பகத்தன்மை மதிப்பெண்", colloquial: "கிரெடிபிலிட்டி ஸ்கோர்", formal: "நம்பகத்தன்மை குறியீடு", technical: "நம்பகத்தன்மை அளவீடு" },
      },
      ml: {
        preferred: "വിശ്വാസ്യത സ്കോർ",
        acceptableAlternatives: ["ക്രെഡിബിലിറ്റി സ്കോർ"],
        disallowedLiteral: ["വിശ്വാസം പോയിന്റുകൾ"],
        profiles: { neutral: "വിശ്വാസ്യത സ്കോർ", colloquial: "ക്രെഡിബിലിറ്റി സ്കോർ", formal: "വിശ്വാസ്യത സൂചിക", technical: "ക്രെഡിബിലിറ്റി മെട്രിക്" },
      },
      ar: {
        preferred: "درجة المصداقية",
        acceptableAlternatives: ["مؤشر المصداقية"],
        disallowedLiteral: ["نقاط الثقة"],
        profiles: { neutral: "درجة المصداقية", colloquial: "درجة الثقة", formal: "مؤشر المصداقية الإعلامية", technical: "مقياس المصداقية" },
      },
      pt: {
        preferred: "pontuação de credibilidade",
        acceptableAlternatives: ["índice de credibilidade"],
        disallowedLiteral: ["pontos de crença"],
        profiles: { neutral: "pontuação de credibilidade", colloquial: "nota de confiança", formal: "índice de credibilidade informativa", technical: "métrica de credibilidade" },
      },
      fr: {
        preferred: "score de crédibilité",
        acceptableAlternatives: ["indice de crédibilité"],
        disallowedLiteral: ["points de croyance"],
        profiles: { neutral: "score de crédibilité", colloquial: "note de confiance", formal: "indice de crédibilité informationnelle", technical: "métrique de crédibilité" },
      },
    },
  },

  // ─── SCIENCE (new category — previously zero entries) ─────────────────────

  {
    termId: "climate_change",
    sourceEn: "climate change",
    category: "science",
    translations: {
      es: {
        preferred: "cambio climático",
        acceptableAlternatives: ["crisis climática"],
        disallowedLiteral: ["cambio de clima"],
        profiles: { neutral: "cambio climático", colloquial: "crisis climática", formal: "cambio climático global", technical: "cambio climático antropogénico" },
      },
      te: {
        preferred: "వాతావరణ మార్పు",
        acceptableAlternatives: ["క్లైమేట్ చేంజ్"],
        disallowedLiteral: ["వాతావరణం మారడం"],
        profiles: { neutral: "వాతావరణ మార్పు", colloquial: "క్లైమేట్ చేంజ్", formal: "ప్రపంచ వాతావరణ మార్పు", technical: "మానవజనిత వాతావరణ మార్పు" },
      },
      hi: {
        preferred: "जलवायु परिवर्तन",
        acceptableAlternatives: ["क्लाइमेट चेंज"],
        disallowedLiteral: ["मौसम बदलना"],
        profiles: { neutral: "जलवायु परिवर्तन", colloquial: "क्लाइमेट चेंज", formal: "वैश्विक जलवायु परिवर्तन", technical: "मानवजनित जलवायु परिवर्तन" },
      },
      ta: {
        preferred: "காலநிலை மாற்றம்",
        acceptableAlternatives: ["கிளைமேட் சேஞ்ச்"],
        disallowedLiteral: ["வானிலை மாறுதல்"],
        profiles: { neutral: "காலநிலை மாற்றம்", colloquial: "கிளைமேட் சேஞ்ச்", formal: "உலகளாவிய காலநிலை மாற்றம்", technical: "மனிதனால் ஏற்படும் காலநிலை மாற்றம்" },
      },
      ml: {
        preferred: "കാലാവസ്ഥാ വ്യതിയാനം",
        acceptableAlternatives: ["ക്ലൈമറ്റ് ചേഞ്ച്"],
        disallowedLiteral: ["കാലാവസ്ഥ മാറ്റം"],
        profiles: { neutral: "കാലാവസ്ഥാ വ്യതിയാനം", colloquial: "ക്ലൈമറ്റ് ചേഞ്ച്", formal: "ആഗോള കാലാവസ്ഥാ വ്യതിയാനം", technical: "മനുഷ്യനിർമ്മിത കാലാവസ്ഥാ വ്യതിയാനം" },
      },
      ar: {
        preferred: "تغير المناخ",
        acceptableAlternatives: ["أزمة المناخ"],
        disallowedLiteral: ["تغيير الطقس"],
        profiles: { neutral: "تغير المناخ", colloquial: "أزمة المناخ", formal: "تغير المناخ العالمي", technical: "تغير المناخ البشري المنشأ" },
      },
      pt: {
        preferred: "mudança climática",
        acceptableAlternatives: ["alteração climática", "crise climática"],
        disallowedLiteral: ["mudança de clima"],
        profiles: { neutral: "mudança climática", colloquial: "crise climática", formal: "mudança climática global", technical: "mudança climática antropogênica" },
      },
      fr: {
        preferred: "changement climatique",
        acceptableAlternatives: ["crise climatique", "dérèglement climatique"],
        disallowedLiteral: ["changement de climat"],
        profiles: { neutral: "changement climatique", colloquial: "crise climatique", formal: "changement climatique mondial", technical: "changement climatique anthropique" },
      },
    },
  },
  {
    termId: "vaccine",
    sourceEn: "vaccine",
    category: "science",
    translations: {
      es: {
        preferred: "vacuna",
        acceptableAlternatives: ["la vacuna"],
        disallowedLiteral: ["vaxina"],
        profiles: { neutral: "vacuna", colloquial: "vacuna", formal: "vacuna inmunológica", technical: "inmunógeno vacunal" },
      },
      te: {
        preferred: "టీకా",
        acceptableAlternatives: ["వ్యాక్సిన్"],
        disallowedLiteral: ["వాక్సీన్"],
        profiles: { neutral: "టీకా", colloquial: "టీకా", formal: "రోగ నిరోధక టీకా", technical: "వ్యాక్సిన్ (ఇమ్యునోజెన్)" },
      },
      hi: {
        preferred: "टीका",
        acceptableAlternatives: ["वैक्सीन"],
        disallowedLiteral: ["वाक्सीन"],
        profiles: { neutral: "टीका", colloquial: "टीका", formal: "प्रतिरक्षा टीका", technical: "वैक्सीन (इम्यूनोजेन)" },
      },
      ta: {
        preferred: "தடுப்பூசி",
        acceptableAlternatives: ["வாக்சின்"],
        disallowedLiteral: ["வேக்சின்"],
        profiles: { neutral: "தடுப்பூசி", colloquial: "தடுப்பூசி", formal: "நோய்த்தடுப்பு தடுப்பூசி", technical: "வாக்சின் (இம்யூனோஜென்)" },
      },
      ml: {
        preferred: "വാക്സിൻ",
        acceptableAlternatives: ["പ്രതിരോധ കുത്തിവയ്പ്"],
        disallowedLiteral: ["വാക്സീൻ"],
        profiles: { neutral: "വാക്സിൻ", colloquial: "കുത്തിവയ്പ്", formal: "രോഗപ്രതിരോധ വാക്സിൻ", technical: "വാക്സിൻ (ഇമ്യൂണോജൻ)" },
      },
      ar: {
        preferred: "لقاح",
        acceptableAlternatives: ["اللقاح", "تطعيم"],
        disallowedLiteral: ["فاكسين"],
        profiles: { neutral: "لقاح", colloquial: "تطعيم", formal: "لقاح مناعي", technical: "لقاح مناعي (مولد المضاد)" },
      },
      pt: {
        preferred: "vacina",
        acceptableAlternatives: ["a vacina"],
        disallowedLiteral: ["vaxina"],
        profiles: { neutral: "vacina", colloquial: "vacina", formal: "vacina imunológica", technical: "imunógeno vacinal" },
      },
      fr: {
        preferred: "vaccin",
        acceptableAlternatives: ["le vaccin"],
        disallowedLiteral: ["vaxin"],
        profiles: { neutral: "vaccin", colloquial: "vaccin", formal: "vaccin immunologique", technical: "immunogène vaccinal" },
      },
    },
  },
  {
    termId: "peer_review",
    sourceEn: "peer review",
    category: "science",
    translations: {
      es: {
        preferred: "revisión por pares",
        acceptableAlternatives: ["evaluación por pares"],
        disallowedLiteral: ["revisión de compañeros"],
        profiles: { neutral: "revisión por pares", colloquial: "revisión por pares", formal: "revisión por pares académica", technical: "arbitraje científico por pares" },
      },
      te: {
        preferred: "పీర్ రివ్యూ",
        acceptableAlternatives: ["సహచర సమీక్ష"],
        disallowedLiteral: ["తోటివారి సమీక్ష"],
        profiles: { neutral: "పీర్ రివ్యూ", colloquial: "పీర్ రివ్యూ", formal: "సహచర నిపుణుల సమీక్ష", technical: "పీర్ రివ్యూ (శాస్త్రీయ మధ్యవర్తిత్వం)" },
      },
      hi: {
        preferred: "पीयर रिव्यू",
        acceptableAlternatives: ["सहकर्मी समीक्षा"],
        disallowedLiteral: ["साथी समीक्षा"],
        profiles: { neutral: "पीयर रिव्यू", colloquial: "पीयर रिव्यू", formal: "सहकर्मी विशेषज्ञ समीक्षा", technical: "पीयर रिव्यू (वैज्ञानिक मध्यस्थता)" },
      },
      ta: {
        preferred: "சக மதிப்பாய்வு",
        acceptableAlternatives: ["பியர் ரிவியூ"],
        disallowedLiteral: ["நண்பர் மதிப்பாய்வு"],
        profiles: { neutral: "சக மதிப்பாய்வு", colloquial: "பியர் ரிவியூ", formal: "சக நிபுணர் மதிப்பாய்வு", technical: "பியர் ரிவியூ (அறிவியல் நடுவர் முறை)" },
      },
      ml: {
        preferred: "പിയർ റിവ്യൂ",
        acceptableAlternatives: ["സഹപ്രവർത്തക അവലോകനം"],
        disallowedLiteral: ["സുഹൃദ് അവലോകനം"],
        profiles: { neutral: "പിയർ റിവ്യൂ", colloquial: "പിയർ റിവ്യൂ", formal: "സഹപ്രവർത്തക വിദഗ്ധ അവലോകനം", technical: "പിയർ റിവ്യൂ (ശാസ്ത്രീയ മധ്യസ്ഥത)" },
      },
      ar: {
        preferred: "مراجعة الأقران",
        acceptableAlternatives: ["التحكيم العلمي"],
        disallowedLiteral: ["مراجعة الأصدقاء"],
        profiles: { neutral: "مراجعة الأقران", colloquial: "مراجعة الأقران", formal: "مراجعة الأقران الأكاديمية", technical: "التحكيم العلمي بالأقران" },
      },
      pt: {
        preferred: "revisão por pares",
        acceptableAlternatives: ["avaliação por pares"],
        disallowedLiteral: ["revisão de colegas"],
        profiles: { neutral: "revisão por pares", colloquial: "revisão por pares", formal: "revisão por pares acadêmica", technical: "arbitragem científica por pares" },
      },
      fr: {
        preferred: "évaluation par les pairs",
        acceptableAlternatives: ["examen par les pairs"],
        disallowedLiteral: ["revue de camarades"],
        profiles: { neutral: "évaluation par les pairs", colloquial: "relecture par les pairs", formal: "évaluation par les pairs académique", technical: "arbitrage scientifique par les pairs" },
      },
    },
  },
  {
    termId: "carbon_emissions",
    sourceEn: "carbon emissions",
    category: "science",
    translations: {
      es: {
        preferred: "emisiones de carbono",
        acceptableAlternatives: ["emisiones de CO2"],
        disallowedLiteral: ["emisiones de carbón"],
        profiles: { neutral: "emisiones de carbono", colloquial: "emisiones de CO2", formal: "emisiones de dióxido de carbono", technical: "emisiones de gases de efecto invernadero" },
        notes: "Never translate as 'emisiones de carbón' (coal emissions). Carbon ≠ coal.",
      },
      te: {
        preferred: "కార్బన్ ఉద్గారాలు",
        acceptableAlternatives: ["CO2 ఉద్గారాలు"],
        disallowedLiteral: ["బొగ్గు ఉద్గారాలు"],
        profiles: { neutral: "కార్బన్ ఉద్గారాలు", colloquial: "CO2 ఉద్గారాలు", formal: "కార్బన్ డయాక్సైడ్ ఉద్గారాలు", technical: "గ్రీన్‌హౌస్ వాయు ఉద్గారాలు" },
      },
      hi: {
        preferred: "कार्बन उत्सर्जन",
        acceptableAlternatives: ["CO2 उत्सर्जन"],
        disallowedLiteral: ["कोयला उत्सर्जन"],
        profiles: { neutral: "कार्बन उत्सर्जन", colloquial: "CO2 उत्सर्जन", formal: "कार्बन डाइऑक्साइड उत्सर्जन", technical: "ग्रीनहाउस गैस उत्सर्जन" },
      },
      ta: {
        preferred: "கார்பன் உமிழ்வுகள்",
        acceptableAlternatives: ["CO2 உமிழ்வுகள்"],
        disallowedLiteral: ["நிலக்கரி உமிழ்வுகள்"],
        profiles: { neutral: "கார்பன் உமிழ்வுகள்", colloquial: "CO2 உமிழ்வுகள்", formal: "கார்பன் டை ஆக்சைடு உமிழ்வுகள்", technical: "பசுமை இல்ல வாயு உமிழ்வுகள்" },
      },
      ml: {
        preferred: "കാർബൺ ഉദ്വമനം",
        acceptableAlternatives: ["CO2 ഉദ്വമനം"],
        disallowedLiteral: ["കൽക്കരി ഉദ്വമനം"],
        profiles: { neutral: "കാർബൺ ഉദ്വമനം", colloquial: "CO2 ഉദ്വമനം", formal: "കാർബൺ ഡൈ ഓക്സൈഡ് ഉദ്വമനം", technical: "ഹരിതഗൃഹ വാതക ഉദ്വമനം" },
      },
      ar: {
        preferred: "انبعاثات الكربون",
        acceptableAlternatives: ["انبعاثات ثاني أكسيد الكربون"],
        disallowedLiteral: ["انبعاثات الفحم"],
        profiles: { neutral: "انبعاثات الكربون", colloquial: "انبعاثات CO2", formal: "انبعاثات ثاني أكسيد الكربون", technical: "انبعاثات غازات الدفيئة" },
      },
      pt: {
        preferred: "emissões de carbono",
        acceptableAlternatives: ["emissões de CO2"],
        disallowedLiteral: ["emissões de carvão"],
        profiles: { neutral: "emissões de carbono", colloquial: "emissões de CO2", formal: "emissões de dióxido de carbono", technical: "emissões de gases de efeito estufa" },
      },
      fr: {
        preferred: "émissions de carbone",
        acceptableAlternatives: ["émissions de CO2"],
        disallowedLiteral: ["émissions de charbon"],
        profiles: { neutral: "émissions de carbone", colloquial: "émissions de CO2", formal: "émissions de dioxyde de carbone", technical: "émissions de gaz à effet de serre" },
      },
    },
  },

  // ─── STATISTICS (new category — previously zero entries) ──────────────────

  {
    termId: "confidence_interval",
    sourceEn: "confidence interval",
    category: "statistics",
    translations: {
      es: {
        preferred: "intervalo de confianza",
        acceptableAlternatives: ["IC"],
        disallowedLiteral: ["intervalo de fe"],
        profiles: { neutral: "intervalo de confianza", colloquial: "margen de confianza", formal: "intervalo de confianza estadístico", technical: "IC (intervalo de confianza)" },
      },
      te: {
        preferred: "విశ్వాస అంతరం",
        acceptableAlternatives: ["కాన్ఫిడెన్స్ ఇంటర్వల్"],
        disallowedLiteral: ["నమ్మకం అంతరం"],
        profiles: { neutral: "విశ్వాస అంతరం", colloquial: "కాన్ఫిడెన్స్ ఇంటర్వల్", formal: "సాంఖ్యిక విశ్వాస అంతరం", technical: "CI (విశ్వాస అంతరం)" },
      },
      hi: {
        preferred: "विश्वास अंतराल",
        acceptableAlternatives: ["कॉन्फिडेंस इंटरवल"],
        disallowedLiteral: ["भरोसा अंतराल"],
        profiles: { neutral: "विश्वास अंतराल", colloquial: "कॉन्फिडेंस इंटरवल", formal: "सांख्यिकी विश्वास अंतराल", technical: "CI (विश्वास अंतराल)" },
      },
      ta: {
        preferred: "நம்பக இடைவெளி",
        acceptableAlternatives: ["கான்ஃபிடன்ஸ் இன்டர்வல்"],
        disallowedLiteral: ["நம்பிக்கை இடைவெளி"],
        profiles: { neutral: "நம்பக இடைவெளி", colloquial: "கான்ஃபிடன்ஸ் இன்டர்வல்", formal: "புள்ளியியல் நம்பக இடைவெளி", technical: "CI (நம்பக இடைவெளி)" },
      },
      ml: {
        preferred: "വിശ്വാസ ഇടവേള",
        acceptableAlternatives: ["കോൺഫിഡൻസ് ഇന്റർവൽ"],
        disallowedLiteral: ["വിശ്വാസം ഇടവേള"],
        profiles: { neutral: "വിശ്വാസ ഇടവേള", colloquial: "കോൺഫിഡൻസ് ഇന്റർവൽ", formal: "സ്ഥിതിവിവര വിശ്വാസ ഇടവേള", technical: "CI (വിശ്വാസ ഇടവേള)" },
      },
      ar: {
        preferred: "فترة الثقة",
        acceptableAlternatives: ["مجال الثقة"],
        disallowedLiteral: ["فاصل الإيمان"],
        profiles: { neutral: "فترة الثقة", colloquial: "هامش الثقة", formal: "فترة الثقة الإحصائية", technical: "CI (فترة الثقة)" },
      },
      pt: {
        preferred: "intervalo de confiança",
        acceptableAlternatives: ["IC"],
        disallowedLiteral: ["intervalo de fé"],
        profiles: { neutral: "intervalo de confiança", colloquial: "margem de confiança", formal: "intervalo de confiança estatístico", technical: "IC (intervalo de confiança)" },
      },
      fr: {
        preferred: "intervalle de confiance",
        acceptableAlternatives: ["IC"],
        disallowedLiteral: ["intervalle de foi"],
        profiles: { neutral: "intervalle de confiance", colloquial: "marge de confiance", formal: "intervalle de confiance statistique", technical: "IC (intervalle de confiance)" },
      },
    },
  },
  {
    termId: "correlation_causation",
    sourceEn: "correlation does not imply causation",
    category: "statistics",
    translations: {
      es: {
        preferred: "correlación no implica causalidad",
        acceptableAlternatives: ["correlación no es causalidad"],
        disallowedLiteral: ["correlación no significa causar"],
        profiles: { neutral: "correlación no implica causalidad", colloquial: "que dos cosas se relacionen no significa que una cause la otra", formal: "la correlación estadística no implica relación causal", technical: "cum hoc ergo propter hoc" },
      },
      te: {
        preferred: "సహసంబంధం కారణత్వం కాదు",
        acceptableAlternatives: ["కొరిలేషన్ ఈజ్ నాట్ కాజేషన్"],
        disallowedLiteral: ["సంబంధం అంటే కారణం"],
        profiles: { neutral: "సహసంబంధం కారణత్వం కాదు", colloquial: "రెండు విషయాలు కలిసి జరగడం అంటే ఒకటి మరొకదానికి కారణం కాదు", formal: "సాంఖ్యిక సహసంబంధం కారణాత్మక సంబంధాన్ని సూచించదు", technical: "కొరిలేషన్ ≠ కాజేషన్" },
      },
      hi: {
        preferred: "सहसंबंध कारण नहीं है",
        acceptableAlternatives: ["कोरिलेशन इज़ नॉट कॉज़ेशन"],
        disallowedLiteral: ["संबंध का मतलब कारण"],
        profiles: { neutral: "सहसंबंध कारण नहीं है", colloquial: "दो चीज़ें एक साथ होने का मतलब यह नहीं कि एक दूसरी की वजह है", formal: "सांख्यिकी सहसंबंध कार्य-कारण संबंध नहीं दर्शाता", technical: "कोरिलेशन ≠ कॉज़ेशन" },
      },
      ta: {
        preferred: "தொடர்பு காரணம் அல்ல",
        acceptableAlternatives: ["கோரிலேஷன் காசேஷன் அல்ல"],
        disallowedLiteral: ["தொடர்பு என்றால் காரணம்"],
        profiles: { neutral: "தொடர்பு காரணம் அல்ல", colloquial: "இரண்டு விஷயங்கள் ஒரே நேரத்தில் நடப்பதால் ஒன்று மற்றதற்கு காரணம் என்று அர்த்தமில்லை", formal: "புள்ளியியல் தொடர்பு காரண-காரிய உறவை குறிக்காது", technical: "கோரிலேஷன் ≠ காசேஷன்" },
      },
      ml: {
        preferred: "പരസ്പരബന്ധം കാരണമല്ല",
        acceptableAlternatives: ["കോറിലേഷൻ കോസേഷൻ അല്ല"],
        disallowedLiteral: ["ബന്ധം എന്നാൽ കാരണം"],
        profiles: { neutral: "പരസ്പരബന്ധം കാരണമല്ല", colloquial: "രണ്ട് കാര്യങ്ങൾ ഒരുമിച്ച് സംഭവിക്കുന്നത് ഒന്ന് മറ്റൊന്നിന്റെ കാരണമാണെന്ന് അർത്ഥമാക്കുന്നില്ല", formal: "സ്ഥിതിവിവര പരസ്പരബന്ധം കാരണ-ഫല ബന്ധത്തെ സൂചിപ്പിക്കുന്നില്ല", technical: "കോറിലേഷൻ ≠ കോസേഷൻ" },
      },
      ar: {
        preferred: "الارتباط لا يعني السببية",
        acceptableAlternatives: ["التلازم ليس تسبباً"],
        disallowedLiteral: ["الارتباط يعني السبب"],
        profiles: { neutral: "الارتباط لا يعني السببية", colloquial: "حدوث شيئين معاً لا يعني أن أحدهما سبب الآخر", formal: "الارتباط الإحصائي لا يستلزم علاقة سببية", technical: "الارتباط ≠ السببية" },
      },
      pt: {
        preferred: "correlação não implica causalidade",
        acceptableAlternatives: ["correlação não é causalidade"],
        disallowedLiteral: ["correlação significa causa"],
        profiles: { neutral: "correlação não implica causalidade", colloquial: "duas coisas acontecerem juntas não significa que uma causa a outra", formal: "a correlação estatística não implica relação causal", technical: "correlação ≠ causalidade" },
      },
      fr: {
        preferred: "corrélation n'implique pas causalité",
        acceptableAlternatives: ["corrélation n'est pas causalité"],
        disallowedLiteral: ["corrélation signifie cause"],
        profiles: { neutral: "corrélation n'implique pas causalité", colloquial: "ce n'est pas parce que deux choses arrivent ensemble que l'une cause l'autre", formal: "la corrélation statistique n'implique pas une relation de causalité", technical: "corrélation ≠ causalité" },
      },
    },
  },

  // ─── MONETIZATION (expanded) ──────────────────────────────────────────────

  {
    termId: "revenue_share",
    sourceEn: "revenue share",
    category: "monetization",
    translations: {
      es: {
        preferred: "reparto de ingresos",
        acceptableAlternatives: ["participación en ingresos"],
        disallowedLiteral: ["compartir ingresos"],
        profiles: { neutral: "reparto de ingresos", colloquial: "reparto de ganancias", formal: "distribución proporcional de ingresos", technical: "modelo de revenue share" },
      },
      te: {
        preferred: "ఆదాయ భాగస్వామ్యం",
        acceptableAlternatives: ["రెవెన్యూ షేర్"],
        disallowedLiteral: ["ఆదాయం పంచుకోవడం"],
        profiles: { neutral: "ఆదాయ భాగస్వామ్యం", colloquial: "రెవెన్యూ షేర్", formal: "ఆదాయ విభజన నమూనా", technical: "రెవెన్యూ షేర్ మోడల్" },
      },
      hi: {
        preferred: "राजस्व हिस्सेदारी",
        acceptableAlternatives: ["रेवेन्यू शेयर"],
        disallowedLiteral: ["आय बांटना"],
        profiles: { neutral: "राजस्व हिस्सेदारी", colloquial: "रेवेन्यू शेयर", formal: "राजस्व वितरण मॉडल", technical: "रेवेन्यू शेयर मॉडल" },
      },
      ta: {
        preferred: "வருவாய் பகிர்வு",
        acceptableAlternatives: ["ரெவின்யூ ஷேர்"],
        disallowedLiteral: ["வருமானம் பகிர்தல்"],
        profiles: { neutral: "வருவாய் பகிர்வு", colloquial: "ரெவின்யூ ஷேர்", formal: "வருவாய் விநியோக மாதிரி", technical: "ரெவின்யூ ஷேர் மாடல்" },
      },
      ml: {
        preferred: "വരുമാന പങ്കിടൽ",
        acceptableAlternatives: ["റെവന്യൂ ഷെയർ"],
        disallowedLiteral: ["വരുമാനം പങ്കുവയ്ക്കൽ"],
        profiles: { neutral: "വരുമാന പങ്കിടൽ", colloquial: "റെവന്യൂ ഷെയർ", formal: "വരുമാന വിതരണ മാതൃക", technical: "റെവന്യൂ ഷെയർ മോഡൽ" },
      },
      ar: {
        preferred: "تقاسم الإيرادات",
        acceptableAlternatives: ["المشاركة في الإيرادات"],
        disallowedLiteral: ["مشاركة الدخل"],
        profiles: { neutral: "تقاسم الإيرادات", colloquial: "تقاسم الأرباح", formal: "نموذج تقاسم الإيرادات", technical: "نموذج ريفينيو شير" },
      },
      pt: {
        preferred: "compartilhamento de receita",
        acceptableAlternatives: ["divisão de receita"],
        disallowedLiteral: ["compartilhar receita"],
        profiles: { neutral: "compartilhamento de receita", colloquial: "divisão de ganhos", formal: "modelo de distribuição de receita", technical: "modelo de revenue share" },
      },
      fr: {
        preferred: "partage des revenus",
        acceptableAlternatives: ["répartition des revenus"],
        disallowedLiteral: ["partager les revenus"],
        profiles: { neutral: "partage des revenus", colloquial: "partage des gains", formal: "modèle de répartition des revenus", technical: "modèle de revenue share" },
      },
    },
  },

  // ─── HISTORICAL (new category — previously zero entries) ──────────────────

  {
    termId: "sovereignty",
    sourceEn: "sovereignty",
    category: "historical",
    translations: {
      es: {
        preferred: "soberanía",
        acceptableAlternatives: ["la soberanía"],
        disallowedLiteral: ["soberanidad"],
        profiles: { neutral: "soberanía", colloquial: "soberanía", formal: "soberanía nacional", technical: "soberanía estatal" },
      },
      te: {
        preferred: "సార్వభౌమత్వం",
        acceptableAlternatives: ["సావరిన్టీ", "సార్వభౌమాధికారం"],
        disallowedLiteral: ["సావరిన్"],
        profiles: { neutral: "సార్వభౌమత్వం", colloquial: "సార్వభౌమత్వం", formal: "జాతీయ సార్వభౌమత్వం", technical: "రాజ్య సార్వభౌమత్వం" },
      },
      hi: {
        preferred: "संप्रभुता",
        acceptableAlternatives: ["सोवरेनिटी", "सार्वभौमता"],
        disallowedLiteral: ["सोवरेन"],
        profiles: { neutral: "संप्रभुता", colloquial: "संप्रभुता", formal: "राष्ट्रीय संप्रभुता", technical: "राज्य संप्रभुता" },
      },
      ta: {
        preferred: "இறையாண்மை",
        acceptableAlternatives: ["சார்வபௌமத்துவம்"],
        disallowedLiteral: ["சாவரன்டி"],
        profiles: { neutral: "இறையாண்மை", colloquial: "இறையாண்மை", formal: "தேசிய இறையாண்மை", technical: "அரசு இறையாண்மை" },
      },
      ml: {
        preferred: "പരമാധികാരം",
        acceptableAlternatives: ["സോവറിന്റി"],
        disallowedLiteral: ["സോവറൻ"],
        profiles: { neutral: "പരമാധികാരം", colloquial: "പരമാധികാരം", formal: "ദേശീയ പരമാധികാരം", technical: "രാഷ്ട്ര പരമാധികാരം" },
      },
      ar: {
        preferred: "السيادة",
        acceptableAlternatives: ["سيادة الدولة"],
        disallowedLiteral: ["سوفرنتي"],
        profiles: { neutral: "السيادة", colloquial: "السيادة", formal: "السيادة الوطنية", technical: "سيادة الدولة" },
      },
      pt: {
        preferred: "soberania",
        acceptableAlternatives: ["a soberania"],
        disallowedLiteral: ["soberanidade"],
        profiles: { neutral: "soberania", colloquial: "soberania", formal: "soberania nacional", technical: "soberania estatal" },
      },
      fr: {
        preferred: "souveraineté",
        acceptableAlternatives: ["la souveraineté"],
        disallowedLiteral: ["souverainité"],
        profiles: { neutral: "souveraineté", colloquial: "souveraineté", formal: "souveraineté nationale", technical: "souveraineté étatique" },
      },
    },
  },
  {
    termId: "democracy",
    sourceEn: "democracy",
    category: "historical",
    translations: {
      es: {
        preferred: "democracia",
        acceptableAlternatives: ["sistema democrático"],
        disallowedLiteral: ["democratia"],
        profiles: { neutral: "democracia", colloquial: "democracia", formal: "democracia representativa", technical: "sistema democrático" },
        example: {
          sourceSentence: "Democracy depends on informed citizens.",
          targetSentence: "La democracia depende de ciudadanos informados.",
        },
      },
      te: {
        preferred: "ప్రజాస్వామ్యం",
        acceptableAlternatives: ["డెమోక్రసీ"],
        disallowedLiteral: ["డెమాక్రసీ"],
        profiles: { neutral: "ప్రజాస్వామ్యం", colloquial: "డెమోక్రసీ", formal: "ప్రజాస్వామ్య వ్యవస్థ", technical: "ప్రాతినిధ్య ప్రజాస్వామ్యం" },
        example: {
          sourceSentence: "Democracy depends on informed citizens.",
          targetSentence: "సమాచారం తెలిసిన పౌరులపై ప్రజాస్వామ్యం ఆధారపడి ఉంటుంది.",
        },
      },
      hi: {
        preferred: "लोकतंत्र",
        acceptableAlternatives: ["डेमोक्रेसी", "जनतंत्र", "लोकतन्त्र"],
        disallowedLiteral: ["डेमोक्रसी"],
        profiles: { neutral: "लोकतंत्र", colloquial: "डेमोक्रेसी", formal: "प्रतिनिधि लोकतंत्र", technical: "लोकतांत्रिक व्यवस्था" },
        example: {
          sourceSentence: "Democracy depends on informed citizens.",
          targetSentence: "सजग नागरिकों पर लोकतंत्र निर्भर करता है।",
        },
      },
      ta: {
        preferred: "ஜனநாயகம்",
        acceptableAlternatives: ["டெமாக்ரசி"],
        disallowedLiteral: ["டிமாக்ரசி"],
        profiles: { neutral: "ஜனநாயகம்", colloquial: "டெமாக்ரசி", formal: "பிரதிநிதித்துவ ஜனநாயகம்", technical: "ஜனநாயக அமைப்பு" },
      },
      ml: {
        preferred: "ജനാധിപത്യം",
        acceptableAlternatives: ["ഡെമോക്രസി"],
        disallowedLiteral: ["ഡെമാക്രസി"],
        profiles: { neutral: "ജനാധിപത്യം", colloquial: "ഡെമോക്രസി", formal: "പ്രാതിനിധ്യ ജനാധിപത്യം", technical: "ജനാധിപത്യ സംവിധാനം" },
      },
      ar: {
        preferred: "الديمقراطية",
        acceptableAlternatives: ["النظام الديمقراطي"],
        disallowedLiteral: ["ديموكراسي"],
        profiles: { neutral: "الديمقراطية", colloquial: "الديمقراطية", formal: "الديمقراطية التمثيلية", technical: "النظام الديمقراطي" },
      },
      pt: {
        preferred: "democracia",
        acceptableAlternatives: ["sistema democrático"],
        disallowedLiteral: ["democratia"],
        profiles: { neutral: "democracia", colloquial: "democracia", formal: "democracia representativa", technical: "sistema democrático" },
      },
      fr: {
        preferred: "démocratie",
        acceptableAlternatives: ["système démocratique"],
        disallowedLiteral: ["democratie"],
        profiles: { neutral: "démocratie", colloquial: "démocratie", formal: "démocratie représentative", technical: "système démocratique" },
      },
    },
  },
];

export interface TerminologyComplianceResult {
  matchedTerms: string[];
  compliantTerms: string[];
  approvedExceptions: Array<{ termId: string; matchedText: string; context: string }>;
  violations: Array<{ termId: string; source: string; disallowedFound: string; suggested: string; context?: string }>;
  complianceRate: number;
  isFullyCompliant: boolean;
}

export class TerminologyService {
  /**
   * Scans translated subtitle text and validates whether approved terms are used,
   * flagging disallowed literal mistranslations while supporting contextual alternatives,
   * profile adaptations, and documented reviewer exceptions.
   */
  public static checkTerminologyCompliance(
    sourceText: string,
    translatedText: string,
    targetLanguage: string,
    options?: {
      domainContext?: "fact_checking_news" | "energy_engineering" | "finance" | "colloquial";
      localeStyle?: TerminologyProfile;
      approvedExceptions?: string[];
    }
  ): TerminologyComplianceResult {
    const matchedTerms: string[] = [];
    const compliantTerms: string[] = [];
    const approvedExceptions: Array<{ termId: string; matchedText: string; context: string }> = [];
    const violations: Array<{ termId: string; source: string; disallowedFound: string; suggested: string; context?: string }> = [];

    const normTarget = targetLanguage.toLowerCase().slice(0, 2);
    const domainContext = options?.domainContext || "fact_checking_news";
    const approvedExceptionSet = new Set(options?.approvedExceptions || []);
    const style = options?.localeStyle;

    for (const entry of DOMAIN_GLOSSARY) {
      const sourceRegex = new RegExp(`\\b${escapeRegex(entry.sourceEn)}\\b`, 'i');
      if (sourceRegex.test(sourceText)) {
        matchedTerms.push(entry.termId);

        const langData = entry.translations[normTarget];
        if (!langData) {
          compliantTerms.push(entry.termId);
          continue;
        }

        // Check preferred, profile-specific, or acceptable alternatives
        const preferredRegex = new RegExp(escapeRegex(langData.preferred), 'i');
        const profileTerm = style && langData.profiles?.[style] ? langData.profiles[style] : null;
        const profileRegex = profileTerm ? new RegExp(escapeRegex(profileTerm), 'i') : null;

        const altMatches = langData.acceptableAlternatives.some((alt) =>
          new RegExp(escapeRegex(alt), 'i').test(translatedText)
        );

        // Check for documented reviewer exception
        const isApprovedException = approvedExceptionSet.has(entry.termId);

        if (preferredRegex.test(translatedText) || (profileRegex && profileRegex.test(translatedText)) || altMatches) {
          compliantTerms.push(entry.termId);
        } else if (isApprovedException) {
          approvedExceptions.push({
            termId: entry.termId,
            matchedText: translatedText,
            context: domainContext,
          });
          compliantTerms.push(entry.termId);
        }

        // Check for disallowed literal machine translation errors
        for (const disallowed of langData.disallowedLiteral) {
          const disRegex = new RegExp(escapeRegex(disallowed), 'i');
          if (disRegex.test(translatedText) && !isApprovedException) {
            // Guard: If the matched disallowed token is part of preferred or profile term, ignore false positive
            const isSelfSubstring = (langData.preferred.includes(disallowed) && preferredRegex.test(translatedText)) ||
              Boolean(profileTerm && profileTerm.includes(disallowed) && profileRegex && profileRegex.test(translatedText));
            if (isSelfSubstring) {
              const stripped = translatedText
                .replace(preferredRegex, "")
                .replace(profileRegex || "", "");
              if (!disRegex.test(stripped)) {
                continue;
              }
            }
            violations.push({
              termId: entry.termId,
              source: entry.sourceEn,
              disallowedFound: disallowed,
              suggested: profileTerm || langData.preferred,
              context: domainContext,
            });
          }
        }
      }
    }

    const complianceRate = matchedTerms.length > 0 ? Number((compliantTerms.length / matchedTerms.length).toFixed(4)) : 1.0;
    const isFullyCompliant = violations.length === 0;

    return {
      matchedTerms,
      compliantTerms,
      approvedExceptions,
      violations,
      complianceRate,
      isFullyCompliant,
    };
  }
}
