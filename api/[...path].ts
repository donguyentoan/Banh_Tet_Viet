import { createHmac, timingSafeEqual } from "node:crypto";
import { get, put } from "@vercel/blob";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

interface ApiRequest extends AsyncIterable<Buffer | string> {
  method?: string;
  url?: string;
  headers: Record<string, string | string[] | undefined>;
  query?: { path?: string | string[] };
  body?: unknown;
}

interface ApiResponse {
  setHeader(name: string, value: string): void;
  status(code: number): ApiResponse;
  json(body: unknown): void;
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
const ADMIN_COOKIE = "tet_admin";
const SESSION_SECONDS = 8 * 60 * 60;

function json(res: ApiResponse, status: number, body: unknown) {
  return res.status(status).json(body);
}

function getHeader(req: ApiRequest, name: string): string {
  const value = req.headers[name.toLowerCase()];
  return Array.isArray(value) ? value[0] ?? "" : value ?? "";
}

async function readBody(req: ApiRequest): Promise<Record<string, any>> {
  // Vercel parses JSON request bodies onto req.body before invoking the
  // function. Prefer that value there; local Vite requests still use the raw
  // request stream below.
  if (req.body !== undefined && req.body !== null) {
    const value = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      throw new Error("Nội dung gửi lên không hợp lệ");
    }
    return value as Record<string, any>;
  }

  const chunks: Buffer[] = [];
  let length = 0;
  for await (const chunk of req) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    length += buffer.length;
    if (length > 1_000_000) throw new Error("Dữ liệu gửi lên quá lớn");
    chunks.push(buffer);
  }
  if (!chunks.length) return {};
  const value = JSON.parse(Buffer.concat(chunks).toString("utf8"));
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Nội dung gửi lên không hợp lệ");
  }
  return value;
}

function sessionSignature(expires: string): string {
  const secret = process.env.ADMIN_SESSION_SECRET;
  if (!secret) throw new Error("Thiếu ADMIN_SESSION_SECRET");
  return createHmac("sha256", secret).update(expires).digest("base64url");
}

function hasAdminSession(req: ApiRequest): boolean {
  const cookieHeader = getHeader(req, "cookie");
  const token = cookieHeader
    .split(";")
    .map((part) => part.trim())
    .find((part) => part.startsWith(`${ADMIN_COOKIE}=`))
    ?.slice(ADMIN_COOKIE.length + 1);
  if (!token) return false;

  const [expires, signature] = token.split(".");
  if (!expires || !signature || Number(expires) <= Math.floor(Date.now() / 1000)) {
    return false;
  }
  try {
    const expected = Buffer.from(sessionSignature(expires));
    const received = Buffer.from(signature);
    return expected.length === received.length && timingSafeEqual(expected, received);
  } catch {
    return false;
  }
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

function collectionPath(req: ApiRequest): string[] {
  if (Array.isArray(req.query?.path)) return req.query.path.map(decodeURIComponent);
  if (req.query?.path) return req.query.path.split("/").map(decodeURIComponent);
  const pathname = new URL(req.url ?? "/", "http://localhost").pathname;
  return pathname.replace(/^\/api\/?/, "").split("/").filter(Boolean).map(decodeURIComponent);
}

function secureCookie(value: string, maxAge: number) {
  return `${ADMIN_COOKIE}=${value}; HttpOnly; Secure; SameSite=Strict; Path=/api; Max-Age=${maxAge}`;
}

async function handleAuth(req: ApiRequest, res: ApiResponse, action: string) {
  const method = (req.method ?? "GET").toUpperCase();
  if (action === "session" && method === "GET") {
    return json(res, 200, { authenticated: hasAdminSession(req) });
  }

  if (action === "logout" && method === "POST") {
    res.setHeader("Set-Cookie", secureCookie("", 0));
    return json(res, 200, { authenticated: false });
  }

  if (action === "login" && method === "POST") {
    const password = process.env.ADMIN_PASSWORD;
    if (!password || !process.env.ADMIN_SESSION_SECRET) {
      return json(res, 503, { message: "Chưa cấu hình mật khẩu quản trị trên Vercel." });
    }
    const body = await readBody(req);
    const expected = createHmac("sha256", "password-check").update(password).digest();
    const received = createHmac("sha256", "password-check")
      .update(String(body.password ?? ""))
      .digest();
    if (!timingSafeEqual(expected, received)) {
      return json(res, 401, { message: "Mật khẩu quản trị không đúng." });
    }
    const expires = String(Math.floor(Date.now() / 1000) + SESSION_SECONDS);
    res.setHeader("Set-Cookie", secureCookie(`${expires}.${sessionSignature(expires)}`, SESSION_SECONDS));
    return json(res, 200, { authenticated: true });
  }

  res.setHeader("Allow", "GET, POST");
  return json(res, 405, { message: "Method Not Allowed" });
}

export default async function handler(req: ApiRequest, res: ApiResponse) {
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("Content-Type", "application/json; charset=utf-8");

  const path = collectionPath(req);
  if (path[0] === "auth") {
    try {
      return await handleAuth(req, res, path[1] ?? "");
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
