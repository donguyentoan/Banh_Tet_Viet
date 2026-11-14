extends VBoxContainer

## Màn hình Tạo / Chỉnh sửa đơn hàng - port 1:1 từ web:
##   src/pages/create-order-page.tsx  (banner đỏ + khung form)
##   src/components/orders/order-form.tsx  (4 section: khách hàng, chọn bánh,
##       lịch giao & trạng thái, thanh toán & ghi chú + nút)
##   src/components/orders/add-product-dialog.tsx  (Thêm loại bánh)

var store: BakeryStore

# Màu Tailwind dùng riêng cho màn này
const EMERALD_50 := Color("#ecfdf5")
const EMERALD_100 := Color("#d1fae5")
const EMERALD_200 := Color("#a7f3d0")
const EMERALD_400 := Color("#34d399")
const EMERALD_700 := Color("#047857")
const EMERALD_800 := Color("#065f46")
const RED_100_TW := Color("#fee2e2")
const GRAY_100_TW := Color("#f3f4f6")
const GRAY_200_TW := Color("#e5e7eb")
const GRAY_400_TW := Color("#9ca3af")
const GRAY_500_TW := Color("#6b7280")
const GRAY_600_TW := Color("#4b5563")
const GRAY_700_TW := Color("#374151")
const GRAY_800_TW := Color("#1f2937")
const GRAY_900_TW := Color("#111827")

var _editing_id := ""

var _name_edit: LineEdit
var _phone_edit: LineEdit
var _address_edit: LineEdit
var _date_edit: LineEdit
var _time_edit: LineEdit
var _status_option: OptionButton
var _deposit_edit: LineEdit
var _notes_edit: TextEdit
var _errors := {}          # field -> Label lỗi

var _quantities := {}
var _qty_edits := {}       # product_id -> LineEdit
var _product_cards := {}   # product_id -> PanelContainer

var _total_label: Label
var _remain_label: Label

# Phần tử cần đổi theo breakpoint
var _banner_style: StyleBoxTexture
var _banner_box: BoxContainer
var _banner_title: Label
var _back_btn: Button
var _form_style: StyleBoxFlat
var _sections: Array[StyleBox] = []
var _customer_grid: GridContainer
var _address_field: Control
var _product_grid: GridContainer
var _product_note: Label
var _schedule_grid: GridContainer
var _pay_box: BoxContainer
var _pay_total_box: BoxContainer
var _deposit_wrap: Control
var _footer: BoxContainer
var _submit_btn: Button
var _page_title_text := "Tạo Đơn Hàng Mới"
var _built := false
var _section_titles: Array[Label] = []


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 24)

	add_child(_build_banner())
	add_child(_build_form_card())

	if store:
		store.products_changed.connect(_rebuild_products)

	_built = true
	get_viewport().size_changed.connect(_apply_responsive)
	_apply_responsive()
	_recalculate()


## ============================================================ API công khai
## Điền form từ "Tạo Đơn Nhanh" ở trang Đơn Hàng (web: openFormWithPrefill)
func apply_parsed(text: String) -> void:
	var parsed: Dictionary = QuickParse.parse_quick_order(text, store.products)
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
	_quantities.clear()
	var quantities = parsed.get("quantities", {})
	for product_id in quantities:
		if int(quantities[product_id]) > 0:
			_quantities[str(product_id)] = int(quantities[product_id])
	_refresh_quantities()
	_recalculate()


## Nạp đơn có sẵn để chỉnh sửa (web: openEditForm)
func load_order(order: Dictionary) -> void:
	_editing_id = str(order.get("id", ""))
	_name_edit.text = str(order.get("customerName", ""))
	_phone_edit.text = str(order.get("phone", ""))
	_address_edit.text = str(order.get("address", ""))
	_date_edit.text = str(order.get("deliveryDate", BanhTet.DEFAULT_DELIVERY_DATE))
	_time_edit.text = str(order.get("deliveryTime", BanhTet.DEFAULT_DELIVERY_TIME))
	_deposit_edit.text = str(int(order.get("deposit", 0)))
	_notes_edit.text = str(order.get("notes", ""))
	_status_option.selected = maxi(0, BanhTet.ORDER_STATUSES.find(str(order.get("status", ""))))
	_quantities.clear()
	var items = order.get("items", {})
	for product_id in items:
		if int(items[product_id]) > 0:
			_quantities[str(product_id)] = int(items[product_id])
	_banner_title.text = "Chỉnh Sửa Đơn #%s" % _editing_id
	_submit_btn.text = "Cập Nhật Đơn Hàng"
	_refresh_quantities()
	_recalculate()


## =============================================================== Responsive
func _apply_responsive() -> void:
	if not _built:
		return
	var w := get_viewport_rect().size.x
	var sm := w >= UiTheme.BP_SM
	var md := w >= UiTheme.BP_MD

	# Banner: px-4 py-4 / sm:px-6 sm:py-6 ; md:flex-row
	_banner_style.content_margin_left = 24 if sm else 16
	_banner_style.content_margin_right = 24 if sm else 16
	_banner_style.content_margin_top = 24 if sm else 16
	_banner_style.content_margin_bottom = 24 if sm else 16
	_banner_box.vertical = not md
	_banner_title.add_theme_font_size_override("font_size", 24 if sm else 18)
	_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_END if md else Control.SIZE_SHRINK_BEGIN
	add_theme_constant_override("separation", 24 if sm else 16)

	# Khung form p-3 / sm:p-6 ; section p-4 / sm:p-5
	_form_style.set_content_margin_all(24 if sm else 12)
	for st in _sections:
		st.set_content_margin_all(20 if sm else 16)

	_customer_grid.columns = 2 if md else 1
	# Tiêu đề section: 1 dòng trên màn rộng, tự xuống dòng trên điện thoại
	for t in _section_titles:
		t.autowrap_mode = TextServer.AUTOWRAP_OFF if sm else TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_FILL if sm else Control.SIZE_EXPAND_FILL

	# grid-cols-1 sm:2 lg:3 xl:4 2xl:5
	_product_grid.columns = 5 if w >= 1536 else (4 if w >= 1280 else (3 if w >= UiTheme.BP_LG else (2 if sm else 1)))
	for id in _product_cards:
		(_product_cards[id] as Control).custom_minimum_size.y = 220 if sm else 150
	_product_note.visible = sm

	_schedule_grid.columns = 3 if md else 1

	_pay_box.vertical = not md
	_pay_total_box.vertical = md
	_total_label.add_theme_font_size_override("font_size", 30 if sm else 24)
	_deposit_wrap.custom_minimum_size.x = 160 if sm else 0
	_remain_label.add_theme_font_size_override("font_size", 18 if sm else 16)

	# Footer: flex-col-reverse / sm:flex-row sm:justify-end
	_footer.vertical = not sm
	_footer.alignment = BoxContainer.ALIGNMENT_END if sm else BoxContainer.ALIGNMENT_BEGIN
	var children := _footer.get_children()
	# Trên điện thoại nút chính (submit) nằm trên (flex-col-reverse)
	_footer.move_child(_submit_btn, 0 if not sm else children.size() - 1)
	for c in _footer.get_children():
		(c as Control).size_flags_horizontal = Control.SIZE_SHRINK_END if sm else Control.SIZE_FILL


## =================================================================== Banner
## rounded-2xl border-amber-300 bg-gradient-to-r from-red-800 via-red-700 to-amber-700
func _build_banner() -> Control:
	_banner_style = StyleBoxTexture.new()
	_banner_style.texture = _hgradient([BanhTet.RED_800, BanhTet.RED_700, Color("#b45309")])
	var parts := _rounded_box(_banner_style, BanhTet.AMBER_300, 16, true)
	var frame: Control = parts[0]
	var inner: PanelContainer = parts[1]

	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(layer)
	# 🧧 mờ 10% ở góc phải trên (text-[10rem] -right-6 -top-8)
	var envelope := UiTheme.text("🧧", 150, BanhTet.WHITE)
	envelope.modulate.a = 0.1
	envelope.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	envelope.offset_left = -170
	envelope.offset_top = -70
	envelope.offset_right = 30
	layer.add_child(envelope)

	_banner_box = BoxContainer.new()
	_banner_box.add_theme_constant_override("separation", 16)
	inner.add_child(_banner_box)

	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 16)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner_box.add_child(left)

	var icon_box := UiTheme.panel(UiTheme.box_style(Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.25), 16))
	icon_box.custom_minimum_size = Vector2(56, 56)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cart := UiTheme.icon("shopping-cart", 28, Color("#fcd34d"))
	cart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_box.add_child(cart)
	left.add_child(icon_box)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_theme_constant_override("separation", 2)
	left.add_child(titles)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	titles.add_child(trow)
	_banner_title = UiTheme.text(_page_title_text, 24, BanhTet.WHITE, "extrabold")
	trow.add_child(_banner_title)
	trow.add_child(UiTheme.icon("sparkles", 20, Color("#fcd34d")))
	var sub := UiTheme.text("Nhập thông tin khách hàng, chọn bánh & ngày giao hàng", 12, BanhTet.RED_100, "medium")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(sub)

	# Nút "Về danh sách đơn" (outline trắng trong suốt)
	_back_btn = Button.new()
	_back_btn.text = "Về danh sách đơn"
	_back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_back_btn.add_theme_font_size_override("font_size", 14)
	UiTheme.set_weight(_back_btn, "semibold")
	UiTheme.set_button_icon(_back_btn, "arrow-left", 16, BanhTet.WHITE)
	_back_btn.add_theme_stylebox_override("normal", UiTheme.box_style(Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.4), 8, 12, 7))
	_back_btn.add_theme_stylebox_override("hover", UiTheme.box_style(Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.4), 8, 12, 7))
	_back_btn.add_theme_stylebox_override("pressed", UiTheme.box_style(Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.4), 8, 12, 7))
	_back_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_back_btn.add_theme_color_override(c, BanhTet.WHITE)
	_back_btn.pressed.connect(_go_to_list)
	_banner_box.add_child(_back_btn)
	return frame


## ============================================================== Khung form
func _build_form_card() -> Control:
	_form_style = UiTheme.box_style(BanhTet.WHITE, GRAY_200_TW, 16, 24, 24)
	_form_style.shadow_color = Color(0, 0, 0, 0.05)
	_form_style.shadow_size = 2
	_form_style.shadow_offset = Vector2(0, 1)
	var card := UiTheme.panel(_form_style)

	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 24)
	card.add_child(form)

	form.add_child(_build_customer_section())
	form.add_child(_build_product_section())
	form.add_child(_build_schedule_section())
	form.add_child(_build_payment_section())
	form.add_child(_build_footer())
	return card


## Section bo góc 2xl. bg: Color hoặc Texture (gradient)
func _section(border: Color, bg: Variant) -> PanelContainer:
	var st: StyleBox
	if bg is Texture2D:
		var t := StyleBoxTexture.new()
		t.texture = bg
		st = t
	else:
		st = UiTheme.box_style(bg, Color.TRANSPARENT, 16)
	st.set_content_margin_all(20)
	_sections.append(st)
	var parts := _rounded_box(st, border, 16, false)
	var frame: Control = parts[0]
	frame.set_meta("inner", parts[1])
	return frame


## Hộp bo góc: [khung ngoài (bóng), panel nội dung]. Nền (kể cả gradient)
## được cắt theo góc bo; viền vẽ đè lên trên cùng như CSS border.
func _rounded_box(bg: StyleBox, border: Color, radius: int, shadow: bool) -> Array:
	var outer_style := UiTheme.box_style(Color.TRANSPARENT, Color.TRANSPARENT, radius)
	if shadow:
		outer_style.bg_color = Color(0, 0, 0, 0.01)
		outer_style.shadow_color = Color(0, 0, 0, 0.18)
		outer_style.shadow_size = 12
		outer_style.shadow_offset = Vector2(0, 6)
	var outer := UiTheme.panel(outer_style)
	var clip := _RoundClip.new()
	clip.radius = radius
	outer.add_child(clip)
	var inner := UiTheme.panel(bg)
	clip.add_child(inner)
	var border_style := UiTheme.box_style(Color.TRANSPARENT, border, radius)
	border_style.draw_center = false
	var border_panel := Panel.new()
	border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_panel.add_theme_stylebox_override("panel", border_style)
	outer.add_child(border_panel)
	return [outer, inner]


## Tiêu đề section: chấm tròn số + chữ in hoa đậm
func _section_title(num: String, title: String, color: Color, dot: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var circle := UiTheme.panel(UiTheme.box_style(dot, Color.TRANSPARENT, 12))
	circle.custom_minimum_size = Vector2(24, 24)
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n := UiTheme.text(num, 12, BanhTet.WHITE, "extrabold")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	circle.add_child(n)
	row.add_child(circle)
	var t := UiTheme.text(title.to_upper(), 14, color, "bold")
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_section_titles.append(t)
	row.add_child(t)
	return row


## Ô nhập có nhãn (Label text-xs font-semibold + dấu * đỏ) + dòng lỗi
func _field(label_text: String, required: bool, control: Control, key: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 3)
	lrow.add_child(UiTheme.text(label_text, 12, GRAY_900_TW, "semibold"))
	if required:
		lrow.add_child(UiTheme.text("*", 12, BanhTet.RED_500, "semibold"))
	v.add_child(lrow)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(control)
	if key != "":
		var err := UiTheme.text("", 12, BanhTet.RED_600)
		err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		err.visible = false
		v.add_child(err)
		_errors[key] = err
	return v


func _input_box(placeholder: String) -> LineEdit:
	var e := UiTheme.line_edit(placeholder)
	e.custom_minimum_size.y = 32
	return e


## ------------------------------------------------- 1. Thông tin khách hàng
func _build_customer_section() -> Control:
	var frame := _section(BanhTet.AMBER_200, _vgradient([Color(BanhTet.AMBER_50, 1.0).lerp(BanhTet.WHITE, 0.4), BanhTet.WHITE]))
	var inner: PanelContainer = frame.get_meta("inner")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	inner.add_child(v)
	v.add_child(_section_title("1", "Thông Tin Khách Hàng", BanhTet.RED_800, BanhTet.RED_700))

	_customer_grid = GridContainer.new()
	_customer_grid.add_theme_constant_override("h_separation", 16)
	_customer_grid.add_theme_constant_override("v_separation", 16)
	v.add_child(_customer_grid)

	_name_edit = _input_box("Nhập tên người đặt...")
	_customer_grid.add_child(_field("Họ & Tên Khách Hàng", true, _name_edit, "customerName"))
	_phone_edit = _input_box("0901234567")
	_phone_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PHONE
	_customer_grid.add_child(_field("Số Điện Thoại Liên Hệ", true, _phone_edit, "phone"))

	# Địa chỉ: md:col-span-2 -> nằm riêng 1 hàng phía dưới lưới
	_address_edit = _input_box("Số nhà, đường, phường/xã...")
	_address_field = _field("Địa Chỉ Giao Hàng", true, _address_edit, "address")
	v.add_child(_address_field)
	return frame


## ------------------------------------------------ 2. Chọn loại bánh
func _build_product_section() -> Control:
	var frame := _section(EMERALD_200, BanhTet.WHITE)
	var inner: PanelContainer = frame.get_meta("inner")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	inner.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var title := _section_title("2", "Chọn Loại Bánh & Số Lượng", EMERALD_800, EMERALD_700)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pill := UiTheme.panel(UiTheme.box_style(EMERALD_100, Color.TRANSPARENT, 999, 8, 4))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pill_label := UiTheme.text("", 11, EMERALD_800, "bold")
	pill_label.name = "PillLabel"
	pill.add_child(pill_label)
	title.add_child(pill)
	head.add_child(title)
	_product_note = UiTheme.text("Giá đã bao gồm lá bọc & luộc chuẩn", 12, GRAY_500_TW)
	_product_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_product_note)

	_product_grid = GridContainer.new()
	_product_grid.add_theme_constant_override("h_separation", 12)
	_product_grid.add_theme_constant_override("v_separation", 12)
	_product_grid.set_meta("pill", pill_label)
	v.add_child(_product_grid)

	var err := UiTheme.text("", 12, BanhTet.RED_600, "medium")
	err.visible = false
	v.add_child(err)
	_errors["quantities"] = err

	_rebuild_products()
	return frame


func _rebuild_products() -> void:
	if _product_grid == null:
		return
	for c in _product_grid.get_children():
		c.queue_free()
	_qty_edits.clear()
	_product_cards.clear()
	var products: Array = store.products if store else []
	(_product_grid.get_meta("pill") as Label).text = "%d LOẠI" % products.size()
	for p in products:
		_product_grid.add_child(_build_product_card(p))
	_product_grid.add_child(_build_add_tile())
	_refresh_quantities()
	_apply_responsive()


func _product_texture(product: Dictionary) -> Texture2D:
	var file := str(product.get("icon", "")).get_file()
	if file == "":
		file = "banh-chung.png" if str(product.get("category", "")) == "CHUNG" else "banh-tet.png"
	var path := "res://assets/anh/%s" % file
	if ResourceLoader.exists(path):
		return load(path)
	return load("res://assets/anh/banh-chung.png")


func _card_style(selected: bool, hover: bool) -> StyleBoxFlat:
	var border := EMERALD_400 if (selected or hover) else GRAY_200_TW
	var st := UiTheme.box_style(BanhTet.WHITE, border, 16, 16, 16)
	st.shadow_color = Color(0, 0, 0, 0.08 if hover else 0.05)
	st.shadow_size = 6 if hover else 2
	st.shadow_offset = Vector2(0, 2 if hover else 1)
	if selected and not hover:
		# ring-1 ring-emerald-100
		st.expand_margin_left = 0
		st.shadow_color = Color(EMERALD_100, 1.0)
		st.shadow_size = 2
		st.shadow_offset = Vector2.ZERO
	return st


func _build_product_card(product: Dictionary) -> Control:
	var id := str(product.get("id", ""))
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 220
	card.add_theme_stylebox_override("panel", _card_style(false, false))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.mouse_entered.connect(func(): _set_card_hover(id, true))
	card.mouse_exited.connect(func(): _set_card_hover(id, false))
	_product_cards[id] = card

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	# Ảnh + tên + giá
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(top)
	var img_box := UiTheme.panel(UiTheme.box_style(EMERALD_50, Color.TRANSPARENT, 12, 4, 4))
	img_box.custom_minimum_size = Vector2(40, 40)
	img_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var img := TextureRect.new()
	img.texture = _product_texture(product)
	img.custom_minimum_size = Vector2(32, 32)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img_box.add_child(img)
	top.add_child(img_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	top.add_child(info)
	var name := UiTheme.text(str(product.get("name", id)), 14, GRAY_800_TW, "bold")
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name)
	var price := RichTextLabel.new()
	price.bbcode_enabled = true
	price.fit_content = true
	price.scroll_active = false
	price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	price.add_theme_font_override("normal_font", UiTheme.font("regular"))
	price.add_theme_font_override("bold_font", UiTheme.font("semibold"))
	price.add_theme_font_size_override("normal_font_size", 12)
	price.add_theme_font_size_override("bold_font_size", 12)
	price.text = "[b][color=#047857]%s / bánh[/color][/b] [color=#9ca3af](%s)[/color]" % [
		BanhTet.format_money(int(product.get("price", 0))), str(product.get("weight", "")),
	]
	info.add_child(price)

	# Viền trên + bộ đếm số lượng
	var line := ColorRect.new()
	line.color = GRAY_100_TW
	line.custom_minimum_size.y = 1
	v.add_child(line)
	var stepper := HBoxContainer.new()
	stepper.alignment = BoxContainer.ALIGNMENT_END
	stepper.add_theme_constant_override("separation", 8)
	v.add_child(stepper)

	stepper.add_child(_step_button("minus", GRAY_100_TW, Color("#e5e7eb"), GRAY_900_TW, func(): _change_qty(id, -1)))
	var qty := LineEdit.new()
	qty.text = "0"
	qty.alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty.custom_minimum_size = Vector2(56, 36)
	qty.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	qty.add_theme_font_override("font", UiTheme.font("bold"))
	var qs := UiTheme.web_input_style(false, 4, 4)
	var qf := UiTheme.web_input_style(true, 4, 4)
	qty.add_theme_stylebox_override("normal", qs)
	qty.add_theme_stylebox_override("focus", qf)
	# onFocus: clearZeroOnFocus - xoá số 0 khi bấm vào
	qty.focus_entered.connect(func():
		if qty.text == "0":
			qty.text = "")
	qty.focus_exited.connect(func(): _set_qty_from_text(id, qty.text))
	qty.text_submitted.connect(func(t): _set_qty_from_text(id, t))
	stepper.add_child(qty)
	_qty_edits[id] = qty
	stepper.add_child(_step_button("plus", EMERALD_100, EMERALD_200, EMERALD_800, func(): _change_qty(id, 1)))
	return card


func _step_button(icon_name: String, bg: Color, hover: Color, fg: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.icon = UiTheme.icon_texture(icon_name, 14, fg)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(36, 36)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UiTheme.box_style(bg, Color.TRANSPARENT, 8))
	b.add_theme_stylebox_override("hover", UiTheme.box_style(hover, Color.TRANSPARENT, 8))
	b.add_theme_stylebox_override("pressed", UiTheme.box_style(hover, Color.TRANSPARENT, 8))
	b.pressed.connect(cb)
	return b


## Ô "Thêm loại bánh": viền đứt nét vàng, nền amber-50/50
func _build_add_tile() -> Control:
	var tile := _DashedTile.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size.y = 220
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.focus_mode = Control.FOCUS_NONE
	for k in ["normal", "hover", "pressed", "focus"]:
		tile.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(v)
	var plus := UiTheme.icon("plus", 24, BanhTet.AMBER_700)
	plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(plus)
	var t := UiTheme.text("Thêm loại bánh", 12, BanhTet.AMBER_700, "bold")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	tile.mouse_entered.connect(func():
		tile.hovered = true
		plus.texture = UiTheme.icon_texture("plus", 24, EMERALD_700)
		t.add_theme_color_override("font_color", EMERALD_700)
		tile.queue_redraw())
	tile.mouse_exited.connect(func():
		tile.hovered = false
		plus.texture = UiTheme.icon_texture("plus", 24, BanhTet.AMBER_700)
		t.add_theme_color_override("font_color", BanhTet.AMBER_700)
		tile.queue_redraw())
	tile.pressed.connect(_show_add_product_dialog)
	_product_cards["__add__"] = tile
	return tile


func _set_card_hover(id: String, hover: bool) -> void:
	var card: PanelContainer = _product_cards.get(id)
	if card == null:
		return
	card.add_theme_stylebox_override("panel", _card_style(int(_quantities.get(id, 0)) > 0, hover))


## --------------------------------------------- 3. Lịch giao & trạng thái
func _build_schedule_section() -> Control:
	var frame := _section(GRAY_200_TW, BanhTet.WHITE)
	var inner: PanelContainer = frame.get_meta("inner")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	inner.add_child(v)
	v.add_child(_section_title("3", "Lịch Giao & Trạng Thái", GRAY_700_TW, GRAY_700_TW))

	_schedule_grid = GridContainer.new()
	_schedule_grid.add_theme_constant_override("h_separation", 16)
	_schedule_grid.add_theme_constant_override("v_separation", 16)
	v.add_child(_schedule_grid)

	# Ngày giao
	_date_edit = _input_box("YYYY-MM-DD")
	_date_edit.text = BanhTet.DEFAULT_DELIVERY_DATE
	_date_edit.add_theme_color_override("font_color", BanhTet.RED_700)
	_date_edit.add_theme_font_override("font", UiTheme.font("medium"))
	var date_field := _field("Ngày Giao Hàng", true, _date_edit, "deliveryDate")
	var date_chips := HFlowContainer.new()
	date_chips.add_theme_constant_override("h_separation", 4)
	date_chips.add_theme_constant_override("v_separation", 4)
	for d in BanhTet.DELIVERY_DATE_SUGGESTIONS:
		var val := str(d["value"])
		date_chips.add_child(_chip(str(d["short"]), func(): _date_edit.text = val))
	date_field.add_child(date_chips)
	_schedule_grid.add_child(date_field)

	# Khung giờ
	_time_edit = _input_box("VD: Sáng (07:00 - 11:00)")
	_time_edit.text = BanhTet.DEFAULT_DELIVERY_TIME
	var time_field := _field("Khung Giờ Nhận Bánh", true, _time_edit, "deliveryTime")
	var time_chips := HFlowContainer.new()
	time_chips.add_theme_constant_override("h_separation", 4)
	time_chips.add_theme_constant_override("v_separation", 4)
	for t in BanhTet.DELIVERY_TIME_SUGGESTIONS:
		var tv := str(t)
		time_chips.add_child(_chip(tv.split(" (")[0], func(): _time_edit.text = tv))
	time_field.add_child(time_chips)
	_schedule_grid.add_child(time_field)

	# Trạng thái
	var labels: Array = []
	for s in BanhTet.ORDER_STATUSES:
		labels.append(str(BanhTet.STATUS_LABELS[s]))
	_status_option = UiTheme.option_button(labels)
	_status_option.custom_minimum_size.y = 32
	_status_option.add_theme_font_override("font", UiTheme.font("semibold"))
	var status_field := _field("Trạng Thái Đơn Hàng", false, _status_option)
	status_field.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_schedule_grid.add_child(status_field)
	return frame


func _chip(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 32
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_font_override("font", UiTheme.font("semibold"))
	b.add_theme_stylebox_override("normal", UiTheme.box_style(BanhTet.AMBER_50, BanhTet.AMBER_200, 6, 8, 4))
	b.add_theme_stylebox_override("hover", UiTheme.box_style(BanhTet.AMBER_100, BanhTet.RED_300, 6, 8, 4))
	b.add_theme_stylebox_override("pressed", UiTheme.box_style(BanhTet.AMBER_100, BanhTet.RED_300, 6, 8, 4))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, BanhTet.AMBER_800)
	b.pressed.connect(cb)
	return b


## ---------------------------------------------- 4. Thanh toán & ghi chú
func _build_payment_section() -> Control:
	var frame := _section(BanhTet.RED_200, _hgradient([BanhTet.RED_50, BanhTet.RED_50.lerp(BanhTet.WHITE, 0.5)]))
	var inner: PanelContainer = frame.get_meta("inner")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	inner.add_child(v)
	v.add_child(_section_title("4", "Thanh Toán & Ghi Chú", BanhTet.RED_800, BanhTet.RED_700))

	var box_style := UiTheme.box_style(BanhTet.WHITE, BanhTet.RED_200, 12, 16, 16)
	var box := UiTheme.panel(box_style)
	v.add_child(box)
	_pay_box = BoxContainer.new()
	_pay_box.add_theme_constant_override("separation", 12)
	box.add_child(_pay_box)

	# Tổng giá trị
	_pay_total_box = BoxContainer.new()
	_pay_total_box.add_theme_constant_override("separation", 2)
	_pay_total_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pay_box.add_child(_pay_total_box)
	var tl := UiTheme.text("Tổng giá trị đơn bánh:", 12, GRAY_600_TW)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pay_total_box.add_child(tl)
	_total_label = UiTheme.text("0 đ", 30, BanhTet.RED_700, "extrabold")
	_pay_total_box.add_child(_total_label)

	# Đặt cọc + còn lại
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 16)
	right.size_flags_horizontal = Control.SIZE_FILL
	_pay_box.add_child(right)
	_deposit_edit = _input_box("0")
	_deposit_edit.text = "0"
	_deposit_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_deposit_edit.add_theme_color_override("font_color", BanhTet.AMBER_700)
	_deposit_edit.add_theme_font_override("font", UiTheme.font("bold"))
	_deposit_edit.text_changed.connect(func(_t): _recalculate())
	_deposit_edit.focus_entered.connect(func():
		if _deposit_edit.text == "0":
			_deposit_edit.text = "")
	_deposit_wrap = _field("Số Tiền Đã Đặt Cọc (₫)", false, _deposit_edit)
	_deposit_wrap.size_flags_vertical = Control.SIZE_SHRINK_END
	right.add_child(_deposit_wrap)

	var remain_box := UiTheme.panel(UiTheme.box_style(Color("#f9fafb"), Color.TRANSPARENT, 8, 12, 8))
	remain_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remain_box.size_flags_vertical = Control.SIZE_SHRINK_END
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 0)
	remain_box.add_child(rv)
	rv.add_child(UiTheme.text("Còn lại cần thu:", 12, GRAY_600_TW))
	_remain_label = UiTheme.text("0 đ", 18, GRAY_900_TW, "bold")
	rv.add_child(_remain_label)
	right.add_child(remain_box)

	# Ghi chú
	_notes_edit = UiTheme.text_area("Ví dụ: Bớt mỡ, nhiều đậu xanh, buộc lạt đỏ mừng thọ, hút chân không...")
	_notes_edit.custom_minimum_size.y = 64
	v.add_child(_field("Ghi Chú Đặc Biệt Về Nhân/Đóng Gói", false, _notes_edit))
	return frame


## ------------------------------------------------------------ Nút cuối form
func _build_footer() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 16)
	var line := ColorRect.new()
	line.color = GRAY_200_TW
	line.custom_minimum_size.y = 1
	wrap.add_child(line)

	_footer = BoxContainer.new()
	_footer.add_theme_constant_override("separation", 8)
	wrap.add_child(_footer)

	var cancel := Button.new()
	cancel.text = "Về danh sách đơn"
	cancel.custom_minimum_size.y = 32
	cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel.add_theme_font_size_override("font_size", 14)
	cancel.add_theme_font_override("font", UiTheme.font("medium"))
	cancel.add_theme_stylebox_override("normal", UiTheme.box_style(GRAY_100_TW, Color.TRANSPARENT, 8, 12, 6))
	cancel.add_theme_stylebox_override("hover", UiTheme.box_style(GRAY_200_TW, Color.TRANSPARENT, 8, 12, 6))
	cancel.add_theme_stylebox_override("pressed", UiTheme.box_style(GRAY_200_TW, Color.TRANSPARENT, 8, 12, 6))
	cancel.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		cancel.add_theme_color_override(c, GRAY_900_TW)
	cancel.pressed.connect(_go_to_list)
	_footer.add_child(cancel)

	_submit_btn = Button.new()
	_submit_btn.text = "Tạo Đơn Hàng"
	_submit_btn.custom_minimum_size.y = 32
	_submit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_submit_btn.add_theme_font_size_override("font_size", 14)
	_submit_btn.add_theme_font_override("font", UiTheme.font("bold"))
	_submit_btn.add_theme_stylebox_override("normal", UiTheme.box_style(BanhTet.RED_700, Color.TRANSPARENT, 8, 12, 6))
	_submit_btn.add_theme_stylebox_override("hover", UiTheme.box_style(BanhTet.RED_800, Color.TRANSPARENT, 8, 12, 6))
	_submit_btn.add_theme_stylebox_override("pressed", UiTheme.box_style(BanhTet.RED_800, Color.TRANSPARENT, 8, 12, 6))
	_submit_btn.add_theme_stylebox_override("disabled", UiTheme.box_style(BanhTet.RED_700.lerp(BanhTet.WHITE, 0.5), Color.TRANSPARENT, 8, 12, 6))
	_submit_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		_submit_btn.add_theme_color_override(c, BanhTet.WHITE)
	_submit_btn.pressed.connect(_on_save_pressed)
	_footer.add_child(_submit_btn)
	return wrap


## ================================================================ Số lượng
func _change_qty(product_id: String, delta: int) -> void:
	var next := maxi(0, int(_quantities.get(product_id, 0)) + delta)
	_set_qty(product_id, next)


func _set_qty_from_text(product_id: String, text: String) -> void:
	var n := text.strip_edges()
	_set_qty(product_id, maxi(0, n.to_int()) if n.is_valid_int() else 0)


func _set_qty(product_id: String, qty: int) -> void:
	if qty > 0:
		_quantities[product_id] = qty
	else:
		_quantities.erase(product_id)
	_refresh_quantities()
	_recalculate()


func _refresh_quantities() -> void:
	for id in _qty_edits:
		var e: LineEdit = _qty_edits[id]
		if not e.has_focus():
			e.text = str(int(_quantities.get(id, 0)))
		_set_card_hover(id, false)


func _recalculate() -> void:
	if _total_label == null or store == null:
		return
	var total := BanhTet.calculate_total(_quantities, store.products)
	var deposit := maxi(0, _deposit_edit.text.to_int())
	_total_label.text = BanhTet.format_money(total)
	_remain_label.text = BanhTet.format_money(maxi(0, total - deposit))
	if not _quantities.is_empty():
		_set_error("quantities", "")


## ================================================================== Lưu đơn
func _set_error(key: String, msg: String) -> void:
	var l: Label = _errors.get(key)
	if l:
		l.text = msg
		l.visible = msg != ""


func _validate() -> bool:
	var ok := true
	var name := _name_edit.text.strip_edges()
	var phone := _phone_edit.text.strip_edges()
	var address := _address_edit.text.strip_edges()
	var date := _date_edit.text.strip_edges()
	var time := _time_edit.text.strip_edges()

	var phone_re := RegEx.create_from_string("^(0|\\+84)\\d{9,10}$")
	var date_re := RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$")
	var checks := {
		"customerName": "" if name.length() >= 2 else "Vui lòng nhập họ tên khách hàng",
		"phone": "" if phone_re.search(phone) else "Số điện thoại không hợp lệ (VD: 0901234567)",
		"address": "" if address.length() >= 5 else "Vui lòng nhập địa chỉ giao hàng",
		"deliveryDate": "" if date_re.search(date) else "Vui lòng nhập ngày giao hàng (YYYY-MM-DD)",
		"deliveryTime": "" if time.length() >= 1 else "Vui lòng nhập khung giờ nhận bánh",
		"quantities": "" if not _quantities.is_empty() else "Vui lòng chọn ít nhất 01 loại bánh để đặt!",
	}
	for k in checks:
		_set_error(k, checks[k])
		if checks[k] != "":
			ok = false
	return ok


func _on_save_pressed() -> void:
	if not _validate():
		return

	var payload := {
		"customerName": _name_edit.text.strip_edges(),
		"phone": _phone_edit.text.strip_edges(),
		"address": _address_edit.text.strip_edges(),
		"deliveryDate": _date_edit.text.strip_edges(),
		"deliveryTime": _time_edit.text.strip_edges(),
		"items": _quantities.duplicate(),
		"totalAmount": BanhTet.calculate_total(_quantities, store.products),
		"deposit": maxi(0, _deposit_edit.text.to_int()),
		"status": BanhTet.ORDER_STATUSES[maxi(0, _status_option.selected)],
		"notes": _notes_edit.text.strip_edges(),
	}

	_submit_btn.disabled = true
	var label_before := _submit_btn.text
	_submit_btn.text = "Đang lưu..."

	if _editing_id != "":
		var updated := await store.update_order(_editing_id, payload)
		_submit_btn.disabled = false
		_submit_btn.text = label_before
		if updated.is_empty():
			_toast("Không cập nhật được đơn hàng. Kiểm tra kết nối / quyền quản trị.", false)
			return
		_toast("Đã cập nhật đơn hàng #%s" % _editing_id, true)
		_go_to_list()
		return

	payload["id"] = store.next_order_id()
	payload["createdAt"] = BanhTet.today_iso()
	var created := await store.create_order(payload)
	_submit_btn.disabled = false
	_submit_btn.text = label_before
	if created.is_empty():
		_toast("Không lưu được đơn hàng. Kiểm tra kết nối / quyền quản trị.", false)
		return
	# Web: toast thành công rồi tự chuyển về trang danh sách
	_toast("Đã tạo thành công đơn hàng #%s" % str(created.get("id", "")), true)
	_go_to_list()


## Về trang Đơn Hàng (web: navigate({to: "/"}))
func _go_to_list() -> void:
	var main := get_tree().current_scene
	if main and main.has_method("_show_screen"):
		main.call("_show_screen", "orders")


## Toast giống sonner: góc dưới giữa, tự ẩn sau 3 giây (gắn vào scene chính
## để vẫn hiện sau khi chuyển màn hình)
func _toast(message: String, success: bool) -> void:
	var host := get_tree().current_scene
	if host == null:
		host = self
	var st := UiTheme.box_style(BanhTet.WHITE, GRAY_200_TW, 8, 16, 12)
	st.shadow_color = Color(0, 0, 0, 0.12)
	st.shadow_size = 10
	st.shadow_offset = Vector2(0, 4)
	var p := UiTheme.panel(st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	row.add_child(UiTheme.text("✅" if success else "⛔", 14, GRAY_900_TW))
	var l := UiTheme.text(message, 13, GRAY_900_TW, "medium")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 260
	row.add_child(l)
	p.top_level = true
	p.z_index = 100
	host.add_child(p)
	await get_tree().process_frame
	var vp: Vector2 = host.get_viewport_rect().size
	p.position = Vector2((vp.x - p.size.x) / 2.0, vp.y - p.size.y - 80)
	var tw := p.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


## ============================================= Hộp thoại Thêm loại bánh
func _show_add_product_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Thêm Loại Bánh Mới"
	dialog.dialog_hide_on_ok = false
	dialog.ok_button_text = "Thêm Loại Bánh"

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.custom_minimum_size.x = 340

	var name_edit := _input_box("VD: Bánh Chưng Nhân Đỗ Đỏ")
	v.add_child(_field("Tên Loại Bánh", true, name_edit, "p_name"))

	var grid := GridContainer.new()
	grid.columns = 2 if get_viewport_rect().size.x >= UiTheme.BP_SM else 1
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	v.add_child(grid)
	var price_edit := _input_box("0")
	price_edit.text = "0"
	price_edit.add_theme_color_override("font_color", BanhTet.AMBER_700)
	price_edit.add_theme_font_override("font", UiTheme.font("bold"))
	price_edit.focus_entered.connect(func():
		if price_edit.text == "0":
			price_edit.text = "")
	grid.add_child(_field("Giá Bán / Cái (₫)", true, price_edit, "p_price"))
	var weight_edit := _input_box("1.2 kg")
	grid.add_child(_field("Khối Lượng", false, weight_edit))
	var cat := UiTheme.option_button([BanhTet.PRODUCT_CATEGORIES["CHUNG"], BanhTet.PRODUCT_CATEGORIES["TET"]])
	cat.custom_minimum_size.y = 32
	grid.add_child(_field("Loại Bánh", true, cat))

	dialog.add_child(v)
	dialog.add_cancel_button("Hủy Bỏ")
	add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(_on_add_product_confirmed.bind(dialog, name_edit, price_edit, weight_edit, cat))
	dialog.popup_centered(Vector2i(420, 0))
	name_edit.grab_focus()


func _on_add_product_confirmed(dialog: AcceptDialog, name_edit: LineEdit, price_edit: LineEdit, weight_edit: LineEdit, cat: OptionButton) -> void:
	var pname := name_edit.text.strip_edges()
	var price := price_edit.text.strip_edges().to_int()
	_set_error("p_name", "" if pname.length() >= 2 else "Vui lòng nhập tên loại bánh")
	_set_error("p_price", "" if price > 0 else "Giá phải lớn hơn 0")
	if pname.length() < 2 or price <= 0:
		return
	var category := "CHUNG" if cat.selected == 0 else "TET"
	var weight := weight_edit.text.strip_edges()
	var created: Dictionary = await store.api.create("products", {
		"name": pname,
		"price": price,
		"category": category,
		"icon": "/banh-chung.png" if category == "CHUNG" else "/banh-tet.png",
		"weight": weight if weight != "" else "1.0 kg",
	})
	if created.is_empty():
		_toast("Không thêm được loại bánh. Kiểm tra quyền quản trị.", false)
		return
	store.products.append(created)
	store.products_changed.emit()
	_toast("Đã thêm loại bánh \"%s\"" % pname, true)
	dialog.hide()
	dialog.queue_free()


## ================================================================= Helpers
func _hgradient(colors: Array) -> GradientTexture2D:
	return _gradient(colors, Vector2(0, 0), Vector2(1, 0))


func _vgradient(colors: Array) -> GradientTexture2D:
	return _gradient(colors, Vector2(0, 0), Vector2(0, 1))


func _gradient(colors: Array, from: Vector2, to: Vector2) -> GradientTexture2D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / max(1, colors.size() - 1))
		cols.append(colors[i])
	g.offsets = offsets
	g.colors = cols
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 64
	tex.height = 64
	return tex


## Container cắt nội dung theo hình bo góc (dùng cho nền gradient bo góc)
class _RoundClip extends PanelContainer:
	var radius := 16

	func _ready() -> void:
		var st := StyleBoxFlat.new()
		st.bg_color = Color.WHITE
		st.set_corner_radius_all(radius)
		st.anti_aliasing = true
		add_theme_stylebox_override("panel", st)
		clip_children = CanvasItem.CLIP_CHILDREN_ONLY


## Ô viền đứt nét (border-2 border-dashed border-amber-300 bg-amber-50/50)
class _DashedTile extends Button:
	var hovered := false

	func _draw() -> void:
		var border := Color("#34d399") if hovered else Color("#fcd34d")
		var bg := Color("#ecfdf5") if hovered else Color(1.0, 0.98, 0.941, 0.5)
		var r := Rect2(Vector2.ONE, size - Vector2(2, 2))
		var st := StyleBoxFlat.new()
		st.bg_color = bg
		st.set_corner_radius_all(16)
		st.anti_aliasing = true
		draw_style_box(st, Rect2(Vector2.ZERO, size))
		var rad := 16.0
		var dash := 6.0
		var gap := 4.0
		# 4 cạnh thẳng
		_dash_line(Vector2(r.position.x + rad, r.position.y), Vector2(r.end.x - rad, r.position.y), border, dash, gap)
		_dash_line(Vector2(r.position.x + rad, r.end.y), Vector2(r.end.x - rad, r.end.y), border, dash, gap)
		_dash_line(Vector2(r.position.x, r.position.y + rad), Vector2(r.position.x, r.end.y - rad), border, dash, gap)
		_dash_line(Vector2(r.end.x, r.position.y + rad), Vector2(r.end.x, r.end.y - rad), border, dash, gap)
		# 4 góc bo
		draw_arc(r.position + Vector2(rad, rad), rad, PI, PI * 1.5, 12, border, 2.0, true)
		draw_arc(Vector2(r.end.x - rad, r.position.y + rad), rad, PI * 1.5, TAU, 12, border, 2.0, true)
		draw_arc(Vector2(r.end.x - rad, r.end.y - rad), rad, 0, PI * 0.5, 12, border, 2.0, true)
		draw_arc(Vector2(r.position.x + rad, r.end.y - rad), rad, PI * 0.5, PI, 12, border, 2.0, true)

	func _dash_line(a: Vector2, b: Vector2, color: Color, dash: float, gap: float) -> void:
		var length := a.distance_to(b)
		var dir := (b - a).normalized()
		var d := 0.0
		while d < length:
			var e := minf(d + dash, length)
			draw_line(a + dir * d, a + dir * e, color, 2.0)
			d += dash + gap
