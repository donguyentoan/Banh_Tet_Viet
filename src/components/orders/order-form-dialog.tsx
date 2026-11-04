import { ShoppingCart, SquarePen } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { OrderForm } from "@/components/orders/order-form";
import type { Order, OrderFormValues } from "@/lib/types";

interface OrderFormDialogProps {
  open: boolean;
  order: Order | null;
  onOpenChange: (open: boolean) => void;
  onSubmit: (values: OrderFormValues) => void;
  isPending?: boolean;
}

export function OrderFormDialog({
  open,
  order,
  onOpenChange,
  onSubmit,
  isPending = false,
}: OrderFormDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] w-[calc(100%-2rem)] max-w-6xl overflow-y-auto border-amber-300 p-0 sm:max-w-6xl">
        <DialogHeader className="sticky top-0 z-10 rounded-t-xl bg-gradient-to-r from-red-700 to-red-800 px-6 py-4 text-white">
          <DialogTitle className="flex items-center gap-2 text-lg font-bold">
            {order ? (
              <SquarePen className="size-5 text-amber-300" />
            ) : (
              <ShoppingCart className="size-5 text-amber-300" />
            )}
            {order
              ? `Chỉnh Sửa Đơn Hàng #${order.id}`
              : "Tạo Đơn Hàng Đặt Bánh Tết Mới"}
          </DialogTitle>
          <DialogDescription className="sr-only">
            Nhập thông tin khách hàng, chọn loại bánh và ngày giao hàng.
          </DialogDescription>
        </DialogHeader>

        <OrderForm
          order={order}
          onSubmit={onSubmit}
          isPending={isPending}
          resetKey={open ? "open" : "closed"}
          onCancel={() => onOpenChange(false)}
          className="space-y-6 px-6 pb-6"
          footerClassName="-mx-6 -mb-6 flex flex-col-reverse gap-2 border-t border-gray-200 bg-gray-50 px-6 py-3 sm:flex-row sm:justify-end"
        />
      </DialogContent>
    </Dialog>
  );
}
