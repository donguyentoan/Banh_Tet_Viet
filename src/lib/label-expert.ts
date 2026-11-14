import { toPng } from "html-to-image";
import { jsPDF } from "jspdf";

export type ShareResult = "shared" | "cancelled" | "downloaded";

/** Khổ giấy nhiệt mặc định: rộng 76mm, chiều cao tự động theo nội dung */
export const PAPER_WIDTH_MM = 76;
/** Chiều cao tối thiểu của 1 trang giấy nhiệt 76mm */
export const PAPER_MIN_HEIGHT_MM = 120;

/**
 * Chụp một phần tử HTML (vd: #print-area) thành PDF khổ giấy nhiệt 76mm.
 *
 * - Bề rộng luôn = 76mm, khớp với khổ giấy của máy in bill.
 * - Chiều cao trang được tính TOÁN theo chiều cao nội dung => phiếu luôn nằm
 *   gọn trong MỘT trang liên tục, không bị cắt thành 2-3 trang như bản cũ
 *   (máy in nhiệt tự cắt cuộn giấy đúng độ dài nội dung).
 * - Nếu nội dung vẫn dài hơn khổ giấy, vẫn chia trang để không mất thông tin.
 */
export async function elementToPdfBlob(
  el: HTMLElement,
  options?: { widthMm?: number; minHeightMm?: number },
): Promise<Blob> {
  const widthMm = options?.widthMm ?? PAPER_WIDTH_MM;
  const minHeightMm = options?.minHeightMm ?? PAPER_MIN_HEIGHT_MM;

  const dataUrl = await toPng(el, {
    pixelRatio: 2,
    backgroundColor: "#ffffff",
    filter: (node) =>
      !(node instanceof HTMLElement && node.classList.contains("no-print")),
  });

  const img = new Image();
  img.src = dataUrl;
  await img.decode();

  // Tỉ lệ ảnh (chiều cao / chiều rộng)
  const ratio = img.height / img.width;
  const margin = 2;
  const usableW = widthMm - margin * 2;

  // Chiều cao nội dung quy đổi sang mm (khi fill đúng bề rộng giấy)
  const contentH = usableW * ratio;
  // Chiều cao trang = nội dung + 2 lần margin, tối thiểu là minHeightMm
  const pageH = Math.max(minHeightMm, contentH + margin * 2);

  const pdf = new jsPDF({
    unit: "mm",
    format: [widthMm, pageH],
    orientation: "portrait",
  });

  const drawW = usableW;
  const drawH = contentH;
  const offsetX = margin;

  // Nội dung vừa 1 trang -> in nguyên 1 trang (phần lớn các đơn hàng)
  if (drawH <= pageH - margin * 2) {
    pdf.addImage(dataUrl, "PNG", offsetX, margin, drawW, drawH);
    return pdf.output("blob");
  }

  // Nội dung quá dài -> chia trang, không mất thông tin
  const usableH = pageH - margin * 2;
  let offset = 0;
  while (offset < drawH) {
    if (offset > 0) pdf.addPage([widthMm, pageH], "portrait");
    pdf.addImage(dataUrl, "PNG", offsetX, margin - offset, drawW, drawH);
    offset += usableH;
  }

  return pdf.output("blob");
}

/**
 * Mở bảng Chia sẻ của hệ điều hành để gửi PDF sang Label Expert.
 * - Phải gọi trong sự kiện click/tap, trang chạy HTTPS.
 * - Web không chọn sẵn app đích được: người dùng chọn "Label Expert" trong bảng Share.
 * - Không hỗ trợ share file (desktop) -> tải PDF về máy.
 */
export async function sharePdfToLabelExpert(
  blob: Blob,
  fileName = "label.pdf",
): Promise<ShareResult> {
  const file = new File([blob], fileName, { type: "application/pdf" });

  if (navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({ files: [file], title: fileName });
      return "shared";
    } catch (e) {
      if (e instanceof DOMException && e.name === "AbortError") return "cancelled";
      throw e;
    }
  }

  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = fileName;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 10000);
  return "downloaded";
}

/**
 * Tải PDF từ URL (cần CORS) rồi gửi sang Label Expert.
 */
export async function sendPdfUrlToLabelExpert(
  pdfUrl: string,
  fileName = "label.pdf",
): Promise<ShareResult> {
  const res = await fetch(pdfUrl);
  if (!res.ok) throw new Error(`Tải PDF lỗi: HTTP ${res.status}`);
  const blob = await res.blob();
  const head = new TextDecoder().decode(await blob.slice(0, 4).arrayBuffer());
  if (head !== "%PDF") throw new Error("File tải về không phải PDF");
  return sharePdfToLabelExpert(blob, fileName);
}
