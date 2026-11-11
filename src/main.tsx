import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider } from "@tanstack/react-router";
import { Toaster } from "@/components/ui/sonner";
import { router } from "@/router";
import "./index.css";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

// Hàm khởi tạo OneSignal sử dụng biến toàn cục
const initOneSignal = async () => {
  // Đợi script trong index.html tải xong
  while (!(window as any).OneSignal) {
    await new Promise((resolve) => setTimeout(resolve, 100));
  }

  try {
    await (window as any).OneSignal.init({
      appId: '123ef950-72a8-48d2-8844-ecc890b91d00', // <-- Nhớ thay App ID của bạn vào đây
      allowLocalhostAsSecureOrigin: true,
      notifyButton: {
        enable: true,
      },
    });
    console.log("OneSignal initialized successfully via index.html");
  } catch (error) {
    console.error("OneSignal init failed:", error);
  }
};

// Gọi khởi tạo
initOneSignal();

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
      <Toaster position="bottom-right" richColors />
    </QueryClientProvider>
  </StrictMode>,
);