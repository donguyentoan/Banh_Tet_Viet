extends VBoxContainer

## Màn hình Thống Kê & Cân Đối Kho: so sánh nhu cầu (khách lẻ + mối chợ) với nguồn cung.

var store: BakeryStore

var _date_edit: LineEdit
var _balance_box: VBoxContainer
var _stats_box: GridContainer
var _production_edits := {}
var _inventory_edits := {}


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_build_stats()
	_build_date_picker()
	_build_balance()
	_build_production_section()
	_build_inventory_section()


func _build_stats() -> void:
	var card := UiTheme.card(BanhTet.RED_50, BanhTet.AMBER_200)
	add_child(card)

	_stats_box = GridContainer.new()
	_stats_box.columns = 2
	_stats_box.add_theme_constant_override("h_separation", 10)
	_stats_box.add_theme_constant_override("v_separation", 8)
	card.add_child(_stats_box)

	store.orders_changed.connect(_refresh_stats)
	store.wholesale_changed.connect(_refresh_stats)
	_refresh_stats()


func _refresh_stats() -> void:
	for child in _stats_box.get_children():
		child.queue_free()

	var stats := store.dashboard_stats()
	_add_stat("💰 Doanh thu", BanhTet.format_money(int(stats["totalRevenue"])), BanhTet.RED_700)
	_add_stat("💵 Đã cọc", BanhTet.format_money(int(stats["totalDeposit"])), BanhTet.GREEN_700)
	_add_stat("🧧 Bánh chưng", str(stats["chungCount"]), BanhTet.GRAY_800)
	_add_stat("🌾 Bánh tét", str(stats["tetCount"]), BanhTet.GRAY_800)
	_add_stat("🔥 Cần giao cao điểm", str(stats["peakDeliveryCount"]), BanhTet.RED_600)
	_add_stat("🍳 Đang nấu/gói", str(stats["peakCookingCount"]), Color(0.85, 0.45, 0.05))


func _add_stat(title: String, value: String, color: Color) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)

	box.add_child(UiTheme.label(value, UiTheme.FONT_SIZE_TITLE, color))
	box.add_child(UiTheme.label(title, UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500))
	_stats_box.add_child(box)


func _build_date_picker() -> void:
	var card := UiTheme.card()
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	box.add_child(UiTheme.label(
		"📅 Chọn ngày cân đối", UiTheme.FONT_SIZE_TITLE, BanhTet.RED_700
	))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)

	_date_edit = UiTheme.line_edit(BanhTet.DEFAULT_DELIVERY_DATE)
	_date_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_date_edit.text_changed.connect(func(_t): _refresh_balance())
	row.add_child(_date_edit)

	var prev_btn := UiTheme.button("◀", "secondary")
	prev_btn.custom_minimum_size.x = 42
	prev_btn.pressed.connect(func(): _shift_day(-1))
	row.add_child(prev_btn)

	var next_btn := UiTheme.button("▶", "secondary")
	next_btn.custom_minimum_size.x = 42
	next_btn.pressed.connect(func(): _shift_day(1))
	row.add_child(next_btn)

	# Gợi ý ngày Tết
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 4)
	quick.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(quick)

	for suggestion in BanhTet.DELIVERY_DATE_SUGGESTIONS:
		var btn := UiTheme.button(str(suggestion["short"]), "secondary", 11)
		btn.pressed.connect(func():
			_date_edit.text = str(suggestion["value"])
			_refresh_balance()
		)
		quick.add_child(btn)


func _shift_day(delta: int) -> void:
	var unix := Time.get_unix_time_from_datetime_string(_date_edit.text + "T00:00:00Z")
	if unix == 0:
		return
	_date_edit.text = Time.get_date_string_from_unix_time(unix + delta * 86400)
	_refresh_balance()


func _build_balance() -> void:
	var card := UiTheme.card()
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(UiTheme.label(
		"⚖️ Bảng cân đối kho", UiTheme.FONT_SIZE_TITLE, BanhTet.RED_700
	))

	_balance_box = VBoxContainer.new()
	_balance_box.add_theme_constant_override("separation", 6)
	box.add_child(_balance_box)

	_refresh_balance()


func _refresh_balance() -> void:
	for child in _balance_box.get_children():
		child.queue_free()

	var date := _date_edit.text.strip_edges()
	if date.is_empty():
		date = BanhTet.DEFAULT_DELIVERY_DATE

	var balance := ProductionCalc.calculate_day_balance(
		date, store.orders, store.wholesale, store.production, store.inventory, store.products
	)

	# Tổng quan
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 8)
	_balance_box.add_child(summary)

	var demand_box := VBoxContainer.new()
	demand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	demand_box.add_theme_constant_override("separation", 0)
	demand_box.add_child(UiTheme.label(
		"%d" % int(balance["totalDemand"]), UiTheme.FONT_SIZE_HEADING, BanhTet.RED_700
	))
	demand_box.add_child(UiTheme.label("Nhu cầu", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500))
	summary.add_child(demand_box)

	var supply_box := VBoxContainer.new()
	supply_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	supply_box.add_theme_constant_override("separation", 0)
	supply_box.add_child(UiTheme.label(
		"%d" % int(balance["totalProduced"]), UiTheme.FONT_SIZE_HEADING, BanhTet.GREEN_700
	))
	supply_box.add_child(UiTheme.label("Đã làm", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500))
	summary.add_child(supply_box)

	var surplus_box := VBoxContainer.new()
	surplus_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surplus_box.add_theme_constant_override("separation", 0)
	var surplus := int(balance["totalSurplus"])
	surplus_box.add_child(UiTheme.label(
		"%+d" % surplus, UiTheme.FONT_SIZE_HEADING,
		BanhTet.RED_700 if surplus < 0 else BanhTet.GREEN_700
	))
	surplus_box.add_child(UiTheme.label("Dư (+) / Thiếu (-)", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500))
	summary.add_child(surplus_box)

	# Header bảng
	var head := PanelContainer.new()
	var head_style := StyleBoxFlat.new()
	head_style.bg_color = BanhTet.GRAY_100
	head_style.set_corner_radius_all(UiTheme.RADIUS_SM)
	head_style.content_margin_left = 6
	head_style.content_margin_right = 6
	head_style.content_margin_top = 5
	head_style.content_margin_bottom = 5
	head.add_theme_stylebox_override("panel", head_style)

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 4)
	head.add_child(head_row)

	var h1 := UiTheme.label("Bánh", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_700)
	h1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(h1)
	head_row.add_child(UiTheme.label("Cần", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_700))
	head_row.add_child(UiTheme.label("Tồn", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_700))
	head_row.add_child(UiTheme.label("Làm", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_700))
	head_row.add_child(UiTheme.label("Dư", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_700))
	_balance_box.add_child(head)

	# Các dòng sản phẩm
	for row_data in balance["rows"]:
		_balance_box.add_child(_build_balance_row(row_data))


func _build_balance_row(row_data: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var surplus := int(row_data["surplus"])

	var name := UiTheme.label(
		str(row_data["name"]), UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_800
	)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	row.add_child(name)

	row.add_child(UiTheme.label(str(row_data["totalDemand"]), UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_700))
	row.add_child(UiTheme.label(str(row_data["openingStock"]), UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_700))
	row.add_child(UiTheme.label(str(row_data["produced"]), UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_700))
	row.add_child(UiTheme.label(
		"%+d" % surplus, UiTheme.FONT_SIZE_TINY,
		BanhTet.RED_700 if surplus < 0 else BanhTet.GREEN_700
	))

	return row


## ---------------------------------------------------------------- Sản lượng
func _build_production_section() -> void:
	var card := UiTheme.card()
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(UiTheme.label(
		"🍳 Sản lượng bếp đã làm", UiTheme.FONT_SIZE_TITLE, BanhTet.RED_700
	))

	var hint := UiTheme.label(
		"Nhập số bánh bếp đã nấu/gói xong trong ngày.",
		UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_600
	)
	box.add_child(hint)

	var existing := {}
	for production in store.production:
		if str(production.get("date", "")) == _date_edit.text:
			existing = production.get("items", {})
			break

	for product in store.products:
		var product_id := str(product.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name := UiTheme.label(
			str(product.get("name", "")), UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_800
		)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		row.add_child(name)

		var edit := UiTheme.line_edit(str(int(existing.get(product_id, 0))))
		edit.custom_minimum_size.x = 84
		row.add_child(edit)
		_production_edits[product_id] = edit

		box.add_child(row)

	var save_btn := UiTheme.button("💾 Lưu sản lượng", "success", UiTheme.FONT_SIZE_SMALL)
	save_btn.pressed.connect(_on_save_production)
	box.add_child(save_btn)


func _on_save_production() -> void:
	var items := {}
	for product_id in _production_edits:
		var value := (_production_edits[product_id] as LineEdit).text.to_int()
		if value > 0:
			items[product_id] = value
	var ok := await store.save_production(_date_edit.text.strip_edges(), items, "")
	if ok:
		_refresh_balance()
		_show_success("✅ Đã lưu sản lượng")


## ---------------------------------------------------------------- Tồn kho gối đầu
func _build_inventory_section() -> void:
	var card := UiTheme.card()
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(UiTheme.label(
		"📦 Tồn kho gối đầu", UiTheme.FONT_SIZE_TITLE, BanhTet.RED_700
	))

	var hint := UiTheme.label(
		"Số bánh dư từ ngày trước chuyển sang. Để trống = 0.",
		UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_600
	)
	box.add_child(hint)

	var existing := {}
	for inv in store.inventory:
		if str(inv.get("date", "")) == _date_edit.text:
			existing = inv.get("items", {})
			break

	for product in store.products:
		var product_id := str(product.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name := UiTheme.label(
			str(product.get("name", "")), UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_800
		)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		row.add_child(name)

		var edit := UiTheme.line_edit(str(int(existing.get(product_id, 0))))
		edit.custom_minimum_size.x = 84
		row.add_child(edit)
		_inventory_edits[product_id] = edit

		box.add_child(row)

	var save_btn := UiTheme.button("💾 Lưu tồn kho", "primary", UiTheme.FONT_SIZE_SMALL)
	save_btn.pressed.connect(_on_save_inventory)
	box.add_child(save_btn)


func _on_save_inventory() -> void:
	var items := {}
	for product_id in _inventory_edits:
		var value := (_inventory_edits[product_id] as LineEdit).text.to_int()
		if value > 0:
			items[product_id] = value
	var ok := await store.save_inventory(_date_edit.text.strip_edges(), items)
	if ok:
		_refresh_balance()
		_show_success("✅ Đã lưu tồn kho")


func _show_success(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "🎉 Thành công"
	dialog.ok_button_text = "OK"

	var label := UiTheme.label(message, UiTheme.FONT_SIZE_BODY, BanhTet.GREEN_700)
	label.custom_minimum_size = Vector2(300, 0)
	dialog.add_child(label)
	add_child(dialog)
	dialog.popup_centered(Vector2i(360, 180))
	dialog.confirmed.connect(func(): dialog.queue_free())
