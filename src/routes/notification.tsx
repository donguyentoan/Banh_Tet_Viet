import { createRoute } from "@tanstack/react-router";
import { Route as rootRoute } from "@/routes/__root";
import { useState } from "react";
import { useOrders } from "@/hooks/use-orders";

// Token đã được nối liền trên 1 dòng duy nhất, tuyệt đối không xuống dòng
const FB_CONFIG = {
  PAGE_ACCESS_TOKEN: import.meta.env.FB_PAGE_ACCESS_TOKEN,
  OWNER_PSID: import.meta.env.FB_OWNER_PSID
};

function NotificationPage() {
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState(null);
const { data: orders, isLoading, error } = useOrders();


const getTodayOrders = () => {
    // Tạm thời lấy tất cả đơn để test gửi tin nhắn bất cứ lúc nào bạn muốn
    return orders || []; 
    
    // Sau khi test xong, bạn có thể đổi lại điều kiện lọc theo ý muốn:
    // const todayStr = new Date().toISOString().split('T')[0]; 
    // return orders?.filter((order) => order.deliveryDate === todayStr) || [];
  };
  // Tổng hợp nội dung báo cáo gửi chủ lò phù hợp với cấu trúc items object
  const buildOwnerReportMessage = (todayOrders: any) => {
    const todayStr = new Date().toLocaleDateString('vi-VN');
    
    if (todayOrders.length === 0) {
      return `📅 BÁO CÁO ĐƠN BÁNH TẾT (${todayStr}):\nHôm nay chưa có đơn hàng nào được ghi nhận.`;
    }

    const productSummary = {};
    let totalRevenue = 0;
    let totalDeposit = 0;

    // Từ điển ánh xạ mã bánh sang tên hiển thị tiếng Việt (bạn có thể bổ sung thêm các mã khác)
    const itemNameMap = {
      bc_chay: "Bánh Chưng Chay",
      bc_chay_lon: "Bánh Chưng Chay Lớn",
      bt_thit: "Bánh Tét Nhân Thịt",
      bt_chuoi: "Bánh Tét Chuối",
      // Thêm các mã khác nếu có trong hệ thống của bạn
    };

    todayOrders.forEach((order) => {
      totalRevenue += Number(order.totalAmount || 0);
      totalDeposit += Number(order.deposit || 0);

      // Xử lý khi items là một Object (ví dụ: { bc_chay: 3, bc_chay_lon: 2 })
      if (order.items && typeof order.items === 'object') {
        Object.entries(order.items).forEach(([key, qty]) => {
          const readableName = itemNameMap[key] || key; // Lấy tên đẹp hoặc giữ nguyên mã nếu chưa map
          productSummary[readableName] = (productSummary[readableName] || 0) + Number(qty || 0);
        });
      }
    });

    const summaryLines = Object.entries(productSummary)
      .map(([name, qty]) => `  • ${name}: ${qty} cái`)
      .join('\n');

    const orderDetailLines = todayOrders
      .map((o, idx) => {
        // Gom danh sách bánh của từng đơn
        const itemsDesc = o.items && typeof o.items === 'object'
          ? Object.entries(o.items)
              .map(([key, qty]) => `${qty} ${itemNameMap[key] || key}`)
              .join(', ')
          : '';

        return (
          `${idx + 1}. ${o.customerName} (${o.phone || 'K SĐT'})\n` +
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
    } catch (error) {
      console.error('Lỗi kết nối:', error);
      setStatus({ type: 'error', text: '❌ Lỗi kết nối mạng khi gọi Facebook API.' });
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