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
  notes?: string;
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
      const sourceRegex = new RegExp(`\\b${entry.sourceEn.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&')}\\b`, 'i');
      if (sourceRegex.test(sourceText)) {
        matchedTerms.push(entry.termId);

        const langData = entry.translations[normTarget];
        if (!langData) {
          compliantTerms.push(entry.termId);
          continue;
        }

        // Check preferred, profile-specific, or acceptable alternatives
        const preferredRegex = new RegExp(langData.preferred.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&'), 'i');
        const profileTerm = style && langData.profiles?.[style] ? langData.profiles[style] : null;
        const profileRegex = profileTerm ? new RegExp(profileTerm.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&'), 'i') : null;

        const altMatches = langData.acceptableAlternatives.some((alt) =>
          new RegExp(alt.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&'), 'i').test(translatedText)
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
          const disRegex = new RegExp(disallowed.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&'), 'i');
          if (disRegex.test(translatedText) && !isApprovedException) {
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
