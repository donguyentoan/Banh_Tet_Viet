import { createRouter } from "@tanstack/react-router";
import { Route as rootRoute } from "@/routes/__root";
import { Route as indexRoute } from "@/routes/index";
import { Route as orderRoute } from "@/routes/order";

export const router = createRouter({
  routeTree: rootRoute.addChildren([indexRoute, orderRoute]),
  defaultPreload: "intent",
});

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}
