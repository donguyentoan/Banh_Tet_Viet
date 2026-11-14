extends VBoxContainer

## Màn hình Đơn Hàng & Thống Kê - port 1:1 từ orders-page.tsx:
##   DashboardStats (4 thẻ) -> QuickParseBox (Tạo Đơn Nhanh) ->
##   Card "Danh Sách Đơn Hàng" (header + toolbar lọc + lưới đơn + footer)

## Phát ra khi cần mở màn Tạo Đơn: kind = "parse" (data = text) | "edit" (data = order)
signal open_create(kind: String, data: Variant)

var store: BakeryStore
var printer: Node

var _stats_grid: GridContainer
var _search_edit: LineEdit
var _status_filter: OptionButton
var _cake_filter: OptionButton
var _date_filter: OptionButton
var _sort_filter: OptionButton
var _toolbar_box: BoxContainer
var _toolbar_filters: GridContainer
var _order_grid: GridContainer
var _empty_box: Control
var _count_badge: Label
var _footer_count: Label
var _quick_input: TextEdit
var _quick_hint: Control
var _hint_btn: Button
var _parse_btn: Button
var _fb_status: Label


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 24)

	_stats_grid = GridContainer.new()
	_stats_grid.add_theme_constant_override("h_separation", 12)
	_stats_grid.add_theme_constant_override("v_separation", 12)
	add_child(_stats_grid)

	add_child(_build_quick_parse())
	add_child(_build_list_card())

	store.orders_changed.connect(_refresh)
	store.products_changed.connect(_refresh)
	get_viewport().size_changed.connect(_apply_responsive)
	_apply_responsive()
	_refresh()


## Số cột theo breakpoint giống Tailwind
func _apply_responsive() -> void:
	var w := get_viewport_rect().size.x
	# grid-cols-1 sm:grid-cols-2 lg:grid-cols-4
	_stats_grid.columns = 4 if w >= UiTheme.BP_LG else (2 if w >= UiTheme.BP_SM else 1)
	# grid-cols-1 md:grid-cols-2 lg:grid-cols-3
	_order_grid.columns = 3 if w >= UiTheme.BP_LG else (2 if w >= UiTheme.BP_MD else 1)
	# Toolbar: md:flex-row, dưới md xếp dọc; bộ lọc 2 cột trên điện thoại
	_toolbar_box.vertical = w < UiTheme.BP_MD
	_search_edit.custom_minimum_size.x = 320 if w >= UiTheme.BP_MD else 0
	_toolbar_filters.columns = 6 if w >= UiTheme.BP_SM else 2
	# sm:w-[170px]... ; điện thoại: w-full chia đôi
	var wide := w >= UiTheme.BP_SM
	_status_filter.custom_minimum_size.x = 170 if wide else 0
	_cake_filter.custom_minimum_size.x = 160 if wide else 0
	_date_filter.custom_minimum_size.x = 160 if wide else 0
	_sort_filter.custom_minimum_size.x = 170 if wide else 0
	_status_filter.clip_text = not wide
	_cake_filter.clip_text = not wide
	_date_filter.clip_text = not wide
	_sort_filter.clip_text = not wide


## ================================================================ Thống kê
func _refresh_stats() -> void:
	for child in _stats_grid.get_children():
		child.queue_free()

	var stats := store.dashboard_stats()

	_stats_grid.add_child(_stat_card(
		"TỔNG ĐƠN HÀNG", str(stats["totalOrders"]), "receipt",
		BanhTet.RED_600, BanhTet.RED_100, BanhTet.RED_100,
		[["Xong: ", BanhTet.GRAY_500, "regular"], [str(int(stats["completedOrders"])), BanhTet.GREEN_700, "bold"],
		 ["  |  ", BanhTet.GRAY_300, "regular"],
		 ["Nấu/gói: ", Color("#ea580c"), "medium"], [str(int(stats["cookingCount"])), Color("#ea580c"), "bold"]]
	))
	_stats_grid.add_child(_stat_card(
		"TỔNG SỐ BÁNH", str(stats["totalCakes"]), "leaf",
		BanhTet.GREEN_700, Color("#d1fae5"), Color("#d1fae5"),
		[["Chưng: ", BanhTet.GRAY_500, "regular"], [str(int(stats.get("chungCount", 0))), BanhTet.GREEN_800, "bold"],
		 ["  |  ", BanhTet.GRAY_300, "regular"],
		 ["Tét: ", BanhTet.GRAY_500, "regular"], [str(int(stats.get("tetCount", 0))), BanhTet.GREEN_800, "bold"]]
	))
	_stats_grid.add_child(_stat_card(
		"TỔNG DOANH THU", BanhTet.format_money(int(stats["totalRevenue"])), "coins",
		BanhTet.AMBER_600, BanhTet.AMBER_100, BanhTet.AMBER_100,
		[["Đã cọc: ", BanhTet.GRAY_500, "regular"],
		 [BanhTet.format_money(int(stats["totalDeposit"])), BanhTet.AMBER_700, "bold"]]
	))
	_stats_grid.add_child(_stat_card(
		"THÔNG BÁO FACEBOOK", "", "coins",
		BanhTet.AMBER_600, BanhTet.AMBER_100, BanhTet.AMBER_100, [], _build_fb_box()
	))


## StatCard (dashboard-stats.tsx): tiêu đề nhỏ uppercase, số lớn extrabold,
## icon vuông bo góc bên phải, icon lớn mờ 10% ở góc dưới phải.
func _stat_card(
	title: String, value: String, icon_name: String, accent: Color,
	icon_bg: Color, border: Color, sub_parts: Array, extra: Control = null
) -> Control:
	var style := UiTheme.box_style(BanhTet.WHITE, border, 12, 16, 16)
	style.shadow_color = Color(0, 0, 0, 0.05)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	var card := UiTheme.panel(style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true

	# Icon watermark (absolute -bottom-4 -right-4 opacity-10)
	var wm_layer := Control.new()
	wm_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(wm_layer)
	var wm := UiTheme.icon(icon_name, 64, accent)
	wm.modulate.a = 0.1
	wm.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	wm.offset_left = -48
	wm.offset_top = -48
	wm.offset_right = 16
	wm.offset_bottom = 16
	wm_layer.add_child(wm)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)

	text_box.add_child(UiTheme.text(title, 11, BanhTet.GRAY_500, "bold"))
	if value != "":
		text_box.add_child(UiTheme.text(value, 21, BanhTet.GRAY_900, "extrabold"))
	if not sub_parts.is_empty():
		var sub := HBoxContainer.new()
		sub.add_theme_constant_override("separation", 0)
		for part in sub_parts:
			sub.add_child(UiTheme.text(str(part[0]), 11, part[1], str(part[2])))
		text_box.add_child(sub)
	if extra != null:
		text_box.add_child(extra)

	var icon_box := UiTheme.panel(UiTheme.box_style(icon_bg, Color.TRANSPARENT, 8, 10, 10))
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.add_child(UiTheme.icon(icon_name, 20, accent))
	row.add_child(icon_box)
	return card


## Khối "Báo cáo đơn hôm nay" (routes/notification.tsx)
func _build_fb_box() -> Control:
	var box := UiTheme.panel(UiTheme.box_style(Color(BanhTet.AMBER_50, 0.6), BanhTet.AMBER_200, 12, 16, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	v.add_child(UiTheme.text("Báo cáo đơn hôm nay (%d đơn)" % store.orders.size(), 14, BanhTet.GRAY_800, "bold"))
	var btn := UiTheme.tw_button("🚀 Gửi thông báo", "", "primary", 14)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.pressed.connect(_on_fb_pressed)
	v.add_child(btn)
	_fb_status = UiTheme.text("", 12, BanhTet.RED_700, "medium")
	_fb_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fb_status.visible = false
	v.add_child(_fb_status)
	return box


## Web gửi báo cáo qua Facebook Graph API bằng Page Token nhúng trong frontend.
## Không chép token vào app (lộ token) -> cần endpoint server (vd /api/notify).
func _on_fb_pressed() -> void:
	_fb_status.visible = true
	_fb_status.text = "❌ Bản Godot chưa hỗ trợ gửi Facebook (cần API server /api/notify)."


## ======================================================== Tạo Đơn Nhanh
## quick-parse-box.tsx: header đỏ gradient + hướng dẫn + textarea + nút
func _build_quick_parse() -> Control:
	var outer_style := UiTheme.box_style(BanhTet.WHITE, BanhTet.AMBER_300, 16)
	outer_style.shadow_color = Color(0, 0, 0, 0.05)
	outer_style.shadow_size = 2
	outer_style.shadow_offset = Vector2(0, 1)
	var outer := UiTheme.panel(outer_style)
	outer.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	outer.add_child(col)

	# --- Header đỏ ---
	var head_style := StyleBoxTexture.new()
	head_style.texture = _gradient([BanhTet.RED_700, BanhTet.RED_800])
	head_style.content_margin_left = 20
	head_style.content_margin_right = 20
	head_style.content_margin_top = 12
	head_style.content_margin_bottom = 12
	var head := UiTheme.panel(head_style)
	col.add_child(head)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 10)
	head.add_child(head_row)
	head_row.add_child(UiTheme.icon("message-square-text", 20, Color("#fcd34d")))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	head_row.add_child(titles)
	titles.add_child(UiTheme.text("Tạo Đơn Nhanh", 14, BanhTet.WHITE, "extrabold"))
	var qsub := UiTheme.text("Tự động tách tên khách, ngày giao & số lượng bánh", 11, BanhTet.RED_100)
	qsub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(qsub)

	_hint_btn = Button.new()
	_hint_btn.text = "Hướng dẫn cú pháp"
	_hint_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hint_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hint_btn.add_theme_font_size_override("font_size", 11)
	UiTheme.set_weight(_hint_btn, "bold")
	_hint_btn.add_theme_stylebox_override("normal", UiTheme.box_style(Color.TRANSPARENT, Color(1, 1, 1, 0.4), 999, 12, 4))
	_hint_btn.add_theme_stylebox_override("hover", UiTheme.box_style(Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.4), 999, 12, 4))
	_hint_btn.add_theme_stylebox_override("pressed", UiTheme.box_style(Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.4), 999, 12, 4))
	_hint_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_hint_btn.add_theme_color_override(c, Color("#fde68a"))
	_hint_btn.pressed.connect(_toggle_hint)
	head_row.add_child(_hint_btn)

	# --- Hướng dẫn (ẩn mặc định) ---
	_quick_hint = _build_hint()
	_quick_hint.visible = false
	col.add_child(_quick_hint)

	# --- Thân: nền amber-50 nhạt ---
	var body_style := StyleBoxTexture.new()
	body_style.texture = _gradient([BanhTet.AMBER_50, BanhTet.WHITE, Color(BanhTet.RED_50, 0.4).blend(Color(1, 1, 1, 0.6))])
	body_style.content_margin_left = 20
	body_style.content_margin_right = 20
	body_style.content_margin_top = 20
	body_style.content_margin_bottom = 20
	var body := UiTheme.panel(body_style)
	col.add_child(body)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	body.add_child(v)

	var mic_row := HFlowContainer.new()
	mic_row.add_theme_constant_override("h_separation", 10)
	mic_row.add_theme_constant_override("v_separation", 6)
	v.add_child(mic_row)
	var mic := UiTheme.tw_button("Thu âm giọng nói", "mic", "outline-red", 14)
	(mic.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = BanhTet.RED_50
	(mic.get_theme_stylebox("normal") as StyleBoxFlat).border_color = BanhTet.RED_300
	mic.custom_minimum_size.y = 40
	mic.pressed.connect(func(): _quick_input.grab_focus())
	mic.tooltip_text = "Bản Godot chưa hỗ trợ nhận giọng nói - hãy dùng bàn phím giọng nói của điện thoại"
	mic_row.add_child(mic)
	var eg := UiTheme.text("Ví dụ: “Bán chị Lan 5 bánh chưng mặn giao 28 Tết”", 12, BanhTet.GRAY_500)
	eg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mic_row.add_child(eg)

	_quick_input = UiTheme.text_area("Ví dụ: bà mi / 03/02/2027 / 2 CM / 1 CC / 8 giờ sáng")
	_quick_input.custom_minimum_size.y = 72
	_quick_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	UiTheme.set_weight(_quick_input, "medium")
	_quick_input.text_changed.connect(_on_quick_changed)
	v.add_child(_quick_input)

	var act := HBoxContainer.new()
	act.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(act)
	_parse_btn = UiTheme.tw_button("Phân Tích & Tạo Đơn", "sparkles", "primary", 13, Color("#fcd34d"))
	_parse_btn.disabled = true
	_parse_btn.pressed.connect(_on_parse_pressed)
	act.add_child(_parse_btn)
	return outer


func _build_hint() -> Control:
	var st := UiTheme.box_style(Color(1, 1, 1, 0.7), Color.TRANSPARENT, 0, 20, 12)
	st.border_color = BanhTet.AMBER_200
	st.border_width_bottom = 1
	var p := UiTheme.panel(st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var lines := [
		["Cú pháp: ", "tên khách / ngày giao / số lượng + mã hoặc tên bánh / khung giờ giao"],
		["Mã bánh: ", "CM (chưng thịt), CC (chưng chay), CML (chưng thịt lớn), CCL (chưng chay lớn), TT (tét thịt), TN (tét ngọt), TC (tét chay)"],
		["Ngày: ", "03/02/2027 hoặc \"27 tết\""],
		["Giờ: ", "\"8 giờ sáng\", \"chiều\", \"tối\""],
	]
	for i in lines.size():
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.add_theme_font_size_override("normal_font_size", 12)
		r.add_theme_font_size_override("bold_font_size", 12)
		r.add_theme_font_override("normal_font", UiTheme.font("regular"))
		r.add_theme_font_override("bold_font", UiTheme.font("bold"))
		r.add_theme_color_override("default_color", BanhTet.GRAY_600)
		var key_color := "#374151" if i == 0 else "#047857"
		var val_color := "#b91c1c" if i == 0 else "#4b5563"
		r.text = "[b][color=%s]%s[/color][/b][color=%s]%s[/color]" % [key_color, lines[i][0], val_color, lines[i][1]]
		v.add_child(r)
	var ex_row := HFlowContainer.new()
	ex_row.add_theme_constant_override("h_separation", 6)
	ex_row.add_theme_constant_override("v_separation", 6)
	v.add_child(ex_row)
	for ex in ["bà mi / 03/02/2027 / 2 CM / 1 CC / 8 giờ sáng", "chị Lan 0912345678 5 bánh chưng mặn 28 Tết", "anh Hùng / 27 tết / 3 TT / 2 TN / chiều"]:
		var b := Button.new()
		b.text = ex
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_stylebox_override("normal", UiTheme.box_style(BanhTet.AMBER_50, BanhTet.AMBER_200, 6, 8, 4))
		b.add_theme_stylebox_override("hover", UiTheme.box_style(BanhTet.AMBER_100, BanhTet.RED_300, 6, 8, 4))
		b.add_theme_stylebox_override("pressed", UiTheme.box_style(BanhTet.AMBER_100, BanhTet.RED_300, 6, 8, 4))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, BanhTet.AMBER_900)
		b.pressed.connect(func():
			_quick_input.text = ex
			_on_quick_changed())
		ex_row.add_child(b)
	return p


func _toggle_hint() -> void:
	_quick_hint.visible = not _quick_hint.visible
	_hint_btn.text = "Ẩn hướng dẫn" if _quick_hint.visible else "Hướng dẫn cú pháp"


func _on_quick_changed() -> void:
	var parsed: Dictionary = QuickParse.parse_quick_order(_quick_input.text, store.products)
	var q = parsed.get("quantities", {})
	_parse_btn.disabled = _quick_input.text.strip_edges() == "" or q.is_empty()


func _on_parse_pressed() -> void:
	open_create.emit("parse", _quick_input.text)


## ===================================================== Danh sách đơn hàng
func _build_list_card() -> Control:
	var st := UiTheme.box_style(BanhTet.WHITE, BanhTet.GRAY_200, 16)
	st.shadow_color = Color(0, 0, 0, 0.05)
	st.shadow_size = 2
	st.shadow_offset = Vector2(0, 1)
	var card := UiTheme.panel(st)
	card.clip_contents = true
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)

	# Header: tiêu đề + badge số đơn
	var hs := StyleBoxTexture.new()
	hs.texture = _gradient([Color("#fef7f7"), BanhTet.WHITE, Color("#fffcf5")])
	hs.content_margin_left = 20
	hs.content_margin_right = 20
	hs.content_margin_top = 16
	hs.content_margin_bottom = 16
	var head := UiTheme.panel(hs)
	col.add_child(head)
	col.add_child(_hline())
	var hr := HBoxContainer.new()
	head.add_child(hr)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 2)
	hr.add_child(tv)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	trow.add_child(UiTheme.icon("clipboard-list", 16, BanhTet.RED_700))
	trow.add_child(UiTheme.text("Danh Sách Đơn Hàng", 16, BanhTet.GRAY_900, "extrabold"))
	tv.add_child(trow)
	var sub := UiTheme.text("Quản lý đơn đặt bánh chưng & bánh tét dịp Tết Đinh Mùi 2027", 12, BanhTet.GRAY_500)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(sub)
	var badge := UiTheme.panel(UiTheme.box_style(BanhTet.RED_50, BanhTet.RED_200, 999, 10, 2))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_count_badge = UiTheme.text("0 đơn", 12, BanhTet.RED_700, "bold")
	badge.add_child(_count_badge)
	hr.add_child(badge)

	col.add_child(_build_toolbar())
	col.add_child(_hline())

	# Lưới đơn
	var gs := UiTheme.box_style(Color("#fffdf8"), Color.TRANSPARENT, 0, 20, 20)
	var grid_panel := UiTheme.panel(gs)
	col.add_child(grid_panel)
	var gv := VBoxContainer.new()
	grid_panel.add_child(gv)
	_order_grid = GridContainer.new()
	_order_grid.add_theme_constant_override("h_separation", 20)
	_order_grid.add_theme_constant_override("v_separation", 20)
	gv.add_child(_order_grid)
	_empty_box = _build_empty()
	gv.add_child(_empty_box)

	# Footer
	col.add_child(_hline())
	var fs := UiTheme.box_style(BanhTet.GRAY_50, Color.TRANSPARENT, 0, 20, 12)
	var foot := UiTheme.panel(fs)
	col.add_child(foot)
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 0)
	foot.add_child(fr)
	fr.add_child(UiTheme.text("Hiển thị ", 12, BanhTet.GRAY_600))
	_footer_count = UiTheme.text("0", 12, BanhTet.RED_700, "bold")
	fr.add_child(_footer_count)
	fr.add_child(UiTheme.text(" đơn hàng", 12, BanhTet.GRAY_600))
	return card


func _hline() -> Control:
	var r := ColorRect.new()
	r.color = BanhTet.GRAY_200
	r.custom_minimum_size.y = 1
	return r


func _build_empty() -> Control:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size.y = 220
	var circle := UiTheme.panel(UiTheme.box_style(BanhTet.AMBER_100, Color.TRANSPARENT, 40, 0, 0))
	circle.custom_minimum_size = Vector2(80, 80)
	circle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lamp := UiTheme.text("🏮", 36, BanhTet.AMBER_600)
	lamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	circle.add_child(lamp)
	v.add_child(circle)
	var t := UiTheme.text("Không tìm thấy đơn hàng nào!", 18, BanhTet.GRAY_800, "bold")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := UiTheme.text("Vui lòng thử lại với từ khóa hoặc bộ lọc khác.", 12, BanhTet.GRAY_500)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	return v


## order-toolbar.tsx: ô tìm kiếm có icon | trạng thái, loại bánh, ngày, sắp xếp, reset
func _build_toolbar() -> Control:
	var ts := StyleBoxTexture.new()
	ts.texture = _gradient([Color("#fef8f8"), BanhTet.WHITE, Color("#fffdf7")])
	ts.content_margin_left = 20
	ts.content_margin_right = 20
	ts.content_margin_top = 16
	ts.content_margin_bottom = 16
	var p := UiTheme.panel(ts)

	_toolbar_box = BoxContainer.new()
	_toolbar_box.add_theme_constant_override("separation", 12)
	p.add_child(_toolbar_box)

	_search_edit = UiTheme.line_edit("Tìm tên khách, SĐT, mã đơn...")
	_search_edit.right_icon = null
	var ss := UiTheme.input_style()
	ss.content_margin_left = 34
	_search_edit.add_theme_stylebox_override("normal", ss)
	var sf := UiTheme.input_focus_style()
	sf.content_margin_left = 34
	_search_edit.add_theme_stylebox_override("focus", sf)
	_search_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search_edit.custom_minimum_size.y = 36
	_search_edit.text = store.filter_search
	var search_icon := UiTheme.icon("search", 16, BanhTet.GRAY_400)
	search_icon.position = Vector2(11, 11)
	_search_edit.add_child(search_icon)
	_search_edit.text_changed.connect(_on_search_changed)
	_toolbar_box.add_child(_search_edit)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toolbar_box.add_child(spacer)

	_toolbar_filters = GridContainer.new()
	_toolbar_filters.add_theme_constant_override("h_separation", 10)
	_toolbar_filters.add_theme_constant_override("v_separation", 8)
	_toolbar_box.add_child(_toolbar_filters)

	var status_items := ["-- Tất cả trạng thái --"]
	for status in BanhTet.ORDER_STATUSES:
		status_items.append(str(BanhTet.STATUS_LABELS[status]))
	_status_filter = _filter_select(status_items, 170)
	_cake_filter = _filter_select(["-- Tất cả loại bánh --", "Bánh Chưng", "Bánh Tét"], 160)
	var date_items := ["-- Tất cả ngày --"]
	for suggestion in BanhTet.DELIVERY_DATE_SUGGESTIONS:
		date_items.append(str(suggestion["label"]))
	_date_filter = _filter_select(date_items, 160)
	_sort_filter = _filter_select(["⏳ Mới nhất", "⌛ Cũ nhất", "🔥 Giao gấp (Ngày giao)"], 170)
	# Ô sắp xếp viền vàng nền amber-50 như web
	var sort_style := UiTheme.web_input_style(false)
	sort_style.bg_color = BanhTet.AMBER_50
	sort_style.border_color = BanhTet.AMBER_300
	_sort_filter.add_theme_stylebox_override("normal", sort_style)
	_sort_filter.add_theme_stylebox_override("hover", sort_style)
	_sort_filter.add_theme_color_override("font_color", BanhTet.AMBER_900)
	UiTheme.set_weight(_sort_filter, "semibold")

	var reset := UiTheme.tw_button("", "rotate-ccw", "ghost", 14)
	reset.tooltip_text = "Đặt lại bộ lọc"
	reset.custom_minimum_size = Vector2(36, 36)
	reset.pressed.connect(_on_reset_filters)
	_toolbar_filters.add_child(reset)
	# Ô cuối trống để lưới 2 cột (điện thoại) không lệch
	_toolbar_filters.add_child(Control.new())
	return p


func _filter_select(items: Array, min_w: int) -> OptionButton:
	var o := UiTheme.option_button(items)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.custom_minimum_size = Vector2(min_w, 36)
	UiTheme.set_weight(o, "medium")
	o.item_selected.connect(_on_filter_changed)
	_toolbar_filters.add_child(o)
	return o


func _on_reset_filters() -> void:
	_search_edit.text = ""
	_status_filter.selected = 0
	_cake_filter.selected = 0
	_date_filter.selected = 0
	_sort_filter.selected = 0
	store.filter_search = ""
	_on_filter_changed(0)


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


func _on_search_changed(text: String) -> void:
	store.filter_search = text
	_refresh()


func _on_filter_changed(_index: int) -> void:
	var status_index := _status_filter.selected
	if status_index <= 0:
		store.filter_status = "ALL"
	else:
		store.filter_status = BanhTet.ORDER_STATUSES[status_index - 1]

	var cake_index := _cake_filter.selected
	store.filter_cake = "ALL" if cake_index <= 0 else ("CHUNG" if cake_index == 1 else "TET")

	var date_index := _date_filter.selected
	if date_index <= 0:
		store.filter_delivery_date = "ALL"
	else:
		store.filter_delivery_date = str(BanhTet.DELIVERY_DATE_SUGGESTIONS[date_index - 1]["value"])

	var sort_index := maxi(0, _sort_filter.selected)
	store.filter_sort = ["NEWEST", "OLDEST", "URGENT"][sort_index]

	_refresh()


func _refresh() -> void:
	_refresh_stats()

	for child in _order_grid.get_children():
		child.queue_free()

	var orders := store.filtered_orders()
	_empty_box.visible = orders.is_empty()
	_order_grid.visible = not orders.is_empty()
	_count_badge.text = "%d đơn" % orders.size()
	_footer_count.text = str(orders.size())

	for order in orders:
		_order_grid.add_child(_build_order_card(order))


## ============================================================ Thẻ đơn hàng
## order-card.tsx
func _build_order_card(order: Dictionary) -> Control:
	var status := str(order.get("status", ""))
	var is_cancelled := status == "Đã hủy"
	var id := str(order.get("id", ""))

	var st := UiTheme.box_style(BanhTet.WHITE, BanhTet.RED_200 if is_cancelled else BanhTet.AMBER_200, 16)
	st.shadow_color = Color(0, 0, 0, 0.05)
	st.shadow_size = 2
	st.shadow_offset = Vector2(0, 1)
	var card := UiTheme.panel(st)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	if is_cancelled:
		card.modulate = Color(1, 1, 1, 0.75)

	var outer := HBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	card.add_child(outer)

	# Viền trạng thái bên trái (w-1)
	var accent := Panel.new()
	var acs := StyleBoxFlat.new()
	acs.bg_color = BanhTet.STATUS_ACCENT_COLORS.get(status, BanhTet.GRAY_300)
	acs.corner_radius_top_left = 16
	acs.corner_radius_bottom_left = 16
	acs.anti_aliasing = true
	accent.add_theme_stylebox_override("panel", acs)
	accent.custom_minimum_size = Vector2(4, 0)
	outer.add_child(accent)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	outer.add_child(box)

	# --- Đầu card ---
	var head_m := _margin(12, 16, 16, 12)
	box.add_child(head_m)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	head_m.add_child(header)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	header.add_child(left)

	var id_row := HBoxContainer.new()
	id_row.add_theme_constant_override("separation", 8)
	left.add_child(id_row)
	var id_btn := LinkButton.new()
	id_btn.text = "#%s" % id
	id_btn.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	id_btn.add_theme_font_size_override("font_size", 14)
	id_btn.add_theme_font_override("font", UiTheme.font("extrabold"))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		id_btn.add_theme_color_override(c, BanhTet.RED_700)
	id_btn.tooltip_text = "Xem chi tiết"
	id_btn.pressed.connect(_show_order_detail.bind(order))
	id_row.add_child(id_btn)
	var cb := UiTheme.panel(UiTheme.box_style(Color("#ecfdf5"), Color("#a7f3d0"), 999, 8, 1))
	cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cb.add_child(UiTheme.text("%d bánh" % _total_cakes(order), 11, Color("#065f46"), "bold"))
	id_row.add_child(cb)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	name_row.add_child(UiTheme.icon("user", 14, BanhTet.AMBER_600))
	var nm := UiTheme.text(str(order.get("customerName", "")), 14, BanhTet.GRAY_900, "bold")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	name_row.add_child(nm)
	left.add_child(name_row)

	var phone := str(order.get("phone", ""))
	var phone_row := HBoxContainer.new()
	phone_row.add_theme_constant_override("separation", 4)
	phone_row.add_child(UiTheme.icon("phone", 12, BanhTet.GRAY_400))
	phone_row.add_child(UiTheme.text(phone, 12, BanhTet.GRAY_500, "medium"))
	left.add_child(phone_row)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	header.add_child(right)
	var sb := UiTheme.status_badge(status)
	sb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(sb)
	if phone != "":
		var call := Button.new()
		call.icon = UiTheme.icon_texture("phone-call", 20, BanhTet.RED_600)
		call.tooltip_text = "Gọi khách hàng"
		call.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		call.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		call.add_theme_stylebox_override("normal", UiTheme.box_style(BanhTet.WHITE, Color("#9f0712"), 16, 8, 8))
		call.add_theme_stylebox_override("hover", UiTheme.box_style(BanhTet.RED_50, Color("#9f0712"), 16, 8, 8))
		call.add_theme_stylebox_override("pressed", UiTheme.box_style(BanhTet.RED_50, Color("#9f0712"), 16, 8, 8))
		call.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		call.pressed.connect(_on_call_pressed.bind(phone))
		right.add_child(call)

	# --- Địa chỉ + ngày giao ---
	var addr_m := _margin(0, 16, 16, 12)
	box.add_child(addr_m)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 6)
	addr_m.add_child(av)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 6)
	var pin := UiTheme.icon("map-pin", 12, BanhTet.AMBER_600)
	pin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	arow.add_child(pin)
	var addr := UiTheme.text(str(order.get("address", "")), 12, BanhTet.GRAY_600)
	addr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	addr.max_lines_visible = 2
	addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arow.add_child(addr)
	av.add_child(arow)
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 6)
	drow.add_child(UiTheme.icon("calendar-clock", 12, BanhTet.AMBER_600))
	drow.add_child(UiTheme.text(BanhTet.format_date_display(str(order.get("deliveryDate", ""))), 12, BanhTet.RED_700, "semibold"))
	drow.add_child(UiTheme.text("·", 12, BanhTet.GRAY_400, "semibold"))
	var tm := UiTheme.text(str(order.get("deliveryTime", "")), 12, BanhTet.GRAY_600, "semibold")
	tm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tm.clip_text = true
	tm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drow.add_child(tm)
	av.add_child(drow)

	# Đẩy phần tiền xuống đáy (mt-auto) để các thẻ cùng hàng bằng nhau
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(fill)

	# --- Tiền ---
	box.add_child(_hline_color(BanhTet.GRAY_100))
	var ms := UiTheme.box_style(Color(BanhTet.GRAY_50, 0.7), Color.TRANSPARENT, 0, 16, 12)
	var money := UiTheme.panel(ms)
	box.add_child(money)
	var mr := HBoxContainer.new()
	money.add_child(mr)
	var tb := VBoxContainer.new()
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.add_theme_constant_override("separation", 0)
	mr.add_child(tb)
	tb.add_child(UiTheme.text("TỔNG TIỀN", 10, BanhTet.GRAY_400, "bold"))
	tb.add_child(UiTheme.text(BanhTet.format_money(int(order.get("totalAmount", 0))), 14, BanhTet.GRAY_900, "bold"))
	var rb := VBoxContainer.new()
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb.add_theme_constant_override("separation", 0)
	mr.add_child(rb)
	var rc := UiTheme.text("CÒN LẠI THU", 10, BanhTet.RED_500, "bold")
	rc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rb.add_child(rc)
	var remain := int(order.get("totalAmount", 0)) - int(order.get("deposit", 0))
	var rv := UiTheme.text(BanhTet.format_money(remain), 14, BanhTet.RED_700, "extrabold")
	rv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rb.add_child(rv)

	# --- Chân card: đổi trạng thái + xem / sửa / xoá ---
	box.add_child(_hline_color(BanhTet.GRAY_100))
	var fm := _margin(10, 12, 12, 10)
	box.add_child(fm)
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 8)
	fm.add_child(fr)
	var labels: Array = []
	for s in BanhTet.ORDER_STATUSES:
		labels.append(str(BanhTet.STATUS_LABELS[s]))
	var sel := UiTheme.option_button(labels)
	sel.selected = maxi(0, BanhTet.ORDER_STATUSES.find(status))
	sel.custom_minimum_size = Vector2(145, 32)
	sel.add_theme_font_size_override("font_size", 12)
	UiTheme.set_weight(sel, "semibold")
	sel.item_selected.connect(_on_status_selected.bind(id))
	fr.add_child(sel)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fr.add_child(sp)
	fr.add_child(_icon_action("eye", Color("#2563eb"), Color("#eff6ff"), "Xem chi tiết & In phiếu", _show_order_detail.bind(order)))
	fr.add_child(_icon_action("pencil", BanhTet.AMBER_600, BanhTet.AMBER_50, "Sửa đơn hàng", func(): open_create.emit("edit", order)))
	fr.add_child(_icon_action("trash-2", BanhTet.RED_600, BanhTet.RED_50, "Xóa đơn", _confirm_delete.bind(id)))

	return card


func _margin(top: int, left: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	return m


func _hline_color(c: Color) -> Control:
	var r := ColorRect.new()
	r.color = c
	r.custom_minimum_size.y = 1
	return r


func _icon_action(icon_name: String, fg: Color, hover_bg: Color, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.icon = UiTheme.icon_texture(icon_name, 14, fg)
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(32, 32)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", UiTheme.box_style(Color.TRANSPARENT, Color.TRANSPARENT, 8))
	b.add_theme_stylebox_override("hover", UiTheme.box_style(hover_bg, Color.TRANSPARENT, 8))
	b.add_theme_stylebox_override("pressed", UiTheme.box_style(hover_bg, Color.TRANSPARENT, 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b


func _on_status_selected(index: int, id: String) -> void:
	await store.update_order(id, {"status": BanhTet.ORDER_STATUSES[index]})


## Web dùng window.confirm(...) -> bản web gọi đúng confirm của trình duyệt;
## Android dùng WebDialog cùng nội dung.
func _confirm_delete(id: String) -> void:
	var msg := "Bạn có chắc chắn muốn xóa đơn hàng #%s không?" % id
	if OS.has_feature("web"):
		var ok = JavaScriptBridge.eval("window.confirm(%s)" % JSON.stringify(msg))
		if ok:
			await store.delete_order(id)
		return
	var d := WebDialog.open(self, "Xóa đơn hàng", msg)
	var cancel := WebDialog.button("Huỷ", "", Color("#f5f5f5"), UiTheme.WEB_FG)
	cancel.pressed.connect(d.close)
	d.add_footer_button(cancel)
	var del := WebDialog.button("Xóa", "trash-2", BanhTet.RED_600, BanhTet.WHITE)
	del.pressed.connect(func():
		d.close()
		await store.delete_order(id))
	d.add_footer_button(del)


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


## order-detail-dialog.tsx + order-print-sheet.tsx: phiếu đặt bánh (đường kẻ
## đứt), footer: "Đóng" (secondary) + "In Phiếu Đặt Hàng" (emerald-600).
func _show_order_detail(order: Dictionary) -> void:
	var d := WebDialog.open(self, "", "", 768)
	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", 0)
	d.body.add_child(sheet)

	# --- Tiêu đề ---
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	for item in [["PHIẾU ĐẶT BÁNH TẾT", 26, BanhTet.RED_700, "extrabold"], ["2027", 17, BanhTet.RED_600, "extrabold"], ["Bánh Chưng - Bánh Tét Gia Truyền", 11, BanhTet.GRAY_600, "regular"]]:
		var l := UiTheme.text(item[0], item[1], item[2], item[3])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(l)
	sheet.add_child(_sheet_section(head, 0, 6))

	# --- Mã đơn + ngày ---
	var idr := HBoxContainer.new()
	var idl := UiTheme.text("Mã đơn: #%s" % str(order.get("id", "")), 12, BanhTet.GRAY_900, "bold")
	idl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	idr.add_child(idl)
	idr.add_child(UiTheme.text(BanhTet.format_date_display(str(order.get("deliveryDate", ""))), 12, BanhTet.GRAY_600))
	sheet.add_child(_sheet_section(idr, 4, 4))

	# --- Khách hàng ---
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.add_child(_sheet_row("Khách hàng", str(order.get("customerName", "")), true))
	info.add_child(_sheet_row("SĐT", str(order.get("phone", "")), true))
	info.add_child(_sheet_row("Địa chỉ", str(order.get("address", ""))))
	info.add_child(_sheet_row("Ngày & giờ giao", "%s (%s)" % [BanhTet.format_date_display(str(order.get("deliveryDate", ""))), str(order.get("deliveryTime", ""))], true, true))
	var st := str(order.get("status", ""))
	info.add_child(_sheet_row("Trạng thái", str(BanhTet.STATUS_LABELS.get(st, st))))
	sheet.add_child(_sheet_section(info, 6, 6))

	# --- Sản phẩm ---
	var prod := VBoxContainer.new()
	prod.add_theme_constant_override("separation", 0)
	var ph := UiTheme.text("SẢN PHẨM ĐÃ ĐẶT", 13, BanhTet.GRAY_900, "extrabold")
	ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prod.add_child(ph)
	var items = order.get("items", {})
	var keys: Array = []
	for k in items:
		if int(items[k]) > 0 and not store.find_product(str(k)).is_empty():
			keys.append(k)
	for i in keys.size():
		var product := store.find_product(str(keys[i]))
		var qty := int(items[keys[i]])
		var li := VBoxContainer.new()
		li.add_theme_constant_override("separation", 2)
		var r1 := HBoxContainer.new()
		var nm := RichTextLabel.new()
		nm.bbcode_enabled = true
		nm.fit_content = true
		nm.scroll_active = false
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_font_override("normal_font", UiTheme.font("regular"))
		nm.add_theme_font_override("bold_font", UiTheme.font("bold"))
		nm.add_theme_font_size_override("normal_font_size", 12)
		nm.add_theme_font_size_override("bold_font_size", 12)
		var w := str(product.get("weight", ""))
		nm.text = "[b][color=#111827]%s[/color][/b]%s" % [str(product.get("name", "")), (" [color=#6b7280](%s)[/color]" % w) if w != "" else ""]
		r1.add_child(nm)
		r1.add_child(UiTheme.text("×%d" % qty, 12, BanhTet.RED_700, "extrabold"))
		li.add_child(r1)
		var r2 := HBoxContainer.new()
		var up := UiTheme.text("%s/cái" % BanhTet.format_money(int(product.get("price", 0))), 12, BanhTet.GRAY_600)
		up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r2.add_child(up)
		r2.add_child(UiTheme.text(BanhTet.format_money(int(product.get("price", 0)) * qty), 12, BanhTet.GRAY_900, "bold"))
		li.add_child(r2)
		var pad := _margin(4, 0, 0, 4)
		pad.add_child(li)
		if i < keys.size() - 1:
			prod.add_child(_dashed_wrap(pad, BanhTet.GRAY_300, false))
		else:
			prod.add_child(pad)
	sheet.add_child(_sheet_section(prod, 6, 6, false))

	# --- Tổng tiền (border-y dashed) ---
	var tot := VBoxContainer.new()
	tot.add_theme_constant_override("separation", 2)
	tot.add_child(_money_row("Tổng tiền bánh:", BanhTet.format_money(int(order.get("totalAmount", 0))), BanhTet.GRAY_600, BanhTet.GRAY_900, 12))
	tot.add_child(_money_row("Đã đặt cọc trước:", "-" + BanhTet.format_money(int(order.get("deposit", 0))), BanhTet.GREEN_700, BanhTet.GREEN_700, 12))
	tot.add_child(_hline_color(BanhTet.GRAY_300))
	var remain := int(order.get("totalAmount", 0)) - int(order.get("deposit", 0))
	var rr := _money_row("Còn lại khi giao:", BanhTet.format_money(remain), BanhTet.RED_700, BanhTet.RED_700, 15, "extrabold")
	tot.add_child(rr)
	var notes := str(order.get("notes", ""))
	if notes != "":
		tot.add_child(_hline_color(BanhTet.GRAY_300))
		var nl := RichTextLabel.new()
		nl.bbcode_enabled = true
		nl.fit_content = true
		nl.add_theme_font_override("normal_font", UiTheme.font("regular"))
		nl.add_theme_font_override("bold_font", UiTheme.font("bold"))
		nl.add_theme_font_size_override("normal_font_size", 11)
		nl.add_theme_font_size_override("bold_font_size", 11)
		nl.add_theme_color_override("default_color", BanhTet.GRAY_700)
		nl.text = "[b]Ghi chú:[/b] " + notes
		tot.add_child(nl)
	var tot_top := _dashed_wrap(tot, BanhTet.GRAY_400, true)
	sheet.add_child(_sheet_section(tot_top, 6, 6))

	# --- Chữ ký ---
	var sig := GridContainer.new()
	sig.columns = 2
	sig.add_theme_constant_override("h_separation", 12)
	for pair in [["Người Đặt Bánh", "(Ký & ghi rõ họ tên)"], ["Bánh Tết Gia Truyền", "(Xác nhận & Đóng dấu)"]]:
		var c := VBoxContainer.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_constant_override("separation", 2)
		var t1 := UiTheme.text(pair[0], 11, BanhTet.GRAY_800, "bold")
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(t1)
		var gap := Control.new()
		gap.custom_minimum_size.y = 26
		c.add_child(gap)
		c.add_child(_hline_color(BanhTet.GRAY_400))
		var t2 := UiTheme.text(pair[1], 11, BanhTet.GRAY_600)
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(t2)
		sig.add_child(c)
	var sigm := _margin(8, 0, 0, 4)
	sigm.add_child(sig)
	sheet.add_child(sigm)
	var thanks := UiTheme.text("Cảm ơn quý khách! Hẹn giao bánh đúng ngày 🌺", 10, BanhTet.GRAY_500)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet.add_child(thanks)

	# --- Footer ---
	var close_btn := WebDialog.button("Đóng", "x", Color("#f5f5f5"), UiTheme.WEB_FG)
	close_btn.pressed.connect(d.close)
	d.add_footer_button(close_btn)
	var print_btn := WebDialog.button("In Phiếu Đặt Hàng", "printer", BanhTet.GREEN_600, BanhTet.WHITE)
	UiTheme.set_weight(print_btn, "bold")
	print_btn.pressed.connect(_print_order.bind(order, print_btn))
	d.add_footer_button(print_btn)


## Một section của phiếu, có viền đứt phía dưới (border-b border-dashed)
func _sheet_section(content: Control, pad_top: int, pad_bottom: int, dashed_bottom: bool = true) -> Control:
	var m := _margin(pad_top, 0, 0, pad_bottom)
	m.add_child(content)
	if not dashed_bottom:
		return m
	return _dashed_wrap(m, BanhTet.GRAY_400, false)


## Vẽ đường kẻ đứt dưới (và trên nếu both=true) một control
func _dashed_wrap(content: Control, color: Color, both: bool) -> Control:
	var holder := MarginContainer.new()
	holder.add_child(content)
	holder.draw.connect(func():
		var w := holder.size.x
		holder.draw_dashed_line(Vector2(0, holder.size.y - 0.5), Vector2(w, holder.size.y - 0.5), color, 1.0, 4.0)
		if both:
			holder.draw_dashed_line(Vector2(0, 0.5), Vector2(w, 0.5), color, 1.0, 4.0))
	holder.resized.connect(holder.queue_redraw)
	return holder


func _sheet_row(label_text: String, value: String, bold: bool = false, accent: bool = false) -> Control:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	var l := UiTheme.text(label_text + ":", 12, BanhTet.GRAY_500)
	l.custom_minimum_size.x = 86
	r.add_child(l)
	var v := UiTheme.text(value, 12, BanhTet.RED_700 if accent else BanhTet.GRAY_900, "bold" if bold else "medium")
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(v)
	return r


func _money_row(label_text: String, value: String, lc: Color, vc: Color, size: int, weight: String = "bold") -> Control:
	var r := HBoxContainer.new()
	var l := UiTheme.text(label_text, size, lc, weight if size > 12 else "regular")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	r.add_child(UiTheme.text(value, size, vc, weight))
	return r


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
	btn.text = "In Phiếu Đặt Hàng"
