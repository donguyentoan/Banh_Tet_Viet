/**
 * Sinh mã viết tắt (short code) cho loại bánh — dùng để gõ nhanh trong
 * tin nhắn đặt hàng và in trên phiếu nhiệt.
 *
 * Mục tiêu: người quản lý thêm loại bánh mới vào `products.json` (hoặc qua
 * form "Thêm loại bánh") thì hệ thống tự sinh mã và hiển thị đúng, KHÔNG
 * cần sửa code thủ công.
 *
 * Quy tắc sinh mã:
 *   "Bánh Chưng Thịt Mỡ Đậu Xanh"       -> CM
 *   "Bánh Chưng Chay Đậu Xanh"          -> CC
 *   "Bánh Chưng Thịt Mỡ Đậu Xanh (Lớn)" -> CML
 *   "Bánh Tét Nhân Ngọt"                -> TN
 *   "Bánh Tét Nếp Cẩm"                  -> TMC
 *   "Bánh Chưng Nhân Đỗ Đỏ"            -> CDD
 *
 * Cấu trúc mã: <viết tắt loại bánh> + <viết tắt nhân> + [L nếu "lớn"]
 */

import type { Product, ProductCategory } from "@/lib/types";

/** Số ký tự tối đa cho một mã bánh (khớp `productFormSchema`). */
export const MAX_CODE_LENGTH = 6;

/** Từ bỏ qua khi sinh viết tắt (không mang thông tin phân biệt). */
const STOP_WORDS = new Set([
  "banh",
  "nh",
  "nhan",
  "von",
  "vo",
  "mot",
  "mo",
  "vo",
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
 * THỨ TỰ RẤT QUAN TRỌNG - quy tắc đầu tiên khớp sẽ thắng:
 *   - "Bánh Chưng Đặc Biệt Trứng Muối" -> "Đặc Biệt" phải thắng "Trứng Muối"
 *     => CĐB (không phải CTM)
 *   - "Bánh Tét Nhân Chuối Ngọt" -> "Chuối" phải thắng "Ngọt" => TC
 *   - "Bánh Tét Nếp Cẩm" -> "Nếp Cẩm" thắng "Cẩm" => TMC
 *
 * Mỗi mục là [mẫu khớp trong tên đã bỏ dấu, viết tắt].
 */
const FILLING_RULES: ReadonlyArray<readonly [RegExp, string]> = [
  // Nhân đặc biệt - ưu tiên cao nhất
  [/dac\s*biet/, "ĐB"],
  // Nếp cẩm (Bánh Tét Nếp Cẩm)
  [/nep\s*cam/, "MC"],
  // Chuối (trước "Ngọt" vì "Bánh Tét Nhân Chuối Ngọt" là chuối)
  [/chuoi/, "C"],
  // Chay
  [/chay/, "C"],
  // Nhân ngọt
  [/ngot/, "N"],
  // Mỡ (nhân mặn) - "Bánh Chưng Thịt Mỡ" -> CM
  [/\bmo\b/, "M"],
  // Thịt
  [/thit/, "T"],
  // Đỗ đỏ
  [/do\s*do/, "D"],
  // Đậu xanh
  [/dau/, "DX"],
  // Trứng muối
  [/trung\s*mua/, "TM"],
  // Nấm đông cô
  [/nam\s*dong\s*co/, "NĐC"],
  // Nấm
  [/nam/, "N"],
];

/** Viết tắt mặc định theo nhóm bánh. */
const CATEGORY_PREFIX: Record<ProductCategory, string> = {
  CHUNG: "C",
  TET: "T",
};

/**
 * Chuẩn hoá chuỗi: bỏ dấu (trừ chữ "Đ"), lowercase, gộp khoảng trắng.
 *
 * Giữ lại chữ "Đ" vì mã "CĐB" (Bánh Chưng Đặc Biệt) đọc tự nhiên hơn "CDB",
 * và "Đ" là ký tự mà người dùng cũng dễ gõ trong tin nhắn.
 *
 * Dùng chung quy ước với `quick-parse.ts` để mã sinh ra luôn khớp khi gõ.
 */
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
/** Tách tên bánh thành các từ đã chuẩn hoá (bỏ dấu, lowercase). */
function tokenize(name: string): string[] {
  return normalizeCodeText(name)
    .split(" ")
    .filter((word) => word.length > 0 && !STOP_WORDS.has(word));
}

/**
 * Sinh mã viết tắt từ tên + category của sản phẩm.
 *
 * @param name   tên loại bánh (VD: "Bánh Chưng Thịt Mỡ Đậu Xanh")
 * @param category nhóm bánh, dùng làm tiền tố khi tên không chứa từ khoá rõ ràng
 * @returns mã viết tắt, có thể rỗng nếu không suy ra được
 */
export function generateProductCode(
  name: string,
  category: ProductCategory,
): string {
  const normalized = normalizeCodeText(name);
  const tokens = tokenize(name);

  // 1. Tiền tố: ưu tiên từ trong tên ("chưng" -> C, "tét" -> T),
  //    nếu tên không nói rõ thì lấy theo category.
  let prefix = "";
  if (normalized.includes("chung")) prefix = "C";
  else if (normalized.includes("tet")) prefix = "T";
  else prefix = CATEGORY_PREFIX[category] ?? "C";

  // 2. Viết tắt nhân: quét các quy tắc, lấy mã đầu tiên khớp.
  let filling = "";
  for (const [pattern, code] of FILLING_RULES) {
    if (pattern.test(normalized)) {
      filling = code;
      break;
    }
  }

  // 3. Hậu tố "L" cho bản "Lớn".
  const isLarge = normalized.includes("lon");
  const largeSuffix = isLarge ? "L" : "";

  // 4. Nếu không suy ra được nhân, ghép từ khoá đầu tiên còn lại trong tên.
  if (!filling) {
    const extra = tokens.find(
      (word) =>
        !word.startsWith("banh") &&
        !["chung", "tet"].includes(word) &&
        word.length >= 2,
    );
    filling = extra ? extra.slice(0, 2) : "";
  }

  // 5. Viết hoa. Chữ "Đ" được giữ nguyên (CĐB) vì `toUpperCase()` tự
  //    chuyển "đ" -> "Đ".
  const raw = `${prefix}${filling}${largeSuffix}`.toUpperCase();

  // 6. Giới hạn độ dài, luôn giữ lại hậu tố "L" nếu có.
  if (raw.length > MAX_CODE_LENGTH) {
    return raw.slice(0, MAX_CODE_LENGTH);
  }

  return raw;
}

/**
 * Sinh mã cho sản phẩm, ưu tiên `code` do người dùng đặt.
 * Trả về `null` nếu không sinh được mã nào hợp lệ.
 */
export function resolveProductCode(
  product: Pick<Product, "name" | "category" | "code">,
): string | null {
  const explicit = product.code?.trim();
  if (explicit) return explicit;
  const generated = generateProductCode(product.name, product.category);
  return generated || null;
}

/**
 * Đảm bảo mã là duy nhất trong danh mục.
 *
 * - Mã trùng sẽ được thêm hậu tố số: `CM` -> `CM2`, `CM3`, ...
 * - `taken` là tập mã đã dùng (đã chuẩn hoá lowercase, bỏ khoảng trắng).
 *
 * @param code     mã cần kiểm tra
 * @param taken    tập mã đang được dùng (sẽ được cập nhật tại chỗ)
 * @returns mã duy nhất
 */
export function ensureUniqueCode(
  code: string,
  taken: Set<string>,
): string {
  const normalized = code.replace(/\s+/g, "").toUpperCase();
  if (!normalized) return normalized;

  if (!taken.has(normalized)) {
    taken.add(normalized);
    return normalized;
  }

  // Thử hậu tố số tăng dần: CM -> CM2 -> CM3 ...
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
 * Gán mã cho toàn bộ danh mục, đảm bảo:
 * - Sản phẩm đã có `code` giữ nguyên mã đó.
 * - Sản phẩm chưa có `code` được sinh mã tự động, không trùng mã của ai.
 *
 * @returns Map<productId, mã> (mã đã được chuẩn hoá uppercase, bỏ khoảng trắng)
 */
export function assignProductCodes(
  products: Array<Pick<Product, "id" | "name" | "category" | "code">>,
): Map<string, string> {
  const result = new Map<string, string>();
  const taken = new Set<string>();

  // Vòng 1: ưu tiên mã được đặt tay — giữ nguyên để không đổi mã cũ.
  for (const product of products) {
    const explicit = product.code?.trim();
    if (!explicit) continue;
    const normalized = explicit.replace(/\s+/g, "").toUpperCase();
    if (taken.has(normalized)) continue; // bỏ qua mã trùng, sẽ xử lý ở vòng 2
    taken.add(normalized);
    result.set(product.id, normalized);
  }

  // Vòng 2: sinh mã cho sản phẩm còn thiếu mã.
  for (const product of products) {
    if (result.has(product.id)) continue;
    const generated = generateProductCode(product.name, product.category);
    if (!generated) continue;
    const unique = ensureUniqueCode(generated, taken);
    result.set(product.id, unique);
  }

  return result;
}

/**
 * Sinh mã gợi ý cho form "Thêm loại bánh", dựa trên các sản phẩm đã có.
 * Nếu mã vừa sinh bị trùng, tự thêm hậu tố số.
 */
export function suggestProductCode(
  name: string,
  category: ProductCategory,
  existingProducts: Array<Pick<Product, "name" | "category" | "code">>,
): string {
  const taken = new Set<string>();
  for (const product of existingProducts) {
    const code = resolveProductCode(product);
    if (code) taken.add(code.replace(/\s+/g, "").toUpperCase());
  }
  const generated = generateProductCode(name, category);
  if (!generated) return "";
  return ensureUniqueCode(generated, taken);
}
