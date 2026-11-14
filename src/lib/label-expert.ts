import { toPng } from "html-to-image";
import { jsPDF } from "jspdf";

export type ShareResult = "shared" | "cancelled" | "downloaded";

/**
 * Khổ giấy nhiệt máy POS thông dụng: cuộn 75mm (máy 80mm series cũng in được),
 * vùng in thực tế ~72mm. Chiều cao tự động theo nội dung (máy tự cắt giấy).
 */
export const PAPER_WIDTH_MM = 75;
/** Lề trái/phải: (75 - 72) / 2 */
const MARGIN_X_MM = 1.5;
const MARGIN_Y_MM = 3;
/** Bề rộng CSS dùng để dàn trang phiếu (~72mm @96dpi), để layout co về dạng mobile */
const RENDER_WIDTH_PX = 272;

/**
 * Render bản sao phần tử trong iframe ẩn rộng đúng khổ giấy, để media query
 * (sm:, md:...) tính theo bề rộng phiếu chứ không theo màn hình.
 */
async function renderReceiptPng(el: HTMLElement): Promise<string> {
  const iframe = document.createElement("iframe");
  iframe.setAttribute("aria-hidden", "true");
  iframe.style.cssText = `position:fixed;left:-10000px;top:0;width:${RENDER_WIDTH_PX}px;height:10px;border:0;`;
  document.body.appendChild(iframe);

  try {
    const doc = iframe.contentDocument!;
    doc.open();
    doc.write("<!doctype html><html><head></head><body></body></html>");
    doc.close();

    // Copy CSS của trang (Tailwind...) sang iframe
    const styleLoads: Promise<unknown>[] = [];
    document.querySelectorAll('link[rel="stylesheet"], style').forEach((node) => {
      const clone = node.cloneNode(true) as HTMLElement;
      if (clone instanceof HTMLLinkElement) {
        styleLoads.push(
          new Promise((resolve) => {
            clone.onload = resolve;
            clone.onerror = resolve;
          }),
        );
      }
      doc.head.appendChild(clone);
    });

    // Style phiếu nhiệt: nền trắng, chữ đen đậm, không bóng/viền màu
    const receiptStyle = doc.createElement("style");
    receiptStyle.textContent = `
      html, body { margin:0; padding:0; background:#fff; width:${RENDER_WIDTH_PX}px; }
      #receipt { width:${RENDER_WIDTH_PX}px; color:#000; font-size:12px; line-height:1.35; }
      #receipt * { box-shadow:none !important; text-shadow:none !important;
        background:transparent !important; color:#000 !important;
        border-color:#000 !important; max-width:100%; }
      #receipt .no-print { display:none !important; }
      #receipt table { width:100% !important; table-layout:auto; }
      #receipt th, #receipt td { padding:2px 3px !important; font-size:11px !important; }
      #receipt [class*="overflow-x"] { overflow:visible !important; }
    `;
    doc.head.appendChild(receiptStyle);

    const wrapper = doc.createElement("div");
    wrapper.id = "receipt";
    wrapper.appendChild(doc.importNode(el, true));
    doc.body.appendChild(wrapper);

    await Promise.all(styleLoads);
    await doc.fonts?.ready;

    iframe.style.height = `${wrapper.scrollHeight}px`;

    return await toPng(wrapper, {
      pixelRatio: 3, // ~ 203 dpi của đầu in nhiệt, nét chữ rõ
      backgroundColor: "#ffffff",
      width: RENDER_WIDTH_PX,
      height: wrapper.scrollHeight,
    });
  } finally {
    iframe.remove();
  }
}

/**
 * Tạo PDF khổ giấy nhiệt 75mm, 1 trang liền dài đúng bằng nội dung.
 */
export async function elementToPdfBlob(
  el: HTMLElement,
  options?: { widthMm?: number },
): Promise<Blob> {
  const widthMm = options?.widthMm ?? PAPER_WIDTH_MM;
  const dataUrl = await renderReceiptPng(el);

  const img = new Image();
  img.src = dataUrl;
  await img.decode();

  const drawW = widthMm - MARGIN_X_MM * 2;
  const drawH = (drawW * img.height) / img.width;
  const pageH = drawH + MARGIN_Y_MM * 2;

  const pdf = new jsPDF({
    unit: "mm",
    format: [widthMm, pageH],
    orientation: pageH >= widthMm ? "portrait" : "landscape",
  });
  pdf.addImage(dataUrl, "PNG", MARGIN_X_MM, MARGIN_Y_MM, drawW, drawH);
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
