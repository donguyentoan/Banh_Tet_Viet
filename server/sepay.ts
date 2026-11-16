/**
 * Logic chung cho tích hợp SePay / VietQR.
 *
 * Đặt trong `server/` vì được dùng bởi cả:
 *  - API function `api/sepay-webhook.ts` (Vercel runtime)
 *  - UI React trong `src/` (client runtime)
 *
 * Không dùng bất kỳ API nào của trình duyệt hay Node ở đây để chạy được
 * ở cả hai môi trường.
 */

/** Thông tin tài khoản ngân hàng nhận tiền bánh Tết. */
export const SEPAY_BANK = {
  /** Mã ngân hàng theo chuẩn VietQR (BIDV, MB, VCB, Techcombank, ...) */
  bank: "BIDV",
  /** Số tài khoản */
  accountNo: "962471364V",
  /** Tên chủ tài khoản */
  accountName: "DO NGUYEN TOAN",
} as const;

/** Tiền tố nội dung chuyển khoản. Webhook bóc mã đơn từ tiền tố này. */
export const SEPAY_CONTENT_PREFIX = "TET";

/** Trạng thái thanh toán được webhook ghi vào đơn. */
export const SEPAY_PAYMENT_STATUS_PAID = "Đã thanh toán";

/**
 * Khoản trừ an toàn khi so khớp mã đơn: bỏ dấu gạch ngang, khoảng trắng
 * và chuyển chữ hoa. Giúp "TETTB2027-004" và "TETTB2027004" là một.
 */
export function normalizeOrderId(value: string): string {
  return value.replace(/[\s-]/g, "").toUpperCase();
}

/**
 * Tạo nội dung chuyển khoản có gắn mã đơn để webhook đối soát.
 * Ví dụ: orderId = "TB2027-004" -> "TETTB2027-004"
 */
export function buildPaymentContent(orderId: string): string {
  return `${SEPAY_CONTENT_PREFIX}${orderId}`;
}

/**
 * Bóc mã đơn từ nội dung chuyển khoản.
 *
 * Nội dung có thể bị ngân hàng thêm/bớt ký tự (chèn khoảng trắng, đổi ký tự
 * đặc biệt, bỏ tiền tố...), nên ta thử nhiều dạng và so khớp với danh sách
 * mã đơn đang có trong hệ thống.
 *
 * @returns mã đơn gốc (đúng định dạng trong hệ thống), hoặc null nếu không khớp.
 */
export function extractOrderId(
  content: string,
  knownOrderIds: string[],
): string | null {
  const raw = String(content ?? "").trim();
  if (!raw) return null;

  const prefix = SEPAY_CONTENT_PREFIX;
  const upper = raw.toUpperCase();

  // Lấy mọi đoạn bắt đầu bằng tiền tố (nội dung có thể có thêm chữ)
  const candidates: string[] = [];
  let idx = upper.indexOf(prefix);
  while (idx !== -1) {
    candidates.push(raw.slice(idx + prefix.length));
    idx = upper.indexOf(prefix, idx + prefix.length);
  }
  // Trường hợp ngân hàng bỏ tiền tố, thử dùng luôn toàn bộ nội dung
  candidates.push(raw);

  const normalizedKnown = knownOrderIds
    .filter(Boolean)
    .map((id) => ({ original: id, normalized: normalizeOrderId(id) }));

  for (const candidate of candidates) {
    const normalizedCandidate = normalizeOrderId(candidate);
    if (!normalizedCandidate) continue;

    // Ưu tiên khớp chính xác
    const exact = normalizedKnown.find(
      (k) => k.normalized === normalizedCandidate,
    );
    if (exact) return exact.original;

    // Khớp tiền tố (nội dung có thể kèm hậu tố)
    const prefixMatch = normalizedKnown.find((k) =>
      normalizedCandidate.startsWith(k.normalized),
    );
    if (prefixMatch) return prefixMatch.original;

    // Khớp chứa (mã đơn nằm trong nội dung)
    const contains = normalizedKnown.find((k) =>
      normalizedCandidate.includes(k.normalized),
    );
    if (contains) return contains.original;
  }

  return null;
}

/**
 * Dựng URL ảnh QR VietQR (mỏ nhẹ, dùng được cho cả màn hình và phiếu in).
 */
export function buildVietQrUrl(options: {
  amount: number;
  content: string;
  bank?: string;
  accountNo?: string;
  accountName?: string;
}): string {
  const {
    amount,
    content,
    bank = SEPAY_BANK.bank,
    accountNo = SEPAY_BANK.accountNo,
    accountName = SEPAY_BANK.accountName,
  } = options;

  const params = new URLSearchParams({
    bank,
    acc: accountNo,
    amount: String(Math.max(0, Math.round(amount))),
    des: content,
    holder: accountName,
    template: "compact",
    showinfo: "true",
  });

  return `https://vietqr.app/img?${params.toString()}`;
}
