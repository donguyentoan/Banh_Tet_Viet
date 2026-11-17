/**
 * Sinh mã viết tắt cho loại bánh - phiên bản chạy ở server.
 *
 * Đặt trong `server/` vì được dùng bởi:
 *  - API function `api/[...path].ts` (Vercel runtime)
 *  - Middleware dev/preview trong `vite.config.ts`
 *
 * Logic phải GIỐNG HỆT `src/lib/product-code.ts` (phía client) để mã sinh ở
 * server và mã hiển thị ở client luôn khớp nhau.
 *
 * File này cố tình không import zod hay bất kỳ thư viện phía client nào để
 * chạy được trong môi trường Node của Vercel.
 */

export const MAX_CODE_LENGTH = 6;

const STOP_WORDS = new Set([
  "banh",
  "nh",
  "nhan",
  "von",
  "vo",
  "mot",
  "mo",
  "da",
  "dau",
  "xanh",
  "trung",
  "thuy",
  "qua",
  "hop",
  "thoi",
]);

/**
 * Từ khoá nhân bánh -> viết tắt.
 *
 * THỨ TỰ RẤT QUAN TRỌNG - quy tắc đầu tiên khớp sẽ thắng.
 * Phải GIỐNG HỆT `src/lib/product-code.ts`.
 */
const FILLING_RULES: ReadonlyArray<readonly [RegExp, string]> = [
  [/dac\s*biet/, "ĐB"],
  [/nep\s*cam/, "MC"],
  [/chuoi/, "C"],
  [/chay/, "C"],
  [/ngot/, "N"],
  [/\bmo\b/, "M"],
  [/thit/, "T"],
  [/do\s*do/, "D"],
  [/dau/, "DX"],
  [/trung\s*mua/, "TM"],
  [/nam\s*dong\s*co/, "NĐC"],
  [/nam/, "N"],
];

const CATEGORY_PREFIX: Record<string, string> = {
  CHUNG: "C",
  TET: "T",
};

export function normalizeCodeText(text: string): string {
  return text
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "Đ")
    .toLowerCase()
    .replace(/đ/g, "d")
    .replace(/[^a-z0-9đ]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function tokenize(name: string): string[] {
  return normalizeCodeText(name)
    .split(" ")
    .filter((word) => word.length > 0 && !STOP_WORDS.has(word));
}

export function generateProductCode(
  name: string,
  category: string,
): string {
  const normalized = normalizeCodeText(name);
  const tokens = tokenize(name);

  let prefix = "";
  if (normalized.includes("chung")) prefix = "C";
  else if (normalized.includes("tet")) prefix = "T";
  else prefix = CATEGORY_PREFIX[category] ?? "C";

  let filling = "";
  for (const [pattern, code] of FILLING_RULES) {
    if (pattern.test(normalized)) {
      filling = code;
      break;
    }
  }

  const largeSuffix = normalized.includes("lon") ? "L" : "";

  if (!filling) {
    const extra = tokens.find(
      (word) =>
        !word.startsWith("banh") &&
        !["chung", "tet"].includes(word) &&
        word.length >= 2,
    );
    filling = extra ? extra.slice(0, 2) : "";
  }

  const raw = `${prefix}${filling}${largeSuffix}`.toUpperCase();
  return raw.length > MAX_CODE_LENGTH ? raw.slice(0, MAX_CODE_LENGTH) : raw;
}

export function ensureUniqueCode(code: string, taken: Set<string>): string {
  const normalized = code.replace(/\s+/g, "").toUpperCase();
  if (!normalized) return normalized;

  if (!taken.has(normalized)) {
    taken.add(normalized);
    return normalized;
  }

  const base = normalized.slice(0, MAX_CODE_LENGTH - 1);
  let suffix = 2;
  while (taken.has(`${base}${suffix}`)) {
    suffix += 1;
    if (suffix > 99) break;
  }
  const unique = `${base}${suffix}`;
  taken.add(unique);
  return unique;
}

/**
 * Sinh mã duy nhất cho một sản phẩm mới, dựa trên danh sách sản phẩm đã có.
 * - Nếu người dùng đã gửi `code` -> dùng mã đó (đảm bảo không trùng).
 * - Nếu không -> tự sinh từ tên.
 *
 * @param name      tên loại bánh
 * @param category  nhóm bánh ("CHUNG" | "TET")
 * @param explicitCode mã do người dùng nhập (có thể rỗng)
 * @param existing  danh sách sản phẩm hiện có (để tránh trùng mã)
 */
export function resolveNewProductCode(
  name: string,
  category: string,
  explicitCode: string | undefined,
  existing: Array<{ code?: string }>,
): string | undefined {
  const taken = new Set<string>();
  for (const product of existing) {
    const code = product.code?.trim();
    if (!code) continue;
    taken.add(code.replace(/\s+/g, "").toUpperCase());
  }

  const explicit = explicitCode?.trim();
  if (explicit) {
    return ensureUniqueCode(explicit, taken);
  }

  const generated = generateProductCode(name, category);
  if (!generated) return undefined;
  return ensureUniqueCode(generated, taken);
}
