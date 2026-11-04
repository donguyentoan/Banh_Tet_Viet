import type { Order, Product } from "@/lib/types";

const ORDERS_URL = "/api/orders";
const PRODUCTS_URL = "/api/products";

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
