class_name WebDialog
extends Control

## Dialog giống shadcn/ui (src/components/ui/dialog.tsx) - thay cho AcceptDialog:
##   Overlay:  fixed inset-0 bg-black/10 backdrop-blur-xs, fade 100ms
##   Content:  rounded-xl bg-popover p-4 ring-1 ring-foreground/10
##             w-full max-w-[calc(100%-2rem)] sm:max-w-sm, zoom-in-95
##   Close:    nút X tròn ở top-2 right-2
##   Header:   flex-col gap-2; Title text-base font-medium; Description text-sm muted
##   Footer:   -mx-4 -mb-4 border-t bg-muted/50 p-4, nút căn phải (mobile: xếp dọc)
##
## Dùng:
##   var d := WebDialog.open(self, "Tiêu đề", "Mô tả", 384)
##   d.body.add_child(...)
##   d.add_footer_button(btn)
##   d.closed.connect(...)

signal closed

var body: VBoxContainer
var footer: BoxContainer
var _panel: PanelContainer
var _max_width := 384
var _footer_wrap: PanelContainer
var _closable := true


static func open(host: Node, title: String, description: String = "", max_width: int = 384, closable: bool = true) -> WebDialog:
	var d := WebDialog.new()
	d._max_width = max_width
	d._closable = closable
	d._build(title, description)
	# Gắn vào cửa sổ gốc để phủ toàn màn hình, nằm trên mọi thứ
	host.get_tree().root.add_child(d)
	d._animate_in()
	return d


func _build(title: String, description: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100

	# Overlay bg-black/10
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.1)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(_on_overlay_input)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var st := StyleBoxFlat.new()
	st.bg_color = Color.WHITE
	st.border_color = Color(0, 0, 0, 0.1)  # ring-1 ring-foreground/10
	st.set_border_width_all(1)
	st.set_corner_radius_all(14)
	st.set_content_margin_all(16)
	st.shadow_color = Color(0, 0, 0, 0.08)
	st.shadow_size = 16
	st.shadow_offset = Vector2(0, 6)
	st.anti_aliasing = true
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", st)
	center.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)  # gap-4
	_panel.add_child(col)

	# Header
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	col.add_child(header)
	if title != "":
		var t := UiTheme.text(title, 16, UiTheme.WEB_FG, "medium")
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Chừa chỗ cho nút X
		var tm := MarginContainer.new()
		tm.add_theme_constant_override("margin_right", 24)
		tm.add_child(t)
		header.add_child(tm)
	if description != "":
		var desc := UiTheme.text(description, 14, UiTheme.WEB_MUTED_FG)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.add_child(desc)
	header.visible = title != "" or description != ""

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	col.add_child(body)

	# Footer (ẩn cho tới khi có nút)
	var fst := StyleBoxFlat.new()
	fst.bg_color = Color("#f5f5f5", 0.5)  # bg-muted/50
	fst.border_color = UiTheme.WEB_INPUT_BORDER
	fst.border_width_top = 1
	fst.corner_radius_bottom_left = 14
	fst.corner_radius_bottom_right = 14
	fst.set_content_margin_all(16)
	fst.expand_margin_left = 16   # -mx-4
	fst.expand_margin_right = 16
	fst.expand_margin_bottom = 16  # -mb-4
	_footer_wrap = PanelContainer.new()
	_footer_wrap.add_theme_stylebox_override("panel", fst)
	_footer_wrap.visible = false
	col.add_child(_footer_wrap)
	footer = BoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 8)
	_footer_wrap.add_child(footer)

	# Nút X (absolute top-2 right-2)
	if _closable:
		var x := Button.new()
		x.icon = UiTheme.icon_texture("x", 16, UiTheme.WEB_FG)
		x.tooltip_text = "Đóng"
		x.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		x.add_theme_stylebox_override("normal", UiTheme.box_style(Color.TRANSPARENT, Color.TRANSPARENT, 999, 6, 6))
		x.add_theme_stylebox_override("hover", UiTheme.box_style(Color(0, 0, 0, 0.1), Color.TRANSPARENT, 999, 6, 6))
		x.add_theme_stylebox_override("pressed", UiTheme.box_style(Color(0, 0, 0, 0.1), Color.TRANSPARENT, 999, 6, 6))
		x.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		x.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		x.position = Vector2(-36, 8)
		x.pressed.connect(close)
		var layer := Control.new()
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(layer)
		layer.add_child(x)



func _ready() -> void:
	get_viewport().size_changed.connect(_fit_width)
	_fit_width()


## w-full max-w-[calc(100%-2rem)] sm:max-w-*
func _fit_width() -> void:
	if _panel == null:
		return
	var vw := get_viewport_rect().size.x
	var w: float = min(float(_max_width), vw - 32.0)
	_panel.custom_minimum_size.x = w
	# Footer: mobile flex-col-reverse (nút full width), sm: hàng ngang căn phải
	var wide := vw >= UiTheme.BP_SM
	footer.vertical = not wide
	for b in footer.get_children():
		if b is Control:
			b.size_flags_horizontal = Control.SIZE_SHRINK_END if wide else Control.SIZE_EXPAND_FILL
	_check_height.call_deferred()


## max-h-[92vh] -> nếu nội dung cao hơn thì cuộn. Đo sau 2 frame vì label
## autowrap chỉ có chiều cao đúng khi đã có chiều rộng.
func _check_height() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _scrolled or not is_inside_tree():
		return
	var vh := get_viewport_rect().size.y
	var col := _panel.get_child(0) as Control
	if col.size.y + 32 > vh * 0.92:
		_wrap_scroll(vh * 0.92)


var _scrolled := false
func _wrap_scroll(max_h: float) -> void:
	if _scrolled:
		return
	_scrolled = true
	var col := _panel.get_child(0)
	_panel.remove_child(col)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.y = max_h - 32
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	_panel.add_child(sc)
	_panel.move_child(sc, 0)


func add_footer_button(btn: Button) -> Button:
	_footer_wrap.visible = true
	footer.add_child(btn)
	# Thứ tự nút mobile: flex-col-reverse -> nút chính ở trên
	_fit_width.call_deferred()
	return btn


func _on_overlay_input(event: InputEvent) -> void:
	if _closable and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if _closable and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## fade-in-0 zoom-in-95, 100ms
func _animate_in() -> void:
	modulate.a = 0.0
	_panel.pivot_offset = _panel.size / 2
	_panel.scale = Vector2(0.95, 0.95)
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size / 2
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.1)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.1)


func close() -> void:
	if is_queued_for_deletion():
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_property(_panel, "scale", Vector2(0.95, 0.95), 0.1)
	await tw.finished
	closed.emit()
	queue_free()


## Nút kiểu shadcn: "default" (đen/đỏ tuỳ class), "secondary" (bg-secondary), "outline"
static func button(label_text: String, icon_name: String, bg: Color, fg: Color, border: Color = Color.TRANSPARENT) -> Button:
	var b := Button.new()
	b.text = label_text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 14)
	UiTheme.set_weight(b, "medium")
	var n := UiTheme.box_style(bg, border, 10, 12, 7)
	var h := UiTheme.box_style(bg.darkened(0.08) if bg.a > 0 else Color("#f5f5f5"), border, 10, 12, 7)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var dis := n.duplicate() as StyleBoxFlat
	dis.bg_color = Color(bg, bg.a * 0.5)
	b.add_theme_stylebox_override("disabled", dis)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.6))
	if icon_name != "":
		UiTheme.set_button_icon(b, icon_name, 16, fg)
	return b
