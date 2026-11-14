class_name BakeryStore
extends Node

## Kho dữ liệu trung tâm: giữ toàn bộ đơn hàng / sản phẩm / mối chợ / sản lượng
## và đồng bộ với API của web app.
##
## Chiến lược: luôn đọc từ API (nguồn sự thật), ghi thao tác lên API.
## Nếu mất mạng, vẫn giữ dữ liệu cache trong RAM để người dùng xem được.

signal data_loaded()
signal orders_changed()
signal products_changed()
signal wholesale_changed()
signal sync_state_changed(is_syncing: bool)
## Phát ra sau khi kiểm tra phiên quản trị lúc khởi động.
## authenticated = false nghĩa là chưa đăng nhập -> cần mở hộp thoại nhập mật khẩu.
signal session_checked(authenticated: bool)

const CACHE_PATH := "user://bakery_cache.json"

var orders: Array = []
var products: Array = []
var markets: Array = []
var wholesale: Array = []
var production: Array = []
var inventory: Array = []

var api: ApiClient
var is_syncing := false
var is_online := false

## Bộ lọc hiện tại (đơn hàng)
var filter_search := ""
var filter_status := "ALL"
var filter_cake := "ALL"
var filter_delivery_date := "ALL"
var filter_sort := "NEWEST"


func _ready() -> void:
	api = ApiClient.new()
	api.request_failed.connect(_on_api_error)
	add_child(api)
	_load_cache()


## Đăng nhập quản trị và tải lại toàn bộ dữ liệu
func login(password: String) -> bool:
	var ok := await api.login(password)
	if ok:
		await refresh_all()
	return ok


## Kiểm tra phiên quản trị hiện có còn hợp lệ không.
## Dùng lúc khởi động app: nếu chưa đăng nhập thì mở hộp thoại nhập mật khẩu
## (giống web app mở sẵn Dialog khi chưa có phiên quản trị).
func check_admin_session() -> bool:
	var ok := await api.check_session()
	session_checked.emit(ok)
	return ok


func logout() -> void:
	await api.logout()


## Tải lại toàn bộ dữ liệu từ API
func refresh_all() -> void:
	is_syncing = true
	sync_state_changed.emit(true)

	var results := await _load_collections()

	orders = results["orders"]
	products = results["products"]
	markets = results["markets"]
	wholesale = results["wholesale"]
	production = results["production"]
	inventory = results["inventory"]

	is_online = true
	is_syncing = false
	sync_state_changed.emit(false)
	_save_cache()

	orders_changed.emit()
	products_changed.emit()
	wholesale_changed.emit()
	data_loaded.emit()


## Tải song song 6 collection
func _load_collections() -> Dictionary:
	var names := ["orders", "products", "markets", "wholesale", "production", "inventory"]
	var result := {}
	for name in names:
		result[name] = await api.list_collection(name)
	return result


## Tạo đơn hàng mới
func create_order(payload: Dictionary) -> Dictionary:
	var created := await api.create("orders", payload)
	if created.is_empty():
		return {}
	orders.insert(0, created)
	_save_cache()
	orders_changed.emit()
	return created


## Cập nhật đơn hàng
func update_order(id: String, payload: Dictionary) -> Dictionary:
	var updated := await api.update("orders", id, payload)
	if updated.is_empty():
		return {}
	for i in range(orders.size()):
		if str(orders[i].get("id", "")) == id:
			orders[i] = updated
			break
	_save_cache()
	orders_changed.emit()
	return updated


## Xoá đơn hàng
func delete_order(id: String) -> bool:
	var ok := await api.remove("orders", id)
	if ok:
		for i in range(orders.size()):
			if str(orders[i].get("id", "")) == id:
				orders.remove_at(i)
				break
		_save_cache()
		orders_changed.emit()
	return ok


## Lưu bản ghi bánh sỉ cho mối chợ
func save_wholesale(payload: Dictionary) -> bool:
	var id := str(payload.get("id", ""))
	var ok := false
	if id.is_empty():
		var created := await api.create("wholesale", payload)
		ok = not created.is_empty()
		if ok:
			wholesale.insert(0, created)
	else:
		var updated := await api.update("wholesale", id, payload)
		ok = not updated.is_empty()
		if ok:
			for i in range(wholesale.size()):
				if str(wholesale[i].get("id", "")) == id:
					wholesale[i] = updated
					break
	if ok:
		_save_cache()
		wholesale_changed.emit()
	return ok


## Xoá bản ghi bánh sỉ
func delete_wholesale(id: String) -> bool:
	var ok := await api.remove("wholesale", id)
	if ok:
		for i in range(wholesale.size()):
			if str(wholesale[i].get("id", "")) == id:
				wholesale.remove_at(i)
				break
		wholesale_changed.emit()
	return ok


## Lưu thông tin mối chợ
func save_market(payload: Dictionary) -> bool:
	var id := str(payload.get("id", ""))
	var ok := false
	if id.is_empty():
		var created := await api.create("markets", payload)
		ok = not created.is_empty()
		if ok:
			markets.insert(0, created)
	else:
		var updated := await api.update("markets", id, payload)
		ok = not updated.is_empty()
		if ok:
			for i in range(markets.size()):
				if str(markets[i].get("id", "")) == id:
					markets[i] = updated
					break
	return ok


## Xoá mối chợ
func delete_market(id: String) -> bool:
	var ok := await api.remove("markets", id)
	if ok:
		for i in range(markets.size()):
			if str(markets[i].get("id", "")) == id:
				markets.remove_at(i)
				break
	return ok


## Lưu sản lượng trong ngày (upsert theo ngày)
func save_production(date: String, items: Dictionary, notes: String) -> bool:
	var payload := {"date": date, "items": items, "notes": notes}
	var response: Dictionary = await api.send_request("POST", "/production", ["Content-Type: application/json"], JSON.stringify(payload))
	var ok: bool = int(response.get("status", 0)) in [200, 201]
	if ok:
		var data = response.get("data", {})
		if data is Dictionary:
			var found := false
			for i in range(production.size()):
				if str(production[i].get("date", "")) == date:
					production[i] = data
					found = true
					break
			if not found:
				production.insert(0, data)
	return ok


## Lưu tồn kho gối đầu (upsert theo ngày)
func save_inventory(date: String, items: Dictionary) -> bool:
	var payload := {"date": date, "items": items}
	var response: Dictionary = await api.send_request("POST", "/inventory", ["Content-Type: application/json"], JSON.stringify(payload))
	var ok: bool = int(response.get("status", 0)) in [200, 201]
	if ok:
		var data = response.get("data", {})
		if data is Dictionary:
			var found := false
			for i in range(inventory.size()):
				if str(inventory[i].get("date", "")) == date:
					inventory[i] = data
					found = true
					break
			if not found:
				inventory.insert(0, data)
	return ok


## Lấy mã đơn tự tăng (khớp logic server: TB2027-001)
func next_order_id() -> String:
	var max_seq := 0
	for order in orders:
		var id := str(order.get("id", ""))
		var parts := id.split("-")
		if parts.size() > 1:
			var seq := int(parts[1])
			if seq > max_seq:
				max_seq = seq
	return "TB2027-%03d" % (max_seq + 1)


## Lọc + sắp xếp đơn hàng theo bộ lọc hiện tại
func filtered_orders() -> Array:
	var keyword := filter_search.to_lower().strip_edges()
	var product_map := {}
	for p in products:
		product_map[p.get("id", "")] = p

	var result: Array = []
	for order in orders:
		var name := str(order.get("customerName", "")).to_lower()
		var phone := str(order.get("phone", ""))
		var id := str(order.get("id", "")).to_lower()
		var match_search := (
			keyword.is_empty()
			or name.find(keyword) != -1
			or phone.find(keyword) != -1
			or id.find(keyword) != -1
		)
		if not match_search:
			continue

		var status := str(order.get("status", ""))
		if filter_status != "ALL" and status != filter_status:
			continue

		if filter_delivery_date != "ALL":
			if str(order.get("deliveryDate", "")) != filter_delivery_date:
				continue

		if filter_cake != "ALL":
			var match_cake := false
			var items = order.get("items", {})
			for product_id in items:
				if int(items[product_id]) <= 0:
					continue
				var product = product_map.get(product_id, null)
				if product != null and str(product.get("category", "")) == filter_cake:
					match_cake = true
					break
			if not match_cake:
				continue

		result.append(order)

	result.sort_custom(_compare_orders)
	return result


func _compare_orders(a: Dictionary, b: Dictionary) -> bool:
	match filter_sort:
		"OLDEST":
			return str(a.get("id", "")) < str(b.get("id", ""))
		"URGENT":
			var date_a := str(a.get("deliveryDate", ""))
			var date_b := str(b.get("deliveryDate", ""))
			if date_a == date_b:
				return str(a.get("id", "")) > str(b.get("id", ""))
			return date_a < date_b
		_:
			return str(a.get("id", "")) > str(b.get("id", ""))


## Tính thống kê dashboard
func dashboard_stats() -> Dictionary:
	var product_map := {}
	for p in products:
		product_map[p.get("id", "")] = p

	var stats := {
		"totalOrders": orders.size(),
		"completedOrders": 0,
		"totalCakes": 0,
		"chungCount": 0,
		"tetCount": 0,
		"totalRevenue": 0,
		"totalDeposit": 0,
		"pendingDelivery": 0,
		"cookingCount": 0,
		"peakDeliveryCount": 0,
		"peakCookingCount": 0,
	}

	for order in orders:
		var status := str(order.get("status", ""))
		if status == "Đã hủy":
			continue
		stats["totalRevenue"] += int(order.get("totalAmount", 0))
		stats["totalDeposit"] += int(order.get("deposit", 0))
		if status == "Đã giao":
			stats["completedOrders"] += 1
		if status == "Đang nấu/gói":
			stats["cookingCount"] += 1
		if status != "Đã giao":
			stats["pendingDelivery"] += 1
		var delivery_date := str(order.get("deliveryDate", ""))
		if status != "Đã giao" and BanhTet.PEAK_DELIVERY_DATES.has(delivery_date):
			stats["peakDeliveryCount"] += 1
			if status == "Đang nấu/gói":
				stats["peakCookingCount"] += 1

		var items = order.get("items", {})
		for product_id in items:
			var qty := int(items[product_id])
			if qty <= 0:
				continue
			stats["totalCakes"] += qty
			var product = product_map.get(product_id, null)
			if product != null:
				var category := str(product.get("category", ""))
				if category == "CHUNG":
					stats["chungCount"] += qty
				elif category == "TET":
					stats["tetCount"] += qty

	return stats


## Tìm đơn hàng theo id
func find_order(id: String) -> Dictionary:
	for order in orders:
		if str(order.get("id", "")) == id:
			return order
	return {}


## Tìm sản phẩm theo id
func find_product(id: String) -> Dictionary:
	for p in products:
		if str(p.get("id", "")) == id:
			return p
	return {}


## Lưu cache cục bộ (dùng khi offline)
func _save_cache() -> void:
	var data := {
		"orders": orders,
		"products": products,
		"markets": markets,
		"wholesale": wholesale,
		"production": production,
		"inventory": inventory,
	}
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()


## Đọc cache cục bộ
func _load_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var json = JSON.parse_string(text)
	if json == null or not (json is Dictionary):
		return
	var data: Dictionary = json
	orders = data.get("orders", [])
	products = data.get("products", [])
	markets = data.get("markets", [])
	wholesale = data.get("wholesale", [])
	production = data.get("production", [])
	inventory = data.get("inventory", [])


func _on_api_error(message: String) -> void:
	is_online = false
