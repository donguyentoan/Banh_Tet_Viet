import { Link, useRouterState } from "@tanstack/react-router";
import {
  ClipboardList,
  Factory,
  ShoppingCart,
  Store,
} from "lucide-react";
import { cn } from "@/lib/utils";

const TABS = [
  {
    to: "/",
    label: "Đơn Hàng & Thống Kê",
    short: "Đơn Hàng",
    icon: ClipboardList,
    match: (pathname: string) => pathname === "/",
  },
  {
    to: "/order",
    label: "Tạo & Chỉnh Sửa Đơn",
    short: "Tạo Đơn",
    icon: ShoppingCart,
    match: (pathname: string) => pathname.startsWith("/order"),
  },
  {
    to: "/wholesale",
    label: "Bỏ Bánh Cho Mối Chợ",
    short: "Mối Chợ",
    icon: Store,
    match: (pathname: string) => pathname.startsWith("/wholesale"),
  },
  {
    to: "/analytics",
    label: "Thống Kê & Cân Đối Kho",
    short: "Cân Đối Kho",
    icon: Factory,
    match: (pathname: string) => pathname.startsWith("/analytics"),
  },
] as const;

export function TabNav() {
  const pathname = useRouterState({
    select: (state) => state.location.pathname,
  });

  return (
    <nav
      aria-label="Điều hướng chính"
      className="no-print fixed inset-x-0 bottom-0 z-40 border-t border-amber-200 bg-white/95 pb-[env(safe-area-inset-bottom)] shadow-[0_-4px_16px_rgba(0,0,0,0.08)] backdrop-blur sm:static sm:border-t-0 sm:border-b sm:bg-white sm:shadow-sm"
    >
      <div className="mx-auto flex w-full justify-around px-1 sm:justify-start sm:overflow-x-auto sm:px-4 lg:px-6">
        {TABS.map((tab) => {
          const active = tab.match(pathname);
          const Icon = tab.icon;

          return (
            <Link
              key={tab.to}
              to={tab.to}
              className={cn(
                "relative flex min-w-0 flex-1 flex-col items-center gap-1 border-b-2 px-1 py-2 text-[10px] font-bold leading-tight transition-colors sm:flex-none sm:flex-row sm:gap-2 sm:px-4 sm:py-3 sm:text-sm",
                active
                  ? "border-red-600 text-red-700"
                  : "border-transparent text-gray-500 hover:border-amber-300 hover:text-amber-700",
              )}
            >
              <Icon
                className={cn(
                  "size-4",
                  active ? "text-red-600" : "text-gray-400",
                )}
              />
              <span className="hidden sm:inline">{tab.label}</span>
              <span className="sm:hidden">{tab.short}</span>
              {active && (
                <span
                  className="absolute inset-x-0 -bottom-px h-0.5 bg-red-600"
                  aria-hidden
                />
              )}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
