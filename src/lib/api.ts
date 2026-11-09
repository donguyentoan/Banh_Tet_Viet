import type {
  Inventory,
  Market,
  Order,
  Product,
  Production,
  Wholesale,
} from "@/lib/types";

const ORDERS_URL = "/api/orders";
const PRODUCTS_URL = "/api/products";
const MARKETS_URL = "/api/markets";
const WHOLESALE_URL = "/api/wholesale";
const PRODUCTION_URL = "/api/production";
const INVENTORY_URL = "/api/inventory";

async function request<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...init?.headers,
    },
  });

  if (!response.ok) {
    let message = `Lỗi ${response.status}`;
    try {
      const body = (await response.json()) as { message?: string };
      if (body?.message) message = body.message;
    } catch {
      /* ignore non-json error body */
    }
    throw new Error(message);
  }

  return (await response.json()) as T;
}

export const ordersApi = {
  list: () => request<Order[]>(ORDERS_URL),

  create: (payload: Omit<Order, "id" | "createdAt">) =>
    request<Order>(ORDERS_URL, {
      method: "POST",
      body: JSON.stringify(payload),
    }),

  update: (id: string, payload: Partial<Omit<Order, "id">>) =>
    request<Order>(`${ORDERS_URL}/${encodeURIComponent(id)}`, {
      method: "PUT",
      body: JSON.stringify(payload),
    }),

  remove: (id: string) =>
    request<Order>(`${ORDERS_URL}/${encodeURIComponent(id)}`, {
      method: "DELETE",
    }),
};

export const productsApi = {
  list: () => request<Product[]>(PRODUCTS_URL),

  create: (payload: Omit<Product, "id">) =>
    request<Product>(PRODUCTS_URL, {
      method: "POST",
      body: JSON.stringify(payload),
    }),

  update: (id: string, payload: Partial<Omit<Product, "id">>) =>
    request<Product>(`${PRODUCTS_URL}/${encodeURIComponent(id)}`, {
      method: "PUT",
      body: JSON.stringify(payload),
    }),

  remove: (id: string) =>
    request<Product>(`${PRODUCTS_URL}/${encodeURIComponent(id)}`, {
      method: "DELETE",
    }),
};

/* -------------------------------------------------------------------------- */
/*                          Mối chợ & bánh sỉ                                   */
/* -------------------------------------------------------------------------- */

export const marketsApi = {
  list: () => request<Market[]>(MARKETS_URL),

  create: (payload: Omit<Market, "id">) =>
    request<Market>(MARKETS_URL, {
      method: "POST",
      body: JSON.stringify(payload),
    }),

  update: (id: string, payload: Partial<Omit<Market, "id">>) =>
    request<Market>(`${MARKETS_URL}/${encodeURIComponent(id)}`, {
      method: "PUT",
      body: JSON.stringify(payload),
    }),

  remove: (id: string) =>
    request<Market>(`${MARKETS_URL}/${encodeURIComponent(id)}`, {
      method: "DELETE",
    }),
};

export const wholesaleApi = {
  list: () => request<Wholesale[]>(WHOLESALE_URL),

  create: (payload: Omit<Wholesale, "id" | "createdAt">) =>
    request<Wholesale>(WHOLESALE_URL, {
      method: "POST",
      body: JSON.stringify(payload),
    }),

  update: (id: string, payload: Partial<Omit<Wholesale, "id">>) =>
    request<Wholesale>(`${WHOLESALE_URL}/${encodeURIComponent(id)}`, {
      method: "PUT",
      body: JSON.stringify(payload),
    }),

  remove: (id: string) =>
    request<Wholesale>(`${WHOLESALE_URL}/${encodeURIComponent(id)}`, {
      method: "DELETE",
    }),
};

/* -------------------------------------------------------------------------- */
/*                       Sản lượng & tồn kho gối đầu                             */
/* -------------------------------------------------------------------------- */

export const productionApi = {
  list: () => request<Production[]>(PRODUCTION_URL),

  save: (payload: { date: string; items: Record<string, number>; notes?: string }) =>
    request<Production>(PRODUCTION_URL, {
      method: "POST",
      body: JSON.stringify(payload),
    }),

  remove: (id: string) =>
    request<Production>(`${PRODUCTION_URL}/${encodeURIComponent(id)}`, {
      method: "DELETE",
    }),
};

export const inventoryApi = {
  list: () => request<Inventory[]>(INVENTORY_URL),

  save: (payload: { date: string; items: Record<string, number> }) =>
    request<Inventory>(INVENTORY_URL, {
      method: "POST",
      body: JSON.stringify(payload),
    }),

  remove: (id: string) =>
    request<Inventory>(`${INVENTORY_URL}/${encodeURIComponent(id)}`, {
      method: "DELETE",
    }),
};
