#!/usr/bin/env python3
"""
Server tĩnh đơn giản để test bản web Godot.

Cần header COOP/COEP vì bản web bật multithreading + extensions
(SharedArrayBuffer), nếu thiếu thì trình duyệt sẽ báo lỗi.

Dùng:
    python3 serve_web.py [port]
"""
import http.server
import socketserver
import sys
import os

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        # Bắt buộc cho SharedArrayBuffer (PWA + multithreading)
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("  %s\n" % (fmt % args))


if __name__ == "__main__":
    if not os.path.isdir(ROOT):
        print(f"Không thấy thư mục web: {ROOT}")
        sys.exit(1)
    socketserver.TCPServer.allow_reuse_address = True
    # Bind 0.0.0.0 để truy cập được từ mạng LAN / container / thiết bị khác
    with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
        print(f"🌺 Bánh Tết Việt 2027 (Godot Web)")
        print(f"   Đang chạy tại:  http://localhost:{PORT}")
        print(f"   Thư mục:       {ROOT}")
        print(f"   Nhấn Ctrl+C để dừng\n")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nĐã dừng.")
