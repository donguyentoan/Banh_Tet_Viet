import { useEffect, useMemo, useState } from "react";
import { toast } from "sonner";
import {
  Check,
  Copy,
  Download,
  QrCode,
  Wallet,
} from "lucide-react";
import { formatMoney } from "@/lib/format";
import {
  buildPaymentContent,
  buildVietQrUrl,
  SEPAY_BANK,
} from "@/lib/sepay";

interface SePayCheckoutProps {
  orderId: string;
  /** Tổng số tiền khách cần thanh toán (VNĐ) */
  amount: number;
  /** Gọi lại khi người dùng bấm "Tôi đã thanh toán" */
  onSuccess?: () => void;
}

/**
 * URL ảnh QR đi qua proxy của chính app (`/api/sepay-qr`).
 *
 * VietQR là domain khác origin và chặn CORS:
 *  - `<img src="https://vietqr.app/...">` -> `html-to-image` không đọc được
 *    pixel của ảnh khác origin nên phiếu in ra ô trống.
 *  - `crossOrigin="anonymous"` -> trình duyệt chặn luôn, ảnh không load.
 *
 * Đi qua proxy cùng origin thì ảnh hiển thị và in được ổn định.
 */
function buildQrImageUrl(vietQrUrl: string): string {
  return `/api/sepay-qr?url=${encodeURIComponent(vietQrUrl)}`;
}

/** Kiểm tra số tiền có thực sự cần thanh toán hay không. */
function hasAmountValue(amount: number): boolean {
  return Math.max(0, Math.round(amount)) > 0;
}

/**
 * Panel thanh toán QR (VietQR / SePay).
 *
 * Hiển thị đầy đủ thông tin khách cần để chuyển khoản:
 * QR, số tài khoản, tên chủ tài khoản, số tiền và nội dung (có mã đơn).
 * Nội dung chuyển khoản gắn mã đơn để webhook SePay tự đối soát.
 */
export const SePayCheckout: React.FC<SePayCheckoutProps> = ({
  orderId,
  amount,
  onSuccess,
}) => {
  const [copiedField, setCopiedField] = useState<string | null>(null);

  const paymentContent = useMemo(
    () => buildPaymentContent(orderId),
    [orderId],
  );

  const qrUrl = useMemo(
    () =>
      buildVietQrUrl({
        amount,
        content: paymentContent,
      }),
    [amount, paymentContent],
  );

  const qrImageUrl = useMemo(
    () => (hasAmountValue(amount) ? buildQrImageUrl(qrUrl) : null),
    [qrUrl, amount],
  );

  const [qrFailed, setQrFailed] = useState(false);

  useEffect(() => {
    setQrFailed(false);
  }, [qrImageUrl]);

  const amountValue = Math.max(0, Math.round(amount));
  const hasAmount = amountValue > 0;

  async function copyText(field: string, value: string, label: string) {
    try {
      await navigator.clipboard.writeText(value);
      setCopiedField(field);
      setTimeout(() => setCopiedField(null), 1800);
      toast.success(`Đã sao chép ${label}`);
    } catch {
      toast.error("Không sao chép được, hãy bấm giữ để chọn thủ công.");
    }
  }

  function downloadQr() {
    const link = document.createElement("a");
    link.href = qrImageUrl ?? qrUrl;
    link.download = `qr-thanh-toan-${orderId}.png`;
    link.rel = "noopener";
    document.body.appendChild(link);
    link.click();
    link.remove();
  }

  return (
    <section className="print-sheet overflow-hidden !py-3 !px-0">
      <div className="flex justify-between gap-4 sm:flex-row sm:items-start">
        <div className="mx-auto shrink-0 text-center sm:mx-0">
          <div className="rounded-xl border-1 bg-white p-2">
            {hasAmount && qrImageUrl ? (
              qrFailed ? (
                <div className="flex size-[180px] flex-col items-center justify-center gap-2 text-center text-emerald-700">
                  <QrCode className="size-8 text-amber-500" />
                  <span className="px-3 text-[10px] font-bold leading-snug">
                    Không tải được ảnh QR
                  </span>
                </div>
              ) : (
                <img
                  src={qrImageUrl}
                  alt={`Mã QR thanh toán đơn hàng ${orderId}`}
                  width={180}
                  height={180}
                  className="size-[180px] object-contain"
                  onError={() => setQrFailed(true)}
                />
              )
            ) : (
              <div className="flex size-[180px] flex-col items-center justify-center gap-2 text-center text-emerald-700">
                <Check className="size-8" />
                <span className="px-3 text-[11px] font-bold leading-snug">
                  Đơn hàng đã thanh toán đủ
                </span>
              </div>
            )}
          </div>

          {hasAmount ? (
            <div className="no-print mt-2 flex flex-col items-center gap-1">
              <button
                type="button"
                onClick={downloadQr}
                className="inline-flex items-center gap-1.5  bg-white px-2.5 py-1 text-[11px] font-bold text-emerald-700 transition hover:bg-emerald-50"
              >
                <Download className="size-3.5" />
                Tải ảnh QR
              </button>
              {qrFailed ? (
                <a
                  href={qrUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-[10px] font-bold text-amber-700 underline"
                >
                  Mở ảnh QR trong tab mới
                </a>
              ) : null}
            </div>
          ) : null}
        </div>
        <div className="min-w-0 flex-1 space-y-2">
          <div className="bg-white/80 px-3 py-2">
            <p className="text-[10px] font-bold uppercase tracking-wide text-emerald-700">
              Số tiền thanh toán
            </p>
            <p className="mt-0.5 text-[22px] font-black leading-tight text-emerald-800">
              {formatMoney(amountValue)}
            </p>
          </div>

          <dl className="space-y-1.5 bg-white/80 px-3 py-2 text-[11px] leading-snug">
            <InfoRow
              label="Ngân hàng"
              value={SEPAY_BANK.bank}
              onCopy={() =>
                copyText("bank", SEPAY_BANK.bank, "tên ngân hàng")
              }
              copied={copiedField === "bank"}
            />
            <InfoRow
              label="Số tài khoản"
              value={SEPAY_BANK.accountNo}
              mono
              onCopy={() =>
                copyText("acc", SEPAY_BANK.accountNo, "số tài khoản")
              }
              copied={copiedField === "acc"}
            />
            <InfoRow
              label="Chủ tài khoản"
              value={SEPAY_BANK.accountName}
              onCopy={() =>
                copyText("holder", SEPAY_BANK.accountName, "chủ tài khoản")
              }
              copied={copiedField === "holder"}
            />
            <InfoRow
              label="Nội dung"
              value={paymentContent}
              mono
              highlight
              onCopy={() =>
                copyText("des", paymentContent, "nội dung chuyển khoản")
              }
              copied={copiedField === "des"}
            />
          </dl>

          {onSuccess ? (
            <button
              type="button"
              onClick={onSuccess}
              className="no-print flex w-full items-center justify-center gap-1.5 rounded-lg bg-emerald-600 px-3 py-2 text-[12px] font-bold text-white transition hover:bg-emerald-700 active:scale-[0.99]"
            >
              <Wallet className="size-3.5" />
              Tôi đã thanh toán
            </button>
          ) : null}
        </div>
      </div>
    </section>
  );
}

function InfoRow({
  label,
  value,
  mono,
  highlight,
  onCopy,
  copied,
}: {
  label: string;
  value: string;
  mono?: boolean;
  highlight?: boolean;
  onCopy: () => void;
  copied: boolean;
}) {
  return (
    <div className="flex items-center gap-2">
      <dt className="w-[74px] shrink-0 text-emerald-700">{label}:</dt>
      <dd
        className={[
          "min-w-0 flex-1 break-all font-bold text-gray-900",
          mono ? "font-mono tracking-tight" : "",
          highlight ? "text-red-700" : "",
        ].join(" ")}
      >
        {value}
      </dd>
      <button
        type="button"
        onClick={onCopy}
        aria-label={`Sao chép ${label}`}
        className="no-print shrink-0 rounded p-1 text-emerald-700 transition hover:bg-emerald-100"
      >
        {copied ? (
          <Check className="size-3.5 text-emerald-600" />
        ) : (
          <Copy className="size-3.5" />
        )}
      </button>
    </div>
  );
}
