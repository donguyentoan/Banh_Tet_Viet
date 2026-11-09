import { FileSpreadsheet, LayoutList, PlusCircle } from "lucide-react";
import { useNavigate } from "@tanstack/react-router";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { useOrders, useProducts } from "@/hooks/use-orders";
import { exportToCSV } from "@/lib/export";
import type { Order, Product } from "@/lib/types";

/** Mảng rỗng ổn định - tránh tạo reference mới mỗi render */
const EMPTY_ORDERS: Order[] = [];
const EMPTY_PRODUCTS: Product[] = [];

export function AppHeader() {
  const navigate = useNavigate();
  const { data: orders } = useOrders();
  const { data: products } = useProducts();

  const ordersData = orders ?? EMPTY_ORDERS;
  const productsData = products ?? EMPTY_PRODUCTS;

  function handleExport() {
    try {
      exportToCSV(ordersData, productsData);
      toast.success("Đã tải xuống file CSV đơn hàng thành công!");
    } catch (error) {
      toast.warning(
        error instanceof Error ? error.message : "Không thể xuất dữ liệu đơn hàng",
      );
    }
  }

  return (
    <header className="no-print sticky top-0 z-30 border-b border-amber-200 bg-white shadow-sm">
      <div className="mx-auto flex w-full flex-wrap items-center justify-between gap-2 px-3 py-2.5 sm:gap-4 sm:px-6 sm:py-3.5 lg:px-8">
        <div className="flex items-center space-x-3">
          <div className="flex size-10 items-center justify-center rounded-xl border-2 border-amber-400 bg-gradient-to-tr from-emerald-700 to-emerald-500 text-xl sm:size-12 sm:text-2xl text-white shadow-md">
            🍃
          </div>
          <div>
            <h1 className="flex items-center gap-2 text-sm font-extrabold leading-tight text-red-700 sm:text-xl md:text-2xl">
              BÁNH TẾT VIỆT 2027
              <span className="hidden rounded-full border border-amber-300 bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-800 sm:inline-flex">
                Xuân Đinh Mùi
              </span>
            </h1>
            <p className="hidden text-xs font-medium text-gray-500 sm:block">
              Hệ thống quản lý đặt Bánh Chưng &amp; Bánh Tét gia truyền
            </p>
          </div>
        </div>

        <div className="hidden items-center justify-end space-x-3 sm:flex sm:w-auto">
          <Button
            variant="outline"
            onClick={handleExport}
            className="gap-2 border-amber-300 bg-amber-50 text-amber-800 shadow-sm hover:bg-amber-100 hover:text-amber-900"
          >
            <FileSpreadsheet className="size-4 text-emerald-600" />
            Xuất Excel
          </Button>
          <Button
            variant="outline"
            onClick={() => navigate({ to: "/" })}
            className="gap-2 border-amber-300 bg-amber-50 text-amber-800 shadow-sm hover:bg-amber-100 hover:text-amber-900"
          >
            <LayoutList className="size-4 text-emerald-600" />
            Danh Sách
          </Button>
          <Button
            onClick={() => navigate({ to: "/order" })}
            className="gap-2 bg-gradient-to-r from-red-600 to-red-700 font-bold text-white shadow-md transition hover:-translate-y-0.5 hover:from-red-700 hover:to-red-800 hover:shadow-lg"
          >
            <PlusCircle className="size-4 text-amber-300" />
            Tạo Đơn Hàng Mới
          </Button>
        </div>
      </div>
    </header>
  );
}
