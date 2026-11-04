import { Outlet } from "@tanstack/react-router";
import { TetBanner } from "@/components/layout/tet-banner";
import { AppHeader } from "@/components/layout/app-header";
import { AppFooter } from "@/components/layout/app-footer";

export function AppShell() {
  return (
    <div className="flex min-h-screen flex-col font-sans text-gray-800">
      <TetBanner />
      <AppHeader />
      <main className="mx-auto w-full  flex-grow px-4 py-6 sm:px-6 lg:px-8">
        <Outlet />
      </main>
      <AppFooter />
    </div>
  );
}
