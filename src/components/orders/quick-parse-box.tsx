import { useEffect, useMemo, useRef, useState } from "react";
import {
  AlertTriangle,
  Mic,
  MicOff,
  MessageSquareText,
  Sparkles,
  X,
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { useProducts } from "@/hooks/use-orders";
import { formatMoney } from "@/lib/format";
import { parseQuickOrder, type ParsedOrder } from "@/lib/quick-parse";
import {
  calculateTotal,
  type OrderFormValues,
  type Product,
} from "@/lib/types";

interface QuickParseBoxProps {
  /** Nhận dữ liệu đã phân tích - bấm "Tạo đơn" để mở form điền sẵn */
  onParsed: (parsed: ParsedOrder, values: OrderFormValues) => void;
}

const EXAMPLES = [
  // Nhập bằng mã
  "bà Mi / 03/02/2027 / 2 CM / 1 CC / 8 giờ sáng",
  "anh Tuấn 0908123457 ngày 27 tết 3 CML 2 TN chiều",
  "chị Hồng 0912345678 28/02/2027 1 CCL 2 TC tối",

  // Nhập bằng tên bánh
  "bà Hoa 0901234567 5 bánh chưng chay giao 28 Tết",
  "anh Minh 0912345678 5 bánh chưng chay lớn giao 28 Tết",
  "chị Lan 2 bánh chưng chay lớn 3 bánh chưng chay chiều",
];

/** Mảng rỗng ổn định - tránh tạo reference mới mỗi render */
const EMPTY_PRODUCTS: Product[] = [];

interface SpeechRecognitionAlternativeLike {
  transcript: string;
}

interface SpeechRecognitionResultLike extends ArrayLike<SpeechRecognitionAlternativeLike> {
  isFinal: boolean;
}

interface SpeechRecognitionEventLike extends Event {
  results: ArrayLike<SpeechRecognitionResultLike>;
}

interface SpeechRecognitionLike {
  lang: string;
  interimResults: boolean;
  continuous: boolean;
  onresult: ((event: SpeechRecognitionEventLike) => void) | null;
  onerror: ((event: Event & { error?: string }) => void) | null;
  onend: (() => void) | null;
  start: () => void;
  stop: () => void;
}

interface SpeechWindow extends Window {
  SpeechRecognition?: new () => SpeechRecognitionLike;
  webkitSpeechRecognition?: new () => SpeechRecognitionLike;
}

export function QuickParseBox({ onParsed }: QuickParseBoxProps) {
  const { data } = useProducts();
  const products = data ?? EMPTY_PRODUCTS;
  const [text, setText] = useState("");
  const [showHint, setShowHint] = useState(false);
  const [isListening, setIsListening] = useState(false);
  const [voiceError, setVoiceError] = useState("");
  const recognitionRef = useRef<SpeechRecognitionLike | null>(null);

  useEffect(() => () => recognitionRef.current?.stop(), []);

  function handleVoiceInput() {
    if (isListening) {
      recognitionRef.current?.stop();
      setIsListening(false);
      return;
    }

    const speechWindow = window as SpeechWindow;
    const Recognition =
      speechWindow.SpeechRecognition ?? speechWindow.webkitSpeechRecognition;
    if (!Recognition) {
      setVoiceError(
        "Trình duyệt chưa hỗ trợ nhập giọng nói. Bạn có thể dùng tính năng nhập liệu bằng giọng nói của bàn phím.",
      );
      return;
    }

    setVoiceError("");
    const recognition = new Recognition();
    recognitionRef.current = recognition;
    recognition.lang = "vi-VN";
    recognition.continuous = false;
    recognition.interimResults = false;
    recognition.onresult = (event) => {
      const transcript = Array.from(event.results)
        .map((result) => result[0]?.transcript ?? "")
        .join(" ")
        .trim();
      if (transcript) setText((current) => `${current} ${transcript}`.trim());
    };
    recognition.onerror = (event) => {
      const message =
        event.error === "not-allowed"
          ? "Bạn cần cho phép truy cập micro để đọc đơn."
          : event.error === "no-speech"
            ? "Chưa nghe rõ nội dung. Bạn thử nói lại nhé."
            : "Không nhận được giọng nói. Bạn thử lại hoặc nhập nội dung bằng tay.";
      setVoiceError(message);
    };
    recognition.onend = () => setIsListening(false);
    try {
      recognition.start();
      setIsListening(true);
    } catch {
      setIsListening(false);
      setVoiceError(
        "Micro đang bận hoặc trình duyệt chưa sẵn sàng. Bạn thử lại nhé.",
      );
    }
  }

  const parsed = useMemo(
    () => (text.trim() ? parseQuickOrder(text, products) : null),
    [text, products],
  );

  const total = useMemo(
    () => (parsed ? calculateTotal(parsed.quantities, products) : 0),
    [parsed, products],
  );

  const hasItems = parsed
    ? Object.values(parsed.quantities).some((qty) => qty > 0)
    : false;

  function handleParse() {
    if (!parsed || !hasItems) return;

    onParsed(parsed, {
      customerName: parsed.customerName || "Khách vô danh",
      phone: parsed.phone ?? "",
      address: parsed.address ?? "",
      deliveryDate: parsed.deliveryDate,
      deliveryTime: parsed.deliveryTime,
      status: "Mới đặt",
      deposit: 0,
      notes: "",
      quantities: parsed.quantities,
    });
  }

  return (
    <div className="overflow-hidden rounded-2xl border border-amber-300 bg-gradient-to-br from-amber-50 via-white to-red-50/40 shadow-sm">
      <div className="flex flex-wrap items-center justify-between gap-2 border-b border-amber-200 bg-gradient-to-r from-red-700 to-red-800 px-5 py-3 text-white">
        <div className="flex items-center gap-2">
          <MessageSquareText className="size-5 text-amber-300" />
          <div>
            <h3 className="text-sm font-extrabold">Tạo Đơn Nhanh</h3>
            <p className="text-[11px] text-red-100">
              Tự động tách tên khách, ngày giao & số lượng bánh
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={() => setShowHint((value) => !value)}
          className="rounded-full border border-white/40 px-3 py-1 text-[11px] font-bold text-amber-200 transition hover:bg-white/10"
        >
          {showHint ? "Ẩn hướng dẫn" : "Hướng dẫn cú pháp"}
        </button>
      </div>

      {showHint && (
        <div className="border-b border-amber-200 bg-white/70 px-5 py-3 text-xs">
          <p className="font-semibold text-gray-700">
            Cú pháp:{" "}
            <span className="text-red-700">
              tên khách / ngày giao / số lượng + mã hoặc tên bánh / khung giờ giao
            </span>
          </p>

          <ul className="mt-1.5 space-y-1 text-gray-600">
            <li>
              <strong className="text-emerald-700">Mã bánh:</strong> CM (chưng
              thịt), CC (chưng chay), CML (chưng thịt lớn), CCL (chưng chay
              lớn), TT (tét thịt), TN (tét ngọt), TC (tét chay)
            </li>

            <li>
              <strong className="text-emerald-700">Ngày:</strong> 03/02/2027
              hoặc "27 tết"
            </li>

            <li>
              <strong className="text-emerald-700">Giờ:</strong> "8 giờ sáng",
              "chiều", "tối"
            </li>
          </ul>

          <div className="mt-2 flex flex-wrap gap-1.5">
            {EXAMPLES.map((example) => (
              <button
                key={example}
                type="button"
                onClick={() => setText(example)}
                className="rounded-md border border-amber-200 bg-amber-50 px-2 py-1 font-mono text-[11px] text-amber-900 transition hover:border-red-300 hover:bg-amber-100"
              >
                {example}
              </button>
            ))}
          </div>
        </div>
      )}

      <div className="space-y-3 p-5">
        <div className="flex flex-wrap items-center gap-2">
          <Button
            type="button"
            variant={isListening ? "destructive" : "outline"}
            onClick={handleVoiceInput}
            aria-pressed={isListening}
            className={`min-h-10 gap-2 font-bold ${isListening ? "animate-pulse" : "border-red-300 bg-red-50 text-red-700 hover:bg-red-100"}`}
          >
            {isListening ? (
              <MicOff className="size-4" />
            ) : (
              <Mic className="size-4" />
            )}
            {isListening ? "Đang nghe… Bấm để dừng" : "Thu âm giọng nói"}
          </Button>
          <span className="text-xs text-gray-500">
            Ví dụ: “Bán chị Lan 5 bánh chưng mặn giao 28 Tết”
          </span>
        </div>
        {voiceError && (
          <p role="status" className="text-xs font-medium text-red-700">
            {voiceError}
          </p>
        )}
        <div className="relative">
          <Textarea
            value={text}
            onChange={(event) => setText(event.target.value)}
            rows={2}
            placeholder="Ví dụ: bà mi / 03/02/2027 / 2 CM / 1 CC / 8 giờ sáng"
            className="min-h-[72px] resize-y bg-white font-medium text-gray-800"
            aria-label="Ô ghi nhanh đơn hàng bằng tin nhắn"
          />
          {text && (
            <Button
              variant="ghost"
              size="icon-sm"
              onClick={() => setText("")}
              aria-label="Xoá nội dung ghi nhanh"
              className="absolute right-1.5 top-1.5 text-gray-500 hover:bg-red-50 hover:text-red-700"
            >
              <X className="size-3.5" />
            </Button>
          )}
        </div>

        {parsed && (
          <div className="rounded-xl border border-emerald-200 bg-white p-3">
            <div className="flex flex-wrap items-center gap-2">
              <Badge className="border-emerald-300 bg-emerald-50 text-[11px] font-bold text-emerald-800">
                <Sparkles className="mr-1 size-3" />
                Đã phân tích
              </Badge>
              <span className="text-sm font-bold text-gray-900">
                {parsed.customerName || "(chưa nhận ra tên)"}
              </span>
              {parsed.phone && (
                <span className="text-xs font-semibold text-gray-500">
                  ☎ {parsed.phone}
                </span>
              )}
              <span className="text-xs font-semibold text-red-700">
                📅 {parsed.deliveryDate}
              </span>
              <span className="text-xs font-semibold text-gray-600">
                🕐 {parsed.deliveryTime}
              </span>
              {hasItems && (
                <span className="text-xs font-bold text-amber-700">
                  💰 {formatMoney(total)}
                </span>
              )}
            </div>

            <div className="mt-2 flex flex-wrap gap-1.5">
              {Object.entries(parsed.quantities).map(([productId, qty]) => {
                const product = products.find((p) => p.id === productId);
                return (
                  <Badge
                    key={productId}
                    className="border-amber-300 bg-amber-50 text-[11px] font-bold text-amber-900"
                  >
                    <img
                      src={product?.icon}
                      alt={product?.name}
                      className="inline-block size-5"
                    />{" "}
                    {product?.name ?? productId} × {qty}
                  </Badge>
                );
              })}
              {parsed.unknownCodes.map((code) => (
                <Badge
                  key={code}
                  className="border-red-300 bg-red-50 text-[11px] font-bold text-red-700"
                >
                  <AlertTriangle className="mr-1 size-3" />
                  Mã lạ: {code}
                </Badge>
              ))}
              {!hasItems && (
                <span className="text-xs font-medium text-red-600">
                  Chưa nhận ra bánh nào. Thử dùng mã CM, CC, CML, CCL, TT, TN, TC hoặc nhập tên bánh.
                </span>
              )}
            </div>
          </div>
        )}

        <div className="flex flex-wrap items-center justify-end gap-2">
          <Button
            size="sm"
            onClick={handleParse}
            disabled={!hasItems}
            className="gap-1.5 bg-gradient-to-r from-red-600 to-red-700 font-bold text-white hover:from-red-700 hover:to-red-800"
          >
            <Sparkles className="size-3.5 text-amber-300" />
            Phân Tích & Tạo Đơn
          </Button>
        </div>
      </div>
    </div>
  );
}
