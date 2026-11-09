import { readFile } from "node:fs/promises";
import { join } from "node:path";

interface ApiRequest {
  method?: string;
  query?: { collection?: string | string[] };
}

interface ApiResponse {
  setHeader(name: string, value: string): void;
  status(code: number): ApiResponse;
  json(body: unknown): void;
}

const COLLECTIONS = new Set([
  "orders",
  "products",
  "markets",
  "wholesale",
  "production",
  "inventory",
]);

/** Public read-only JSON collection API for Vercel production. */
export default async function handler(req: ApiRequest, res: ApiResponse) {
  res.setHeader("Cache-Control", "no-store");

  const collection = Array.isArray(req.query?.collection)
    ? req.query.collection[0]
    : req.query?.collection;

  if (!collection || !COLLECTIONS.has(collection)) {
    return res.status(404).json({ message: "Không tìm thấy danh mục API" });
  }

  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    return res.status(405).json({
      message: "API này chỉ hỗ trợ đọc dữ liệu JSON.",
    });
  }

  try {
    const file = join(process.cwd(), "data", `${collection}.json`);
    const items = JSON.parse(await readFile(file, "utf8"));
    return res.status(200).json(items);
  } catch (error) {
    console.error(`[api/${collection}] Could not load collection:`, error);
    return res.status(500).json({ message: "Không tải được dữ liệu" });
  }
}
