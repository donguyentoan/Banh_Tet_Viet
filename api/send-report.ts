import type { VercelRequest, VercelResponse } from '@vercel/node';
import fs from 'fs';
import path from 'path';

const FB_CONFIG = {
  PAGE_ACCESS_TOKEN: "EAAlzD2yepCEBSxRLZCwcee9Do079GfMusNBCxBrfYIO0DlHdDrka6agameW8dZCYOxOUyLdo1nWVxSiZBaWYZAybZCZBIfg0CKxVOYErOhAAeoop4TZCV8ZCHOBSZA7iXaOi0G5pyTBlmeexLhR7yojPMz99dxjZAT7t7RDeZBDuoa9X4iZCWDBxYkdM00rBKFH6VGvCp42h",
  OWNER_PSID: "39911301058514741"
};

export default async function handler(req: VercelRequest, res: VercelResponse) {
  try {
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
    let messageText = "";

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

    // Gửi request sang Facebook Graph API
    const cleanToken = (FB_CONFIG.PAGE_ACCESS_TOKEN || "").trim().replace(/\s+/g, '');
    const cleanPsid = (FB_CONFIG.OWNER_PSID || "").trim().replace(/\s+/g, '');
    const fbUrl = `https://graph.facebook.com/v21.0/me/messages?access_token=${encodeURIComponent(cleanToken)}`;
    
    const fbRes = await fetch(fbUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        recipient: { id: cleanPsid },
        messaging_type: 'RESPONSE',
        message: { text: messageText },
      }),
    });

    const fbData = await fbRes.json();
    if (!fbRes.ok) {
      throw new Error(JSON.stringify(fbData));
    }

    return res.status(200).json({ success: true, message: "Đã gửi báo cáo tự động lúc 14:00 thành công!" });
  } catch (error: any) {
    console.error("Lỗi Cron Job:", error);
    return res.status(500).json({ success: false, error: error?.message || error });
  }
}