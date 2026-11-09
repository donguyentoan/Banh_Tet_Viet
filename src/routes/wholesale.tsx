import { createRoute } from "@tanstack/react-router";
import { Route as rootRoute } from "@/routes/__root";
import { WholesalePage } from "@/pages/wholesale-page";

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: "/wholesale",
  component: WholesalePage,
});
