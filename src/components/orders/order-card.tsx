import {
  CalendarClock,
  Eye,
  MapPin,
  Pencil,
  Phone,
  PhoneCall,
  Trash2,
  User,
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { formatDateDisplay, formatMoney, getRemaining } from "@/lib/format";
import { STATUS_BADGE_CLASSES, STATUS_LABELS } from "@/lib/constants";
import {
  ORDER_STATUSES,
  type Order,
  type OrderStatus,
  type Product,
} from "@/lib/types";

const STATUS_ITEMS = Object.fromEntries(
  ORDER_STATUSES.map((status) => [status, STATUS_LABELS[status]]),
);

/** Màu viền trái theo trạng thái đơn */
const STATUS_ACCENT: Record<OrderStatus, string> = {
  "Mới đặt": "bg-yellow-400",
  "Đã cọc": "bg-blue-500",
  "Đang nấu/gói": "bg-orange-500",
  "Đã giao": "bg-emerald-500",
  "Đã hủy": "bg-red-500",
};

interface OrderCardProps {
  order: Order;
  products: Product[];
  onView: (id: string) => void;
  onEdit: (id: string) => void;
  onDelete: (id: string) => void;
  onStatusChange: (id: string, status: OrderStatus) => void;
}

export function OrderCard({
  order,
  products,
  onView,
  onEdit,
  onDelete,
  onStatusChange,
}: OrderCardProps) {
  const productMap = new Map(products.map((p) => [p.id, p]));

  let totalCakesInOrder = 0;

  for (const [productId, qty] of Object.entries(order.items)) {
    if (qty <= 0) continue;
    const product = productMap.get(productId);
    if (!product) continue;
    totalCakesInOrder += qty;
  }

  const remaining = getRemaining(order);
  const isCancelled = order.status === "Đã hủy";

  return (
    <div
      className={`group relative flex flex-col overflow-hidden rounded-2xl border bg-white shadow-sm transition-all duration-300 hover:-translate-y-0.5 hover:shadow-md ${
        isCancelled
          ? "border-red-200 opacity-75"
          : "border-amber-200/90 hover:border-amber-300"
      }`}
    >
      {/* Viền trạng thái bên trái */}
      <div
        className={`absolute inset-y-0 left-0 w-1 ${STATUS_ACCENT[order.status] ?? "bg-gray-300"}`}
        aria-hidden
      />

      {/* Đầu card */}
      <div className="flex items-start justify-between gap-2 pl-4 pr-4 pt-4 pb-3">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => onView(order.id)}
              title="Xem chi tiết"
              className="cursor-pointer text-sm font-black tracking-tight text-red-700 hover:underline"
            >
              #{order.id}
            </button>
            <Badge className="border-emerald-200 bg-emerald-50 text-[11px] font-bold text-emerald-800">
               {totalCakesInOrder} bánh
            </Badge>
          </div>
          <p className="mt-1 truncate text-sm font-bold text-gray-900">
            <User className="mr-1 inline size-3.5 text-amber-600" />
            {order.customerName}
          </p>
          <p className="mt-0.5 flex items-center gap-1 text-xs font-medium text-gray-500">
            <Phone className="size-3 shrink-0 text-gray-400" />
            {order.phone}
          </p>
        </div>
        <div className="flex items-center gap-1 flex-col">
           <Badge className={`shrink-0 border text-[11px] font-bold ${STATUS_BADGE_CLASSES[order.status] ?? ""}`}>
          {STATUS_LABELS[order.status] ?? order.status}
        </Badge>
        {order.phone !== "" ? (
           <Button
            variant="ghost"
            size="icon"
            className="size-10 text-red-600 hover:bg-red-50 sm:size-8 mt-2"
            title="Gọi khách hàng"
          >
           <a className="bg-white p-2 rounded-2xl border-1 border-[#9f0712]" href={`tel:${order.phone}`}>
            <PhoneCall className="size-5" />
          </a>
          </Button>
        ) : null}
        </div>
       
      </div>

      {/* Địa chỉ + ngày giao */}
      <div className="space-y-1.5 px-4 pb-3">
        <p
          className="flex items-start gap-1.5 text-xs leading-relaxed text-gray-600"
          title={order.address}
        >
          <MapPin className="mt-0.5 size-3 shrink-0 text-amber-600" />
          <span className="line-clamp-2">{order.address}</span>
        </p>
        <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs font-semibold">
          <span className="flex items-center gap-1 text-red-700">
            <CalendarClock className="size-3 text-amber-600" />
            {formatDateDisplay(order.deliveryDate)}
          </span>
          <span className="text-gray-400">·</span>
          <span className="text-gray-600">{order.deliveryTime}</span>
        </div>
      </div>
      {/* Tiền */}
      <div className="mt-auto grid grid-cols-2 gap-2 border-t border-gray-100 bg-gray-50/70 px-4 py-3">
        <div>
          <span className="block text-[10px] font-bold uppercase tracking-wide text-gray-400">
            Tổng tiền
          </span>
          <span className="text-sm font-bold text-gray-900">
            {formatMoney(order.totalAmount)}
          </span>
        </div>
        <div className="text-right">
          <span className="block text-[10px] font-bold uppercase tracking-wide text-red-500">
            Còn lại thu
          </span>
          <span className="text-sm font-extrabold text-red-700">
            {formatMoney(remaining)}
          </span>
        </div>
      </div>

      {/* Chân card: đổi trạng thái + hành động */}
      <div className="flex items-center justify-between gap-2 border-t border-gray-100 px-3 py-2.5">
        <Select
          items={STATUS_ITEMS}
          value={order.status}
          onValueChange={(value) =>
            onStatusChange(order.id, (value ?? order.status) as OrderStatus)
          }
        >
          <SelectTrigger className="h-10 min-w-0 flex-1 cursor-pointer bg-white py-1 text-xs font-semibold sm:h-8 sm:flex-none sm:w-[145px]">
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

        <div className="flex items-center gap-0.5">
          <Button
            variant="ghost"
            size="icon"
            className="size-10 text-blue-600 hover:bg-blue-50 sm:size-8"
            title="Xem chi tiết & In phiếu"
            onClick={() => onView(order.id)}
          >
            <Eye className="size-3.5" />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="size-10 text-amber-600 hover:bg-amber-50 sm:size-8"
            title="Sửa đơn hàng"
            onClick={() => onEdit(order.id)}
          >
            <Pencil className="size-3.5" />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="size-10 text-red-600 hover:bg-red-50 sm:size-8"
            title="Xóa đơn"
            onClick={() => onDelete(order.id)}
          >
            <Trash2 className="size-3.5" />
          </Button>

         
        </div>
      </div>
    </div>
  );
}
