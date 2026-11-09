import { z } from "zod";

export const ORDER_STATUSES = [
  "Mới đặt",
  "Đã cọc",
  "Đang nấu/gói",
  "Đã giao",
  "Đã hủy",
] as const;

export type OrderStatus = (typeof ORDER_STATUSES)[number];

/** Gợi ý nhanh các ngày giao trong dịp Tết (không giới hạn - có thể chọn bất kỳ ngày nào) */
export const DELIVERY_DATE_SUGGESTIONS = [
  { value: "2027-02-02", label: "26 Tết (02/02)", short: "26 Tết" },
  { value: "2027-02-03", label: "27 Tết (03/02)", short: "27 Tết" },
  { value: "2027-02-04", label: "28 Tết (04/02)", short: "28 Tết" },
  { value: "2027-02-05", label: "29 Tết (05/02)", short: "29 Tết" },
  { value: "2027-02-06", label: "Mùng 1 Tết (06/02)", short: "Mùng 1" },
] as const;

/** Gợi ý nhanh các khung giờ nhận bánh (không giới hạn - có thể nhập tự do) */
export const DELIVERY_TIME_SUGGESTIONS = [
  "Sáng (07:00 - 11:00)",
  "Chiều (13:00 - 17:00)",
  "Tối (18:00 - 21:00)",
] as const;

export const DEFAULT_DELIVERY_DATE = "2027-02-03";
export const DEFAULT_DELIVERY_TIME: string = DELIVERY_TIME_SUGGESTIONS[0];

/** Ngày mùng 1 Tết Nguyên Đán Đinh Mùi (06/02/2027) - dùng cho đồng hồ đếm ngược */
export const TET_DATE_ISO = "2027-02-06";

/** Mã ngắn của 6 loại bánh - dùng cho ô ghi nhanh theo cú pháp tin nhắn */
export const PRODUCT_CODES = [
  "CM",
  "CC",
  "CĐB",
  "TT",
  "TC",
  "TMC",
] as const;

export type ProductCode = (typeof PRODUCT_CODES)[number];

export type ProductCategory = "CHUNG" | "TET";

export const productSchema = z.object({
  id: z.string().min(1),
  name: z.string().trim().min(2, "Vui lòng nhập tên loại bánh"),
  price: z.number().int().min(0, "Giá phải lớn hơn 0"),
  /** Giá bán sỉ cho mối chợ (nếu bỏ trống = lấy 80% giá bán lẻ) */
  wholesalePrice: z.number().int().min(0).optional(),
  category: z.enum(["CHUNG", "TET"]),
  /** Mã ngắn để gõ nhanh trong tin nhắn (CM, CC, CĐB, TT, TC, TMC) */
  code: z.string().trim().min(1).optional(),
  icon: z.string().default("🍃"),
  weight: z.string().default("1.0 kg"),
});

export type Product = z.infer<typeof productSchema>;

export const productFormSchema = z.object({
  name: z.string().trim().min(2, "Vui lòng nhập tên loại bánh"),
  price: z.coerce.number().int().min(0, "Giá phải lớn hơn 0"),
  wholesalePrice: z.coerce.number().int().min(0).optional(),
  category: z.enum(["CHUNG", "TET"]),
  code: z.string().trim().max(6).optional(),
  icon: z.string().trim().min(1, "Vui lòng nhập biểu tượng"),
  weight: z.string().trim().min(1, "Vui lòng nhập khối lượng"),
});

export type ProductFormValues = z.input<typeof productFormSchema>;

/** Ngày giao: tự do, không giới hạn trong danh sách Tết */
export const deliveryDateSchema = z
  .string()
  .trim()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Vui lòng nhập ngày giao hàng (YYYY-MM-DD)");

/** Khung giờ: tự do, không giới hạn trong danh sách gợi ý */
export const deliveryTimeSchema = z
  .string()
  .trim()
  .min(1, "Vui lòng nhập khung giờ nhận bánh");

export const orderSchema = z.object({
  id: z.string().min(1),
  customerName: z.string().trim().min(2, "Vui lòng nhập họ tên khách hàng"),
  phone: z
    .string()
    .trim()
    .regex(/^(0|\+84)\d{9,10}$/, "Số điện thoại không hợp lệ (VD: 0901234567)"),
  address: z.string().trim().min(5, "Vui lòng nhập địa chỉ giao hàng"),
  deliveryDate: deliveryDateSchema,
  deliveryTime: deliveryTimeSchema,
  items: z.record(z.string(), z.number().int().min(0)),
  totalAmount: z.number().int().min(0),
  deposit: z.number().int().min(0),
  status: z.enum(ORDER_STATUSES),
  notes: z.string().optional().default(""),
  createdAt: z.string(),
});

export type Order = z.infer<typeof orderSchema>;

export const orderFormSchema = z
  .object({
    customerName: z.string().trim().min(2, "Vui lòng nhập họ tên khách hàng"),
    phone: z
      .string()
      .trim()
      .regex(/^(0|\+84)\d{9,10}$/, "Số điện thoại không hợp lệ (VD: 0901234567)"),
    address: z.string().trim().min(5, "Vui lòng nhập địa chỉ giao hàng"),
    deliveryDate: deliveryDateSchema,
    deliveryTime: deliveryTimeSchema,
    status: z.enum(ORDER_STATUSES),
    deposit: z.coerce.number().int().min(0, "Tiền cọc không hợp lệ"),
    notes: z.string().optional().default(""),
    quantities: z.record(z.string(), z.number().int().min(0)),
  })
  .superRefine((data, ctx) => {
    const total = Object.values(data.quantities).reduce((sum, qty) => sum + qty, 0);
    if (total <= 0) {
      ctx.addIssue({
        code: "custom",
        path: ["quantities"],
        message: "Vui lòng chọn ít nhất 01 loại bánh để đặt!",
      });
    }
  });

export type OrderFormValues = z.input<typeof orderFormSchema>;

/* -------------------------------------------------------------------------- */
/*                        Mối chợ (bánh sỉ cho tiểu thương)                     */
/* -------------------------------------------------------------------------- */

export const marketSchema = z.object({
  id: z.string().min(1),
  /** Tên tiểu thương / chủ sạp */
  name: z.string().trim().min(2, "Vui lòng nhập tên tiểu thương"),
  /** Tên chợ / sạp chợ */
  stall: z.string().trim().min(2, "Vui lòng nhập tên sạp chợ"),
  phone: z
    .string()
    .trim()
    .regex(/^(0|\+84)\d{9,10}$/, "Số điện thoại không hợp lệ (VD: 0901234567)"),
  notes: z.string().optional().default(""),
});

export type Market = z.infer<typeof marketSchema>;

export const marketFormSchema = z.object({
  name: z.string().trim().min(2, "Vui lòng nhập tên tiểu thương"),
  stall: z.string().trim().min(2, "Vui lòng nhập tên sạp chợ"),
  phone: z
    .string()
    .trim()
    .regex(/^(0|\+84)\d{9,10}$/, "Số điện thoại không hợp lệ (VD: 0901234567)"),
  notes: z.string().optional().default(""),
});

export type MarketFormValues = z.input<typeof marketFormSchema>;

/* -------------------------------------------------------------------------- */
/*                        Lịch bỏ bánh sỉ theo ngày                              */
/* -------------------------------------------------------------------------- */

export const wholesaleSchema = z.object({
  id: z.string().min(1),
  marketId: z.string().min(1),
  /** Ngày bỏ bánh (ISO) */
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  /** Số lượng theo productId */
  items: z.record(z.string(), z.number().int().min(0)),
  /** Tổng tiền đã tính sẵn theo giá sỉ */
  totalAmount: z.number().int().min(0),
  notes: z.string().optional().default(""),
  createdAt: z.string(),
});

export type Wholesale = z.infer<typeof wholesaleSchema>;

/* -------------------------------------------------------------------------- */
/*                        Sản lượng & tồn kho gối đầu                            */
/* -------------------------------------------------------------------------- */

export const productionSchema = z.object({
  id: z.string().min(1),
  /** Ngày bếp nấu/gói xong */
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  /** Số lượng thực tế bếp đã làm xong, theo productId */
  items: z.record(z.string(), z.number().int().min(0)),
  notes: z.string().optional().default(""),
  updatedAt: z.string(),
});

export type Production = z.infer<typeof productionSchema>;

/** Tồn kho gối đầu của một ngày (dư từ ngày trước chuyển sang) */
export const inventorySchema = z.object({
  id: z.string().min(1),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  /** Tồn kho gối đầu theo productId */
  items: z.record(z.string(), z.number().int().min(0)),
  updatedAt: z.string(),
});

export type Inventory = z.infer<typeof inventorySchema>;

/* -------------------------------------------------------------------------- */
/*                              Tiện ích tính tiền                               */
/* -------------------------------------------------------------------------- */

export function calculateTotal(
  quantities: Record<string, number | null | undefined>,
  products: Product[],
): number {
  const productMap = new Map(products.map((p) => [p.id, p]));
  return Object.entries(quantities ?? {}).reduce((total, [productId, qty]) => {
    const product = productMap.get(productId);
    const quantity = Number(qty) || 0;
    if (!product || quantity <= 0) return total;
    return total + product.price * quantity;
  }, 0);
}

/** Giá sỉ: ưu tiên `wholesalePrice`, nếu không có thì lấy 80% giá bán lẻ */
export function getWholesalePrice(product: Product): number {
  if (
    typeof product.wholesalePrice === "number" &&
    product.wholesalePrice > 0
  ) {
    return product.wholesalePrice;
  }
  return Math.round((product.price * 80) / 100 / 1000) * 1000;
}
