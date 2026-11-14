#!/bin/bash
#
# Chạy bản web Bánh Tết Việt 2027 (Godot) để test trên trình duyệt.
#
#   ./run_web.sh          -> http://localhost:8080
#   ./run_web.sh 9000     -> http://localhost:9000
#
# Giữ cửa sổ terminal này mở trong khi test. Nhấn Ctrl+C để dừng.

PORT="${1:-8080}"
DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_DIR="$DIR/build/web"

if [ ! -f "$WEB_DIR/index.html" ]; then
    echo "❌ Chưa có bản build web. Đang build..."
    GODOT="/tmp/Godot.app/Contents/MacOS/Godot"
    if [ ! -x "$GODOT" ]; then
        echo "❌ Không tìm thấy Godot tại $GODOT"
        echo "   Hãy mở Godot 4.3 → Project → Export → Web → Export Project"
        exit 1
    fi
    mkdir -p "$WEB_DIR"
    "$GODOT" --headless --path "$DIR" --export-debug "Web" "$WEB_DIR/index.html" 2>&1 | tail -5
fi

# Giải phóng port cũ nếu còn
if lsof -ti:$PORT >/dev/null 2>&1; then
    lsof -ti:$PORT | xargs kill -9 2>/dev/null
    sleep 1
fi

IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")

echo ""
echo "  🌺 Bánh Tết Việt 2027 — bản web (Godot 4.3)"
echo "  ─────────────────────────────────────────────"
echo "  Máy này:    http://localhost:$PORT"
if [ -n "$IP" ]; then
    echo "  Điện thoại: http://$IP:$PORT    (cùng WiFi)"
fi
echo "  ─────────────────────────────────────────────"
echo "  Nhấn Ctrl+C để dừng server"
echo ""

exec python3 "$DIR/serve_web.py" "$PORT"
