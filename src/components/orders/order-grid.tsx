import { useMemo } from "react";
import { OrderCard } from "@/components/orders/order-card";
import { applyFilters } from "@/lib/filter";
import type { Order, OrderStatus, Product } from "@/lib/types";
import { useBakeryStore } from "@/stores/bakery-store";

interface OrderGridProps {
  orders: Order[];
  products: Product[];
  onView: (id: string) => void;
  onEdit: (id: string) => void;
  onDelete: (id: string) => void;
  onStatusChange: (id: string, status: OrderStatus) => void;
}

export function OrderGrid({
  orders,
  products,
  onView,
  onEdit,
  onDelete,
  onStatusChange,
}: OrderGridProps) {
  const filters = useBakeryStore((s) => s.filters);

  const visible = useMemo(
    () => applyFilters(orders, filters, products),
    [orders, filters, products],
  );

  if (visible.length === 0) {
    return (
      <div className="px-4 py-16 text-center">
        <div className="mx-auto mb-3 flex size-20 items-center justify-center rounded-full bg-amber-100 text-4xl text-amber-600 shadow-inner">
          🏮
        </div>
        <h3 className="text-lg font-bold text-gray-800">
          Không tìm thấy đơn hàng nào!
        </h3>
        <p className="mt-1 text-xs text-gray-500">
          Vui lòng thử lại với từ khóa hoặc bộ lọc khác.
        </p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 gap-5 md:grid-cols-2 lg:grid-cols-3">
      {visible.map((order) => (
        <OrderCard
          key={order.id}
          order={order}
          products={products}
          onView={onView}
          onEdit={onEdit}
          onDelete={onDelete}
          onStatusChange={onStatusChange}
        />
      ))}
    </div>
  );
}
