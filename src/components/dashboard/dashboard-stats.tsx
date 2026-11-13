import { useMemo } from "react";
import type { ReactNode } from "react";
import { Coins, Leaf, Receipt } from "lucide-react";
import { Card } from "@/components/ui/card";
import { formatMoney } from "@/lib/format";
import { calculateDashboardStats } from "@/lib/stats";
import type { Order, Product } from "@/lib/types";
import { NotificationPage } from "@/routes/notification";

function StatCard({
  title,
  value,
  accent,
  borderClass,
  icon,
  iconClass,
  children,
}: {
  title: string;
  value: string | number;
  accent: string;
  borderClass: string;
  icon: ReactNode;
  iconClass: string;
  children?: ReactNode;
}) {
  return (
    <Card
      className={`group relative overflow-hidden border ${borderClass} p-4 shadow-sm transition hover:shadow-md`}
    >
      <div
        className={`pointer-events-none absolute -bottom-4 -right-4 text-6xl opacity-10 transition group-hover:scale-110 ${accent}`}
        aria-hidden
      >
        {icon}
      </div>
      <div className="flex items-center justify-between gap-2">
        <div className="min-w-0">
          <p className="truncate text-[11px] font-bold uppercase tracking-wider text-gray-500">
            {title}
          </p>
          <h3 className="mt-0.5 truncate text-xl font-extrabold text-gray-900">
            {value}
          </h3>
          {children ? (
            <div className="mt-0.5 truncate text-[11px] font-medium text-gray-500">
              {children}
            </div>
          ) : null}
        </div>
        <div
          className={`flex size-10 shrink-0 items-center justify-center rounded-lg text-lg ${iconClass}`}
        >
          {icon}
        </div>
      </div>
    </Card>
  );
}

export function DashboardStats({
  orders,
  products,
}: {
  orders: Order[];
  products: Product[];
}) {
  const stats = useMemo(
    () => calculateDashboardStats(orders, products),
    [orders, products],
  );

  return (
    <div className="mb-6 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
      <StatCard
        title="Tổng Đơn Hàng"
        value={stats.totalOrders}
        accent="text-red-600"
        borderClass="border-red-100"
        icon={<Receipt className="size-16" />}
        iconClass="bg-red-100 text-red-600"
      >
        <span className="space-x-1.5">
          <span>
            Xong:{" "}
            <strong className="text-emerald-700">{stats.completedOrders}</strong>
          </span>
          <span className="text-gray-300">|</span>
          <span className="text-orange-600">
            Nấu/gói:{" "}
            <strong>{stats.cookingCount}</strong>
          </span>
        </span>
      </StatCard>

      <StatCard
        title="Tổng Số Bánh"
        value={stats.totalCakes}
        accent="text-emerald-600"
        borderClass="border-emerald-100"
        icon={<Leaf className="size-16" />}
        iconClass="bg-emerald-100 text-emerald-700"
      >
        <span className="space-x-1.5">
          <span>
            Chưng:{" "}
            <strong className="text-emerald-800">{stats.chungCount}</strong>
          </span>
          <span className="text-gray-300">|</span>
          <span>
            Tét:{" "}
            <strong className="text-emerald-800">{stats.tetCount}</strong>
          </span>
        </span>
      </StatCard>

      <StatCard
        title="Tổng Doanh Thu"
        value={formatMoney(stats.totalRevenue)}
        accent="text-amber-500"
        borderClass="border-amber-100"
        icon={<Coins className="size-16" />}
        iconClass="bg-amber-100 text-amber-600"
      >
        <span>
          Đã cọc:{" "}
          <strong className="text-amber-700">
            {formatMoney(stats.totalDeposit)}
          </strong>
        </span>
      </StatCard>

       <StatCard
        title="Thông báo Facebook"
        value={""}
        accent="text-amber-500"
        borderClass="border-amber-100"
        icon={<Coins className="size-16" />}
        iconClass="bg-amber-100 text-amber-600"
      >
      <NotificationPage />
      </StatCard>

    </div>
  );
}
