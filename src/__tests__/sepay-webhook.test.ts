import { describe, expect, it } from "vitest";
import { ORDER_STATUSES, orderSchema } from "@/lib/types";
import { extractOrderId, SEPAY_PAYMENT_STATUS_PAID } from "@/lib/sepay";

/**
 * Mô phỏng đúng logic của api/sepay-webhook.ts để bảo đảm trạng thái ghi vào
 * đơn luôn hợp lệ theo ORDER_STATUSES (Zod schema sẽ từ chối nếu sai).
 */
function simulateWebhook(
  orders: Record<string, any>[],
  content: string,
  transferAmount: number,
) {
  const knownIds = orders.map((o) => String(o.id)).filter(Boolean);
  const matchedId = extractOrderId(content, knownIds);
  if (!matchedId) return { orders, matchedId: null };

  const updated = orders.map((order) => {
    if (order.id !== matchedId) return order;

    const totalAmount = Number(order.totalAmount ?? 0);
    const deposit = Number(order.deposit ?? 0);
    const previousPaid = Math.max(Number(order.paidAmount ?? 0), deposit);
    const paidAmount = previousPaid + transferAmount;
    const outstanding = Math.max(0, totalAmount - paidAmount);

    const next: Record<string, any> = {
      ...order,
      paidAmount,
      paymentStatus: SEPAY_PAYMENT_STATUS_PAID,
    };

    // Trả đủ -> "Đã thanh toán", trả một phần -> "Đã cọc"
    next.status = outstanding > 0 ? "Đã cọc" : "Đã thanh toán";

    next.deposit = Math.min(totalAmount, Math.max(deposit, paidAmount));
    return next;
  });

  return { orders: updated, matchedId };
}

const BASE_ORDERS = [
  {
    id: "TB2027-003",
    customerName: "Chị Lan",
    phone: "0587962548",
    address: "Thôn 15",
    deliveryDate: "2026-11-12",
    deliveryTime: "Chiều (13:00 - 17:00)",
    items: { bc_chay: 3 },
    totalAmount: 650000,
    deposit: 500000,
    status: "Đang nấu/gói",
    notes: "",
    createdAt: "2026-11-12",
  },
];

describe("webhook cập nhật trạng thái đơn", () => {
  it("tìm được đơn dù mã đơn có dấu gạch ngang", () => {
    const { matchedId } = simulateWebhook(
      BASE_ORDERS,
      "TETTB2027-003",
      150000,
    );
    expect(matchedId).toBe("TB2027-003");
  });

  it("trả một phần -> chuyển sang 'Đã cọc' và cộng dồn vào tiền cọc", () => {
    const { orders } = simulateWebhook(BASE_ORDERS, "TETTB2027-003", 100000);
    const order = orders[0];

    expect(order.status).toBe("Đã cọc");
    // Đã cọc 500.000 trước + chuyển thêm 100.000 = 600.000
    expect(order.deposit).toBe(600000);
    expect(order.paidAmount).toBe(600000);
    expect(order.paymentStatus).toBe(SEPAY_PAYMENT_STATUS_PAID);
  });

  it("trả đủ phần còn lại -> chuyển sang 'Đã thanh toán' (không đánh dấu đã giao)", () => {
    const { orders } = simulateWebhook(BASE_ORDERS, "TETTB2027-003", 150000);
    const order = orders[0];

    expect(order.status).toBe("Đã thanh toán");
    expect(order.status).not.toBe("Đã giao");
    expect(order.deposit).toBe(650000);
    expect(order.paidAmount).toBe(650000);
  });

  it("trạng thái ghi vào luôn nằm trong ORDER_STATUSES", () => {
    const { orders } = simulateWebhook(BASE_ORDERS, "TETTB2027-003", 150000);
    expect(ORDER_STATUSES).toContain(orders[0].status);
  });

  it("đơn sau khi webhook vẫn vượt qua Zod schema", () => {
    const { orders } = simulateWebhook(BASE_ORDERS, "TETTB2027-003", 100000);
    const parsed = orderSchema.safeParse(orders[0]);

    expect(parsed.success).toBe(true);
  });

  it("không khớp mã đơn nào -> trả về null, không sửa dữ liệu", () => {
    const { orders, matchedId } = simulateWebhook(
      BASE_ORDERS,
      "TETKHAC",
      150000,
    );
    expect(matchedId).toBeNull();
    expect(orders).toEqual(BASE_ORDERS);
  });

  it("cộng dồn khi webhook được gọi lại nhiều lần", () => {
    const first = simulateWebhook(BASE_ORDERS, "TETTB2027-003", 100000);
    const second = simulateWebhook(first.orders, "TETTB2027-003", 50000);

    // 500.000 (cọc trước) + 100.000 + 50.000 = 650.000
    expect(second.orders[0].paidAmount).toBe(650000);
    expect(second.orders[0].deposit).toBe(650000);
    expect(second.orders[0].status).toBe("Đã thanh toán");
  });

  it("nội dung không có mã đơn -> bỏ qua an toàn", () => {
    const { matchedId } = simulateWebhook(BASE_ORDERS, "Thanh toán bánh", 100);
    expect(matchedId).toBeNull();
  });
});
