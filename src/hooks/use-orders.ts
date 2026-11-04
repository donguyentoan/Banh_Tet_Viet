import {
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { ordersApi, productsApi } from "@/lib/api";
import type { Order, Product } from "@/lib/types";

export const ordersQueryKey = ["orders"] as const;
export const productsQueryKey = ["products"] as const;

export function useOrders() {
  return useQuery({
    queryKey: ordersQueryKey,
    queryFn: ordersApi.list,
    staleTime: 5_000,
  });
}

export function useCreateOrder() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ordersApi.create,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ordersQueryKey });
    },
  });
}

export function useUpdateOrder() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: Partial<Order> }) =>
      ordersApi.update(id, payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ordersQueryKey });
    },
  });
}

export function useDeleteOrder() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ordersApi.remove,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ordersQueryKey });
    },
  });
}

export function useProducts() {
  return useQuery({
    queryKey: productsQueryKey,
    queryFn: productsApi.list,
    staleTime: 5_000,
  });
}

export function useCreateProduct() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: productsApi.create,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: productsQueryKey });
    },
  });
}

export function useUpdateProduct() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: Partial<Product> }) =>
      productsApi.update(id, payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: productsQueryKey });
    },
  });
}

export function useDeleteProduct() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: productsApi.remove,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: productsQueryKey });
    },
  });
}
