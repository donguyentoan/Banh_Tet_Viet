import { useEffect, useState } from "react";
import { Clock } from "lucide-react";
import { TET_DATE_ISO } from "@/lib/types";

function useTetCountdown() {
  const [text, setText] = useState("-- Ngày -- Giờ -- Phút");

  useEffect(() => {
    const target = new Date(`${TET_DATE_ISO}T00:00:00`).getTime();

    const update = () => {
      const distance = target - Date.now();
      if (distance < 0) {
        setText("CHÚC MỪNG NĂM MỚI 2027!");
        return;
      }
      const days = Math.floor(distance / 86_400_000);
      const hours = Math.floor((distance % 86_400_000) / 3_600_000);
      const minutes = Math.floor((distance % 3_600_000) / 60_000);
      setText(`${days} Ngày ${hours} Giờ ${minutes} Phút`);
    };

    update();
    const timer = window.setInterval(update, 60_000);
    return () => window.clearInterval(timer);
  }, []);

  return text;
}

export function TetBanner() {
  const countdown = useTetCountdown();

  return (
    <div className="no-print hidden bg-gradient-to-r from-red-800 via-red-600 to-amber-600 text-white text-xs md:text-sm py-2 px-4 text-center font-medium shadow-md flex items-center justify-between sm:flex">
      <div className="hidden md:flex items-center space-x-2">
        <span>🌸 Chúc Mừng Năm Mới 2027 - Đinh Mùi 🌸</span>
      </div>
      <div className="mx-auto md:mx-0 flex items-center gap-2">
        <Clock className="size-4 animate-bounce" />
        <span>Đếm ngược đến Tết Nguyên Đán 2027 (Mùng 1 Tết): </span>
        <span className="font-bold text-amber-300 bg-black/20 px-2 py-0.5 rounded">
          {countdown}
        </span>
      </div>
      <div className="hidden md:flex items-center space-x-2">
        <span>🧧 Vạn Sự Như Ý - Phát Tài Phát Lộc 🧧</span>
      </div>
    </div>
  );
}
