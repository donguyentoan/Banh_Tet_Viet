extends Control

## Scene chính: bố cục giống web app (shadcn/ui):
##   TetBanner -> AppHeader -> TabNav -> nội dung -> AppFooter
##
## Web dùng AppShell với thứ tự: TetBanner, AppHeader, TabNav, main, AppFooter.

const SCREEN_ORDERS := "orders"
const SCREEN_CREATE := "create"
const SCREEN_WHOLESALE := "wholesale"
const SCREEN_ANALYTICS := "analytics"

var store: BakeryStore
var printer: Node

var _content: MarginContainer
var _tab_bar: HBoxContainer
var _current_screen := SCREEN_ORDERS
var _tab_buttons := {}
var _countdown_label: Label
var _countdown_timer: Timer
var _admin_button: Button
var _root: VBoxContainer
var _tab_nav: Control
var _banner: Control
var _banner_left: Control
var _banner_right: Control
var _header_badge: Control
var _header_subtitle: Control
var _header_title: Label
var _header_actions: HBoxContainer
var _logo_frame: Control
var _is_wide := true
var _last_layout := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_add_emoji_font_fallback()
	# Theme chung gắn ở cửa sổ gốc: mọi ô nhập / select / popup (kể cả trong
	# hộp thoại) có style + hành vi giống input của web
	get_tree().root.theme = UiTheme.build_app_theme()
	# Mọi AcceptDialog trong app (đăng nhập, xác nhận, chi tiết...) tự nhận theme Tết
	get_tree().node_added.connect(_on_node_added)

	# Nền app + dot pattern giống web
	add_child(UiTheme.make_dotted_background())

	store = BakeryStore.new()
	add_child(store)
	store.session_checked.connect(_on_session_checked)

	printer = load("res://script/bluetooth_printer.gd").new()
	add_child(printer)

	_build_layout()
	_show_screen(SCREEN_ORDERS)

	# Kiểm tra phiên quản trị như web app: nếu chưa đăng nhập thì mở hộp
	# thoại nhập mật khẩu ngay khi app vừa mở.
	_check_session_on_start()


func _on_node_added(node: Node) -> void:
	if node is LineEdit or node is TextEdit or node is OptionButton:
		UiTheme.apply_web_input_behavior(node)
	if node is AcceptDialog:
		# Đợi dialog thêm xong các nút (add_cancel_button...) rồi mới style
		UiTheme.style_dialog.call_deferred(node)


## Giống trình duyệt: bấm ra ngoài ô nhập thì ô đó mất focus (blur),
## trên điện thoại bàn phím ảo cũng tự đóng.
func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not (focused is LineEdit or focused is TextEdit):
		return
	if not focused.get_global_rect().has_point(event.position):
		focused.release_focus()


## Trình duyệt (bản web) không có font emoji hệ thống như Android ->
## gắn Noto Color Emoji làm font dự phòng để icon hiển thị giống app.
func _add_emoji_font_fallback() -> void:
	# UiTheme.font() gắn Noto Color Emoji làm fallback cho mọi độ đậm
	for w in ["regular", "medium", "semibold", "bold", "extrabold"]:
		UiTheme.font(w)


## Kiểm tra phiên quản trị lúc khởi động.
## Nếu chưa đăng nhập -> mở hộp thoại nhập mật khẩu (giống web app).
func _check_session_on_start() -> void:
	# Chờ vài frame để UI dựng xong trước khi hiện dialog
	await get_tree().process_frame
	await get_tree().process_frame

	var authenticated := await store.check_admin_session()
	if authenticated:
		_set_admin_state(true)
		await store.refresh_all()
		_show_screen(_current_screen)
	else:
		_show_login_dialog()


func _on_session_checked(authenticated: bool) -> void:
	if authenticated:
		_set_admin_state(true)


func _build_layout() -> void:
	var root := VBoxContainer.new()
	_root = root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# TetBanner (gradient đỏ -> hổ phách, đếm ngược Tết)
	_banner = _build_tet_banner()
	root.add_child(_banner)

	# AppHeader
	root.add_child(_build_header())

	# TabNav (desktop: dưới header; mobile: cố định đáy màn hình như web)
	_tab_nav = _build_tab_nav()
	root.add_child(_tab_nav)

	# Nội dung
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 0)
	scroll.add_child(page)

	_content = MarginContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_content)
	page.add_child(_build_footer())

	resized.connect(_apply_responsive)
	_apply_responsive.call_deferred()


## Responsive giống Tailwind: < sm (640) là bố cục điện thoại, >= sm là desktop.
func _apply_responsive() -> void:
	var w := size.x
	var layout := "lg" if w >= UiTheme.BP_LG else ("md" if w >= UiTheme.BP_MD else ("sm" if w >= UiTheme.BP_SM else "xs"))
	if layout == _last_layout:
		return
	_last_layout = layout
	_is_wide = w >= UiTheme.BP_SM

	# Banner: ẩn trên điện thoại; 2 câu chúc 2 bên chỉ hiện từ md
	_banner.visible = _is_wide
	_banner_left.visible = w >= UiTheme.BP_MD
	_banner_right.visible = w >= UiTheme.BP_MD

	# Header: badge, mô tả, nhóm nút chỉ hiện từ sm
	_header_badge.visible = _is_wide
	_header_subtitle.visible = _is_wide
	_header_actions.visible = _is_wide
	_header_title.add_theme_font_size_override("font_size", 24 if w >= UiTheme.BP_MD else (20 if _is_wide else 14))
	# Tiêu đề chỉ giãn hết chỗ trên điện thoại; desktop để badge nằm sát tiêu đề
	_header_title.size_flags_horizontal = Control.SIZE_FILL if _is_wide else Control.SIZE_EXPAND_FILL
	_header_title.clip_text = not _is_wide
	# Ellipsis làm min-width của Label = 0 -> desktop bị mất chữ; chỉ bật trên điện thoại
	_header_title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if _is_wide else TextServer.OVERRUN_TRIM_ELLIPSIS
	_logo_frame.custom_minimum_size = Vector2(56, 56) if _is_wide else Vector2(48, 48)
	var hs := (_logo_frame.get_parent().get_parent() as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	hs.content_margin_left = 24 if _is_wide else 12
	hs.content_margin_right = 24 if _is_wide else 12
	hs.content_margin_top = 12 if _is_wide else 10
	hs.content_margin_bottom = 12 if _is_wide else 10

	# Tab nav: desktop ngay dưới header, điện thoại ở đáy
	_root.move_child(_tab_nav, 2 if _is_wide else _root.get_child_count() - 1)
	_update_tab_styles()

	# Lề nội dung: px-3 / sm:px-6 / lg:px-8, py-6
	var pad := 32 if w >= UiTheme.BP_LG else (24 if _is_wide else 12)
	_content.add_theme_constant_override("margin_left", pad)
	_content.add_theme_constant_override("margin_right", pad)
	_content.add_theme_constant_override("margin_top", 24 if _is_wide else 14)
	_content.add_theme_constant_override("margin_bottom", 24)


## ---------------------------------------------------------------- TetBanner
## Đỏ -> hổ phách, chữ trắng, có đếm ngược tới Mùng 1 Tết
func _build_tet_banner() -> Control:
	# bg-gradient-to-r from-red-800 via-red-600 to-amber-600
	var panel := PanelContainer.new()
	var style := StyleBoxTexture.new()
	style.texture = _gradient_texture([BanhTet.RED_800, BanhTet.RED_600, BanhTet.AMBER_600])
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var left := UiTheme.text("🌸 Chúc Mừng Năm Mới 2027 - Đinh Mùi 🌸", 14, BanhTet.WHITE, "medium")
	_banner_left = left
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(left)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	row.add_child(mid)

	mid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(UiTheme.icon("clock", 16, BanhTet.WHITE))
	mid.add_child(UiTheme.text("Đếm ngược đến Tết Nguyên Đán 2027 (Mùng 1 Tết):", 14, BanhTet.WHITE, "medium"))

	_countdown_label = UiTheme.text("-- Ngày -- Giờ -- Phút", 14, Color("#fcd34d"), "bold")
	var chip := PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(0, 0, 0, 0.2)
	chip_style.set_corner_radius_all(4)
	chip_style.content_margin_left = 8
	chip_style.content_margin_right = 8
	chip_style.content_margin_top = 2
	chip_style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", chip_style)
	chip.add_child(_countdown_label)
	mid.add_child(chip)

	var right := UiTheme.text("🧧 Vạn Sự Như Ý - Phát Tài Phát Lộc 🧧", 14, BanhTet.WHITE, "medium")
	_banner_right = right
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(right)

	# Cập nhật đếm ngược mỗi phút
	_countdown_timer = Timer.new()
	_countdown_timer.wait_time = 60.0
	_countdown_timer.autostart = true
	_countdown_timer.timeout.connect(_update_countdown)
	add_child(_countdown_timer)
	_update_countdown()

	return panel


func _update_countdown() -> void:
	if _countdown_label == null:
		return
	var days_left := _days_until_tet()
	if days_left < 0:
		_countdown_label.text = "CHÚC MỪNG NĂM MỚI 2027!"
		return

	# Tính giờ và phút còn lại trong ngày
	var now_dict := Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system())
	var seconds_of_day := int(now_dict["hour"]) * 3600 + int(now_dict["minute"]) * 60 + int(now_dict["second"])
	var hours_left := (86400 - seconds_of_day) / 3600
	var minutes_left := ((86400 - seconds_of_day) % 3600) / 60

	_countdown_label.text = "%d Ngày %d Giờ %d Phút" % [days_left, hours_left, minutes_left]


## Số ngày còn lại tới Mùng 1 Tết (theo TET_DATE_ISO trong banh_tet.gd)
func _days_until_tet() -> int:
	var parts := BanhTet.TET_DATE_ISO.split("-")
	if parts.size() != 3:
		return 0
	# Dùng Time.get_datetime_dict_from_unix_time() để lấy ngày hiện tại,
	# rồi tính chênh lệch theo ngày (Time.parse_datetime không có trong 4.3).
	var today := Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system())
	var tet_year := int(parts[0])
	var tet_month := int(parts[1])
	var tet_day := int(parts[2])

	# Chuyển ngày Tết thành số ngày Julian để so sánh
	var tet_julian := _to_julian(tet_year, tet_month, tet_day)
	var now_julian := _to_julian(today["year"], today["month"], today["day"])
	return tet_julian - now_julian


## Chuyển ngày dương lịch sang số ngày Julian (để tính chênh lệch ngày)
func _to_julian(year: int, month: int, day: int) -> int:
	var a := (14 - month) / 12
	var y := year + 4800 - a
	var m := month + 12 * a - 3
	return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045


## ---------------------------------------------------------------- AppHeader
## Giống app-header.tsx: logo + tiêu đề + badge | Xuất Excel, Danh Sách,
## Tạo Đơn Hàng Mới | Quản trị / Thoát quản trị
func _build_header() -> Control:
	var header := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.WHITE
	style.border_color = BanhTet.AMBER_200
	style.border_width_bottom = 1
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.05)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 1)
	header.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	header.add_child(row)

	# Logo: khung bo góc viền vàng, ảnh de.jpg như web
	var logo_style := UiTheme.box_style(BanhTet.RED_700, BanhTet.AMBER_300, 12, 0, 0, 2)
	logo_style.shadow_color = Color(0, 0, 0, 0.15)
	logo_style.shadow_size = 4
	logo_style.shadow_offset = Vector2(0, 2)
	var logo_frame := UiTheme.panel(logo_style)
	logo_frame.custom_minimum_size = Vector2(56, 56)
	logo_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo_frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_logo_frame = logo_frame
	var logo := TextureRect.new()
	logo.texture = load("res://assets/anh/logo.jpg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	logo_frame.add_child(logo)
	row.add_child(logo_frame)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_box.add_theme_constant_override("separation", 0)
	row.add_child(title_box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_box.add_child(title_row)

	_header_title = UiTheme.text("BÁNH TẾT VIỆT 2027", 24, BanhTet.RED_700, "extrabold")
	_header_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_header_title.clip_text = true
	_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_header_title)

	var badge := UiTheme.panel(UiTheme.box_style(BanhTet.AMBER_100, BanhTet.AMBER_300, 999, 8, 2))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(UiTheme.text("Xuân Đinh Mùi", 12, BanhTet.AMBER_800, "semibold"))
	title_row.add_child(badge)
	_header_badge = badge

	_header_subtitle = UiTheme.text(
		"Hệ thống quản lý đặt Bánh Chưng & Bánh Tét gia truyền", 12, BanhTet.GRAY_500, "medium"
	)
	title_box.add_child(_header_subtitle)

	# Nhóm nút giữa (chỉ hiện trên màn rộng)
	_header_actions = HBoxContainer.new()
	_header_actions.add_theme_constant_override("separation", 12)
	_header_actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_header_actions)

	var export_btn := UiTheme.tw_button("Xuất Excel", "file-spreadsheet", "amber", 14, BanhTet.GREEN_600)
	export_btn.pressed.connect(_on_export_pressed)
	_header_actions.add_child(export_btn)

	var list_btn := UiTheme.tw_button("Danh Sách", "layout-list", "amber", 14, BanhTet.GREEN_600)
	list_btn.pressed.connect(_show_screen.bind(SCREEN_ORDERS))
	_header_actions.add_child(list_btn)

	var new_btn := UiTheme.tw_button("Tạo Đơn Hàng Mới", "circle-plus", "primary", 14, Color("#fcd34d"))
	new_btn.pressed.connect(_show_screen.bind(SCREEN_CREATE))
	_header_actions.add_child(new_btn)

	var spacer := Control.new()
	spacer.custom_minimum_size.x = 8
	_header_actions.add_child(spacer)

	_admin_button = UiTheme.tw_button("Quản trị", "lock-keyhole", "outline-red", 13)
	_admin_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_admin_button.pressed.connect(_on_admin_pressed)
	row.add_child(_admin_button)

	return header


## Cập nhật nút quản trị theo trạng thái đăng nhập (giống web)
func _set_admin_state(is_admin: bool) -> void:
	var fresh := UiTheme.tw_button(
		"Thoát quản trị" if is_admin else "Quản trị",
		"log-out" if is_admin else "lock-keyhole",
		"outline-amber" if is_admin else "outline-red", 13
	)
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		_admin_button.add_theme_stylebox_override(key, fresh.get_theme_stylebox(key))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_admin_button.add_theme_color_override(key, fresh.get_theme_color(key))
	_admin_button.text = fresh.text
	_admin_button.icon = fresh.icon
	_admin_button.set_meta("is_admin", is_admin)
	fresh.free()


func _on_admin_pressed() -> void:
	if bool(_admin_button.get_meta("is_admin", false)):
		await store.logout()
		_set_admin_state(false)
	else:
		_show_login_dialog()


## Xuất CSV giống web (exportToCSV): web tải file, Android lưu vào user://
func _on_export_pressed() -> void:
	var lines := PackedStringArray(["Mã đơn,Khách hàng,SĐT,Địa chỉ,Ngày giao,Giờ giao,Tổng tiền,Đặt cọc,Trạng thái,Ghi chú"])
	for o in store.orders:
		var cells := PackedStringArray()
		for k in ["id", "customerName", "phone", "address", "deliveryDate", "deliveryTime", "totalAmount", "deposit", "status", "notes"]:
			cells.append('"%s"' % str(o.get(k, "")).replace('"', '""'))
		lines.append(",".join(cells))
	var csv := "\ufeff" + "\n".join(lines)
	var file_name := "don-hang-banh-tet-2027.csv"
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(csv.to_utf8_buffer(), file_name, "text/csv")
	else:
		var f := FileAccess.open("user://" + file_name, FileAccess.WRITE)
		if f:
			f.store_string(csv)


## Gradient ngang cho StyleBoxTexture
func _gradient_texture(colors: Array) -> GradientTexture2D:
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


## ------------------------------------------------------------------ TabNav
## Giống tab-nav.tsx: desktop = icon + nhãn dài nằm ngang, gạch đỏ dưới tab
## đang chọn; điện thoại = icon trên, nhãn ngắn dưới, thanh cố định ở đáy.
const TABS := [
	{"id": "orders", "icon": "clipboard-list", "label": "Đơn Hàng & Thống Kê", "short": "Đơn Hàng"},
	{"id": "create", "icon": "shopping-cart", "label": "Tạo & Chỉnh Sửa Đơn", "short": "Tạo Đơn"},
	{"id": "wholesale", "icon": "store", "label": "Bỏ Bánh Cho Mối Chợ", "short": "Mối Chợ"},
	{"id": "analytics", "icon": "factory", "label": "Thống Kê & Cân Đối Kho", "short": "Cân Đối Kho"},
]


func _build_tab_nav() -> Control:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.WHITE
	style.border_color = BanhTet.AMBER_200
	style.border_width_bottom = 1
	style.shadow_color = Color(0, 0, 0, 0.05)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	bar.add_theme_stylebox_override("panel", style)

	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 0)
	bar.add_child(_tab_bar)

	for tab in TABS:
		var btn := Button.new()
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.set_meta("tab", tab)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		UiTheme.set_weight(btn, "bold")
		btn.pressed.connect(_on_tab_pressed.bind(str(tab["id"])))
		_tab_bar.add_child(btn)
		_tab_buttons[str(tab["id"])] = btn

	return bar


func _on_tab_pressed(screen_id: String) -> void:
	_show_screen(screen_id)


func _show_screen(screen_id: String) -> void:
	_current_screen = screen_id

	for child in _content.get_children():
		child.queue_free()

	match screen_id:
		SCREEN_ORDERS:
			_content.add_child(_build_orders_screen())
		SCREEN_CREATE:
			_content.add_child(_build_create_screen())
		SCREEN_WHOLESALE:
			_content.add_child(_build_wholesale_screen())
		SCREEN_ANALYTICS:
			_content.add_child(_build_analytics_screen())

	_update_tab_styles()


func _update_tab_styles() -> void:
	var bar_style := _tab_nav.get_theme_stylebox("panel") as StyleBoxFlat
	bar_style.border_width_bottom = 1 if _is_wide else 0
	bar_style.border_width_top = 0 if _is_wide else 1
	bar_style.shadow_offset = Vector2(0, 1) if _is_wide else Vector2(0, -4)
	bar_style.shadow_size = 2 if _is_wide else 8
	bar_style.content_margin_left = 24 if _is_wide else 4
	bar_style.content_margin_right = 24 if _is_wide else 4
	_tab_bar.alignment = BoxContainer.ALIGNMENT_BEGIN

	for id in _tab_buttons:
		var btn: Button = _tab_buttons[id]
		var tab: Dictionary = btn.get_meta("tab")
		var active: bool = id == _current_screen
		var fg := BanhTet.RED_700 if active else BanhTet.GRAY_500
		btn.text = str(tab["label"]) if _is_wide else str(tab["short"])
		btn.add_theme_font_size_override("font_size", 14 if _is_wide else 10)
		btn.icon = UiTheme.icon_texture(str(tab["icon"]), 16, BanhTet.RED_600 if active else BanhTet.GRAY_400)
		btn.add_theme_constant_override("icon_max_width", 16)
		btn.add_theme_constant_override("h_separation", 8)
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER if _is_wide else VERTICAL_ALIGNMENT_TOP
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT if _is_wide else HORIZONTAL_ALIGNMENT_CENTER
		btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if _is_wide else Control.SIZE_EXPAND_FILL

		# Gạch chân 2px đỏ cho tab đang chọn (border-b-2)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color.TRANSPARENT
		normal.content_margin_left = 16 if _is_wide else 2
		normal.content_margin_right = 16 if _is_wide else 2
		normal.content_margin_top = 12 if _is_wide else 8
		normal.content_margin_bottom = 12 if _is_wide else 8
		normal.border_width_bottom = 2
		normal.border_color = BanhTet.RED_600 if active else Color.TRANSPARENT
		var hover := normal.duplicate() as StyleBoxFlat
		if not active:
			hover.border_color = BanhTet.AMBER_300
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", normal)
		btn.add_theme_color_override("font_color", fg)
		btn.add_theme_color_override("font_focus_color", fg)
		btn.add_theme_color_override("font_pressed_color", fg)
		btn.add_theme_color_override("font_hover_color", BanhTet.RED_700 if active else BanhTet.AMBER_700)


func _on_refresh_pressed() -> void:
	if not store.is_online:
		_show_login_dialog()
		return
	await store.refresh_all()
	_show_screen(_current_screen)


func _build_orders_screen() -> Control:
	var script := load("res://scene/tinh_nang/OrdersScreen.gd")
	var screen = script.new()
	screen.store = store
	screen.printer = printer
	screen.open_create.connect(_on_open_create)
	return screen


## Từ trang Đơn Hàng: mở màn Tạo Đơn kèm dữ liệu (Tạo Đơn Nhanh / Sửa đơn)
func _on_open_create(kind: String, data: Variant) -> void:
	_show_screen(SCREEN_CREATE)
	var screen = _content.get_child(_content.get_child_count() - 1)
	if kind == "parse":
		screen.apply_parsed(str(data))
	elif kind == "edit":
		screen.load_order(data)


func _build_create_screen() -> Control:
	var script := load("res://scene/tinh_nang/CreateOrderScreen.gd")
	var screen = script.new()
	screen.store = store
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	return screen


func _build_wholesale_screen() -> Control:
	var script := load("res://scene/tinh_nang/WholesaleScreen.gd")
	var screen = script.new()
	screen.store = store
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	return screen


func _build_analytics_screen() -> Control:
	var script := load("res://scene/tinh_nang/AnalyticsScreen.gd")
	var screen = script.new()
	screen.store = store
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	return screen


## ------------------------------------------------------- Dialog đăng nhập
## Giống app-header.tsx: DialogTitle + DialogDescription, Input password,
## lỗi đỏ, nút "Đăng nhập" full width bg-red-700 (disabled khi chưa nhập).
var _login_dialog: WebDialog


func _show_login_dialog() -> void:
	if is_instance_valid(_login_dialog):
		return
	var d := WebDialog.open(self, "Đăng nhập quản trị", "Đăng nhập để tạo, sửa hoặc xoá dữ liệu trên hệ thống.")
	_login_dialog = d

	var password := UiTheme.line_edit("Mật khẩu quản trị")
	password.secret = true
	password.custom_minimum_size.y = 32
	d.body.add_child(password)

	var status := UiTheme.text("", 14, BanhTet.RED_700, "medium")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.visible = false
	d.body.add_child(status)

	var submit := WebDialog.button("Đăng nhập", "", BanhTet.RED_700, BanhTet.WHITE)
	submit.disabled = true
	d.body.add_child(submit)

	password.text_changed.connect(func(t: String): submit.disabled = t.is_empty())
	password.text_submitted.connect(func(_t: String):
		if not submit.disabled:
			_on_login_submit(d, password, status, submit))
	submit.pressed.connect(_on_login_submit.bind(d, password, status, submit))
	password.grab_focus.call_deferred()


func _on_login_submit(d: WebDialog, password: LineEdit, status: Label, submit: Button) -> void:
	submit.disabled = true
	submit.text = "Đang xác thực…"
	status.visible = false
	var ok := await store.login(password.text)
	# Dialog có thể đã bị đóng (X / Esc) trong lúc chờ API
	if not is_instance_valid(submit) or not is_instance_valid(password):
		if ok:
			_set_admin_state(true)
			_show_screen(_current_screen)
		return
	submit.text = "Đăng nhập"
	if ok:
		password.text = ""
		d.close()
		_set_admin_state(true)
		_show_screen(_current_screen)
	else:
		status.text = "Mật khẩu không đúng"
		status.visible = true
		submit.disabled = password.text.is_empty()
		password.grab_focus()


## ------------------------------------------------------------------ Footer
## app-footer.tsx: border-t-4 amber-400, gradient red-800 -> red-700 -> amber-700
func _build_footer() -> Control:
	var p := PanelContainer.new()
	var st := StyleBoxTexture.new()
	st.texture = _gradient_texture([BanhTet.RED_800, BanhTet.RED_700, BanhTet.AMBER_700])
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 24
	st.content_margin_bottom = 24
	p.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var l1 := UiTheme.text("🌸 HỆ THỐNG QUẢN LÝ ĐẶT BÁNH CHƯNG & BÁNH TÉT TRUYỀN THỐNG 🌸", 14, Color("#fcd34d"), "bold")
	var l2 := UiTheme.text("Đảm bảo bánh thơm ngon - Đậm đà hương vị Tết Việt - Giao hàng đúng hẹn 27-29 Tết", 12, BanhTet.RED_100)
	var l3 := UiTheme.text("© 2027 Tết Đinh Mùi", 11, Color(BanhTet.RED_200, 0.8))
	for l in [l1, l2, l3]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	# mt-6 sm:mt-8 + border-t-4 border-amber-400
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	wrap.add_child(gap)
	var top := ColorRect.new()
	top.color = BanhTet.AMBER_400
	top.custom_minimum_size.y = 4
	wrap.add_child(top)
	wrap.add_child(p)
	return wrap
