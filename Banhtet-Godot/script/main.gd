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


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

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


## Kiểm tra phiên quản trị lúc khởi động.
## Nếu chưa đăng nhập -> mở hộp thoại nhập mật khẩu (giống web app).
func _check_session_on_start() -> void:
	# Chờ vài frame để UI dựng xong trước khi hiện dialog
	await get_tree().process_frame
	await get_tree().process_frame

	var authenticated := await store.check_admin_session()
	if authenticated:
		_admin_button.text = "👤 Thoát"
		await store.refresh_all()
		_show_screen(_current_screen)
	else:
		_show_login_dialog()


func _on_session_checked(authenticated: bool) -> void:
	if authenticated:
		_admin_button.text = "👤 Thoát"


func _build_layout() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# TetBanner (gradient đỏ -> hổ phách, đếm ngược Tết)
	root.add_child(_build_tet_banner())

	# AppHeader
	root.add_child(_build_header())

	# TabNav
	root.add_child(_build_tab_nav())

	# Nội dung
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_content = MarginContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("margin_left", 12)
	_content.add_theme_constant_override("margin_right", 12)
	_content.add_theme_constant_override("margin_top", 14)
	_content.add_theme_constant_override("margin_bottom", 14)
	scroll.add_child(_content)


## ---------------------------------------------------------------- TetBanner
## Đỏ -> hổ phách, chữ trắng, có đếm ngược tới Mùng 1 Tết
func _build_tet_banner() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.RED_700
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	style.shadow_color = Color(0, 0, 0, 0.12)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var left := UiTheme.label("🌸 Chúc Mừng Năm Mới 2027 - Đinh Mùi 🌸", UiTheme.FONT_SIZE_SMALL, BanhTet.WHITE)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(left)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	row.add_child(mid)

	mid.add_child(UiTheme.label("🕐", UiTheme.FONT_SIZE_SMALL, BanhTet.AMBER_400))
	mid.add_child(UiTheme.label("Đếm ngược đến Tết:", UiTheme.FONT_SIZE_SMALL, BanhTet.WHITE))

	_countdown_label = UiTheme.label("-- Ngày -- Giờ -- Phút", UiTheme.FONT_SIZE_SMALL, BanhTet.AMBER_400)
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

	var right := UiTheme.label("🧧 Vạn Sự Như Ý 🧧", UiTheme.FONT_SIZE_SMALL, BanhTet.WHITE)
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
func _build_header() -> Control:
	var header := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.WHITE
	style.border_color = BanhTet.AMBER_200
	style.border_width_bottom = 1
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.05)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 1)
	header.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	header.add_child(row)

	# Logo
	var logo := TextureRect.new()
	logo.texture = load("res://assets/icon.svg")
	logo.custom_minimum_size = Vector2(48, 48)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(logo)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 1)
	row.add_child(title_box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	title_box.add_child(title_row)

	var title := UiTheme.label("BÁNH TẾT VIỆT 2027", UiTheme.FONT_SIZE_TITLE, BanhTet.RED_700)
	title_row.add_child(title)

	var badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = BanhTet.AMBER_100
	badge_style.border_color = BanhTet.AMBER_300
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(999)
	badge_style.content_margin_left = 8
	badge_style.content_margin_right = 8
	badge_style.content_margin_top = 2
	badge_style.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.add_child(UiTheme.label("Xuân Đinh Mùi", UiTheme.FONT_SIZE_TINY, BanhTet.AMBER_800))
	title_row.add_child(badge)

	title_box.add_child(UiTheme.label(
		"Hệ thống quản lý đặt Bánh Chưng & Bánh Tét gia truyền",
		UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_500
	))

	# Nút quản trị + đồng bộ
	var sync_btn := UiTheme.button("⟳", "outline", 18)
	sync_btn.custom_minimum_size = Vector2(42, 42)
	sync_btn.pressed.connect(_on_refresh_pressed)
	row.add_child(sync_btn)

	_admin_button = UiTheme.button("🔒 Quản trị", "outline", UiTheme.FONT_SIZE_SMALL)
	_admin_button.pressed.connect(_show_login_dialog)
	row.add_child(_admin_button)

	return header


## ------------------------------------------------------------------ TabNav
func _build_tab_nav() -> Control:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.WHITE
	style.border_color = BanhTet.AMBER_200
	style.border_width_bottom = 1
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	bar.add_theme_stylebox_override("panel", style)

	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 0)
	bar.add_child(_tab_bar)

	# Nhãn + icon giống web (ClipboardList, ShoppingCart, Store, Factory)
	var tabs := [
		{"id": SCREEN_ORDERS, "icon": "📋", "label": "Đơn Hàng"},
		{"id": SCREEN_CREATE, "icon": "🛒", "label": "Tạo Đơn"},
		{"id": SCREEN_WHOLESALE, "icon": "🏪", "label": "Mối Chợ"},
		{"id": SCREEN_ANALYTICS, "icon": "🏭", "label": "Cân Đối"},
	]

	for tab in tabs:
		var btn := Button.new()
		btn.text = "%s\n%s" % [tab["icon"], tab["label"]]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 10)
		# Style rỗng cho mọi trạng thái - nền do PanelContainer cha lo.
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		# Màu chữ đầy đủ cho từng trạng thái (nếu thiếu, hover sẽ mất chữ).
		btn.add_theme_color_override("font_color", BanhTet.GRAY_500)
		btn.add_theme_color_override("font_hover_color", BanhTet.RED_700)
		btn.add_theme_color_override("font_pressed_color", BanhTet.RED_800)
		btn.add_theme_color_override("font_focus_color", BanhTet.RED_700)
		btn.add_theme_color_override("font_disabled_color", BanhTet.GRAY_300)
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
	for id in _tab_buttons:
		var btn: Button = _tab_buttons[id]
		if id == _current_screen:
			btn.add_theme_color_override("font_color", BanhTet.RED_700)
		else:
			btn.add_theme_color_override("font_color", BanhTet.GRAY_500)


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
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	return screen


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
func _show_login_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Đăng nhập quản trị"
	dialog.dialog_hide_on_ok = false
	dialog.ok_button_text = "Đăng nhập"
	dialog.cancel_button_text = "Huỷ"

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var info := UiTheme.label(
		"Đăng nhập để tạo, sửa hoặc xoá dữ liệu trên hệ thống.",
		UiTheme.FONT_SIZE_SMALL, BanhTet.GRAY_600
	)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)

	var password := UiTheme.line_edit("Mật khẩu quản trị")
	password.secret = true
	box.add_child(password)

	var status := UiTheme.label("", UiTheme.FONT_SIZE_SMALL, BanhTet.RED_700)
	box.add_child(status)

	# Thêm nội dung vào VBoxContainer bên trong AcceptDialog (dialog.get_vbox())
	# để nút OK / Huỷ vẫn hiển thị đúng. Dùng dialog.add_child(box) sẽ làm
	# nút bị đẩy ra khỏi vùng hiển thị trên Godot 4.3.
	dialog.get_vbox().add_child(box)
	add_child(dialog)

	# Gọi get_ok_button() để chắc chắn nút tồn tại và bấm được.
	var ok_button := dialog.get_ok_button()
	ok_button.text = "Đăng nhập"

	# Dùng method thường thay vì lambda có await - GDScript 4.3 không cho
	# await bên trong lambda của signal một cách an toàn.
	dialog.confirmed.connect(_on_login_confirmed.bind(dialog, password, status, ok_button))
	dialog.popup_centered(Vector2i(380, 260))


## Xử lý khi bấm nút "Đăng nhập"
func _on_login_confirmed(
	dialog: AcceptDialog,
	password: LineEdit,
	status: Label,
	ok_button: Button
) -> void:
	ok_button.disabled = true
	status.text = "Đang xác thực..."
	var ok := await store.login(password.text)
	ok_button.disabled = false
	if ok:
		status.text = ""
		dialog.hide()
		_admin_button.text = "👤 Thoát"
		_show_screen(_current_screen)
	else:
		status.text = "Mật khẩu không đúng"
		password.text = ""
		password.grab_focus()
