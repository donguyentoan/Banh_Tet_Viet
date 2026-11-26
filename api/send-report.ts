import type { VercelRequest, VercelResponse } from '@vercel/node';
import fs from 'fs';
import path from 'path';

/**
 * Cron job: gửi báo cáo đơn hàng đến Messenger của chủ shop.
 *
 * Token Facebook đọc từ biến môi trường trên Vercel:
 *   FB_PAGE_ACCESS_TOKEN - Page Access Token (EAA...)
 *   FB_OWNER_PSID        - PSID của người nhận
 *
 * File này chạy ở phía SERVER (Vercel Function) nên đọc process.env an toàn -
 * token không bị đóng gói vào bundle trình duyệt.
 */

function getFbConfig() {
  const pageAccessToken = (process.env.FB_PAGE_ACCESS_TOKEN || "").trim().replace(/\s+/g, '');
  const ownerPsid = (process.env.FB_OWNER_PSID || "").trim().replace(/\s+/g, '');

  if (!pageAccessToken || !ownerPsid) {
    const missing = [
      !pageAccessToken ? "FB_PAGE_ACCESS_TOKEN" : null,
      !ownerPsid ? "FB_OWNER_PSID" : null,
    ].filter(Boolean).join(", ");
    throw new Error(
      `Thiếu biến môi trường: ${missing}. ` +
        `Hãy thêm trong Vercel > Settings > Environment Variables rồi redeploy.`
    );
  }

  return { pageAccessToken, ownerPsid };
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  try {
    // Nếu client gửi kèm nội dung tin nhắn thì dùng luôn, ngược lại tự
    // dựng báo cáo từ data/orders.json (dùng cho cron job).
    const requestedMessage =
      typeof req.body?.message === "string" ? req.body.message.trim() : "";

    let messageText = requestedMessage;

    if (!messageText) {
      // Đọc trực tiếp file orders.json từ thư mục data nhờ cấu hình includeFiles trong vercel.json
      const filePath = path.join(process.cwd(), 'data', 'orders.json');
      let todayOrders = [];

      if (fs.existsSync(filePath)) {
        const fileData = fs.readFileSync(filePath, 'utf8');
        const jsonData = JSON.parse(fileData);
        // Lọc hoặc lấy danh sách đơn hàng (tùy thuộc cấu trúc json của bạn là mảng hay object chứa orders)
        todayOrders = Array.isArray(jsonData) ? jsonData : (jsonData.orders || []);
      }

      const todayStr = new Date().toLocaleDateString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' });

      if (todayOrders.length === 0) {
        messageText = `📅 BÁO CÁO ĐƠN BÁNH TẾT (${todayStr}):\nHôm nay chưa có đơn hàng nào được ghi nhận.`;
      } else {
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

        todayOrders.forEach((order: any) => {
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

        const summaryLines = Object.entries(productSummary)
          .map(([name, qty]) => `  • ${name}: *${qty} cái*`)
          .join('\n');

        const orderDetailLines = todayOrders
          .map((o: any, idx: number) => {
            const revenue = Number(o.totalAmount || 0);
            const deposit = Number(o.deposit || 0);
            const remaining = revenue - deposit;
            const itemsDesc = o.items && typeof o.items === 'object'
              ? Object.entries(o.items).map(([key, qty]) => `${qty} ${itemNameMap[key] || key}`).join(', ')
              : 'Không có chi tiết';

            return `🔹 *${idx + 1}. ${o.customerName || 'Khách lẻ'}* (${o.phone || 'Chưa có SĐT'})\n   - Đặt: ${itemsDesc}\n   - Tiền: ${revenue.toLocaleString('vi-VN')}đ | Cọc: ${deposit.toLocaleString('vi-VN')}đ | Thu thêm: *${remaining.toLocaleString('vi-VN')}đ*`;
          })
          .join('\n\n');

        messageText = `🧧 *BÁO CÁO ĐƠN BÁNH TẾT VIỆT 2027* (${todayStr})\n==============================\n📦 *TỔNG SỐ LƯỢNG CẦN GÓI (${todayOrders.length} đơn):*\n${summaryLines}\n\n💰 *Tổng doanh thu:* ${totalRevenue.toLocaleString('vi-VN')}đ\n💵 *Tổng tiền cọc:* ${totalDeposit.toLocaleString('vi-VN')}đ\n📥 *Cần thu thêm:* ${totalRemaining.toLocaleString('vi-VN')}đ\n==============================\n📋 *CHI TIẾT TỪNG ĐƠN HÀNG:*\n\n${orderDetailLines}`;
      }
    }

    // Gửi request sang Facebook Graph API
    const { pageAccessToken, ownerPsid } = getFbConfig();
    const fbUrl = `https://graph.facebook.com/v21.0/me/messages?access_token=${encodeURIComponent(pageAccessToken)}`;

    const fbRes = await fetch(fbUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        recipient: { id: ownerPsid },
        messaging_type: 'RESPONSE',
        message: { text: messageText },
      }),
    });

    const fbData = await fbRes.json();
    if (!fbRes.ok) {
      throw new Error(JSON.stringify(fbData));
    }

    return res.status(200).json({ success: true, message: "Đã gửi báo cáo thành công!" });
  } catch (error: any) {
    console.error("Lỗi Cron Job:", error);
    return res.status(500).json({ success: false, error: error?.message || error });
  }
}