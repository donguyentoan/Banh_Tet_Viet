import { readFile } from "node:fs/promises";
import { join } from "node:path";

interface ApiRequest {
  method?: string;
}

interface ApiResponse {
  setHeader(name: string, value: string): void;
  status(code: number): ApiResponse;
  json(body: unknown): void;
}

/** Vercel Function serving the product catalog in production. */
export default async function handler(req: ApiRequest, res: ApiResponse) {
  res.setHeader("Cache-Control", "no-store");

  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    return res.status(405).json({ message: "Method Not Allowed" });
  }

  try {
    const file = join(process.cwd(), "data", "products.json");
    const products = JSON.parse(await readFile(file, "utf8"));
    return res.status(200).json(products);
  } catch (error) {
    console.error("[api/products] Could not load product catalog:", error);
    return res.status(500).json({ message: "Không tải được danh mục bánh" });
  }
}
