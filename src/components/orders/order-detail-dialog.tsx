import { useState } from "react";
import { Loader2, Printer, X } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { type Order, type Product } from "@/lib/types";
import { elementToLabelPngBlob, sharePdfToLabelExpert } from "@/lib/label-expert";
import { OrderPrintSheet } from "@/components/orders/order-print-sheet";

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
  const [printing, setPrinting] = useState(false);

  if (!order) return null;

  async function handlePrint() {
    const el = document.getElementById("print-area");
    if (!el || !order) return;
    setPrinting(true);
    try {
      const blob = await elementToLabelPngBlob(el);
      const r = await sharePdfToLabelExpert(blob, `don-${order.id}.png`);
      if (r === "downloaded")
        toast.info("Trình duyệt không hỗ trợ chia sẻ file, đã tải ảnh phiếu về máy.");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Không tạo được phiếu in");
    } finally {
      setPrinting(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] w-[calc(100%-1rem)] min-w-0 max-w-3xl overflow-x-hidden overflow-y-auto border-amber-300 p-3 sm:w-[calc(100%-2rem)] sm:p-4 sm:max-w-3xl">
        <DialogHeader>
          <DialogTitle className="sr-only">Chi tiết đơn hàng</DialogTitle>
        </DialogHeader>

        {/*
          Phiếu in: luôn render theo khung A4 cố định (794px) ở mọi kích thước
          màn hình, nhờ vậy ảnh chụp có tỉ lệ đúng A4 và luôn vừa 1 trang khi in.
        */}
        <div className="print-sheet-host">
          <div id="print-area" className="print-sheet bg-white">
            <OrderPrintSheet order={order} products={products} />
          </div>
        </div>

        <DialogFooter className="no-print -mx-3 -mb-3 mt-4 border-t border-gray-200 p-3 pt-4 sm:-mx-4 sm:-mb-4 sm:mt-6 sm:p-4 sm:pt-4">
          <Button variant="secondary" onClick={() => onOpenChange(false)}>
            <X className="size-4" />
            Đóng
          </Button>
          <Button
            onClick={handlePrint}
            disabled={printing}
            className="gap-2 bg-emerald-600 font-bold text-white hover:bg-emerald-700"
          >
            {printing ? (
              <Loader2 className="size-4 animate-spin" />
            ) : (
              <Printer className="size-4" />
            )}
            {printing ? "Đang tạo phiếu..." : "In Phiếu Đặt Hàng"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
