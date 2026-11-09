import { describe, expect, it } from "vitest";
import {
  buildCodeIndex,
  parseDeliveryDate,
  parseDeliveryTime,
  parsePhone,
  parseQuickOrder,
} from "@/lib/quick-parse";
import type { Product } from "@/lib/types";

const PRODUCTS: Product[] = [
  {
    id: "bc_thit",
    name: "Bánh Chưng Thịt Mỡ Đậu Xanh",
    price: 150000,
    wholesalePrice: 120000,
    category: "CHUNG",
    code: "CM",
    icon: "🍃",
    weight: "1.2 kg",
  },
  {
    id: "bc_chay",
    name: "Bánh Chưng Chay Đậu Xanh Hạt Sen",
    price: 130000,
    wholesalePrice: 105000,
    category: "CHUNG",
    code: "CC",
    icon: "🌱",
    weight: "1.0 kg",
  },
  {
    id: "bc_dacbiet",
    name: "Bánh Chưng Đặc Biệt Trứng Muối Nấm Đông Cô",
    price: 180000,
    wholesalePrice: 145000,
    category: "CHUNG",
    code: "CĐB",
    icon: "⭐",
    weight: "1.4 kg",
  },
  {
    id: "bt_thit",
    name: "Bánh Tét Nhân Thịt Trứng Muối",
    price: 160000,
    wholesalePrice: 128000,
    category: "TET",
    code: "TT",
    icon: "🎋",
    weight: "1.2 kg",
  },
  {
    id: "bt_chuoi",
    name: "Bánh Tét Nhân Chuối Ngọt",
    price: 110000,
    wholesalePrice: 88000,
    category: "TET",
    code: "TC",
    icon: "🍌",
    weight: "1.0 kg",
  },
  {
    id: "bt_cam",
    name: "Bánh Tét Nếp Cẩm Trứng Muối Đặc Sản",
    price: 175000,
    wholesalePrice: 140000,
    category: "TET",
    code: "TMC",
    icon: "🟣",
    weight: "1.2 kg",
  },
];

describe("buildCodeIndex", () => {
  it("dùng `code` của sản phẩm làm khoá", () => {
    const index = buildCodeIndex(PRODUCTS);
    expect(index.get("cm")?.id).toBe("bc_thit");
    expect(index.get("tmc")?.id).toBe("bt_cam");
  });

  it("suy ra mã từ tên khi sản phẩm không có `code`", () => {
    const withoutCodes: Product[] = PRODUCTS.map((p) => ({ ...p, code: undefined }));
    const index = buildCodeIndex(withoutCodes);
    expect(index.get("cm")?.id).toBe("bc_thit");
    expect(index.get("cc")?.id).toBe("bc_chay");
    expect(index.get("cdb")?.id).toBe("bc_dacbiet");
    expect(index.get("tt")?.id).toBe("bt_thit");
    expect(index.get("tc")?.id).toBe("bt_chuoi");
    expect(index.get("tmc")?.id).toBe("bt_cam");
  });
});

describe("parseDeliveryDate", () => {
  it("đọc ngày dương lịch dd/mm/yyyy", () => {
    expect(parseDeliveryDate("03/02/2027")).toBe("2027-02-03");
    expect(parseDeliveryDate("05/2/2027")).toBe("2027-02-05");
  });

  it("đọc ngày theo dương lịch khi thiếu năm", () => {
    expect(parseDeliveryDate("04/02")).toBe("2027-02-04");
  });

  it("đọc ngày âm lịch ghi bằng chữ", () => {
    expect(parseDeliveryDate("27 tết")).toBe("2027-02-03");
    expect(parseDeliveryDate("29 Tết")).toBe("2027-02-05");
    expect(parseDeliveryDate("26 tết")).toBe("2027-02-02");
  });

  it("trả null khi không nhận ra được ngày", () => {
    expect(parseDeliveryDate("abc")).toBeNull();
  });
});

describe("parseDeliveryTime", () => {
  it("đọc giờ kèm buổi", () => {
    expect(parseDeliveryTime("8 giờ sáng")).toBe("Sáng (08:00 - 11:00)");
    expect(parseDeliveryTime("chiều")).toBe("Chiều (13:00 - 17:00)");
    expect(parseDeliveryTime("tối")).toBe("Tối (18:00 - 21:00)");
  });

  it("trả null khi không có thông tin giờ", () => {
    expect(parseDeliveryTime("xyz")).toBeNull();
  });
});

describe("parsePhone", () => {
  it("nhận diện số điện thoại Việt Nam", () => {
    expect(parsePhone("gọi 0908123456 nhé")).toBe("0908123456");
    expect(parsePhone("+849081234567")).toBe("+849081234567");
  });

  it("trả undefined nếu không có số điện thoại", () => {
    expect(parsePhone("không có số")).toBeUndefined();
  });
});

describe("parseQuickOrder", () => {
  it("phân tích đúng tin nhắn mẫu trong đề bài", () => {
    const result = parseQuickOrder(
      "bà mi / 03/02/2027 / 2 CM / 1 CC / 8 giờ sáng",
      PRODUCTS,
    );

    expect(result.customerName).toBe("bà mi");
    expect(result.deliveryDate).toBe("2027-02-03");
    expect(result.deliveryTime).toBe("Sáng (08:00 - 11:00)");
    expect(result.quantities.bc_thit).toBe(2);
    expect(result.quantities.bc_chay).toBe(1);
    expect(result.unknownCodes).toHaveLength(0);
  });

  it("đọc được số lượng đặt trước mã bánh", () => {
    const result = parseQuickOrder("anh Tuấn 3cm 2tmc", PRODUCTS);
    expect(result.quantities.bc_thit).toBe(3);
    expect(result.quantities.bt_cam).toBe(2);
  });

  it("nhận diện ngày ghi bằng âm lịch", () => {
    const result = parseQuickOrder("chị Hồng ngày 27 tết 1CĐB", PRODUCTS);
    expect(result.deliveryDate).toBe("2027-02-03");
    expect(result.quantities.bc_dacbiet).toBe(1);
  });

  it("lấy số điện thoại ra khỏi tên khách", () => {
    const result = parseQuickOrder(
      "anh Tuấn 0908123457 ngày 27 tết 3cm",
      PRODUCTS,
    );
    expect(result.phone).toBe("0908123457");
    expect(result.customerName).toBe("anh Tuấn");
  });

  it("báo các mã lạ chưa biết", () => {
    const result = parseQuickOrder("chị Hồng 2 XY 1cm", PRODUCTS);
    expect(result.unknownCodes).toContain("XY");
    expect(result.quantities.bc_thit).toBe(1);
  });

  it("không bắt nhầm từ tiếng Việt là mã bánh", () => {
    const result = parseQuickOrder("bà mi 2 cm", PRODUCTS);
    expect(result.unknownCodes).toHaveLength(0);
    expect(result.customerName).toBe("bà mi");
  });

  it("cộng dồn khi mã bánh xuất hiện nhiều lần", () => {
    const result = parseQuickOrder("chị Hồng 2cm và 3cm", PRODUCTS);
    expect(result.quantities.bc_thit).toBe(5);
  });

  it("trả về ngày mặc định khi tin nhắn không có ngày", () => {
    const result = parseQuickOrder("chị Hồng 2cm", PRODUCTS);
    expect(result.deliveryDate).toBe("2027-02-03");
  });
});
