import { toPng } from "html-to-image";
import { jsPDF } from "jspdf";

export type ShareResult = "shared" | "cancelled" | "downloaded";

/**
 * Chụp một phần tử HTML (vd: #print-area) thành PDF khổ A4.
 */
export async function elementToPdfBlob(el: HTMLElement): Promise<Blob> {
  const dataUrl = await toPng(el, {
    pixelRatio: 2,
    backgroundColor: "#ffffff",
    filter: (node) =>
      !(node instanceof HTMLElement && node.classList.contains("no-print")),
  });

  const img = new Image();
  img.src = dataUrl;
  await img.decode();

  const pdf = new jsPDF({ unit: "mm", format: "a4", orientation: "portrait" });
  const pageW = pdf.internal.pageSize.getWidth();
  const pageH = pdf.internal.pageSize.getHeight();
  const margin = 8;
  const w = pageW - margin * 2;
  const h = (img.height * w) / img.width;

  // Nếu nội dung dài hơn 1 trang thì cắt sang các trang tiếp theo
  let offset = 0;
  const usableH = pageH - margin * 2;
  while (offset < h) {
    if (offset > 0) pdf.addPage();
    pdf.addImage(dataUrl, "PNG", margin, margin - offset, w, h);
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
