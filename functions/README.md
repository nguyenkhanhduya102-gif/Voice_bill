# VoiceBill Cloud Functions

Proxy an toàn để gọi Gemini. API key nằm ở server (Secret Manager), không nhúng vào app.

## Yêu cầu
- Firebase CLI: `npm install -g firebase-tools`
- Dự án Firebase đã bật gói **Blaze** (Cloud Functions cần Blaze).
- Node.js 20.

## Cài đặt & deploy lần đầu

```bash
cd functions
npm install

# Nạp Gemini API key vào Secret Manager (chạy 1 lần, dán key khi được hỏi)
firebase functions:secrets:set GEMINI_API_KEY

# Deploy 2 function: parseSale, parseStock
firebase deploy --only functions
```

## Lưu ý
- Region đang đặt `asia-southeast1` (Singapore). Client (`GeminiService`) phải dùng đúng region này.
- Đổi model Gemini tại hằng `GEMINI_MODEL` trong `index.js`.
- Nếu chưa deploy, app vẫn chạy: nó tự fallback sang parser local (rule-based).

## Cập nhật key sau này
```bash
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions
```
