import { describe, expect, it, beforeEach, afterEach } from "vitest";
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
);
const DATA_DIR = path.join(rootDir, "data");
const ORDERS_FILE = path.join(DATA_DIR, "orders.json");
const PRODUCTS_FILE = path.join(DATA_DIR, "products.json");

async function readJson<T>(file: string): Promise<T> {
  return JSON.parse(await readFile(file, "utf-8")) as T;
}

async function writeJson(file: string, data: unknown): Promise<void> {
  await writeFile(file, JSON.stringify(data, null, 2) + "\n", "utf-8");
}

/** Mô phỏng đúng logic của Vite plugin khi POST /api/products */
function slugify(name: string): string {
  const slug = name
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
  return slug || "san_pham";
}

describe("JSON file storage", () => {
  let originalProducts: any[] = [];

  beforeEach(async () => {
    originalProducts = await readJson<any[]>(PRODUCTS_FILE);
  });

  afterEach(async () => {
    // Khôi phục file gốc để test không làm bẩn dữ liệu
    await writeJson(PRODUCTS_FILE, originalProducts);
  });

  it("orders.json tồn tại và là mảng hợp lệ", async () => {
    const orders = await readJson<any[]>(ORDERS_FILE);
    expect(Array.isArray(orders)).toBe(true);
    expect(orders.length).toBeGreaterThan(0);
    expect(orders[0]).toHaveProperty("id");
    expect(orders[0]).toHaveProperty("items");
    expect(orders[0]).toHaveProperty("totalAmount");
  });

  it("products.json tồn tại và là mảng hợp lệ", async () => {
    const products = await readJson<any[]>(PRODUCTS_FILE);
    expect(Array.isArray(products)).toBe(true);
    expect(products.length).toBeGreaterThan(0);
    for (const product of products) {
      expect(product).toHaveProperty("id");
      expect(product).toHaveProperty("name");
      expect(product).toHaveProperty("price");
      expect(product).toHaveProperty("category");
    }
  });

  it("loại bánh mới được ghi xuống products.json và đọc lại được", async () => {
    const products = await readJson<any[]>(PRODUCTS_FILE);
    const before = products.length;

    const newProduct = {
      id: slugify("Bánh Chưng Nhân Đỗ Đỏ"),
      name: "Bánh Chưng Nhân Đỗ Đỏ",
      price: 165000,
      category: "CHUNG",
      icon: "🫘",
      weight: "1.3 kg",
    };

    products.unshift(newProduct);
    await writeJson(PRODUCTS_FILE, products);

    // Đọc lại từ đĩa
    const reloaded = await readJson<any[]>(PRODUCTS_FILE);
    expect(reloaded).toHaveLength(before + 1);
    expect(reloaded[0]).toMatchObject({
      id: "banh_chung_nhan_do_do",
      name: "Bánh Chưng Nhân Đỗ Đỏ",
      price: 165000,
      category: "CHUNG",
    });
  });

  it("slugify tạo id duy nhất và ổn định", () => {
    expect(slugify("Bánh Chưng Nhân Đỗ Đỏ")).toBe("banh_chung_nhan_do_do");
    expect(slugify("Bánh Tét Nếp Cẩm")).toBe("banh_tet_nep_cam");
    expect(slugify("  !!!  ")).toBe("san_pham");
  });
});
