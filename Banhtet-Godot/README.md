# 🌺 Bánh Tết Việt 2027 — Ứng dụng Android (Godot Engine)

Bản chuyển đổi của web app **Quản lý bánh Tết 2027** (`src/` React/Vite) sang
**Godot 4.3** để chạy native trên Android.

---

## 1. Tính năng đã port

| Màn hình | Nội dung |
|---|---|
| **📋 Đơn Hàng** | 4 thẻ thống kê, tìm kiếm + lọc (trạng thái / loại / khoảng ngày), danh sách phiếu, xem chi tiết, **in phiếu qua Bluetooth** (máy in nhiệt 76mm) |
| **🛒 Tạo Đơn** | Form đầy đủ + ô **"Ghi Nhận Nhanh"** (parse tin nhắn tự do), bộ chọn số lượng tăng/giảm, tự tính tiền, lưu đơn |
| **🏪 Mối Chợ** | Quản lý điểm bán sỉ (CRUD), lịch giao hàng sỉ theo ngày |
| **🏭 Cân Đối** | Bảng cân đối sản xuất ↔ nhu cầu, nhập tồn kho đầu kỳ, tính tồn kho cuối kỳ |

### Đồng bộ dữ liệu với web (dùng chung API)

App gọi **chung API của web app** qua `ApiClient`:

```
base_url = https://banh-tet-viet.vercel.app/api
```

| Collection | Endpoint |
|---|---|
| Đơn hàng | `/api/orders` |
| Sản phẩm | `/api/products` |
| Mối chợ | `/api/markets` |
| Bán sỉ | `/api/wholesale` |
| Sản xuất | `/api/production` |
| Tồn kho | `/api/inventory` |

Các thao tác ghi (POST/PUT/DELETE) cần cookie phiên quản trị (`tet_admin`).
App hiện màn hình **đăng nhập bằng mật khẩu quản trị** khi bấm nút ⟳ đồng bộ.

Ngoài ra app có **cache cục bộ** tại `user://bakery_cache.json` để mở app
vẫn thấy dữ liệu gần nhất khi mất mạng.

---

## 2. Cấu trúc thư mục

```
Banhtet-Godot/
├── project.godot            # Cấu hình project (portrait 390x844, GL Compatibility)
├── export_presets.cfg       # Cấu hình export Android (arm64-v8a)
├── keystore/                # Keystore ký app (đổi mật khẩu trước khi phát hành!)
├── data/                    # Dữ liệu mẫu / fallback offline
│   ├── products.json  orders.json  markets.json
│   └── wholesale.json  production.json  inventory.json
├── assets/                  # Icon + hình bánh
├── scene/
│   ├── Main.tscn            # Scene chính (App shell)
│   └── tinh_nang/           # 4 màn hình tính năng
│       ├── OrdersScreen.gd
│       ├── CreateOrderScreen.gd
│       ├── WholesaleScreen.gd
│       └── AnalyticsScreen.gd
└── script/
    ├── main.gd              # App shell: header + tab bar + điều hướng
    ├── api_client.gd        # HTTP client + quản lý cookie phiên
    ├── bakery_store.gd      # Store trạng thái + cache + CRUD
    ├── banh_tet.gd          # Hằng số, format tiền/ngày
    ├── ui_theme.gd          # Theme Tết (đỏ-vàng)
    ├── quick_parse.gd       # Parse tin nhắn tự do -> đơn hàng
    ├── production_calc.gd   # Thuật toán cân đối sản xuất
    └── bluetooth_printer.gd # Sinh lệnh ESC/POS 76mm
```

---

## 3. Ô "Ghi Nhận Nhanh" — Parse tin nhắn

Dán vào ô **"Ghi Nhận Nhanh"** một tin nhắn tự do, app tự điền form:

```
chị Lan 0912345678 5 bánh chưng mặn ngày 28 Tết địa chỉ: 12 Nguyễn Huệ, Q1
```

→ Tên: `chị Lan` · ĐT: `0912345678` · Địa chỉ: `12 Nguyễn Huệ, Q1`
· Ngày: `28 Tết` (04/02/2027) · Số lượng: `5 bánh chưng mặn`

Hỗ trợ:

- Mã sản phẩm: `2 CM`, `1 CC`, `3cm`, `2tmc`
- Tên tự nhiên: `5 bánh chưng mặn`, `3 bánh chưng chay`, `2 bánh tét ngọt`
- Số từ: `hai bánh chưng`
- Ngày: `28 Tết`, `03/02/2027`
- Giờ: `8 giờ sáng`, `chiều`, `20h tối`
- Địa chỉ: `địa chỉ:`, `ở tại`, `dc:`

---

## 4. In phiếu Bluetooth (máy in nhiệt 76mm)

`script/bluetooth_printer.gd` sinh mã lệnh **ESC/POS** thuần:

- Cỡ giấy **76mm**, font chữ 1:1, không dùng table view (gọn 1 trang)
- Tự ngắt trang theo **42 dòng/trang**
- Lệnh: `GS !` (cỡ chữ), `ESC E` (đậm), `ESC a` (căn), `GS V 0` (cắt giấy)

Trên desktop (chạy test) sẽ báo **không có Bluetooth** và fallback sang in file.
Trên Android cần:

1. Bật **Bluetooth** và cấp quyền
2. Kết nối máy in trước (Android 13+ dùng được hệ thống, hoặc app tự ghép nối)
3. Bấm **🖨️ In phiếu** trên chi tiết đơn

---

## 5. Build APK cho Android

### 5.1. Yêu cầu (đã cài sẵn trên máy này)

| Thành phần | Phiên bản | Vị trí |
|---|---|---|
| Godot | 4.3.stable | `/tmp/Godot.app` |
| Export templates | 4.3.stable | `~/Library/Application Support/Godot/export_templates/4.3.stable` |
| JDK | 17 (Zulu) | `~/Library/Java/JavaVirtualMachines/azul-17.0.21/Contents/Home` |
| Android SDK | cmdline-tools + build-tools 34 + platform 34 | `~/Library/Android/sdk` |

> **Lưu ý:** `project.godot` phải có dòng
> `rendering/textures/vram_compression/import_etc2_astc=true`.
> Godot 4.3 **từ chối xuất Android** nếu thiếu dòng này (báo lỗi
> `configuration errors` với danh sách lỗi **rỗng** — rất dễ gây nhầm).

### 5.2. Build bằng dòng lệnh

```bash
cd "Quản lý bánh tết 2027/Banhtet-Godot"

# Bản debug
/tmp/Godot.app/Contents/MacOS/Godot --headless --path . \
  --export-debug "Android" build/Banhtet-2027-debug.apk

# Bản release (đã ký)
export ANDROID_HOME=~/Library/Android/sdk
export JAVA_HOME=~/Library/Java/JavaVirtualMachines/azul-17.0.21/Contents/Home
/tmp/Godot.app/Contents/MacOS/Godot --headless --path . \
  --export-release "Android" build/Banhtet-2027.apk
```

### 5.3. Build bằng giao diện Godot

1. Mở Godot 4.3 → **Import** → chọn `project.godot` trong `Banhtet-Godot/`
2. **Project → Export…** → chọn preset **Android** → **Export Project**
3. Chọn thư mục `build/` → chờ xong → có file `.apk`

### 5.4. Cài lên điện thoại

```bash
~/Library/Android/sdk/platform-tools/adb install -r build/Banhtet-2027.apk
```

Hoặc chép file `.apk` sang máy Android và mở (cần bật "Cài đặt ứng dụng lạ").

### 5.5. File APK đã build sẵn

| File | Dung lượng | Mô tả |
|---|---|---|
| `build/Banhtet-2027.apk` | 22 MB | **Bản release**, đã ký với keystore release, tối ưu cho phát hành |
| `build/Banhtet-2027-debug.apk` | 23 MB | Bản debug, để test nhanh |

Thông tin bản release đã verify:

```
package: com.quanlybanhtet2027.app  versionCode 1  versionName 1.0.0
minSdk 21 (Android 5.0)   targetSdk 34 (Android 14)
compileSdk 34   abi: arm64-v8a
Chữ ký: v1 ✓  v2 ✓  v3 ✓  (CN=Banh Tet Viet 2027)
```

---

## 6. Đổi API server

Mặc định trỏ tới `https://banh-tet-viet.vercel.app/api`.
Đổi trong `script/api_client.gd`:

```gdscript
var base_url := "https://banh-tet-viet.vercel.app/api"
```

Sau khi đổi phải **build lại APK**.

---

## 7. Lưu ý phát hành

- **Keystore KHÔNG được commit lên git** (đã thêm `keystore/` vào `.gitignore`).
  Nếu bạn clone repo trên máy khác, phải tạo keystore riêng:
  ```bash
  keytool -keyalg RSA -keysize 2048 -validity 10000 -genkeypair \
    -alias banhtet2027 -keystore keystore/banhtet-release.keystore \
    -storepass <MAT_KHAU> -keypass <MAT_KHAU> \
    -dname "CN=Banh Tet Viet 2027, O=Banh Tet Viet, C=VN"
  ```
  rồi sửa `keystore/release_user` và `keystore/release_password` trong
  `export_presets.cfg` cho khớp.
  **Mất keystore = không thể cập nhật app đã phát hành.**
- `package/unique_name` trong `export_presets.cfg`:
  `com.quanlybanhtet2027.app` — nên đổi thành domain riêng của bạn
  (không thể đổi sau khi đã publish lên Google Play).
- App dùng `gl_compatibility` renderer để chạy được trên máy cũ.
- Mật khẩu quản trị nằm trong Vercel Environment Variables
  (`ADMIN_PASSWORD`, `ADMIN_SESSION_SECRET`), không có trong repo.

---

## 8. Chạy test

```bash
# Parse tin nhắn
/tmp/Godot.app/Contents/MacOS/Godot --headless --path . --script test_scene.gd
cat /tmp/qp.txt

# Smoke test toàn app
/tmp/Godot.app/Contents/MacOS/Godot --headless --path . --script smoke_test.gd
cat /tmp/smoke.txt
```

---

## 9. Bản web chạy bằng Docker

```bash
cd Banhtet-Godot
docker compose up -d --build     # -> http://localhost:8080
```

- `Dockerfile`: stage 1 dùng `barichello/godot-ci:4.3` export preset **Web**,
  stage 2 là nginx phục vụ `build/web` (kèm header COOP/COEP).
- `docker/nginx.conf` proxy `/api/*` -> `https://banh-tet-viet.vercel.app/api/*`
  để API **cùng origin**: trình duyệt tự giữ cookie `tet_admin` (JS không đọc được
  `Set-Cookie`), `api_client.gd` tự dùng `window.location.origin + "/api"` khi chạy web.
- Font `assets/fonts/NotoColorEmoji.ttf` được gắn làm font dự phòng để emoji
  hiển thị trên trình duyệt giống trên Android.
