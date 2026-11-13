import { createRoute } from "@tanstack/react-router";
import { Route as rootRoute } from "@/routes/__root";
import { useState } from "react";
import { useOrders } from "@/hooks/use-orders";

// Giữ nguyên FB_CONFIG theo yêu cầu của bạn
const FB_CONFIG = {
  PAGE_ACCESS_TOKEN: "EAAlzD2yepCEBSxRLZCwcee9Do079GfMusNBCxBrfYIO0DlHdDrka6agameW8dZCYOxOUyLdo1nWVxSiZBaWYZAybZCZBIfg0CKxVOYErOhAAeoop4TZCV8ZCHOBSZA7iXaOi0G5pyTBlmeexLhR7yojPMz99dxjZAT7t7RDeZBDuoa9X4iZCWDBxYkdM00rBKFH6VGvCp42h",
  OWNER_PSID: "39911301058514741"
};


// Định nghĩa kiểu dữ liệu chuẩn TypeScript để triệt tiêu lỗi
interface OrderItem {
  [key: string]: number | string;
}

interface Order {
  id?: string;
  customerName?: string;
  phone?: string;
  deliveryDate?: string;
  totalAmount?: number;
  deposit?: number;
  items?: OrderItem;
  [key: string]: any;
}

interface StatusMessage {
  type: 'success' | 'error';
  text: string;
}

function NotificationPage() {
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState<StatusMessage | null>(null);
  
  const { data: orders } = useOrders();
  const typedOrders: Order[] = (orders as Order[]) || [];

  const getTodayOrders = (): Order[] => {
    return typedOrders; 
  };

  const buildOwnerReportMessage = (todayOrders: Order[]) => {
    const todayStr = new Date().toLocaleDateString('vi-VN');
    
    if (todayOrders.length === 0) {
      return `📅 BÁO CÁO ĐƠN BÁNH TẾT (${todayStr}):\nHôm nay chưa có đơn hàng nào được ghi nhận.`;
    }

    const productSummary: Record<string, number> = {};
    let totalRevenue = 0;
    let totalDeposit = 0;
    let totalRemaining = 0;

    const itemNameMap: Record<string, string> = {
      bc_thit: "Bánh Chưng Thịt Mỡ",
      bc_chay: "Bánh Chưng Chay",
      bc_thit_lon: "Bánh Chưng Thịt Mỡ (Lớn)",
      bc_chay_lon: "Bánh Chưng Chay (Lớn)",
      bt_thit: "Bánh Tét Thịt Mỡ",
      bt_ngot: "Bánh Tét Nhân Ngọt",
      bt_chay: "Bánh Tét Chay",
      bt_chuoi: "Bánh Tét Chuối",
    };

    todayOrders.forEach((order) => {
      const revenue = Number(order.totalAmount || 0);
      const deposit = Number(order.deposit || 0);
      const remaining = revenue - deposit;

      totalRevenue += revenue;
      totalDeposit += deposit;
      totalRemaining += remaining;

      if (order.items && typeof order.items === 'object') {
        Object.entries(order.items).forEach(([key, qty]) => {
          const readableName = itemNameMap[key] || key;
          productSummary[readableName] = (productSummary[readableName] || 0) + Number(qty || 0);
        });
      }
    });

    // Sửa lại format số lượng để không bị lỗi dính dấu sao * trên Messenger
    const summaryLines = Object.entries(productSummary)
      .map(([name, qty]) => `  • ${name}: *${qty} cái*`)
      .join('\n');

    const orderDetailLines = todayOrders
      .map((o, idx) => {
        const revenue = Number(o.totalAmount || 0);
        const deposit = Number(o.deposit || 0);
        const remaining = revenue - deposit;

        const itemsDesc = o.items && typeof o.items === 'object'
          ? Object.entries(o.items)
              .map(([key, qty]) => `${qty} ${itemNameMap[key] || key}`)
              .join(', ')
          : 'Không có chi tiết';

        return (
          `🔹 *${idx + 1}. ${o.customerName || 'Khách lẻ'}* (${o.phone || 'Chưa có SĐT'})\n` +
          `   - Đặt: ${itemsDesc}\n` +
          `   - Tiền: ${revenue.toLocaleString('vi-VN')}đ | Cọc: ${deposit.toLocaleString('vi-VN')}đ | Thu thêm: *${remaining.toLocaleString('vi-VN')}đ*`
        );
      })
      .join('\n\n');

    return (
      `🧧 *BÁO CÁO ĐƠN BÁNH TẾT VIỆT 2027* (${todayStr})\n` +
      `==============================\n` +
      `📦 *TỔNG SỐ LƯỢNG CẦN GÓI (${todayOrders.length} đơn):*\n` +
      `${summaryLines || '  (Chưa có sản phẩm)'}\n\n` +
      `💰 *Tổng doanh thu:* ${totalRevenue.toLocaleString('vi-VN')}đ\n` +
      `💵 *Tổng tiền cọc:* ${totalDeposit.toLocaleString('vi-VN')}đ\n` +
      `📥 *Cần thu thêm:* ${totalRemaining.toLocaleString('vi-VN')}đ\n` +
      `==============================\n` +
      `📋 *CHI TIẾT TỪNG ĐƠN HÀNG:*\n\n` +
      `${orderDetailLines}`
    );
  };

  const handleSendDirectFb = async () => {
    const todayOrders = getTodayOrders();
    const messageText = buildOwnerReportMessage(todayOrders);

    setLoading(true);
    setStatus(null);

    try {
      // Làm sạch token, loại bỏ khoảng trắng thừa nếu có lúc copy dán
      const cleanToken = (FB_CONFIG.PAGE_ACCESS_TOKEN || "").trim().replace(/\s+/g, '');
      const cleanPsid = (FB_CONFIG.OWNER_PSID || "").trim().replace(/\s+/g, '');
      const url = `https://graph.facebook.com/v21.0/me/messages?access_token=${encodeURIComponent(cleanToken)}`;

      const payload = {
        recipient: { id: cleanPsid },
        messaging_type: 'RESPONSE',
        message: { text: messageText },
      };

      const res = await fetch(url, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      const responseText = await res.text();
      console.log("Phản hồi thô từ Facebook:", responseText);

      let data;
      try {
        data = responseText ? JSON.parse(responseText) : {};
      } catch (e) {
        data = { error: { message: responseText || "Phản hồi trống từ Facebook" } };
      }

      if (res.ok && (data.message_id || data.recipient_id)) {
        setStatus({
          type: 'success',
          text: `✅ Đã gửi thành công báo cáo (${todayOrders.length} đơn)`,
        });
      } else {
        console.error('Lỗi chi tiết từ Facebook:', data);
        setStatus({
          type: 'error',
          text: `❌ Facebook từ chối: ${data?.error?.message || JSON.stringify(data)}`,
        });
      }
    } catch (error: any) {
      console.error('Lỗi kết nối mạng:', error);
      setStatus({ type: 'error', text: `❌ Lỗi kết nối mạng hoặc CORS: ${error?.message || error}` });
    } finally {
      setLoading(false);
    }
  };

  const todayCount = getTodayOrders().length;

  return (
    <div className="p-4 bg-amber-50/60 border border-amber-200 rounded-xl flex flex-col gap-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 className="font-bold text-gray-800">
            Báo cáo đơn hôm nay ({todayCount} đơn)
          </h3>
        </div>

        <button
          onClick={handleSendDirectFb}
          disabled={loading}
          className="px-4 py-2 bg-red-600 hover:bg-red-700 disabled:bg-red-300 text-white text-sm font-semibold rounded-lg shadow-sm transition-all cursor-pointer"
        >
          {loading ? 'Đang gửi...' : '🚀 Gửi thông báo'}
        </button>
      </div>

      {status && (
        <div
          className={`p-2.5 rounded-lg text-sm font-medium ${
            status.type === 'success'
              ? 'bg-green-100 text-green-800 border border-green-200'
              : 'bg-red-100 text-red-800 border border-red-200'
          }`}
        >
          {status.text}
        </div>
      )}
    </div>
  );
}

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: "/notification",
  component: NotificationPage,
});