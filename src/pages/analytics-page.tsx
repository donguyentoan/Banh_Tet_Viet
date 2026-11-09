import { useMemo, useState } from "react";
import { toast } from "sonner";
import {
  AlertTriangle,
  Boxes,
  ChefHat,
  Factory,
  Save,
  TrendingUp,
} from "lucide-react";
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
import {
  useInventories,
  useOrders,
  useProductions,
  useProducts,
  useSaveInventory,
  useSaveProduction,
  useWholesale,
} from "@/hooks/use-orders";
import { formatDateDisplay } from "@/lib/format";
import {
  buildInventoryChain,
  calculateDayBalance,
  eachDate,
} from "@/lib/production";
import {
  DELIVERY_DATE_SUGGESTIONS,
  type Inventory,
  type Order,
  type Product,
  type Production,
  type Wholesale,
} from "@/lib/types";

/** Mảng rỗng ổn định - tránh tạo reference mới mỗi render gây vòng lặp effect */
const EMPTY_ORDERS: Order[] = [];
const EMPTY_PRODUCTS: Product[] = [];
const EMPTY_WHOLESALE: Wholesale[] = [];
const EMPTY_PRODUCTION: Production[] = [];
const EMPTY_INVENTORY: Inventory[] = [];

export function AnalyticsPage() {
  const { data: orders } = useOrders();
  const { data: products } = useProducts();
  const { data: wholesaleList } = useWholesale();
  const { data: productions } = useProductions();
  const { data: inventories } = useInventories();

  const ordersData = orders ?? EMPTY_ORDERS;
  const productsData = products ?? EMPTY_PRODUCTS;
  const wholesaleData = wholesaleList ?? EMPTY_WHOLESALE;
  const productionsData = productions ?? EMPTY_PRODUCTION;
  const inventoriesData = inventories ?? EMPTY_INVENTORY;

  const saveProduction = useSaveProduction();
  const saveInventory = useSaveInventory();

  const dates = useMemo(
    () =>
      eachDate(
        DELIVERY_DATE_SUGGESTIONS[0].value,
        DELIVERY_DATE_SUGGESTIONS[DELIVERY_DATE_SUGGESTIONS.length - 1].value,
      ),
    [],
  );

  const [selectedDate, setSelectedDate] = useState<string>(
    DELIVERY_DATE_SUGGESTIONS[0].value,
  );

  /** Tồn kho gối đầu được cộng dồn tự động qua các ngày */
  const inventoryChain = useMemo(
    () =>
      buildInventoryChain(
        dates,
        ordersData,
        wholesaleData,
        productionsData,
        inventoriesData,
        productsData,
      ),
    [
      dates,
      ordersData,
      wholesaleData,
      productionsData,
      inventoriesData,
      productsData,
    ],
  );

  /** Bảng cân đối của ngày đang chọn (dùng tồn gối đầu đã cộng dồn) */
  const balance = useMemo(
    () =>
      calculateDayBalance(
        selectedDate,
        ordersData,
        wholesaleData,
        productionsData,
        [
          {
            id: "chain",
            date: selectedDate,
            items: inventoryChain.get(selectedDate) ?? {},
            updatedAt: "",
          },
        ],
        productsData,
      ),
    [
      selectedDate,
      ordersData,
      wholesaleData,
      productionsData,
      inventoryChain,
      productsData,
    ],
  );

  const productionToday = productionsData.find(
    (p) => p.date === selectedDate,
  );
  const [producedInput, setProducedInput] = useState<
    Record<string, number>
  >({});

  /** Giá trị nhập liệu: ưu tiên giá trị đang sửa, fallback sản lượng đã lưu */
  const producedQty = (productId: string) =>
    producedInput[productId] ?? productionToday?.items?.[productId] ?? 0;

  const openingQty = (productId: string) =>
    inventoryChain.get(selectedDate)?.[productId] ?? 0;

  function handleProducedChange(productId: string, value: number) {
    setProducedInput((prev) => ({ ...prev, [productId]: value }));
  }

  function handleSaveProduction() {
    const items = Object.fromEntries(
      Object.entries(producedInput).filter(([, qty]) => qty > 0),
    );
    if (Object.keys(items).length === 0) {
      toast.warning("Chưa nhập số lượng bánh nào đã nấu/gói xong!");
      return;
    }

    saveProduction.mutate(
      { date: selectedDate, items },
      {
        onSuccess: () => {
          toast.success("Đã lưu số lượng bánh ra lò!");
          setProducedInput({});
        },
        onError: (error) => toast.error(error.message),
      },
    );
  }

  function handleSaveInventory() {
    const items = Object.fromEntries(
      productsData.map((product) => [product.id, openingQty(product.id)]),
    );
    saveInventory.mutate(
      { date: selectedDate, items },
      {
        onSuccess: () => toast.success("Đã chốt tồn kho gối đầu!"),
        onError: (error) => toast.error(error.message),
      },
    );
  }

  const shortageRows = balance.rows.filter((row) => row.surplus < 0);

  return (
    <>
      {/* Banner tiêu đề */}
      <div className="mb-5 flex flex-col gap-3 overflow-hidden rounded-2xl border border-amber-300 bg-gradient-to-r from-red-800 via-red-700 to-amber-700 px-4 py-4 text-white shadow-lg sm:mb-6 sm:gap-4 sm:px-6 sm:py-6 md:flex-row md:items-center md:justify-between">
        <div className="flex min-w-0 items-start gap-3 sm:items-center sm:gap-4">
          <span className="flex size-11 shrink-0 items-center justify-center rounded-xl sm:size-14 sm:rounded-2xl bg-white/15 ring-1 ring-white/25">
            <Factory className="size-6 text-amber-200 sm:size-7" />
          </span>
          <div className="min-w-0 flex-1">
            <h1 className="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1 text-lg font-extrabold leading-tight sm:text-2xl">
              <span className="sm:hidden">Cân Đối Kho Bánh</span>
              <span className="hidden sm:inline">Thống Kê &amp; Cân Đối Kho Bánh</span>
              <Badge className="shrink-0 whitespace-nowrap border-amber-200 bg-amber-300 text-[10px] font-black text-amber-950 sm:text-[11px]">
                BẾP
              </Badge>
            </h1>
            <p className="mt-1 hidden text-xs font-medium text-red-100 sm:block">
              Nhập số bánh ra lò, đối chiếu nhu cầu giao &amp; cộng dồn tồn kho
              gối đầu
            </p>
          </div>
        </div>
        <div className="grid grid-cols-2 gap-2 border-t border-white/20 pt-3 sm:flex sm:items-center sm:gap-4 sm:border-0 sm:pt-0">
          <div className="min-w-0 rounded-xl bg-white/10 px-3 py-2 text-left sm:rounded-none sm:bg-transparent sm:p-0 sm:text-right">
            <p className="text-[11px] text-red-100">Tổng nhu cầu ngày</p>
            <p className="whitespace-nowrap text-2xl font-black leading-none text-amber-200 sm:text-xl">
              {balance.totalDemand}
            </p>
          </div>
          <div className="min-w-0 rounded-xl bg-white/10 px-3 py-2 text-left sm:rounded-none sm:bg-transparent sm:p-0 sm:text-right">
            <p className="text-[11px] text-red-100">Tổng đã làm</p>
            <p className="whitespace-nowrap text-2xl font-black leading-none text-amber-200 sm:text-xl">
              {balance.totalProduced}
            </p>
          </div>
        </div>
      </div>

      {/* Cảnh báo thiếu bánh */}
      {shortageRows.length > 0 && (
        <div className="mb-6 flex items-start gap-3 rounded-2xl border border-red-300 bg-red-50 px-5 py-4">
          <AlertTriangle className="mt-0.5 size-5 shrink-0 text-red-600" />
          <div className="min-w-0">
            <p className="text-sm font-extrabold text-red-800">
              ⚠️ Thiếu bánh so với nhu cầu giao trong ngày {formatDateDisplay(selectedDate)}
            </p>
            <ul className="mt-1 space-y-0.5 text-xs font-medium text-red-700">
              {shortageRows.map((row) => (
                <li key={row.productId}>
                  • {row.icon} {row.name}: thiếu{" "}
                  <strong>{Math.abs(row.surplus)}</strong> cái (cần{" "}
                  {row.totalDemand} - có {row.availableSupply})
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}

      {/* Chọn ngày */}
      <div className="mb-6 flex flex-wrap gap-2">
        {dates.map((date) => {
          const active = date === selectedDate;
          return (
            <button
              key={date}
              type="button"
              onClick={() => {
                setSelectedDate(date);
                setProducedInput({});
              }}
              className={`rounded-lg border px-3 py-2 text-xs font-bold transition ${
                active
                  ? "border-red-600 bg-red-600 text-white shadow-sm"
                  : "border-amber-200 bg-white text-amber-900 hover:border-red-300 hover:bg-amber-50"
              }`}
            >
              {formatDateDisplay(date)}
            </button>
          );
        })}
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-[1fr_380px]">
        {/* Bảng cân đối */}
        <div className="overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm">
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-gray-200 bg-gradient-to-r from-orange-50 via-white to-amber-50/40 px-5 py-4">
            <div>
              <h2 className="flex items-center gap-2 text-base font-extrabold text-gray-900">
                <Boxes className="size-4 text-orange-700" />
                Bảng Đối Soát Kho Bánh — {formatDateDisplay(selectedDate)}
              </h2>
              <p className="text-xs text-gray-500">
                Khách lẻ + mối chợ = nhu cầu · Tồn gối đầu + sản lượng = nguồn cung
              </p>
            </div>
            {balance.hasShortage ? (
              <Badge className="border-red-300 bg-red-100 text-xs font-black text-red-800">
                ⚠️ Thiếu {Math.abs(balance.totalSurplus)} bánh
              </Badge>
            ) : (
              <Badge className="border-emerald-300 bg-emerald-100 text-xs font-black text-emerald-800">
                ✅ Đủ nhu cầu
              </Badge>
            )}
          </div>

          <div className="space-y-2 p-3 sm:hidden">
            {balance.rows.map((row) => (
              <div key={row.productId} className={`rounded-xl border p-3 ${row.surplus < 0 ? "border-red-200 bg-red-50/50" : "border-gray-200 bg-white"}`}>
                <div className="flex items-start justify-between gap-2">
                  <p className="min-w-0 text-xs font-bold leading-snug text-gray-800">{row.icon} {row.name}</p>
                  <span className={`shrink-0 rounded-full px-2 py-1 text-xs font-black ${row.surplus < 0 ? "bg-red-100 text-red-700" : "bg-emerald-100 text-emerald-800"}`}>
                    {row.surplus > 0 ? `+${row.surplus}` : row.surplus}
                  </span>
                </div>
                <div className="mt-2 grid grid-cols-2 gap-x-3 gap-y-2 border-t border-gray-200/70 pt-2 text-xs">
                  <div><p className="text-gray-500">Khách lẻ</p><p className="font-semibold">{row.retailDemand}</p></div>
                  <div><p className="text-gray-500">Mối chợ</p><p className="font-semibold">{row.wholesaleDemand}</p></div>
                  <div><p className="text-gray-500">Tổng cầu</p><p className="font-bold">{row.totalDemand}</p></div>
                  <div><p className="text-gray-500">Tồn gối đầu</p><p className="font-semibold text-blue-700">{row.openingStock}</p></div>
                  <div><p className="text-gray-500">Đã làm</p><p className="font-semibold text-orange-700">{row.produced}</p></div>
                  <div><p className="text-gray-500">Có thể giao</p><p className="font-bold">{row.availableSupply}</p></div>
                </div>
              </div>
            ))}
            <div className="grid grid-cols-2 gap-2 rounded-xl bg-gray-100 p-3 text-xs font-bold">
              <div>Tổng cầu <span className="float-right">{balance.totalDemand}</span></div>
              <div>Tồn gối đầu <span className="float-right">{balance.totalOpeningStock}</span></div>
              <div>Đã làm <span className="float-right">{balance.totalProduced}</span></div>
              <div>Có thể giao <span className="float-right">{balance.totalOpeningStock + balance.totalProduced}</span></div>
            </div>
          </div>

          <div className="hidden sm:block">
          <Table>
            <TableHeader>
              <TableRow className="bg-gray-100">
                <TableHead className="min-w-[190px]">Loại Bánh</TableHead>
                <TableHead className="text-center">Khách Lẻ</TableHead>
                <TableHead className="text-center">Mối Chợ</TableHead>
                <TableHead className="text-center">Tổng Cầu</TableHead>
                <TableHead className="text-center">Tồn Gối Đầu</TableHead>
                <TableHead className="text-center">Đã Làm</TableHead>
                <TableHead className="text-center">Có Thể Giao</TableHead>
                <TableHead className="text-right">Dư / Thiếu</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {balance.rows.map((row) => (
                <TableRow
                  key={row.productId}
                  className={row.surplus < 0 ? "bg-red-50/60" : undefined}
                >
                  <TableCell>
                    <span className="flex items-center gap-2">
                      <span className="text-lg">{row.icon}</span>
                      <span className="font-medium text-gray-800">
                        {row.name}
                      </span>
                    </span>
                  </TableCell>
                  <TableCell className="text-center font-semibold text-gray-700">
                    {row.retailDemand || "—"}
                  </TableCell>
                  <TableCell className="text-center font-semibold text-emerald-700">
                    {row.wholesaleDemand || "—"}
                  </TableCell>
                  <TableCell className="text-center font-black text-gray-900">
                    {row.totalDemand}
                  </TableCell>
                  <TableCell className="text-center font-semibold text-blue-700">
                    {row.openingStock || "—"}
                  </TableCell>
                  <TableCell className="text-center font-semibold text-orange-700">
                    {row.produced || "—"}
                  </TableCell>
                  <TableCell className="text-center font-black text-gray-900">
                    {row.availableSupply}
                  </TableCell>
                  <TableCell
                    className={`text-right font-black ${
                      row.surplus < 0
                        ? "text-red-700"
                        : row.surplus > 0
                          ? "text-emerald-700"
                          : "text-gray-400"
                    }`}
                  >
                    {row.surplus > 0 ? `+${row.surplus}` : row.surplus}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
            <tfoot>
              <TableRow className="bg-gray-50 font-black">
                <TableCell className="text-gray-700">TỔNG CỘNG</TableCell>
                <TableCell className="text-center">
                  {balance.rows.reduce((s, r) => s + r.retailDemand, 0)}
                </TableCell>
                <TableCell className="text-center">
                  {balance.rows.reduce((s, r) => s + r.wholesaleDemand, 0)}
                </TableCell>
                <TableCell className="text-center">
                  {balance.totalDemand}
                </TableCell>
                <TableCell className="text-center">
                  {balance.totalOpeningStock}
                </TableCell>
                <TableCell className="text-center">
                  {balance.totalProduced}
                </TableCell>
                <TableCell className="text-center">
                  {balance.totalOpeningStock + balance.totalProduced}
                </TableCell>
                <TableCell
                  className={`text-right ${
                    balance.totalSurplus < 0 ? "text-red-700" : "text-emerald-700"
                  }`}
                >
                  {balance.totalSurplus > 0
                    ? `+${balance.totalSurplus}`
                    : balance.totalSurplus}
                </TableCell>
              </TableRow>
            </tfoot>
          </Table>
          </div>

          <div className="border-t border-gray-200 bg-blue-50/60 px-5 py-3 text-xs text-blue-900">
            <TrendingUp className="mr-1.5 inline size-3.5" />
            Phần dư của ngày này (
            {Object.values(balance.carryOver).reduce((s, v) => s + v, 0)} bánh) sẽ
            tự động chuyển thành <strong>tồn kho gối đầu</strong> cho ngày kế
            tiếp.
          </div>
        </div>

        {/* Nhập số lượng ra lò */}
        <div className="space-y-6">
          <div className="overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm">
            <div className="flex items-center justify-between gap-2 border-b border-gray-200 bg-gradient-to-r from-orange-50 to-white px-4 py-3">
              <div>
                <h2 className="flex items-center gap-2 text-sm font-extrabold text-gray-900">
                  <ChefHat className="size-4 text-orange-700" />
                  Số Lượng Ra Lò
                </h2>
                <p className="text-[11px] text-gray-500">
                  {formatDateDisplay(selectedDate)} — bếp đã nấu/gói xong
                </p>
              </div>
              <Button
                size="sm"
                onClick={handleSaveProduction}
                disabled={saveProduction.isPending}
                className="gap-1.5 bg-orange-600 font-bold text-white hover:bg-orange-700"
              >
                <Save className="size-3.5" />
                Lưu
              </Button>
            </div>

            <div className="space-y-3 p-4">
              {productsData.map((product) => (
                <div
                  key={product.id}
                  className="flex items-center justify-between gap-3 rounded-lg border border-gray-200 bg-white px-3 py-2"
                >
                  <span className="flex min-w-0 items-center gap-2">
                    <span className="text-lg">{product.icon}</span>
                    <span className="truncate text-xs font-semibold text-gray-800">
                      {product.name}
                    </span>
                  </span>
                  <div className="flex shrink-0 items-center gap-2">
                    <span className="text-[11px] font-semibold text-blue-700">
                      Tồn gối đầu: {openingQty(product.id)}
                    </span>
                    <input
                      type="number"
                      min={0}
                      value={producedQty(product.id)}
                      onChange={(event) => {
                        const value = Number(event.target.value);
                        handleProducedChange(
                          product.id,
                          Number.isFinite(value)
                            ? Math.max(0, Math.trunc(value))
                            : 0,
                        );
                      }}
                      aria-label={`Số lượng ra lò ${product.name}`}
                      className="h-8 w-20 rounded-lg border border-input bg-white px-2 text-center text-sm font-bold focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
                    />
                  </div>
                </div>
              ))}

              <Button
                variant="outline"
                onClick={handleSaveInventory}
                disabled={saveInventory.isPending}
                className="w-full gap-1.5 border-blue-300 bg-blue-50 text-blue-800 hover:bg-blue-100"
              >
                <Save className="size-3.5" />
                Chốt Tồn Kho Gối Đầu Cho Ngày Này
              </Button>
            </div>
          </div>

          {/* Tồn kho gối đầu các ngày */}
          <div className="overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm">
            <div className="border-b border-gray-200 bg-gradient-to-r from-blue-50 to-white px-4 py-3">
              <h2 className="flex items-center gap-2 text-sm font-extrabold text-gray-900">
                <Boxes className="size-4 text-blue-700" />
                Tồn Kho Gối Đầu Các Ngày
              </h2>
              <p className="text-[11px] text-gray-500">
                Được cộng dồn tự động từ phần dư của ngày trước
              </p>
            </div>
            <div className="divide-y divide-gray-100">
              {dates.map((date) => {
                const stock = inventoryChain.get(date) ?? {};
                const total = Object.values(stock).reduce((s, v) => s + v, 0);
                const active = date === selectedDate;
                return (
                  <button
                    key={date}
                    type="button"
                    onClick={() => {
                      setSelectedDate(date);
                      setProducedInput({});
                    }}
                    className={`flex w-full items-center justify-between gap-2 px-4 py-2 text-left transition ${
                      active ? "bg-blue-50" : "hover:bg-gray-50"
                    }`}
                  >
                    <span className="text-xs font-semibold text-gray-700">
                      {formatDateDisplay(date)}
                    </span>
                    <span
                      className={`text-xs font-black ${
                        total > 0 ? "text-blue-700" : "text-gray-400"
                      }`}
                    >
                      {total} bánh
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
