import { getWholesalePrice } from "@/lib/types";
import type {
  Inventory,
  Order,
  Product,
  Production,
  Wholesale,
} from "@/lib/types";

export interface BalanceRow {
  productId: string;
  name: string;
  icon: string;
  /** Nhu cầu giao cho khách lẻ trong ngày */
  retailDemand: number;
  /** Nhu cầu lấy cho mối chợ trong ngày */
  wholesaleDemand: number;
  /** Tổng nhu cầu cần giao trong ngày */
  totalDemand: number;
  /** Tồn kho gối đầu mang sang từ ngày trước */
  openingStock: number;
  /** Số lượng bếp đã nấu/gói xong trong ngày */
  produced: number;
  /** Nguồn cung khả dụng = tồn gối đầu + sản lượng */
  availableSupply: number;
  /** Dư (+) hoặc thiếu (-) */
  surplus: number;
}

export interface DayBalance {
  date: string;
  rows: BalanceRow[];
  totalDemand: number;
  totalProduced: number;
  totalOpeningStock: number;
  totalSurplus: number;
  /** Có loại bánh nào thiếu không */
  hasShortage: boolean;
  /** Tồn kho gối đầu chuyển sang ngày hôm sau (chỉ tính phần dư) */
  carryOver: Record<string, number>;
}

/**
 * Tổng hợp số lượng bánh khách lẻ đặt trong ngày.
 * Bỏ qua đơn đã hủy. Đơn "Đã giao" vẫn tính (đã giao rồi vẫn là nhu cầu của ngày đó).
 */
export function sumRetailDemand(
  orders: Order[],
  date: string,
): Record<string, number> {
  const result: Record<string, number> = {};

  for (const order of orders) {
    if (order.status === "Đã hủy") continue;
    if (order.deliveryDate !== date) continue;

    for (const [productId, qty] of Object.entries(order.items)) {
      if (!qty || qty <= 0) continue;
      result[productId] = (result[productId] ?? 0) + qty;
    }
  }

  return result;
}

/**
 * Tổng hợp số lượng bánh các mối chợ lấy trong ngày.
 */
export function sumWholesaleDemand(
  wholesaleList: Wholesale[],
  date: string,
): Record<string, number> {
  const result: Record<string, number> = {};

  for (const entry of wholesaleList) {
    if (entry.date !== date) continue;

    for (const [productId, qty] of Object.entries(entry.items)) {
      if (!qty || qty <= 0) continue;
      result[productId] = (result[productId] ?? 0) + qty;
    }
  }

  return result;
}

/** Tồn kho gối đầu của ngày (dư từ ngày hôm trước chuyển sang) */
export function getOpeningStock(
  inventories: Inventory[],
  date: string,
): Record<string, number> {
  const found = inventories.find((inv) => inv.date === date);
  return found ? { ...found.items } : {};
}

/**
 * Tính bảng cân đối kho bánh cho một ngày.
 *
 * - Nhu cầu = khách lẻ + mối chợ
 * - Nguồn cung = tồn kho gối đầu + số bếp đã làm
 * - Dư = nguồn cung - nhu cầu; phần dư chuyển thành tồn kho gối đầu ngày sau
 */
export function calculateDayBalance(
  date: string,
  orders: Order[],
  wholesaleList: Wholesale[],
  productions: Production[],
  inventories: Inventory[],
  products: Product[],
): DayBalance {
  const retailDemand = sumRetailDemand(orders, date);
  const wholesaleDemand = sumWholesaleDemand(wholesaleList, date);
  const openingStock = getOpeningStock(inventories, date);

  const production = productions.find((p) => p.date === date);
  const produced = production ? { ...production.items } : {};

  const rows: BalanceRow[] = products.map((product) => {
    const r = retailDemand[product.id] ?? 0;
    const w = wholesaleDemand[product.id] ?? 0;
    const totalDemand = r + w;
    const stock = openingStock[product.id] ?? 0;
    const made = produced[product.id] ?? 0;
    const availableSupply = stock + made;

    return {
      productId: product.id,
      name: product.name,
      icon: product.icon,
      retailDemand: r,
      wholesaleDemand: w,
      totalDemand,
      openingStock: stock,
      produced: made,
      availableSupply,
      surplus: availableSupply - totalDemand,
    };
  });

  const carryOver: Record<string, number> = {};
  for (const row of rows) {
    if (row.surplus > 0) carryOver[row.productId] = row.surplus;
  }

  return {
    date,
    rows,
    totalDemand: rows.reduce((sum, r) => sum + r.totalDemand, 0),
    totalProduced: rows.reduce((sum, r) => sum + r.produced, 0),
    totalOpeningStock: rows.reduce((sum, r) => sum + r.openingStock, 0),
    totalSurplus: rows.reduce((sum, r) => sum + r.surplus, 0),
    hasShortage: rows.some((r) => r.surplus < 0),
    carryOver,
  };
}

/**
 * Chuỗi ngày liên tiếp từ `startDate` tới `endDate` (bao gồm 2 đầu).
 */
export function eachDate(startDate: string, endDate: string): string[] {
  const result: string[] = [];
  const start = new Date(`${startDate}T00:00:00Z`);
  const end = new Date(`${endDate}T00:00:00Z`);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    return [startDate];
  }

  const cursor = new Date(start);
  while (cursor <= end) {
    result.push(cursor.toISOString().slice(0, 10));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }

  return result;
}

/**
 * Tính tồn kho gối đầu cho tất cả các ngày trong khoảng, tự động cộng dồn
 * phần dư của ngày trước sang ngày sau.
 *
 * - `manualInventories`: các bản ghi tồn kho gối đầu do người dùng nhập tay
 *   (được coi là "chốt" cho ngày đó, ghi đè giá trị cộng dồn).
 * - `carryOver` được suy ra từ ngày trước: tồn gối đầu + sản lượng - nhu cầu.
 */
export function buildInventoryChain(
  dates: string[],
  orders: Order[],
  wholesaleList: Wholesale[],
  productions: Production[],
  manualInventories: Inventory[],
  products: Product[],
): Map<string, Record<string, number>> {
  const chain = new Map<string, Record<string, number>>();
  let carry: Record<string, number> = {};

  for (const date of dates) {
    const manual = manualInventories.find((inv) => inv.date === date);
    // Tồn gối đầu = max(carry từ ngày trước, tồn nhập tay nếu có)
    const opening: Record<string, number> = {};

    for (const product of products) {
      const fromCarry = carry[product.id] ?? 0;
      const fromManual = manual?.items?.[product.id];
      const value =
        typeof fromManual === "number" && fromManual > 0
          ? Math.max(fromCarry, fromManual)
          : fromCarry;
      if (value > 0) opening[product.id] = value;
    }

    chain.set(date, opening);

    const balance = calculateDayBalance(
      date,
      orders,
      wholesaleList,
      productions,
      [{ id: "tmp", date, items: opening, updatedAt: "" }],
      products,
    );

    carry = balance.carryOver;
  }

  return chain;
}

/** Tính tổng tiền sỉ cho 1 mối chợ theo danh mục sản phẩm */
export function calculateWholesaleTotal(
  items: Record<string, number>,
  products: Product[],
): number {
  const productMap = new Map(products.map((p) => [p.id, p]));
  return Object.entries(items ?? {}).reduce((total, [productId, qty]) => {
    const product = productMap.get(productId);
    const quantity = Number(qty) || 0;
    if (!product || quantity <= 0) return total;
    return total + getWholesalePrice(product) * quantity;
  }, 0);
}
