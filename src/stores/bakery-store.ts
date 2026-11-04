import { create } from "zustand";
import type { OrderStatus } from "@/lib/types";

export type SortOption = "NEWEST" | "OLDEST" | "URGENT";

export interface FiltersState {
  search: string;
  status: OrderStatus | "ALL";
  cake: "ALL" | "CHUNG" | "TET";
  deliveryDate: string;
  sort: SortOption;
}

export interface UIState {
  filters: FiltersState;
  editingOrderId: string | null;
  detailOrderId: string | null;
  isFormOpen: boolean;
  isDetailOpen: boolean;
}

interface BakeryStore extends UIState {
  setSearch: (search: string) => void;
  setStatusFilter: (status: FiltersState["status"]) => void;
  setCakeFilter: (cake: FiltersState["cake"]) => void;
  setDeliveryDateFilter: (deliveryDate: string) => void;
  setSort: (sort: SortOption) => void;
  resetFilters: () => void;

  openCreateForm: () => void;
  openEditForm: (orderId: string) => void;
  closeForm: () => void;
  openDetail: (orderId: string) => void;
  closeDetail: () => void;
}

export const DEFAULT_FILTERS: FiltersState = {
  search: "",
  status: "ALL",
  cake: "ALL",
  deliveryDate: "ALL",
  sort: "NEWEST",
};

export const useBakeryStore = create<BakeryStore>((set) => ({
  filters: { ...DEFAULT_FILTERS },
  editingOrderId: null,
  detailOrderId: null,
  isFormOpen: false,
  isDetailOpen: false,

  setSearch: (search) =>
    set((state) => ({ filters: { ...state.filters, search } })),

  setStatusFilter: (status) =>
    set((state) => ({ filters: { ...state.filters, status } })),

  setCakeFilter: (cake) =>
    set((state) => ({ filters: { ...state.filters, cake } })),

  setDeliveryDateFilter: (deliveryDate) =>
    set((state) => ({ filters: { ...state.filters, deliveryDate } })),

  setSort: (sort) => set((state) => ({ filters: { ...state.filters, sort } })),

  resetFilters: () => set({ filters: { ...DEFAULT_FILTERS } }),

  openCreateForm: () =>
    set({ isFormOpen: true, editingOrderId: null, isDetailOpen: false }),

  openEditForm: (orderId) =>
    set({ isFormOpen: true, editingOrderId: orderId, isDetailOpen: false }),

  closeForm: () => set({ isFormOpen: false, editingOrderId: null }),

  openDetail: (orderId) =>
    set({ isDetailOpen: true, detailOrderId: orderId }),

  closeDetail: () => set({ isDetailOpen: false, detailOrderId: null }),
}));
