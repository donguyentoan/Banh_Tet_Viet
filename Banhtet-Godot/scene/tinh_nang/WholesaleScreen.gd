extends VBoxContainer

## Màn hình Mối Chợ: quản lý chủ mối chợ + lịch bỏ bánh sỉ theo ngày.

var store: BakeryStore

var _date_edit: LineEdit
var _market_option: OptionButton
var _quantities := {}
var _quantity_labels := {}
var _total_label: Label
var _list_box: VBoxContainer
var _markets := []


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_build_form()
	_build_list()


func _build_form() -> void:
	var card := UiTheme.card()
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(UiTheme.label(
		"🏪 Bỏ bánh cho mối chợ", UiTheme.FONT_SIZE_TITLE, BanhTet.RED_700
	))

	# Mối chợ
	var market_col := VBoxContainer.new()
	market_col.add_theme_constant_override("separation", 4)
	box.add_child(market_col)
	market_col.add_child(UiTheme.label(
		"Mối chợ", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500
	))

	var market_row := HBoxContainer.new()
	market_row.add_theme_constant_override("separation", 6)
	market_col.add_child(market_row)

	_market_option = UiTheme.option_button(["-- Chọn mối chợ --"])
	_market_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_row.add_child(_market_option)

	var add_market_btn := UiTheme.button("+", "secondary")
	add_market_btn.custom_minimum_size.x = 40
	add_market_btn.pressed.connect(_show_market_dialog)
	market_row.add_child(add_market_btn)

	# Ngày bỏ bánh
	var date_col := VBoxContainer.new()
	date_col.add_theme_constant_override("separation", 4)
	box.add_child(date_col)
	date_col.add_child(UiTheme.label(
		"Ngày bỏ bánh", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500
	))
	_date_edit = UiTheme.line_edit(BanhTet.today_iso())
	date_col.add_child(_date_edit)

	# Chọn bánh
	box.add_child(UiTheme.label(
		"Số lượng bánh sỉ", UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_700
	))

	for product in store.products:
		box.add_child(_build_product_row(product))

	# Tổng
	var total_card := UiTheme.card(BanhTet.AMBER_50, BanhTet.AMBER_300)
	var total_box := VBoxContainer.new()
	total_box.add_theme_constant_override("separation", 4)
	total_card.add_child(total_box)

	var row := HBoxContainer.new()
	var lbl := UiTheme.label("Tổng tiền sỉ:", UiTheme.FONT_SIZE_BODY, BanhTet.GRAY_700)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	_total_label = UiTheme.label("0 đ", UiTheme.FONT_SIZE_TITLE, BanhTet.RED_700)
	row.add_child(_total_label)
	total_box.add_child(row)
	box.add_child(total_card)

	var save_btn := UiTheme.button("💾 Lưu lịch bỏ bánh", "primary")
	save_btn.pressed.connect(_on_save_pressed)
	box.add_child(save_btn)


func _build_product_row(product: Dictionary) -> Control:
	var product_id := str(product.get("id", ""))
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.GRAY_50
	style.set_corner_radius_all(UiTheme.RADIUS_SM)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", style)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 0)
	box.add_child(name_box)

	name_box.add_child(UiTheme.label(
		str(product.get("name", "")), UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_900
	))
	name_box.add_child(UiTheme.label(
		"Giá sỉ: %s" % BanhTet.format_money(BanhTet.get_wholesale_price(product)),
		UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500
	))

	var qty_box := HBoxContainer.new()
	qty_box.add_theme_constant_override("separation", 4)
	box.add_child(qty_box)

	var minus_btn := UiTheme.icon_button("−")
	minus_btn.pressed.connect(func(): _change_qty(product_id, -1))
	qty_box.add_child(minus_btn)

	var qty_label := UiTheme.label("0", UiTheme.FONT_SIZE_BODY, BanhTet.RED_700)
	qty_label.custom_minimum_size.x = 26
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_box.add_child(qty_label)
	_quantity_labels[product_id] = qty_label

	var plus_btn := UiTheme.icon_button("+")
	plus_btn.pressed.connect(func(): _change_qty(product_id, 1))
	qty_box.add_child(plus_btn)

	return row


func _change_qty(product_id: String, delta: int) -> void:
	var current := int(_quantities.get(product_id, 0))
	var next := maxi(0, current + delta)
	if next == 0:
		_quantities.erase(product_id)
	else:
		_quantities[product_id] = next
	_refresh_quantities()
	_recalculate()


func _refresh_quantities() -> void:
	for product_id in _quantity_labels:
		var lbl: Label = _quantity_labels[product_id]
		lbl.text = str(int(_quantities.get(product_id, 0)))


func _recalculate() -> void:
	var total := ProductionCalc.calculate_wholesale_total(_quantities, store.products)
	if _total_label != null:
		_total_label.text = BanhTet.format_money(total)


## ---------------------------------------------------------------- Danh sách lịch bỏ bánh
func _build_list() -> void:
	var card := UiTheme.card()
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(UiTheme.label(
		"📅 Lịch đã bỏ bánh", UiTheme.FONT_SIZE_TITLE, BanhTet.RED_700
	))

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 6)
	box.add_child(_list_box)

	store.wholesale_changed.connect(_refresh_list)
	_refresh_markets()
	_refresh_list()


func _refresh_markets() -> void:
	_markets = store.markets.duplicate()
	_market_option.clear()
	_market_option.add_item("-- Chọn mối chợ --")
	for market in _markets:
		_market_option.add_item("%s - %s" % [
			str(market.get("name", "")),
			str(market.get("stall", "")),
		])


func _market_by_id(id: String) -> Dictionary:
	for market in store.markets:
		if str(market.get("id", "")) == id:
			return market
	return {}


func _refresh_list() -> void:
	for child in _list_box.get_children():
		child.queue_free()

	if store.wholesale.is_empty():
		_list_box.add_child(UiTheme.label(
			"Chưa có lịch bỏ bánh nào.", UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_500
		))
		return

	for entry in store.wholesale:
		_list_box.add_child(_build_entry_card(entry))


func _build_entry_card(entry: Dictionary) -> Control:
	var card := UiTheme.card(BanhTet.GRAY_50, BanhTet.GRAY_200)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)

	var market := _market_by_id(str(entry.get("marketId", "")))
	var market_name := str(market.get("name", "Mối chợ"))
	var stall := str(market.get("stall", ""))

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)

	var title := UiTheme.label(
		"🏪 %s%s" % [market_name, " (%s)" % stall if not stall.is_empty() else ""],
		UiTheme.FONT_SIZE_BODY, BanhTet.GRAY_900
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var date_label := UiTheme.label(
		BanhTet.format_date_display(str(entry.get("date", ""))),
		UiTheme.FONT_SIZE_SMALL, BanhTet.RED_700
	)
	head.add_child(date_label)

	# Sản phẩm
	var items = entry.get("items", {})
	for product_id in items:
		var qty := int(items[product_id])
		if qty <= 0:
			continue
		var product := store.find_product(str(product_id))
		var name := str(product.get("name", product_id)) if not product.is_empty() else str(product_id)
		var line := UiTheme.label(
			"• %s x%d" % [name, qty], UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_600
		)
		box.add_child(line)

	var total_row := HBoxContainer.new()
	var t1 := UiTheme.label("Tổng:", UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_600)
	t1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(t1)
	total_row.add_child(UiTheme.label(
		BanhTet.format_money(int(entry.get("totalAmount", 0))),
		UiTheme.FONT_SIZE_SMALL, BanhTet.RED_700
	))
	box.add_child(total_row)

	# Nút xoá
	var delete_btn := UiTheme.button("🗑️ Xoá lịch", "secondary", UiTheme.FONT_SIZE_TINY)
	delete_btn.pressed.connect(func(): await store.delete_wholesale(str(entry.get("id", ""))))
	box.add_child(delete_btn)

	return card


## ---------------------------------------------------------------- Lưu
func _on_save_pressed() -> void:
	if _market_option.selected <= 0:
		_show_error("Vui lòng chọn mối chợ")
		return
	if _quantities.is_empty():
		_show_error("Vui lòng nhập số lượng bánh sỉ")
		return

	var market_index := _market_option.selected - 1
	var market = _markets[market_index] if market_index < _markets.size() else {}

	var payload := {
		"marketId": str(market.get("id", "")),
		"date": _date_edit.text.strip_edges(),
		"items": _quantities.duplicate(),
		"totalAmount": ProductionCalc.calculate_wholesale_total(_quantities, store.products),
		"notes": "",
		"createdAt": Time.get_datetime_string_from_system(),
	}

	var ok := await store.save_wholesale(payload)
	if ok:
		_show_success("✅ Đã lưu lịch bỏ bánh")
		_quantities.clear()
		_refresh_quantities()
		_recalculate()
	else:
		_show_error("Không lưu được. Kiểm tra kết nối mạng.")


## ---------------------------------------------------------------- Thêm mối chợ
func _show_market_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "🏪 Thêm mối chợ"
	dialog.dialog_hide_on_ok = false
	dialog.ok_button_text = "Lưu"
	dialog.cancel_button_text = "Huỷ"

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(320, 0)

	var name_edit := UiTheme.line_edit("Tên chủ mối chợ *")
	box.add_child(name_edit)

	var stall_edit := UiTheme.line_edit("Tên chợ / sạp chợ *")
	box.add_child(stall_edit)

	var phone_edit := UiTheme.line_edit("Số điện thoại *")
	box.add_child(phone_edit)

	var notes_edit := UiTheme.text_area("Ghi chú")
	box.add_child(notes_edit)

	# Dùng get_vbox() để nút OK/Huỷ của AcceptDialog hiển thị đúng.
	dialog.get_vbox().add_child(box)
	add_child(dialog)

	dialog.confirmed.connect(func():
		var name := name_edit.text.strip_edges()
		var stall := stall_edit.text.strip_edges()
		var phone := phone_edit.text.strip_edges()
		if name.length() < 2 or stall.length() < 2:
			_show_error("Vui lòng nhập tên chủ mối chợ và tên chợ")
			return
		if phone.length() < 9:
			_show_error("Số điện thoại không hợp lệ")
			return

		await store.save_market({
			"name": name,
			"stall": stall,
			"phone": phone,
			"notes": notes_edit.text.strip_edges(),
		})
		_refresh_markets()
		dialog.hide()
		dialog.queue_free()
	)

	dialog.popup_centered(Vector2i(380, 420))


func _show_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "⚠️ Thiếu thông tin"
	dialog.ok_button_text = "OK"

	var label := UiTheme.label(message, UiTheme.FONT_SIZE_BODY, BanhTet.RED_700)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(300, 0)
	dialog.add_child(label)
	add_child(dialog)
	dialog.popup_centered(Vector2i(360, 190))
	dialog.confirmed.connect(func(): dialog.queue_free())


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
