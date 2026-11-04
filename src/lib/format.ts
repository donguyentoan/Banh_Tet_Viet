import { DELIVERY_DATE_SUGGESTIONS, type Order } from "@/lib/types";

const LUNAR_MAP: Record<string, string> = Object.fromEntries(
  DELIVERY_DATE_SUGGESTIONS.map((d) => [d.value, d.short]),
);

export function formatMoney(amount: number): string {
  return new Intl.NumberFormat("vi-VN", {
    style: "currency",
    currency: "VND",
  }).format(amount);
}

export function formatDateDisplay(dateStr?: string): string {
  if (!dateStr) return "";
  const parts = dateStr.split("-");
  if (parts.length !== 3) return dateStr;
  const lunarText = LUNAR_MAP[dateStr] ? ` (${LUNAR_MAP[dateStr]})` : "";
  return `${parts[2]}/${parts[1]}/${parts[0]}${lunarText}`;
}

export function getRemaining(order: Pick<Order, "totalAmount" | "deposit">): number {
  return Math.max(0, order.totalAmount - order.deposit);
}
