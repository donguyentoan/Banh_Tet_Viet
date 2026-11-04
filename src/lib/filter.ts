import { PRODUCT_CATEGORIES } from "@/lib/constants";
import type { Order, Product } from "@/lib/types";
import type { FiltersState } from "@/stores/bakery-store";

export function applyFilters(
  orders: Order[],
  filters: FiltersState,
  products: Product[],
): Order[] {
  const keyword = filters.search.toLowerCase().trim();
  const productMap = new Map(products.map((p) => [p.id, p]));

  const filtered = orders.filter((order) => {
    const matchSearch =
      order.customerName.toLowerCase().includes(keyword) ||
      order.phone.includes(keyword) ||
      order.id.toLowerCase().includes(keyword);

    const matchStatus = filters.status === "ALL" || order.status === filters.status;
    const matchDate =
      filters.deliveryDate === "ALL" || order.deliveryDate === filters.deliveryDate;

    let matchCake = true;
    if (filters.cake !== "ALL") {
      matchCake = Object.entries(order.items).some(([productId, qty]) => {
        if (qty <= 0) return false;
        return productMap.get(productId)?.category === filters.cake;
      });
    }

    return matchSearch && matchStatus && matchDate && matchCake;
  });

  return filtered.sort((a, b) => {
    switch (filters.sort) {
      case "OLDEST":
        return a.id.localeCompare(b.id);
      case "URGENT":
        return a.deliveryDate.localeCompare(b.deliveryDate);
      case "NEWEST":
      default:
        return b.id.localeCompare(a.id);
    }
  });
}

export { PRODUCT_CATEGORIES };
