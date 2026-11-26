/**
 * Clip 2 regression (Telugu read with English phonetics, voice drifting between scenes),
 * extended to every language TruthWorld dubs with eleven_v4.
 */
import {
  applyDubbingStabilityFloor,
  assertNativeScriptForTts,
  ELEVEN_V4_LANGUAGE_CODES,
  elevenLabsLanguageCode,
  isElevenV4Language,
  MIN_DUBBING_STABILITY,
  nativeScriptRatio,
  NonNativeScriptError,
  requiresNativeScript,
} from "../../src/pipeline/services/dubbing-guards";

/** TruthWorld's dubbing gate list (V4_PREMIUM_80_LANGUAGES in tts.ts), copied so this test stays dependency-free. */
const TRUTHWORLD_DUB_LANGUAGES = [
  "te", "hi", "ta", "kn", "ml", "bn", "mr", "gu", "pa", "or", "as", "ur", "sa", "ks", "sd",
  "en", "es", "fr", "de", "it", "pt", "nl", "ru", "pl", "sv", "no", "da", "fi", "cs", "sk",
  "el", "hu", "ro", "bg", "hr", "sr", "uk", "sl", "lt", "lv", "et", "ga", "cy", "ca", "gl",
  "eu", "is", "sq", "mk", "bs",
  "zh", "ja", "ko", "id", "ms", "vi", "th", "fil", "tl", "my", "km", "lo", "ka", "hy", "az",
  "kk", "uz", "mn", "ne", "si",
  "ar", "he", "fa", "tr", "ku", "ps",
  "sw", "af", "zu", "xh", "ha", "yo", "ig", "am", "so",
];

/** In TruthWorld's list but not on ElevenLabs' published eleven_v4 list (2026-11-19). */
const NOT_ON_V4_LIST = ["sa", "ks", "ga", "eu", "sq", "km", "si", "ku", "xh", "yo", "ig"];

/** One correct dubbing line per non-Latin-script language. */
const NATIVE_SAMPLES: Record<string, string> = {
  te: "చింతించకు. మేము ఇక్కడ మిమ్మల్ని జాగ్రత్తగా చూసుకుంటాం.",
  ta: "கவலைப்படாதீர்கள். நாங்கள் உங்களை நன்றாக கவனித்துக்கொள்வோம்.",
  kn: "ಚಿಂತಿಸಬೇಡಿ. ನಾವು ನಿಮ್ಮನ್ನು ಚೆನ್ನಾಗಿ ನೋಡಿಕೊಳ್ಳುತ್ತೇವೆ.",
  ml: "വിഷമിക്കേണ്ട. ഞങ്ങൾ നിങ്ങളെ നന്നായി നോക്കും.",
  mr: "काळजी करू नका. आम्ही तुमची काळजी घेऊ.",
  ne: "चिन्ता नगर्नुहोस्। हामी तपाईंको हेरचाह गर्छौं।",
  bn: "চিন্তা করবেন না। আমরা আপনাদের ভালো করে দেখব।",
  as: "চিন্তা নকৰিব। আমি আপোনালোকৰ যত্ন ল'ম।",
  gu: "ચિંતા કરશો નહીં. અમે તમારી સંભાળ રાખીશું.",
  pa: "ਚਿੰਤਾ ਨਾ ਕਰੋ। ਅਸੀਂ ਤੁਹਾਡਾ ਧਿਆਨ ਰੱਖਾਂਗੇ।",
  or: "ଚିନ୍ତା କରନ୍ତୁ ନାହିଁ। ଆମେ ଆପଣଙ୍କର ଯତ୍ନ ନେବୁ।",
  ur: "فکر نہ کریں۔ ہم آپ کا خیال رکھیں گے۔",
  sd: "فڪر نه ڪريو. اسان توهان جو خيال رکنداسين.",
  ar: "لا تقلقوا. سنعتني بكم جيداً هنا.",
  fa: "نگران نباشید. ما اینجا از شما مراقبت می‌کنیم.",
  ps: "اندېښنه مه کوئ. موږ به ستاسو پاملرنه وکړو.",
  he: "אל תדאגו. נשמור עליכם היטב כאן.",
  el: "Μην ανησυχείτε. Θα σας φροντίσουμε καλά εδώ.",
  ru: "Не волнуйтесь. Мы о вас хорошо позаботимся.",
  uk: "Не хвилюйтеся. Ми добре про вас подбаємо.",
  bg: "Не се тревожете. Ще се грижим добре за вас.",
  mk: "Не грижете се. Ќе се грижиме добро за вас.",
  hy: "Մի անհանգստացեք։ Մենք լավ կհոգանք ձեր մասին։",
  ka: "ნუ ღელავთ. ჩვენ კარგად მოგივლით.",
  am: "አትጨነቁ። በደንብ እንንከባከባችኋለን።",
  th: "ไม่ต้องกังวล เราจะดูแลพวกคุณอย่างดี",
  lo: "ບໍ່ຕ້ອງເປັນຫ່ວງ ພວກເຮົາຈະເບິ່ງແຍງພວກເຈົ້າ",
  my: "စိတ်မပူပါနဲ့။ ကျွန်တော်တို့ ဂရုစိုက်ပေးပါမယ်။",
  zh: "别担心，我们会在这里好好照顾你们。",
  ja: "心配しないでください。ここでしっかりお世話します。",
  ko: "걱정하지 마세요. 저희가 잘 돌봐 드릴게요.",
};

describe("language_code for every eleven_v4 language", () => {
  test("the v4 list has the 91 languages ElevenLabs publishes", () => {
    expect(ELEVEN_V4_LANGUAGE_CODES.size).toBe(91);
  });

  test("every TruthWorld dubbing language on the v4 list gets a language_code", () => {
    const covered = TRUTHWORLD_DUB_LANGUAGES.filter((l) => !NOT_ON_V4_LIST.includes(l));
    expect(covered.length).toBe(74);
    for (const lang of covered) {
      expect(elevenLabsLanguageCode(lang)).toBeDefined();
    }
  });

  test("Tagalog is sent as Filipino", () => {
    expect(elevenLabsLanguageCode("tl")).toBe("fil");
    expect(elevenLabsLanguageCode("fil")).toBe("fil");
  });

  test("languages missing from the v4 list are never sent a code ElevenLabs would reject", () => {
    for (const lang of NOT_ON_V4_LIST) {
      expect(isElevenV4Language(lang)).toBe(false);
      expect(elevenLabsLanguageCode(lang)).toBeUndefined();
    }
  });

  test("region and casing forms resolve", () => {
    expect(elevenLabsLanguageCode("te-IN")).toBe("te");
    expect(elevenLabsLanguageCode("PT_br")).toBe("pt");
    expect(elevenLabsLanguageCode("zh-CN")).toBe("zh");
    expect(elevenLabsLanguageCode(undefined)).toBeUndefined();
  });
});

describe("native-script guard for every non-Latin dubbing language", () => {
  test.each(Object.entries(NATIVE_SAMPLES))("correct %s text passes", (lang, line) => {
    expect(requiresNativeScript(lang)).toBe(true);
    expect(nativeScriptRatio(line, lang)).toBeGreaterThan(0.9);
    expect(() => assertNativeScriptForTts(`[calm] ${line}`, lang)).not.toThrow();
  });

  test.each(Object.keys(NATIVE_SAMPLES))("an untranslated English line on a %s track is rejected", (lang) => {
    expect(() => assertNativeScriptForTts("Don't worry, we will take good care of you here.", lang))
      .toThrow(NonNativeScriptError);
  });

  test.each(Object.entries(NATIVE_SAMPLES))("mojibake %s text is rejected", (lang, line) => {
    const mojibake = Buffer.from(line, "utf8").toString("latin1");
    expect(() => assertNativeScriptForTts(mojibake, lang)).toThrow(NonNativeScriptError);
  });

  test("romanized Telugu is rejected; one Latin proper noun is allowed", () => {
    expect(() => assertNativeScriptForTts("Chintinchaku. Memu ikkada ninnu chusukuntam.", "te")).toThrow(/native script/);
    expect(() => assertNativeScriptForTts("ఫరో Pharaoh తన రొట్టెలవాడిపై కోపంగా ఉన్నాడు.", "te")).not.toThrow();
  });

  test("Japanese with a katakana loanword and a Latin brand name passes", () => {
    expect(() => assertNativeScriptForTts("このビデオはYouTubeで公開されました。", "ja")).not.toThrow();
  });

  test("mixed-script and Latin-script languages are not checked", () => {
    for (const lang of ["hi", "sr", "uz", "az", "kk", "mn", "en", "es", "fr", "de", "tr", "vi", "id", "sw", "fil"]) {
      expect(requiresNativeScript(lang)).toBe(false);
      expect(() => assertNativeScriptForTts("Yeh video bahut interesting hai", lang)).not.toThrow();
    }
  });
});

describe("stability floor", () => {
  test("every non-English dubbing language is floored", () => {
    for (const lang of TRUTHWORLD_DUB_LANGUAGES.filter((l) => l !== "en")) {
      expect(applyDubbingStabilityFloor(0.2, lang)).toBe(MIN_DUBBING_STABILITY);
      expect(applyDubbingStabilityFloor(0.8, lang)).toBe(0.8);
    }
  });

  test("English keeps the expressive range", () => {
    expect(applyDubbingStabilityFloor(0.2, "en")).toBe(0.2);
    expect(applyDubbingStabilityFloor(0.2, "en-US")).toBe(0.2);
  });
});
