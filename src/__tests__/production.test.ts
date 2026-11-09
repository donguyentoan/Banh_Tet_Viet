import { describe, expect, it } from "vitest";
import {
  buildInventoryChain,
  calculateDayBalance,
  calculateWholesaleTotal,
  eachDate,
  sumRetailDemand,
  sumWholesaleDemand,
} from "@/lib/production";
import type {
  Inventory,
  Order,
  Product,
  Production,
  Wholesale,
} from "@/lib/types";

const PRODUCTS: Product[] = [
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
    id: "bc_chay",
    name: "Bánh Chưng Chay",
    price: 130000,
    wholesalePrice: 105000,
    category: "CHUNG",
    code: "CC",
    icon: "🌱",
    weight: "1.0 kg",
  },
];

function makeOrder(overrides: Partial<Order> = {}): Order {
  return {
    id: "TB2026-001",
    customerName: "Nguyễn Văn An",
    phone: "0908123456",
    address: "123 Nguyễn Huệ, Quận 1",
    deliveryDate: "2026-02-13",
    deliveryTime: "Sáng (07:00 - 11:00)",
    items: { bc_thit: 5 },
    totalAmount: 750000,
    deposit: 0,
    status: "Mới đặt",
    notes: "",
    createdAt: "2026-02-01",
    ...overrides,
  };
}

describe("sumRetailDemand", () => {
  it("chỉ tính đơn của đúng ngày giao", () => {
    const orders = [
      makeOrder({ deliveryDate: "2026-02-13", items: { bc_thit: 3 } }),
      makeOrder({ id: "TB2026-002", deliveryDate: "2026-02-14", items: { bc_thit: 2 } }),
    ];

    expect(sumRetailDemand(orders, "2026-02-13")).toEqual({ bc_thit: 3 });
  });

  it("bỏ qua đơn đã hủy", () => {
    const orders = [
      makeOrder({ items: { bc_thit: 9 }, status: "Đã hủy" }),
    ];
    expect(sumRetailDemand(orders, "2026-02-13")).toEqual({});
  });

  it("cộng dồn nhiều đơn cùng ngày", () => {
    const orders = [
      makeOrder({ items: { bc_thit: 3, bc_chay: 1 } }),
      makeOrder({ id: "TB2026-002", items: { bc_thit: 2 } }),
    ];
    expect(sumRetailDemand(orders, "2026-02-13")).toEqual({
      bc_thit: 5,
      bc_chay: 1,
    });
  });
});

describe("sumWholesaleDemand", () => {
  it("tổng hợp số lượng mối chợ theo ngày", () => {
    const wholesale: Wholesale[] = [
      {
        id: "BH-001",
        marketId: "m1",
        date: "2026-02-13",
        items: { bc_thit: 10 },
        totalAmount: 1200000,
        notes: "",
        createdAt: "2026-02-10",
      },
      {
        id: "BH-002",
        marketId: "m2",
        date: "2026-02-14",
        items: { bc_thit: 4 },
        totalAmount: 480000,
        notes: "",
        createdAt: "2026-02-10",
      },
    ];

    expect(sumWholesaleDemand(wholesale, "2026-02-13")).toEqual({ bc_thit: 10 });
  });
});

describe("calculateDayBalance", () => {
  it("tính nhu cầu = khách lẻ + mối chợ", () => {
    const orders = [makeOrder({ items: { bc_thit: 5 } })];
    const wholesale: Wholesale[] = [
      {
        id: "BH-001",
        marketId: "m1",
        date: "2026-02-13",
        items: { bc_thit: 10, bc_chay: 3 },
        totalAmount: 0,
        notes: "",
        createdAt: "2026-02-10",
      },
    ];
    const productions: Production[] = [
      {
        id: "SX-001",
        date: "2026-02-13",
        items: { bc_thit: 20, bc_chay: 5 },
        notes: "",
        updatedAt: "2026-02-13",
      },
    ];

    const balance = calculateDayBalance(
      "2026-02-13",
      orders,
      wholesale,
      productions,
      [],
      PRODUCTS,
    );

    const chung = balance.rows.find((r) => r.productId === "bc_thit")!;
    expect(chung.retailDemand).toBe(5);
    expect(chung.wholesaleDemand).toBe(10);
    expect(chung.totalDemand).toBe(15);
    expect(chung.produced).toBe(20);
    expect(chung.availableSupply).toBe(20);
    expect(chung.surplus).toBe(5);
    expect(balance.hasShortage).toBe(false);
  });

  it("phát hiện thiếu bánh khi sản lượng không đủ", () => {
    const orders = [makeOrder({ items: { bc_thit: 20 } })];
    const productions: Production[] = [
      {
        id: "SX-001",
        date: "2026-02-13",
        items: { bc_thit: 5 },
        notes: "",
        updatedAt: "2026-02-13",
      },
    ];

    const balance = calculateDayBalance(
      "2026-02-13",
      orders,
      [],
      productions,
      [],
      PRODUCTS,
    );

    expect(balance.hasShortage).toBe(true);
    const chung = balance.rows.find((r) => r.productId === "bc_thit")!;
    expect(chung.surplus).toBe(-15);
    expect(balance.carryOver.bc_thit).toBeUndefined();
  });

  it("tính tồn kho gối đầu vào nguồn cung", () => {
    const inventories: Inventory[] = [
      {
        id: "TON-001",
        date: "2026-02-13",
        items: { bc_thit: 4 },
        updatedAt: "2026-02-13",
      },
    ];
    const productions: Production[] = [
      {
        id: "SX-001",
        date: "2026-02-13",
        items: { bc_thit: 10 },
        notes: "",
        updatedAt: "2026-02-13",
      },
    ];

    const balance = calculateDayBalance(
      "2026-02-13",
      [makeOrder({ items: { bc_thit: 12 } })],
      [],
      productions,
      inventories,
      PRODUCTS,
    );

    const chung = balance.rows.find((r) => r.productId === "bc_thit")!;
    expect(chung.openingStock).toBe(4);
    expect(chung.availableSupply).toBe(14);
    expect(chung.surplus).toBe(2);
    expect(balance.carryOver.bc_thit).toBe(2);
  });
});

describe("eachDate", () => {
  it("sinh dãy ngày liên tiếp gồm 2 đầu", () => {
    expect(eachDate("2026-02-13", "2026-02-17")).toEqual([
      "2026-02-13",
      "2026-02-14",
      "2026-02-15",
      "2026-02-16",
      "2026-02-17",
    ]);
  });
});

describe("buildInventoryChain (cộng dồn tồn kho gối đầu)", () => {
  it("chuyển phần dư của ngày trước sang tồn gối đầu ngày sau", () => {
    const orders = [
      makeOrder({ deliveryDate: "2026-02-13", items: { bc_thit: 10 } }),
    ];
    const productions: Production[] = [
      {
        id: "SX-001",
        date: "2026-02-13",
        items: { bc_thit: 25 },
        notes: "",
        updatedAt: "2026-02-13",
      },
      {
        id: "SX-002",
        date: "2026-02-14",
        items: { bc_thit: 10 },
        notes: "",
        updatedAt: "2026-02-14",
      },
    ];

    const chain = buildInventoryChain(
      ["2026-02-13", "2026-02-14"],
      orders,
      [],
      productions,
      [],
      PRODUCTS,
    );

    // Ngày 13: dư 15 -> ngày 14 có tồn gối đầu 15
    expect(chain.get("2026-02-13")).toEqual({});
    expect(chain.get("2026-02-14")).toEqual({ bc_thit: 15 });
  });

  it("giữ tồn kho nhập tay nếu lớn hơn giá trị cộng dồn", () => {
    const manual: Inventory[] = [
      {
        id: "TON-001",
        date: "2026-02-14",
        items: { bc_thit: 30 },
        updatedAt: "2026-02-14",
      },
    ];

    const chain = buildInventoryChain(
      ["2026-02-13", "2026-02-14"],
      [],
      [],
      [],
      manual,
      PRODUCTS,
    );

    expect(chain.get("2026-02-14")?.bc_thit).toBe(30);
  });
});

describe("calculateWholesaleTotal", () => {
  it("dùng giá sỉ ưu đãi của từng loại bánh", () => {
    expect(calculateWholesaleTotal({ bc_thit: 10 }, PRODUCTS)).toBe(1200000);
    expect(calculateWholesaleTotal({ bc_thit: 2, bc_chay: 3 }, PRODUCTS)).toBe(
      240000 + 315000,
    );
  });

  it("bỏ qua loại bánh không có trong danh mục", () => {
    expect(calculateWholesaleTotal({ khong_co: 5 }, PRODUCTS)).toBe(0);
  });
});
