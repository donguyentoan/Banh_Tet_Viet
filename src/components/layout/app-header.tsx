import { useEffect, useState } from "react";
import { FileSpreadsheet, LayoutList, LockKeyhole, LogOut, PlusCircle } from "lucide-react";
import { useNavigate } from "@tanstack/react-router";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { useOrders, useProducts } from "@/hooks/use-orders";
import { exportToCSV } from "@/lib/export";
import type { Order, Product } from "@/lib/types";

/** Mảng rỗng ổn định - tránh tạo reference mới mỗi render */
const EMPTY_ORDERS: Order[] = [];
const EMPTY_PRODUCTS: Product[] = [];

export function AppHeader() {
  const navigate = useNavigate();
  const { data: orders } = useOrders();
  const { data: products } = useProducts();

  const ordersData = orders ?? EMPTY_ORDERS;
  const productsData = products ?? EMPTY_PRODUCTS;

  const [isAdmin, setIsAdmin] = useState(false);
  const [loginOpen, setLoginOpen] = useState(false);
  const [password, setPassword] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [authError, setAuthError] = useState("");

  useEffect(() => {
    void fetch("/api/auth/session")
      .then((response) => response.json() as Promise<{ authenticated?: boolean }>)
      .then((result) => setIsAdmin(Boolean(result.authenticated)))
      .catch(() => setIsAdmin(false));
  }, []);

  async function handleAdminLogin(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSubmitting(true);
    setAuthError("");
    try {
      const response = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ password }),
      });
      const result = (await response.json()) as { message?: string; authenticated?: boolean };
      if (!response.ok) throw new Error(result.message ?? "Không đăng nhập được");
      setIsAdmin(Boolean(result.authenticated));
      setPassword("");
      setLoginOpen(false);
      toast.success("Đã mở quyền quản trị trong phiên này");
    } catch (error) {
      setAuthError(error instanceof Error ? error.message : "Không đăng nhập được");
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleAdminLogout() {
    try {
      await fetch("/api/auth/logout", { method: "POST" });
      setIsAdmin(false);
      toast.success("Đã đăng xuất quản trị");
    } catch {
      toast.error("Không thể đăng xuất. Vui lòng tải lại trang.");
    }
  }

  function handleExport() {
    try {
      exportToCSV(ordersData, productsData);
      toast.success("Đã tải xuống file CSV đơn hàng thành công!");
    } catch (error) {
      toast.warning(
        error instanceof Error ? error.message : "Không thể xuất dữ liệu đơn hàng",
      );
    }
  }

  return (
    <header className="no-print sticky top-0 z-30 border-b border-amber-200 bg-white shadow-sm">
      <div className="mx-auto flex w-full flex-wrap items-center justify-between gap-2 px-3 py-2.5 sm:gap-4 sm:px-6 sm:py-3.5 lg:px-8">
        <div className="flex items-center space-x-3">
          <div className="flex size-10 items-center justify-center rounded-xl border-2 border-amber-400 bg-gradient-to-tr from-emerald-700 to-emerald-500 text-xl sm:size-12 sm:text-2xl text-white shadow-md">
            🍃
          </div>
          <div>
            <h1 className="flex items-center gap-2 text-sm font-extrabold leading-tight text-red-700 sm:text-xl md:text-2xl">
              BÁNH TẾT VIỆT 2027
              <span className="hidden rounded-full border border-amber-300 bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-800 sm:inline-flex">
                Xuân Đinh Mùi
              </span>
            </h1>
            <p className="hidden text-xs font-medium text-gray-500 sm:block">
              Hệ thống quản lý đặt Bánh Chưng &amp; Bánh Tét gia truyền
            </p>
          </div>
        </div>

        <div className="hidden items-center justify-end space-x-3 sm:flex sm:w-auto">
          <Button
            variant="outline"
            onClick={handleExport}
            className="gap-2 border-amber-300 bg-amber-50 text-amber-800 shadow-sm hover:bg-amber-100 hover:text-amber-900"
          >
            <FileSpreadsheet className="size-4 text-emerald-600" />
            Xuất Excel
          </Button>
          <Button
            variant="outline"
            onClick={() => navigate({ to: "/" })}
            className="gap-2 border-amber-300 bg-amber-50 text-amber-800 shadow-sm hover:bg-amber-100 hover:text-amber-900"
          >
            <LayoutList className="size-4 text-emerald-600" />
            Danh Sách
          </Button>
          <Button
            onClick={() => navigate({ to: "/order" })}
            className="gap-2 bg-gradient-to-r from-red-600 to-red-700 font-bold text-white shadow-md transition hover:-translate-y-0.5 hover:from-red-700 hover:to-red-800 hover:shadow-lg"
          >
            <PlusCircle className="size-4 text-amber-300" />
            Tạo Đơn Hàng Mới
          </Button>
        </div>
        {!import.meta.env.DEV && <div className="shrink-0">
          {isAdmin ? (
            <Button variant="outline" size="sm" onClick={handleAdminLogout} className="gap-1.5 border-amber-300 text-amber-900">
              <LogOut className="size-3.5" />
              Thoát quản trị
            </Button>
          ) : (
            <Button variant="outline" size="sm" onClick={() => setLoginOpen(true)} className="gap-1.5 border-red-200 text-red-700">
              <LockKeyhole className="size-3.5" />
              Quản trị
            </Button>
          )}
        </div>}
      </div>

      <Dialog open={loginOpen} onOpenChange={setLoginOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Đăng nhập quản trị</DialogTitle>
            <DialogDescription>Đăng nhập để tạo, sửa hoặc xoá dữ liệu trên hệ thống.</DialogDescription>
          </DialogHeader>
          <form onSubmit={handleAdminLogin} className="space-y-3">
            <Input
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              placeholder="Mật khẩu quản trị"
              required
              autoFocus
            />
            {authError && <p role="alert" className="text-sm font-medium text-red-700">{authError}</p>}
            <Button type="submit" disabled={isSubmitting || !password} className="w-full bg-red-700 text-white hover:bg-red-800">
              {isSubmitting ? "Đang xác thực…" : "Đăng nhập"}
            </Button>
          </form>
        </DialogContent>
      </Dialog>
    </header>
  );
}
