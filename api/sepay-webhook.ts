import { VercelRequest, VercelResponse } from '@vercel/node';
import fs from 'fs';
import path from 'path';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  // SePay gọi webhook bằng phương thức POST
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, message: 'Method not allowed' });
  }

  try {
    const webhookData = req.body;
    
    /* Cấu trúc dữ liệu SePay gửi sang:
      {
        id: 12345,
        gateway: "VCB",
        transactionDate: "2026-11-14 14:30:00",
        accountNumber: "...",
        subAccount: null,
        amountIn: 500000, // Số tiền khách chuyển
        amountOut: 0,
        accumulated: 10000000,
        code: "TET123", // Nội dung chuyển khoản khớp với cú pháp
        content: "Chuyen tien mua banh tet TET123",
        referenceCode: "...",
        description: "..."
      }
    */

    const { amountIn, content, code } = webhookData;

    // 1. Kiểm tra bảo mật (Tùy chọn: Bạn có thể cài đặt thêm SePay API Token Header nếu muốn bảo mật tuyệt đối)
    // const authHeader = req.headers.authorization;
    // if (authHeader !== `Apikey TOKEN_CUA_BAN`) return res.status(401).json({ error: 'Unauthorized' });

    if (!content) {
      return res.status(400).json({ success: false, message: 'Invalid content' });
    }

    // 2. Trích xuất mã đơn hàng từ nội dung chuyển khoản (Ví dụ tìm chuỗi "TET<orderId>")
    const match = content.match(/TET(\d+)/i);
    if (!match) {
      return res.status(200).json({ success: true, message: 'Không tìm thấy mã đơn hàng phù hợp, bỏ qua.' });
    }

    const orderId = match[1];

    // 3. Đọc file orders.json để cập nhật trạng thái đơn hàng thành "Đã thanh toán"
    const filePath = path.join(process.cwd(), 'data', 'orders.json');
    if (fs.existsSync(filePath)) {
      const fileData = fs.readFileSync(filePath, 'utf8');
      let orders = JSON.parse(fileData);

      // Cập nhật trạng thái đơn hàng
      let orderFound = false;
      orders = orders.map((order: any) => {
        if (order.id == orderId || order.orderId == orderId) {
          orderFound = true;
          order.status = 'Đã giao'; // Đã thanh toán
          order.paidAmount = amountIn;
          order.paidAt = new Date().toISOString();
        }
        return order;
      });

      if (orderFound) {
        fs.writeFileSync(filePath, JSON.stringify(orders, null, 2), 'utf8');
        
        // (Tùy chọn) Trigger gửi thông báo về Facebook/Zalo ngay tại đây nếu muốn!
      }
    }

    return res.status(200).json({ success: true, message: 'Webhook processed successfully' });
  } catch (error: any) {
    console.error('SePay Webhook Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
}