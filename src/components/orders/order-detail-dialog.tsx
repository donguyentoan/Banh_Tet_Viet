import { Printer, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatDateDisplay, formatMoney } from "@/lib/format";
import { STATUS_BADGE_CLASSES, STATUS_LABELS } from "@/lib/constants";
import { type Order, type Product } from "@/lib/types";

interface OrderDetailDialogProps {
  open: boolean;
  order: Order | null;
  products: Product[];
  onOpenChange: (open: boolean) => void;
}

export function OrderDetailDialog({
  open,
  order,
  products,
  onOpenChange,
}: OrderDetailDialogProps) {
  if (!order) return null;

  const productMap = new Map(products.map((p) => [p.id, p]));
  const items = Object.entries(order.items).filter(([, qty]) => qty > 0);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] w-[calc(100%-1rem)] min-w-0 max-w-3xl overflow-x-hidden overflow-y-auto border-amber-300 p-3 sm:w-[calc(100%-2rem)] sm:p-4 sm:max-w-3xl">
        <DialogHeader>
          <DialogTitle className="sr-only">Chi tiết đơn hàng</DialogTitle>
        </DialogHeader>

        <div id="print-area">
          <div className="border-b-2 border-dashed border-gray-300 pb-4 text-center">
            <h2 className="text-xl font-black uppercase text-red-700 sm:text-2xl">
              🌺 PHIẾU ĐẶT BÁNH TẾT 2027 🌺
            </h2>
            <p className="mt-1 text-xs text-gray-500">
              Bánh Chưng - Bánh Tét Gia Truyền Chuẩn Vị Tết Việt
            </p>
            <div className="mt-2 inline-block rounded-full bg-amber-100 px-3 py-1 text-xs font-bold text-amber-800">
              Mã đơn: #{order.id}
            </div>
          </div>

          <div className="grid grid-cols-1 gap-3 border-b border-gray-200 py-4 text-sm sm:grid-cols-2 sm:gap-4">
            <div>
              <p className="text-xs text-gray-500">Khách hàng:</p>
              <p className="font-bold text-gray-800">{order.customerName}</p>
            </div>
            <div>
              <p className="text-xs text-gray-500">Số điện thoại:</p>
              <p className="font-bold text-gray-800">{order.phone}</p>
            </div>
            <div className="sm:col-span-2">
              <p className="text-xs text-gray-500">Địa chỉ nhận bánh:</p>
              <p className="font-medium text-gray-800">{order.address}</p>
            </div>
            <div>
              <p className="text-xs text-gray-500">Ngày &amp; Giờ giao bánh:</p>
              <p className="font-bold text-red-700">
                {formatDateDisplay(order.deliveryDate)} ({order.deliveryTime})
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-500">Trạng thái đơn hàng:</p>
              <Badge
                className={`border font-bold ${STATUS_BADGE_CLASSES[order.status] ?? ""}`}
              >
                {STATUS_LABELS[order.status] ?? order.status}
              </Badge>
            </div>
          </div>

          <div className="min-w-0 py-4">
            <h4 className="mb-2 text-sm font-bold text-gray-800">
              Chi tiết sản phẩm đã đặt:
            </h4>
            <div className="space-y-2 sm:hidden">
              {items.map(([productId, qty]) => {
                const product = productMap.get(productId);
                if (!product) return null;
                return (
                  <div
                    key={productId}
                    className="rounded-lg border border-gray-200 bg-white p-3"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <p className="min-w-0 text-xs font-semibold leading-snug text-gray-800">
                      <img src={product.icon} alt={product.name} className="mr-2 inline-block size-5" />  {product.name}
                      </p>
                      <span className="shrink-0 rounded-full bg-red-50 px-2 py-0.5 text-xs font-bold text-red-700">
                        × {qty}
                      </span>
                    </div>
                    <div className="mt-2 grid grid-cols-2 gap-2 border-t border-gray-100 pt-2 text-xs">
                      <div>
                        <p className="text-gray-500">Đơn giá</p>
                        <p className="font-medium text-gray-700">{formatMoney(product.price)}</p>
                      </div>
                      <div className="text-right">
                        <p className="text-gray-500">Thành tiền</p>
                        <p className="font-bold text-gray-900">{formatMoney(product.price * qty)}</p>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>

            <div className="hidden min-w-0 sm:block">
            <Table>
              <TableHeader>
                <TableRow className="bg-gray-100">
                  <TableHead>Sản phẩm</TableHead>
                  <TableHead className="text-center">SL</TableHead>
                  <TableHead className="text-right">Đơn giá</TableHead>
                  <TableHead className="text-right">Thành tiền</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.map(([productId, qty]) => {
                  const product = productMap.get(productId);
                  if (!product) return null;
                  return (
                    <TableRow key={productId}>
                      <TableCell className="font-medium text-gray-800">
                        {product.icon} {product.name}
                      </TableCell>
                      <TableCell className="text-center font-bold text-red-700">
                        {qty}
                      </TableCell>
                      <TableCell className="text-right text-gray-600">
                        {formatMoney(product.price)}
                      </TableCell>
                      <TableCell className="text-right font-bold text-gray-900">
                        {formatMoney(product.price * qty)}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
            </div>
          </div>

          <div className="space-y-2 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm">
            <div className="flex flex-wrap justify-between gap-x-2">
              <span className="text-gray-600">Tổng tiền bánh:</span>
              <span className="font-bold text-gray-900">
                {formatMoney(order.totalAmount)}
              </span>
            </div>
            <div className="flex flex-wrap justify-between gap-x-2 text-emerald-700">
              <span>Đã đặt cọc trước:</span>
              <span className="font-bold">-{formatMoney(order.deposit)}</span>
            </div>
            <div className="flex flex-wrap justify-between gap-x-2 border-t border-amber-300 pt-2 text-sm font-extrabold text-red-700 sm:text-base">
              <span>Còn lại thu khi giao bánh:</span>
              <span className="whitespace-nowrap">{formatMoney(order.totalAmount - order.deposit)}</span>
            </div>
            {order.notes ? (
              <div className="border-t border-amber-200 pt-2 text-xs text-gray-600">
                <strong>Ghi chú:</strong> {order.notes}
              </div>
            ) : null}
          </div>

          <div className="mt-4 grid grid-cols-1 gap-3 border-t border-gray-200 pt-4 text-center text-xs text-gray-500 sm:mt-6 sm:grid-cols-2 sm:gap-4">
            <div>
              <p className="font-bold text-gray-700">Người Đặt Bánh</p>
              <p className="mt-4 italic sm:mt-8">(Ký &amp; ghi rõ họ tên)</p>
            </div>
            <div>
              <p className="font-bold text-gray-700">Bánh Tết Gia Truyền</p>
              <p className="mt-4 italic sm:mt-8">(Xác nhận &amp; Đóng dấu)</p>
            </div>
          </div>
        </div>

        <DialogFooter className="no-print -mx-3 -mb-3 mt-4 border-t border-gray-200 p-3 pt-4 sm:-mx-4 sm:-mb-4 sm:mt-6 sm:p-4 sm:pt-4">
          <Button variant="secondary" onClick={() => onOpenChange(false)}>
            <X className="size-4" />
            Đóng
          </Button>
          <Button
            onClick={() => window.print()}
            className="gap-2 bg-emerald-600 font-bold text-white hover:bg-emerald-700"
          >
            <Printer className="size-4" />
            In Phiếu Đặt Hàng
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
