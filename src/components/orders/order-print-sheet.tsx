import { formatDateDisplay, formatMoney } from "@/lib/format";
import { STATUS_LABELS } from "@/lib/constants";
import { type Order, type Product } from "@/lib/types";

interface OrderPrintSheetProps {
  order: Order;
  products: Product[];
}

/**
 * PHIẾU ĐẶT BÁNH TẾT 2027 - bố cục cho máy in nhiệt khổ 76mm.
 *
 * Khổ giấy 76mm @96dpi tương đương 287px. Nhưng html-to-image chụp ở
 * pixelRatio = 2 nên ta dùng bề rộng 576px (76mm @192dpi) để ảnh ra đủ nét,
 * sau đó jsPDF đặt vào khổ 76mm - nội dung luôn vừa đúng bề rộng giấy.
 *
 * Toàn bộ chiều cao được kiểm soát để phiếu gọn, không bị cắt trang.
 */
export function OrderPrintSheet({ order, products }: OrderPrintSheetProps) {
  const productMap = new Map(products.map((p) => [p.id, p]));
  const items = Object.entries(order.items).filter(([, qty]) => qty > 0);
  const remaining = order.totalAmount - order.deposit;

  return (
    <div className="print-sheet bg-white text-gray-900">
      {/* ---------------- Tiêu đề ---------------- */}
      <header className="border-b border-dashed border-gray-400 pb-1.5 text-center">
        <h1 className="text-[26px] font-black uppercase leading-tight tracking-tight text-red-700">
          PHIẾU ĐẶT BÁNH TẾT
        </h1>
        <p className="text-[17px] font-black leading-tight text-red-600">
          2027
        </p>
        <p className="mt-0.5 text-[11px] leading-tight text-gray-600">
          Bánh Chưng - Bánh Tét Gia Truyền
        </p>
      </header>

      {/* ---------------- Mã đơn + thời gian ---------------- */}
      <section className="flex items-center justify-between border-b border-dashed border-gray-400 py-1 text-[12px]">
        <span className="font-bold">Mã đơn: #{order.id}</span>
        <span className="text-gray-600">
          {formatDateDisplay(order.deliveryDate)}
        </span>
      </section>

      {/* ---------------- Thông tin khách hàng ---------------- */}
      <section className="border-b border-dashed border-gray-400 py-1.5 text-[12px] leading-snug">
        <Row label="Khách hàng" value={order.customerName} bold />
        <Row label="SĐT" value={order.phone} bold />
        <Row label="Địa chỉ" value={order.address} />
        <Row
          label="Ngày & giờ giao"
          value={`${formatDateDisplay(order.deliveryDate)} (${order.deliveryTime})`}
          bold
          accent
        />
        <Row label="Trạng thái" value={STATUS_LABELS[order.status] ?? order.status} />
      </section>

      {/* ---------------- Sản phẩm đã đặt (dạng dòng gọn, không dùng table) ---------------- */}
      <section className="py-1.5">
        <h2 className="mb-1 text-center text-[13px] font-black uppercase tracking-wide text-gray-900">
          Sản phẩm đã đặt
        </h2>
        <ul className="text-[12px] leading-tight">
          {items.map(([productId, qty]) => {
            const product = productMap.get(productId);
            if (!product) return null;
            return (
              <li
                key={productId}
                className="border-b border-dashed border-gray-300 py-1 last:border-b-0"
              >
                {/* Dòng 1: tên bánh (trái) - số lượng (phải) */}
                <div className="flex items-start justify-between gap-2">
                  <span className="min-w-0 flex-1 font-bold text-gray-900">
                    {product.name}
                    {product.weight ? (
                      <span className="font-normal text-gray-500">
                        {" "}
                        ({product.weight})
                      </span>
                    ) : null}
                  </span>
                  <span className="shrink-0 whitespace-nowrap font-black text-red-700">
                    ×{qty}
                  </span>
                </div>
                {/* Dòng 2: đơn giá (trái) - thành tiền (phải) */}
                <div className="mt-0.5 flex items-start justify-between gap-2">
                  <span className="text-gray-600">
                    {formatMoney(product.price)}/cái
                  </span>
                  <span className="whitespace-nowrap font-bold text-gray-900">
                    {formatMoney(product.price * qty)}
                  </span>
                </div>
              </li>
            );
          })}
        </ul>
      </section>

      {/* ---------------- Tổng tiền ---------------- */}
      <section className="border-y border-dashed border-gray-400 py-1.5 text-[12px] leading-snug">
        <div className="flex justify-between gap-2">
          <span className="text-gray-600">Tổng tiền bánh:</span>
          <span className="font-bold text-gray-900">
            {formatMoney(order.totalAmount)}
          </span>
        </div>
        <div className="flex justify-between gap-2 text-emerald-700">
          <span>Đã đặt cọc trước:</span>
          <span className="font-bold">-{formatMoney(order.deposit)}</span>
        </div>
        <div className="mt-1 flex justify-between gap-2 border-t border-gray-300 pt-1 text-[15px] font-black text-red-700">
          <span>Còn lại khi giao:</span>
          <span className="whitespace-nowrap">{formatMoney(remaining)}</span>
        </div>
        {order.notes ? (
          <p className="mt-1 border-t border-gray-300 pt-1 text-[11px] leading-snug text-gray-700">
            <strong>Ghi chú:</strong> {order.notes}
          </p>
        ) : null}
      </section>

      {/* ---------------- Chữ ký ---------------- */}
      <section className="grid grid-cols-2 gap-3 pt-2 text-center text-[11px] text-gray-600">
        <SignatureBlock title="Người Đặt Bánh" hint="(Ký & ghi rõ họ tên)" />
        <SignatureBlock title="Bánh Tết Gia Truyền" hint="(Xác nhận & Đóng dấu)" />
      </section>

      <p className="mt-1 text-center text-[10px] text-gray-500">
        Cảm ơn quý khách! Hẹn giao bánh đúng ngày 🌺
      </p>
    </div>
  );
}

function Row({
  label,
  value,
  bold,
  accent,
}: {
  label: string;
  value: string;
  bold?: boolean;
  accent?: boolean;
}) {
  return (
    <div className="flex gap-2">
      <span className="w-[86px] shrink-0 text-gray-500">{label}:</span>
      <span
        className={[
          "min-w-0 flex-1 break-words",
          bold ? "font-bold" : "font-medium",
          accent ? "text-red-700" : "text-gray-900",
        ].join(" ")}
      >
        {value}
      </span>
    </div>
  );
}

function SignatureBlock({ title, hint }: { title: string; hint: string }) {
  return (
    <div>
      <p className="font-bold text-gray-800">{title}</p>
      <p className="mt-7 h-px w-full bg-gray-400" />
      <p className="mt-0.5 italic">{hint}</p>
    </div>
  );
}
