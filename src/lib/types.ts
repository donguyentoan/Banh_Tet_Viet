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
  { value: "2026-02-13", label: "26 Tết (13/02)", short: "26 Tết" },
  { value: "2026-02-14", label: "27 Tết (14/02)", short: "27 Tết" },
  { value: "2026-02-15", label: "28 Tết (15/02)", short: "28 Tết" },
  { value: "2026-02-16", label: "29 Tết (16/02)", short: "29 Tết" },
  { value: "2026-02-17", label: "30 Tết (17/02)", short: "30 Tết" },
] as const;

/** Gợi ý nhanh các khung giờ nhận bánh (không giới hạn - có thể nhập tự do) */
export const DELIVERY_TIME_SUGGESTIONS = [
  "Sáng (07:00 - 11:00)",
  "Chiều (13:00 - 17:00)",
  "Tối (18:00 - 21:00)",
] as const;

export const DEFAULT_DELIVERY_DATE = "2026-02-14";
export const DEFAULT_DELIVERY_TIME = DELIVERY_TIME_SUGGESTIONS[0];

export type ProductCategory = "CHUNG" | "TET";

export const productSchema = z.object({
  id: z.string().min(1),
  name: z.string().trim().min(2, "Vui lòng nhập tên loại bánh"),
  price: z.number().int().min(0, "Giá phải lớn hơn 0"),
  category: z.enum(["CHUNG", "TET"]),
  icon: z.string().default("🍃"),
  weight: z.string().default("1.0 kg"),
});

export type Product = z.infer<typeof productSchema>;

export const productFormSchema = z.object({
  name: z.string().trim().min(2, "Vui lòng nhập tên loại bánh"),
  price: z.coerce.number().int().min(0, "Giá phải lớn hơn 0"),
  category: z.enum(["CHUNG", "TET"]),
  icon: z.string().trim().min(1, "Vui lòng nhập biểu tượng"),
  weight: z.string().trim().min(1, "Vui lòng nhập khối lượng"),
});

export type ProductFormValues = z.input<typeof productFormSchema>;

export const TET_DATE_ISO = "2026-02-17";

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
