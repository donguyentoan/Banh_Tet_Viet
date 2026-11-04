import { createRootRoute } from "@tanstack/react-router";
import { AppShell } from "@/components/layout/app-shell";

export const Route = createRootRoute({
  component: AppShell,
});

export type RootRoute = typeof Route;
