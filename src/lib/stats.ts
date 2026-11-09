import type { Order, Product } from "@/lib/types";

export interface DashboardStats {
  totalOrders: number;
  completedOrders: number;
  totalCakes: number;
  chungCount: number;
  tetCount: number;
  totalRevenue: number;
  totalDeposit: number;
  pendingDelivery: number;
  cookingCount: number;
  /** Số đơn cần giao trong dải ngày cao điểm (27-29 Tết) */
  peakDeliveryCount: number;
  /** Số đơn đang trong trạng thái nấu/gói */
  peakCookingCount: number;
}

/** Dải ngày cao điểm cần giao: 27-29 Tết (03/02 - 05/02/2027) */
export const PEAK_DELIVERY_DATES = ["2027-02-03", "2027-02-04", "2027-02-05"];

export function calculateDashboardStats(
  orders: Order[],
  products: Product[],
): DashboardStats {
  const productMap = new Map(products.map((p) => [p.id, p]));

  const stats: DashboardStats = {
    totalOrders: orders.length,
    completedOrders: 0,
    totalCakes: 0,
    chungCount: 0,
    tetCount: 0,
    totalRevenue: 0,
    totalDeposit: 0,
    pendingDelivery: 0,
    cookingCount: 0,
    peakDeliveryCount: 0,
    peakCookingCount: 0,
  };

  for (const order of orders) {
    if (order.status === "Đã hủy") continue;

    stats.totalRevenue += order.totalAmount;
    stats.totalDeposit += order.deposit;

    if (order.status === "Đã giao") stats.completedOrders += 1;
    if (order.status === "Đang nấu/gói") stats.cookingCount += 1;
    if (order.status !== "Đã giao") stats.pendingDelivery += 1;

    // Đơn chưa giao trong dải 27-29 Tết = cần giao cao điểm
    if (
      order.status !== "Đã giao" &&
      PEAK_DELIVERY_DATES.includes(order.deliveryDate)
    ) {
      stats.peakDeliveryCount += 1;
      if (order.status === "Đang nấu/gói") stats.peakCookingCount += 1;
    }

    for (const [productId, qty] of Object.entries(order.items)) {
      if (!qty) continue;
      stats.totalCakes += qty;
      const category = productMap.get(productId)?.category;
      if (category === "CHUNG") stats.chungCount += qty;
      if (category === "TET") stats.tetCount += qty;
    }
  }

  return stats;
}
