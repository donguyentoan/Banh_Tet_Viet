extends VBoxContainer

## Màn hình Đơn Hàng: thống kê, bộ lọc, danh sách đơn, chi tiết + in phiếu.

var store: BakeryStore
var printer: Node

var _stats_box: GridContainer
var _search_edit: LineEdit
var _status_filter: OptionButton
var _cake_filter: OptionButton
var _date_filter: OptionButton
var _sort_filter: OptionButton
var _list_box: VBoxContainer
var _empty_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 10)

	_build_stats()
	_build_filters()

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 8)
	add_child(_list_box)

	_empty_label = UiTheme.label(
		"Chưa có đơn hàng nào. Nhấn nút ➕ để tạo đơn mới.",
		UiTheme.FONT_SIZE_BODY, BanhTet.GRAY_500
	)
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.custom_minimum_size.y = 80
	_list_box.add_child(_empty_label)

	store.orders_changed.connect(_refresh)
	_refresh()


func _build_stats() -> void:
	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)

	_stats_box = grid


func _refresh_stats() -> void:
	for child in _stats_box.get_children():
		child.queue_free()

	var stats := store.dashboard_stats()

	# Card 1: Tổng Đơn Hàng (viền đỏ nhạt, icon nền đỏ nhạt)
	_add_stat_card(
		"TỔNG ĐƠN HÀNG",
		str(stats["totalOrders"]),
		"🧾",
		BanhTet.RED_100,
		BanhTet.RED_600,
		BanhTet.RED_200,
		"Xong: %d  |  Nấu/gói: %d" % [
			int(stats["completedOrders"]), int(stats["cookingCount"])
		]
	)

	# Card 2: Tổng Số Bánh (viền xanh, icon nền xanh)
	_add_stat_card(
		"TỔNG SỐ BÁNH",
		str(stats["totalCakes"]),
		"🍃",
		Color(0.882, 0.996, 0.941),
		BanhTet.GREEN_700,
		Color(0.808, 0.976, 0.902),
		"Chưng: %d  |  Tét: %d" % [
			int(stats.get("chungCount", 0)), int(stats.get("tetCount", 0))
		]
	)

	# Card 3: Tổng Doanh Thu (viền hổ phách, icon nền hổ phách)
	_add_stat_card(
		"TỔNG DOANH THU",
		BanhTet.format_money(int(stats["totalRevenue"])),
		"💰",
		BanhTet.AMBER_100,
		BanhTet.AMBER_600,
		BanhTet.AMBER_200,
		"Đã cọc: %s" % BanhTet.format_money(int(stats["totalDeposit"]))
	)


## Card thống kê giống web: tiêu đề uppercase nhỏ, giá trị lớn đậm,
## icon tròn màu ở góc phải, và dòng phụ nhỏ.
func _add_stat_card(
	title: String,
	value: String,
	icon: String,
	icon_bg: Color,
	icon_fg: Color,
	border: Color,
	subtitle: String
) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.WHITE
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(UiTheme.RADIUS_LG)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.05)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 1)
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	var cap := UiTheme.label(title, UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500)
	text_box.add_child(cap)

	text_box.add_child(UiTheme.label(value, UiTheme.FONT_SIZE_HEADING, BanhTet.GRAY_900))

	if subtitle != "":
		text_box.add_child(UiTheme.label(subtitle, UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500))

	# Icon tròn bên phải
	var icon_panel := PanelContainer.new()
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = icon_bg
	icon_style.set_corner_radius_all(10)
	icon_style.content_margin_left = 8
	icon_style.content_margin_right = 8
	icon_style.content_margin_top = 8
	icon_style.content_margin_bottom = 8
	icon_panel.add_theme_stylebox_override("panel", icon_style)

	var icon_label := UiTheme.label(icon, 20, icon_fg)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_panel.add_child(icon_label)

	icon_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon_panel)

	_stats_box.add_child(card)



func _build_filters() -> void:
	var card := UiTheme.card()
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	# Ô tìm kiếm
	_search_edit = UiTheme.line_edit("Tìm tên, SĐT, mã đơn...")
	_search_edit.text_changed.connect(_on_search_changed)
	box.add_child(_search_edit)

	# Hàng bộ lọc
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)

	var status_items := ["-- Tất cả trạng thái --"]
	for status in BanhTet.ORDER_STATUSES:
		status_items.append(str(BanhTet.STATUS_LABELS[status]))
	_status_filter = UiTheme.option_button(status_items)
	_status_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_filter.item_selected.connect(_on_filter_changed)
	row.add_child(_status_filter)

	_cake_filter = UiTheme.option_button([
		"-- Tất cả bánh --", "Bánh Chưng", "Bánh Tét"
	])
	_cake_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cake_filter.item_selected.connect(_on_filter_changed)
	row.add_child(_cake_filter)

	# Hàng ngày giao + sắp xếp
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	box.add_child(row2)

	var date_items := ["-- Tất cả ngày --"]
	for suggestion in BanhTet.DELIVERY_DATE_SUGGESTIONS:
		date_items.append(str(suggestion["label"]))
	_date_filter = UiTheme.option_button(date_items)
	_date_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_date_filter.item_selected.connect(_on_filter_changed)
	row2.add_child(_date_filter)

	_sort_filter = UiTheme.option_button([
		"⏳ Mới nhất", "⌛ Cũ nhất", "🔥 Giao gấp"
	])
	_sort_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sort_filter.item_selected.connect(_on_filter_changed)
	row2.add_child(_sort_filter)


func _on_search_changed(text: String) -> void:
	store.filter_search = text
	_refresh()


func _on_filter_changed(_index: int) -> void:
	var status_index := _status_filter.selected
	if status_index == 0:
		store.filter_status = "ALL"
	else:
		store.filter_status = BanhTet.ORDER_STATUSES[status_index - 1]

	var cake_index := _cake_filter.selected
	store.filter_cake = "ALL" if cake_index == 0 else ("CHUNG" if cake_index == 1 else "TET")

	var date_index := _date_filter.selected
	if date_index == 0:
		store.filter_delivery_date = "ALL"
	else:
		store.filter_delivery_date = str(BanhTet.DELIVERY_DATE_SUGGESTIONS[date_index - 1]["value"])

	var sort_index := _sort_filter.selected
	store.filter_sort = ["NEWEST", "OLDEST", "URGENT"][sort_index]

	_refresh()


func _refresh() -> void:
	_refresh_stats()

	for child in _list_box.get_children():
		if child != _empty_label:
			child.queue_free()

	var orders := store.filtered_orders()
	_empty_label.visible = orders.is_empty()

	for order in orders:
		_list_box.add_child(_build_order_card(order))


func _build_order_card(order: Dictionary) -> Control:
	var status := str(order.get("status", ""))
	var is_cancelled := status == "Đã hủy"

	# Card trắng, viền amber, bo góc 16px - giống web (rounded-2xl border-amber-200)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.WHITE
	style.border_color = BanhTet.RED_200 if is_cancelled else BanhTet.AMBER_200
	style.set_border_width_all(1)
	style.set_corner_radius_all(UiTheme.RADIUS_LG)
	style.shadow_color = Color(0, 0, 0, 0.05)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 1)
	card.add_theme_stylebox_override("panel", style)
	if is_cancelled:
		card.modulate = Color(1, 1, 1, 0.78)

	# HBox: viền trạng thái bên trái + nội dung
	var outer := HBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	card.add_child(outer)

	# Viền trạng thái (absolute inset-y-0 left-0 w-1 trong web)
	var accent := ColorRect.new()
	accent.color = BanhTet.STATUS_ACCENT_COLORS.get(status, BanhTet.GRAY_300)
	accent.custom_minimum_size = Vector2(4, 0)
	accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(accent)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	outer.add_child(box)

	# --- Đầu card: mã đơn + badge số bánh / tên / SĐT | trạng thái + gọi ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.custom_minimum_size.y = 8
	box.add_child(header)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 2)
	header.add_child(left)

	var id_row := HBoxContainer.new()
	id_row.add_theme_constant_override("separation", 6)
	left.add_child(id_row)

	var id_label := UiTheme.label(
		"#%s" % str(order.get("id", "")), UiTheme.FONT_SIZE_SMALL, BanhTet.RED_700
	)
	id_row.add_child(id_label)

	# Badge "N bánh" (emerald)
	var cakes := _total_cakes(order)
	var cake_badge := PanelContainer.new()
	var cake_style := StyleBoxFlat.new()
	cake_style.bg_color = Color(0.949, 0.988, 0.961)
	cake_style.border_color = Color(0.796, 0.949, 0.882)
	cake_style.set_border_width_all(1)
	cake_style.set_corner_radius_all(999)
	cake_style.content_margin_left = 7
	cake_style.content_margin_right = 7
	cake_style.content_margin_top = 1
	cake_style.content_margin_bottom = 1
	cake_badge.add_theme_stylebox_override("panel", cake_style)
	cake_badge.add_child(UiTheme.label("%d bánh" % cakes, UiTheme.FONT_SIZE_TINY, Color(0.043, 0.388, 0.271)))
	id_row.add_child(cake_badge)

	# Tên khách
	var name_label := UiTheme.label(
		"👤 %s" % str(order.get("customerName", "")), UiTheme.FONT_SIZE_BODY, BanhTet.GRAY_900
	)
	left.add_child(name_label)

	# SĐT
	left.add_child(UiTheme.label(
		"📞 %s" % str(order.get("phone", "")), UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_500
	))

	# Cột phải: badge trạng thái + nút gọi
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	header.add_child(right)

	right.add_child(UiTheme.status_badge(status))

	var phone := str(order.get("phone", ""))
	if phone != "":
		var call_btn := Button.new()
		call_btn.text = "📞"
		call_btn.tooltip_text = "Gọi khách hàng"
		call_btn.custom_minimum_size = Vector2(38, 38)
		call_btn.add_theme_font_size_override("font_size", 16)
		call_btn.add_theme_stylebox_override("normal", UiTheme.call_button_style())
		call_btn.add_theme_stylebox_override("hover", UiTheme.call_button_hover_style())
		call_btn.add_theme_stylebox_override("pressed", UiTheme.call_button_pressed_style())
		call_btn.add_theme_stylebox_override("disabled", UiTheme.disabled_button_style())
		call_btn.add_theme_color_override("font_color", BanhTet.RED_600)
		call_btn.add_theme_color_override("font_hover_color", BanhTet.RED_800)
		call_btn.add_theme_color_override("font_pressed_color", BanhTet.RED_900)
		call_btn.pressed.connect(_on_call_pressed.bind(phone))
		right.add_child(call_btn)

	# --- Địa chỉ + ngày giao ---
	var addr_box := VBoxContainer.new()
	addr_box.add_theme_constant_override("separation", 3)
	box.add_child(addr_box)

	var address := UiTheme.label(
		"📍 %s" % str(order.get("address", "")), UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_600
	)
	address.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	address.custom_minimum_size.y = 30
	addr_box.add_child(address)

	var date_label := UiTheme.label(
		"🕐 %s · %s" % [
			BanhTet.format_date_display(str(order.get("deliveryDate", ""))),
			str(order.get("deliveryTime", "")),
		],
		UiTheme.FONT_SIZE_SMALL, BanhTet.RED_700
	)
	addr_box.add_child(date_label)

	# --- Tóm tắt sản phẩm ---
	var summary := _build_items_summary(order)
	box.add_child(summary)

	# --- Khung tiền: nền xám nhạt, 2 cột ---
	var money_panel := PanelContainer.new()
	var money_style := StyleBoxFlat.new()
	money_style.bg_color = Color(0.976, 0.976, 0.976)
	money_style.border_color = BanhTet.GRAY_100
	money_style.border_width_top = 1
	money_style.content_margin_left = 12
	money_style.content_margin_right = 12
	money_style.content_margin_top = 8
	money_style.content_margin_bottom = 8
	money_panel.add_theme_stylebox_override("panel", money_style)

	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 8)
	money_panel.add_child(money_row)

	var total_box := VBoxContainer.new()
	total_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_box.add_theme_constant_override("separation", 0)
	money_row.add_child(total_box)

	total_box.add_child(UiTheme.label(
		"TỔNG TIỀN", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_400
	))
	total_box.add_child(UiTheme.label(
		BanhTet.format_money(int(order.get("totalAmount", 0))),
		UiTheme.FONT_SIZE_BODY, BanhTet.GRAY_900
	))

	var remain := int(order.get("totalAmount", 0)) - int(order.get("deposit", 0))
	var remain_box := VBoxContainer.new()
	remain_box.add_theme_constant_override("separation", 0)
	money_row.add_child(remain_box)

	var remain_cap := UiTheme.label("CÒN LẠI THU", UiTheme.FONT_SIZE_TINY, BanhTet.RED_600)
	remain_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	remain_box.add_child(remain_cap)
	var remain_label := UiTheme.label(
		BanhTet.format_money(remain), UiTheme.FONT_SIZE_BODY, BanhTet.RED_700
	)
	remain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	remain_box.add_child(remain_label)

	box.add_child(money_panel)

	return card


## Tổng số bánh trong đơn
func _total_cakes(order: Dictionary) -> int:
	var items = order.get("items", {})
	var total := 0
	for product_id in items:
		var qty := int(items[product_id])
		if qty > 0:
			total += qty
	return total


## Nút gọi khách hàng (viền đỏ, nền trắng - giống web)
func _call_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.WHITE
	style.border_color = BanhTet.RED_700
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	return style


func _on_call_pressed(phone: String) -> void:
	OS.shell_open("tel:%s" % phone)



func _build_items_summary(order: Dictionary) -> Control:
	var items = order.get("items", {})
	var parts: Array[String] = []
	var total_cakes := 0
	for product_id in items:
		var qty := int(items[product_id])
		if qty <= 0:
			continue
		total_cakes += qty
		var product := store.find_product(str(product_id))
		var name := str(product.get("name", product_id)) if not product.is_empty() else str(product_id)
		parts.append("%s x%d" % [name, qty])

	var label := UiTheme.label(
		"🧧 %d chiếc · %s" % [total_cakes, " · ".join(parts)],
		UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_600
	)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = 32
	return label



func _on_card_input(event: InputEvent, order: Dictionary) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_show_order_detail(order)


func _show_order_detail(order: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Chi tiết đơn #%s" % str(order.get("id", ""))
	dialog.dialog_hide_on_ok = false
	dialog.ok_button_text = "Đóng"
	dialog.cancel_button_text = ""

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(330, 0)

	# --- Thông tin ---
	var info_card := UiTheme.card(BanhTet.RED_50, BanhTet.AMBER_200)
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 4)
	info_card.add_child(info_box)

	info_box.add_child(UiTheme.label(
		"🌺 PHIẾU ĐẶT BÁNH TẾT 2027", UiTheme.FONT_SIZE_TITLE, BanhTet.RED_700
	))
	info_box.add_child(_kv("Khách hàng", str(order.get("customerName", ""))))
	info_box.add_child(_kv("Số điện thoại", str(order.get("phone", ""))))
	info_box.add_child(_kv("Địa chỉ", str(order.get("address", ""))))
	info_box.add_child(_kv("Ngày giao", "%s (%s)" % [
		BanhTet.format_date_display(str(order.get("deliveryDate", ""))),
		str(order.get("deliveryTime", "")),
	]))
	info_box.add_child(_kv("Trạng thái", str(BanhTet.STATUS_LABELS.get(
		str(order.get("status", "")), str(order.get("status", ""))
	))))
	box.add_child(info_card)

	# --- Sản phẩm ---
	var products_card := UiTheme.card()
	var products_box := VBoxContainer.new()
	products_box.add_theme_constant_override("separation", 5)
	products_card.add_child(products_box)

	products_box.add_child(UiTheme.label(
		"Chi tiết sản phẩm đã đặt:", UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_700
	))

	var items = order.get("items", {})
	for product_id in items:
		var qty := int(items[product_id])
		if qty <= 0:
			continue
		var product := store.find_product(str(product_id))
		var name := str(product.get("name", product_id)) if not product.is_empty() else str(product_id)
		var price := int(product.get("price", 0)) if not product.is_empty() else 0

		var row := HBoxContainer.new()
		var name_label := UiTheme.label("%s x%d" % [name, qty], UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_800)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(name_label)

		var price_label := UiTheme.label(
			BanhTet.format_money(price * qty), UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_900
		)
		row.add_child(price_label)
		products_box.add_child(row)

	box.add_child(products_card)

	# --- Tổng tiền ---
	var total_card := UiTheme.card(BanhTet.AMBER_50, BanhTet.AMBER_300)
	var total_box := VBoxContainer.new()
	total_box.add_theme_constant_override("separation", 4)
	total_card.add_child(total_box)

	var total_row := HBoxContainer.new()
	var t1 := UiTheme.label("Tổng tiền bánh:", UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_600)
	t1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(t1)
	total_row.add_child(UiTheme.label(
		BanhTet.format_money(int(order.get("totalAmount", 0))),
		UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_900
	))
	total_box.add_child(total_row)

	var deposit_row := HBoxContainer.new()
	var d1 := UiTheme.label("Đã đặt cọc trước:", UiTheme.FONT_SIZE_SMALL, BanhTet.GREEN_700)
	d1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deposit_row.add_child(d1)
	deposit_row.add_child(UiTheme.label(
		"-%s" % BanhTet.format_money(int(order.get("deposit", 0))),
		UiTheme.FONT_SIZE_SMALL, BanhTet.GREEN_700
	))
	total_box.add_child(deposit_row)

	var remain_row := HBoxContainer.new()
	var r1 := UiTheme.label("Còn lại thu khi giao:", UiTheme.FONT_SIZE_BODY, BanhTet.RED_700)
	r1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remain_row.add_child(r1)
	remain_row.add_child(UiTheme.label(
		BanhTet.format_money(int(order.get("totalAmount", 0)) - int(order.get("deposit", 0))),
		UiTheme.FONT_SIZE_BODY, BanhTet.RED_700
	))
	total_box.add_child(remain_row)

	var notes := str(order.get("notes", ""))
	if not notes.is_empty():
		var note_label := UiTheme.label(
			"Ghi chú: %s" % notes, UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_600
		)
		note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		total_box.add_child(note_label)

	box.add_child(total_card)

	# --- Nút hành động ---
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	var edit_btn := UiTheme.button("✏️ Sửa", "secondary")
	edit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(edit_btn)

	var print_btn := UiTheme.button("🖨️ In phiếu", "success")
	print_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(print_btn)

	# Dùng get_vbox() để nút OK/Huỷ của AcceptDialog hiển thị đúng.
	dialog.get_vbox().add_child(box)
	add_child(dialog)

	print_btn.pressed.connect(func():
		_print_order(order, print_btn)
	)

	edit_btn.pressed.connect(func():
		dialog.hide()
		queue_free()
	)

	dialog.popup_centered(Vector2i(400, 560))


func _kv(label_text: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl := UiTheme.label(label_text + ":", UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_500)
	lbl.custom_minimum_size.x = 100
	row.add_child(lbl)

	var val := UiTheme.label(value, UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_900)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(val)

	return row


func _print_order(order: Dictionary, btn: Button) -> void:
	if printer == null:
		return

	if not printer.is_bluetooth_available():
		btn.text = "Không hỗ trợ BT"
		return

	btn.disabled = true
	btn.text = "Đang in..."

	printer.print_order(order, store.products)

	btn.disabled = false
	btn.text = "🖨️ In phiếu"
