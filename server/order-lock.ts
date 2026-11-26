/**
 * Quy tắc khoá đơn hàng - phiên bản chạy ở server.
 *
 * Đặt trong `server/` vì được dùng bởi:
 *  - API function `api/[...path].ts` (Vercel runtime)
 *
 * Logic phải GIỐNG HỆT `src/lib/types.ts` (phía client) để hành vi ở server
 * và ở giao diện luôn khớp nhau.
 *
 * File này cố tình không import zod hay bất kỳ thư viện phía client nào để
 * chạy được trong môi trường Node của Vercel.
 */

/** Trạng thái thanh toán mà webhook SePay đặt khi khách đã trả đủ. */
export const PAYMENT_STATUS_PAID = "Đã thanh toán";

/** Thông báo trả về cho client khi thao tác bị chặn. */
export const ORDER_LOCKED_MESSAGE = "Đơn đã thanh toán không thể xóa hoặc sửa.";

/**
 * Đơn đã "chốt" (không được xóa / sửa) khi:
 *   - trạng thái đơn là "Đã thanh toán", hoặc
 *   - webhook SePay đã xác nhận khách trả đủ (paymentStatus).
 *
 * Mục đích: tránh mất đơn đã thu tiền của khách.
 */
export function isOrderLocked(order: {
  status?: string;
  paymentStatus?: string;
}): boolean {
  return (
    order.status === PAYMENT_STATUS_PAID ||
    order.paymentStatus === PAYMENT_STATUS_PAID
  );
}
