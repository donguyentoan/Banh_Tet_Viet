import { createRoute } from "@tanstack/react-router";
import { Route as rootRoute } from "@/routes/__root";
import { useState } from "react";
import { useOrders } from "@/hooks/use-orders";

// Giữ nguyên FB_CONFIG theo yêu cầu của bạn
const FB_CONFIG = {
  PAGE_ACCESS_TOKEN: (import.meta.env as Record<string, any>).FB_PAGE_ACCESS_TOKEN || '',
  OWNER_PSID: (import.meta.env as Record<string, any>).FB_OWNER_PSID || ''
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

    const itemNameMap: Record<string, string> = {
      bc_chay: "Bánh Chưng Chay",
      bc_chay_lon: "Bánh Chưng Chay Lớn",
      bt_thit: "Bánh Tét Nhân Thịt",
      bt_chuoi: "Bánh Tét Chuối",
    };

    todayOrders.forEach((order) => {
      totalRevenue += Number(order.totalAmount || 0);
      totalDeposit += Number(order.deposit || 0);

      if (order.items && typeof order.items === 'object') {
        Object.entries(order.items).forEach(([key, qty]) => {
          const readableName = itemNameMap[key] || key;
          productSummary[readableName] = (productSummary[readableName] || 0) + Number(qty || 0);
        });
      }
    });

    const summaryLines = Object.entries(productSummary)
      .map(([name, qty]) => `  • ${name}: ${qty} cái`)
      .join('\n');

    const orderDetailLines = todayOrders
      .map((o, idx) => {
        const itemsDesc = o.items && typeof o.items === 'object'
          ? Object.entries(o.items)
              .map(([key, qty]) => `${qty} ${itemNameMap[key] || key}`)
              .join(', ')
          : '';

        return (
          `${idx + 1}. ${o.customerName || 'Khách lẻ'} (${o.phone || 'K SĐT'})\n` +
          `   - Đặt: ${itemsDesc}\n` +
          `   - Tiền: ${Number(o.totalAmount || 0).toLocaleString('vi-VN')}đ (Cọc: ${Number(o.deposit || 0).toLocaleString('vi-VN')}đ)`
        );
      })
      .join('\n');

    return (
      `🧧 BÁO CÁO ĐƠN BÁNH TẾT VIỆT (${todayStr})\n` +
      `==============================\n` +
      `📦 TỔNG SỐ LƯỢNG CẦN LÀM (${todayOrders.length} đơn):\n` +
      `${summaryLines || '  (Xem chi tiết bên dưới)'}\n\n` +
      `💰 Tổng tiền hàng: ${totalRevenue.toLocaleString('vi-VN')}đ\n` +
      `💵 Đã cọc: ${totalDeposit.toLocaleString('vi-VN')}đ\n` +
      `==============================\n` +
      `📋 CHI TIẾT TỪNG ĐƠN HÔM NAY:\n` +
      `${orderDetailLines}`
    );
  };

  const handleSendDirectFb = async () => {
    const todayOrders = getTodayOrders();
    const messageText = buildOwnerReportMessage(todayOrders);

    setLoading(true);
    setStatus(null);

    try {
      const cleanToken = FB_CONFIG.PAGE_ACCESS_TOKEN.trim().replace(/\s+/g, '');
      const url = `/fb-api/v21.0/me/messages?access_token=${encodeURIComponent(cleanToken)}`;

      const payload = {
        recipient: { id: FB_CONFIG.OWNER_PSID },
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

      const data = await res.json();

      if (res.ok && data.message_id) {
        setStatus({
          type: 'success',
          text: `✅ Đã gửi thành công báo cáo (${todayOrders.length} đơn) tới Messenger chủ lò! (ID: ${data.message_id})`,
        });
      } else {
        console.error('Lỗi từ Facebook:', data);
        setStatus({
          type: 'error',
          text: `❌ Facebook từ chối: ${data?.error?.message || JSON.stringify(data)}`,
        });
      }
    } catch (error: any) {
      console.error('Lỗi kết nối:', error);
      setStatus({ type: 'error', text: `❌ Lỗi kết nối mạng khi gọi Facebook API: ${error?.message || error}` });
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
            Báo cáo đơn hôm nay cho Chủ Lò ({todayCount} đơn)
          </h3>
          <p className="text-xs text-gray-600">
            Tự động tổng hợp số lượng bánh cần gói và gửi thẳng qua Messenger.
          </p>
        </div>

        <button
          onClick={handleSendDirectFb}
          disabled={loading}
          className="px-4 py-2 bg-red-600 hover:bg-red-700 disabled:bg-red-300 text-white text-sm font-semibold rounded-lg shadow-sm transition-all cursor-pointer"
        >
          {loading ? 'Đang gửi...' : '🚀 Gửi FB cho Chủ Lò'}
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