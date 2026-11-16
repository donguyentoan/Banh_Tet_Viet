/**
 * Logic chung SePay/VietQR cho phía UI.
 *
 * Nguồn sự thật nằm ở `server/sepay.ts` để dùng chung với webhook
 * (`api/sepay-webhook.ts`) - tránh tình trạng QR ghi nội dung khác với
 * nội dung webhook bóc ra.
 */
export {
  buildPaymentContent,
  buildVietQrUrl,
  extractOrderId,
  normalizeOrderId,
  SEPAY_BANK,
  SEPAY_CONTENT_PREFIX,
  SEPAY_PAYMENT_STATUS_PAID,
} from "../../server/sepay";
