import { VercelRequest, VercelResponse } from '@vercel/node';
import fs from 'fs';
import path from 'path';
import { updateOrder } from '@/hooks/useOrder';
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, message: 'Method not allowed' });
  }

  try {
    const webhookData = req.body;
    
    // Lấy đúng tên trường transferAmount từ SePay JSON
    const { transferAmount, content } = webhookData;

    if (!content) {
      return res.status(400).json({ success: false, message: 'Invalid content' });
    }

    // Cập nhật Regex để bắt cả chữ và số sau chữ TET (Ví dụ: TETTB2027004 -> bắt được "TB2027004" hoặc "TB2027004")
    // Hoặc nếu mã đơn của bạn dạng TET + [Chữ/Số], dùng: /TET([A-Za-z0-9]+)/i
    const match = content.match(/TET([A-Za-z0-9]+)/i);
    if (!match) {
      return res.status(200).json({ success: true, message: 'Không tìm thấy mã đơn hàng phù hợp, bỏ qua.' });
    }

    const orderId = match[1]; // Sẽ bắt được "TB2027004" (hoặc điều chỉnh lại nếu bạn muốn lấy trọn gói "TETTB2027004")

    // Đọc file orders.json
    const filePath = path.join(process.cwd(), 'data', 'orders.json');
    if (fs.existsSync(filePath)) {
      const fileData = fs.readFileSync(filePath, 'utf8');
      let orders = JSON.parse(fileData);

      let orderFound = false;
      orders = orders.map((order: any) => {
        // So khớp orderId trong file json (hỗ trợ cả dạng id số hoặc mã đơn dạng string)
        if (order.id == orderId || order.orderId == orderId || order.code == `TET${orderId}`) {
          orderFound = true;
          order.status = 'PAID';
          order.paidAmount = transferAmount; // Gán đúng số tiền chuyển khoản
          order.paidAt = new Date().toISOString();
        }
        return order;
      });

      updateOrder.mutate(
        { id: orderId, payload: { status: 'PAID', paidAmount: transferAmount, paidAt: new Date().toISOString() } },
        {
          onSuccess: () => {
            return res.status(200).json({ success: true, message: `Đã cập nhật đơn hàng #${orderId}` });
          },
          onError: (err: any) => {
            return res.status(500).json({ success: false, error: err.message });
          },
        },
      );

      if (orderFound) {
        fs.writeFileSync(filePath, JSON.stringify(orders, null, 2), 'utf8');
      }
    }
  } catch (error: any) {
    console.error('SePay Webhook Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
}