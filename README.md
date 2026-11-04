# 🍃 Bánh Tết Việt 2026 — Hệ thống quản lý đặt Bánh Chưng & Bánh Tét

Chuyển đổi từ file `quanlybanh.html` (single-file vanilla JS + localStorage) sang stack **React + TypeScript + Vite**, dữ liệu lưu trong **file JSON**.

## Stack

| Công nghệ | Vai trò |
|---|---|
| Vite 8 + React 19 + TypeScript | Bundler / framework |
| TanStack Router | Routing (`/` + root layout) |
| TanStack Query | Fetch + cache + mutation (invalidate sau mỗi write) |
| Zustand | State UI: bộ lọc, mở/đóng modal, chỉnh sửa & xem chi tiết |
| Zod | Schema validation cho cả form lẫn dữ liệu từ API |
| React Hook Form + `@hookform/resolvers/zod` | Quản lý form modal Thêm/Sửa |
| shadcn/ui (Base UI) | Button, Card, Input, Select, Dialog, Badge, Table, Sonner… |
| Tailwind CSS v4 | Styling, giữ nguyên bộ màu Tết từ file gốc |

## Chạy dự án

```bash
npm install
npm run dev        # http://localhost:5173
```

| Script | Mô tả |
|---|---|
| `npm run dev` | Dev server + JSON REST API |
| `npm run build` | Typecheck (`tsc -b`) + build production |
| `npm run preview` | Chạy bản build (kèm JSON API) |
| `npm test` | Chạy test (Vitest + Testing Library) |
| `npm run lint` | Oxlint |

## Lưu trữ dữ liệu bằng file JSON

Dữ liệu nằm ở:

- [`data/orders.json`](./data/orders.json) — danh sách đơn hàng
- [`data/products.json`](./data/products.json) — danh mục loại bánh

Vite có plugin middleware tự viết trong [`vite.config.ts`](./vite.config.ts) expose các file này thành REST API nhỏ:

```
GET    /api/orders      → danh sách đơn        POST   /api/orders      → tạo đơn
PUT    /api/orders/:id  → cập nhật             DELETE /api/orders/:id  → xoá

GET    /api/products    → danh mục bánh        POST   /api/products    → thêm loại bánh
PUT    /api/products/:id→ cập nhật             DELETE /api/products/:id→ xoá
```

Plugin hoạt động ở cả `vite dev` và `vite preview`, đọc/ghi file bằng `node:fs`.

> **Lưu ý triển khai production:** middleware này chỉ chạy trong Vite dev/preview server.
> Khi deploy production, cần đưa API sang backend thật (Express/NestJS/Hono…) hoặc
> serverless function đọc/ghi cùng định dạng file JSON.

## Cấu trúc

```
bakery-app/
├─ data/
│  ├─ orders.json          # dữ liệu đơn hàng
│  └─ products.json        # danh mục loại bánh
├─ vite.config.ts          # plugin JSON API + alias @ → src
├─ vitest.config.ts
└─ src/
   ├─ components/
   │  ├─ layout/             # banner đếm ngược Tết, header, footer, shell
   │  ├─ dashboard/          # 4 thẻ số liệu tổng quan
   │  ├─ orders/             # toolbar lọc, card grid, form dialog, receipt dialog, add product dialog
   │  └─ ui/                 # shadcn/ui components
   ├─ hooks/use-orders.ts    # TanStack Query hooks (orders + products)
   ├─ lib/                   # types + Zod schema, api client, format, filter, stats, export
   ├─ pages/orders-page.tsx  # trang chính
   ├─ routes/                # TanStack Router route tree
   ├─ stores/bakery-store.ts # Zustand store
   └─ router.tsx / main.tsx
```

## Đối chiếu với file gốc

Giữ nguyên 100% UI và nghiệp vụ của `quanlybanh.html`:

- Banner đếm ngược Tết, header sticky, footer đỏ-vàng
- 4 thẻ dashboard: Tổng đơn / Tổng số bánh (Chưng–Tét) / Doanh thu + cọc / Cần giao + đang nấu
- Toolbar: tìm kiếm (tên, SĐT, mã đơn) + lọc trạng thái / loại bánh / ngày giao + sắp xếp
- Card view dạng lưới với đổi trạng thái inline, sửa, xoá, xem chi tiết
- Modal thêm/sửa: thông tin khách → chọn bánh (nút +/−) → ngày/giờ/trạng thái → tính tiền → ghi chú
- Phiếu đặt bánh in được (có chữ ký 2 bên), xuất CSV

### Điểm đã cải thiện so với bản gốc

1. **Mã đơn không còn trùng** — API tính `max(seq) + 1` từ file thay vì `orders.length + 1`.
2. **Sắp xếp đúng thứ tự** — dùng `localeCompare` thay vì so sánh chuỗi thô (`TB2026-010` trước `TB2026-002` trong bản gốc).
3. **In chỉ phiếu** — thêm `@media print` ẩn dashboard/banner/header/footer, chỉ in `#print-area`.
4. **Validation thật** — Zod chặn SĐT sai định dạng, địa chỉ quá ngắn, đơn không có bánh nào.
5. **Không còn innerHTML** — toàn bộ render bằng React, không có rủi ro XSS.
# Banh_Tet_Viet
