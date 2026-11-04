import { defineConfig, type Plugin, type Connect } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.resolve(rootDir, "data");
const ORDERS_FILE = path.join(DATA_DIR, "orders.json");
const PRODUCTS_FILE = path.join(DATA_DIR, "products.json");

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

/**
 * Dev/preview middleware exposing the JSON files as a tiny REST API.
 *
 *   GET    /api/orders      -> list          POST   /api/orders      -> create
 *   PUT    /api/orders/:id  -> update        DELETE /api/orders/:id  -> remove
 *
 *   GET    /api/products    -> list          POST   /api/products    -> create
 *   PUT    /api/products/:id-> update        DELETE /api/products/:id-> remove
 */
function jsonApiPlugin(): Plugin {
  const handler: Connect.NextHandleFunction = async (req, res, next) => {
    const url = new URL(req.url ?? "/", "http://localhost");
    const method = (req.method ?? "GET").toUpperCase();

    const isOrders = url.pathname.startsWith("/api/orders");
    const isProducts = url.pathname.startsWith("/api/products");
    if (!isOrders && !isProducts) return next();

    const collection = isOrders ? "/api/orders" : "/api/products";
    const file = isOrders ? ORDERS_FILE : PRODUCTS_FILE;
    const idPrefix = isOrders ? "TB2026" : "SP";
    const id =
      decodeURIComponent(url.pathname.replace(new RegExp(`^${collection}/?`), "")) ||
      null;

    try {
      const items = await readJson<any[]>(file);

      if (method === "GET" && !id) return json(res, 200, items);

      if (method === "POST" && !id) {
        const body = await readBody(req);
        const baseId = isOrders
          ? nextId(idPrefix, items.map((i) => i.id))
          : slugify(String(body.name ?? "san_pham"));
        // Đảm bảo id duy nhất
        let uniqueId = baseId;
        let suffix = 2;
        while (items.some((i) => i.id === uniqueId)) {
          uniqueId = `${baseId}_${suffix}`;
          suffix += 1;
        }
        const created = {
          ...body,
          id: body.id ?? uniqueId,
          ...(isOrders
            ? { createdAt: body.createdAt ?? new Date().toISOString().slice(0, 10) }
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
            message: `Không tìm thấy ${isOrders ? "đơn" : "sản phẩm"} #${id}`,
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
  plugins: [react(), tailwindcss(), jsonApiPlugin()],
  resolve: {
    alias: {
      "@": path.resolve(rootDir, "src"),
    },
  },
  server: {
    port: 5173,
  },
});
