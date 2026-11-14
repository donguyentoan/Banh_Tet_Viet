import { Minus, PhoneCall, Plus, Printer, Save, Trash2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatDateDisplay, formatMoney } from "@/lib/format";
import { calculateWholesaleTotal } from "@/lib/production";
import { getWholesalePrice, type Market, type Product } from "@/lib/types";

interface DistributionTableProps {
  markets: Market[];
  products: Product[];
  /** Số lượng đang nhập: marketId -> productId -> qty */
  quantities: Record<string, Record<string, number>>;
  onChange: (marketId: string, productId: string, value: number) => void;
  onSave: (marketId: string) => void;
  onDelete: (marketId: string) => void;
  onPrint: (marketId: string) => void;
  isPending?: boolean;
}

export function DistributionTable({
  markets,
  products,
  quantities,
  onChange,
  onSave,
  onDelete,
  onPrint,
  isPending = false,
}: DistributionTableProps) {
  if (markets.length === 0) {
    return (
      <div className="px-4 py-12 text-center">
        <p className="text-sm font-bold text-gray-700">
          Chưa có mối chợ nào để phân phối
        </p>
        <p className="mt-1 text-xs text-gray-500">
          Thêm mối chợ ở cột bên trái trước khi nhập số lượng bánh sỉ.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4 p-4">
      {markets.map((market) => {
        const row = quantities[market.id] ?? {};
        const total = calculateWholesaleTotal(row, products);
        const totalQty = Object.values(row).reduce((sum, qty) => sum + qty, 0);

        return (
          <div
            key={market.id}
            className="overflow-hidden rounded-xl border border-amber-200 bg-white shadow-sm"
          >
            <div className="flex flex-wrap items-center justify-between gap-3 border-b border-amber-300 bg-gradient-to-r from-red-800 via-red-700 to-amber-700 px-4 py-3 text-white">
              <div className="flex justify-between items-center gap-6 w-full">
                <div className="min-w-0">
                  <h3 className="flex items-center gap-2 text-sm font-extrabold">
                    <span className="text-lg">🏪</span>
                    {market.name}
                  </h3>
                  <p className="truncate text-[11px] text-red-100">
                    {market.stall} · ☎ {market.phone}
                  </p>
                </div>
                <div className="flex items-center gap-2"> 
                  {market.phone !== "" ? (
                  <Button
                    variant="ghost"
                    size="icon"
                    className="size-10 text-red-600 hover:bg-red-50 sm:size-8"
                    title="Gọi khách hàng"
                  >
                  <a className="bg-white p-2 rounded-2xl border-1" href={`tel:${market.phone}`}>
                    <PhoneCall className="size-5" />
                  </a>
                  </Button>
                ) : null}
                </div>
              </div>

              <div className="flex flex-wrap items-center gap-2">
                <Badge className="border-amber-300 bg-amber-400 text-[11px] font-black text-amber-950">
                  {totalQty} bánh
                </Badge>
                <Badge className="border-white/30 bg-white/15 text-[11px] font-black text-white">
                  {formatMoney(total)}
                </Badge>
                <Button
                  size="icon-sm"
                  variant="ghost"
                  onClick={() => onPrint(market.id)}
                  title="In phiếu giao sỉ"
                  className="text-amber-200 hover:bg-white/20 hover:text-white"
                >
                  <Printer className="size-4" />
                </Button>
                <Button
                  size="icon-sm"
                  variant="ghost"
                  onClick={() => onDelete(market.id)}
                  title="Xoá lịch bỏ bánh của mối chợ này"
                  className="text-red-200 hover:bg-red-500/40 hover:text-white"
                >
                  <Trash2 className="size-4" />
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => onSave(market.id)}
                  disabled={isPending || totalQty === 0}
                  className="gap-1.5 border-amber-300 bg-amber-400 font-bold text-amber-950 hover:bg-amber-300"
                >
                  <Save className="size-3.5" />
                  Lưu
                </Button>
              </div>
            </div>

            <div className="space-y-2 p-3 sm:hidden">
              {products.map((product) => {
                const qty = Number(row[product.id] ?? 0);
                const unitPrice = getWholesalePrice(product);
                return (
                  <div key={product.id} className="rounded-lg border border-gray-200 p-3">
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0 text-xs font-semibold leading-snug text-gray-800">
                        <img src={product.icon} alt={product.name} className="mr-2 inline-block size-5" /> {product.name}
                        {product.code && <span className="ml-1 text-[10px] text-amber-700">{product.code}</span>}
                      </div>
                      <span className="shrink-0 text-xs font-semibold text-red-700">{formatMoney(unitPrice)}</span>
                    </div>
                    <div className="mt-2 flex items-center justify-between gap-2 border-t border-gray-100 pt-2">
                      <div className="flex items-center gap-2">
                        <Button
                          type="button"
                          variant="secondary"
                          size="icon-sm"
                          className="size-9"
                          onClick={() => onChange(market.id, product.id, Math.max(0, qty - 1))}
                          aria-label={`Giảm ${product.name}`}
                        >
                          <Minus className="size-3" />
                        </Button>
                        <input
                          type="number"
                          min={0}
                          value={qty || ""} placeholder="0" onFocus={(e) => e.currentTarget.select()}
                          onChange={(event) => {
                            const value = Number(event.target.value);
                            onChange(market.id, product.id, Number.isFinite(value) ? Math.max(0, Math.trunc(value)) : 0);
                          }}
                          aria-label={`Số lượng ${product.name} cho ${market.name}`}
                          className="h-9 w-16 rounded-lg border border-input bg-white px-2 text-center text-sm font-bold"
                        />
                        <Button
                          type="button"
                          variant="secondary"
                          size="icon-sm"
                          className="size-9 bg-amber-100 text-amber-900 hover:bg-amber-200"
                          onClick={() => onChange(market.id, product.id, qty + 1)}
                          aria-label={`Tăng ${product.name}`}
                        >
                          <Plus className="size-3" />
                        </Button>
                      </div>
                      <div className="text-right">
                        <p className="text-[10px] text-gray-500">Thành tiền</p>
                        <p className="whitespace-nowrap text-xs font-bold text-gray-900">{formatMoney(unitPrice * qty)}</p>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>

            <div className="hidden sm:block">
            <Table>
              <TableHeader>
                <TableRow className="bg-amber-50/60">
                  <TableHead className="min-w-[220px]">Loại Bánh</TableHead>
                  <TableHead className="text-center">Giá Sỉ</TableHead>
                  <TableHead className="text-center">Số Lượng</TableHead>
                  <TableHead className="text-right">Thành Tiền</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {products.map((product) => {
                  const qty = Number(row[product.id] ?? 0);
                  const unitPrice = getWholesalePrice(product);

                  return (
                    <TableRow key={product.id}>
                      <TableCell>
                        <span className="flex items-center gap-2">
                          <img src={product.icon} alt={product.name} className="inline-block size-5" />
                          <span className="font-medium text-gray-800">
                            {product.name}
                          </span>
                          {product.code && (
                            <Badge className="border-amber-300 bg-amber-50 text-[10px] font-bold text-amber-800">
                              {product.code}
                            </Badge>
                          )}
                        </span>
                      </TableCell>
                      <TableCell className="text-center font-semibold text-red-700">
                        {formatMoney(unitPrice)}
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center justify-center gap-1.5">
                          <Button
                            variant="secondary"
                            size="icon-sm"
                            onClick={() =>
                              onChange(market.id, product.id, Math.max(0, qty - 1))
                            }
                            aria-label={`Giảm ${product.name}`}
                          >
                            <Minus className="size-3" />
                          </Button>
                          <input
                            type="number"
                            min={0}
                            value={qty || ""} placeholder="0" onFocus={(e) => e.currentTarget.select()}
                            onChange={(event) => {
                              const value = Number(event.target.value);
                              onChange(
                                market.id,
                                product.id,
                                Number.isFinite(value) ? Math.max(0, Math.trunc(value)) : 0,
                              );
                            }}
                            aria-label={`Số lượng ${product.name} cho ${market.name}`}
                            className="h-7 w-16 rounded-lg border border-input bg-white px-2 text-center text-sm font-bold focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
                          />
                          <Button
                            variant="secondary"
                            size="icon-sm"
                            className="bg-amber-100 text-amber-900 hover:bg-amber-200"
                            onClick={() => onChange(market.id, product.id, qty + 1)}
                            aria-label={`Tăng ${product.name}`}
                          >
                            <Plus className="size-3" />
                          </Button>
                        </div>
                      </TableCell>
                      <TableCell className="text-right font-bold text-gray-900">
                        {formatMoney(unitPrice * qty)}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
              <tfoot>
                <TableRow className="bg-amber-50 font-black">
                  <TableCell colSpan={3} className="text-right text-gray-700">
                    TỔNG TIỀN PHẢI THU
                  </TableCell>
                  <TableCell className="text-right text-base text-red-800">
                    {formatMoney(total)}
                  </TableCell>
                </TableRow>
              </tfoot>
            </Table>
            </div>
          </div>
        );
      })}
    </div>
  );
}

/** Phiếu giao bánh sỉ - dùng cho in ấn */
export function WholesaleReceipt({
  market,
  products,
  quantities,
  date,
}: {
  market: Market;
  products: Product[];
  quantities: Record<string, number>;
  date: string;
}) {
  const rows = products
    .map((product) => ({ product, qty: Number(quantities[product.id] ?? 0) }))
    .filter((row) => row.qty > 0);
  const total = calculateWholesaleTotal(quantities, products);

  return (
    <div className="mx-auto max-w-2xl border-2 border-red-700 bg-white p-3 text-gray-900 sm:p-6">
      <div className="border-b-2 border-dashed border-gray-400 pb-3 text-center">
        <h2 className="text-lg font-black uppercase text-red-700 sm:text-xl">
          🏪 PHIẾU GIAO BÁNH SỈ — MỐI CHỢ
        </h2>
        <p className="mt-1 text-xs text-gray-600">
          Bánh Chưng - Bánh Tét Gia Truyền Chuẩn Vị Tết Việt 2027
        </p>
      </div>

      <div className="grid grid-cols-1 gap-2 border-b border-gray-300 py-4 text-sm sm:grid-cols-2 sm:gap-3">
        <div>
          <p className="text-xs text-gray-500">Mối chợ / Tiểu thương:</p>
          <p className="font-bold">{market.name}</p>
        </div>
        <div>
          <p className="text-xs text-gray-500">Sạp chợ:</p>
          <p className="font-bold">{market.stall}</p>
        </div>
        <div>
          <p className="text-xs text-gray-500">Số điện thoại:</p>
          <p className="font-bold">{market.phone}</p>
        </div>
        <div>
          <p className="text-xs text-gray-500">Ngày giao bánh:</p>
          <p className="font-bold text-red-700">{formatDateDisplay(date)}</p>
        </div>
      </div>

      <div className="my-3 space-y-2 sm:hidden">
        {rows.map(({ product, qty }) => (
          <div key={product.id} className="rounded-lg border border-gray-200 p-3">
            <div className="flex items-start justify-between gap-2">
              <p className="min-w-0 text-xs font-semibold leading-snug"><img src={product.icon} alt={product.name} className="inline-block size-5" /> {product.name}</p>
              <span className="shrink-0 rounded-full bg-red-50 px-2 py-0.5 text-xs font-bold text-red-700">× {qty}</span>
            </div>
            <div className="mt-2 flex justify-between gap-2 border-t border-gray-100 pt-2 text-xs">
              <span className="text-gray-600">Đơn giá {formatMoney(getWholesalePrice(product))}</span>
              <span className="whitespace-nowrap font-bold">{formatMoney(getWholesalePrice(product) * qty)}</span>
            </div>
          </div>
        ))}
      </div>

      <div className="my-4 hidden sm:block">
      <Table>
        <TableHeader>
          <TableRow className="bg-gray-100">
            <TableHead>Loại bánh</TableHead>
            <TableHead className="text-center">SL</TableHead>
            <TableHead className="text-right">Đơn giá</TableHead>
            <TableHead className="text-right">Thành tiền</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map(({ product, qty }) => (
            <TableRow key={product.id}>
              <TableCell className="font-medium">
                <img src={product.icon} alt={product.name} className="inline-block size-5" /> {product.name}
              </TableCell>
              <TableCell className="text-center font-bold text-red-700">
                {qty}
              </TableCell>
              <TableCell className="text-right text-gray-600">
                {formatMoney(getWholesalePrice(product))}
              </TableCell>
              <TableCell className="text-right font-bold">
                {formatMoney(getWholesalePrice(product) * qty)}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
      </div>

      <div className="rounded-lg border border-amber-300 bg-amber-50 p-3 text-right">
        <span className="text-sm text-gray-700">TỔNG TIỀN: </span>
        <span className="text-xl font-black text-red-800">
          {formatMoney(total)}
        </span>
      </div>

      <div className="mt-5 grid grid-cols-1 gap-3 border-t border-gray-300 pt-4 text-center text-xs text-gray-600 sm:mt-8 sm:grid-cols-2 sm:gap-4">
        <div>
          <p className="font-bold text-gray-800">Người Nhận Bánh</p>
          <p className="mt-4 italic sm:mt-10">(Ký &amp; ghi rõ họ tên)</p>
        </div>
        <div>
          <p className="font-bold text-gray-800">Bánh Tết Gia Truyền</p>
          <p className="mt-4 italic sm:mt-10">(Xác nhận &amp; Đóng dấu)</p>
        </div>
      </div>
    </div>
  );
}
