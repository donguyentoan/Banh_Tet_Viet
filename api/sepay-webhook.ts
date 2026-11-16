import { VercelRequest, VercelResponse } from "@vercel/node";
import { get, put } from "@vercel/blob";
import {
  extractOrderId,
  normalizeOrderId,
  SEPAY_PAYMENT_STATUS_PAID,
} from "../server/sepay.js";

/** Đường dẫn Blob phải KHỚP chính xác với file mà app đang dùng. */
const BLOB_PATH = "collections/orders.json";

/** App lưu collection với quyền private - webhook cũng phải dùng đúng mode. */
const BLOB_ACCESS = "private" as const;

/**
 * Trạng thái hợp lệ của đơn (phải khớp ORDER_STATUSES trong src/lib/types.ts).
 * Webhook KHÔNG được gán trạng thái ngoài danh sách này, nếu không Zod schema
 * sẽ từ chối và UI hiển thị "undefined".
 */
const STATUS_DEPOSITED = "Đã cọc";
const STATUS_PAID = "Đã thanh toán";

/** Trạng thái cho biết đơn đã thanh toán đủ (để UI/báo cáo nhận ra). */
const PAYMENT_STATUS_PAID = SEPAY_PAYMENT_STATUS_PAID;

interface SepayWebhookBody {
  /** Số tiền người gửi chuyển khoản */
  transferAmount?: number;
  /** Nội dung chuyển khoản (có mã đơn) */
  content?: string;
  /** Tài khoản người gửi */
  accountNumber?: string;
  /** Mã giao dịch phía ngân hàng */
  referenceCode?: string;
  /** Thời điểm giao dịch */
  transactionDate?: string;
  /** Số tiền (alias cho transferAmount) */
  amount?: number;
}

export default async function handler(
  req: VercelRequest,
  res: VercelResponse,
) {
  if (req.method !== "POST") {
    return res
      .status(405)
      .json({ success: false, message: "Method not allowed" });
  }

  try {
    const body = (req.body ?? {}) as SepayWebhookBody;

    const content = String(body.content ?? "").trim();
    if (!content) {
      return res
        .status(400)
        .json({ success: false, message: "Thiếu nội dung chuyển khoản." });
    }

    const transferAmount = Number(body.transferAmount ?? body.amount ?? 0);
    const paidAt = body.transactionDate
      ? new Date(body.transactionDate).toISOString()
      : new Date().toISOString();

    /* ---------------------------------------------------------------- */
    /* 1. Đọc danh sách đơn từ đúng đường dẫn Blob                     */
    /* ---------------------------------------------------------------- */
    let orders: Record<string, any>[] = [];
    let originalShape: "array" | "orders" | "data" = "array";
    let rootObject: Record<string, any> | null = null;

    try {
      const stored = await get(BLOB_PATH, {
        access: BLOB_ACCESS,
        useCache: false,
      });

      if (stored?.statusCode === 200 && stored.stream) {
        const parsed = await new Response(stored.stream).json();

        if (Array.isArray(parsed)) {
          orders = parsed;
          originalShape = "array";
        } else if (parsed && Array.isArray(parsed.orders)) {
          orders = parsed.orders;
          originalShape = "orders";
          rootObject = parsed;
        } else if (parsed && Array.isArray(parsed.data)) {
          orders = parsed.data;
          originalShape = "data";
          rootObject = parsed;
        }
      }
    } catch (err) {
      console.error("[sepay] Lỗi khi đọc Blob:", err);
      return res.status(500).json({
        success: false,
        message: "Không đọc được dữ liệu đơn hàng.",
      });
    }

    if (!Array.isArray(orders)) {
      orders = [];
    }

    /* ---------------------------------------------------------------- */
    /* 2. Tìm đơn khớp với nội dung chuyển khoản                       */
    /* ---------------------------------------------------------------- */
    const knownIds = orders
      .map((order) =>
        String(order?.id ?? order?.orderId ?? order?.code ?? "").trim(),
      )
      .filter(Boolean);

    const matchedId = extractOrderId(content, knownIds);

    if (!matchedId) {
      console.warn(
        `[sepay] Không tìm thấy mã đơn trong nội dung "${content}". ` +
          `Các mã đang có: ${knownIds.join(", ") || "(rỗng)"}`,
      );
      return res.status(200).json({
        success: true,
        message: `Không tìm thấy mã đơn hàng phù hợp trong nội dung "${content}".`,
      });
    }

    const normalizedMatched = normalizeOrderId(matchedId);

    /* ---------------------------------------------------------------- */
    /* 3. Cập nhật đơn                                                */
    /* ---------------------------------------------------------------- */
    let updatedOrder: Record<string, any> | null = null;

    orders = orders.map((order: Record<string, any>) => {
      const orderIdInFile = String(
        order?.id ?? order?.orderId ?? order?.code ?? "",
      ).trim();

      if (normalizeOrderId(orderIdInFile) !== normalizedMatched) {
        return order;
      }

      const totalAmount = Number(order.totalAmount ?? 0);
      const deposit = Number(order.deposit ?? 0);
      // Tổng tiền khách đã trả trước đó: lấy max giữa số tiền đã ghi nhận
      // và tiền cọc khai trên đơn (trường hợp cọc tiền mặt khi đặt hàng).
      const previousPaid = Math.max(
        Number(order.paidAmount ?? 0),
        deposit,
      );

      // Cộng dồn tiền đã thanh toán (webhook có thể gọi lại nhiều lần).
      const paidAmount = previousPaid + (transferAmount || 0);
      const outstanding = Math.max(0, totalAmount - paidAmount);

      const updated: Record<string, any> = {
        ...order,
        paidAmount,
        paidAt,
        paymentStatus: PAYMENT_STATUS_PAID,
        lastTransferContent: content,
        ...(body.referenceCode
          ? { paymentReference: body.referenceCode }
          : {}),
        ...(body.accountNumber
          ? { payerAccount: body.accountNumber }
          : {}),
      };

      // Chỉ dùng trạng thái nằm trong ORDER_STATUSES.
      //
      // Lưu ý nghiệp vụ:
      //  - Trả một phần -> "Đã cọc" (đã đặt cọc nhưng chưa trả đủ).
      //  - Trả đủ       -> "Đã thanh toán" (đã trả hết tiền bánh).
      //  - "Đã giao" KHÔNG được đặt ở đây vì đó là hành động giao hàng
      //    thực tế, khách trả tiền không đồng nghĩa với đã giao.
      updated.status = outstanding > 0 ? STATUS_DEPOSITED : STATUS_PAID;

      // Cập nhật tiền cọc cho khớp số tiền đã trả (giới hạn trong tổng).
      updated.deposit = Math.min(totalAmount, Math.max(deposit, paidAmount));

      updatedOrder = updated;
      return updated;
    });

    if (!updatedOrder) {
      console.warn(`[sepay] Không tìm thấy đơn khớp "${matchedId}" trong dữ liệu.`);
      return res.status(200).json({
        success: true,
        message: "Không tìm thấy đơn hàng tương ứng trong hệ thống.",
      });
    }

    /* ---------------------------------------------------------------- */
    /* 4. Ghi lại Blob, giữ nguyên cấu trúc file gốc                    */
    /* ---------------------------------------------------------------- */
    const dataToSave =
      originalShape === "array" || !rootObject
        ? orders
        : originalShape === "orders"
          ? { ...rootObject, orders }
          : { ...rootObject, data: orders };

    await put(BLOB_PATH, JSON.stringify(dataToSave, null, 2), {
      access: BLOB_ACCESS,
      allowOverwrite: true,
      addRandomSuffix: false,
      contentType: "application/json; charset=utf-8",
      cacheControlMaxAge: 0,
    });

    console.log(
      `[sepay] Đã cập nhật đơn ${matchedId}: status=${(updatedOrder as Record<string, any>).status}, ` +
        `paidAmount=${(updatedOrder as Record<string, any>).paidAmount}`,
    );

    return res.status(200).json({
      success: true,
      message: "Webhook processed and order updated successfully",
      orderId: matchedId,
      status: (updatedOrder as Record<string, any>).status,
      paidAmount: (updatedOrder as Record<string, any>).paidAmount,
    });
  } catch (error: unknown) {
    console.error("[sepay] Webhook error:", error);
    const message =
      error instanceof Error ? error.message : "Lỗi không xác định";
    return res.status(500).json({ success: false, error: message });
  }
}
