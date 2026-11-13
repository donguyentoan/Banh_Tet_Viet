import { createRouter } from "@tanstack/react-router";
import { Route as rootRoute } from "@/routes/__root";
import { Route as indexRoute } from "@/routes/index";
import { Route as orderRoute } from "@/routes/order";
import { Route as wholesaleRoute } from "@/routes/wholesale";
import { Route as analyticsRoute } from "@/routes/analytics";
import { Route as notificationRoute } from "@/routes/notification";
export const router = createRouter({
  routeTree: rootRoute.addChildren([
    indexRoute,
    orderRoute,
    wholesaleRoute,
    analyticsRoute,
    notificationRoute,
  ]),
  defaultPreload: "intent",
});

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}
