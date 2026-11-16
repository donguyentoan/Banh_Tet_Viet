import { VercelRequest, VercelResponse } from '@vercel/node';
import { get, put } from '@vercel/blob';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, message: 'Method not allowed' });
  }

  try {
    const webhookData = req.body;
    const { transferAmount, content } = webhookData;

    if (!content) {
      return res.status(400).json({ success: false, message: 'Invalid content' });
    }

    // Bắt mã đơn hàng sau chữ TET (Ví dụ: TETTB2027004 -> "TB2027004")
    const match = content.match(/TET([A-Za-z0-9]+)/i);
    if (!match) {
      return res.status(200).json({ success: true, message: 'Không tìm thấy mã đơn hàng phù hợp, bỏ qua.' });
    }

    const rawOrderId = match[1]; // "TB2027004"
    const normalizedRaw = rawOrderId.replace(/-/g, '').toUpperCase();

    // 1. Lấy file orders.json từ Vercel Blob (giả định đường dẫn blob là 'orders.json' hoặc URL tương ứng)
    // Nếu bạn lưu đường dẫn dạng tên file trong store, hãy truyền đúng path/url của Blob.
    const blobPath = 'orders.json'; 
    let orders: any[] = [];
    let blobExists = false;

    try {
      const blobResponse = await get(blobPath, { access: 'public' });
      if (blobResponse && blobResponse.url) {
        const fetchRes = await fetch(blobResponse.url);
        if (fetchRes.ok) {
          orders = await fetchRes.json();
          blobExists = true;
        }
      }
    } catch (err) {
      console.log('Chưa tìm thấy file orders.json trên Vercel Blob, sẽ tạo mới nếu cần.');
    }

    let orderFound = false;
    orders = orders.map((order: any) => {
      const orderIdInFile = (order.id || order.orderId || order.code || '').toString();
      const normalizedFileId = orderIdInFile.replace(/-/g, '').toUpperCase();

      // So khớp linh hoạt giữa "TB2027-004" và "TB2027004"
      if (normalizedFileId.includes(normalizedRaw) || normalizedRaw.includes(normalizedFileId)) {
        orderFound = true;
        order.status = 'Đã giao'; // Hoặc 'Đã giao' tùy ý bạn
        order.paidAmount = transferAmount;
        order.paidAt = new Date().toISOString();
      }
      return order;
    });

    if (orderFound) {
      // 2. Ghi đè lại file orders.json lên Vercel Blob
      await put(blobPath, JSON.stringify(orders, null, 2), {
        access: 'public',
        contentType: 'application/json',
        addRandomSuffix: false, // Giữ nguyên tên file không bị sinh hash ngẫu nhiên phía sau
      });
      console.log(`Đã cập nhật thành công đơn hàng khớp với: ${rawOrderId}`);
    } else {
      console.log(`Không tìm thấy order khớp với: ${rawOrderId}`);
      return res.status(200).json({ success: true, message: 'Không tìm thấy đơn hàng tương ứng trong hệ thống.' });
    }

    return res.status(200).json({ success: true, message: 'Webhook processed and Blob updated successfully' });
  } catch (error: any) {
    console.error('SePay Webhook Vercel Blob Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
}