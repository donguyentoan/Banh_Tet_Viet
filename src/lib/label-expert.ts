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
      html, body { margin:0; padding:0; background:#fff; }
      #receipt { width:${RENDER_WIDTH_PX}px; margin:0 auto; color:#000; font-size:12px; line-height:1.35; }
      #receipt * { box-shadow:none !important; text-shadow:none !important;
        background:transparent !important; color:#000 !important;
        border-color:#000 !important; max-width:100%; }
      #receipt .no-print { display:none !important; }
      #receipt > * { margin-left:0 !important; margin-right:0 !important; padding-left:0 !important; padding-right:0 !important; }
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

    // Lấy bề rộng thật (nội dung có thể tràn quá khổ) để không bị cắt mép phải
    const fullW = Math.max(RENDER_WIDTH_PX, wrapper.scrollWidth);
    const fullH = wrapper.scrollHeight;
    iframe.style.width = `${fullW}px`;
    iframe.style.height = `${fullH}px`;

    return await toPng(wrapper, {
      pixelRatio: 3, // ~ 203 dpi của đầu in nhiệt, nét chữ rõ
      backgroundColor: "#ffffff",
      width: fullW,
      height: fullH,
    });
  } finally {
    iframe.remove();
  }
}

/**
 * Cắt bỏ viền trắng quanh ảnh để phần nội dung thật được căn giữa chính xác.
 */
async function trimWhitespace(
  dataUrl: string,
  verticalOnly = false,
): Promise<{ dataUrl: string; width: number; height: number }> {
  const img = new Image();
  img.src = dataUrl;
  await img.decode();

  const canvas = document.createElement("canvas");
  canvas.width = img.width;
  canvas.height = img.height;
  const ctx = canvas.getContext("2d");
  if (!ctx) return { dataUrl, width: img.width, height: img.height };
  ctx.drawImage(img, 0, 0);
  const { data, width, height } = ctx.getImageData(0, 0, img.width, img.height);

  let top = height, left = width, right = -1, bottom = -1;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      // Điểm không phải trắng (ngưỡng 245)
      if (data[i] < 245 || data[i + 1] < 245 || data[i + 2] < 245) {
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
  }
  if (right < 0) return { dataUrl, width: img.width, height: img.height };

  if (verticalOnly) {
    left = 0;
    right = width - 1;
  }
  const pad = 6;
  left = Math.max(0, left - pad);
  top = Math.max(0, top - pad);
  right = Math.min(width - 1, right + pad);
  bottom = Math.min(height - 1, bottom + pad);
  const w = right - left + 1;
  const h = bottom - top + 1;

  const out = document.createElement("canvas");
  out.width = w;
  out.height = h;
  out.getContext("2d")!.drawImage(canvas, left, top, w, h, 0, 0, w, h);
  return { dataUrl: out.toDataURL("image/png"), width: w, height: h };
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

  const img = await trimWhitespace(dataUrl);

  // Co vừa vùng in, căn giữa theo chiều ngang
  const maxW = widthMm - MARGIN_X_MM * 2;
  const naturalW = (img.width / 3) * (25.4 / 96); // px@3x -> mm
  const drawW = Math.min(maxW, naturalW);
  const drawH = (drawW * img.height) / img.width;
  const offsetX = (widthMm - drawW) / 2;
  const pageH = drawH + MARGIN_Y_MM * 2;

  const pdf = new jsPDF({
    unit: "mm",
    format: [widthMm, pageH],
    orientation: pageH >= widthMm ? "portrait" : "landscape",
  });
  pdf.addImage(img.dataUrl, "PNG", offsetX, MARGIN_Y_MM, drawW, drawH);
  return pdf.output("blob");
}

/** Tem máy in nhiệt QR380A: 76×100mm, đầu in 203dpi (8 chấm/mm) */
export const LABEL_DOTS = { width: 608, height: 800 };
/** Lề trắng quanh nội dung, tính theo chấm in (~2mm) */
const LABEL_PADDING_DOTS = 16;

/**
 * Xuất phiếu thành ảnh PNG đúng kích thước tem (608×800 chấm @203dpi).
 * Label Expert in ảnh 1 điểm ảnh = 1 chấm nên phiếu phủ kín tem và căn giữa,
 * tránh lỗi PDF bị co nhỏ ~75% và dồn về góc trái khi in.
 */
export async function elementToLabelPngBlob(
  el: HTMLElement,
  dots: { width: number; height: number } = LABEL_DOTS,
): Promise<Blob> {
  // Chỉ cắt trắng trên/dưới, giữ nguyên bề ngang layout để chữ trải đều khổ giấy
  const img = await trimWhitespace(await renderReceiptPng(el), true);
  const source = new Image();
  source.src = img.dataUrl;
  await source.decode();

  // Fill đúng bề ngang 76mm trừ lề 2 bên, chiều cao theo nội dung
  const drawW = dots.width - LABEL_PADDING_DOTS * 2;
  const drawH = Math.round((img.height * drawW) / img.width);
  const canvasH = Math.max(dots.height, drawH + LABEL_PADDING_DOTS * 2);

  const canvas = document.createElement("canvas");
  canvas.width = dots.width;
  canvas.height = canvasH;
  const ctx = canvas.getContext("2d")!;
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.imageSmoothingQuality = "high";
  ctx.drawImage(
    source,
    LABEL_PADDING_DOTS,
    LABEL_PADDING_DOTS,
    drawW,
    drawH,
  );

  return new Promise((resolve, reject) =>
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error("Không tạo được ảnh phiếu"))),
      "image/png",
    ),
  );
}

/**
 * Mở bảng Chia sẻ của hệ điều hành để gửi file (PNG/PDF) sang Label Expert.
 * - Phải gọi trong sự kiện click/tap, trang chạy HTTPS.
 * - Web không chọn sẵn app đích được: người dùng chọn "Label Expert" trong bảng Share.
 * - Không hỗ trợ share file (desktop) -> tải PDF về máy.
 */
export async function sharePdfToLabelExpert(
  blob: Blob,
  fileName = "label.pdf",
): Promise<ShareResult> {
  const file = new File([blob], fileName, {
    type: blob.type || "application/pdf",
  });
  return shareFilesToLabelExpert([file]);
}

/**
 * Chia sẻ nhiều file cùng lúc (vd: mỗi mối chợ 1 tem). Không hỗ trợ share
 * nhiều file thì thử share từng file; không share được thì tải về máy.
 */
export async function shareFilesToLabelExpert(
  files: File[],
): Promise<ShareResult> {
  if (files.length === 0) return "cancelled";

  if (navigator.canShare?.({ files })) {
    try {
      await navigator.share({ files, title: files[0].name });
      return "shared";
    } catch (e) {
      if (e instanceof DOMException && e.name === "AbortError") return "cancelled";
      throw e;
    }
  }

  for (const file of files) {
    const a = document.createElement("a");
    a.href = URL.createObjectURL(file);
    a.download = file.name;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 10000);
  }
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
