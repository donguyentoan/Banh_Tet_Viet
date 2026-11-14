import { formatDateDisplay, formatMoney } from "@/lib/format";
import { calculateWholesaleTotal } from "@/lib/production";
import { getWholesalePrice, type Market, type Product } from "@/lib/types";

interface WholesalePrintSheetProps {
  market: Market;
  products: Product[];
  quantities: Record<string, number>;
  date: string;
}

/**
 * PHIẾU GIAO BÁNH SỈ - MỐI CHỢ, bố cục máy in nhiệt khổ 76mm.
 * Đồng bộ với OrderPrintSheet (cùng class .print-sheet, cùng kiểu dòng gọn).
 */
export function WholesalePrintSheet({
  market,
  products,
  quantities,
  date,
}: WholesalePrintSheetProps) {
  const rows = products
    .map((product) => ({ product, qty: Number(quantities[product.id] ?? 0) }))
    .filter((row) => row.qty > 0);
  const total = calculateWholesaleTotal(quantities, products);
  const totalQty = rows.reduce((sum, row) => sum + row.qty, 0);

  return (
    <div className="print-sheet bg-white text-gray-900">
      {/* ---------------- Tiêu đề ---------------- */}
      <header className="border-b border-dashed border-gray-400 pb-1.5 text-center">
        <h1 className="text-[24px] font-black uppercase leading-tight tracking-tight text-red-700">
          PHIẾU GIAO BÁNH SỈ
        </h1>
        <p className="text-[15px] font-black leading-tight text-red-600">
          MỐI CHỢ · 2027
        </p>
        <p className="mt-0.5 text-[11px] leading-tight text-gray-600">
          Bánh Chưng - Bánh Tét Gia Truyền
        </p>
      </header>

      {/* ---------------- Ngày giao ---------------- */}
      <section className="flex items-center justify-between border-b border-dashed border-gray-400 py-1 text-[12px]">
        <span className="font-bold">Ngày giao:</span>
        <span className="font-bold text-red-700">{formatDateDisplay(date)}</span>
      </section>

      {/* ---------------- Thông tin mối chợ ---------------- */}
      <section className="border-b border-dashed border-gray-400 py-1.5 text-[12px] leading-snug">
        <Row label="Mối chợ" value={market.name} bold />
        {market.stall ? <Row label="Sạp chợ" value={market.stall} /> : null}
        {market.phone ? <Row label="SĐT" value={market.phone} bold /> : null}
      </section>

      {/* ---------------- Bánh giao ---------------- */}
      <section className="py-1.5">
        <h2 className="mb-1 text-center text-[13px] font-black uppercase tracking-wide text-gray-900">
          Bánh giao
        </h2>
        <ul className="text-[12px] leading-tight">
          {rows.map(({ product, qty }) => {
            const unitPrice = getWholesalePrice(product);
            return (
              <li
                key={product.id}
                className="border-b border-dashed border-gray-300 py-1 last:border-b-0"
              >
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
                <div className="mt-0.5 flex items-start justify-between gap-2">
                  <span className="text-gray-600">
                    {formatMoney(unitPrice)}/cái (sỉ)
                  </span>
                  <span className="whitespace-nowrap font-bold text-gray-900">
                    {formatMoney(unitPrice * qty)}
                  </span>
                </div>
              </li>
            );
          })}
        </ul>
      </section>

      {/* ---------------- Tổng ---------------- */}
      <section className="border-y border-dashed border-gray-400 py-1.5 text-[12px] leading-snug">
        <div className="flex justify-between gap-2">
          <span className="text-gray-600">Tổng số bánh:</span>
          <span className="font-bold text-gray-900">{totalQty} cái</span>
        </div>
        <div className="mt-1 flex justify-between gap-2 border-t border-gray-300 pt-1 text-[15px] font-black text-red-700">
          <span>Tổng tiền:</span>
          <span className="whitespace-nowrap">{formatMoney(total)}</span>
        </div>
      </section>

      {/* ---------------- Chữ ký ---------------- */}
      <section className="grid grid-cols-2 gap-3 pt-2 text-center text-[11px] text-gray-600">
        <SignatureBlock title="Người Nhận Bánh" hint="(Ký & ghi rõ họ tên)" />
        <SignatureBlock title="Bánh Tết Gia Truyền" hint="(Xác nhận & Đóng dấu)" />
      </section>

      <p className="mt-1 text-center text-[10px] text-gray-500">
        Cảm ơn quý mối! Chúc buôn may bán đắt 🌺
      </p>
    </div>
  );
}

function Row({
  label,
  value,
  bold,
}: {
  label: string;
  value: string;
  bold?: boolean;
}) {
  return (
    <div className="flex gap-2">
      <span className="w-[86px] shrink-0 text-gray-500">{label}:</span>
      <span
        className={[
          "min-w-0 flex-1 break-words text-gray-900",
          bold ? "font-bold" : "font-medium",
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
