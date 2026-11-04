import { describe, expect, it, beforeAll, afterEach, vi } from "vitest";
import { render, screen, waitFor, cleanup } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { OrdersPage } from "@/pages/orders-page";
import { applyFilters } from "@/lib/filter";
import { calculateDashboardStats } from "@/lib/stats";
import type { Order, Product } from "@/lib/types";

const MOCK_ORDERS: Order[] = [
  {
    id: "TB2026-001",
    customerName: "Nguyễn Văn An",
    phone: "0908123456",
    address: "123 Nguyễn Huệ, Quận 1, TP.HCM",
    deliveryDate: "2026-02-15",
    deliveryTime: "Sáng (07:00 - 11:00)",
    items: { bc_thit: 4, bt_thit: 2 },
    totalAmount: 920000,
    deposit: 300000,
    status: "Đã cọc",
    notes: "Gói bớt mỡ",
    createdAt: "2026-02-01",
  },
  {
    id: "TB2026-002",
    customerName: "Trần Thị Mai",
    phone: "0912987654",
    address: "45 Lê Lợi, Quận 1",
    deliveryDate: "2026-02-16",
    deliveryTime: "Chiều (13:00 - 17:00)",
    items: { bc_dacbiet: 2, bt_cam: 2 },
    totalAmount: 930000,
    deposit: 930000,
    status: "Đang nấu/gói",
    notes: "",
    createdAt: "2026-02-02",
  },
  {
    id: "TB2026-003",
    customerName: "Phạm Hoàng Long",
    phone: "0977443322",
    address: "88 Võ Văn Tần, Quận 3",
    deliveryDate: "2026-02-14",
    deliveryTime: "Sáng (07:00 - 11:00)",
    items: { bc_chay: 5 },
    totalAmount: 650000,
    deposit: 200000,
    status: "Đã giao",
    notes: "Giao trước 10h",
    createdAt: "2026-02-03",
  },
];

const MOCK_PRODUCTS: Product[] = [
  {
    id: "bc_thit",
    name: "Bánh Chưng Truyền Thống (Thịt Mỡ Đậu Xanh)",
    price: 150000,
    category: "CHUNG",
    icon: "🍃",
    weight: "1.2 kg",
  },
  {
    id: "bc_chay",
    name: "Bánh Chưng Chay (Đậu Xanh Hạt Sen)",
    price: 130000,
    category: "CHUNG",
    icon: "🌱",
    weight: "1.0 kg",
  },
  {
    id: "bc_dacbiet",
    name: "Bánh Chưng Đắc Biệt (Trứng Muối Nấm Đông Cô)",
    price: 180000,
    category: "CHUNG",
    icon: "⭐",
    weight: "1.4 kg",
  },
  {
    id: "bt_thit",
    name: "Bánh Tét Nhân Thịt Trứng Muối",
    price: 160000,
    category: "TET",
    icon: "🎋",
    weight: "1.2 kg",
  },
  {
    id: "bt_chuoi",
    name: "Bánh Tét Nhân Chuối Ngọt (Bánh Chay)",
    price: 110000,
    category: "TET",
    icon: "🍌",
    weight: "1.0 kg",
  },
  {
    id: "bt_cam",
    name: "Bánh Tét Nếp Cẩm Trứng Muối Đặc Sản",
    price: 175000,
    category: "TET",
    icon: "🟣",
    weight: "1.2 kg",
  },
];

beforeAll(() => {
  globalThis.fetch = vi.fn(async (input: RequestInfo | URL) => {
    const url = String(input);
    const body = url.includes("/api/products") ? MOCK_PRODUCTS : MOCK_ORDERS;
    return new Response(JSON.stringify(body), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as unknown as typeof fetch;
});

afterEach(() => cleanup());

function renderPage() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>
      <OrdersPage />
    </QueryClientProvider>,
  );
}

describe("OrdersPage", () => {
  it("renders dashboard stats and order cards from the JSON API", async () => {
    renderPage();

    await waitFor(() => {
      expect(screen.getByText("Nguyễn Văn An")).toBeTruthy();
    });

    // Dashboard totals
    expect(screen.getByText("Tổng Đơn Hàng")).toBeTruthy();
    expect(screen.getByText("Tổng Số Bánh")).toBeTruthy();
    expect(screen.getByText("Tổng Doanh Thu")).toBeTruthy();
    expect(screen.queryByText("Cần Giao (27-29 Tết)")).toBeNull();

    // All 3 orders rendered as cards
    expect(screen.getByText("Trần Thị Mai")).toBeTruthy();
    expect(screen.getByText("Phạm Hoàng Long")).toBeTruthy();
  });
});

describe("dashboard stats", () => {
  it("ignores cancelled orders for revenue and cake counts", () => {
    const orders: Order[] = [
      ...MOCK_ORDERS,
      {
        ...MOCK_ORDERS[0],
        id: "TB2026-009",
        status: "Đã hủy",
        items: { bc_thit: 10 },
        totalAmount: 9_000_000,
      },
    ];

    const stats = calculateDashboardStats(orders, MOCK_PRODUCTS);

    expect(stats.totalOrders).toBe(4);
    expect(stats.totalRevenue).toBe(920000 + 930000 + 650000);
    expect(stats.totalCakes).toBe(6 + 4 + 5);
    expect(stats.completedOrders).toBe(1);
    expect(stats.cookingCount).toBe(1);
    expect(stats.pendingDelivery).toBe(2);
  });
});

describe("filters", () => {
  const base = {
    search: "",
    status: "ALL",
    cake: "ALL",
    deliveryDate: "ALL",
    sort: "NEWEST",
  } as const;

  it("matches by name, phone and order id", () => {
    expect(
      applyFilters(MOCK_ORDERS, { ...base, search: "mai" }, MOCK_PRODUCTS),
    ).toHaveLength(1);
    expect(
      applyFilters(MOCK_ORDERS, { ...base, search: "0908123456" }, MOCK_PRODUCTS),
    ).toHaveLength(1);
    expect(
      applyFilters(MOCK_ORDERS, { ...base, search: "TB2026-003" }, MOCK_PRODUCTS),
    ).toHaveLength(1);
    expect(
      applyFilters(MOCK_ORDERS, { ...base, search: "zzz" }, MOCK_PRODUCTS),
    ).toHaveLength(0);
  });

  it("filters by status, cake category and delivery date", () => {
    expect(
      applyFilters(MOCK_ORDERS, { ...base, status: "Đã giao" }, MOCK_PRODUCTS),
    ).toHaveLength(1);
    expect(
      applyFilters(MOCK_ORDERS, { ...base, cake: "TET" }, MOCK_PRODUCTS),
    ).toHaveLength(2);
    expect(
      applyFilters(
        MOCK_ORDERS,
        { ...base, deliveryDate: "2026-02-14" },
        MOCK_PRODUCTS,
      ),
    ).toHaveLength(1);
  });

  it("sorts newest / oldest / by delivery date", () => {
    expect(
      applyFilters(MOCK_ORDERS, { ...base, sort: "NEWEST" }, MOCK_PRODUCTS).map(
        (o) => o.id,
      ),
    ).toEqual(["TB2026-003", "TB2026-002", "TB2026-001"]);

    expect(
      applyFilters(MOCK_ORDERS, { ...base, sort: "OLDEST" }, MOCK_PRODUCTS).map(
        (o) => o.id,
      ),
    ).toEqual(["TB2026-001", "TB2026-002", "TB2026-003"]);

    expect(
      applyFilters(MOCK_ORDERS, { ...base, sort: "URGENT" }, MOCK_PRODUCTS).map(
        (o) => o.id,
      ),
    ).toEqual(["TB2026-003", "TB2026-001", "TB2026-002"]);
  });
});
