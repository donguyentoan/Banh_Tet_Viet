import { describe, expect, it, beforeAll, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WholesalePage } from "@/pages/wholesale-page";
import { AnalyticsPage } from "@/pages/analytics-page";
import type { Market, Product } from "@/lib/types";

const MOCK_PRODUCTS: Product[] = [
  {
    id: "bc_thit",
    name: "Bánh Chưng Thịt",
    price: 150000,
    wholesalePrice: 120000,
    category: "CHUNG",
    code: "CM",
    icon: "🍃",
    weight: "1.2 kg",
  },
  {
    id: "bt_thit",
    name: "Bánh Tét Thịt",
    price: 160000,
    wholesalePrice: 128000,
    category: "TET",
    code: "TT",
    icon: "🎋",
    weight: "1.2 kg",
  },
];

const MOCK_MARKETS: Market[] = [
  {
    id: "cho_ben_thanh",
    name: "Chị Hương",
    stall: "Sạp 12 - Chợ Bến Thành",
    phone: "0908123456",
    notes: "",
  },
];

beforeAll(() => {
  globalThis.fetch = vi.fn(async (input: RequestInfo | URL) => {
    const url = String(input);
    let body: unknown = [];
    if (url.includes("/api/products")) body = MOCK_PRODUCTS;
    else if (url.includes("/api/markets")) body = MOCK_MARKETS;
    else if (url.includes("/api/wholesale")) body = [];
    else if (url.includes("/api/production")) body = [];
    else if (url.includes("/api/inventory")) body = [];
    else if (url.includes("/api/orders")) body = [];

    return new Response(JSON.stringify(body), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as unknown as typeof fetch;
});

function renderPage(ui: React.ReactNode) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>,
  );
}

describe("WholesalePage (Tab 3)", () => {
  it("hiển thị danh sách mối chợ và bảng phân phối", async () => {
    renderPage(<WholesalePage />);

    await waitFor(() => {
      expect(screen.getByText("Bỏ Bánh Cho Mối Chợ")).toBeTruthy();
    });

    // Danh sách mối chợ (tên hiển thị ở list + ở header bảng phân phối)
    await waitFor(() => {
      expect(screen.getAllByText("Chị Hương").length).toBeGreaterThan(0);
    });
    expect(
      screen.getAllByText((_, element) =>
        (element?.textContent ?? "").includes("Sạp 12 - Chợ Bến Thành"),
      ).length,
    ).toBeGreaterThan(0);

    // Bảng phân phối có các loại bánh
    await waitFor(() => {
      expect(screen.getAllByText("Bánh Chưng Thịt").length).toBeGreaterThan(0);
    });
    expect(screen.getAllByText("Bánh Tét Thịt").length).toBeGreaterThan(0);
    expect(screen.getByText("Lịch Bỏ Bánh Sỉ Theo Ngày")).toBeTruthy();
  });

  it("hiển thị giá sỉ ưu đãi cho từng loại bánh", async () => {
    renderPage(<WholesalePage />);

    // Giá sỉ của Bánh Chưng Thịt = 120.000
    await waitFor(() => {
      expect(
        screen.getAllByText((_, element) =>
          (element?.textContent ?? "").includes("120.000"),
        ).length,
      ).toBeGreaterThan(0);
    });
  });
});

describe("AnalyticsPage (Tab 4)", () => {
  it("hiển thị bảng cân đối kho và ô nhập số lượng ra lò", async () => {
    renderPage(<AnalyticsPage />);

    await waitFor(() => {
      expect(screen.getByText("Thống Kê & Cân Đối Kho Bánh")).toBeTruthy();
    });

    expect(screen.getByText("Số Lượng Ra Lò")).toBeTruthy();
    expect(screen.getByText("Tồn Kho Gối Đầu Các Ngày")).toBeTruthy();

    await waitFor(() => {
      expect(
        screen.getByText(/Bảng Đối Soát Kho Bánh/),
      ).toBeTruthy();
    });

    // Cột "Cần Giao" (tồn kho gối đầu) và "Đã Làm" (sản lượng)
    expect(screen.getByText("Tồn Gối Đầu")).toBeTruthy();
    expect(screen.getByText("Đã Làm")).toBeTruthy();
  });

  it("cho phép nhập số lượng ra lò cho từng loại bánh", async () => {
    renderPage(<AnalyticsPage />);

    await waitFor(() => {
      expect(
        screen.getByLabelText("Số lượng ra lò Bánh Chưng Thịt"),
      ).toBeTruthy();
    });
  });
});
