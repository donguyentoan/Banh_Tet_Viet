class_name BluetoothPrinter
extends Node

## In phiếu đặt bánh qua Bluetooth (máy in nhiệt 76mm) từ Android.
##
## Cách hoạt động:
## 1. Tạo một `BluetoothServerSocket` RFCOMM (UUID SPP chuẩn 00001101-0000-1000-8000-00805F9B34FB).
## 2. App đóng vai "server": máy in (đã bật chế độ nhận SPP / "Bluetooth Printer") kết nối vào.
## 3. Gửi dữ liệu ESC/POS (mã máy in nhiệt 76mm) theo kích thước khổ giấy 76mm.
##
## Trên Android cần các quyền sau trong export preset:
##   android.permission.BLUETOOTH_CONNECT
##   android.permission.BLUETOOTH_SCAN
##   android.permission.BLUETOOTH_ADVERTISE
##   android.permission.ACCESS_FINE_LOCATION (Android <= 11)

signal printer_status(message: String)
signal print_progress(current: int, total: int)

## Số dòng mà 1 trang giấy nhiệt 76mm chứa được
const LINES_PER_PAGE := 42

var _server: Object = null
var _client: Object = null
var _is_printing := false
var _current_page := 0
var _total_pages := 0


## Kiểm tra thiết bị có hỗ trợ Bluetooth không
func is_bluetooth_available() -> bool:
	if not OS.has_feature("mobile"):
		return false
	return ClassDB.class_exists("BluetoothServerSocket")


## Bắt đầu lắng nghe kết nối từ máy in
func start_listening() -> void:
	if not is_bluetooth_available():
		printer_status.emit("Thiết bị này không hỗ trợ Bluetooth")
		return

	stop_listening()

	_server = ClassDB.instantiate("BluetoothServerSocket")
	if _server == null:
		printer_status.emit("Không khởi tạo được BluetoothServerSocket")
		return

	var error: int = _server.listen(1)
	if error != OK:
		printer_status.emit("Không mở được cổng Bluetooth (mã %d)" % error)
		return

	printer_status.emit("Đang chờ máy in kết nối...")


## Dừng lắng nghe
func stop_listening() -> void:
	if _client != null:
		_client.close()
		_client = null
	if _server != null:
		_server.stop()
		_server = null


## Chấp nhận kết nối từ máy in
func _process(_delta: float) -> void:
	if _server == null or _client != null:
		return
	if not _server.is_connection_available():
		return
	_client = _server.take_connection()
	if _client == null:
		return
	printer_status.emit("Đã kết nối máy in")
	_client.connect("disconnected", _on_disconnected)


func _on_disconnected() -> void:
	_client = null
	printer_status.emit("Máy in đã ngắt kết nối")


## Gửi dữ liệu thô tới máy in
func _send_bytes(data: PackedByteArray) -> bool:
	if _client == null:
		printer_status.emit("Chưa kết nối máy in")
		return false
	_client.put_data(data)
	return true


## In một phiếu đặt bánh.
## `order` là dict đơn hàng, `products` là danh sách sản phẩm.
func print_order(order: Dictionary, products: Array) -> void:
	if _is_printing:
		return
	_is_printing = true

	var lines := _build_receipt(order, products)
	_total_pages = int(ceil(float(lines.size()) / float(LINES_PER_PAGE)))
	_current_page = 0

	for chunk in _paginate(lines, LINES_PER_PAGE):
		_current_page += 1
		print_progress.emit(_current_page, _total_pages)

		var payload := _escpos_init()
		for line in chunk:
			payload += _line_to_bytes(line)
		# Cắt giấy + 3 dòng trống cuối phiếu
		payload += PackedByteArray([0x1B, 0x64, 0x03])  # feed 3 lines
		payload += PackedByteArray([0x1D, 0x56, 0x00])  # cut paper

		if not _send_bytes(payload):
			_is_printing = false
			return

	_is_printing = false
	printer_status.emit("Đã in xong phiếu (%d trang)" % _total_pages)


## Chia danh sách dòng thành các trang
func _paginate(lines: Array, per_page: int) -> Array:
	var pages: Array = []
	var current: Array = []
	for line in lines:
		current.append(line)
		if current.size() >= per_page:
			pages.append(current)
			current = []
	if current.size() > 0:
		pages.append(current)
	return pages


## Khởi tạo máy in (ESC/POS)
func _escpos_init() -> PackedByteArray:
	var data := PackedByteArray()
	data.append(0x1B)  # ESC
	data.append(0x40)  # @ - initialize
	return data


## Chuyển 1 dòng text (kèm style) thành bytes
func _line_to_bytes(line: Dictionary) -> PackedByteArray:
	var data := PackedByteArray()
	var style := str(line.get("style", ""))
	var text := str(line.get("text", ""))

	var bold := 1 if style.contains("bold") else 0
	var double_h := 1 if style.contains("double") else 0
	var center := 1 if style.contains("center") else 0
	var right := 1 if style.contains("right") else 0

	var width_scale := 1
	var height_scale := 1
	if double_h:
		width_scale = 2
		height_scale = 2

	# Font size: GS !
	data.append(0x1D)
	data.append(0x21)
	data.append((height_scale - 1) << 4 | (width_scale - 1))

	# Bold: ESC E
	data.append(0x1B)
	data.append(0x45)
	data.append(bold)

	# Căn lề: ESC a
	data.append(0x1B)
	data.append(0x61)
	data.append(1 if center else (2 if right else 0))

	data.append_array(text.to_utf8_buffer())

	# Xuống dòng
	data.append(0x0A)

	# Reset style
	data.append(0x1B)
	data.append(0x61)
	data.append(0)
	data.append(0x1B)
	data.append(0x45)
	data.append(0)

	return data


## Dựng nội dung phiếu (danh sách các dòng có style)
func _build_receipt(order: Dictionary, products: Array) -> Array:
	var lines: Array = []
	var product_map := {}
	for p in products:
		product_map[p.get("id", "")] = p

	# --- Tiêu đề ---
	lines.append({"text": "PHIEU DAT BANH TET", "style": "bold,double,center"})
	lines.append({"text": "2027", "style": "bold,double,center"})
	lines.append({"text": "Banh Chung - Banh Tet Gia Truyen", "style": "center"})
	lines.append({"text": "", "style": ""})
	lines.append({"text": "--------------------------------", "style": ""})

	# --- Mã đơn + ngày ---
	lines.append({"text": "Ma don: #%s" % str(order.get("id", "")), "style": "bold"})
	lines.append({
		"text": "Ngay giao: %s" % BanhTet.format_date_display(str(order.get("deliveryDate", ""))),
		"style": "",
	})
	lines.append({"text": "--------------------------------", "style": ""})

	# --- Khách hàng ---
	lines.append({"text": "Khach hang: %s" % str(order.get("customerName", "")), "style": "bold"})
	lines.append({"text": "SĐT: %s" % str(order.get("phone", "")), "style": "bold"})
	lines.append({"text": "Dia chi: %s" % str(order.get("address", "")), "style": ""})
	lines.append({"text": "Giao luc: %s" % str(order.get("deliveryTime", "")), "style": "bold"})
	lines.append({
		"text": "Trang thai: %s" % str(
			BanhTet.STATUS_LABELS.get(str(order.get("status", "")), str(order.get("status", "")))
		),
		"style": "",
	})
	lines.append({"text": "--------------------------------", "style": ""})

	# --- Sản phẩm ---
	lines.append({"text": "SAN PHAM DA DAT", "style": "bold,center"})
	lines.append({"text": "--------------------------------", "style": ""})

	var items = order.get("items", {})
	for product_id in items:
		var qty := int(items[product_id])
		if qty <= 0:
			continue
		var product = product_map.get(product_id, null)
		if product == null:
			continue
		lines.append({
			"text": "%s  x%d" % [str(product.get("name", "")), qty],
			"style": "bold",
		})
		lines.append({
			"text": "   %s/cai    %s" % [
				BanhTet.format_money(int(product.get("price", 0))),
				BanhTet.format_money(int(product.get("price", 0)) * qty),
			],
			"style": "",
		})

	lines.append({"text": "--------------------------------", "style": ""})

	# --- Tổng tiền ---
	var total := int(order.get("totalAmount", 0))
	var deposit := int(order.get("deposit", 0))
	lines.append({"text": "Tong tien banh: %s" % BanhTet.format_money(total), "style": ""})
	lines.append({"text": "Da dat coc truoc: -%s" % BanhTet.format_money(deposit), "style": ""})
	lines.append({
		"text": "CON LAI KHI GIAO: %s" % BanhTet.format_money(total - deposit),
		"style": "bold,double",
	})
	lines.append({"text": "--------------------------------", "style": ""})

	var notes := str(order.get("notes", ""))
	if not notes.is_empty():
		lines.append({"text": "Ghi chu: %s" % notes, "style": ""})
		lines.append({"text": "--------------------------------", "style": ""})

	# --- Chữ ký ---
	lines.append({"text": "NGUOI DAT BANH      BANH TET GIA TRUYEN", "style": "bold"})
	lines.append({"text": "", "style": ""})
	lines.append({"text": "    (Ky)                (Dau)", "style": ""})
	lines.append({"text": "", "style": ""})
	lines.append({"text": "Cam on quy khach! Hen giao dung ngay", "style": "center"})

	return lines
