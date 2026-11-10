import type { OrderStatus, ProductCategory } from "@/lib/types";

export const STATUS_LABELS: Record<OrderStatus, string> = {
  "Mới đặt": "🟡 Mới đặt",
  "Đã cọc": "🔵 Đã cọc",
  "Đang nấu/gói": "🟠 Đang nấu/gói",
  "Đã giao": "🟢 Đã giao",
  "Đã hủy": "🔴 Đã hủy",
};

export const STATUS_BADGE_CLASSES: Record<OrderStatus, string> = {
  "Mới đặt": "bg-yellow-100 text-yellow-800 border-yellow-300",
  "Đã cọc": "bg-blue-100 text-blue-800 border-blue-300",
  "Đang nấu/gói": "bg-orange-100 text-orange-800 border-orange-300",
  "Đã giao": "bg-emerald-100 text-emerald-800 border-emerald-300",
  "Đã hủy": "bg-red-100 text-red-800 border-red-300",
};

export const PRODUCT_CATEGORIES: Record<ProductCategory, string> = {
  CHUNG: "Bánh Chưng",
  TET: "Bánh Tét",
};

/** Danh mục 6 loại bánh chuẩn, dùng cho ô ghi nhanh theo cú pháp tin nhắn */
export const PRODUCT_CODE_LABELS: Record<string, string> = {
  CM: "Bánh Chưng Thịt",
  CC: "Bánh Chưng Chay",
  "CĐB": "Bánh Chưng Đặc Biệt",
  TT: "Bánh Tét Thịt",
  TC: "Bánh Tét Chuối",
  TMC: "Bánh Tét Nếp Cẩm",
};

/** Danh mục 6 loại bánh chuẩn - dùng làm fallback khi API chưa có */
export const DEFAULT_PRODUCT_CATALOG = [
  {
    id: "bc_thit",
    code: "CM",
    name: "Bánh Chưng Thịt",
    price: 150000,
    category: "CHUNG" as ProductCategory,
    icon: "🍖",
    weight: "1.2 kg",
  },
  {
    id: "bc_chay",
    code: "CC",
    name: "Bánh Chưng Chay",
    price: 130000,
    category: "CHUNG" as ProductCategory,
    icon: "🥬",
    weight: "1.0 kg",
  },
  {
    id: "bc_dacbiet",
    code: "CĐB",
    name: "Bánh Chưng Đặc Biệt",
    price: 180000,
    category: "CHUNG" as ProductCategory,
    icon: "✨",
    weight: "1.4 kg",
  },
  {
    id: "bt_thit",
    code: "TT",
    name: "Bánh Tét Thịt",
    price: 160000,
    category: "TET" as ProductCategory,
    icon: "🥓",
    weight: "1.2 kg",
  },
  {
    id: "bt_chuoi",
    code: "TC",
    name: "Bánh Tét Chuối",
    price: 110000,
    category: "TET" as ProductCategory,
    icon: "🍌",
    weight: "1.0 kg",
  },
  {
    id: "bt_cam",
    code: "TMC",
    name: "Bánh Tét Nếp Cẩm",
    price: 175000,
    category: "TET" as ProductCategory,
    icon: "🍚",
    weight: "1.2 kg",
  },
];
