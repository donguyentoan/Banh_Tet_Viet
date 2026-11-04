import { useMemo } from "react";
import { toast } from "sonner";
import { ClipboardList } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { DashboardStats } from "@/components/dashboard/dashboard-stats";
import { OrderDetailDialog } from "@/components/orders/order-detail-dialog";
import { OrderFormDialog } from "@/components/orders/order-form-dialog";
import { OrderGrid } from "@/components/orders/order-grid";
import { OrderToolbar } from "@/components/orders/order-toolbar";
import {
  useCreateOrder,
  useDeleteOrder,
  useOrders,
  useProducts,
  useUpdateOrder,
} from "@/hooks/use-orders";
import { applyFilters } from "@/lib/filter";
import { calculateTotal, type OrderFormValues, type OrderStatus } from "@/lib/types";
import { useBakeryStore } from "@/stores/bakery-store";

export function OrdersPage() {
  const { data: orders = [], isLoading, error } = useOrders();
  const { data: products = [] } = useProducts();

  const filters = useBakeryStore((s) => s.filters);
  const isFormOpen = useBakeryStore((s) => s.isFormOpen);
  const isDetailOpen = useBakeryStore((s) => s.isDetailOpen);
  const editingOrderId = useBakeryStore((s) => s.editingOrderId);
  const detailOrderId = useBakeryStore((s) => s.detailOrderId);
  const openEditForm = useBakeryStore((s) => s.openEditForm);
  const closeForm = useBakeryStore((s) => s.closeForm);
  const openDetail = useBakeryStore((s) => s.openDetail);
  const closeDetail = useBakeryStore((s) => s.closeDetail);

  const createOrder = useCreateOrder();
  const updateOrder = useUpdateOrder();
  const deleteOrder = useDeleteOrder();

  const editingOrder = useMemo(
    () => orders.find((order) => order.id === editingOrderId) ?? null,
    [orders, editingOrderId],
  );

  const detailOrder = useMemo(
    () => orders.find((order) => order.id === detailOrderId) ?? null,
    [orders, detailOrderId],
  );

  const visibleCount = useMemo(
    () => applyFilters(orders, filters, products).length,
    [orders, filters, products],
  );

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

    if (editingOrderId) {
      updateOrder.mutate(
        { id: editingOrderId, payload },
        {
          onSuccess: () => {
            toast.success(`Đã cập nhật đơn hàng #${editingOrderId}`);
            closeForm();
          },
          onError: (err) => toast.error(err.message),
        },
      );
      return;
    }

    createOrder.mutate(payload, {
      onSuccess: (created) => {
        toast.success(`Đã tạo thành công đơn hàng #${created.id}`);
        closeForm();
      },
      onError: (err) => toast.error(err.message),
    });
  }

  function handleStatusChange(id: string, status: OrderStatus) {
    updateOrder.mutate(
      { id, payload: { status } },
      {
        onSuccess: () => toast.success(`Đã cập nhật đơn #${id} sang "${status}"`),
        onError: (err) => toast.error(err.message),
      },
    );
  }

  function handleDelete(id: string) {
    if (!window.confirm(`Bạn có chắc chắn muốn xóa đơn hàng #${id} không?`)) return;
    deleteOrder.mutate(id, {
      onSuccess: () => toast.warning(`Đã xóa đơn hàng #${id}`),
      onError: (err) => toast.error(err.message),
    });
  }

  return (
    <>
      <DashboardStats orders={orders} products={products} />

      <div className="overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-gray-200 bg-gradient-to-r from-red-50/60 via-white to-amber-50/40 px-5 py-4">
          <div>
            <h2 className="flex items-center gap-2 text-base font-extrabold text-gray-900">
              <ClipboardList className="size-4 text-red-700" />
              Danh Sách Đơn Hàng
            </h2>
            <p className="text-xs text-gray-500">
              Quản lý đơn đặt bánh chưng &amp; bánh tét dịp Tết Ất Tỵ 2026
            </p>
          </div>
          <Badge className="border-red-200 bg-red-50 text-xs font-bold text-red-700">
            {visibleCount} đơn
          </Badge>
        </div>

        <OrderToolbar />

        <div className="bg-amber-50/20 p-4 sm:p-6">
          {isLoading ? (
            <p className="py-16 text-center text-sm text-gray-500">
              Đang tải dữ liệu đơn hàng...
            </p>
          ) : error ? (
            <p className="py-16 text-center text-sm text-red-600">
              Không tải được dữ liệu: {error.message}
            </p>
          ) : (
            <OrderGrid
              orders={orders}
              products={products}
              onView={openDetail}
              onEdit={openEditForm}
              onDelete={handleDelete}
              onStatusChange={handleStatusChange}
            />
          )}
        </div>

        <div className="flex items-center justify-between border-t border-gray-200 bg-gray-50 px-5 py-3 text-xs text-gray-600">
          <div>
            Hiển thị{" "}
            <span className="font-bold text-red-700">{visibleCount}</span> đơn hàng
            dạng Thẻ
          </div>
          <div className="flex items-center space-x-1">
            <span className="italic text-gray-400">
              Quản lý trực quan Card View - Tết Ất Tỵ 2026
            </span>
          </div>
        </div>
      </div>

      <OrderFormDialog
        open={isFormOpen}
        order={editingOrder}
        onOpenChange={(open) => {
          if (!open) closeForm();
        }}
        onSubmit={handleSubmit}
        isPending={createOrder.isPending || updateOrder.isPending}
      />

      <OrderDetailDialog
        open={isDetailOpen}
        order={detailOrder}
        products={products}
        onOpenChange={(open) => {
          if (!open) closeDetail();
        }}
      />
    </>
  );
}
