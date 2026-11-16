import { describe, expect, it } from "vitest";
import {
  buildPaymentContent,
  buildVietQrUrl,
  extractOrderId,
  normalizeOrderId,
  SEPAY_BANK,
  SEPAY_CONTENT_PREFIX,
} from "@/lib/sepay";

describe("normalizeOrderId", () => {
  it("bỏ dấu gạch ngang và khoảng trắng, chuyển chữ hoa", () => {
    expect(normalizeOrderId("TB2027-004")).toBe("TB2027004");
    expect(normalizeOrderId("tb 2027 004")).toBe("TB2027004");
    expect(normalizeOrderId("TB2027004")).toBe("TB2027004");
  });
});

describe("buildPaymentContent", () => {
  it("gắn tiền tố TET vào mã đơn", () => {
    expect(buildPaymentContent("TB2027-004")).toBe("TETTB2027-004");
    expect(buildPaymentContent("TB2027-004").startsWith(SEPAY_CONTENT_PREFIX)).toBe(
      true,
    );
  });
});

describe("extractOrderId", () => {
  const known = ["TB2027-001", "TB2027-002", "TB2027-003", "TB2027-004"];

  it("bóc đúng mã đơn khi nội dung có tiền tố TET", () => {
    expect(extractOrderId("TETTB2027-004", known)).toBe("TB2027-004");
  });

  it("bóc đúng mã đơn khi ngân hàng bỏ dấu gạch ngang", () => {
    expect(extractOrderId("TETTB2027004", known)).toBe("TB2027-004");
  });

  it("bóc đúng mã đơn khi nội dung có khoảng trắng thừa", () => {
    expect(extractOrderId("TET TB2027-004", known)).toBe("TB2027-004");
  });

  it("bóc đúng mã đơn khi nội dung có hậu tố thêm", () => {
    expect(extractOrderId("TETTB2027-004 BÁNH", known)).toBe("TB2027-004");
  });

  it("bóc đúng mã đơn khi ngân hàng bỏ luôn tiền tố", () => {
    expect(extractOrderId("TB2027-002", known)).toBe("TB2027-002");
  });

  it("trả về null khi không có mã đơn nào khớp", () => {
    expect(extractOrderId("TETHELLO", known)).toBeNull();
    expect(extractOrderId("", known)).toBeNull();
    expect(extractOrderId("TETTB2027-999", known)).toBeNull();
  });

  it("không bóc nhầm mã đơn khi danh sách rỗng", () => {
    expect(extractOrderId("TETTB2027-004", [])).toBeNull();
  });

  it("ưu tiên khớp chính xác thay vì khớp tiền tố", () => {
    const ids = ["TB2027-001", "TB2027-0012"];
    expect(extractOrderId("TETTB2027-0012", ids)).toBe("TB2027-0012");
  });
});

describe("buildVietQrUrl", () => {
  it("chứa đủ thông tin tài khoản, số tiền và nội dung", () => {
    const url = new URL(
      buildVietQrUrl({ amount: 650000, content: "TETTB2027-004" }),
    );

    expect(url.searchParams.get("bank")).toBe(SEPAY_BANK.bank);
    expect(url.searchParams.get("acc")).toBe(SEPAY_BANK.accountNo);
    expect(url.searchParams.get("amount")).toBe("650000");
    expect(url.searchParams.get("des")).toBe("TETTB2027-004");
    expect(url.searchParams.get("holder")).toBe(SEPAY_BANK.accountName);
  });

  it("không cho số tiền âm", () => {
    const url = new URL(
      buildVietQrUrl({ amount: -100, content: "TETTB2027-004" }),
    );
    expect(url.searchParams.get("amount")).toBe("0");
  });
});
