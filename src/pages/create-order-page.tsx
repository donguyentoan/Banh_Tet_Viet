import { useEffect, useState } from "react";
import { useNavigate } from "@tanstack/react-router";
import { toast } from "sonner";
import { ArrowLeft, ShoppingCart, Sparkles } from "lucide-react";
import { Button } from "@/components/ui/button";
import { OrderForm } from "@/components/orders/order-form";
import { useCreateOrder, useProducts } from "@/hooks/use-orders";
import { calculateTotal, type OrderFormValues } from "@/lib/types";

export function CreateOrderPage() {
  const navigate = useNavigate();
  const createOrder = useCreateOrder();
  const { data: products = [] } = useProducts();
  const [submitted, setSubmitted] = useState(false);

  // Tự động chuyển về trang danh sách sau khi tạo thành công
  useEffect(() => {
    if (submitted && !createOrder.isPending) {
      navigate({ to: "/" });
    }
  }, [submitted, createOrder.isPending, navigate]);

  function handleSubmit(values: OrderFormValues) {
    const payload = {
      customerName: values.customerName,
      phone: values.phone,
      address: values.address,
      deliveryDate: values.deliveryDate,
      deliveryTime: values.deliveryTime,
      items: Object.fromEntries(
        Object.entries(values.quantities).filter(([, qty]) => qty > 0),
      ),
      totalAmount: calculateTotal(values.quantities, products),
      deposit: Number(values.deposit) || 0,
      status: values.status,
      notes: values.notes ?? "",
    };

    createOrder.mutate(payload, {
      onSuccess: (created) => {
        toast.success(`Đã tạo thành công đơn hàng #${created.id}`);
        setSubmitted(true);
      },
      onError: (err) => toast.error(err.message),
    });
  }

  return (
    <div className="w-full space-y-6">
      {/* Banner tiêu đề */}
      <div className="relative overflow-hidden rounded-2xl border border-amber-300 bg-gradient-to-r from-red-700 via-red-800 to-red-900 px-6 py-6 text-white shadow-lg">
        <div
          className="pointer-events-none absolute -right-6 -top-8 text-[10rem] leading-none opacity-10"
          aria-hidden
        >
          🧧
        </div>
        <div className="relative flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div className="flex items-center gap-4">
            <span className="flex size-14 shrink-0 items-center justify-center rounded-2xl bg-white/15 ring-1 ring-white/25">
              <ShoppingCart className="size-7 text-amber-300" />
            </span>
            <div>
              <h1 className="flex items-center gap-2 text-2xl font-extrabold">
                Tạo Đơn Hàng Mới
                <Sparkles className="size-5 text-amber-300" />
              </h1>
              <p className="mt-0.5 text-xs font-medium text-red-100">
                Nhập thông tin khách hàng, chọn bánh &amp; ngày giao — lưu trực
                tiếp vào{" "}
                <code className="rounded bg-white/15 px-1 py-0.5 font-mono text-[11px] text-amber-200">
                  data/orders.json
                </code>
              </p>
            </div>
          </div>
          <Button
            variant="outline"
            onClick={() => navigate({ to: "/" })}
            className="gap-2 self-start border-white/40 bg-white/10 font-semibold text-white hover:bg-white/20 hover:text-white md:self-auto"
          >
            <ArrowLeft className="size-4" />
            Về danh sách đơn
          </Button>
        </div>
      </div>

      {/* Form tạo đơn - chiếm toàn bộ chiều rộng */}
      <div className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
        <OrderForm
          onSubmit={handleSubmit}
          isPending={createOrder.isPending}
          submitLabel="Tạo Đơn Hàng"
          cancelLabel="Về danh sách đơn"
          onCancel={() => navigate({ to: "/" })}
        />
      </div>
    </div>
  );
}
