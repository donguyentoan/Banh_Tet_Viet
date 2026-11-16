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

    const blobPath = 'orders.json'; 
    let fileJsonData: any = null;
    let orders: any[] = [];

    try {
      const blobResponse = await get(blobPath, { access: 'public' });
      if (blobResponse && blobResponse.url) {
        const fetchRes = await fetch(blobResponse.url);
        if (fetchRes.ok) {
          fileJsonData = await fetchRes.json();
          
          // Xử lý linh hoạt cấu trúc file: có thể là Array trực tiếp hoặc Object chứa mảng (VD: { orders: [...] })
          if (Array.isArray(fileJsonData)) {
            orders = fileJsonData;
          } else if (fileJsonData && Array.isArray(fileJsonData.orders)) {
            orders = fileJsonData.orders;
          } else if (fileJsonData && Array.isArray(fileJsonData.data)) {
            orders = fileJsonData.data;
          }
        }
      }
    } catch (err) {
      console.log('Lỗi khi đọc file orders.json từ Vercel Blob:', err);
    }

    let orderFound = false;
    
    // Duyệt qua danh sách đơn hàng và so sánh chuẩn hóa (bỏ dấu gạch ngang, upper case)
    orders = orders.map((order: any) => {
      // Hỗ trợ kiểm tra các trường id, orderId, hoặc code
      const orderIdInFile = (order.id || order.orderId || order.code || '').toString();
      const normalizedFileId = orderIdInFile.replace(/-/g, '').toUpperCase();

      if (normalizedFileId === normalizedRaw || normalizedFileId.includes(normalizedRaw) || normalizedRaw.includes(normalizedFileId)) {
        orderFound = true;
        order.status = 'Đã thanh toán'; // Cập nhật trạng thái đơn
        order.paidAmount = transferAmount;
        order.paidAt = new Date().toISOString();
      }
      return order;
    });

    if (orderFound) {
      // Giữ nguyên cấu trúc dữ liệu ban đầu của file khi ghi ngược lại lên Vercel Blob
      let dataToSave: any = orders;
      if (!Array.isArray(fileJsonData)) {
        if (fileJsonData && typeof fileJsonData === 'object') {
          if (Array.isArray(fileJsonData.orders)) {
            fileJsonData.orders = orders;
          } else if (Array.isArray(fileJsonData.data)) {
            fileJsonData.data = orders;
          }
          dataToSave = fileJsonData;
        }
      }

      await put(blobPath, JSON.stringify(dataToSave, null, 2), {
        access: 'public',
        contentType: 'application/json',
        addRandomSuffix: false,
      });

      console.log(`Đã cập nhật thành công đơn hàng khớp với mã: ${rawOrderId}`);
      return res.status(200).json({ success: true, message: 'Webhook processed and order updated successfully' });
    } else {
      console.log(`Không tìm thấy đơn hàng nào khớp với mã: ${rawOrderId}`);
      return res.status(200).json({ success: true, message: 'Không tìm thấy đơn hàng tương ứng trong hệ thống.' });
    }

  } catch (error: any) {
    console.error('SePay Webhook Vercel Blob Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
}