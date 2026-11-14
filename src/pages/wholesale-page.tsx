import { useEffect, useMemo, useState } from "react";
import { toast } from "sonner";
import { ChevronDown, ChevronUp, Loader2, Plus, Printer, Store, X } from "lucide-react";
import { elementToLabelPngBlob, shareFilesToLabelExpert } from "@/lib/label-expert";
import { WholesalePrintSheet } from "@/components/wholesale/wholesale-print-sheet";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  DistributionTable,
} from "@/components/wholesale/distribution-table";
import {
  MarketFormDialog,
  MarketList,
} from "@/components/wholesale/market-list";
import {
  useCreateWholesale,
  useDeleteMarket,
  useDeleteWholesale,
  useMarkets,
  useProducts,
  useUpdateWholesale,
  useWholesale,
} from "@/hooks/use-orders";
import { formatMoney } from "@/lib/format";
import { calculateWholesaleTotal } from "@/lib/production";
import {
  DELIVERY_DATE_SUGGESTIONS,
  type Market,
  type Product,
  type Wholesale,
} from "@/lib/types";

const DATE_ITEMS = Object.fromEntries(
  DELIVERY_DATE_SUGGESTIONS.map((d) => [d.value, d.label]),
);

/** Mảng rỗng ổn định - tránh tạo reference mới mỗi render gây vòng lặp effect */
const EMPTY_MARKETS: Market[] = [];
const EMPTY_PRODUCTS: Product[] = [];
const EMPTY_WHOLESALE: Wholesale[] = [];

export function WholesalePage() {
  const { data: markets } = useMarkets();
  const { data: products } = useProducts();
  const { data: wholesaleList } = useWholesale();

  const marketsData = markets ?? EMPTY_MARKETS;
  const productsData = products ?? EMPTY_PRODUCTS;
  const wholesaleData = wholesaleList ?? EMPTY_WHOLESALE;

  const createWholesale = useCreateWholesale();
  const updateWholesale = useUpdateWholesale();
  const deleteWholesale = useDeleteWholesale();
  const deleteMarket = useDeleteMarket();

  const [selectedDate, setSelectedDate] = useState<string>(
    DELIVERY_DATE_SUGGESTIONS[1].value,
  );
  const [quantities, setQuantities] = useState<
    Record<string, Record<string, number>>
  >({});
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [editingMarket, setEditingMarket] = useState<Market | null>(null);
  const [selectedMarketId, setSelectedMarketId] = useState<string | null>(null);
  const [marketListOpen, setMarketListOpen] = useState(false);
  /** Các phiếu sẽ in (marketId -> quantities) */
  const [printTargets, setPrintTargets] = useState<
    { market: Market; quantities: Record<string, number> }[]
  >([]);

  // Nạp lịch bỏ bánh đã lưu của ngày đang chọn vào bảng nhập
  useEffect(() => {
    const next: Record<string, Record<string, number>> = {};
    for (const market of marketsData) {
      // Mỗi tiểu thương có một phiếu riêng. Không lấy phiếu đầu tiên
      // của ngày rồi gán lại cho tất cả các tiểu thương.
      const saved = wholesaleData.find(
        (entry) => entry.date === selectedDate && entry.marketId === market.id,
      );
      next[market.id] = saved ? { ...saved.items } : {};
    }
    setQuantities(next);
  }, [selectedDate, wholesaleData, marketsData]);

  const visibleMarkets = useMemo(() => {
    if (!selectedMarketId) return marketsData;
    return marketsData.filter((market) => market.id === selectedMarketId);
  }, [marketsData, selectedMarketId]);

  const dayTotal = useMemo(
    () =>
      Object.values(quantities).reduce(
        (sum, row) => sum + calculateWholesaleTotal(row, productsData),
        0,
      ),
    [quantities, productsData],
  );

  const dayQty = useMemo(
    () =>
      Object.values(quantities).reduce(
        (sum, row) =>
          sum +
          Object.values(row).reduce(
            (inner, qty) => inner + (qty > 0 ? qty : 0),
            0,
          ),
        0,
      ),
    [quantities],
  );

  function handleQtyChange(
    marketId: string,
    productId: string,
    value: number,
  ) {
    setQuantities((prev) => ({
      ...prev,
      [marketId]: {
        ...prev[marketId],
        [productId]: value,
      },
    }));
  }

  function handleSave(marketId: string) {
    const items = Object.fromEntries(
      Object.entries(quantities[marketId] ?? {}).filter(([, qty]) => qty > 0),
    );
    if (Object.keys(items).length === 0) {
      toast.warning("Chưa nhập số lượng bánh cho mối chợ này!");
      return;
    }

    const totalAmount = calculateWholesaleTotal(items, productsData);
    const existing = wholesaleData.find(
      (entry) => entry.date === selectedDate && entry.marketId === marketId,
    );

    const payload = {
      marketId,
      date: selectedDate,
      items,
      totalAmount,
      notes: existing?.notes ?? "",
    };

    if (existing) {
      updateWholesale.mutate(
        { id: existing.id, payload },
        {
          onSuccess: () => toast.success("Đã cập nhật lịch bỏ bánh!"),
          onError: (error) => toast.error(error.message),
        },
      );
      return;
    }

    createWholesale.mutate(payload, {
      onSuccess: () => toast.success("Đã lưu lịch bỏ bánh sỉ!"),
      onError: (error) => toast.error(error.message),
    });
  }

  function handleDeleteSchedule(marketId: string) {
    const existing = wholesaleData.find(
      (entry) => entry.date === selectedDate && entry.marketId === marketId,
    );
    if (!existing) {
      setQuantities((prev) => {
        const next = { ...prev };
        delete next[marketId];
        return next;
      });
      return;
    }

    deleteWholesale.mutate(existing.id, {
      onSuccess: () => {
        toast.warning("Đã xoá lịch bỏ bánh của mối chợ này");
        setQuantities((prev) => {
          const next = { ...prev };
          delete next[marketId];
          return next;
        });
      },
      onError: (error) => toast.error(error.message),
    });
  }

  function handlePrint(marketId: string) {
    const market = marketsData.find((m) => m.id === marketId);
    if (!market) return;
    setPrintTargets([{ market, quantities: quantities[marketId] ?? {} }]);
  }

  const [sharing, setSharing] = useState(false);
  /** Ảnh tem đã tạo sẵn (mỗi mối 1 tem) + vị trí tem kế tiếp cần in */
  const [printFiles, setPrintFiles] = useState<File[] | null>(null);
  const [printIndex, setPrintIndex] = useState(0);

  // Mở xem trước thì tạo sẵn tem ngay: navigator.share phải được gọi ngay
  // trong cú bấm, chờ tạo ảnh sẽ bị lỗi "Must be handling a user gesture".
  useEffect(() => {
    setPrintFiles(null);
    setPrintIndex(0);
    if (printTargets.length === 0) return;
    let cancelled = false;
    const timer = setTimeout(async () => {
      const sheets = Array.from(
        document.querySelectorAll<HTMLElement>("#print-area [data-print-sheet]"),
      );
      try {
        const files: File[] = [];
        for (const sheet of sheets) {
          const blob = await elementToLabelPngBlob(sheet);
          const name = `phieu-si-${sheet.dataset.printSheet}-${selectedDate}.png`;
          files.push(new File([blob], name, { type: "image/png" }));
        }
        if (!cancelled) setPrintFiles(files);
      } catch (e) {
        if (!cancelled)
          toast.error(e instanceof Error ? e.message : "Không tạo được phiếu in");
      }
    }, 300);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [printTargets, selectedDate]);

  /** Trình duyệt có cho chia sẻ nhiều file trong 1 lần không */
  const canShareAll =
    !!printFiles &&
    printFiles.length > 1 &&
    typeof navigator !== "undefined" &&
    !!navigator.canShare?.({ files: printFiles });

  /**
   * Gửi tất cả tem trong 1 lần Share. Trình duyệt không hỗ trợ share nhiều
   * file thì in lần lượt từng tem (In phiếu 1/N, 2/N...).
   */
  async function handleSharePdf() {
    if (!printFiles || printFiles.length === 0) return;
    const batch = canShareAll ? printFiles : [printFiles[printIndex]];
    if (!batch[0]) return;
    setSharing(true);
    try {
      // Không await gì trước share để giữ "user gesture"
      const r = await shareFilesToLabelExpert(batch);
      if (r === "cancelled") return;

      const next = canShareAll ? printFiles.length : printIndex + 1;
      if (next >= printFiles.length) {
        toast.success(
          r === "downloaded"
            ? "Đã tải ảnh phiếu về máy."
            : `Đã gửi ${printFiles.length} phiếu sang máy in!`,
        );
        setPrintIndex(0);
      } else {
        setPrintIndex(next);
      }
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Không in được phiếu");
    } finally {
      setSharing(false);
    }
  }

  const printTotal = printTargets.length;
  const printLabel =
    printTotal <= 1
      ? "In Ngay"
      : canShareAll || !printFiles
        ? `In Tất Cả ${printTotal} Phiếu`
        : `In phiếu ${printIndex + 1}/${printTotal}`;

  function handlePrintAll() {
    const targets = marketsData
      .map((market) => ({
        market,
        quantities: quantities[market.id] ?? {},
      }))
      .filter((item) =>
        Object.values(item.quantities).some((qty) => Number(qty) > 0),
      );

    if (targets.length === 0) {
      toast.warning("Chưa có số lượng nào để in!");
      return;
    }

    setPrintTargets(targets);
  }

  function handleDeleteMarket(market: Market) {
    if (
      !window.confirm(
        `Xoá mối chợ "${market.name}"? Lịch bỏ bánh tương ứng cũng sẽ bị ảnh hưởng.`,
      )
    )
      return;
    deleteMarket.mutate(market.id, {
      onSuccess: () => toast.warning(`Đã xoá mối chợ "${market.name}"`),
      onError: (error) => toast.error(error.message),
    });
  }

  return (
    <>
      {/* Banner tiêu đề */}
      <div className="mb-5 flex flex-col gap-3 overflow-hidden rounded-2xl border border-amber-300 bg-gradient-to-r from-red-800 via-red-700 to-amber-700 px-4 py-4 text-white shadow-lg sm:mb-6 sm:gap-4 sm:px-6 sm:py-6 md:flex-row md:items-center md:justify-between">
        <div className="flex min-w-0 items-start gap-3 sm:items-center sm:gap-4">
          <span className="flex size-11 shrink-0 items-center justify-center rounded-xl sm:size-14 sm:rounded-2xl bg-white/15 ring-1 ring-white/25">
            <Store className="size-6 text-amber-300 sm:size-7" />
          </span>
          <div className="min-w-0 flex-1">
            <h1 className="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1 text-lg font-extrabold leading-tight sm:text-2xl">
              Bỏ Bánh Cho Mối Chợ
              <Badge className="shrink-0 whitespace-nowrap border-amber-300 bg-amber-400 text-[10px] font-black text-amber-950 sm:text-[11px]">
                BÁN SỈ
              </Badge>
            </h1>
            <p className="mt-1 hidden text-xs font-medium text-red-100 sm:block">
              Quản lý tiểu thương, lịch bỏ bánh theo ngày &amp; in phiếu giao sỉ
            </p>
          </div>
        </div>
        <div className="grid grid-cols-2 gap-2 border-t border-white/20 pt-3 sm:flex sm:items-center sm:gap-4 sm:border-0 sm:pt-0">
          <div className="min-w-0 rounded-xl bg-white/10 px-3 py-2 text-left sm:rounded-none sm:bg-transparent sm:p-0 sm:text-right">
            <p className="text-[11px] text-red-100">Tổng bánh trong ngày</p>
            <p className="whitespace-nowrap text-2xl font-black leading-none text-amber-300 sm:text-xl">{dayQty}</p>
          </div>
          <div className="min-w-0 rounded-xl bg-white/10 px-3 py-2 text-left sm:rounded-none sm:bg-transparent sm:p-0 sm:text-right">
            <p className="text-[11px] text-red-100">Tổng tiền sỉ</p>
            <p className="whitespace-nowrap text-2xl font-black leading-none text-amber-300 sm:text-xl">
              {formatMoney(dayTotal)}
            </p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-[320px_1fr]">
        {/* Cột trái: danh sách mối chợ */}
        <div className="overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm">
          <div className="flex cursor-pointer items-center justify-between gap-2 border-b border-gray-200 bg-gradient-to-r from-red-50 to-white px-4 py-3" onClick={() => setMarketListOpen((open) => !open)}>
            <div>
              <h2 className="flex items-center gap-2 text-sm font-extrabold text-gray-900">
                <Store className="size-4 text-red-700" />
                Danh Sách Mối Chợ
              </h2>
              <p className="text-[11px] text-gray-500">
                {marketsData.length} tiểu thương đã đăng ký
              </p>
            </div>
            <Button
              size="sm"
              onClick={(event) => {
                event.stopPropagation();
                setEditingMarket(null);
                setIsFormOpen(true);
              }}
              className="gap-1.5 bg-red-700 font-bold text-white hover:bg-red-800"
            >
              <Plus className="size-3.5" />
              Thêm Mối Chợ
            </Button>
            {marketListOpen ? (
              <ChevronUp className="size-4 shrink-0 text-red-700" />
            ) : (
              <ChevronDown className="size-4 shrink-0 text-red-700" />
            )}
          </div>

          {marketListOpen && (
          <>
          <MarketList
            markets={marketsData}
            selectedMarketId={selectedMarketId}
            onSelect={setSelectedMarketId}
            onEdit={(market) => {
              setEditingMarket(market);
              setIsFormOpen(true);
            }}
            onDelete={handleDeleteMarket}
          />

          {selectedMarketId && (
            <div className="border-t border-gray-200 px-4 py-2">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setSelectedMarketId(null)}
                className="w-full text-xs text-gray-600"
              >
                Xem tất cả mối chợ
              </Button>
            </div>
          )}
          </>
          )}
        </div>

        {/* Cột phải: bảng phân phối */}
        <div className="overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm">
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-gray-200 bg-gradient-to-r from-red-50 via-white to-amber-50/50 px-4 py-3">
            <div>
              <h2 className="text-sm font-extrabold text-gray-900">
                Lịch Bỏ Bánh Sỉ Theo Ngày
              </h2>
              <p className="text-[11px] text-gray-500">
                Nhập số lượng phân phối — tự động áp dụng giá sỉ ưu đãi
              </p>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <Select
                items={DATE_ITEMS}
                value={selectedDate}
                onValueChange={(value) =>
                  setSelectedDate(value ?? DELIVERY_DATE_SUGGESTIONS[1].value)
                }
              >
                <SelectTrigger className="w-[180px] bg-white font-semibold text-red-700">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {DELIVERY_DATE_SUGGESTIONS.map((date) => (
                    <SelectItem key={date.value} value={date.value}>
                      {date.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <Button
                size="sm"
                onClick={handlePrintAll}
                className="gap-1.5 bg-red-700 font-bold text-white hover:bg-red-800"
              >
                <Printer className="size-3.5 text-amber-300" />
                In Tất Cả Phiếu Trong Ngày
              </Button>
            </div>
          </div>

          <DistributionTable
            markets={visibleMarkets}
            products={productsData}
            quantities={quantities}
            onChange={handleQtyChange}
            onSave={handleSave}
            onDelete={handleDeleteSchedule}
            onPrint={handlePrint}
            isPending={createWholesale.isPending || updateWholesale.isPending}
          />
        </div>
      </div>

      <MarketFormDialog
        open={isFormOpen}
        market={editingMarket}
        onOpenChange={(open) => {
          setIsFormOpen(open);
          if (!open) setEditingMarket(null);
        }}
      />

      {/* Khu vực in phiếu giao sỉ (chỉ hiện khi bấm In) */}
      {printTargets.length > 0 && (
        <div className="fixed inset-0 z-50 overflow-auto bg-black/20 p-3 sm:p-6">
          <div className="relative mx-auto min-h-full w-full max-w-3xl rounded-2xl bg-white p-3 shadow-2xl sm:p-6">
            <button
              type="button"
              aria-label="Đóng bản xem trước"
              onClick={() => setPrintTargets([])}
              className="no-print absolute right-3 top-3 z-10 flex size-9 items-center justify-center rounded-full border border-gray-200 bg-white text-gray-600 shadow-sm transition hover:bg-gray-100 hover:text-gray-900"
            >
              <X className="size-4" />
            </button>
          <div id="print-area" className="space-y-6">
            {printTargets.map((target) => (
              <div key={target.market.id} className="print-sheet-host">
                <div data-print-sheet={target.market.id} className="bg-white">
                  <WholesalePrintSheet
                    market={target.market}
                    products={productsData}
                    quantities={target.quantities}
                    date={selectedDate}
                  />
                </div>
              </div>
            ))}
          </div>
          <div className="no-print mt-4 flex justify-end gap-2 border-t border-gray-200 pt-3">
            <Button
              variant="secondary"
              onClick={() => setPrintTargets([])}
              className="bg-white"
            >
              <X className="size-4" />
              Đóng
            </Button>
            <Button
              onClick={handleSharePdf}
              disabled={sharing || !printFiles}
              className="gap-2 bg-red-700 font-bold text-white hover:bg-red-800"
            >
              {sharing || !printFiles ? (
                <Loader2 className="size-4 animate-spin" />
              ) : (
                <Printer className="size-4" />
              )}
              {!printFiles ? "Đang chuẩn bị phiếu..." : printLabel}
            </Button>
          </div>
          </div>
        </div>
      )}
    </>
  );
}

