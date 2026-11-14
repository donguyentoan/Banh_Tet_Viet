extends VBoxContainer

## Màn hình "Bỏ Bánh Cho Mối Chợ" - port 1:1 từ wholesale-page.tsx:
##   Banner tiêu đề (gradient đỏ -> hổ phách, tổng bánh + tổng tiền sỉ)
##   Lưới lg:[320px_1fr]:
##     - Trái: "Danh Sách Mối Chợ" (thu gọn được) + MarketList
##     - Phải: "Lịch Bỏ Bánh Sỉ Theo Ngày" + chọn ngày + In tất cả + DistributionTable
##   Dialog thêm/sửa mối chợ (MarketFormDialog) + xem trước phiếu giao sỉ

var store: BakeryStore

## marketId -> { productId -> qty } của ngày đang chọn
var _quantities := {}
var _selected_date: String = str(BanhTet.DELIVERY_DATE_SUGGESTIONS[1]["value"])
var _selected_market_id := ""
var _market_list_open := false
var _wide := true
var _last_layout := ""

var _banner_box: BoxContainer
var _banner_subtitle: Control
var _banner_stats: GridContainer
var _banner_icon_box: PanelContainer
var _banner_title: Label
var _day_qty_label: Label
var _day_total_label: Label
var _stat_boxes: Array[PanelContainer] = []

var _columns: BoxContainer
var _left_card: PanelContainer
var _market_count_label: Label
var _market_chevron: TextureRect
var _market_list_box: VBoxContainer
var _right_header_box: HFlowContainer
var _right_tools: BoxContainer
var _date_select: OptionButton
var _dist_box: VBoxContainer

## Tham chiếu để cập nhật tại chỗ khi gõ số lượng (không dựng lại -> giữ focus)
## marketId -> { "qty_badge": Label, "money_badge": Label, "save": Button,
##               "footer": Label, "line": { productId -> Label }, "edit": { productId -> LineEdit } }
var _market_refs := {}


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 24)

	add_child(_build_banner())

	_columns = BoxContainer.new()
	_columns.add_theme_constant_override("separation", 24)
	add_child(_columns)

	_left_card = _build_left_card()
	_columns.add_child(_left_card)
	_columns.add_child(_build_right_card())

	store.wholesale_changed.connect(_reload)
	store.products_changed.connect(_reload)
	store.data_loaded.connect(_reload)
	get_viewport().size_changed.connect(_apply_responsive)
	_reload()
	_apply_responsive()


## ============================================================ Responsive
func _apply_responsive() -> void:
	var w := get_viewport_rect().size.x
	var layout := "lg" if w >= UiTheme.BP_LG else ("md" if w >= UiTheme.BP_MD else ("sm" if w >= UiTheme.BP_SM else "xs"))
	if layout == _last_layout:
		return
	_last_layout = layout
	var was_wide := _wide
	_wide = w >= UiTheme.BP_SM

	# mb-5 sm:mb-6 (khoảng cách giữa banner và lưới)
	add_theme_constant_override("separation", 24 if _wide else 20)

	# Banner: md:flex-row, dưới md xếp dọc
	_banner_box.vertical = w < UiTheme.BP_MD
	_banner_subtitle.visible = _wide
	_banner_title.add_theme_font_size_override("font_size", 24 if _wide else 18)
	_banner_icon_box.custom_minimum_size = Vector2(56, 56) if _wide else Vector2(44, 44)
	var bs := _banner_box.get_parent().get_theme_stylebox("panel") as StyleBox
	bs.content_margin_left = 24 if _wide else 16
	bs.content_margin_right = 24 if _wide else 16
	bs.content_margin_top = 24 if _wide else 16
	bs.content_margin_bottom = 24 if _wide else 16
	_banner_box.add_theme_constant_override("separation", 16 if _wide else 12)
	# grid-cols-2 (điện thoại, ô nền trắng mờ) / sm:flex (chữ căn phải, không nền)
	_banner_stats.columns = 2
	for box in _stat_boxes:
		var st := box.get_theme_stylebox("panel") as StyleBoxFlat
		st.bg_color = Color(1, 1, 1, 0.0 if _wide else 0.1)
		st.content_margin_left = 0 if _wide else 12
		st.content_margin_right = 0 if _wide else 12
		st.content_margin_top = 0 if _wide else 8
		st.content_margin_bottom = 0 if _wide else 8
		for lbl in box.get_child(0).get_children():
			(lbl as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if _wide else HORIZONTAL_ALIGNMENT_LEFT
	_banner_stats.add_theme_constant_override("h_separation", 16 if _wide else 8)
	_banner_stats.size_flags_horizontal = Control.SIZE_SHRINK_END if not _banner_box.vertical else Control.SIZE_FILL
	var sep := _banner_stats.get_parent().get_child(0) as Control
	sep.visible = not _wide  # border-t border-white/20 pt-3 chỉ trên điện thoại

	# Lưới: lg:grid-cols-[320px_1fr]
	_columns.vertical = w < UiTheme.BP_LG
	_left_card.custom_minimum_size.x = 320 if not _columns.vertical else 0
	_left_card.size_flags_horizontal = Control.SIZE_FILL if not _columns.vertical else Control.SIZE_EXPAND_FILL
	_left_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_right_tools.vertical = w < 420
	_right_tools.alignment = BoxContainer.ALIGNMENT_BEGIN

	# Bảng phân phối: thẻ sản phẩm (điện thoại) / bảng (sm+)
	if was_wide != _wide:
		_rebuild_distribution()


## ================================================================ Banner
func _build_banner() -> Control:
	var st := StyleBoxTexture.new()
	st.texture = _gradient([BanhTet.RED_800, BanhTet.RED_700, BanhTet.AMBER_700])
	# Nền khung phải đặc: clip_children dùng alpha của khung làm mặt nạ cho con
	var outer_style := UiTheme.box_style(BanhTet.RED_800, BanhTet.AMBER_300, 16)
	outer_style.shadow_color = Color(0, 0, 0, 0.15)
	outer_style.shadow_size = 10
	outer_style.shadow_offset = Vector2(0, 4)
	outer_style.set_content_margin_all(1)
	# Khung bo góc + viền vàng bọc ngoài, nền gradient bên trong
	var frame := UiTheme.panel(outer_style)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var inner := UiTheme.panel(st)
	frame.add_child(inner)

	_banner_box = BoxContainer.new()
	_banner_box.add_theme_constant_override("separation", 16)
	inner.add_child(_banner_box)

	# --- Trái: icon + tiêu đề ---
	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 16)
	_banner_box.add_child(left)

	var icon_style := UiTheme.box_style(Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.25), 16)
	_banner_icon_box = UiTheme.panel(icon_style)
	_banner_icon_box.custom_minimum_size = Vector2(56, 56)
	_banner_icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := UiTheme.icon("store", 28, Color("#fcd34d"))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner_icon_box.add_child(ic)
	left.add_child(_banner_icon_box)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_theme_constant_override("separation", 4)
	left.add_child(titles)

	var title_row := HFlowContainer.new()
	title_row.add_theme_constant_override("h_separation", 8)
	title_row.add_theme_constant_override("v_separation", 4)
	titles.add_child(title_row)
	_banner_title = UiTheme.text("Bỏ Bánh Cho Mối Chợ", 24, BanhTet.WHITE, "extrabold")
	title_row.add_child(_banner_title)
	var badge := UiTheme.panel(UiTheme.box_style(BanhTet.AMBER_400, BanhTet.AMBER_300, 999, 8, 2))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(UiTheme.text("BÁN SỈ", 11, Color("#451a03"), "extrabold"))
	title_row.add_child(badge)

	_banner_subtitle = UiTheme.text(
		"Quản lý tiểu thương, lịch bỏ bánh theo ngày & in phiếu giao sỉ", 12, BanhTet.RED_100, "medium"
	)
	(_banner_subtitle as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_banner_subtitle)

	# --- Phải: thống kê ---
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_banner_box.add_child(right)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.2)
	line.custom_minimum_size.y = 1
	right.add_child(line)

	_banner_stats = GridContainer.new()
	_banner_stats.columns = 2
	_banner_stats.add_theme_constant_override("v_separation", 8)
	right.add_child(_banner_stats)
	_day_qty_label = _banner_stat("Tổng bánh trong ngày")
	_day_total_label = _banner_stat("Tổng tiền sỉ")
	return frame


func _banner_stat(caption: String) -> Label:
	var box := UiTheme.panel(UiTheme.box_style(Color(1, 1, 1, 0.1), Color.TRANSPARENT, 12, 12, 8))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	v.add_child(UiTheme.text(caption, 11, BanhTet.RED_100))
	var value := UiTheme.text("0", 22, Color("#fcd34d"), "extrabold")
	v.add_child(value)
	_banner_stats.add_child(box)
	_stat_boxes.append(box)
	return value


## ===================================================== Cột trái: mối chợ
func _build_left_card() -> PanelContainer:
	var card := _section_card()
	var col := card.get_child(0) as VBoxContainer

	# Header (bấm để mở/thu danh sách)
	var hs := StyleBoxTexture.new()
	hs.texture = _gradient([BanhTet.RED_50, BanhTet.WHITE])
	_pad(hs, 16, 12)
	var head := UiTheme.panel(hs)
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	head.gui_input.connect(_on_market_header_input)
	col.add_child(head)
	col.add_child(_hline(BanhTet.GRAY_200))

	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(hr)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hr.add_child(tv)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trow.add_child(UiTheme.icon("store", 16, BanhTet.RED_700))
	trow.add_child(UiTheme.text("Danh Sách Mối Chợ", 14, BanhTet.GRAY_900, "extrabold"))
	tv.add_child(trow)
	_market_count_label = UiTheme.text("0 tiểu thương đã đăng ký", 11, BanhTet.GRAY_500)
	tv.add_child(_market_count_label)

	var add_btn := _solid_button("Thêm Mối Chợ", "plus", BanhTet.WHITE)
	add_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_btn.pressed.connect(_show_market_form.bind({}))
	hr.add_child(add_btn)

	_market_chevron = UiTheme.icon("chevron-down", 16, BanhTet.RED_700)
	hr.add_child(_market_chevron)

	_market_list_box = VBoxContainer.new()
	_market_list_box.add_theme_constant_override("separation", 0)
	_market_list_box.visible = false
	col.add_child(_market_list_box)
	return card


func _on_market_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_market_list_open = not _market_list_open
		_refresh_market_list()


func _refresh_market_list() -> void:
	_market_count_label.text = "%d tiểu thương đã đăng ký" % store.markets.size()
	_market_chevron.texture = UiTheme.icon_texture("chevron-up" if _market_list_open else "chevron-down", 16, BanhTet.RED_700)
	_market_list_box.visible = _market_list_open
	for c in _market_list_box.get_children():
		c.queue_free()
	if not _market_list_open:
		return

	if store.markets.is_empty():
		_market_list_box.add_child(_empty_block(
			"🏪", "Chưa có mối chợ nào", "Bấm \"Thêm Mối Chợ\" để khai báo tiểu thương bán sỉ.", BanhTet.RED_100
		))
		return

	for i in store.markets.size():
		var market: Dictionary = store.markets[i]
		if i > 0:
			_market_list_box.add_child(_hline(BanhTet.GRAY_100))
		_market_list_box.add_child(_build_market_item(market))

	if _selected_market_id != "":
		_market_list_box.add_child(_hline(BanhTet.GRAY_200))
		var m := _margin(8, 16, 16, 8)
		var all_btn := UiTheme.tw_button("Xem tất cả mối chợ", "", "ghost", 12)
		all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		all_btn.add_theme_color_override("font_color", BanhTet.GRAY_600)
		all_btn.add_theme_color_override("font_hover_color", BanhTet.GRAY_600)
		all_btn.pressed.connect(_select_market.bind(""))
		m.add_child(all_btn)
		_market_list_box.add_child(m)


func _build_market_item(market: Dictionary) -> Control:
	var id := str(market.get("id", ""))
	var active := id == _selected_market_id
	var normal_bg := BanhTet.RED_50 if active else Color(1, 1, 1, 0)
	var item := UiTheme.panel(UiTheme.box_style(normal_bg, Color.TRANSPARENT, 0, 16, 12))
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_select_market("" if active else id))
	if not active:
		item.mouse_entered.connect(func(): (item.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = BanhTet.GRAY_50)
		item.mouse_exited.connect(func(): (item.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = normal_bg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var name_row := HFlowContainer.new()
	name_row.add_theme_constant_override("h_separation", 8)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(UiTheme.text(str(market.get("name", "")), 14, BanhTet.GRAY_900, "bold"))
	if active:
		var b := UiTheme.panel(UiTheme.box_style(BanhTet.AMBER_100, BanhTet.AMBER_300, 999, 8, 1))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_child(UiTheme.text("Đang chọn", 10, BanhTet.AMBER_900, "bold"))
		name_row.add_child(b)
	info.add_child(name_row)

	var stall := UiTheme.text("🏪 %s" % str(market.get("stall", "")), 12, BanhTet.GRAY_500)
	stall.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stall.clip_text = true
	info.add_child(stall)
	info.add_child(UiTheme.text("☎ %s" % str(market.get("phone", "")), 12, BanhTet.GRAY_600, "semibold"))
	var notes := str(market.get("notes", ""))
	if notes != "":
		var n := UiTheme.text(notes, 11, BanhTet.GRAY_400)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.max_lines_visible = 2
		info.add_child(n)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 2)
	actions.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(actions)
	actions.add_child(_icon_action("pencil", BanhTet.AMBER_600, BanhTet.AMBER_50, "Sửa mối chợ", _show_market_form.bind(market)))
	actions.add_child(_icon_action("trash-2", BanhTet.RED_600, BanhTet.RED_50, "Xoá mối chợ", _confirm_delete_market.bind(market)))
	return item


func _select_market(id: String) -> void:
	_selected_market_id = id
	_refresh_market_list()
	_rebuild_distribution()


func _confirm_delete_market(market: Dictionary) -> void:
	var d := ConfirmationDialog.new()
	d.title = "Xoá mối chợ"
	d.dialog_text = "Xoá mối chợ \"%s\"? Lịch bỏ bánh tương ứng cũng sẽ bị ảnh hưởng." % str(market.get("name", ""))
	d.dialog_autowrap = true
	d.ok_button_text = "Xoá"
	d.cancel_button_text = "Huỷ"
	d.confirmed.connect(func():
		var ok := await store.delete_market(str(market.get("id", "")))
		if ok:
			if _selected_market_id == str(market.get("id", "")):
				_selected_market_id = ""
			_toast("Đã xoá mối chợ \"%s\"" % str(market.get("name", "")), "warning")
			_reload()
		else:
			_toast("Không xoá được mối chợ", "error"))
	add_child(d)
	d.popup_centered(Vector2i(380, 160))


## ============================================ Cột phải: lịch bỏ bánh sỉ
func _build_right_card() -> PanelContainer:
	var card := _section_card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var col := card.get_child(0) as VBoxContainer

	var hs := StyleBoxTexture.new()
	hs.texture = _gradient([BanhTet.RED_50, BanhTet.WHITE, Color(BanhTet.AMBER_50, 0.5).blend(Color(1, 1, 1, 0.5))])
	_pad(hs, 16, 12)
	var head := UiTheme.panel(hs)
	col.add_child(head)
	col.add_child(_hline(BanhTet.GRAY_200))

	_right_header_box = HFlowContainer.new()
	_right_header_box.add_theme_constant_override("h_separation", 12)
	_right_header_box.add_theme_constant_override("v_separation", 12)
	head.add_child(_right_header_box)

	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	_right_header_box.add_child(tv)
	tv.add_child(UiTheme.text("Lịch Bỏ Bánh Sỉ Theo Ngày", 14, BanhTet.GRAY_900, "extrabold"))
	var sub := UiTheme.text("Nhập số lượng phân phối — tự động áp dụng giá sỉ ưu đãi", 11, BanhTet.GRAY_500)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(sub)

	# sm+: một hàng; điện thoại: select và nút xếp dọc (flex-wrap)
	var tools := BoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	_right_header_box.add_child(tools)
	_right_tools = tools

	var labels: Array = []
	for d in BanhTet.DELIVERY_DATE_SUGGESTIONS:
		labels.append(str(d["label"]))
	_date_select = UiTheme.option_button(labels)
	_date_select.custom_minimum_size = Vector2(180, 32)
	UiTheme.set_weight(_date_select, "semibold")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_date_select.add_theme_color_override(c, BanhTet.RED_700)
	for i in BanhTet.DELIVERY_DATE_SUGGESTIONS.size():
		if str(BanhTet.DELIVERY_DATE_SUGGESTIONS[i]["value"]) == _selected_date:
			_date_select.selected = i
	_date_select.item_selected.connect(_on_date_selected)
	_date_select.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tools.add_child(_date_select)

	var print_all := _solid_button("In Tất Cả Phiếu Trong Ngày", "printer", Color("#fcd34d"))
	print_all.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	print_all.pressed.connect(_on_print_all)
	tools.add_child(print_all)

	_dist_box = VBoxContainer.new()
	_dist_box.add_theme_constant_override("separation", 16)
	var m := _margin(16, 16, 16, 16)
	m.add_child(_dist_box)
	col.add_child(m)
	return card


func _on_date_selected(index: int) -> void:
	_selected_date = str(BanhTet.DELIVERY_DATE_SUGGESTIONS[index]["value"])
	_load_quantities()
	_rebuild_distribution()


## ============================================================== Dữ liệu
func _reload() -> void:
	_load_quantities()
	_refresh_market_list()
	_rebuild_distribution()


## Nạp lịch đã lưu của ngày đang chọn - mỗi tiểu thương một phiếu riêng
func _load_quantities() -> void:
	_quantities.clear()
	for market in store.markets:
		var mid := str(market.get("id", ""))
		var saved := _find_entry(mid)
		var row := {}
		if not saved.is_empty():
			var items = saved.get("items", {})
			for pid in items:
				row[str(pid)] = int(items[pid])
		_quantities[mid] = row


func _find_entry(market_id: String) -> Dictionary:
	for entry in store.wholesale:
		if str(entry.get("date", "")) == _selected_date and str(entry.get("marketId", "")) == market_id:
			return entry
	return {}


func _row_total(row: Dictionary) -> int:
	return ProductionCalc.calculate_wholesale_total(row, store.products)


func _row_qty(row: Dictionary) -> int:
	var n := 0
	for pid in row:
		n += maxi(0, int(row[pid]))
	return n


func _update_day_totals() -> void:
	var qty := 0
	var total := 0
	for mid in _quantities:
		qty += _row_qty(_quantities[mid])
		total += _row_total(_quantities[mid])
	_day_qty_label.text = str(qty)
	_day_total_label.text = BanhTet.format_money(total)


## ===================================================== DistributionTable
func _rebuild_distribution() -> void:
	if _dist_box == null:
		return
	for c in _dist_box.get_children():
		c.queue_free()
	_market_refs.clear()
	_update_day_totals()

	var markets: Array = []
	for market in store.markets:
		if _selected_market_id == "" or str(market.get("id", "")) == _selected_market_id:
			markets.append(market)

	if markets.is_empty():
		_dist_box.add_child(_empty_block(
			"", "Chưa có mối chợ nào để phân phối",
			"Thêm mối chợ ở cột bên trái trước khi nhập số lượng bánh sỉ.", Color.TRANSPARENT
		))
		return

	for market in markets:
		_dist_box.add_child(_build_market_card(market))


func _build_market_card(market: Dictionary) -> Control:
	var mid := str(market.get("id", ""))
	if not _quantities.has(mid):
		_quantities[mid] = {}
	var row: Dictionary = _quantities[mid]
	var refs := {"line": {}, "edit": {}}
	_market_refs[mid] = refs

	var cs := UiTheme.box_style(BanhTet.WHITE, BanhTet.AMBER_200, 12)
	cs.shadow_color = Color(0, 0, 0, 0.05)
	cs.shadow_size = 2
	cs.shadow_offset = Vector2(0, 1)
	var card := UiTheme.panel(cs)
	card.clip_contents = true
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)

	# --- Header gradient đỏ ---
	var hs := StyleBoxTexture.new()
	hs.texture = _gradient([BanhTet.RED_800, BanhTet.RED_700, BanhTet.AMBER_700])
	_pad(hs, 16, 12)
	var head := UiTheme.panel(hs)
	col.add_child(head)
	col.add_child(_hline(BanhTet.AMBER_300))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 12)
	head.add_child(hv)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	hv.add_child(top)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	top.add_child(info)
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 8)
	nrow.add_child(UiTheme.text("🏪", 18, BanhTet.WHITE))
	var nm := UiTheme.text(str(market.get("name", "")), 14, BanhTet.WHITE, "extrabold")
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nrow.add_child(nm)
	info.add_child(nrow)
	var sub := UiTheme.text("%s · ☎ %s" % [str(market.get("stall", "")), str(market.get("phone", ""))], 11, BanhTet.RED_100)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.clip_text = true
	info.add_child(sub)

	var phone := str(market.get("phone", ""))
	if phone != "":
		var call := Button.new()
		call.icon = UiTheme.icon_texture("phone-call", 20, BanhTet.RED_600)
		call.tooltip_text = "Gọi khách hàng"
		call.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		call.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var cst := UiTheme.box_style(BanhTet.WHITE, BanhTet.GRAY_200, 16, 8, 8)
		call.add_theme_stylebox_override("normal", cst)
		call.add_theme_stylebox_override("hover", UiTheme.box_style(BanhTet.RED_50, BanhTet.GRAY_200, 16, 8, 8))
		call.add_theme_stylebox_override("pressed", UiTheme.box_style(BanhTet.RED_50, BanhTet.GRAY_200, 16, 8, 8))
		call.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		call.pressed.connect(func(): OS.shell_open("tel:%s" % phone))
		top.add_child(call)

	var tools := HFlowContainer.new()
	tools.add_theme_constant_override("h_separation", 8)
	tools.add_theme_constant_override("v_separation", 8)
	hv.add_child(tools)
	var qb := UiTheme.panel(UiTheme.box_style(BanhTet.AMBER_400, BanhTet.AMBER_300, 999, 8, 2))
	qb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var qlbl := UiTheme.text("%d bánh" % _row_qty(row), 11, Color("#451a03"), "extrabold")
	qb.add_child(qlbl)
	tools.add_child(qb)
	refs["qty_badge"] = qlbl
	var mb := UiTheme.panel(UiTheme.box_style(Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.3), 999, 8, 2))
	mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mlbl := UiTheme.text(BanhTet.format_money(_row_total(row)), 11, BanhTet.WHITE, "extrabold")
	mb.add_child(mlbl)
	tools.add_child(mb)
	refs["money_badge"] = mlbl
	tools.add_child(_icon_action("printer", Color("#fde68a"), Color(1, 1, 1, 0.2), "In phiếu giao sỉ", _show_print_preview.bind([mid]), 16, 28))
	tools.add_child(_icon_action("trash-2", BanhTet.RED_200, Color(BanhTet.RED_500, 0.4), "Xoá lịch bỏ bánh của mối chợ này", _on_delete_schedule.bind(mid), 16, 28))
	var save := Button.new()
	save.text = "Lưu"
	save.icon = UiTheme.icon_texture("save", 14, Color("#451a03"))
	save.add_theme_constant_override("h_separation", 6)
	save.add_theme_font_size_override("font_size", 13)
	UiTheme.set_weight(save, "bold")
	save.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	save.add_theme_stylebox_override("normal", UiTheme.box_style(BanhTet.AMBER_400, BanhTet.AMBER_300, 8, 10, 5))
	save.add_theme_stylebox_override("hover", UiTheme.box_style(BanhTet.AMBER_300, BanhTet.AMBER_300, 8, 10, 5))
	save.add_theme_stylebox_override("pressed", UiTheme.box_style(BanhTet.AMBER_300, BanhTet.AMBER_300, 8, 10, 5))
	save.add_theme_stylebox_override("disabled", UiTheme.box_style(Color(BanhTet.AMBER_400, 0.5), Color(BanhTet.AMBER_300, 0.5), 8, 10, 5))
	save.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		save.add_theme_color_override(c, Color("#451a03"))
	save.add_theme_color_override("font_disabled_color", Color(Color("#451a03"), 0.5))
	save.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	save.disabled = _row_qty(row) == 0
	save.pressed.connect(_on_save.bind(mid, save))
	tools.add_child(save)
	refs["save"] = save

	# --- Thân: thẻ sản phẩm (điện thoại) hoặc bảng (sm+) ---
	if _wide:
		col.add_child(_build_table(market, row, refs))
	else:
		col.add_child(_build_product_cards(market, row, refs))
	return card


## sm:hidden - mỗi sản phẩm một thẻ nhỏ
func _build_product_cards(market: Dictionary, row: Dictionary, refs: Dictionary) -> Control:
	var mid := str(market.get("id", ""))
	var m := _margin(12, 12, 12, 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	for product in store.products:
		var pid := str(product.get("id", ""))
		var qty := int(row.get(pid, 0))
		var unit := BanhTet.get_wholesale_price(product)
		var pc := UiTheme.panel(UiTheme.box_style(BanhTet.WHITE, BanhTet.GRAY_200, 8, 12, 12))
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", 8)
		pc.add_child(pv)

		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		pv.add_child(top)
		top.add_child(_product_image(product, 20))
		var nm := UiTheme.text(str(product.get("name", "")), 12, BanhTet.GRAY_800, "semibold")
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if str(product.get("code", "")) != "":
			nm.text += "  "
		top.add_child(nm)
		if str(product.get("code", "")) != "":
			var code := UiTheme.text(str(product.get("code", "")), 10, BanhTet.AMBER_700)
			code.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			top.add_child(code)
		var price := UiTheme.text(BanhTet.format_money(unit), 12, BanhTet.RED_700, "semibold")
		price.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top.add_child(price)

		pv.add_child(_hline(BanhTet.GRAY_100))
		var bottom := HBoxContainer.new()
		bottom.add_theme_constant_override("separation", 8)
		pv.add_child(bottom)
		bottom.add_child(_qty_stepper(mid, pid, qty, 36, refs))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom.add_child(sp)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		var tc := UiTheme.text("Thành tiền", 10, BanhTet.GRAY_500)
		tc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tv.add_child(tc)
		var line_total := UiTheme.text(BanhTet.format_money(unit * qty), 12, BanhTet.GRAY_900, "bold")
		line_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tv.add_child(line_total)
		bottom.add_child(tv)
		refs["line"][pid] = line_total
		v.add_child(pc)
	return m


## hidden sm:block - bảng shadcn (Table) trong khung cuộn ngang
const COL_PRICE := 120
const COL_QTY := 150
const COL_TOTAL := 130


func _build_table(market: Dictionary, row: Dictionary, refs: Dictionary) -> Control:
	var mid := str(market.get("id", ""))
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var table := VBoxContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("separation", 0)
	scroll.add_child(table)

	# Header
	var hrow := _table_row(Color(BanhTet.AMBER_50, 0.6), 40)
	table.add_child(hrow)
	_table_cells(hrow, [
		UiTheme.text("Loại Bánh", 14, BanhTet.GRAY_900, "medium"),
		_aligned(UiTheme.text("Giá Sỉ", 14, BanhTet.GRAY_900, "medium"), HORIZONTAL_ALIGNMENT_CENTER),
		_aligned(UiTheme.text("Số Lượng", 14, BanhTet.GRAY_900, "medium"), HORIZONTAL_ALIGNMENT_CENTER),
		_aligned(UiTheme.text("Thành Tiền", 14, BanhTet.GRAY_900, "medium"), HORIZONTAL_ALIGNMENT_RIGHT),
	])
	table.add_child(_hline(BanhTet.GRAY_200))

	for product in store.products:
		var pid := str(product.get("id", ""))
		var qty := int(row.get(pid, 0))
		var unit := BanhTet.get_wholesale_price(product)
		var r := _table_row(Color(1, 1, 1, 0), 0)
		_hoverable(r, Color(BanhTet.GRAY_50, 0.6))
		table.add_child(r)

		var name_cell := HBoxContainer.new()
		name_cell.add_theme_constant_override("separation", 8)
		name_cell.add_child(_product_image(product, 20))
		var nm := UiTheme.text(str(product.get("name", "")), 14, BanhTet.GRAY_800, "medium")
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_cell.add_child(nm)
		var code := str(product.get("code", ""))
		if code != "":
			var cb := UiTheme.panel(UiTheme.box_style(BanhTet.AMBER_50, BanhTet.AMBER_300, 999, 8, 1))
			cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cb.add_child(UiTheme.text(code, 10, BanhTet.AMBER_800, "bold"))
			name_cell.add_child(cb)

		var line_total := _aligned(UiTheme.text(BanhTet.format_money(unit * qty), 14, BanhTet.GRAY_900, "bold"), HORIZONTAL_ALIGNMENT_RIGHT)
		refs["line"][pid] = line_total
		var stepper := _qty_stepper(mid, pid, qty, 28, refs)
		stepper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_table_cells(r, [
			name_cell,
			_aligned(UiTheme.text(BanhTet.format_money(unit), 14, BanhTet.RED_700, "semibold"), HORIZONTAL_ALIGNMENT_CENTER),
			stepper,
			line_total,
		])
		table.add_child(_hline(BanhTet.GRAY_200))

	# tfoot
	var frow := _table_row(BanhTet.AMBER_50, 0)
	table.add_child(frow)
	var cap := UiTheme.text("TỔNG TIỀN PHẢI THU", 14, BanhTet.GRAY_700, "extrabold")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var foot_total := UiTheme.text(BanhTet.format_money(_row_total(row)), 16, BanhTet.RED_800, "extrabold")
	foot_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot_total.custom_minimum_size.x = COL_TOTAL
	var fh := frow.get_child(0) as HBoxContainer
	fh.add_child(cap)
	fh.add_child(foot_total)
	refs["footer"] = foot_total
	return scroll


func _table_row(bg: Color, min_h: int) -> PanelContainer:
	var p := UiTheme.panel(UiTheme.box_style(bg, Color.TRANSPARENT, 0, 8, 8))
	p.custom_minimum_size.y = min_h
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	return p


func _table_cells(row: PanelContainer, cells: Array) -> void:
	var h := row.get_child(0) as HBoxContainer
	var widths := [0, COL_PRICE, COL_QTY, COL_TOTAL]
	for i in cells.size():
		var c: Control = cells[i]
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if i == 0:
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c.custom_minimum_size.x = 220
			h.add_child(c)
		else:
			var holder: Container = CenterContainer.new() if i == 2 else MarginContainer.new()
			holder.custom_minimum_size.x = widths[i]
			holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL if i != 2 else Control.SIZE_SHRINK_CENTER
			holder.add_child(c)
			h.add_child(holder)


func _aligned(lbl: Label, align: HorizontalAlignment) -> Label:
	lbl.horizontal_alignment = align
	return lbl


func _hoverable(p: PanelContainer, hover_bg: Color) -> void:
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var st := p.get_theme_stylebox("panel") as StyleBoxFlat
	var normal := st.bg_color
	p.mouse_entered.connect(func(): st.bg_color = hover_bg)
	p.mouse_exited.connect(func(): st.bg_color = normal)


## Bộ tăng/giảm: [-] [input w-16] [+]
func _qty_stepper(mid: String, pid: String, qty: int, h: int, refs: Dictionary) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6 if h <= 28 else 8)

	var minus := _step_button("minus", BanhTet.GRAY_100, BanhTet.GRAY_200, BanhTet.GRAY_900, h)
	box.add_child(minus)

	var edit := LineEdit.new()
	edit.placeholder_text = "0"
	edit.text = str(qty) if qty > 0 else ""
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(64, h)
	edit.select_all_on_focus = true
	edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	UiTheme.set_weight(edit, "bold")
	var ns := UiTheme.web_input_style(false, 8, 2)
	var fs := UiTheme.web_input_style(true, 8, 2)
	edit.add_theme_stylebox_override("normal", ns)
	edit.add_theme_stylebox_override("focus", fs)
	edit.text_changed.connect(func(t: String):
		var v := maxi(0, t.to_int()) if t.strip_edges() != "" else 0
		_set_qty(mid, pid, v, false))
	box.add_child(edit)
	refs["edit"][pid] = edit

	var plus := _step_button("plus", BanhTet.AMBER_100, Color("#fde68a"), BanhTet.AMBER_900, h)
	box.add_child(plus)

	minus.pressed.connect(func(): _set_qty(mid, pid, maxi(0, int(_quantities[mid].get(pid, 0)) - 1), true))
	plus.pressed.connect(func(): _set_qty(mid, pid, int(_quantities[mid].get(pid, 0)) + 1, true))
	return box


func _step_button(icon_name: String, bg: Color, bg_hover: Color, fg: Color, h: int) -> Button:
	var b := Button.new()
	b.icon = UiTheme.icon_texture(icon_name, 12, fg)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(h, h)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", UiTheme.box_style(bg, Color.TRANSPARENT, 8))
	b.add_theme_stylebox_override("hover", UiTheme.box_style(bg_hover, Color.TRANSPARENT, 8))
	b.add_theme_stylebox_override("pressed", UiTheme.box_style(bg_hover, Color.TRANSPARENT, 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## Cập nhật số lượng tại chỗ (không dựng lại bảng để giữ focus ô đang gõ)
func _set_qty(mid: String, pid: String, value: int, update_edit: bool) -> void:
	var row: Dictionary = _quantities.get(mid, {})
	row[pid] = value
	_quantities[mid] = row
	var refs: Dictionary = _market_refs.get(mid, {})
	if refs.is_empty():
		return
	if update_edit and refs["edit"].has(pid):
		(refs["edit"][pid] as LineEdit).text = str(value) if value > 0 else ""
	var product := store.find_product(pid)
	if refs["line"].has(pid):
		(refs["line"][pid] as Label).text = BanhTet.format_money(BanhTet.get_wholesale_price(product) * value)
	var total := _row_total(row)
	var qty := _row_qty(row)
	(refs["qty_badge"] as Label).text = "%d bánh" % qty
	(refs["money_badge"] as Label).text = BanhTet.format_money(total)
	(refs["save"] as Button).disabled = qty == 0
	if refs.has("footer"):
		(refs["footer"] as Label).text = BanhTet.format_money(total)
	_update_day_totals()


## ======================================================== Lưu / Xoá lịch
func _on_save(mid: String, btn: Button) -> void:
	var items := {}
	var row: Dictionary = _quantities.get(mid, {})
	for pid in row:
		if int(row[pid]) > 0:
			items[pid] = int(row[pid])
	if items.is_empty():
		_toast("Chưa nhập số lượng bánh cho mối chợ này!", "warning")
		return
	var existing := _find_entry(mid)
	var payload := {
		"marketId": mid,
		"date": _selected_date,
		"items": items,
		"totalAmount": _row_total(items),
		"notes": str(existing.get("notes", "")),
	}
	if not existing.is_empty():
		payload["id"] = str(existing.get("id", ""))
	btn.disabled = true
	var ok := await store.save_wholesale(payload)
	if is_instance_valid(btn):
		btn.disabled = false
	if ok:
		_toast("Đã cập nhật lịch bỏ bánh!" if not existing.is_empty() else "Đã lưu lịch bỏ bánh sỉ!", "success")
	else:
		_toast("Không lưu được. Kiểm tra kết nối / quyền quản trị.", "error")


func _on_delete_schedule(mid: String) -> void:
	var existing := _find_entry(mid)
	if existing.is_empty():
		_quantities[mid] = {}
		_rebuild_distribution()
		return
	var ok := await store.delete_wholesale(str(existing.get("id", "")))
	if ok:
		_toast("Đã xoá lịch bỏ bánh của mối chợ này", "warning")
		_quantities[mid] = {}
		_rebuild_distribution()
	else:
		_toast("Không xoá được lịch bỏ bánh", "error")


## ================================================================ In phiếu
func _on_print_all() -> void:
	var ids: Array = []
	for market in store.markets:
		var mid := str(market.get("id", ""))
		if _row_qty(_quantities.get(mid, {})) > 0:
			ids.append(mid)
	if ids.is_empty():
		_toast("Chưa có số lượng nào để in!", "warning")
		return
	_show_print_preview(ids)


## Xem trước phiếu giao sỉ (WholesaleReceipt) trong lớp phủ giống web
func _show_print_preview(market_ids: Array) -> void:
	var w := get_viewport_rect().size.x
	var overlay := _overlay(Color(0, 0, 0, 0.2))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(scroll)
	var pad := _margin(24 if w >= UiTheme.BP_SM else 12, 24 if w >= UiTheme.BP_SM else 12, 24 if w >= UiTheme.BP_SM else 12, 24 if w >= UiTheme.BP_SM else 12)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(center)

	var ps := UiTheme.box_style(BanhTet.WHITE, Color.TRANSPARENT, 16, 24 if w >= UiTheme.BP_SM else 12, 24 if w >= UiTheme.BP_SM else 12)
	ps.shadow_color = Color(0, 0, 0, 0.25)
	ps.shadow_size = 24
	ps.shadow_offset = Vector2(0, 8)
	var sheet := UiTheme.panel(ps)
	sheet.custom_minimum_size.x = minf(768, w - (48 if w >= UiTheme.BP_SM else 24))
	center.add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	sheet.add_child(v)

	for mid in market_ids:
		var market := _market_by_id(str(mid))
		if not market.is_empty():
			v.add_child(_build_receipt(market, _quantities.get(str(mid), {}), w >= UiTheme.BP_SM))

	v.add_child(_hline(BanhTet.GRAY_200))
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	v.add_child(actions)
	var close := UiTheme.tw_button("Đóng", "x", "outline-amber", 14, BanhTet.GRAY_800)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		close.add_theme_color_override(c, BanhTet.GRAY_900)
	close.add_theme_stylebox_override("normal", UiTheme.box_style(BanhTet.WHITE, BanhTet.GRAY_200, 8, 14, 7))
	close.add_theme_stylebox_override("hover", UiTheme.box_style(BanhTet.GRAY_100, BanhTet.GRAY_200, 8, 14, 7))
	close.pressed.connect(overlay.queue_free)
	actions.add_child(close)
	var label := "In phiếu 1/%d" % market_ids.size() if market_ids.size() > 1 else "In Ngay"
	var print_btn := _solid_button(label, "printer", BanhTet.WHITE, 14)
	print_btn.pressed.connect(func(): _toast("Bản Godot chưa hỗ trợ in tem sỉ qua Label Expert", "warning"))
	actions.add_child(print_btn)


func _build_receipt(market: Dictionary, quantities: Dictionary, wide: bool) -> Control:
	var rs := UiTheme.box_style(BanhTet.WHITE, BanhTet.RED_700, 0, 24 if wide else 12, 24 if wide else 12, 2)
	var r := UiTheme.panel(rs)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	r.add_child(v)

	var t := UiTheme.text("🏪 PHIẾU GIAO BÁNH SỈ — MỐI CHỢ", 20 if wide else 18, BanhTet.RED_700, "extrabold")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var st := UiTheme.text("Bánh Chưng - Bánh Tét Gia Truyền Chuẩn Vị Tết Việt 2027", 12, BanhTet.GRAY_600)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(st)
	v.add_child(_hline(BanhTet.GRAY_400))

	var info := GridContainer.new()
	info.columns = 2 if wide else 1
	info.add_theme_constant_override("h_separation", 12)
	info.add_theme_constant_override("v_separation", 8)
	v.add_child(info)
	for pair in [
		["Mối chợ / Tiểu thương:", str(market.get("name", "")), BanhTet.GRAY_900],
		["Sạp chợ:", str(market.get("stall", "")), BanhTet.GRAY_900],
		["Số điện thoại:", str(market.get("phone", "")), BanhTet.GRAY_900],
		["Ngày giao bánh:", BanhTet.format_date_display(_selected_date), BanhTet.RED_700],
	]:
		var c := VBoxContainer.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_constant_override("separation", 0)
		c.add_child(UiTheme.text(pair[0], 12, BanhTet.GRAY_500))
		c.add_child(UiTheme.text(pair[1], 14, pair[2], "bold"))
		info.add_child(c)
	v.add_child(_hline(BanhTet.GRAY_300))

	for product in store.products:
		var pid := str(product.get("id", ""))
		var qty := int(quantities.get(pid, 0))
		if qty <= 0:
			continue
		var unit := BanhTet.get_wholesale_price(product)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var nm := UiTheme.text(str(product.get("name", "")), 14, BanhTet.GRAY_900, "medium")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(_product_image(product, 20))
		row.add_child(nm)
		row.add_child(UiTheme.text("× %d" % qty, 14, BanhTet.RED_700, "bold"))
		var lt := UiTheme.text(BanhTet.format_money(unit * qty), 14, BanhTet.GRAY_900, "bold")
		lt.custom_minimum_size.x = 110
		lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(lt)
		v.add_child(row)

	var tb := UiTheme.panel(UiTheme.box_style(BanhTet.AMBER_50, BanhTet.AMBER_300, 8, 12, 12))
	var th := HBoxContainer.new()
	th.alignment = BoxContainer.ALIGNMENT_END
	tb.add_child(th)
	var tc := UiTheme.text("TỔNG TIỀN: ", 14, BanhTet.GRAY_700)
	tc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(tc)
	th.add_child(UiTheme.text(BanhTet.format_money(_row_total(quantities)), 20, BanhTet.RED_800, "extrabold"))
	v.add_child(tb)
	return r


func _market_by_id(id: String) -> Dictionary:
	for market in store.markets:
		if str(market.get("id", "")) == id:
			return market
	return {}


## ======================================== Dialog thêm / sửa mối chợ
func _show_market_form(market: Dictionary) -> void:
	var editing := not market.is_empty()
	var w := get_viewport_rect().size.x
	var overlay := _overlay(Color(0, 0, 0, 0.5))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var ds := UiTheme.box_style(BanhTet.WHITE, BanhTet.RED_200, 16)
	ds.shadow_color = Color(0, 0, 0, 0.2)
	ds.shadow_size = 20
	ds.shadow_offset = Vector2(0, 8)
	var dialog := UiTheme.panel(ds)
	dialog.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	dialog.custom_minimum_size.x = minf(512 if w >= UiTheme.BP_SM else 448, w - 24)
	center.add_child(dialog)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	dialog.add_child(col)

	# Header đỏ
	var hs := StyleBoxTexture.new()
	hs.texture = _gradient([BanhTet.RED_700, BanhTet.RED_800])
	_pad(hs, 20, 16)
	var head := UiTheme.panel(hs)
	col.add_child(head)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	head.add_child(hr)
	hr.add_child(UiTheme.icon("plus", 20, Color("#fcd34d")))
	var ht := UiTheme.text("Sửa Thông Tin Mối Chợ" if editing else "Thêm Mối Chợ Mới", 18 if w >= UiTheme.BP_SM else 16, BanhTet.WHITE, "bold")
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(ht)
	var x := _icon_action("x", Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.15), "Đóng", overlay.queue_free, 16, 28)
	hr.add_child(x)

	# Form
	var fm := _margin(20, 20, 20, 20)
	col.add_child(fm)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 16)
	fm.add_child(form)
	var name_edit := _form_field(form, "Tên Tiểu Thương", true, LineEdit.new(), "VD: Chị Hương")
	var stall_edit := _form_field(form, "Sạp Chợ", true, LineEdit.new(), "VD: Sạp 12 - Chợ Bến Thành")
	var phone_edit := _form_field(form, "Số Điện Thoại", true, LineEdit.new(), "0901234567")
	(phone_edit as LineEdit).virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PHONE
	var notes := TextEdit.new()
	notes.custom_minimum_size.y = 64
	var notes_edit := _form_field(form, "Ghi Chú", false, notes, "VD: Lấy xe tải lúc 5h sáng, cần bánh đồng đều...")
	if editing:
		(name_edit as LineEdit).text = str(market.get("name", ""))
		(stall_edit as LineEdit).text = str(market.get("stall", ""))
		(phone_edit as LineEdit).text = str(market.get("phone", ""))
		(notes_edit as TextEdit).text = str(market.get("notes", ""))

	# Footer xám
	col.add_child(_hline(BanhTet.GRAY_100))
	var fs := UiTheme.box_style(BanhTet.GRAY_50, Color.TRANSPARENT, 0, 20, 16)
	var foot := UiTheme.panel(fs)
	col.add_child(foot)
	var fr := HBoxContainer.new()
	fr.alignment = BoxContainer.ALIGNMENT_END
	fr.add_theme_constant_override("separation", 8)
	foot.add_child(fr)
	var cancel := Button.new()
	cancel.text = "Hủy Bỏ"
	UiTheme.set_weight(cancel, "medium")
	cancel.add_theme_font_size_override("font_size", 14)
	cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel.add_theme_stylebox_override("normal", UiTheme.box_style(BanhTet.GRAY_100, Color.TRANSPARENT, 8, 14, 7))
	cancel.add_theme_stylebox_override("hover", UiTheme.box_style(BanhTet.GRAY_200, Color.TRANSPARENT, 8, 14, 7))
	cancel.add_theme_stylebox_override("pressed", UiTheme.box_style(BanhTet.GRAY_200, Color.TRANSPARENT, 8, 14, 7))
	cancel.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		cancel.add_theme_color_override(c, BanhTet.GRAY_900)
	cancel.pressed.connect(overlay.queue_free)
	fr.add_child(cancel)
	var submit := _solid_button("Lưu Thay Đổi" if editing else "Thêm Mối Chợ", "", BanhTet.WHITE, 14)
	fr.add_child(submit)

	submit.pressed.connect(func():
		var errors := false
		for pair in [[name_edit, 2, "Vui lòng nhập tên tiểu thương"], [stall_edit, 2, "Vui lòng nhập sạp chợ"], [phone_edit, 9, "Số điện thoại không hợp lệ"]]:
			var le := pair[0] as LineEdit
			var err := le.get_meta("error_label") as Label
			var bad := le.text.strip_edges().length() < int(pair[1])
			err.text = str(pair[2]) if bad else ""
			err.visible = bad
			errors = errors or bad
		if errors:
			return
		var payload := {
			"name": (name_edit as LineEdit).text.strip_edges(),
			"stall": (stall_edit as LineEdit).text.strip_edges(),
			"phone": (phone_edit as LineEdit).text.strip_edges(),
			"notes": (notes_edit as TextEdit).text.strip_edges(),
		}
		if editing:
			payload["id"] = str(market.get("id", ""))
		submit.disabled = true
		var ok := await store.save_market(payload)
		if ok:
			_toast(("Đã cập nhật mối chợ \"%s\"" if editing else "Đã thêm mối chợ \"%s\"") % payload["name"], "success")
			overlay.queue_free()
			_reload()
		else:
			submit.disabled = false
			_toast("Không lưu được mối chợ. Kiểm tra kết nối / quyền quản trị.", "error"))
	(name_edit as LineEdit).grab_focus.call_deferred()


func _form_field(parent: VBoxContainer, label: String, required: bool, input: Control, placeholder: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	parent.add_child(v)
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_font_override("normal_font", UiTheme.font("semibold"))
	l.add_theme_font_size_override("normal_font_size", 12)
	l.add_theme_color_override("default_color", BanhTet.GRAY_900)
	l.text = label + (" [color=#ef4444]*[/color]" if required else "")
	v.add_child(l)
	if input is LineEdit:
		(input as LineEdit).placeholder_text = placeholder
	elif input is TextEdit:
		(input as TextEdit).placeholder_text = placeholder
	v.add_child(input)
	var err := UiTheme.text("", 12, BanhTet.RED_600)
	err.visible = false
	v.add_child(err)
	input.set_meta("error_label", err)
	return input


## ================================================================ Helpers
## Lớp phủ toàn màn hình (fixed inset-0) - trên cùng
## Gắn thẳng vào cửa sổ gốc (không qua CanvasLayer) để vẫn nhận theme chung của ô nhập
func _overlay(dim: Color) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().root.add_child(root)
	var bg := ColorRect.new()
	bg.color = dim
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	# Đóng lớp phủ khi rời màn hình Mối Chợ
	tree_exiting.connect(func():
		if is_instance_valid(root):
			root.queue_free())
	return root


## Toast nhỏ ở đáy màn hình giống sonner
func _toast(message: String, kind: String = "success") -> void:
	var fg := BanhTet.GREEN_700
	var icon := "✅"
	match kind:
		"warning":
			fg = BanhTet.AMBER_800
			icon = "⚠️"
		"error":
			fg = BanhTet.RED_700
			icon = "❌"
	var ts := UiTheme.box_style(BanhTet.WHITE, BanhTet.GRAY_200, 8, 16, 12)
	ts.shadow_color = Color(0, 0, 0, 0.12)
	ts.shadow_size = 10
	ts.shadow_offset = Vector2(0, 4)
	var p := UiTheme.panel(ts)
	var l := UiTheme.text("%s  %s" % [icon, message], 13, fg, "medium")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var vw := get_viewport_rect().size
	l.custom_minimum_size.x = minf(340, vw.x - 64)
	p.add_child(l)
	p.top_level = true
	get_tree().root.add_child(p)
	await get_tree().process_frame
	p.position = Vector2((vw.x - p.size.x) / 2.0, vw.y - p.size.y - (90 if vw.x < UiTheme.BP_SM else 24))
	var tw := p.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


func _section_card() -> PanelContainer:
	var st := UiTheme.box_style(BanhTet.WHITE, BanhTet.GRAY_200, 16)
	st.shadow_color = Color(0, 0, 0, 0.05)
	st.shadow_size = 2
	st.shadow_offset = Vector2(0, 1)
	var card := UiTheme.panel(st)
	card.clip_contents = true
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)
	return card


## Nút đỏ đặc (bg-red-700 font-bold text-white) size sm
func _solid_button(label: String, icon_name: String, icon_color: Color, font_size: int = 13) -> Button:
	var b := Button.new()
	b.text = label
	b.add_theme_font_size_override("font_size", font_size)
	UiTheme.set_weight(b, "bold")
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var pad_y := 5 if font_size <= 13 else 7
	b.add_theme_stylebox_override("normal", UiTheme.box_style(BanhTet.RED_700, Color.TRANSPARENT, 8, 10, pad_y))
	b.add_theme_stylebox_override("hover", UiTheme.box_style(BanhTet.RED_800, Color.TRANSPARENT, 8, 10, pad_y))
	b.add_theme_stylebox_override("pressed", UiTheme.box_style(BanhTet.RED_800, Color.TRANSPARENT, 8, 10, pad_y))
	b.add_theme_stylebox_override("disabled", UiTheme.box_style(Color(BanhTet.RED_700, 0.5), Color.TRANSPARENT, 8, 10, pad_y))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, BanhTet.WHITE)
	if icon_name != "":
		b.icon = UiTheme.icon_texture(icon_name, 14, icon_color)
		b.add_theme_constant_override("h_separation", 6)
	return b


func _icon_action(icon_name: String, fg: Color, hover_bg: Color, tip: String, cb: Callable, px: int = 14, size_px: int = 28) -> Button:
	var b := Button.new()
	b.icon = UiTheme.icon_texture(icon_name, px, fg)
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(size_px, size_px)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", UiTheme.box_style(Color.TRANSPARENT, Color.TRANSPARENT, 8))
	b.add_theme_stylebox_override("hover", UiTheme.box_style(hover_bg, Color.TRANSPARENT, 8))
	b.add_theme_stylebox_override("pressed", UiTheme.box_style(hover_bg, Color.TRANSPARENT, 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b


func _empty_block(emoji: String, title: String, desc: String, circle_bg: Color) -> Control:
	var m := _margin(48, 16, 16, 48)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	m.add_child(v)
	if emoji != "":
		var circle := UiTheme.panel(UiTheme.box_style(circle_bg, Color.TRANSPARENT, 32))
		circle.custom_minimum_size = Vector2(64, 64)
		circle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var e := UiTheme.text(emoji, 28, BanhTet.GRAY_900)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		circle.add_child(e)
		v.add_child(circle)
		var gap := Control.new()
		gap.custom_minimum_size.y = 8
		v.add_child(gap)
	var t := UiTheme.text(title, 14, BanhTet.GRAY_700, "bold")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var d := UiTheme.text(desc, 12, BanhTet.GRAY_500)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	return m


func _product_image(product: Dictionary, px: int) -> TextureRect:
	var r := TextureRect.new()
	var file := str(product.get("icon", "")).get_file()
	var path := "res://assets/anh/%s" % file
	if file != "" and ResourceLoader.exists(path):
		r.texture = load(path)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _hline(c: Color) -> Control:
	var r := ColorRect.new()
	r.color = c
	r.custom_minimum_size.y = 1
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _margin(top: int, left: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	return m


func _pad(st: StyleBox, x: float, y: float) -> void:
	st.content_margin_left = x
	st.content_margin_right = x
	st.content_margin_top = y
	st.content_margin_bottom = y


func _gradient(colors: Array) -> GradientTexture2D:
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
	tex.width = 256
	tex.height = 4
	return tex
