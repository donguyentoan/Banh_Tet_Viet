import { createRoute } from "@tanstack/react-router";
import { Route as rootRoute } from "@/routes/__root";
import { OrdersPage } from "@/pages/orders-page";

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: "/",
  component: OrdersPage,
});
