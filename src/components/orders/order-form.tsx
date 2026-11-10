import { useEffect, useId, useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Minus, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { AddProductDialog } from "@/components/orders/add-product-dialog";
import { formatMoney } from "@/lib/format";
import { STATUS_LABELS } from "@/lib/constants";
import { useProducts } from "@/hooks/use-orders";
import {
  calculateTotal,
  DEFAULT_DELIVERY_DATE,
  DEFAULT_DELIVERY_TIME,
  DELIVERY_DATE_SUGGESTIONS,
  DELIVERY_TIME_SUGGESTIONS,
  ORDER_STATUSES,
  orderFormSchema,
  type Order,
  type OrderFormValues,
  type OrderStatus,
  type Product,
} from "@/lib/types";

const STATUS_ITEMS = Object.fromEntries(
  ORDER_STATUSES.map((status) => [status, STATUS_LABELS[status]]),
);

/** Mảng rỗng ổn định - tránh tạo reference mới mỗi render gây vòng lặp effect */
const EMPTY_PRODUCTS: Product[] = [];

export interface OrderFormProps {
  /** Đơn hàng đang sửa (null = tạo mới) */
  order?: Order | null;
  /** Giá trị điền sẵn (VD: từ Ô Ghi Nhanh nhanh) - chỉ dùng khi tạo mới */
  prefill?: OrderFormValues | null;
  /** Bấm "Lưu đơn hàng" */
  onSubmit: (values: OrderFormValues) => void;
  /** Đang gửi API */
  isPending?: boolean;
  /** Nhãn nút submit */
  submitLabel?: string;
  /** Nhãn nút huỷ */
  cancelLabel?: string;
  /** Xử lý khi bấm nút huỷ (không có thì ẩn nút) */
  onCancel?: () => void;
  /** Class cho thẻ bọc ngoài form */
  className?: string;
  /** Class cho khu vực nút bấm ở cuối form */
  footerClassName?: string;
  /** Đổi giá trị này để reset lại toàn bộ form (VD: mở/đóng dialog) */
  resetKey?: string | number;
}

export function OrderForm({
  order = null,
  prefill = null,
  onSubmit,
  isPending = false,
  submitLabel = "Lưu Đơn Hàng",
  cancelLabel = "Hủy Bỏ",
  onCancel,
  className,
  footerClassName,
  resetKey,
}: OrderFormProps) {
  const { data } = useProducts();
  const products = data ?? EMPTY_PRODUCTS;
  const [isAddProductOpen, setIsAddProductOpen] = useState(false);
  const timeListId = useId();

  const form = useForm<OrderFormValues>({
    resolver: zodResolver(orderFormSchema),
    defaultValues: {
      customerName: "",
      phone: "",
      address: "",
      deliveryDate: DEFAULT_DELIVERY_DATE,
      deliveryTime: DEFAULT_DELIVERY_TIME,
      status: "Mới đặt",
      deposit: 0,
      notes: "",
      quantities: {},
    },
    mode: "onChange",
  });

  const { register, handleSubmit, reset, setValue, watch, formState } = form;

  const productIds = useMemo(
    () => products.map((p) => p.id),
    [products],
  );
  const productIdsKey = productIds.join(",");

  useEffect(() => {
    if (order) {
      reset({
        customerName: order.customerName,
        phone: order.phone,
        address: order.address,
        deliveryDate: order.deliveryDate,
        deliveryTime: order.deliveryTime ?? DEFAULT_DELIVERY_TIME,
        status: order.status,
        deposit: order.deposit,
        notes: order.notes ?? "",
        quantities: { ...order.items },
      });
    } else if (prefill) {
      // Điền sẵn từ Ô Ghi Nhanh nhanh
      reset({
        customerName: prefill.customerName,
        phone: prefill.phone ?? "",
        address: prefill.address ?? "",
        deliveryDate: prefill.deliveryDate || DEFAULT_DELIVERY_DATE,
        deliveryTime: prefill.deliveryTime || DEFAULT_DELIVERY_TIME,
        status: prefill.status ?? "Mới đặt",
        deposit: prefill.deposit ?? 0,
        notes: prefill.notes ?? "",
        quantities: {
          ...Object.fromEntries(productIds.map((id) => [id, 0])),
          ...prefill.quantities,
        },
      });
    } else {
      reset({
        customerName: "",
        phone: "",
        address: "",
        deliveryDate: DEFAULT_DELIVERY_DATE,
        deliveryTime: DEFAULT_DELIVERY_TIME,
        status: "Mới đặt",
        deposit: 0,
        notes: "",
        quantities: Object.fromEntries(productIds.map((id) => [id, 0])),
      });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [order, prefill, reset, productIdsKey, resetKey]);

  // Đồng bộ số lượng khi danh mục sản phẩm thay đổi (thêm/xoá loại bánh).
  // Chỉ setValue khi thực sự khác để tránh vòng lặp render.
  useEffect(() => {
    const current = watch("quantities") ?? {};
    const currentKeys = Object.keys(current).join(",");
    if (currentKeys === productIdsKey) return;

    const next = Object.fromEntries(
      productIds.map((id) => [id, Number(current[id] ?? 0)]),
    );
    setValue("quantities", next, { shouldDirty: true, shouldValidate: true });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [productIdsKey, setValue]);

  const quantities = watch("quantities");
  const deposit = watch("deposit") ?? 0;

  // `watch` trả về cùng object reference (RHF mutate tại chỗ) nên useMemo theo
  // reference sẽ không recompute. Dùng chuỗi key để theo dõi thay đổi giá trị.
  const quantitiesKey = Object.entries(quantities ?? {})
    .map(([id, qty]) => `${id}:${Number(qty) || 0}`)
    .join(",");

  const total = useMemo(
    () => calculateTotal(quantities ?? {}, products),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [quantitiesKey, products],
  );
  const remaining = Math.max(0, total - (Number(deposit) || 0));

  function adjustQty(productId: string, delta: number) {
    const current = Number(quantities?.[productId] ?? 0);
    const next = Math.max(0, current + delta);
    setValue(`quantities.${productId}`, next, {
      shouldDirty: true,
      shouldValidate: true,
    });
  }

  return (
    <>
      <form
        onSubmit={handleSubmit(onSubmit)}
        className={className ?? "space-y-6"}
        noValidate
      >
        <section className="space-y-4 rounded-2xl border border-amber-200 bg-gradient-to-b from-amber-50/60 to-white p-4 sm:p-5">
          <h4 className="flex items-center gap-2.5 text-sm font-bold uppercase tracking-wider text-red-800">
            <span className="flex size-6 items-center justify-center rounded-full bg-red-700 text-xs font-black text-white">
              1
            </span>
            Thông Tin Khách Hàng
          </h4>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div>
              <Label htmlFor="customerName" className="mb-1 text-xs font-semibold">
                Họ &amp; Tên Khách Hàng <span className="text-red-500">*</span>
              </Label>
              <Input
                id="customerName"
                placeholder="Nhập tên người đặt..."
                {...register("customerName")}
              />
              {formState.errors.customerName && (
                <p className="mt-1 text-xs text-red-600">
                  {String(formState.errors.customerName.message)}
                </p>
              )}
            </div>
            <div>
              <Label htmlFor="phone" className="mb-1 text-xs font-semibold">
                Số Điện Thoại Liên Hệ <span className="text-red-500">*</span>
              </Label>
              <Input
                id="phone"
                type="tel"
                placeholder="0901234567"
                {...register("phone")}
              />
              {formState.errors.phone && (
                <p className="mt-1 text-xs text-red-600">
                  {String(formState.errors.phone.message)}
                </p>
              )}
            </div>
            <div className="md:col-span-2">
              <Label htmlFor="address" className="mb-1 text-xs font-semibold">
                Địa Chỉ Giao Hàng <span className="text-red-500">*</span>
              </Label>
              <Input
                id="address"
                placeholder="Số nhà, đường, phường/xã..."
                {...register("address")}
              />
              {formState.errors.address && (
                <p className="mt-1 text-xs text-red-600">
                  {String(formState.errors.address.message)}
                </p>
              )}
            </div>
          </div>
        </section>

        <section className="space-y-3 rounded-2xl border border-emerald-200 bg-white p-4 sm:p-5">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h4 className="flex items-center gap-2.5 text-sm font-bold uppercase tracking-wider text-emerald-800">
              <span className="flex size-6 items-center justify-center rounded-full bg-emerald-700 text-xs font-black text-white">
                2
              </span>
              Chọn Loại Bánh &amp; Số Lượng
              <span className="shrink-0 whitespace-nowrap rounded-full bg-emerald-100 px-2 py-1 text-[11px] font-bold text-emerald-800">
                {products.length} loại
              </span>
            </h4>
            <div className="flex items-center gap-3">
              <span className="hidden text-xs text-gray-500 sm:inline">
                Giá đã bao gồm lá bọc &amp; luộc chuẩn
              </span>
            </div>
          </div>

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5">
            {products.map((product) => (
              <div
                key={product.id}
                className={`flex min-h-[150px] flex-col gap-3 rounded-2xl border bg-white p-3 shadow-sm transition hover:-translate-y-0.5 hover:border-emerald-400 hover:shadow-md sm:min-h-[220px] sm:p-4 ${
                  Number(quantities?.[product.id] ?? 0) > 0
                    ? "border-emerald-400 ring-1 ring-emerald-100"
                    : "border-gray-200"
                }`}
              >
                <div className="flex min-w-0 flex-1 items-start gap-3">
                  <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-emerald-50 text-2xl">
                    {product.icon}
                  </span>
                  <div className="min-w-0 pt-0.5">
                    <p className="text-sm font-bold leading-snug text-gray-800">
                      {product.name}
                    </p>
                    <p className="mt-1 text-xs font-semibold leading-relaxed text-emerald-700">
                      {formatMoney(product.price)} / bánh{" "}
                      <span className="font-normal text-gray-400">
                        ({product.weight})
                      </span>
                    </p>
                  </div>
                </div>
                <div className="flex shrink-0 items-center justify-end gap-2 border-t border-gray-100 pt-3">
                  <Button
                    type="button"
                    variant="secondary"
                    size="icon"
                    className="size-9 rounded-lg"
                    onClick={() => adjustQty(product.id, -1)}
                  >
                    <Minus className="size-3.5" />
                  </Button>
                  <Input
                    id={`qty-${product.id}`}
                    type="number"
                    min={0}
                    aria-label={`Số lượng ${product.name}`}
                    className="h-9 w-14 rounded-lg py-1 text-center text-sm font-bold"
                    {...register(`quantities.${product.id}`, {
                      setValueAs: (value) => {
                        const num = Number(value);
                        if (!Number.isFinite(num)) return 0;
                        return Math.max(0, Math.trunc(num));
                      },
                    })}
                  />
                  <Button
                    type="button"
                    variant="secondary"
                    size="icon"
                    className="size-9 rounded-lg bg-emerald-100 text-emerald-800 hover:bg-emerald-200"
                    onClick={() => adjustQty(product.id, 1)}
                  >
                    <Plus className="size-3.5" />
                  </Button>
                </div>
              </div>
            ))}

            {/* Ô trống để thêm loại bánh mới */}
            <button
              type="button"
              onClick={() => setIsAddProductOpen(true)}
              className="flex min-h-[150px] flex-col items-center justify-center gap-2 rounded-2xl border-2 border-dashed border-amber-300 bg-amber-50/50 p-3 text-amber-700 transition hover:border-emerald-400 hover:bg-emerald-50 hover:text-emerald-700 sm:min-h-[220px]"
            >
              <Plus className="size-6" />
              <span className="text-xs font-bold">Thêm loại bánh</span>
            </button>
          </div>
          {formState.errors.quantities && (
            <p className="text-xs font-medium text-red-600">
              {String(formState.errors.quantities.message)}
            </p>
          )}
        </section>

        <section className="rounded-2xl border border-gray-200 bg-white p-4 sm:p-5">
          <h4 className="mb-4 flex items-center gap-2.5 text-sm font-bold uppercase tracking-wider text-gray-700">
            <span className="flex size-6 items-center justify-center rounded-full bg-gray-700 text-xs font-black text-white">
              3
            </span>
            Lịch Giao &amp; Trạng Thái
          </h4>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            <div>
              <Label htmlFor="deliveryDate" className="mb-1 text-xs font-semibold">
                Ngày Giao Hàng <span className="text-red-500">*</span>
              </Label>
              <Input
                id="deliveryDate"
                type="date"
                className="font-medium text-red-700"
                {...register("deliveryDate")}
              />
              {formState.errors.deliveryDate && (
                <p className="mt-1 text-xs text-red-600">
                  {String(formState.errors.deliveryDate.message)}
                </p>
              )}
              <div className="mt-1.5 flex flex-wrap gap-1">
                {DELIVERY_DATE_SUGGESTIONS.map((date) => (
                  <button
                    key={date.value}
                    type="button"
                    onClick={() =>
                      setValue("deliveryDate", date.value, {
                        shouldDirty: true,
                        shouldValidate: true,
                      })
                    }
                    className="min-h-8 rounded-md border border-amber-200 bg-amber-50 px-2 py-1 text-[11px] font-semibold text-amber-800 transition hover:border-red-300 hover:bg-amber-100"
                  >
                    {date.short}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <Label htmlFor="deliveryTime" className="mb-1 text-xs font-semibold">
                Khung Giờ Nhận Bánh <span className="text-red-500">*</span>
              </Label>
              <Input
                id="deliveryTime"
                list={timeListId}
                placeholder="VD: Sáng (07:00 - 11:00)"
                {...register("deliveryTime")}
              />
              <datalist id={timeListId}>
                {DELIVERY_TIME_SUGGESTIONS.map((time) => (
                  <option key={time} value={time} />
                ))}
              </datalist>
              {formState.errors.deliveryTime && (
                <p className="mt-1 text-xs text-red-600">
                  {String(formState.errors.deliveryTime.message)}
                </p>
              )}
              <div className="mt-1.5 flex flex-wrap gap-1">
                {DELIVERY_TIME_SUGGESTIONS.map((time) => (
                  <button
                    key={time}
                    type="button"
                    onClick={() =>
                      setValue("deliveryTime", time, {
                        shouldDirty: true,
                        shouldValidate: true,
                      })
                    }
                    className="min-h-8 rounded-md border border-amber-200 bg-amber-50 px-2 py-1 text-[11px] font-semibold text-amber-800 transition hover:border-red-300 hover:bg-amber-100"
                  >
                    {time.split(" (")[0]}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <Label htmlFor="status" className="mb-1 text-xs font-semibold">
                Trạng Thái Đơn Hàng
              </Label>
              <Select
                items={STATUS_ITEMS}
                value={watch("status")}
                onValueChange={(value) =>
                  setValue("status", (value ?? "Mới đặt") as OrderStatus, {
                    shouldValidate: true,
                  })
                }
              >
                <SelectTrigger id="status" className="font-semibold">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {ORDER_STATUSES.map((status) => (
                    <SelectItem key={status} value={status}>
                      {STATUS_LABELS[status]}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        </section>

        <section className="rounded-2xl border border-red-200 bg-gradient-to-r from-red-50 to-red-50/50 p-4 sm:p-5">
          <h4 className="mb-4 flex items-center gap-2.5 text-sm font-bold uppercase tracking-wider text-red-800">
            <span className="flex size-6 items-center justify-center rounded-full bg-red-700 text-xs font-black text-white">
              4
            </span>
            Thanh Toán &amp; Ghi Chú
          </h4>

          <div className="flex flex-col gap-3 rounded-xl border border-red-200 bg-white p-3 sm:p-4 md:flex-row md:items-center md:justify-between">
            <div className="flex min-w-0 items-center justify-between gap-2 md:block">
              <span className="text-xs text-gray-600">
                Tổng giá trị đơn bánh:
              </span>
              <span className="whitespace-nowrap text-2xl font-black tracking-tight text-red-700 sm:text-3xl md:block">
                {formatMoney(total)}
              </span>
            </div>

            <div className="grid w-full min-w-0 grid-cols-2 items-end gap-2 sm:gap-4 md:w-auto">
              <div>
                <Label
                  htmlFor="deposit"
                  className="mb-1 block text-xs font-semibold"
                >
                  Số Tiền Đã Đặt Cọc (₫)
                </Label>
                <Input
                  id="deposit"
                  type="number"
                  min={0}
                  step={10000}
                  className="w-full font-bold text-amber-700 sm:w-40"
                  {...register("deposit", { valueAsNumber: true })}
                />
              </div>
              <div className="min-w-0 rounded-lg bg-gray-50 px-2 py-2 sm:px-3">
                <span className="block text-[11px] leading-tight text-gray-600 sm:text-xs">Còn lại cần thu:</span>
                <span className="whitespace-nowrap text-base font-bold text-gray-900 sm:text-lg">
                  {formatMoney(remaining)}
                </span>
              </div>
            </div>
          </div>

          <div className="mt-4">
            <Label htmlFor="notes" className="mb-1 text-xs font-semibold">
              Ghi Chú Đặc Biệt Về Nhân/Đóng Gói
            </Label>
            <Textarea
              id="notes"
              rows={2}
              placeholder="Ví dụ: Bớt mỡ, nhiều đậu xanh, buộc lạt đỏ mừng thọ, hút chân không..."
              {...register("notes")}
            />
          </div>
        </section>

        {onCancel ? (
          <div
            className={
              footerClassName ??
              "flex flex-col-reverse gap-2 border-t border-gray-200 pt-4 sm:flex-row sm:justify-end"
            }
          >
            <Button type="button" variant="secondary" onClick={onCancel}>
              {cancelLabel}
            </Button>
            <Button
              type="submit"
              disabled={isPending}
              className="bg-red-700 font-bold text-white hover:bg-red-800"
            >
              {isPending ? "Đang lưu..." : submitLabel}
            </Button>
          </div>
        ) : (
          <Button
            type="submit"
            disabled={isPending}
            className="w-full bg-red-700 font-bold text-white hover:bg-red-800"
          >
            {isPending ? "Đang lưu..." : submitLabel}
          </Button>
        )}
      </form>

      <AddProductDialog
        open={isAddProductOpen}
        onOpenChange={setIsAddProductOpen}
      />
    </>
  );
}
