import {
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import {
  inventoryApi,
  marketsApi,
  ordersApi,
  productionApi,
  productsApi,
  wholesaleApi,
} from "@/lib/api";
import type {
  Market,
  Order,
  Product,
  Wholesale,
} from "@/lib/types";

export const ordersQueryKey = ["orders"] as const;
export const productsQueryKey = ["products"] as const;
export const marketsQueryKey = ["markets"] as const;
export const wholesaleQueryKey = ["wholesale"] as const;
export const productionQueryKey = ["production"] as const;
export const inventoryQueryKey = ["inventory"] as const;

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

/* -------------------------------------------------------------------------- */
/*                          Mối chợ & bánh sỉ                                   */
/* -------------------------------------------------------------------------- */

export function useMarkets() {
  return useQuery({
    queryKey: marketsQueryKey,
    queryFn: marketsApi.list,
    staleTime: 5_000,
  });
}

export function useCreateMarket() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: marketsApi.create,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: marketsQueryKey });
    },
  });
}

export function useUpdateMarket() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: Partial<Market> }) =>
      marketsApi.update(id, payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: marketsQueryKey });
    },
  });
}

export function useDeleteMarket() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: marketsApi.remove,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: marketsQueryKey });
    },
  });
}

export function useWholesale() {
  return useQuery({
    queryKey: wholesaleQueryKey,
    queryFn: wholesaleApi.list,
    staleTime: 5_000,
  });
}

export function useCreateWholesale() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: wholesaleApi.create,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: wholesaleQueryKey });
    },
  });
}

export function useUpdateWholesale() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: Partial<Wholesale> }) =>
      wholesaleApi.update(id, payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: wholesaleQueryKey });
    },
  });
}

export function useDeleteWholesale() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: wholesaleApi.remove,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: wholesaleQueryKey });
    },
  });
}

/* -------------------------------------------------------------------------- */
/*                       Sản lượng & tồn kho gối đầu                             */
/* -------------------------------------------------------------------------- */

export function useProductions() {
  return useQuery({
    queryKey: productionQueryKey,
    queryFn: productionApi.list,
    staleTime: 5_000,
  });
}

export function useSaveProduction() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: productionApi.save,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: productionQueryKey });
    },
  });
}

export function useDeleteProduction() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: productionApi.remove,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: productionQueryKey });
    },
  });
}

export function useInventories() {
  return useQuery({
    queryKey: inventoryQueryKey,
    queryFn: inventoryApi.list,
    staleTime: 5_000,
  });
}

export function useSaveInventory() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: inventoryApi.save,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: inventoryQueryKey });
    },
  });
}

export function useDeleteInventory() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: inventoryApi.remove,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: inventoryQueryKey });
    },
  });
}
