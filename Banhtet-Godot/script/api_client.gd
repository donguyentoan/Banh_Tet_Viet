class_name ApiClient
extends Node

## Client HTTP gọi trực tiếp API của web app (Vercel) để đồng bộ dữ liệu.
##
## API dùng cookie phiên quản trị (`tet_admin`) cho mọi thao tác ghi.
## Vì Godot không tự quản lý cookie, ta lưu cookie phiên vào bộ nhớ và
## gửi kèm header `Cookie` cho mọi request.

signal request_failed(message: String)

const COLLECTIONS: Array[String] = [
	"orders", "products", "markets", "wholesale", "production", "inventory",
]

## Địa chỉ API - đổi theo môi trường deploy thật
var base_url := "https://banh-tet-viet.vercel.app/api"

## Cookie phiên quản trị (lấy từ màn hình đăng nhập)
var session_cookie := ""

var _http := HTTPRequest.new()


func _ready() -> void:
	add_child(_http)
	# Bản web: gọi API cùng origin (nginx proxy /api -> Vercel) để trình duyệt
	# tự quản lý cookie phiên (JS không đọc/gửi được header Cookie).
	if OS.has_feature("web"):
		var origin = JavaScriptBridge.eval("window.location.origin")
		if origin is String and origin != "":
			base_url = origin + "/api"


## Đặt URL API (dùng khi cài app với server khác)
func configure(url: String) -> void:
	base_url = url.rstrip("/")


## Đăng nhập quản trị bằng mật khẩu, lưu cookie phiên để dùng cho các request ghi
func login(password: String) -> bool:
	var body := JSON.stringify({"password": password})
	var headers: Array[String] = ["Content-Type: application/json"]
	var response := await send_request("POST", "/auth/login", headers, body)
	if response.get("status", 0) != 200:
		return false
	if OS.has_feature("web"):
		# Trình duyệt giữ cookie HttpOnly, Godot không đọc được Set-Cookie
		session_cookie = "browser"
		return true
	var cookies := str(response.get("cookies", ""))
	if cookies != "":
		session_cookie = cookies.split(";")[0]
		return true
	return false


## Đăng xuất
func logout() -> bool:
	var response := await send_request("POST", "/auth/logout", ["Content-Type: application/json"], "")
	if response.get("status", 0) == 200:
		session_cookie = ""
		return true
	return false


## Kiểm tra phiên đăng nhập còn hiệu lực không
func check_session() -> bool:
	var response := await send_request("GET", "/auth/session", [], "")
	var data = response.get("data", {})
	if data is Dictionary:
		return bool(data.get("authenticated", false))
	return false


## Lấy danh sách một collection
func list_collection(collection: String) -> Array:
	var response := await send_request("GET", "/" + collection, [], "")
	if response.get("status", 0) != 200:
		return []
	var data = response.get("data", [])
	return data if data is Array else []


## Tạo mới một bản ghi
func create(collection: String, payload: Dictionary) -> Dictionary:
	var response := await send_request(
		"POST", "/" + collection, ["Content-Type: application/json"], JSON.stringify(payload)
	)
	if response.get("status", 0) not in [200, 201]:
		return {}
	var data = response.get("data", {})
	return data if data is Dictionary else {}


## Cập nhật một bản ghi
func update(collection: String, id: String, payload: Dictionary) -> Dictionary:
	var response := await send_request(
		"PUT",
		"/%s/%s" % [collection, id.uri_encode()],
		["Content-Type: application/json"],
		JSON.stringify(payload)
	)
	if response.get("status", 0) != 200:
		return {}
	var data = response.get("data", {})
	return data if data is Dictionary else {}


## Xoá một bản ghi
func remove(collection: String, id: String) -> bool:
	var response := await send_request(
		"DELETE", "/%s/%s" % [collection, id.uri_encode()], [], ""
	)
	return response.get("status", 0) == 200


## Gửi một HTTP request và trả về { status, data, cookies, error }
func send_request(
	method: String, path: String, headers: Array[String], body: String
) -> Dictionary:
	var url := base_url + path
	# HTTPRequest.request_headers yêu cầu PackedStringArray (không phải Array[String])
	var all_headers := PackedStringArray()
	for h in headers:
		all_headers.append(h)
	if session_cookie != "" and not OS.has_feature("web"):
		all_headers.append("Cookie: " + session_cookie)

	_http.timeout = 20.0

	var http_method := HTTPClient.METHOD_GET
	match method:
		"POST":
			http_method = HTTPClient.METHOD_POST
		"PUT":
			http_method = HTTPClient.METHOD_PUT
		"DELETE":
			http_method = HTTPClient.METHOD_DELETE

	# Godot 4: request(url, custom_headers, method, body)
	# Phải truyền all_headers vì tham số này GHI ĐÈ request_headers.
	var error := _http.request(url, all_headers, http_method, body)
	if error != OK:
		return {"status": 0, "data": {}, "cookies": "", "error": "Không gửi được yêu cầu"}

	var result: Array = await _http.request_completed
	var response_code: int = result[1]
	var raw_body: PackedByteArray = result[3]
	var response_headers: PackedStringArray = result[2]

	var cookies := ""
	for header in response_headers:
		if header.to_lower().begins_with("set-cookie:"):
			var value := header.split(":", true, 1)[1].strip_edges()
			if not value.is_empty():
				cookies = value.split(";")[0]
			break

	var parsed = {}
	if raw_body.size() > 0:
		var text := raw_body.get_string_from_utf8()
		var json = JSON.parse_string(text)
		if json != null:
			parsed = json

	if response_code >= 400:
		var message = "Lỗi %d" % response_code
		if parsed is Dictionary and parsed.has("message"):
			message = str(parsed["message"])
		request_failed.emit(str(message))
		return {"status": response_code, "data": parsed, "cookies": cookies, "error": message}

	return {"status": response_code, "data": parsed, "cookies": cookies, "error": ""}
