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
	var style := StyleBoxFlat.new()
	style.bg_color = BanhTet.WHITE
	style.border_color = BanhTet.GRAY_300
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_SM)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


## Style ô nhập khi có focus - viền đỏ (giống ring của shadcn)
static func input_focus_style() -> StyleBoxFlat:
	var style := input_style()
	style.border_color = BanhTet.RED_600
	style.set_border_width_all(2)
	return style


static func line_edit(placeholder: String = "") -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.add_theme_stylebox_override("normal", input_style())
	edit.add_theme_stylebox_override("focus", input_focus_style())
	edit.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	return edit


static func text_area(placeholder: String = "") -> TextEdit:
	var edit := TextEdit.new()
	edit.placeholder_text = placeholder
	edit.add_theme_stylebox_override("normal", input_style())
	edit.add_theme_stylebox_override("focus", input_focus_style())
	edit.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	edit.custom_minimum_size.y = 74
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


static func option_button(items: Array) -> OptionButton:
	var opt := OptionButton.new()
	for item in items:
		opt.add_item(str(item))
	opt.add_theme_stylebox_override("normal", option_button_style())
	opt.add_theme_stylebox_override("hover", option_button_hover_style())
	opt.add_theme_stylebox_override("pressed", option_button_pressed_style())
	opt.add_theme_stylebox_override("focus", option_button_style())
	opt.add_theme_stylebox_override("disabled", disabled_option_button_style())
	opt.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	# Màu chữ đủ trạng thái, nếu thiếu thì hover chữ sẽ bị mất.
	opt.add_theme_color_override("font_color", BanhTet.GRAY_700)
	opt.add_theme_color_override("font_hover_color", BanhTet.RED_700)
	opt.add_theme_color_override("font_pressed_color", BanhTet.RED_800)
	opt.add_theme_color_override("font_focus_color", BanhTet.GRAY_700)
	opt.add_theme_color_override("font_disabled_color", BanhTet.GRAY_400)

	# Style popup menu xổ xuống (Godot mặc định dùng nền tối -> khó đọc)
	var popup := opt.get_popup()
	popup.add_theme_stylebox_override("panel", _popup_panel_style())
	popup.add_theme_stylebox_override("hover", _popup_hover_style())
	popup.add_theme_color_override("font_color", BanhTet.GRAY_800)
	popup.add_theme_color_override("font_hover_color", BanhTet.RED_700)
	popup.add_theme_color_override("font_disabled_color", BanhTet.GRAY_400)
	popup.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
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
