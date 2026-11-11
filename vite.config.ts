import { defineConfig, type Plugin, type Connect } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import basicSsl from '@vitejs/plugin-basic-ssl';
const rootDir = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.resolve(rootDir, "data");
const ORDERS_FILE = path.join(DATA_DIR, "orders.json");
const PRODUCTS_FILE = path.join(DATA_DIR, "products.json");
const MARKETS_FILE = path.join(DATA_DIR, "markets.json");
const WHOLESALE_FILE = path.join(DATA_DIR, "wholesale.json");
const PRODUCTION_FILE = path.join(DATA_DIR, "production.json");
const INVENTORY_FILE = path.join(DATA_DIR, "inventory.json");

async function readJson<T>(file: string): Promise<T> {
  const raw = await fs.readFile(file, "utf-8");
  return JSON.parse(raw) as T;
}

async function writeJson(file: string, data: unknown): Promise<void> {
  await fs.writeFile(file, JSON.stringify(data, null, 2) + "\n", "utf-8");
}

function json(res: any, status: number, body: unknown) {
  res.statusCode = status;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.end(JSON.stringify(body));
}

async function readBody(req: any): Promise<any> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) chunks.push(chunk as Buffer);
  if (!chunks.length) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf-8"));
  } catch {
    return {};
  }
}

function nextId(prefix: string, existing: string[]): string {
  const maxSeq = existing.reduce((max, id) => {
    const seq = Number(String(id).split("-")[1] ?? 0);
    return Number.isFinite(seq) && seq > max ? seq : max;
  }, 0);
  return `${prefix}-${String(maxSeq + 1).padStart(3, "0")}`;
}

/** Sinh slug id từ tên sản phẩm: "Bánh Chưng Nhân Đỗ Đỏ" -> "banh_chung_nhan_do_do" */
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

/** Mô tả từng collection được expose qua REST API */
type CollectionKey =
  | "orders"
  | "products"
  | "markets"
  | "wholesale"
  | "production"
  | "inventory";

interface CollectionSpec {
  file: string;
  /** Tiền tố id tự sinh khi POST */
  idPrefix?: string;
  /** Sinh id bằng slugify(tên) thay vì prefix + seq */
  slugFrom?: string;
  /** Collection có gộp theo ngày khi POST (production/inventory) */
  upsertByDate?: boolean;
  /** Trường ngày dùng để gộp */
  dateField?: string;
}

const COLLECTIONS: Record<CollectionKey, CollectionSpec> = {
  orders: { file: ORDERS_FILE, idPrefix: "TB2027" },
  products: { file: PRODUCTS_FILE, slugFrom: "name" },
  markets: { file: MARKETS_FILE, slugFrom: "name" },
  wholesale: { file: WHOLESALE_FILE, idPrefix: "BH" },
  production: {
    file: PRODUCTION_FILE,
    idPrefix: "SX",
    upsertByDate: true,
    dateField: "date",
  },
  inventory: {
    file: INVENTORY_FILE,
    idPrefix: "TON",
    upsertByDate: true,
    dateField: "date",
  },
};

/**
 * Dev/preview middleware exposing the JSON files as a tiny REST API.
 *
 *   GET    /api/orders      -> list          POST   /api/orders      -> create
 *   PUT    /api/orders/:id  -> update        DELETE /api/orders/:id  -> remove
 *
 *   GET    /api/products    -> list          POST   /api/products    -> create
 *   PUT    /api/products/:id-> update        DELETE /api/products/:id-> remove
 *
 *   GET    /api/markets     -> list          POST   /api/markets     -> create
 *   PUT    /api/markets/:id -> update        DELETE /api/markets/:id -> remove
 *
 *   GET    /api/wholesale   -> list          POST   /api/wholesale   -> create
 *   PUT    /api/wholesale/:id-> update       DELETE /api/wholesale/:id-> remove
 *
 *   GET    /api/production  -> list          POST   /api/production  -> upsert theo ngày
 *   GET    /api/inventory   -> list          POST   /api/inventory   -> upsert theo ngày
 */
function jsonApiPlugin(): Plugin {
  const handler: Connect.NextHandleFunction = async (req, res, next) => {
    const url = new URL(req.url ?? "/", "http://localhost");
    const method = (req.method ?? "GET").toUpperCase();

    const key = (Object.keys(COLLECTIONS) as CollectionKey[]).find((k) =>
      url.pathname.startsWith(`/api/${k}`),
    );
    if (!key) return next();

    const spec = COLLECTIONS[key];
    const collection = `/api/${key}`;
    const file = spec.file;
    const id =
      decodeURIComponent(url.pathname.replace(new RegExp(`^${collection}/?`), "")) ||
      null;

    try {
      const items = await readJson<any[]>(file);

      if (method === "GET" && !id) return json(res, 200, items);

      if (method === "POST" && !id) {
        const body = await readBody(req);

        // Gộp theo ngày: POST lần 2 cùng ngày = cập nhật bản ghi cũ
        if (spec.upsertByDate && spec.dateField) {
          const dateValue = body[spec.dateField];
          const existingIndex = items.findIndex(
            (i) => i[spec.dateField!] === dateValue,
          );
          if (existingIndex !== -1) {
            items[existingIndex] = {
              ...items[existingIndex],
              ...body,
              id: items[existingIndex].id,
              updatedAt: new Date().toISOString(),
            };
            await writeJson(file, items);
            return json(res, 200, items[existingIndex]);
          }
        }

        const baseId = spec.slugFrom
          ? slugify(String(body[spec.slugFrom] ?? "san_pham"))
          : nextId(spec.idPrefix ?? "ID", items.map((i) => i.id));

        // Đảm bảo id duy nhất
        let uniqueId = baseId;
        let suffix = 2;
        while (items.some((i) => i.id === uniqueId)) {
          uniqueId = `${baseId}_${suffix}`;
          suffix += 1;
        }

        const now = new Date().toISOString();
        const created = {
          ...body,
          id: body.id ?? uniqueId,
          ...(key === "orders"
            ? { createdAt: body.createdAt ?? now.slice(0, 10) }
            : {}),
          ...(key === "wholesale" ? { createdAt: body.createdAt ?? now } : {}),
          ...(key === "production" || key === "inventory"
            ? { updatedAt: now }
            : {}),
        };
        items.unshift(created);
        await writeJson(file, items);
        return json(res, 201, created);
      }

      if (id) {
        const index = items.findIndex((i) => i.id === id);
        if (index === -1) {
          return json(res, 404, {
            message: `Không tìm thấy ${key} #${id}`,
          });
        }

        if (method === "PUT" || method === "PATCH") {
          const body = await readBody(req);
          items[index] = { ...items[index], ...body, id };
          await writeJson(file, items);
          return json(res, 200, items[index]);
        }

        if (method === "DELETE") {
          const removed = items.splice(index, 1)[0];
          await writeJson(file, items);
          return json(res, 200, removed);
        }
      }

      return json(res, 405, { message: "Method Not Allowed" });
    } catch (error) {
      console.error("[json-api] error:", error);
      return json(res, 500, { message: "Lỗi khi truy cập file dữ liệu JSON" });
    }
  };

  return {
    name: "bakery-json-api",
    configureServer(server) {
      server.middlewares.use(handler);
    },
    configurePreviewServer(server) {
      server.middlewares.use(handler);
    },
  };
}
export default defineConfig({
  plugins: [
    react(), 
    tailwindcss(), 
    jsonApiPlugin(),
    basicSsl() // Bây giờ biến này đã được định nghĩa
  ],
  resolve: {
    alias: {
      "@": path.resolve(rootDir, "src"),
    },
  },
  server: {
    port: 5173,
  },
});
