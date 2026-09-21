/**
 * voiceParser.js — Gemini-powered multilingual voice command parser
 * =================================================================
 * Parses phrases like:
 *   "Paracetamol 50"            (English)
 *   "பாராசிட்டமால் ஐம்பது"      (Tamil, spoken number)
 *   "पैरासिटामोल पचास"          (Hindi)
 * Falls back to a regex + synonym map when GEMINI_API_KEY is not set, so the
 * emulator/demo works offline. The synonym map also serves as the validation
 * whitelist: the model MUST return a medicine key from this list.
 *
 * Canonical medicine keys EXACTLY match data/inventory_seed.json
 * (see main.py sanitize_key): safe for Realtime Database paths.
 */

const SYNONYMS = {
  "Paracetamol_500mg": ["paracetamol", "para set amol", "dolo", "crocin",
    "பாராசிட்டமால்", "பாராசிட்டமோல்", "पैरासिटामोल", "पैरासिटामॉल"],
  "Amoxicillin_500mg": ["amoxicillin", "amox", "mox", "amoxycillin",
    "அமாக்சிசிலின்", "एमोक्सिसिलिन"],
  "ORS_Low-Osmolarity": ["ors", "o r s", "electral",
    "ஓஆர்எஸ்", "ஓ ஆர் எஸ்", "ओआरएस"],
  "Metformin_500mg": ["metformin", "glucophage", "மெட்ஃபார்மின்", "मेटफॉर्मिन"],
  "Amlodipine_5mg": ["amlodipine", "amlo", "அம்லோடிபின்", "अम्लोडिपिन"],
  "Salbutamol_100mcg": ["salbutamol", "asthalin", "inhaler", "சால்புட்டமால்", "साल्बुटामोल"],
  "Cetirizine_10mg": ["cetirizine", "cetzine", "செட்டிரிசின்", "सेट्रिजिन"],
  "Diclofenac_50mg": ["diclofenac", "voveran", "டைக்ளோஃபினாக்", "डाइक्लोफेनाक"],
  "Ondansetron_4mg": ["ondansetron", "emeset", "ஒண்டான்செட்ரான்", "ओन्डानसेट्रोन"],
  "Ferrous-Sulphate_60mg": ["ferrous", "iron", "ferrous sulphate", "இரும்பு", "आयरन"],
};

const WORD_NUMBERS = {
  // English
  one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8,
  nine: 9, ten: 10, twenty: 20, thirty: 30, forty: 40, fifty: 50,
  sixty: 60, seventy: 70, eighty: 80, ninety: 90, hundred: 100,
  // Tamil (transliterated + script)
  onru: 1, rendu: 2, moonu: 3, naalu: 4, anju: 5, aaru: 6, ezhu: 7, ettu: 8,
  onbadu: 9, pathu: 10, irupathu: 20, muppathu: 30, naarpattu: 40,
  aimpattu: 50, arupattu: 60, ezhupattu: 70, enbathu: 80, nooru: 100,
  "ஒன்று": 1, "இரண்டு": 2, "மூன்று": 3, "நான்கு": 4, "ஐந்து": 5,
  "பத்து": 10, "இருபது": 20, "ஐம்பது": 50, "நூறு": 100,
  // Hindi
  ek: 1, do: 2, teen: 3, chaar: 4, paanch: 5, panch: 5, chah: 6, saat: 7,
  aath: 8, nau: 9, das: 10, bees: 20, tees: 30, chalis: 40, pachaas: 50,
  saath: 70, assi: 80, nabbe: 100,
  "पचास": 50, "दस": 10, "बीस": 20, "सौ": 100,
};

let _index = null;

function buildIndex() {
  if (_index) return _index;
  const index = [];
  for (const [key, syns] of Object.entries(SYNONYMS)) {
    for (const s of syns) index.push({ needle: s.toLowerCase(), key });
  }
  index.sort((a, b) => b.needle.length - a.needle.length); // longest match first
  _index = index;
  return index;
}

function matchMedicine(text) {
  const lower = text.toLowerCase();
  for (const { needle, key } of buildIndex()) {
    if (lower.includes(needle)) return { key, spoken: needle };
  }
  return null;
}

function parseQuantity(text) {
  // 1) digits
  const digits = text.match(/\d+/);
  if (digits) return Number(digits[0]);
  // 2) word numbers (largest wins, e.g. "aimpattu" = 50)
  const words = text.toLowerCase().split(/[\s,]+/);
  let best = null;
  for (const w of words) {
    if (WORD_NUMBERS[w] != null && (best === null || WORD_NUMBERS[w] > best)) {
      best = WORD_NUMBERS[w];
    }
  }
  return best;
}

/** Local fallback parser (no API key needed). */
function parseLocal(text) {
  const med = matchMedicine(text);
  if (!med) return { ok: false, reason: "medicine-not-recognized" };
  const qty = parseQuantity(text);
  if (qty == null) return { ok: false, reason: "quantity-not-found" };
  const type = /(restock|received|new stock|வந்த|आया)/i.test(text) ? "restock" : "dispense";
  return { ok: true, medicineKey: med.key, spoken: med.spoken, quantity: qty, type, engine: "regex" };
}

/** Gemini parse with graceful fallback to regex. */
async function parseCommand(text, lang = "ta") {
  const key = process.env.GEMINI_API_KEY || "";
  if (!key) return parseLocal(text);
  try {
    const prompt = `You are a pharmacy stock-entry parser for Indian PHCs.
Extract (medicine_key, quantity, type) from the utterance. type is "dispense" or "restock".
Allowed medicine keys: ${Object.keys(SYNONYMS).join(", ")}.
Utterance (${lang}): "${text}"
Respond ONLY with JSON: {"medicine_key":"...","quantity":Number,"type":"dispense|restock"}`;
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${key}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0, maxOutputTokens: 100 },
        }),
      }
    );
    if (!res.ok) throw new Error(`gemini ${res.status}`);
    const data = await res.json();
    const raw = (data.candidates?.[0]?.content?.parts?.[0]?.text) || "";
    const match = raw.match(/\{[\s\S]*\}/);
    if (!match) return parseLocal(text);
    const j = JSON.parse(match[0]);
    if (!SYNONYMS[j.medicine_key]) return parseLocal(text); // whitelist validation
    return {
      ok: true,
      medicineKey: j.medicine_key,
      spoken: text,
      quantity: Number(j.quantity),
      type: j.type === "restock" ? "restock" : "dispense",
      engine: "gemini",
    };
  } catch (e) {
    return parseLocal(text);
  }
}

module.exports = { parseCommand, parseLocal, SYNONYMS, WORD_NUMBERS };
