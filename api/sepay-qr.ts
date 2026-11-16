import { VercelRequest, VercelResponse } from "@vercel/node";

/**
 * Proxy ảnh QR VietQR.
 *
 * VietQR chặn CORS nên trình duyệt không đọc được pixel ảnh (và không fetch
 * được) khi render trực tiếp từ domain của họ. Khi đó:
 *  - `html-to-image` không chụp được ảnh -> phiếu in ra ô trống.
 *  - `crossOrigin="anonymous"` -> ảnh không load.
 *
 * Endpoint này fetch ảnh ở phía server rồi trả về cùng origin với app,
 * giúp ảnh hiển thị và in được ổn định.
 */
export default async function handler(
  req: VercelRequest,
  res: VercelResponse,
) {
  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    return res.status(405).json({ message: "Method Not Allowed" });
  }

  const raw = typeof req.query.url === "string" ? req.query.url : "";
  if (!raw) {
    return res.status(400).json({ message: "Thiếu tham số url." });
  }

  // Chỉ cho phép proxy tới VietQR để tránh thành SSRF endpoint mở.
  let target: URL;
  try {
    target = new URL(raw);
  } catch {
    return res.status(400).json({ message: "URL không hợp lệ." });
  }

  if (!/(^|\.)vietqr\.app$/i.test(target.hostname)) {
    return res.status(400).json({ message: "Chỉ hỗ trợ ảnh từ vietqr.app." });
  }

  try {
    const upstream = await fetch(target.toString(), {
      headers: { Accept: "image/png,image/*" },
    });

    if (!upstream.ok) {
      return res.status(502).json({
        message: `Không tải được ảnh QR (HTTP ${upstream.status}).`,
      });
    }

    const contentType = upstream.headers.get("content-type") ?? "image/png";
    if (!contentType.startsWith("image/")) {
      return res.status(502).json({ message: "Dữ liệu trả về không phải ảnh." });
    }

    const buffer = await upstream.arrayBuffer();

    res.setHeader("Content-Type", contentType);
    res.setHeader("Cache-Control", "public, max-age=300, s-maxage=3600");
    res.setHeader("Content-Length", String(buffer.byteLength));
    return res.status(200).send(Buffer.from(buffer));
  } catch (error) {
    console.error("[sepay-qr] Lỗi proxy ảnh QR:", error);
    return res.status(502).json({ message: "Không tải được ảnh QR." });
  }
}
