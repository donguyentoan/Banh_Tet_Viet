import { createHmac, timingSafeEqual } from "node:crypto";

export interface ApiRequest extends AsyncIterable<Buffer | string> {
  method?: string;
  headers: Record<string, string | string[] | undefined>;
  body?: unknown;
}

export interface ApiResponse {
  setHeader(name: string, value: string): void;
  status(code: number): ApiResponse;
  json(body: unknown): void;
}

const ADMIN_COOKIE = "tet_admin";
const SESSION_SECONDS = 8 * 60 * 60;

function json(res: ApiResponse, status: number, body: unknown) {
  return res.status(status).json(body);
}

function getHeader(req: ApiRequest, name: string): string {
  const value = req.headers[name.toLowerCase()];
  return Array.isArray(value) ? value[0] ?? "" : value ?? "";
}

export async function readBody(req: ApiRequest): Promise<Record<string, any>> {
  // Vercel parses JSON request bodies onto req.body before invoking the
  // function. Prefer that value there; local Vite requests use the raw stream.
  if (req.body !== undefined && req.body !== null) {
    const value = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      throw new Error("Nội dung gửi lên không hợp lệ");
    }
    if (Buffer.byteLength(JSON.stringify(value)) > 1_000_000) {
      throw new Error("Dữ liệu gửi lên quá lớn");
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

export function hasAdminSession(req: ApiRequest): boolean {
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

function secureCookie(value: string, maxAge: number) {
  return `${ADMIN_COOKIE}=${value}; HttpOnly; Secure; SameSite=Strict; Path=/api; Max-Age=${maxAge}`;
}

export async function handleAdminAuth(
  req: ApiRequest,
  res: ApiResponse,
  action: "session" | "login" | "logout",
) {
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

  res.setHeader("Allow", action === "session" ? "GET" : "POST");
  return json(res, 405, { message: "Method Not Allowed" });
}
