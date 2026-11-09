import { Outlet } from "@tanstack/react-router";
import { TetBanner } from "@/components/layout/tet-banner";
import { AppHeader } from "@/components/layout/app-header";
import { TabNav } from "@/components/layout/tab-nav";
import { AppFooter } from "@/components/layout/app-footer";

export function AppShell() {
  return (
    <div className="flex min-h-screen flex-col font-sans text-gray-800">
      <TetBanner />
      <AppHeader />
      <TabNav />
      <main className="mx-auto w-full flex-grow px-3 py-4 pb-6 sm:px-6 sm:py-6 sm:pb-6 lg:px-8">
        <Outlet />
      </main>
      <AppFooter />
    </div>
  );
}
