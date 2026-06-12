/**
 * VoiceBill Cloud Functions
 *
 * Proxy an toàn để gọi Gemini. API key được lưu trong Secret Manager
 * (KHÔNG nhúng vào app). Client gọi qua callable function đã xác thực
 * bằng Firebase Auth, nên không ai lấy được key từ file APK/IPA.
 *
 * Trước khi deploy lần đầu, set secret:
 *   firebase functions:secrets:set GEMINI_API_KEY
 * rồi:
 *   firebase deploy --only functions
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { setGlobalOptions } = require("firebase-functions/v2");

// Region gần Việt Nam nhất để giảm độ trễ. Client phải dùng cùng region.
setGlobalOptions({ region: "asia-southeast1" });

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// Model có thể đổi tại đây mà không cần sửa client.
const GEMINI_MODEL = "gemini-2.5-flash";
const GEMINI_ENDPOINT = (model, key) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`;

/**
 * Gọi Gemini và trả về chuỗi text thô.
 */
async function callGemini(promptObject, apiKey) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20000);
  try {
    const res = await fetch(GEMINI_ENDPOINT(GEMINI_MODEL, apiKey), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: controller.signal,
      body: JSON.stringify({
        contents: [{ parts: [{ text: JSON.stringify(promptObject) }] }],
        generationConfig: {
          temperature: 0.1,
          responseMimeType: "application/json",
        },
      }),
    });

    if (!res.ok) {
      const body = await res.text();
      throw new HttpsError("internal", `Gemini API error: ${res.status} ${body}`);
    }

    const data = await res.json();
    const text =
      data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "[]";
    return text;
  } catch (err) {
    if (err.name === "AbortError") {
      throw new HttpsError("deadline-exceeded", "Gemini timeout");
    }
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("internal", `Gemini call failed: ${err}`);
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Bóc tách JSON array từ text Gemini trả về.
 */
function extractJsonArray(text) {
  const cleaned = text.replace(/```json/g, "").replace(/```/g, "").trim();
  try {
    const decoded = JSON.parse(cleaned);
    return Array.isArray(decoded) ? decoded : [];
  } catch (_) {
    return [];
  }
}

/**
 * Chuẩn hóa danh mục sản phẩm gửi từ client để nhúng vào prompt,
 * giúp Gemini khớp đúng tên và tự điền giá khi người dùng không đọc giá.
 */
function sanitizeCatalog(products) {
  if (!Array.isArray(products)) return [];
  return products
    .slice(0, 300)
    .map((p) => ({
      name: String(p?.name ?? "").slice(0, 120),
      price: Number.isFinite(p?.price) ? Math.trunc(p.price) : 0,
    }))
    .filter((p) => p.name.length > 0);
}

// ---------------------------------------------------------------------------
// parseSale: bóc tách câu nói bán hàng thành [{name, quantity, price}]
// ---------------------------------------------------------------------------
exports.parseSale = onCall({ secrets: [GEMINI_API_KEY] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Cần đăng nhập");
  }
  const text = String(request.data?.text ?? "").trim();
  if (!text) return { items: [] };
  if (text.length > 1000) {
    throw new HttpsError("invalid-argument", "Đầu vào quá dài");
  }

  const catalog = sanitizeCatalog(request.data?.products);

  const prompt = {
    instruction:
      "Parse the following Vietnamese sale speech into a JSON array of items.",
    input: text,
    catalog,
    rules: [
      "Return ONLY a JSON array, no markdown, no explanation",
      'Each item: {"name": string, "quantity": int, "price": int}',
      "Name in Vietnamese, quantity and price are integers",
      "If quantity is missing, default to 1. If price is missing, default to 0.",
      "Merge duplicate items by summing quantity.",
      'Vietnamese currency format: "15.000đ" or "15,000" or "15000" -> 15000',
      "If a 'catalog' is provided, match item names to the closest catalog name (fix typos/spacing/accents) and use the catalog price when the speaker did not say a price",
      "If unclear, make your best guess from context",
    ],
    examples: [
      {
        input: "tao 2 15000, cam 1 12000",
        output: [
          { name: "Táo", quantity: 2, price: 15000 },
          { name: "Cam", quantity: 1, price: 12000 },
        ],
      },
      {
        input: "mua 3 bia tiger va 2 cocacola va 5 goi mi tom",
        output: [
          { name: "Bia Tiger", quantity: 3, price: 0 },
          { name: "Coca Cola", quantity: 2, price: 0 },
          { name: "Mì Tôm", quantity: 5, price: 0 },
        ],
      },
    ],
  };

  const text2 = await callGemini(prompt, GEMINI_API_KEY.value());
  return { items: extractJsonArray(text2) };
});

// ---------------------------------------------------------------------------
// parseStock: bóc tách câu nói nhập hàng thành [{name, unit, price}]
// ---------------------------------------------------------------------------
exports.parseStock = onCall({ secrets: [GEMINI_API_KEY] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Cần đăng nhập");
  }
  const text = String(request.data?.text ?? "").trim();
  if (!text) return { items: [] };
  if (text.length > 1000) {
    throw new HttpsError("invalid-argument", "Đầu vào quá dài");
  }

  const catalog = sanitizeCatalog(request.data?.products);

  const prompt = {
    instruction:
      "Parse the following Vietnamese stock entry speech into a JSON array of items.",
    input: text,
    catalog,
    rules: [
      "Return ONLY a JSON array, no markdown, no explanation",
      'Each item: {"name": string, "unit": string, "price": int, "quantity": int}',
      "Name in Vietnamese; unit in Vietnamese (cái, kg, lít, hộp, chai, lon, gói, thùng, lốc, vỉ, bao, két, bó...)",
      "quantity = how many units are added to stock; default 1 if not said",
      'Default unit to "cái" if missing, default price to 0 if missing',
      "Numbers may be spoken as words: 'ba' -> 3, 'mười lăm' -> 15, 'hai mươi lăm' -> 25",
      "Normalize prices: '20.000đ' -> 20000, '90k' -> 90000, '150 nghìn'/'150 ngàn' -> 150000, 'một triệu rưỡi' -> 1500000",
      "Ignore filler words: nhập, thêm, cho, lấy, mua, vào kho",
      "If a 'catalog' is provided, match item names to the closest catalog name (fix typos/spacing/accents)",
    ],
    examples: [
      {
        input: "tao 1kg 20000, cam 1kg 18000",
        output: [
          { name: "Táo", unit: "kg", price: 20000, quantity: 1 },
          { name: "Cam", unit: "kg", price: 18000, quantity: 1 },
        ],
      },
      {
        input: "nhập thêm sting đỏ ba thùng một trăm năm mươi nghìn",
        output: [
          { name: "Sting Đỏ", unit: "thùng", price: 150000, quantity: 3 },
        ],
      },
      {
        input: "2 lốc cocacola 90k và 1 chai nước mắm 35 nghìn",
        output: [
          { name: "Coca Cola", unit: "lốc", price: 90000, quantity: 2 },
          { name: "Nước Mắm", unit: "chai", price: 35000, quantity: 1 },
        ],
      },
    ],
  };

  const text2 = await callGemini(prompt, GEMINI_API_KEY.value());
  return { items: extractJsonArray(text2) };
});
