import { describe, expect, it, beforeAll, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { OrderFormDialog } from "@/components/orders/order-form-dialog";
import { orderFormSchema } from "@/lib/types";
import type { Product } from "@/lib/types";

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
    id: "bt_thit",
    name: "Bánh Tét Nhân Thịt Trứng Muối",
    price: 160000,
    category: "TET",
    icon: "🎋",
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

function renderDialog(order = null) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  const onSubmit = vi.fn();
  const utils = render(
    <QueryClientProvider client={queryClient}>
      <OrderFormDialog
        open
        order={order}
        onOpenChange={() => {}}
        onSubmit={onSubmit}
      />
    </QueryClientProvider>,
  );
  return { onSubmit, ...utils };
}

describe("orderFormSchema (Zod)", () => {
  const valid = {
    customerName: "Nguyễn Văn An",
    phone: "0908123456",
    address: "123 Nguyễn Huệ, Quận 1",
    deliveryDate: "2026-02-14",
    deliveryTime: "Sáng (07:00 - 11:00)",
    status: "Mới đặt",
    deposit: 100000,
    notes: "",
    quantities: { bc_thit: 2, bt_thit: 1 },
  };

  it("accepts a valid payload", () => {
    const result = orderFormSchema.safeParse(valid);
    expect(result.success).toBe(true);
  });

  it("rejects an invalid phone number", () => {
    const result = orderFormSchema.safeParse({ ...valid, phone: "123" });
    expect(result.success).toBe(false);
  });

  it("rejects an order with no cakes selected", () => {
    const result = orderFormSchema.safeParse({
      ...valid,
      quantities: { bc_thit: 0 },
    });
    expect(result.success).toBe(false);
  });

  it("rejects a missing address", () => {
    const result = orderFormSchema.safeParse({ ...valid, address: "" });
    expect(result.success).toBe(false);
  });

  it("accepts any delivery date, not only the Tết presets", () => {
    for (const date of ["2026-01-01", "2026-03-20", "2027-12-31"]) {
      const result = orderFormSchema.safeParse({ ...valid, deliveryDate: date });
      expect(result.success).toBe(true);
    }
  });

  it("rejects a malformed delivery date", () => {
    const result = orderFormSchema.safeParse({
      ...valid,
      deliveryDate: "14/02/2026",
    });
    expect(result.success).toBe(false);
  });

  it("accepts any free-form delivery time", () => {
    const result = orderFormSchema.safeParse({
      ...valid,
      deliveryTime: "Buổi trưa (11:00 - 13:00)",
    });
    expect(result.success).toBe(true);
  });

  it("rejects an empty delivery time", () => {
    const result = orderFormSchema.safeParse({ ...valid, deliveryTime: "" });
    expect(result.success).toBe(false);
  });
});

describe("OrderFormDialog", () => {
  it("blocks submit and shows validation errors when the form is empty", async () => {
    const user = userEvent.setup();
    const { onSubmit } = renderDialog();

    await user.click(screen.getByRole("button", { name: /Lưu Đơn Hàng/i }));

    await waitFor(() => {
      expect(
        screen.getByText(/Vui lòng nhập họ tên khách hàng/i),
      ).toBeTruthy();
    });
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it("renders the product catalog from the API", async () => {
    renderDialog();

    await waitFor(() => {
      expect(
        screen.getByLabelText(/Số lượng Bánh Chưng Truyền Thống/i),
      ).toBeTruthy();
    });
    expect(
      screen.getByLabelText(/Số lượng Bánh Tét Nhân Thịt Trứng Muối/i),
    ).toBeTruthy();
  });

  it("submits the computed payload when the form is valid", async () => {
    const user = userEvent.setup();
    const { onSubmit } = renderDialog();

    await waitFor(() => {
      expect(
        screen.getByLabelText(/Số lượng Bánh Chưng Truyền Thống/i),
      ).toBeTruthy();
    });

    await user.type(
      screen.getByLabelText(/Họ & Tên Khách Hàng/i),
      "Nguyễn Văn An",
    );
    await user.type(screen.getByLabelText(/Số Điện Thoại/i), "0908123456");
    await user.type(
      screen.getByLabelText(/Địa Chỉ Giao Hàng/i),
      "123 Nguyễn Huệ, Quận 1, TP.HCM",
    );

    const qtyInput = screen.getByLabelText(
      /Số lượng Bánh Chưng Truyền Thống/i,
    );

    await user.clear(qtyInput);
    await user.type(qtyInput, "2");

    await user.click(screen.getByRole("button", { name: /Lưu Đơn Hàng/i }));

    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledTimes(1);
    });

    const payload = onSubmit.mock.calls[0][0];
    expect(payload.customerName).toBe("Nguyễn Văn An");
    expect(payload.phone).toBe("0908123456");
    expect(payload.quantities.bc_thit).toBe(2);
  });

  it("cập nhật Tổng giá trị đơn bánh khi thay đổi số lượng", async () => {
    const user = userEvent.setup();
    renderDialog();

    await waitFor(() => {
      expect(
        screen.getByLabelText(/Số lượng Bánh Chưng Truyền Thống/i),
      ).toBeTruthy();
    });

    const totalLabel = () =>
      screen.getByText(/Tổng giá trị đơn bánh/i).parentElement?.textContent ?? "";

    expect(totalLabel()).toContain("0");

    // Nhập 2 bánh chưng (150.000đ) => 300.000đ
    const qtyInput = screen.getByLabelText(
      /Số lượng Bánh Chưng Truyền Thống/i,
    );
    await user.clear(qtyInput);
    await user.type(qtyInput, "2");

    await waitFor(() => {
      expect(totalLabel()).toContain("300.000");
    });

    // Thêm 1 bánh tét (160.000đ) => 460.000đ
    const qtyInput2 = screen.getByLabelText(
      /Số lượng Bánh Tét Nhân Thịt Trứng Muối/i,
    );
    await user.clear(qtyInput2);
    await user.type(qtyInput2, "1");

    await waitFor(() => {
      expect(totalLabel()).toContain("460.000");
    });
  });

  it("cập nhật tổng khi bấm nút tăng/giảm số lượng", async () => {
    const user = userEvent.setup();
    renderDialog();

    await waitFor(() => {
      expect(
        screen.getByLabelText(/Số lượng Bánh Chưng Truyền Thống/i),
      ).toBeTruthy();
    });

    const totalLabel = () =>
      screen.getByText(/Tổng giá trị đơn bánh/i).parentElement?.textContent ?? "";

    // Nút + của bánh chưng nằm ngay sau input số lượng bánh chưng
    const qtyInput = screen.getByLabelText(
      /Số lượng Bánh Chưng Truyền Thống/i,
    );
    const plusButton = qtyInput.parentElement?.querySelector(
      "button:last-of-type",
    ) as HTMLButtonElement;
    await user.click(plusButton);

    await waitFor(() => {
      expect(totalLabel()).toContain("150.000");
    });

    await user.click(plusButton);
    await waitFor(() => {
      expect(totalLabel()).toContain("300.000");
    });
  });

  it("hiển thị số tiền còn lại = tổng - tiền cọc", async () => {
    const user = userEvent.setup();
    renderDialog();

    await waitFor(() => {
      expect(
        screen.getByLabelText(/Số lượng Bánh Chưng Truyền Thống/i),
      ).toBeTruthy();
    });

    const qtyInput = screen.getByLabelText(
      /Số lượng Bánh Chưng Truyền Thống/i,
    );
    await user.clear(qtyInput);
    await user.type(qtyInput, "2");

    const depositInput = screen.getByLabelText(/Số Tiền Đã Đặt Cọc/i);
    await user.clear(depositInput);
    await user.type(depositInput, "100000");

    await waitFor(() => {
      const remaining = screen.getByText(/Còn lại cần thu/i).parentElement
        ?.textContent;
      expect(remaining).toContain("200.000");
    });
  });
});
