import type { OrderStatus, ProductCategory } from "@/lib/types";

/** Trạng thái "đã trả đủ tiền bánh" (khác với "Đã giao" là hành động giao hàng) */
export const STATUS_PAID = "Đã thanh toán";

export const STATUS_LABELS: Record<OrderStatus, string> = {
  "Mới đặt": "🟡 Mới đặt",
  "Đã cọc": "🔵 Đã cọc",
  "Đang nấu/gói": "🟠 Đang nấu/gói",
  "Đã thanh toán": "💰 Đã thanh toán",
  "Đã giao": "🟢 Đã giao",
  "Đã hủy": "🔴 Đã hủy",
};

export const STATUS_BADGE_CLASSES: Record<OrderStatus, string> = {
  "Mới đặt": "bg-yellow-100 text-yellow-800 border-yellow-300",
  "Đã cọc": "bg-blue-100 text-blue-800 border-blue-300",
  "Đang nấu/gói": "bg-orange-100 text-orange-800 border-orange-300",
  "Đã thanh toán": "bg-teal-100 text-teal-800 border-teal-300",
  "Đã giao": "bg-emerald-100 text-emerald-800 border-emerald-300",
  "Đã hủy": "bg-red-100 text-red-800 border-red-300",
};

export const PRODUCT_CATEGORIES: Record<ProductCategory, string> = {
  CHUNG: "Bánh Chưng",
  TET: "Bánh Tét",
};
