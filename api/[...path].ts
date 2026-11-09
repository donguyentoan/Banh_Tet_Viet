import { get, put } from "@vercel/blob";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import {
  handleAdminAuth,
  hasAdminSession,
  readBody,
  type ApiRequest,
  type ApiResponse,
} from "../server/admin-auth.js";

interface CollectionRequest extends ApiRequest {
  url?: string;
  query?: { path?: string | string[] };
}

type CollectionKey =
  | "orders"
  | "products"
  | "markets"
  | "wholesale"
  | "production"
  | "inventory";

interface CollectionSpec {
  idPrefix?: string;
  slugFrom?: string;
  upsertByDate?: boolean;
  dateField?: string;
}

interface CollectionData {
  items: Record<string, any>[];
  etag?: string;
}

const COLLECTIONS: Record<CollectionKey, CollectionSpec> = {
  orders: { idPrefix: "TB2027" },
  products: { slugFrom: "name" },
  markets: { slugFrom: "name" },
  wholesale: { idPrefix: "BH" },
  production: { idPrefix: "SX", upsertByDate: true, dateField: "date" },
  inventory: { idPrefix: "TON", upsertByDate: true, dateField: "date" },
};

const BLOB_ACCESS = "private" as const;

function json(res: ApiResponse, status: number, body: unknown) {
  return res.status(status).json(body);
}

function getBlobConfiguration() {
  const hasStaticToken = Boolean(process.env.BLOB_READ_WRITE_TOKEN);
  const hasOidc = Boolean(process.env.BLOB_STORE_ID && process.env.VERCEL_OIDC_TOKEN);
  return hasStaticToken || hasOidc;
}

async function readSeedFile(collection: CollectionKey) {
  const file = join(process.cwd(), "data", `${collection}.json`);
  return JSON.parse(await readFile(file, "utf8")) as Record<string, any>[];
}

async function readCollection(collection: CollectionKey): Promise<CollectionData> {
  if (getBlobConfiguration()) {
    const stored = await get(`collections/${collection}.json`, {
      access: BLOB_ACCESS,
      useCache: false,
    });
    if (stored?.statusCode === 200 && stored.stream) {
      return {
        items: (await new Response(stored.stream).json()) as Record<string, any>[],
        etag: stored.blob.etag,
      };
    }
  }
  return { items: await readSeedFile(collection) };
}

async function writeCollection(
  collection: CollectionKey,
  items: Record<string, any>[],
  etag?: string,
) {
  if (!getBlobConfiguration()) {
    throw new Error("Blob chưa được kết nối với project Vercel.");
  }
  await put(`collections/${collection}.json`, JSON.stringify(items, null, 2), {
    access: BLOB_ACCESS,
    addRandomSuffix: false,
    allowOverwrite: true,
    contentType: "application/json; charset=utf-8",
    cacheControlMaxAge: 60,
    ...(etag ? { ifMatch: etag } : {}),
  });
}

function nextId(prefix: string, existing: string[]): string {
  const maxSeq = existing.reduce((max, id) => {
    const seq = Number(String(id).split("-")[1] ?? 0);
    return Number.isFinite(seq) && seq > max ? seq : max;
  }, 0);
  return `${prefix}-${String(maxSeq + 1).padStart(3, "0")}`;
}

function slugify(name: string): string {
  return (
    name
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/đ/g, "d")
      .replace(/Đ/g, "D")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "") || "san_pham"
  );
}

function collectionPath(req: CollectionRequest): string[] {
  if (Array.isArray(req.query?.path)) return req.query.path.map(decodeURIComponent);
  if (req.query?.path) return req.query.path.split("/").map(decodeURIComponent);
  const pathname = new URL(req.url ?? "/", "http://localhost").pathname;
  return pathname.replace(/^\/api\/?/, "").split("/").filter(Boolean).map(decodeURIComponent);
}

export default async function handler(req: CollectionRequest, res: ApiResponse) {
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("Content-Type", "application/json; charset=utf-8");

  const path = collectionPath(req);
  if (path[0] === "auth") {
    try {
      return await handleAdminAuth(req, res, (path[1] ?? "") as "session" | "login" | "logout");
    } catch (error) {
      console.error("[api/auth] Request failed:", error);
      return json(res, 400, { message: "Yêu cầu xác thực không hợp lệ." });
    }
  }

  const [rawCollection, id] = path;
  const collection = rawCollection as CollectionKey;
  const spec = COLLECTIONS[collection];
  if (!spec || path.length > 2) return json(res, 404, { message: "Không tìm thấy API" });

  const method = (req.method ?? "GET").toUpperCase();
  const isWrite = method !== "GET";
  if (isWrite && !hasAdminSession(req)) {
    return json(res, 401, { message: "Đăng nhập quản trị để thay đổi dữ liệu." });
  }

  try {
    const { items, etag } = await readCollection(collection);
    if (method === "GET") {
      if (!id) return json(res, 200, items);
      const item = items.find((entry) => entry.id === id);
      return item
        ? json(res, 200, item)
        : json(res, 404, { message: `Không tìm thấy ${collection} #${id}` });
    }

    if (method === "POST" && !id) {
      const body = await readBody(req);
      if (spec.upsertByDate && spec.dateField) {
        const index = items.findIndex((item) => item[spec.dateField!] === body[spec.dateField!]);
        if (index !== -1) {
          const updated = {
            ...items[index],
            ...body,
            id: items[index].id,
            updatedAt: new Date().toISOString(),
          };
          items[index] = updated;
          await writeCollection(collection, items, etag);
          return json(res, 200, updated);
        }
      }

      const baseId = spec.slugFrom
        ? slugify(String(body[spec.slugFrom] ?? "san_pham"))
        : nextId(spec.idPrefix ?? "ID", items.map((item) => item.id));
      let uniqueId = baseId;
      let suffix = 2;
      while (items.some((item) => item.id === uniqueId)) uniqueId = `${baseId}_${suffix++}`;
      const now = new Date().toISOString();
      const created = {
        ...body,
        id: body.id ?? uniqueId,
        ...(collection === "orders" ? { createdAt: body.createdAt ?? now.slice(0, 10) } : {}),
        ...(collection === "wholesale" ? { createdAt: body.createdAt ?? now } : {}),
        ...(collection === "production" || collection === "inventory" ? { updatedAt: now } : {}),
      };
      items.unshift(created);
      await writeCollection(collection, items, etag);
      return json(res, 201, created);
    }

    if (id) {
      const index = items.findIndex((item) => item.id === id);
      if (index === -1) return json(res, 404, { message: `Không tìm thấy ${collection} #${id}` });
      if (method === "PUT" || method === "PATCH") {
        const body = await readBody(req);
        items[index] = { ...items[index], ...body, id };
        await writeCollection(collection, items, etag);
        return json(res, 200, items[index]);
      }
      if (method === "DELETE") {
        const [removed] = items.splice(index, 1);
        await writeCollection(collection, items, etag);
        return json(res, 200, removed);
      }
    }

    res.setHeader("Allow", id ? "GET, PUT, PATCH, DELETE" : "GET, POST");
    return json(res, 405, { message: "Method Not Allowed" });
  } catch (error) {
    console.error(`[api/${collection}] Request failed:`, error);
    const message = error instanceof Error ? error.message : "Lỗi xử lý API";
    if (message.includes("Dữ liệu gửi lên quá lớn") || message.includes("Nội dung gửi lên không hợp lệ")) {
      return json(res, 400, { message });
    }
    if (error instanceof Error && error.name === "BlobPreconditionFailedError") {
      return json(res, 409, { message: "Dữ liệu vừa được thay đổi. Tải lại rồi thử lại." });
    }
    return json(res, 500, { message: "Không thể lưu dữ liệu. Kiểm tra cấu hình Blob trên Vercel." });
  }
}
