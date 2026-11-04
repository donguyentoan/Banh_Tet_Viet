import { describe, expect, it, beforeAll, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { OrderForm } from "@/components/orders/order-form";
import type { Product } from "@/lib/types";

const MOCK_PRODUCTS: Product[] = [
  {
    id: "bc_thit",
    name: "Bánh Chưng Truyền Thống",
    price: 150000,
    category: "CHUNG",
    icon: "🍃",
    weight: "1.2 kg",
  },
];

beforeAll(() => {
  globalThis.fetch = vi.fn(async () =>
    new Response(JSON.stringify(MOCK_PRODUCTS), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    }),
  ) as unknown as typeof fetch;
});

function renderForm() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  const onSubmit = vi.fn();
  const utils = render(
    <QueryClientProvider client={queryClient}>
      <OrderForm onSubmit={onSubmit} submitLabel="Tạo Đơn Hàng" />
    </QueryClientProvider>,
  );
  return { onSubmit, ...utils };
}

describe("OrderForm (dùng chung cho màn hình /order)", () => {
  it("hiển thị danh mục bánh và nút tạo đơn", async () => {
    renderForm();

    await waitFor(() => {
      expect(
        screen.getByLabelText(/Số lượng Bánh Chưng Truyền Thống/i),
      ).toBeTruthy();
    });
    expect(
      screen.getByRole("button", { name: /Tạo Đơn Hàng/i }),
    ).toBeTruthy();
  });

  it("tính tổng và số tiền còn phải thu", async () => {
    const user = userEvent.setup();
    renderForm();

    await waitFor(() => {
      expect(
        screen.getByLabelText(/Số lượng Bánh Chưng Truyền Thống/i),
      ).toBeTruthy();
    });

    const qtyInput = screen.getByLabelText(
      /Số lượng Bánh Chưng Truyền Thống/i,
    );
    await user.clear(qtyInput);
    await user.type(qtyInput, "3");

    await waitFor(() => {
      const total = screen.getByText(/Tổng giá trị đơn bánh/i).parentElement
        ?.textContent;
      expect(total).toContain("450.000");
    });

    const depositInput = screen.getByLabelText(/Số Tiền Đã Đặt Cọc/i);
    await user.clear(depositInput);
    await user.type(depositInput, "150000");

    await waitFor(() => {
      const remaining = screen.getByText(/Còn lại cần thu/i).parentElement
        ?.textContent;
      expect(remaining).toContain("300.000");
    });
  });

  it("gửi dữ liệu đúng khi submit hợp lệ", async () => {
    const user = userEvent.setup();
    const { onSubmit } = renderForm();

    await waitFor(() => {
      expect(
        screen.getByLabelText(/Số lượng Bánh Chưng Truyền Thống/i),
      ).toBeTruthy();
    });

    await user.type(
      screen.getByLabelText(/Họ & Tên Khách Hàng/i),
      "Trần Thị Mai",
    );
    await user.type(screen.getByLabelText(/Số Điện Thoại/i), "0912345678");
    await user.type(
      screen.getByLabelText(/Địa Chỉ Giao Hàng/i),
      "12 Lê Lợi, Quận 1, TP.HCM",
    );

    const qtyInput = screen.getByLabelText(
      /Số lượng Bánh Chưng Truyền Thống/i,
    );
    await user.clear(qtyInput);
    await user.type(qtyInput, "2");

    await user.click(screen.getByRole("button", { name: /Tạo Đơn Hàng/i }));

    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledTimes(1);
    });

    const payload = onSubmit.mock.calls[0][0];
    expect(payload.customerName).toBe("Trần Thị Mai");
    expect(payload.phone).toBe("0912345678");
    expect(payload.quantities.bc_thit).toBe(2);
    expect(payload.deliveryDate).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(payload.deliveryTime).toBeTruthy();
  });

  it("chặn submit khi thiếu thông tin bắt buộc", async () => {
    const user = userEvent.setup();
    const { onSubmit } = renderForm();

    await waitFor(() => {
      expect(
        screen.getByLabelText(/Số lượng Bánh Chưng Truyền Thống/i),
      ).toBeTruthy();
    });

    await user.click(screen.getByRole("button", { name: /Tạo Đơn Hàng/i }));

    await waitFor(() => {
      expect(
        screen.getByText(/Vui lòng nhập họ tên khách hàng/i),
      ).toBeTruthy();
    });
    expect(onSubmit).not.toHaveBeenCalled();
  });
});
