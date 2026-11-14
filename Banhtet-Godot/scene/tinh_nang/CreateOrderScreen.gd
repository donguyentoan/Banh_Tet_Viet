extends VBoxContainer

## Màn hình Tạo / Chỉnh sửa đơn hàng + Ô Ghi Nhận Nhanh.

var store: BakeryStore

var _quick_input: TextEdit
var _quick_result_label: Label
var _quick_preview: VBoxContainer
var _quick_applied := false

var _name_edit: LineEdit
var _phone_edit: LineEdit
var _address_edit: TextEdit
var _date_edit: LineEdit
var _time_edit: LineEdit
var _status_option: OptionButton
var _deposit_edit: LineEdit
var _notes_edit: TextEdit

var _quantities := {}
var _quantity_labels := {}
var _total_label: Label

var _editing_id := ""
var _prefill := {}


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_build_quick_parse()
	_build_form()
	_build_product_section()


## ---------------------------------------------------------------- Ô ghi nhận nhanh
func _build_quick_parse() -> void:
	var card := UiTheme.card(BanhTet.AMBER_50, BanhTet.AMBER_300)
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var title := UiTheme.label(
		"⚡ Ô Ghi Nhận Nhanh", UiTheme.FONT_SIZE_TITLE, BanhTet.RED_700
	)
	box.add_child(title)

	var hint := UiTheme.label(
		"Gõ tin nhắn của khách, app tự tách tên, SĐT, ngày giờ và món bánh.",
		UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_600
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	_quick_input = UiTheme.text_area(
		"Ví dụ: bà Mi / 03/02/2027 / 2 CM / 1 CC / 8 giờ sáng"
	)
	_quick_input.custom_minimum_size.y = 76
	_quick_input.text_changed.connect(_on_quick_changed)
	box.add_child(_quick_input)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	var parse_btn := UiTheme.button("🔍 Phân tích", "primary", UiTheme.FONT_SIZE_SMALL)
	parse_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parse_btn.pressed.connect(_on_parse_pressed)
	actions.add_child(parse_btn)

	var apply_btn := UiTheme.button("✔️ Áp dụng", "success", UiTheme.FONT_SIZE_SMALL)
	apply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_btn.pressed.connect(_on_apply_pressed)
	actions.add_child(apply_btn)

	_quick_result_label = UiTheme.label("", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_600)
	_quick_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_quick_result_label)

	_quick_preview = VBoxContainer.new()
	_quick_preview.add_theme_constant_override("separation", 2)
	box.add_child(_quick_preview)


func _on_quick_changed(_text: String) -> void:
	_quick_applied = false


func _on_parse_pressed() -> void:
	var parsed: Dictionary = QuickParse.parse_quick_order(_quick_input.text, store.products)

	for child in _quick_preview.get_children():
		child.queue_free()

	var name := str(parsed.get("customerName", ""))
	var phone := str(parsed.get("phone", ""))
	var address := str(parsed.get("address", ""))
	var quantities = parsed.get("quantities", {})
	var unknown: Array = parsed.get("unknownCodes", [])

	var summary := "✅ %s" % name if not name.is_empty() else "⚠️ Chưa nhận ra tên khách"
	if not phone.is_empty():
		summary += " · 📞 " + phone
	if not address.is_empty():
		summary += " · 📍 " + address
	summary += "\n📅 %s (%s)" % [
		BanhTet.format_date_display(str(parsed.get("deliveryDate", ""))),
		str(parsed.get("deliveryTime", "")),
	]

	var found_items: Array[String] = []
	for product_id in quantities:
		var qty := int(quantities[product_id])
		if qty <= 0:
			continue
		var product := store.find_product(str(product_id))
		var name_text := str(product.get("name", product_id)) if not product.is_empty() else str(product_id)
		found_items.append("%s x%d" % [name_text, qty])

	if found_items.is_empty():
		summary += "\n⚠️ Chưa nhận ra món bánh nào"
	else:
		summary += "\n🧧 " + " · ".join(found_items)

	if not unknown.is_empty():
		summary += "\n❓ Mã lạ: " + ", ".join(unknown)

	_quick_result_label.text = summary
	_quick_preview.set_meta("parsed", parsed)


func _on_apply_pressed() -> void:
	var parsed = _quick_preview.get_meta("parsed", null)
	if parsed == null:
		_on_parse_pressed()
		parsed = _quick_preview.get_meta("parsed", null)
		if parsed == null:
			return

	var name := str(parsed.get("customerName", ""))
	if not name.is_empty():
		_name_edit.text = name
	var phone := str(parsed.get("phone", ""))
	if not phone.is_empty():
		_phone_edit.text = phone
	var address := str(parsed.get("address", ""))
	if not address.is_empty():
		_address_edit.text = address

	_date_edit.text = str(parsed.get("deliveryDate", BanhTet.DEFAULT_DELIVERY_DATE))
	_time_edit.text = str(parsed.get("deliveryTime", BanhTet.DEFAULT_DELIVERY_TIME))

	var quantities = parsed.get("quantities", {})
	_quantities.clear()
	for product_id in quantities:
		var qty := int(quantities[product_id])
		if qty > 0:
			_quantities[str(product_id)] = qty

	_quick_applied = true
	_refresh_quantities()
	_recalculate()


## ---------------------------------------------------------------- Form thông tin
func _build_form() -> void:
	var card := UiTheme.card()
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(UiTheme.label(
		"1️⃣ Thông tin khách hàng", UiTheme.FONT_SIZE_TITLE, BanhTet.RED_700
	))

	_name_edit = UiTheme.line_edit("Họ và tên khách hàng *")
	box.add_child(_make_field("Khách hàng *", _name_edit))

	_phone_edit = UiTheme.line_edit("0901234567")
	box.add_child(_make_field("Số điện thoại *", _phone_edit))

	_address_edit = UiTheme.text_area("Địa chỉ nhận bánh *")
	_address_edit.custom_minimum_size.y = 56
	box.add_child(_make_field("Địa chỉ *", _address_edit))

	# Ngày + giờ
	var date_row := HBoxContainer.new()
	date_row.add_theme_constant_override("separation", 8)
	box.add_child(date_row)

	var date_col := VBoxContainer.new()
	date_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_col.add_theme_constant_override("separation", 4)
	date_row.add_child(date_col)
	date_col.add_child(UiTheme.label("Ngày giao *", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500))
	_date_edit = UiTheme.line_edit("2027-02-03")
	date_col.add_child(_date_edit)

	var time_col := VBoxContainer.new()
	time_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_col.add_theme_constant_override("separation", 4)
	date_row.add_child(time_col)
	time_col.add_child(UiTheme.label("Giờ giao *", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500))
	_time_edit = UiTheme.line_edit(BanhTet.DEFAULT_DELIVERY_TIME)
	time_col.add_child(_time_edit)

	# Gợi ý ngày nhanh
	var quick_dates := HBoxContainer.new()
	quick_dates.add_theme_constant_override("separation", 4)
	quick_dates.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(quick_dates)

	for suggestion in BanhTet.DELIVERY_DATE_SUGGESTIONS:
		var btn := UiTheme.button(str(suggestion["short"]), "secondary", 11)
		btn.pressed.connect(func(): _date_edit.text = str(suggestion["value"]))
		quick_dates.add_child(btn)

	# Trạng thái
	var status_col := VBoxContainer.new()
	status_col.add_theme_constant_override("separation", 4)
	box.add_child(status_col)
	status_col.add_child(UiTheme.label(
		"Trạng thái đơn hàng", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500
	))
	_status_option = UiTheme.option_button(BanhTet.ORDER_STATUSES)
	status_col.add_child(_status_option)

	# Tiền cọc
	var deposit_col := VBoxContainer.new()
	deposit_col.add_theme_constant_override("separation", 4)
	box.add_child(deposit_col)
	deposit_col.add_child(UiTheme.label(
		"Tiền cọc trước (đ)", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500
	))
	_deposit_edit = UiTheme.line_edit("0")
	_deposit_edit.text_changed.connect(func(_t): _recalculate())
	deposit_col.add_child(_deposit_edit)

	# Ghi chú
	var notes_col := VBoxContainer.new()
	notes_col.add_theme_constant_override("separation", 4)
	box.add_child(notes_col)
	notes_col.add_child(UiTheme.label(
		"Ghi chú", UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500
	))
	_notes_edit = UiTheme.text_area("VD: gọi trước 1 giờ, không hành...")
	notes_col.add_child(_notes_edit)


func _make_field(label_text: String, control: Control) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.add_child(UiTheme.label(label_text, UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500))
	col.add_child(control)
	return col


## ---------------------------------------------------------------- Chọn sản phẩm
func _build_product_section() -> void:
	var card := UiTheme.card()
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(UiTheme.label(
		"2️⃣ Chọn bánh", UiTheme.FONT_SIZE_TITLE, BanhTet.RED_700
	))

	for product in store.products:
		box.add_child(_build_product_row(product))

	# Tổng tiền
	var total_card := UiTheme.card(BanhTet.AMBER_50, BanhTet.AMBER_300)
	var total_box := VBoxContainer.new()
	total_box.add_theme_constant_override("separation", 4)
	total_card.add_child(total_box)

	var row := HBoxContainer.new()
	var lbl := UiTheme.label("Tổng tiền bánh:", UiTheme.FONT_SIZE_BODY, BanhTet.GRAY_700)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	_total_label = UiTheme.label("0 đ", UiTheme.FONT_SIZE_TITLE, BanhTet.RED_700)
	row.add_child(_total_label)
	total_box.add_child(row)
	box.add_child(total_card)

	# Nút lưu
	var save_btn := UiTheme.button("💾 Lưu Đơn Hàng", "primary")
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

	# Ảnh
	var icon_name := str(product.get("icon", ""))
	var texture: Texture2D = null
	if icon_name.ends_with(".png"):
		var path := "res://assets/anh/" + icon_name
		if ResourceLoader.exists(path):
			texture = load(path)
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.custom_minimum_size = Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(icon)

	# Tên + giá
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 0)
	box.add_child(name_box)

	name_box.add_child(UiTheme.label(
		str(product.get("name", "")), UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_900
	))
	name_box.add_child(UiTheme.label(
		"%s · %s" % [
			BanhTet.format_money(int(product.get("price", 0))),
			str(product.get("weight", "")),
		],
		UiTheme.FONT_SIZE_TINY, BanhTet.GRAY_500
	))

	# Nút tăng/giảm
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
	var total := BanhTet.calculate_total(_quantities, store.products)
	if _total_label != null:
		_total_label.text = BanhTet.format_money(total)


## ---------------------------------------------------------------- Lưu đơn
func _on_save_pressed() -> void:
	var name := _name_edit.text.strip_edges()
	var phone := _phone_edit.text.strip_edges()
	var address := _address_edit.text.strip_edges()
	var delivery_date := _date_edit.text.strip_edges()
	var delivery_time := _time_edit.text.strip_edges()

	if name.length() < 2:
		_show_error("Vui lòng nhập họ tên khách hàng")
		return
	if not phone.is_valid_int() or phone.length() < 9:
		_show_error("Số điện thoại không hợp lệ")
		return
	if address.length() < 5:
		_show_error("Vui lòng nhập địa chỉ giao hàng")
		return
	if _quantities.is_empty():
		_show_error("Vui lòng chọn ít nhất 01 loại bánh để đặt!")
		return

	var total := BanhTet.calculate_total(_quantities, store.products)
	var deposit := _deposit_edit.text.to_int()
	if deposit < 0:
		deposit = 0

	var payload := {
		"id": store.next_order_id(),
		"customerName": name,
		"phone": phone,
		"address": address,
		"deliveryDate": delivery_date,
		"deliveryTime": delivery_time,
		"items": _quantities.duplicate(),
		"totalAmount": total,
		"deposit": deposit,
		"status": BanhTet.ORDER_STATUSES[maxi(0, _status_option.selected)],
		"notes": _notes_edit.text.strip_edges(),
		"createdAt": BanhTet.today_iso(),
	}

	var created := await store.create_order(payload)
	if created.is_empty():
		_show_error("Không lưu được đơn hàng. Kiểm tra kết nối mạng.")
		return

	_show_success("✅ Đã lưu đơn #%s" % str(created.get("id", "")))
	_reset_form()


func _reset_form() -> void:
	_name_edit.text = ""
	_phone_edit.text = ""
	_address_edit.text = ""
	_date_edit.text = BanhTet.DEFAULT_DELIVERY_DATE
	_time_edit.text = BanhTet.DEFAULT_DELIVERY_TIME
	_status_option.selected = 0
	_deposit_edit.text = "0"
	_notes_edit.text = ""
	_quick_input.text = ""
	_quantities.clear()
	_refresh_quantities()
	_recalculate()


func _show_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "⚠️ Thiếu thông tin"
	dialog.dialog_hide_on_ok = true
	dialog.ok_button_text = "OK"

	var label := UiTheme.label(message, UiTheme.FONT_SIZE_BODY, BanhTet.RED_700)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(300, 0)
	dialog.add_child(label)
	add_child(dialog)
	dialog.popup_centered(Vector2i(360, 200))
	dialog.confirmed.connect(func(): dialog.queue_free())


func _show_success(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "🎉 Thành công"
	dialog.dialog_hide_on_ok = true
	dialog.ok_button_text = "OK"

	var label := UiTheme.label(message, UiTheme.FONT_SIZE_BODY, BanhTet.GREEN_700)
	label.custom_minimum_size = Vector2(300, 0)
	dialog.add_child(label)
	add_child(dialog)
	dialog.popup_centered(Vector2i(360, 180))
	dialog.confirmed.connect(func(): dialog.queue_free())
