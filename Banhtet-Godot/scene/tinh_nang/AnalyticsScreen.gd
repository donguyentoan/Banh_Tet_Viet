extends VBoxContainer

## Màn hình Thống Kê & Cân Đối Kho - port 1:1 từ src/pages/analytics-page.tsx:
##   Banner đỏ (tổng cầu / tổng đã làm) -> Cảnh báo thiếu bánh -> Chọn ngày ->
##   [Bảng Đối Soát Kho Bánh | (Số Lượng Ra Lò + Tồn Kho Gối Đầu Các Ngày)]
## Desktop >= xl (1280): 2 cột [1fr, 380px]; nhỏ hơn: xếp dọc.
## < sm (640): bảng đối soát chuyển thành danh sách thẻ (giống web sm:hidden).

var store: BakeryStore

const BP_XL := 1280
const BLUE_50 := Color("#eff6ff")
const BLUE_300 := Color("#93c5fd")
const BLUE_700 := Color("#1d4ed8")
const BLUE_800 := Color("#1e40af")
const BLUE_900 := Color("#1e3a8a")
const ORANGE_50 := Color("#fff7ed")
const ORANGE_600 := Color("#ea580c")
const ORANGE_700 := Color("#c2410c")
const EMERALD_100 := Color("#d1fae5")
const EMERALD_300 := Color("#6ee7b7")
const EMERALD_700 := Color("#047857")
const EMERALD_800 := Color("#065f46")
const RED_300 := Color("#fca5a5")

var _dates: Array[String] = []
var _selected_date := ""
var _produced_input := {}   # productId -> int (giá trị đang sửa)
var _chain := {}            # date -> {productId: qty}
var _balance := {}

var _width := 0.0
var _last_layout := ""
var _toast: PanelContainer
var _toast_label: Label
var _toast_timer: Timer


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 24)

	_dates = ProductionCalc.each_date(
		str(BanhTet.DELIVERY_DATE_SUGGESTIONS[0]["value"]),
		str(BanhTet.DELIVERY_DATE_SUGGESTIONS[BanhTet.DELIVERY_DATE_SUGGESTIONS.size() - 1]["value"])
	)
	_selected_date = _dates[0]

	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(func(): if is_instance_valid(_toast): _toast.visible = false)
	add_child(_toast_timer)

	store.orders_changed.connect(_rebuild)
	store.products_changed.connect(_rebuild)
	store.wholesale_changed.connect(_rebuild)
	store.data_loaded.connect(_rebuild)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_width = get_viewport_rect().size.x
	_last_layout = _layout_key()
	_rebuild()


func _layout_key() -> String:
	if _width >= BP_XL:
		return "xl"
	if _width >= UiTheme.BP_MD:
		return "md"
	if _width >= UiTheme.BP_SM:
		return "sm"
	return "xs"


func _on_viewport_resized() -> void:
	_width = get_viewport_rect().size.x
	var key := _layout_key()
	if key != _last_layout:
		_last_layout = key
		_rebuild()


## ================================================================ Dữ liệu
func _compute() -> void:
	_chain = ProductionCalc.build_inventory_chain(
		_dates, store.orders, store.wholesale, store.production, store.inventory, store.products
	)
	_balance = ProductionCalc.calculate_day_balance(
		_selected_date, store.orders, store.wholesale, store.production,
		[{"id": "chain", "date": _selected_date, "items": _chain.get(_selected_date, {})}],
		store.products
	)


func _production_today() -> Dictionary:
	for p in store.production:
		if str(p.get("date", "")) == _selected_date:
			return p
	return {}


func _produced_qty(product_id: String) -> int:
	if _produced_input.has(product_id):
		return int(_produced_input[product_id])
	var items = _production_today().get("items", {})
	return int(items.get(product_id, 0)) if items is Dictionary else 0


func _opening_qty(product_id: String) -> int:
	return int((_chain.get(_selected_date, {}) as Dictionary).get(product_id, 0))


## ================================================================ Dựng UI
func _rebuild() -> void:
	for child in get_children():
		if child != _toast_timer:
			child.queue_free()
	_toast = null
	_compute()

	var sm := _width >= UiTheme.BP_SM

	add_child(_build_banner())

	var shortage: Array = []
	for row in _balance["rows"]:
		if int(row["surplus"]) < 0:
			shortage.append(row)
	if not shortage.is_empty():
		add_child(_build_shortage(shortage))

	add_child(_build_date_buttons())

	# grid-cols-1 xl:grid-cols-[1fr_380px] gap-6
	var main := BoxContainer.new()
	main.vertical = _width < BP_XL
	main.add_theme_constant_override("separation", 24)
	add_child(main)

	var table_card := _build_balance_card(sm)
	table_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main.add_child(table_card)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 24)
	side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if _width >= BP_XL:
		side.custom_minimum_size.x = 380
	else:
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(side)
	side.add_child(_build_production_card())
	side.add_child(_build_chain_card())

	_build_toast()


## --------------------------------------------------------------- Banner
func _build_banner() -> Control:
	var sm := _width >= UiTheme.BP_SM
	var md := _width >= UiTheme.BP_MD

	# rounded-2xl border-amber-300 gradient red-800 -> red-700 -> amber-700, shadow-lg
	var st := StyleBoxTexture.new()
	st.texture = _gradient([BanhTet.RED_800, BanhTet.RED_700, Color("#b45309")])
	var pad_x := 24.0 if sm else 16.0
	var pad_y := 24.0 if sm else 16.0
	st.content_margin_left = pad_x
	st.content_margin_right = pad_x
	st.content_margin_top = pad_y
	st.content_margin_bottom = pad_y
	# Bo góc: bọc trong panel có clip
	var frame_style := UiTheme.box_style(BanhTet.RED_700, BanhTet.AMBER_300, 16)
	frame_style.shadow_color = Color(0.5, 0.05, 0.05, 0.25)
	frame_style.shadow_size = 10
	frame_style.shadow_offset = Vector2(0, 6)
	var frame := UiTheme.panel(frame_style)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var inner := UiTheme.panel(st)
	frame.add_child(inner)

	var box := BoxContainer.new()
	box.vertical = not md
	box.add_theme_constant_override("separation", 16 if sm else 12)
	inner.add_child(box)

	# Trái: icon + tiêu đề
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 16 if sm else 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(left)

	var icon_sz := 56 if sm else 44
	var ic := UiTheme.panel(UiTheme.box_style(Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.25), 16 if sm else 12))
	ic.custom_minimum_size = Vector2(icon_sz, icon_sz)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER if sm else Control.SIZE_SHRINK_BEGIN
	var fac := UiTheme.icon("factory", 28 if sm else 24, Color("#fde68a"))
	fac.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.add_child(fac)
	left.add_child(ic)

	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.add_theme_constant_override("separation", 4)
	left.add_child(tv)
	var trow := HFlowContainer.new()
	trow.add_theme_constant_override("h_separation", 8)
	trow.add_theme_constant_override("v_separation", 4)
	tv.add_child(trow)
	var title := UiTheme.text(
		"Thống Kê & Cân Đối Kho Bánh" if sm else "Cân Đối Kho Bánh",
		24 if sm else 18, BanhTet.WHITE, "extrabold"
	)
	trow.add_child(title)
	var badge := UiTheme.panel(UiTheme.box_style(BanhTet.AMBER_300, BanhTet.AMBER_200, 8, 8, 1))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(UiTheme.text("BẾP", 11 if sm else 10, Color("#451a03"), "extrabold"))
	trow.add_child(badge)
	if sm:
		var sub := UiTheme.text(
			"Nhập số bánh ra lò, đối chiếu nhu cầu giao & cộng dồn tồn kho gối đầu",
			12, BanhTet.RED_100, "medium"
		)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(sub)

	# Phải: 2 chỉ số
	var stats: Container
	if sm:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not md:
			hb.alignment = BoxContainer.ALIGNMENT_END
		stats = hb
	else:
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 8)
		stats = g
	if not sm:
		# border-t border-white/20 pt-3
		var line := ColorRect.new()
		line.color = Color(1, 1, 1, 0.2)
		line.custom_minimum_size.y = 1
		box.add_child(line)
	box.add_child(stats)
	stats.add_child(_banner_stat("Tổng nhu cầu ngày", str(int(_balance["totalDemand"])), sm))
	stats.add_child(_banner_stat("Tổng đã làm", str(int(_balance["totalProduced"])), sm))
	return frame


func _banner_stat(cap: String, value: String, sm: bool) -> Control:
	var p: PanelContainer
	if sm:
		p = UiTheme.panel(StyleBoxEmpty.new())
	else:
		p = UiTheme.panel(UiTheme.box_style(Color(1, 1, 1, 0.1), Color.TRANSPARENT, 12, 12, 8))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var c := UiTheme.text(cap, 11, BanhTet.RED_100)
	var n := UiTheme.text(value, 20 if sm else 24, Color("#fde68a"), "extrabold")
	if sm:
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(c)
	v.add_child(n)
	return p


## --------------------------------------------------------- Cảnh báo thiếu
func _build_shortage(rows: Array) -> Control:
	var p := UiTheme.panel(UiTheme.box_style(BanhTet.RED_50, RED_300, 16, 20, 16))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var ic := UiTheme.icon("triangle-alert", 20, BanhTet.RED_600)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var t := UiTheme.text(
		"⚠️ Thiếu bánh so với nhu cầu giao trong ngày %s" % BanhTet.format_date_display(_selected_date),
		14, BanhTet.RED_800, "extrabold"
	)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	for row in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		line.add_child(UiTheme.text("•", 12, BanhTet.RED_700, "medium"))
		line.add_child(_product_img(str(row["icon"]), 20))
		var r := _rich(
			"%s: thiếu [b]%d[/b] cái (cần %d - có %d)" % [
				row["name"], absi(int(row["surplus"])), int(row["totalDemand"]), int(row["availableSupply"])
			], 12, BanhTet.RED_700, "medium"
		)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(r)
		v.add_child(line)
	return p


## ----------------------------------------------------------- Chọn ngày
func _build_date_buttons() -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for date in _dates:
		var active := date == _selected_date
		var b := Button.new()
		b.text = BanhTet.format_date_display(date)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 12)
		UiTheme.set_weight(b, "bold")
		var normal: StyleBoxFlat
		var hover: StyleBoxFlat
		var fg: Color
		if active:
			normal = UiTheme.box_style(BanhTet.RED_600, BanhTet.RED_600, 8, 12, 8)
			normal.shadow_color = Color(0, 0, 0, 0.08)
			normal.shadow_size = 2
			normal.shadow_offset = Vector2(0, 1)
			hover = normal
			fg = BanhTet.WHITE
		else:
			normal = UiTheme.box_style(BanhTet.WHITE, BanhTet.AMBER_200, 8, 12, 8)
			hover = UiTheme.box_style(BanhTet.AMBER_50, RED_300, 8, 12, 8)
			fg = BanhTet.AMBER_900
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, fg)
		b.pressed.connect(_select_date.bind(date))
		flow.add_child(b)
	return flow


func _select_date(date: String) -> void:
	_selected_date = date
	_produced_input.clear()
	_rebuild()


## -------------------------------------------------- Bảng Đối Soát Kho Bánh
func _build_balance_card(sm: bool) -> Control:
	var card := _card()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)

	# Header: gradient orange-50 -> white -> amber-50/40
	var head := _gradient_panel([ORANGE_50, BanhTet.WHITE, Color("#fffcf3")], 20, 16)
	col.add_child(head)
	var hr := HFlowContainer.new()
	hr.add_theme_constant_override("h_separation", 12)
	hr.add_theme_constant_override("v_separation", 8)
	head.add_child(hr)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# flex-wrap: trên điện thoại khối tiêu đề chiếm cả dòng, badge rớt xuống dưới
	tv.custom_minimum_size.x = 0 if sm else 280
	hr.add_child(tv)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	trow.add_child(UiTheme.icon("boxes", 16, ORANGE_700))
	var tt := UiTheme.text(
		"Bảng Đối Soát Kho Bánh — %s" % BanhTet.format_date_display(_selected_date),
		16, BanhTet.GRAY_900, "extrabold"
	)
	tt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(tt)
	tv.add_child(trow)
	var sub := UiTheme.text(
		"Khách lẻ + mối chợ = nhu cầu · Tồn gối đầu + sản lượng = nguồn cung",
		12, BanhTet.GRAY_500
	)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(sub)
	var badge: Control
	if bool(_balance["hasShortage"]):
		badge = _badge("⚠️ Thiếu %d bánh" % absi(int(_balance["totalSurplus"])), BanhTet.RED_100, RED_300, BanhTet.RED_800)
	else:
		badge = _badge("✅ Đủ nhu cầu", EMERALD_100, EMERALD_300, EMERALD_800)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(badge)
	col.add_child(_hline(BanhTet.GRAY_200))

	if sm:
		col.add_child(_build_table())
	else:
		col.add_child(_build_mobile_rows())

	# Footer xanh: carry over
	col.add_child(_hline(BanhTet.GRAY_200))
	var foot := UiTheme.panel(UiTheme.box_style(Color(BLUE_50, 0.6).blend(Color(1, 1, 1, 0.4)), Color.TRANSPARENT, 0, 20, 12))
	col.add_child(foot)
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 6)
	foot.add_child(fr)
	var ti := UiTheme.icon("trending-up", 14, BLUE_900)
	ti.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	fr.add_child(ti)
	var carry_total := 0
	for v in (_balance["carryOver"] as Dictionary).values():
		carry_total += int(v)
	var r := _rich(
		"Phần dư của ngày này (%d bánh) sẽ tự động chuyển thành [b]tồn kho gối đầu[/b] cho ngày kế tiếp." % carry_total,
		12, BLUE_900
	)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fr.add_child(r)
	return card


## Bảng (>= sm) - shadcn Table: header bg-gray-100, mỗi dòng border-b, p-2
func _build_table() -> Control:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var grid := GridContainer.new()
	grid.columns = 8
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	scroll.add_child(grid)

	var heads := ["Loại Bánh", "Khách Lẻ", "Mối Chợ", "Tổng Cầu", "Tồn Gối Đầu", "Đã Làm", "Có Thể Giao", "Dư / Thiếu"]
	for i in heads.size():
		var align := HORIZONTAL_ALIGNMENT_LEFT if i == 0 else (HORIZONTAL_ALIGNMENT_RIGHT if i == 7 else HORIZONTAL_ALIGNMENT_CENTER)
		var cell := _cell(UiTheme.text(heads[i], 14, BanhTet.GRAY_900, "medium"), BanhTet.GRAY_100, align, 40)
		if i == 0:
			cell.custom_minimum_size.x = 190
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)

	var sum_retail := 0
	var sum_wholesale := 0
	for row in _balance["rows"]:
		var surplus := int(row["surplus"])
		var bg := Color(BanhTet.RED_50, 0.6).blend(Color(1, 1, 1, 0.4)) if surplus < 0 else BanhTet.WHITE
		sum_retail += int(row["retailDemand"])
		sum_wholesale += int(row["wholesaleDemand"])

		var name_box := HBoxContainer.new()
		name_box.add_theme_constant_override("separation", 8)
		name_box.add_child(_product_img(str(row["icon"]), 20))
		# Viewport Godot hẹp hơn px thật (stretch) -> cho tên xuống dòng thay vì cuộn ngang
		var nl := UiTheme.text(str(row["name"]), 14, BanhTet.GRAY_800, "medium")
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size.x = 150
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_box.add_child(nl)
		name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nc := _cell(name_box, bg, HORIZONTAL_ALIGNMENT_LEFT)
		nc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(nc)
		grid.add_child(_num_cell(_dash(int(row["retailDemand"])), BanhTet.GRAY_700, "semibold", bg))
		grid.add_child(_num_cell(_dash(int(row["wholesaleDemand"])), EMERALD_700, "semibold", bg))
		grid.add_child(_num_cell(str(int(row["totalDemand"])), BanhTet.GRAY_900, "extrabold", bg))
		grid.add_child(_num_cell(_dash(int(row["openingStock"])), BLUE_700, "semibold", bg))
		grid.add_child(_num_cell(_dash(int(row["produced"])), ORANGE_700, "semibold", bg))
		grid.add_child(_num_cell(str(int(row["availableSupply"])), BanhTet.GRAY_900, "extrabold", bg))
		var sc := BanhTet.RED_700 if surplus < 0 else (EMERALD_700 if surplus > 0 else BanhTet.GRAY_400)
		grid.add_child(_num_cell(_signed(surplus), sc, "extrabold", bg, HORIZONTAL_ALIGNMENT_RIGHT))

	# tfoot TỔNG CỘNG
	var fbg := BanhTet.GRAY_50
	var total_supply := int(_balance["totalOpeningStock"]) + int(_balance["totalProduced"])
	var ts := int(_balance["totalSurplus"])
	var tc := _cell(UiTheme.text("TỔNG CỘNG", 14, BanhTet.GRAY_700, "extrabold"), fbg, HORIZONTAL_ALIGNMENT_LEFT)
	tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(tc)
	for v in [sum_retail, sum_wholesale, int(_balance["totalDemand"]), int(_balance["totalOpeningStock"]), int(_balance["totalProduced"]), total_supply]:
		grid.add_child(_num_cell(str(v), BanhTet.GRAY_900, "extrabold", fbg))
	grid.add_child(_num_cell(_signed(ts), BanhTet.RED_700 if ts < 0 else EMERALD_700, "extrabold", fbg, HORIZONTAL_ALIGNMENT_RIGHT))
	return scroll


## Danh sách thẻ (< sm) giống khối sm:hidden của web
func _build_mobile_rows() -> Control:
	var m := MarginContainer.new()
	for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(k, 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	for row in _balance["rows"]:
		var surplus := int(row["surplus"])
		var st := UiTheme.box_style(
			Color(BanhTet.RED_50, 0.5).blend(Color(1, 1, 1, 0.5)) if surplus < 0 else BanhTet.WHITE,
			BanhTet.RED_200 if surplus < 0 else BanhTet.GRAY_200, 12, 12, 12
		)
		var card := UiTheme.panel(st)
		v.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 8)
		card.add_child(cv)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		cv.add_child(top)
		top.add_child(_product_img(str(row["icon"]), 20))
		var nm := UiTheme.text(str(row["name"]), 12, BanhTet.GRAY_800, "bold")
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nm)
		var pill := UiTheme.panel(UiTheme.box_style(
			BanhTet.RED_100 if surplus < 0 else EMERALD_100, Color.TRANSPARENT, 999, 8, 4
		))
		pill.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		pill.add_child(UiTheme.text(_signed(surplus), 12, BanhTet.RED_700 if surplus < 0 else EMERALD_800, "extrabold"))
		top.add_child(pill)
		cv.add_child(_hline(Color(BanhTet.GRAY_200, 0.7)))
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 12)
		g.add_theme_constant_override("v_separation", 8)
		cv.add_child(g)
		var kv := [
			["Khách lẻ", str(int(row["retailDemand"])), BanhTet.GRAY_900, "semibold"],
			["Mối chợ", str(int(row["wholesaleDemand"])), BanhTet.GRAY_900, "semibold"],
			["Tổng cầu", str(int(row["totalDemand"])), BanhTet.GRAY_900, "bold"],
			["Tồn gối đầu", str(int(row["openingStock"])), BLUE_700, "semibold"],
			["Đã làm", str(int(row["produced"])), ORANGE_700, "semibold"],
			["Có thể giao", str(int(row["availableSupply"])), BanhTet.GRAY_900, "bold"],
		]
		for item in kv:
			var b := VBoxContainer.new()
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_constant_override("separation", 0)
			b.add_child(UiTheme.text(item[0], 12, BanhTet.GRAY_500))
			b.add_child(UiTheme.text(item[1], 12, item[2], item[3]))
			g.add_child(b)

	# Tổng: bg-gray-100 grid 2 cột
	var tot := UiTheme.panel(UiTheme.box_style(BanhTet.GRAY_100, Color.TRANSPARENT, 12, 12, 12))
	v.add_child(tot)
	var tg := GridContainer.new()
	tg.columns = 2
	tg.add_theme_constant_override("h_separation", 8)
	tg.add_theme_constant_override("v_separation", 8)
	tot.add_child(tg)
	var totals := [
		["Tổng cầu", int(_balance["totalDemand"])],
		["Tồn gối đầu", int(_balance["totalOpeningStock"])],
		["Đã làm", int(_balance["totalProduced"])],
		["Có thể giao", int(_balance["totalOpeningStock"]) + int(_balance["totalProduced"])],
	]
	for t in totals:
		var h := HBoxContainer.new()
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var a := UiTheme.text(t[0], 12, BanhTet.GRAY_900, "bold")
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(UiTheme.text(str(t[1]), 12, BanhTet.GRAY_900, "bold"))
		tg.add_child(h)
	return m


## ------------------------------------------------------- Số Lượng Ra Lò
func _build_production_card() -> Control:
	var card := _card()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)

	var head := _gradient_panel([ORANGE_50, BanhTet.WHITE], 16, 12)
	col.add_child(head)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	head.add_child(hr)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 2)
	hr.add_child(tv)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	trow.add_child(UiTheme.icon("chef-hat", 16, ORANGE_700))
	trow.add_child(UiTheme.text("Số Lượng Ra Lò", 14, BanhTet.GRAY_900, "extrabold"))
	tv.add_child(trow)
	tv.add_child(UiTheme.text(
		"%s — bếp đã nấu/gói xong" % BanhTet.format_date_display(_selected_date), 11, BanhTet.GRAY_500
	))
	var save := _solid_button("Lưu", "save", ORANGE_600, Color("#c2410c"), BanhTet.WHITE)
	save.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	save.pressed.connect(_on_save_production.bind(save))
	hr.add_child(save)
	col.add_child(_hline(BanhTet.GRAY_200))

	var body := MarginContainer.new()
	for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		body.add_theme_constant_override(k, 16)
	col.add_child(body)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	body.add_child(v)

	for product in store.products:
		var pid := str(product.get("id", ""))
		var rowp := UiTheme.panel(UiTheme.box_style(BanhTet.WHITE, BanhTet.GRAY_200, 8, 12, 8))
		v.add_child(rowp)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		rowp.add_child(h)
		h.add_child(_product_img(str(product.get("icon", "")), 20))
		var nm := UiTheme.text(str(product.get("name", "")), 12, BanhTet.GRAY_800, "semibold")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.clip_text = true
		nm.tooltip_text = str(product.get("name", ""))
		nm.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(nm)
		h.add_child(UiTheme.text("Tồn gối đầu: %d" % _opening_qty(pid), 11, BLUE_700, "semibold"))
		var edit := LineEdit.new()
		edit.placeholder_text = "0"
		var q := _produced_qty(pid)
		edit.text = str(q) if q > 0 else ""
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit.custom_minimum_size = Vector2(80, 32)
		edit.select_all_on_focus = true
		edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		UiTheme.set_weight(edit, "bold")
		edit.text_changed.connect(_on_produced_changed.bind(pid, edit))
		h.add_child(edit)

	var inv_btn := _solid_button("Chốt Tồn Kho Gối Đầu Cho Ngày Này", "save", BLUE_50, Color("#dbeafe"), BLUE_800, BLUE_300)
	inv_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_btn.pressed.connect(_on_save_inventory.bind(inv_btn))
	v.add_child(inv_btn)
	return card


func _on_produced_changed(text: String, pid: String, edit: LineEdit) -> void:
	var digits := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits != text:
		var caret := edit.caret_column
		edit.text = digits
		edit.caret_column = mini(caret, digits.length())
	_produced_input[pid] = maxi(0, digits.to_int())


func _on_save_production(btn: Button) -> void:
	if _produced_input.is_empty():
		_show_toast("Chưa nhập số lượng bánh nào đã nấu/gói xong!", "warning")
		return
	var merged := {}
	var saved = _production_today().get("items", {})
	if saved is Dictionary:
		merged = saved.duplicate()
	for pid in _produced_input:
		merged[pid] = int(_produced_input[pid])
	var items := {}
	for pid in merged:
		if int(merged[pid]) > 0:
			items[pid] = int(merged[pid])
	btn.disabled = true
	var ok := await store.save_production(_selected_date, items, "")
	if not is_instance_valid(btn):
		return
	btn.disabled = false
	if ok:
		_produced_input.clear()
		_rebuild()
		_show_toast("Đã lưu số lượng bánh ra lò!", "success")
	else:
		_show_toast("Không lưu được. Kiểm tra kết nối / quyền quản trị.", "error")


func _on_save_inventory(btn: Button) -> void:
	var items := {}
	for product in store.products:
		var pid := str(product.get("id", ""))
		items[pid] = _opening_qty(pid)
	btn.disabled = true
	var ok := await store.save_inventory(_selected_date, items)
	if not is_instance_valid(btn):
		return
	btn.disabled = false
	if ok:
		_rebuild()
		_show_toast("Đã chốt tồn kho gối đầu!", "success")
	else:
		_show_toast("Không lưu được. Kiểm tra kết nối / quyền quản trị.", "error")


## ---------------------------------------------- Tồn Kho Gối Đầu Các Ngày
func _build_chain_card() -> Control:
	var card := _card()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)

	var head := _gradient_panel([BLUE_50, BanhTet.WHITE], 16, 12)
	col.add_child(head)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	head.add_child(tv)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	trow.add_child(UiTheme.icon("boxes", 16, BLUE_700))
	trow.add_child(UiTheme.text("Tồn Kho Gối Đầu Các Ngày", 14, BanhTet.GRAY_900, "extrabold"))
	tv.add_child(trow)
	tv.add_child(UiTheme.text("Được cộng dồn tự động từ phần dư của ngày trước", 11, BanhTet.GRAY_500))
	col.add_child(_hline(BanhTet.GRAY_200))

	for i in _dates.size():
		var date: String = _dates[i]
		if i > 0:
			col.add_child(_hline(BanhTet.GRAY_100))
		var total := 0
		for v in (_chain.get(date, {}) as Dictionary).values():
			total += int(v)
		var active := date == _selected_date
		var b := Button.new()
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var n := UiTheme.box_style(BLUE_50 if active else BanhTet.WHITE, Color.TRANSPARENT, 0, 16, 8)
		var hv := UiTheme.box_style(BLUE_50 if active else BanhTet.GRAY_50, Color.TRANSPARENT, 0, 16, 8)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_select_date.bind(date))
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 16
		h.offset_right = -16
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := UiTheme.text(BanhTet.format_date_display(date), 12, BanhTet.GRAY_700, "semibold")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
		var r := UiTheme.text("%d bánh" % total, 12, BLUE_700 if total > 0 else BanhTet.GRAY_400, "extrabold")
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(r)
		b.add_child(h)
		b.custom_minimum_size.y = 34
		col.add_child(b)
	return card


## ================================================================ Helpers
func _card() -> PanelContainer:
	var st := UiTheme.box_style(BanhTet.WHITE, BanhTet.GRAY_200, 16)
	st.shadow_color = Color(0, 0, 0, 0.05)
	st.shadow_size = 2
	st.shadow_offset = Vector2(0, 1)
	var c := UiTheme.panel(st)
	c.clip_contents = true
	return c


func _gradient_panel(colors: Array, px: float, py: float) -> PanelContainer:
	var st := StyleBoxTexture.new()
	st.texture = _gradient(colors)
	st.content_margin_left = px
	st.content_margin_right = px
	st.content_margin_top = py
	st.content_margin_bottom = py
	return UiTheme.panel(st)


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


func _hline(c: Color) -> Control:
	var r := ColorRect.new()
	r.color = c
	r.custom_minimum_size.y = 1
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _badge(text: String, bg: Color, border: Color, fg: Color) -> Control:
	var p := UiTheme.panel(UiTheme.box_style(bg, border, 999, 10, 3))
	p.add_child(UiTheme.text(text, 12, fg, "extrabold"))
	return p


func _cell(content: Control, bg: Color, align: int, min_h: int = 0) -> PanelContainer:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = BanhTet.GRAY_200
	st.border_width_bottom = 1
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	var p := UiTheme.panel(st)
	if min_h > 0:
		p.custom_minimum_size.y = min_h
	if content is Label:
		(content as Label).horizontal_alignment = align
		(content as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(content)
	return p


func _num_cell(text: String, color: Color, weight: String, bg: Color, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> PanelContainer:
	var c := _cell(UiTheme.text(text, 14, color, weight), bg, align)
	c.custom_minimum_size.x = 0
	return c


func _dash(v: int) -> String:
	return str(v) if v != 0 else "—"


func _signed(v: int) -> String:
	return "+%d" % v if v > 0 else str(v)


func _rich(bb: String, size: int, color: Color, weight: String = "regular") -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_override("normal_font", UiTheme.font(weight))
	r.add_theme_font_override("bold_font", UiTheme.font("bold"))
	r.add_theme_color_override("default_color", color)
	r.text = bb
	return r


func _product_img(icon_file: String, px: int) -> TextureRect:
	var t := TextureRect.new()
	var path := "res://assets/anh/%s" % icon_file.get_file()
	if icon_file != "" and ResourceLoader.exists(path):
		t.texture = load(path)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _solid_button(label_text: String, icon_name: String, bg: Color, bg_hover: Color, fg: Color, border: Color = Color.TRANSPARENT) -> Button:
	var b := Button.new()
	b.text = label_text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 13)
	UiTheme.set_weight(b, "bold")
	b.add_theme_stylebox_override("normal", UiTheme.box_style(bg, border, 8, 12, 6))
	b.add_theme_stylebox_override("hover", UiTheme.box_style(bg_hover, border, 8, 12, 6))
	b.add_theme_stylebox_override("pressed", UiTheme.box_style(bg_hover, border, 8, 12, 6))
	b.add_theme_stylebox_override("disabled", UiTheme.box_style(bg.lerp(BanhTet.WHITE, 0.4), border, 8, 12, 6))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", fg.lerp(BanhTet.WHITE, 0.4))
	if icon_name != "":
		UiTheme.set_button_icon(b, icon_name, 14, fg)
		b.add_theme_constant_override("h_separation", 6)
	return b


## Toast nhỏ giống sonner (góc dưới)
func _build_toast() -> void:
	_toast = UiTheme.panel(UiTheme.box_style(BanhTet.WHITE, BanhTet.GRAY_200, 8, 16, 12))
	_toast.top_level = true
	_toast.visible = false
	_toast.z_index = 100
	_toast_label = UiTheme.text("", 13, BanhTet.GRAY_900, "medium")
	_toast.add_child(_toast_label)
	add_child(_toast)


func _show_toast(message: String, kind: String) -> void:
	if not is_instance_valid(_toast):
		return
	var color := BanhTet.GRAY_900
	var border := BanhTet.GRAY_200
	var bg := BanhTet.WHITE
	match kind:
		"success":
			color = EMERALD_800; border = EMERALD_300; bg = Color("#ecfdf5")
		"warning":
			color = BanhTet.AMBER_800; border = BanhTet.AMBER_300; bg = BanhTet.AMBER_50
		"error":
			color = BanhTet.RED_800; border = RED_300; bg = BanhTet.RED_50
	var st := UiTheme.box_style(bg, border, 8, 16, 12)
	st.shadow_color = Color(0, 0, 0, 0.12)
	st.shadow_size = 8
	st.shadow_offset = Vector2(0, 4)
	_toast.add_theme_stylebox_override("panel", st)
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", color)
	_toast.visible = true
	_toast.reset_size()
	var vp := get_viewport_rect().size
	var s := _toast.get_combined_minimum_size()
	_toast.position = Vector2((vp.x - s.x) / 2.0, vp.y - s.y - (24 if _width >= UiTheme.BP_SM else 90))
	_toast_timer.start(3.0)
