import { createRoute } from "@tanstack/react-router";
import { Route as rootRoute } from "@/routes/__root";
import { CreateOrderPage } from "@/pages/create-order-page";

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: "/order",
  component: CreateOrderPage,
});
