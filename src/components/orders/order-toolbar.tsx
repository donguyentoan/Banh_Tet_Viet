import { useEffect, useState } from "react";
import { RotateCcw, Search, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useBakeryStore } from "@/stores/bakery-store";
import { ORDER_STATUSES } from "@/lib/types";
import { STATUS_LABELS, PRODUCT_CATEGORIES } from "@/lib/constants";

const ALL = "ALL";

const STATUS_ITEMS = {
  [ALL]: "-- Tất cả trạng thái --",
  ...Object.fromEntries(ORDER_STATUSES.map((s) => [s, STATUS_LABELS[s]])),
};

const CAKE_ITEMS = {
  [ALL]: "-- Tất cả loại bánh --",
  CHUNG: PRODUCT_CATEGORIES.CHUNG,
  TET: PRODUCT_CATEGORIES.TET,
};

const SORT_ITEMS = {
  NEWEST: "⏳ Mới nhất",
  OLDEST: "⌛ Cũ nhất",
  URGENT: "🔥 Giao gấp (Ngày giao)",
};

export function OrderToolbar() {
  const filters = useBakeryStore((s) => s.filters);
  const setSearch = useBakeryStore((s) => s.setSearch);
  const setStatusFilter = useBakeryStore((s) => s.setStatusFilter);
  const setCakeFilter = useBakeryStore((s) => s.setCakeFilter);
  const setDeliveryDateFilter = useBakeryStore((s) => s.setDeliveryDateFilter);
  const setSort = useBakeryStore((s) => s.setSort);
  const resetFilters = useBakeryStore((s) => s.resetFilters);

  const [searchInput, setSearchInput] = useState(filters.search);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      if (searchInput !== filters.search) setSearch(searchInput);
    }, 250);
    return () => window.clearTimeout(timer);
  }, [searchInput, filters.search, setSearch]);

  return (
    <div className="flex flex-col items-center justify-between gap-4 border-b border-gray-200 bg-gradient-to-r from-red-50/50 via-white to-amber-50/30 p-4 md:flex-row sm:p-5">
      <div className="relative w-full md:w-80">
        <Search className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3 text-gray-400" />
        <Input
          value={searchInput}
          onChange={(event) => setSearchInput(event.target.value)}
          placeholder="Tìm tên khách, SĐT, mã đơn..."
          className="w-full bg-white pl-9 shadow-sm"
        />
      </div>

      <div className="flex w-full flex-wrap items-center gap-3 md:w-auto md:justify-end">
        <Select
          items={STATUS_ITEMS}
          value={filters.status}
          onValueChange={(value) =>
            setStatusFilter(
              (value ?? ALL) as (typeof ORDER_STATUSES)[number] | "ALL",
            )
          }
        >
          <SelectTrigger className="w-[170px] bg-white font-medium">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value={ALL}>-- Tất cả trạng thái --</SelectItem>
            {ORDER_STATUSES.map((status) => (
              <SelectItem key={status} value={status}>
                {STATUS_LABELS[status]}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Select
          items={CAKE_ITEMS}
          value={filters.cake}
          onValueChange={(value) =>
            setCakeFilter((value ?? ALL) as "ALL" | "CHUNG" | "TET")
          }
        >
          <SelectTrigger className="w-[160px] bg-white font-medium">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value={ALL}>-- Tất cả loại bánh --</SelectItem>
            <SelectItem value="CHUNG">{PRODUCT_CATEGORIES.CHUNG}</SelectItem>
            <SelectItem value="TET">{PRODUCT_CATEGORIES.TET}</SelectItem>
          </SelectContent>
        </Select>

        <div className="relative">
          <Input
            type="date"
            value={filters.deliveryDate === ALL ? "" : filters.deliveryDate}
            onChange={(event) =>
              setDeliveryDateFilter(event.target.value || ALL)
            }
            title="Lọc theo ngày giao (bỏ trống = tất cả)"
            className="w-[160px] bg-white font-medium"
          />
          {filters.deliveryDate !== ALL && (
            <Button
              variant="ghost"
              size="icon"
              onClick={() => setDeliveryDateFilter(ALL)}
              title="Xoá lọc ngày giao"
              className="absolute right-1 top-1/2 size-6 -translate-y-1/2 text-gray-500 hover:bg-red-50 hover:text-red-700"
            >
              <X className="size-3.5" />
            </Button>
          )}
        </div>

        <Select
          items={SORT_ITEMS}
          value={filters.sort}
          onValueChange={(value) =>
            setSort((value ?? "NEWEST") as "NEWEST" | "OLDEST" | "URGENT")
          }
        >
          <SelectTrigger className="w-[170px] border-amber-300 bg-amber-50 font-semibold text-amber-900">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="NEWEST">⏳ Mới nhất</SelectItem>
            <SelectItem value="OLDEST">⌛ Cũ nhất</SelectItem>
            <SelectItem value="URGENT">🔥 Giao gấp (Ngày giao)</SelectItem>
          </SelectContent>
        </Select>

        <Button
          variant="ghost"
          size="icon"
          onClick={() => {
            resetFilters();
            setSearchInput("");
          }}
          title="Đặt lại bộ lọc"
          className="text-gray-500 hover:bg-red-50 hover:text-red-700"
        >
          <RotateCcw className="size-4" />
        </Button>
      </div>
    </div>
  );
}
