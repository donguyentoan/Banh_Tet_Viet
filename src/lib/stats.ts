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
}

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
  };

  for (const order of orders) {
    if (order.status === "Đã hủy") continue;

    stats.totalRevenue += order.totalAmount;
    stats.totalDeposit += order.deposit;

    if (order.status === "Đã giao") stats.completedOrders += 1;
    if (order.status === "Đang nấu/gói") stats.cookingCount += 1;
    if (order.status !== "Đã giao") stats.pendingDelivery += 1;

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
