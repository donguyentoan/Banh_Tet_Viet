import {
  DEFAULT_DELIVERY_DATE,
  DEFAULT_DELIVERY_TIME,
  DELIVERY_DATE_SUGGESTIONS,
  type Product,
} from "@/lib/types";

export interface ParsedOrder {
  customerName: string;
  phone?: string;
  address?: string;
  deliveryDate: string;
  deliveryTime: string;
  /** Số lượng theo productId */
  quantities: Record<string, number>;
  /** Danh sách mã bánh không nhận ra trong tin nhắn */
  unknownCodes: string[];
  /** Tất cả các token đã dùng, để highlight trong UI */
  matchedCodes: string[];
}

/** Chuẩn hoá chuỗi: bỏ dấu, lowercase, gộp khoảng trắng */
export function normalizeText(text: string): string {
  return text
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLowerCase()
    .trim();
}

/** Chuẩn hoá mã bánh: bỏ dấu, uppercase, gộp khoảng trắng */
export function normalizeCode(code: string): string {
  return normalizeText(code).replace(/\s+/g, "");
}

/**
 * Tạo bảng tra mã bánh từ danh mục sản phẩm.
 * - Ưu tiên `product.code` nếu có.
 * - Nếu không có, suy ra từ tên (VD: "Bánh Chưng Thịt" -> "CM").
 */
export function buildCodeIndex(products: Product[]): Map<string, Product> {
  const index = new Map<string, Product>();

  for (const product of products) {
    if (product.code) {
      index.set(normalizeCode(product.code), product);
    }
  }

  for (const product of products) {
    const name = normalizeText(product.name);
    const candidates: string[] = [];

    if (name.includes("chung")) {
      if (name.includes("dac") && name.includes("biet")) candidates.push("cdb");
      else if (name.includes("chay")) candidates.push("cc");
      else candidates.push("cm");
    }

    if (name.includes("tet")) {
      if (name.includes("nep") && name.includes("cam")) candidates.push("tmc");
      else if (name.includes("chuoi")) candidates.push("tc");
      else candidates.push("tt");
    }

    for (const code of candidates) {
      if (!index.has(code)) index.set(code, product);
    }
  }

  return index;
}

/**
 * Chuẩn hoá ngày giao từ nhiều định dạng:
 *   03/02/2027 | 03-02-2027 | 3.2.2027 | 3/2 | 27 Tết | 27Tết
 * Trả về ISO (YYYY-MM-DD) hoặc null.
 */
export function parseDeliveryDate(input: string): string | null {
  const text = input.trim();
  if (!text) return null;

  // 26-29 Tết (theo dương lịch 2027)
  const lunarMatch = text.match(/(2[6-9])\s*t[eế]t/i);
  if (lunarMatch) {
    const lunarDay = Number(lunarMatch[1]);
    const found = DELIVERY_DATE_SUGGESTIONS.find((d) =>
      d.short.startsWith(`${lunarDay} Tết`),
    );
    if (found) return found.value;
  }

  // Dạng 03/02/2027 hoặc 03/02
  const slashMatch = text.match(
    /(\d{1,2})[/.-](\d{1,2})(?:[/.-](\d{2,4}))?/,
  );
  if (slashMatch) {
    const day = Number(slashMatch[1]);
    const month = Number(slashMatch[2]);
    let year = slashMatch[3] ? Number(slashMatch[3]) : 2027;
    if (year < 100) year += 2000;
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
    }
  }

  return null;
}

/** Chuẩn hoá khung giờ giao từ text tự do: "8 giờ sáng", "chiều", "tối" */
export function parseDeliveryTime(input: string): string | null {
  const text = normalizeText(input);

  const hourMatch = text.match(/(\d{1,2})\s*(?:h|gio|:\s*\d{2})?/);
  const periodMatch = text.match(/(sang|chieu|toi|trua|dem)/);

  if (hourMatch && periodMatch) {
    let hour = Number(hourMatch[1]);
    if (hour > 12 && hour <= 23) hour -= 12;
    if (hour >= 1 && hour <= 12) {
      const period = periodMatch[1];
      if (period === "sang") {
        return `Sáng (${String(hour).padStart(2, "0")}:00 - 11:00)`;
      }
      if (period === "chieu") {
        return `Chiều (13:00 - ${String(hour + 4).padStart(2, "0")}:00)`;
      }
      if (period === "toi") {
        return `Tối (${String(hour + 12).padStart(2, "0")}:00 - 21:00)`;
      }
      if (period === "trua") {
        return "Buổi trưa (11:00 - 13:00)";
      }
      if (period === "dem") {
        return "Buổi tối (21:00 - 23:00)";
      }
    }
  }

  if (periodMatch) {
    const period = periodMatch[1];
    if (period === "sang") return "Sáng (07:00 - 11:00)";
    if (period === "chieu") return "Chiều (13:00 - 17:00)";
    if (period === "toi") return "Tối (18:00 - 21:00)";
    if (period === "trua") return "Buổi trưa (11:00 - 13:00)";
    if (period === "dem") return "Buổi tối (21:00 - 23:00)";
  }

  return null;
}

/** Tìm số điện thoại trong text (10-11 số, bắt đầu bằng 0 hoặc +84) */
export function parsePhone(input: string): string | undefined {
  const match = input.match(/(?:\+84|0)\d{9,10}/);
  return match ? match[0] : undefined;
}

/** Tìm địa chỉ trong text (sau các từ khoá chỉ bố trí) */
function parseAddress(input: string): string | undefined {
  const match = input.match(
    /(?:địa chỉ|dc|ở|o tại|gia\s*:\s*|tại)\s*[:-]?\s*(.+)$/i,
  );
  if (match) {
    const value = match[1].trim();
    if (value) return value;
  }
  return undefined;
}

/** Escape regex special chars */
function escapeRegex(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Chuyển mã chuẩn hoá thành pattern regex.
 * Mã "cdb" -> "c[dđ]b" để khớp được cả ký tự "Đ" có dấu.
 */
function codeToPattern(code: string): string {
  return escapeRegex(code)
    .replace(/d/g, "[dđ]")
    .replace(/D/g, "[DĐ]");
}

/** Từ bỏ nhiễu trong tin nhắn, không phải tên khách */
const NOISE_WORDS = [
  "ngay",
  "giao",
  "luc",
  "nhe",
  "nho",
  "cam on",
  "chao",
  "ban",
  "minh",
  "vs",
  "va",
  "cho",
  "them",
  "a",
  "bán",
  "đặt",
  "đơn",
];

/** Cách gọi tự nhiên thường dùng khi đọc đơn bằng giọng nói. */
function getVoiceProductAliases(product: Product): string[] {
  const name = normalizeText(product.name);
  if (product.category === "CHUNG") {
    if (name.includes("dac biet")) {
      return ["bánh chưng đặc biệt", "chưng đặc biệt", "đặc biệt"];
    }
    if (name.includes("chay")) {
      return ["bánh chưng chay", "chưng chay"];
    }
    return ["bánh chưng mặn", "chưng mặn", "bánh chưng thịt", "chưng thịt"];
  }

  if (name.includes("chuoi")) return ["bánh tét chuối", "tét chuối"];
  if (name.includes("nep cam")) {
    return ["bánh tét nếp cẩm", "tét nếp cẩm", "nếp cẩm"];
  }
  return ["bánh tét thịt", "tét thịt"];
}

const SPOKEN_NUMBERS: Record<string, number> = {
  mot: 1,
  hai: 2,
  ba: 3,
  bon: 4,
  tu: 4,
  nam: 5,
  sau: 6,
  bay: 7,
  tam: 8,
  chin: 9,
  muoi: 10,
};

function parseSpokenNumber(value: string): number {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : (SPOKEN_NUMBERS[normalizeText(value)] ?? 0);
}

/**
 * Phân tích tin nhắn đặt bánh theo cú pháp tự do.
 *
 * Ví dụ:
 *   "bà mi / 03/02/2027 / 2 CM / 1 CC / 8 giờ sáng"
 *   "anh Tuấn 0908123457 ngày 27 tết 3cm 2tmc chiều"
 */
export function parseQuickOrder(
  rawText: string,
  products: Product[],
): ParsedOrder {
  const text = rawText.trim();
  const codeIndex = buildCodeIndex(products);

  const quantities: Record<string, number> = {};
  const unknownCodes: string[] = [];
  const matchedCodes: string[] = [];

  // 1) Tìm các cặp "<số lượng> <mã bánh>" dùng mã đã biết trong danh mục.
  //    Dùng alternation từ danh mục để không bắt nhầm từ tiếng Việt.
  const knownCodes = [...codeIndex.keys()].sort(
    (a, b) => b.length - a.length,
  );

  if (knownCodes.length > 0) {
    const alternation = knownCodes.map(codeToPattern).join("|");
    const pairPattern = new RegExp(
      `(\\d{1,4})\\s*(${alternation})\\b|\\b(${alternation})\\s*(\\d{1,4})\\b`,
      "gi",
    );

    let match: RegExpExecArray | null;
    while ((match = pairPattern.exec(text)) !== null) {
      const rawCode = (match[2] ?? match[3] ?? "").trim();
      const rawQty = match[1] ?? match[4] ?? "";
      const quantity = Number(rawQty);
      if (!rawCode || !Number.isFinite(quantity) || quantity <= 0) continue;

      const code = normalizeCode(rawCode);
      const product = codeIndex.get(code);
      if (!product) continue;

      quantities[product.id] = (quantities[product.id] ?? 0) + quantity;
      const label = product.code ?? code;
      if (!matchedCodes.includes(label)) matchedCodes.push(label);
    }
  }

  // Nhận câu nói tự nhiên như “5 bánh chưng mặn”, ngoài cú pháp mã CM/CC.
  const normalizedText = normalizeText(text);
  const spokenQty = "(\\d{1,3}|mot|hai|ba|bon|tu|nam|sau|bay|tam|chin|muoi)";
  for (const product of products) {
    const aliases = getVoiceProductAliases(product)
      .map(normalizeText)
      .sort((a, b) => b.length - a.length);
    const aliasPattern = aliases.map(escapeRegex).join("|");
    const spokenPattern = new RegExp(
      `\\b${spokenQty}\\s*(?:(?:cai|chiec)\\s+)?(?:${aliasPattern})\\b|\\b(?:${aliasPattern})\\s+${spokenQty}\\b`,
      "g",
    );
    let spokenMatch: RegExpExecArray | null;
    while ((spokenMatch = spokenPattern.exec(normalizedText)) !== null) {
      const quantity = parseSpokenNumber(spokenMatch[1] ?? spokenMatch[2] ?? "");
      if (quantity <= 0) continue;
      // Nếu người dùng vừa nói mã vừa nói tên, tránh cộng trùng cùng một loại.
      if (!quantities[product.id]) quantities[product.id] = quantity;
      const label = product.code ?? product.id;
      if (!matchedCodes.includes(label)) matchedCodes.push(label);
    }
  }

  // 2) Tìm mã lạ: chữ in hoa 2-4 ký tự đứng cạnh số lượng (VD: "2 XY")
  const unknownPattern = /(\d{1,4})\s+([A-ZĐ]{2,4})\b|\b([A-ZĐ]{2,4})\s+(\d{1,4})\b/g;
  let unknownMatch: RegExpExecArray | null;
  while ((unknownMatch = unknownPattern.exec(text)) !== null) {
    const rawCode = (unknownMatch[2] ?? unknownMatch[3] ?? "").trim();
    if (!rawCode) continue;

    const code = normalizeCode(rawCode);
    if (codeIndex.has(code)) continue;
    if (!unknownCodes.includes(rawCode)) unknownCodes.push(rawCode);
  }

  // 3) Ngày giao: ưu tiên dạng ngày/tháng, sau đó tới "27 tết"
  let deliveryDate = DEFAULT_DELIVERY_DATE;
  const dateMatch =
    text.match(/\d{1,2}[/.-]\d{1,2}(?:[/.-]\d{2,4})?/) ??
    text.match(/\b(2[6-9])\s*t[eế]t/i);
  if (dateMatch) {
    const parsed = parseDeliveryDate(dateMatch[0]);
    if (parsed) deliveryDate = parsed;
  }

  // 4) Khung giờ
  let deliveryTime = DEFAULT_DELIVERY_TIME;
  const timeMatch = text.match(
    /\d{1,2}\s*(?:h|gi[oờ])\s*(?:s[aá]ng|chi[eề]u|t[oố]i|tr[uư]a|đ[eê]m)?|\b(s[aá]ng|chi[eề]u|t[oố]i|tr[uư]a|đ[eê]m)\b/i,
  );
  if (timeMatch) {
    const parsed = parseDeliveryTime(timeMatch[0]);
    if (parsed) deliveryTime = parsed;
  }

  // 5) SĐT
  const phone = parsePhone(text);

  // 6) Địa chỉ
  const address = parseAddress(text);

  // 7) Tên khách: loại bỏ mã bánh, số lượng, ngày, giờ, SĐT, từ bỏ nhiễu
  let nameText = text;

  if (knownCodes.length > 0) {
    const alternation = knownCodes.map(codeToPattern).join("|");
    nameText = nameText.replace(
      new RegExp(`\\b\\d{1,4}\\s*(?:${alternation})\\b`, "gi"),
      " ",
    );
    nameText = nameText.replace(
      new RegExp(`\\b(?:${alternation})\\s*\\d{1,4}\\b`, "gi"),
      " ",
    );
  }

  // Xoá cụm số lượng + tên bánh tự nhiên khỏi phần tên khách.
  for (const product of products) {
    const aliases = getVoiceProductAliases(product).sort((a, b) => b.length - a.length);
    const aliasPattern = aliases.map(escapeRegex).join("|");
    const spokenNamePattern = new RegExp(
      `(?:\\b\\d{1,3}|\\b(?:một|môt|hai|ba|bốn|tư|năm|sáu|bảy|tám|chín|mười))\\s*(?:(?:cái|chiếc)\\s+)?(?:${aliasPattern})\\b|\\b(?:${aliasPattern})\\s+(?:\\d{1,3}|một|hai|ba|bốn|tư|năm|sáu|bảy|tám|chín|mười)\\b`,
      "gi",
    );
    nameText = nameText.replace(spokenNamePattern, " ");
  }

  nameText = nameText
    .replace(/(\+84|0)\d{9,10}/g, " ")
    .replace(/\d{1,2}[/.-]\d{1,2}(?:[/.-]\d{2,4})?/g, " ")
    .replace(/\b(2[6-9])\s*t[eế]t\b/gi, " ")
    .replace(
      /\d{1,2}\s*(?:h|gi[oờ])\s*(?:s[aá]ng|chi[eề]u|t[oố]i|tr[uư]a|đ[eê]m)?/gi,
      " ",
    )
    .replace(/\b(s[aá]ng|chi[eề]u|t[oố]i|tr[uư]a|đ[eê]m)\b/gi, " ")
    .replace(/\b(địa chỉ|dc|ở|o tại|gia)\b\s*[:-]?\s*/gi, " ")
    .replace(/[/|,]/g, " ");

  for (const word of NOISE_WORDS) {
    nameText = nameText.replace(new RegExp(`\\b${escapeRegex(word)}\\b`, "gi"), " ");
  }

  const customerName = nameText
    .split(/\s{2,}|-{2,}|—/)
    .map((part) => part.replace(/\s+/g, " ").trim())
    .filter((part) => part.length >= 2)
    .sort((a, b) => b.length - a.length)[0];

  return {
    customerName: customerName ?? "",
    phone,
    address,
    deliveryDate,
    deliveryTime,
    quantities,
    unknownCodes,
    matchedCodes,
  };
}
