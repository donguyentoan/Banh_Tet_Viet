import type { Order, Product } from "@/lib/types";
import { getRemaining } from "@/lib/format";

export function exportToCSV(orders: Order[], products: Product[]): void {
  if (orders.length === 0) {
    throw new Error("Không có dữ liệu đơn hàng để xuất!");
  }

  const productMap = new Map(products.map((p) => [p.id, p]));

  let csvContent = "data:text/csv;charset=utf-8,\uFEFF";
  csvContent +=
    "Ma Don,Khach Hang,So Dien Thoai,Dia Chi,Ngay Giao,San Pham,Tong Tien,Da Coc,Con Lai,Trang Thai,Ghi Chu\n";

  for (const order of orders) {
    const itemsText = Object.entries(order.items)
      .filter(([, qty]) => qty > 0)
      .map(([productId, qty]) => {
        const product = productMap.get(productId);
        const label = product ? product.name : productId;
        return `${label} x${qty}`;
      })
      .join(" | ");

    const row = [
      `"${order.id}"`,
      `"${order.customerName}"`,
      `"${order.phone}"`,
      `"${order.address.replace(/"/g, '""')}"`,
      `"${order.deliveryDate}"`,
      `"${itemsText.replace(/"/g, '""')}"`,
      order.totalAmount,
      order.deposit,
      getRemaining(order),
      `"${order.status}"`,
      `"${(order.notes ?? "").replace(/"/g, '""')}"`,
    ].join(",");
    csvContent += `${row}\n`;
  }

  const link = document.createElement("a");
  link.setAttribute("href", encodeURI(csvContent));
  link.setAttribute(
    "download",
    `Danh_Sach_Dat_Banh_Tet_2026_${new Date().toISOString().split("T")[0]}.csv`,
  );
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
}
