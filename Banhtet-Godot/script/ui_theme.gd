class_name UiTheme
extends RefCounted

## Style dùng chung cho toàn app.
## Port từ design system của web app (shadcn/ui + Tailwind) để UI giống web 1:1.

const FONT_SIZE_TINY := 11
const FONT_SIZE_SMALL := 13
const FONT_SIZE_BODY := 15
const FONT_SIZE_TITLE := 19
const FONT_SIZE_HEADING := 23

const RADIUS_SM := 6
const RADIUS_MD := 10
const RADIUS_LG := 16
const RADIUS_XL := 22

## Nền app giống web: #fcf8f2
const PAGE_BG := Color(0.988, 0.973, 0.949)


## Panel trắng viền xám bo góc - giống Card của shadcn
static func card(bg: Color = BanhTet.WHITE, border: Color = BanhTet.GRAY_200) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", card_style(bg, border))
	return panel


## StyleBox cho Card (trắng, viền amber nhạt, bo góc 16px)
static func card_style(bg: Color = BanhTet.WHITE, border: Color = BanhTet.AMBER_200) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_LG)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.05)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 1)
	return style


## Nút chính - đỏ gradient đậm, chữ trắng đậm (giống web)
static func primary_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.RED_700
	style.border_color = BanhTet.RED_800
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_MD)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 11
	style.content_margin_bottom = 11
	style.shadow_color = Color(0, 0, 0, 0.12)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


## Nút chính khi hover - đỏ đậm hơn (web: hover:from-red-700 hover:to-red-800)
static func primary_button_hover_style() -> StyleBoxFlat:
	var style := primary_button_style()
	style.bg_color = BanhTet.RED_800
	style.border_color = BanhTet.RED_900
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style


## Nút chính khi nhấn - đỏ đậm nhất
static func primary_button_pressed_style() -> StyleBoxFlat:
	var style := primary_button_style()
	style.bg_color = BanhTet.RED_900
	style.border_color = BanhTet.RED_900
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	return style


## Nút phụ - viền amber, nền amber nhạt (nút "Xuất Excel", "Danh Sách")
static func outline_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.AMBER_50
	style.border_color = BanhTet.AMBER_300
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_MD)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.05)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	return style


## Nút viền amber khi hover - nền amber đậm hơn
static func outline_button_hover_style() -> StyleBoxFlat:
	var style := outline_button_style()
	style.bg_color = BanhTet.AMBER_100
	style.border_color = BanhTet.AMBER_500
	return style


## Nút viền amber khi nhấn - nền amber 200
static func outline_button_pressed_style() -> StyleBoxFlat:
	var style := outline_button_style()
	style.bg_color = BanhTet.AMBER_200
	style.border_color = BanhTet.AMBER_600
	return style


static func secondary_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.GRAY_100
	style.border_color = BanhTet.GRAY_200
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_MD)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 11
	style.content_margin_bottom = 11
	return style


## Nút xám khi hover - nền xám đậm hơn
static func secondary_button_hover_style() -> StyleBoxFlat:
	var style := secondary_button_style()
	style.bg_color = BanhTet.GRAY_200
	return style


## Nút xám khi nhấn
static func secondary_button_pressed_style() -> StyleBoxFlat:
	var style := secondary_button_style()
	style.bg_color = BanhTet.GRAY_300
	return style


static func success_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.EMERALD_600
	style.border_color = BanhTet.GREEN_700
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_MD)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 11
	style.content_margin_bottom = 11
	return style


## Nút xanh khi hover - đậm hơn
static func success_button_hover_style() -> StyleBoxFlat:
	var style := success_button_style()
	style.bg_color = BanhTet.GREEN_700
	style.border_color = BanhTet.GREEN_800
	return style


## Nút xanh khi nhấn
static func success_button_pressed_style() -> StyleBoxFlat:
	var style := success_button_style()
	style.bg_color = BanhTet.GREEN_800
	return style


static func label(
	text: String,
	size: int = FONT_SIZE_BODY,
	color: Color = BanhTet.GRAY_800
) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


## Label đậm - dùng cho tiêu đề (web dùng font-extrabold)
static func bold_label(
	text: String,
	size: int = FONT_SIZE_BODY,
	color: Color = BanhTet.GRAY_800
) -> Label:
	var lbl := label(text, size, color)
	lbl.add_theme_color_override("font_outline_color", color)
	lbl.add_theme_constant_override("outline_size", 0)
	return lbl


static func input_style() -> StyleBoxFlat:
	return web_input_style(false)


## Style ô nhập khi có focus (focus-visible:border-ring + ring-3 ring-ring/50)
static func input_focus_style() -> StyleBoxFlat:
	return web_input_style(true)


## Ô nhập 1 dòng - style lấy từ theme chung (build_app_theme), không override
static func line_edit(placeholder: String = "") -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	return edit


## Ô nhập nhiều dòng (Textarea: min-h-16, tự xuống dòng)
static func text_area(placeholder: String = "") -> TextEdit:
	var edit := TextEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size.y = 64
	return edit


## Tạo nút với đầy đủ trạng thái normal / hover / pressed / disabled.
## Quan trọng: mỗi trạng thái phải có stylebox RIÊNG và màu chữ RIÊNG,
## nếu không khi hover chữ sẽ bị mất (màu hover mặc định của Godot).
static func button(text: String, kind: String = "primary", font_size: int = FONT_SIZE_BODY) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", font_size)

	match kind:
		"secondary":
			_style_button(
				btn,
				secondary_button_style(),
				secondary_button_hover_style(),
				secondary_button_pressed_style(),
				disabled_button_style(),
				BanhTet.GRAY_800,   # normal
				BanhTet.GRAY_900,   # hover
				BanhTet.GRAY_900,   # pressed
				BanhTet.GRAY_400    # disabled
			)
		"outline":
			_style_button(
				btn,
				outline_button_style(),
				outline_button_hover_style(),
				outline_button_pressed_style(),
				disabled_button_style(),
				BanhTet.AMBER_800,  # normal
				BanhTet.AMBER_900,  # hover
				BanhTet.AMBER_900,  # pressed
				BanhTet.GRAY_400    # disabled
			)
		"success":
			_style_button(
				btn,
				success_button_style(),
				success_button_hover_style(),
				success_button_pressed_style(),
				disabled_button_style(),
				BanhTet.WHITE,      # normal
				BanhTet.WHITE,      # hover
				BanhTet.WHITE,      # pressed
				BanhTet.GRAY_400    # disabled
			)
		_:
			_style_button(
				btn,
				primary_button_style(),
				primary_button_hover_style(),
				primary_button_pressed_style(),
				disabled_button_style(),
				BanhTet.WHITE,      # normal
				BanhTet.WHITE,      # hover
				BanhTet.WHITE,      # pressed
				BanhTet.GRAY_400    # disabled
			)
	return btn


## Gán stylebox + màu chữ cho từng trạng thái của Button
static func _style_button(
	btn: Button,
	normal: StyleBoxFlat,
	hover: StyleBoxFlat,
	pressed: StyleBoxFlat,
	disabled: StyleBoxFlat,
	color_normal: Color,
	color_hover: Color,
	color_pressed: Color,
	color_disabled: Color
) -> void:
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	btn.add_theme_color_override("font_color", color_normal)
	btn.add_theme_color_override("font_hover_color", color_hover)
	btn.add_theme_color_override("font_pressed_color", color_pressed)
	btn.add_theme_color_override("font_focus_color", color_hover)
	btn.add_theme_color_override("font_disabled_color", color_disabled)


## Nút bị vô hiệu hoá - nền xám nhạt, chữ xám
static func disabled_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.GRAY_100
	style.border_color = BanhTet.GRAY_200
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_MD)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 11
	style.content_margin_bottom = 11
	return style


## Nút icon tròn nhỏ (nút +/- số lượng, nút gọi).
## Bo góc tròn, viền xám, chữ xám đật - khi hover nền đậm hơn và chữ đỏ.
static func icon_button(text: String, size: int = 34, font_size: int = 18) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(size, size)
	btn.add_theme_font_size_override("font_size", font_size)

	var normal := _round_button_style(BanhTet.WHITE, BanhTet.GRAY_300)
	var hover := _round_button_style(BanhTet.RED_50, BanhTet.RED_300)
	var pressed := _round_button_style(BanhTet.RED_100, BanhTet.RED_500)
	var disabled := _round_button_style(BanhTet.GRAY_50, BanhTet.GRAY_200)

	_style_button(
		btn,
		normal,
		hover,
		pressed,
		disabled,
		BanhTet.GRAY_700,   # normal
		BanhTet.RED_700,    # hover
		BanhTet.RED_800,    # pressed
		BanhTet.GRAY_300    # disabled
	)
	return btn


## Style nút bo tròn
static func _round_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(999)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


## Nút gọi khách hàng: nền trắng, viền đỏ, chữ đỏ
static func call_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.WHITE
	style.border_color = BanhTet.RED_700
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	return style


static func call_button_hover_style() -> StyleBoxFlat:
	var style := call_button_style()
	style.bg_color = BanhTet.RED_50
	style.border_color = BanhTet.RED_800
	return style


static func call_button_pressed_style() -> StyleBoxFlat:
	var style := call_button_style()
	style.bg_color = BanhTet.RED_100
	return style


static func status_badge(status: String) -> PanelContainer:
	var bg: Color = BanhTet.STATUS_COLORS.get(status, BanhTet.GRAY_100)
	var fg: Color = BanhTet.STATUS_TEXT_COLORS.get(status, BanhTet.GRAY_800)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(999)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = str(BanhTet.STATUS_LABELS.get(status, status))
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_TINY)
	lbl.add_theme_color_override("font_color", fg)
	lbl.add_theme_font_override("font", font("bold"))
	style.border_color = fg.lerp(bg, 0.7)
	style.set_border_width_all(1)
	panel.add_child(lbl)
	return panel


static func option_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.WHITE
	style.border_color = BanhTet.GRAY_300
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_SM)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


## Select (SelectTrigger của shadcn) - style lấy từ theme chung
static func option_button(items: Array) -> OptionButton:
	var opt := OptionButton.new()
	for item in items:
		opt.add_item(str(item))
	return opt


## OptionButton khi hover - viền đỏ
static func option_button_hover_style() -> StyleBoxFlat:
	var style := option_button_style()
	style.border_color = BanhTet.RED_300
	return style


## OptionButton khi nhấn
static func option_button_pressed_style() -> StyleBoxFlat:
	var style := option_button_style()
	style.border_color = BanhTet.RED_600
	return style


## OptionButton bị vô hiệu hoá
static func disabled_option_button_style() -> StyleBoxFlat:
	var style := option_button_style()
	style.bg_color = BanhTet.GRAY_50
	style.border_color = BanhTet.GRAY_200
	return style


## Style cho popup menu xổ xuống của OptionButton.
## Cần đặt riêng vì Godot dùng theme mặc định (nền tối) cho popup,
## gây chữ khó đọc.
static func popup_menu_style() -> PopupMenu:
	var popup := PopupMenu.new()
	popup.add_theme_stylebox_override("panel", _popup_panel_style())
	popup.add_theme_stylebox_override("hover", _popup_hover_style())
	popup.add_theme_color_override("font_color", BanhTet.GRAY_800)
	popup.add_theme_color_override("font_hover_color", BanhTet.RED_700)
	popup.add_theme_color_override("font_disabled_color", BanhTet.GRAY_400)
	popup.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	return popup


static func _popup_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.WHITE
	style.border_color = BanhTet.AMBER_200
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_SM)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0, 0, 0, 0.12)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	return style


static func _popup_hover_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.RED_50
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


## Nền app có dot pattern giống web (radial-gradient #e5e7eb 1px, 24px)
static func make_dotted_background() -> Control:
	var bg := ColorRect.new()
	bg.color = PAGE_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pattern := TextureRect.new()
	pattern.set_anchors_preset(Control.PRESET_FULL_RECT)
	pattern.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pattern.stretch_mode = TextureRect.STRETCH_TILE
	pattern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pattern.texture = _make_dot_texture()
	bg.add_child(pattern)
	return bg


## Tạo texture 24x24 chấm tròn màu #e5e7eb để làm dot pattern
static func _make_dot_texture() -> ImageTexture:
	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= 1.0:
				img.set_pixel(x, y, Color(0.898, 0.906, 0.922, 0.85))
	return ImageTexture.create_from_image(img)


## Style hộp thoại (AcceptDialog/ConfirmationDialog) theo theme Tết:
## Godot mặc định dùng khung + nền xám đen, lệch hẳn với phần còn lại của app.
static func style_dialog(dialog: AcceptDialog) -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = BanhTet.WHITE
	frame.border_color = BanhTet.AMBER_200
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(RADIUS_LG)
	# Chừa chỗ cho thanh tiêu đề (Window vẽ title trong phần expand_margin_top)
	frame.expand_margin_top = 40
	frame.expand_margin_left = 8
	frame.expand_margin_right = 8
	frame.expand_margin_bottom = 8
	frame.shadow_color = Color(0, 0, 0, 0.18)
	frame.shadow_size = 12
	dialog.add_theme_stylebox_override("embedded_border", frame)
	dialog.add_theme_stylebox_override("embedded_unfocused_border", frame)
	dialog.add_theme_constant_override("title_height", 40)
	dialog.add_theme_color_override("title_color", BanhTet.RED_700)
	dialog.add_theme_font_size_override("title_font_size", FONT_SIZE_TITLE)
	dialog.add_theme_color_override("close_color", BanhTet.GRAY_500)

	var panel := StyleBoxFlat.new()
	panel.bg_color = BanhTet.WHITE
	dialog.add_theme_stylebox_override("panel", panel)

	# Nút OK = nút chính đỏ, các nút còn lại (Huỷ...) = viền
	var ok := dialog.get_ok_button()
	for btn in dialog.find_children("*", "Button", true, false):
		if btn is Button:
			_style_dialog_button(btn, btn == ok)


static func _style_dialog_button(btn: Button, primary: bool) -> void:
	btn.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	btn.custom_minimum_size = Vector2(110, 40)
	if primary:
		_style_button(
			btn, primary_button_style(), primary_button_hover_style(),
			primary_button_pressed_style(), disabled_button_style(),
			BanhTet.WHITE, BanhTet.WHITE, BanhTet.WHITE, BanhTet.GRAY_400
		)
	else:
		_style_button(
			btn, outline_button_style(), outline_button_hover_style(),
			outline_button_pressed_style(), disabled_button_style(),
			BanhTet.RED_700, BanhTet.RED_800, BanhTet.RED_800, BanhTet.GRAY_400
		)


## ===================================================================
## Font Be Vietnam Pro (giống web) + icon lucide + breakpoint responsive
## ===================================================================

## Breakpoint Tailwind (đơn vị: px logic của viewport Godot)
const BP_SM := 640
const BP_MD := 768
const BP_LG := 1024

const _FONT_FILES := {
	"regular": "res://assets/fonts/BeVietnamPro-Regular.ttf",
	"medium": "res://assets/fonts/BeVietnamPro-Medium.ttf",
	"semibold": "res://assets/fonts/BeVietnamPro-SemiBold.ttf",
	"bold": "res://assets/fonts/BeVietnamPro-Bold.ttf",
	"extrabold": "res://assets/fonts/BeVietnamPro-ExtraBold.ttf",
}

static var _fonts := {}
static var _icon_cache := {}


## Font theo độ đậm (regular/medium/semibold/bold/extrabold), có fallback emoji
static func font(weight: String = "regular") -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var f := load(_FONT_FILES.get(weight, _FONT_FILES["regular"])) as FontFile
	if f == null:
		return ThemeDB.fallback_font
	var emoji := load("res://assets/fonts/NotoColorEmoji.ttf") as Font
	if emoji != null and f.fallbacks.is_empty():
		f.fallbacks = [emoji]
	_fonts[weight] = f
	return f


## Đổi độ đậm chữ của Label/Button/LineEdit...
static func set_weight(control: Control, weight: String) -> Control:
	control.add_theme_font_override("font", font(weight))
	return control


## Label có độ đậm - tiện dụng cho text giống Tailwind (font-bold, font-extrabold...)
static func text(
	value: String, size: int = FONT_SIZE_BODY, color: Color = BanhTet.GRAY_800,
	weight: String = "regular"
) -> Label:
	var lbl := label(value, size, color)
	set_weight(lbl, weight)
	return lbl


## Texture icon lucide, tô màu sẵn, render sắc nét ở kích thước `px`
static func icon_texture(name: String, px: int = 16, color: Color = BanhTet.GRAY_500) -> Texture2D:
	var key := "%s|%d|%s" % [name, px, color.to_html()]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var file := FileAccess.open("res://assets/icons/%s.lucide" % name, FileAccess.READ)
	if file == null:
		return null
	var svg := file.get_as_text().replace("currentColor", "#" + color.to_html(false))
	var img := Image.new()
	# Render x2 cho sắc nét khi màn hình có scale
	img.load_svg_from_string(svg, px * 2.0 / 24.0)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	# Ảnh render x2 nhưng báo kích thước logic = px (Button/TextureRect không bị phóng to)
	tex.set_size_override(Vector2i(px, px))
	_icon_cache[key] = tex
	return tex


## Icon lucide dạng TextureRect kích thước cố định
static func icon(name: String, px: int = 16, color: Color = BanhTet.GRAY_500) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = icon_texture(name, px, color)
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Gắn icon lucide vào Button (bên trái chữ)
static func set_button_icon(btn: Button, name: String, px: int, color: Color) -> Button:
	btn.icon = icon_texture(name, px, color)
	btn.expand_icon = false
	btn.add_theme_constant_override("icon_max_width", px)
	btn.add_theme_constant_override("h_separation", 8)
	return btn


## StyleBox bo góc tuỳ ý (tiện cho badge / panel kiểu Tailwind)
static func box_style(
	bg: Color, border: Color = Color.TRANSPARENT, radius: int = RADIUS_MD,
	pad_x: float = 0, pad_y: float = 0, border_width: int = 1
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	if border.a > 0:
		s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	s.anti_aliasing = true
	return s


static func panel(style: StyleBox) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style)
	return p


## Nút kiểu shadcn: icon lucide + chữ, các biến thể giống web
## kind: "primary" (đỏ gradient), "amber" (viền vàng nền amber-50),
##       "outline-red", "outline-amber", "ghost"
static func tw_button(
	label_text: String, icon_name: String = "", kind: String = "amber",
	font_size: int = 14, icon_color: Color = Color.TRANSPARENT
) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", font_size)
	set_weight(btn, "semibold" if kind != "primary" else "bold")
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var bg: Color
	var bg_hover: Color
	var border: Color
	var fg: Color
	match kind:
		"primary":
			bg = BanhTet.RED_600; bg_hover = BanhTet.RED_700
			border = BanhTet.RED_700; fg = BanhTet.WHITE
		"outline-red":
			bg = BanhTet.WHITE; bg_hover = BanhTet.RED_50
			border = BanhTet.RED_200; fg = BanhTet.RED_700
		"outline-amber":
			bg = BanhTet.WHITE; bg_hover = BanhTet.AMBER_50
			border = BanhTet.AMBER_300; fg = BanhTet.AMBER_900
		"ghost":
			bg = Color.TRANSPARENT; bg_hover = BanhTet.RED_50
			border = Color.TRANSPARENT; fg = BanhTet.GRAY_500
		_:
			bg = BanhTet.AMBER_50; bg_hover = BanhTet.AMBER_100
			border = BanhTet.AMBER_300; fg = BanhTet.AMBER_800
	var pad_x := 14.0 if label_text != "" else 8.0
	var normal := box_style(bg, border, 8, pad_x, 7)
	var hover := box_style(bg_hover, border, 8, pad_x, 7)
	if kind == "primary":
		normal.shadow_color = Color(0.6, 0.1, 0.1, 0.25)
		normal.shadow_size = 4
		normal.shadow_offset = Vector2(0, 2)
		hover.shadow_color = normal.shadow_color
		hover.shadow_size = 6
		hover.shadow_offset = Vector2(0, 3)
	elif kind != "ghost":
		normal.shadow_color = Color(0, 0, 0, 0.05)
		normal.shadow_size = 2
		normal.shadow_offset = Vector2(0, 1)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", box_style(bg.lerp(BanhTet.WHITE, 0.4), border.lerp(BanhTet.WHITE, 0.4), 8, pad_x, 7))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, fg)
	btn.add_theme_color_override("font_disabled_color", fg.lerp(BanhTet.WHITE, 0.4))
	if icon_name != "":
		set_button_icon(btn, icon_name, 16, icon_color if icon_color.a > 0 else fg)
	return btn



## ===================================================================
## THEME CHUNG CHO MỌI Ô NHẬP - "reset" giống input của web (shadcn/ui)
## ===================================================================
## Web (src/components/ui/input.tsx, textarea.tsx, select.tsx):
##   h-8 rounded-lg border border-input bg-transparent px-2.5 py-1 md:text-sm
##   placeholder:text-muted-foreground
##   focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50
##   disabled:bg-input/50 disabled:opacity-50
## Biến CSS: --input #e5e5e5, --ring/--primary #e7000b, --radius 0.75rem,
##           --muted-foreground #737373, --accent #f5f5f5

const WEB_INPUT_BORDER := Color("#e5e5e5")
const WEB_RING := Color("#e7000b")
const WEB_MUTED_FG := Color("#737373")
const WEB_FG := Color("#0a0a0a")
const WEB_ACCENT := Color("#f5f5f5")
const WEB_SELECTION := Color(0.698, 0.843, 1.0, 0.85)
const WEB_INPUT_RADIUS := 10
const WEB_FONT_SIZE := 14


static func web_input_style(focused: bool, pad_x: float = 10, pad_y: float = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BanhTet.WHITE
	s.border_color = WEB_RING if focused else WEB_INPUT_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(WEB_INPUT_RADIUS)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	s.anti_aliasing = true
	if focused:
		# ring-3 ring-ring/50: vòng sáng 3px quanh ô
		s.shadow_color = Color(WEB_RING, 0.35)
		s.shadow_size = 3
	else:
		s.shadow_color = Color(0, 0, 0, 0.04)  # shadow-xs
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, 1)
	return s


static func _web_disabled_style(pad_x: float = 10, pad_y: float = 6) -> StyleBoxFlat:
	var s := web_input_style(false, pad_x, pad_y)
	s.bg_color = Color(WEB_INPUT_BORDER, 0.5)
	s.shadow_size = 0
	return s


## Theme gắn vào cửa sổ gốc -> mọi LineEdit / TextEdit / OptionButton /
## PopupMenu / ScrollBar trong app (kể cả trong hộp thoại) đều giống web.
static func build_app_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("regular")
	t.default_font_size = WEB_FONT_SIZE

	# ---------- LineEdit (Input) ----------
	t.set_stylebox("normal", "LineEdit", web_input_style(false))
	t.set_stylebox("focus", "LineEdit", web_input_style(true))
	t.set_stylebox("read_only", "LineEdit", _web_disabled_style())
	t.set_font_size("font_size", "LineEdit", WEB_FONT_SIZE)
	t.set_color("font_color", "LineEdit", WEB_FG)
	t.set_color("font_placeholder_color", "LineEdit", WEB_MUTED_FG)
	t.set_color("font_uneditable_color", "LineEdit", Color(WEB_FG, 0.5))
	t.set_color("font_selected_color", "LineEdit", WEB_FG)
	t.set_color("selection_color", "LineEdit", WEB_SELECTION)
	t.set_color("caret_color", "LineEdit", WEB_FG)
	t.set_color("clear_button_color", "LineEdit", WEB_MUTED_FG)
	t.set_color("clear_button_color_pressed", "LineEdit", WEB_RING)
	t.set_constant("caret_width", "LineEdit", 1)
	t.set_constant("minimum_character_width", "LineEdit", 0)

	# ---------- TextEdit (Textarea) ----------
	t.set_stylebox("normal", "TextEdit", web_input_style(false, 10, 8))
	t.set_stylebox("focus", "TextEdit", web_input_style(true, 10, 8))
	t.set_stylebox("read_only", "TextEdit", _web_disabled_style(10, 8))
	t.set_font_size("font_size", "TextEdit", WEB_FONT_SIZE)
	t.set_color("font_color", "TextEdit", WEB_FG)
	t.set_color("font_placeholder_color", "TextEdit", WEB_MUTED_FG)
	t.set_color("font_readonly_color", "TextEdit", Color(WEB_FG, 0.5))
	t.set_color("font_selected_color", "TextEdit", WEB_FG)
	t.set_color("selection_color", "TextEdit", WEB_SELECTION)
	t.set_color("caret_color", "TextEdit", WEB_FG)
	t.set_color("current_line_color", "TextEdit", Color.TRANSPARENT)
	t.set_color("background_color", "TextEdit", Color.TRANSPARENT)
	t.set_constant("caret_width", "TextEdit", 1)
	t.set_constant("line_spacing", "TextEdit", 4)

	# ---------- OptionButton (SelectTrigger) ----------
	var sel_hover := web_input_style(false)
	sel_hover.bg_color = WEB_ACCENT.lerp(BanhTet.WHITE, 0.5)
	t.set_stylebox("normal", "OptionButton", web_input_style(false))
	t.set_stylebox("hover", "OptionButton", sel_hover)
	t.set_stylebox("pressed", "OptionButton", web_input_style(true))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "OptionButton", _web_disabled_style())
	t.set_stylebox("normal_mirrored", "OptionButton", web_input_style(false))
	t.set_stylebox("hover_mirrored", "OptionButton", sel_hover)
	t.set_stylebox("pressed_mirrored", "OptionButton", web_input_style(true))
	t.set_stylebox("disabled_mirrored", "OptionButton", _web_disabled_style())
	t.set_font_size("font_size", "OptionButton", WEB_FONT_SIZE)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "OptionButton", WEB_FG)
	t.set_color("font_disabled_color", "OptionButton", Color(WEB_FG, 0.5))
	t.set_icon("arrow", "OptionButton", icon_texture("chevron-down", 16, WEB_MUTED_FG))
	t.set_constant("arrow_margin", "OptionButton", 8)
	t.set_constant("h_separation", "OptionButton", 6)
	t.set_constant("modulate_arrow", "OptionButton", 0)

	# ---------- PopupMenu (SelectContent / SelectItem) ----------
	var pop := StyleBoxFlat.new()
	pop.bg_color = BanhTet.WHITE
	pop.border_color = Color(0, 0, 0, 0.1)  # ring-1 ring-foreground/10
	pop.set_border_width_all(1)
	pop.set_corner_radius_all(WEB_INPUT_RADIUS)
	pop.set_content_margin_all(4)
	pop.shadow_color = Color(0, 0, 0, 0.12)  # shadow-md
	pop.shadow_size = 8
	pop.shadow_offset = Vector2(0, 4)
	pop.anti_aliasing = true
	t.set_stylebox("panel", "PopupMenu", pop)
	var item_hover := StyleBoxFlat.new()
	item_hover.bg_color = WEB_ACCENT  # focus:bg-accent
	item_hover.set_corner_radius_all(6)
	item_hover.anti_aliasing = true
	t.set_stylebox("hover", "PopupMenu", item_hover)
	var sep := StyleBoxLine.new()
	sep.color = WEB_INPUT_BORDER
	t.set_stylebox("separator", "PopupMenu", sep)
	t.set_font_size("font_size", "PopupMenu", WEB_FONT_SIZE)
	t.set_color("font_color", "PopupMenu", WEB_FG)
	t.set_color("font_hover_color", "PopupMenu", WEB_FG)
	t.set_color("font_disabled_color", "PopupMenu", Color(WEB_FG, 0.5))
	t.set_color("font_separator_color", "PopupMenu", WEB_MUTED_FG)
	# Dấu ✓ cho mục đang chọn (SelectItem có Check bên phải)
	var check := icon_texture("check", 16, WEB_FG)
	t.set_icon("radio_checked", "PopupMenu", check)
	t.set_icon("radio_checked_disabled", "PopupMenu", check)
	t.set_icon("checked", "PopupMenu", check)
	var blank := ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	t.set_icon("radio_unchecked", "PopupMenu", blank)
	t.set_icon("unchecked", "PopupMenu", blank)
	t.set_constant("v_separation", "PopupMenu", 10)
	t.set_constant("h_separation", "PopupMenu", 8)
	t.set_constant("item_start_padding", "PopupMenu", 8)
	t.set_constant("item_end_padding", "PopupMenu", 8)

	# ---------- ScrollBar mảnh như ::-webkit-scrollbar (6px) ----------
	for sb in ["VScrollBar", "HScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color("#f1f1f1")
		track.set_corner_radius_all(3)
		track.set_content_margin_all(0)
		if sb == "VScrollBar":
			track.content_margin_left = 6
		else:
			track.content_margin_top = 6
		var grab := StyleBoxFlat.new()
		grab.bg_color = Color("#d1d5db")
		grab.set_corner_radius_all(3)
		var grab_hi := grab.duplicate() as StyleBoxFlat
		grab_hi.bg_color = Color("#9ca3af")
		t.set_stylebox("scroll", sb, track)
		t.set_stylebox("grabber", sb, grab)
		t.set_stylebox("grabber_highlight", sb, grab_hi)
		t.set_stylebox("grabber_pressed", sb, grab_hi)
	return t


## Hành vi giống ô nhập của trình duyệt - gọi cho mỗi LineEdit/TextEdit mới
static func apply_web_input_behavior(node: Control) -> void:
	if node is LineEdit:
		var le := node as LineEdit
		le.caret_blink = true            # con trỏ nhấp nháy
		le.caret_blink_interval = 0.53
		le.middle_mouse_paste_enabled = false
		le.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	elif node is TextEdit:
		var te := node as TextEdit
		te.caret_blink = true
		te.caret_blink_interval = 0.53
		te.middle_mouse_paste_enabled = false
		te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY   # textarea tự xuống dòng
		te.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		te.highlight_current_line = false
		te.scroll_fit_content_height = false
	elif node is OptionButton:
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# Popup rộng ít nhất bằng ô chọn (SelectContent min-w = trigger)
		var opt := node as OptionButton
		opt.get_popup().about_to_popup.connect(func():
			opt.get_popup().min_size.x = int(opt.size.x))
