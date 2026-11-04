extends SceneTree

## 生成雨夜主题：墨蓝底、无卡片边框、刀鞘金只做焦点提示。
## 设计取向：居合对决，信息优先；按钮靠文字与留白成组，不用圆角玻璃块。
## 用法：godot --headless --path . -s tools/build_rain_night_theme.gd

const THEME_PATH := "res://assets/theme/rain_night.tres"
const FONT := preload("res://assets/fonts/MiSans-Semibold.otf")

const NIGHT_0 := Color("#060a10")
const NIGHT_1 := Color("#0a111a")
const NIGHT_2 := Color("#0e1722")
const LINE := Color("#22303f")
const LINE_BRIGHT := Color("#3a4f63")
const INK := Color("#e9f0f7")
const INK_SOFT := Color("#c3d0dd")
const MUTED := Color("#8b9bac")
const GOLD := Color("#c8a063")
const GOLD_BRIGHT := Color("#e8c98e")
const DANGER := Color("#c98282")
const TRANSPARENT := Color(0, 0, 0, 0)


func _initialize() -> void:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 18

	_build_buttons(theme)
	_build_labels(theme)
	_build_inputs(theme)
	_build_containers(theme)
	_build_progress(theme)
	_build_scrollbars(theme)
	_build_tabs(theme)

	var err := ResourceSaver.save(theme, THEME_PATH)
	print("theme saved: ", THEME_PATH, " error=", err)
	quit(0 if err == OK else 1)


func _build_buttons(theme: Theme) -> void:
	# 普通态完全透明：菜单与设置里的按钮没有卡片边框，只靠文字间距成组。
	var clear := _flat(TRANSPARENT, TRANSPARENT, 0, 0, Vector4(18, 12, 18, 12))
	var hover := _flat(Color(0.72, 0.80, 0.88, 0.07), TRANSPARENT, 0, 0, Vector4(18, 12, 18, 12))
	var pressed := _flat(Color(0.78, 0.62, 0.34, 0.13), TRANSPARENT, 0, 0, Vector4(18, 12, 18, 12))
	var disabled := _flat(TRANSPARENT, TRANSPARENT, 0, 0, Vector4(18, 12, 18, 12))
	# 焦点只留底边一道 2px 刀鞘金，像夹在纸页里的刀镡；不做整圈描边。
	var focus := _flat(TRANSPARENT, GOLD, 0, 0, Vector4.ZERO)
	focus.border_width_bottom = 2

	for type_name in ["Button", "OptionButton", "CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type_name, clear)
		theme.set_stylebox("hover", type_name, hover)
		theme.set_stylebox("pressed", type_name, pressed)
		theme.set_stylebox("disabled", type_name, disabled)
		theme.set_stylebox("focus", type_name, focus)
		theme.set_color("font_color", type_name, INK)
		theme.set_color("font_hover_color", type_name, Color.WHITE)
		theme.set_color("font_pressed_color", type_name, GOLD_BRIGHT)
		theme.set_color("font_hover_pressed_color", type_name, GOLD_BRIGHT)
		theme.set_color("font_focus_color", type_name, Color.WHITE)
		theme.set_color("font_disabled_color", type_name, Color("#566779"))
		theme.set_color("font_outline_color", type_name, Color("#02050a"))
		theme.set_constant("outline_size", type_name, 2)
		theme.set_font_size("font_size", type_name, 18)

	# 下拉框需要“可点”的暗示：只留一条底边，不画盒子。
	var option_normal := _flat(TRANSPARENT, LINE, 0, 0, Vector4(14, 9, 14, 9))
	option_normal.border_width_bottom = 1
	var option_hover := _flat(Color(0.72, 0.80, 0.88, 0.06), LINE_BRIGHT, 0, 0, Vector4(14, 9, 14, 9))
	option_hover.border_width_bottom = 1
	var option_focus := _flat(TRANSPARENT, GOLD_BRIGHT, 0, 0, Vector4(14, 9, 14, 9))
	option_focus.border_width_bottom = 1
	theme.set_stylebox("normal", "OptionButton", option_normal)
	theme.set_stylebox("hover", "OptionButton", option_hover)
	theme.set_stylebox("pressed", "OptionButton", option_normal)
	theme.set_stylebox("focus", "OptionButton", option_focus)
	theme.set_constant("icon_max_width", "OptionButton", 18)

	# 设置页的整行开关：无底色、无边框；文字与左侧音量标签同基线。
	var check_normal := _flat(TRANSPARENT, TRANSPARENT, 0, 0, Vector4(0, 10, 8, 10))
	var check_hover := _flat(Color(0.72, 0.80, 0.88, 0.07), TRANSPARENT, 0, 0, Vector4(0, 10, 8, 10))
	var check_pressed := _flat(Color(0.78, 0.62, 0.34, 0.13), TRANSPARENT, 0, 0, Vector4(0, 10, 8, 10))
	theme.set_stylebox("normal", "CheckButton", check_normal)
	theme.set_stylebox("hover", "CheckButton", check_hover)
	theme.set_stylebox("pressed", "CheckButton", check_pressed)
	theme.set_stylebox("focus", "CheckButton", focus)
	theme.set_constant("icon_max_width", "CheckButton", 26)
	theme.set_color("icon_normal_color", "CheckButton", GOLD)
	theme.set_color("icon_hover_color", "CheckButton", GOLD_BRIGHT)
	theme.set_color("icon_pressed_color", "CheckButton", GOLD_BRIGHT)
	theme.set_color("icon_disabled_color", "CheckButton", Color("#4c5d70"))


func _build_labels(theme: Theme) -> void:
	for type_name in ["Label", "RichTextLabel"]:
		theme.set_color("font_color", type_name, INK)
		theme.set_color("font_outline_color", type_name, Color("#02050a"))
		theme.set_constant("outline_size", type_name, 4)
		theme.set_font_size("font_size", type_name, 18)
	theme.set_constant("line_spacing", "RichTextLabel", 4)


func _build_inputs(theme: Theme) -> void:
	# 输入框和下拉框一样：透明底 + 一条底边，聚焦时底边变金。
	var edit := _flat(TRANSPARENT, LINE, 0, 0, Vector4(10, 7, 10, 7))
	edit.border_width_bottom = 1
	var edit_focus := _flat(TRANSPARENT, GOLD_BRIGHT, 0, 0, Vector4(10, 7, 10, 7))
	edit_focus.border_width_bottom = 1
	var edit_read_only := _flat(TRANSPARENT, Color("#17222f"), 0, 0, Vector4(10, 7, 10, 7))
	edit_read_only.border_width_bottom = 1
	theme.set_stylebox("normal", "LineEdit", edit)
	theme.set_stylebox("focus", "LineEdit", edit_focus)
	theme.set_stylebox("read_only", "LineEdit", edit_read_only)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", GOLD_BRIGHT)
	theme.set_color("selection_color", "LineEdit", Color(0.30, 0.62, 0.64, 0.35))
	theme.set_constant("outline_size", "LineEdit", 2)

	# 滑轨是细钢线，无边框；已填部分保持低饱和刀鞘金。
	theme.set_stylebox("slider", "HSlider", _flat(Color(0.12, 0.17, 0.22, 1.0), TRANSPARENT, 0, 0, Vector4(0, 3, 0, 3)))
	theme.set_stylebox("grabber_area", "HSlider", _flat(GOLD, TRANSPARENT, 0, 0, Vector4(0, 3, 0, 3)))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _flat(GOLD_BRIGHT, TRANSPARENT, 0, 0, Vector4(0, 3, 0, 3)))

	# 弹出菜单是无边框的深色纸面，不做投影/玻璃高光。
	var popup_panel := _flat(Color(0.035, 0.060, 0.090, 0.99), TRANSPARENT, 0, 0, Vector4(8, 8, 8, 8))
	theme.set_stylebox("panel", "PopupMenu", popup_panel)
	theme.set_stylebox("hover", "PopupMenu", _flat(Color(0.72, 0.80, 0.88, 0.08), TRANSPARENT, 0, 0, Vector4(10, 5, 10, 5)))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_color("font_disabled_color", "PopupMenu", Color("#566779"))
	theme.set_color("font_separator_color", "PopupMenu", MUTED)
	theme.set_constant("item_start_padding", "PopupMenu", 12)
	theme.set_constant("item_end_padding", "PopupMenu", 12)
	theme.set_constant("v_separation", "PopupMenu", 6)


func _build_containers(theme: Theme) -> void:
	# 面板只做“更暗的一层纸”，无描边、无阴影、直角。
	var panel := _flat(Color(0.025, 0.045, 0.066, 0.97), TRANSPARENT, 0, 0, Vector4(24, 20, 24, 20))
	theme.set_stylebox("panel", "Panel", panel)
	var panel_container := _flat(Color(0.030, 0.052, 0.075, 0.97), TRANSPARENT, 0, 0, Vector4(18, 14, 18, 14))
	theme.set_stylebox("panel", "PanelContainer", panel_container)


func _build_progress(theme: Theme) -> void:
	# 填充用近白：HUD 会用 modulate 按心流档位整体染色。
	var bg := _flat(Color(0.020, 0.035, 0.055, 0.94), TRANSPARENT, 0, 0, Vector4.ZERO)
	var fill := _flat(Color("#e6eef7"), TRANSPARENT, 0, 0, Vector4.ZERO)
	theme.set_stylebox("background", "ProgressBar", bg)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_color("font_color", "ProgressBar", INK)
	theme.set_color("font_outline_color", "ProgressBar", Color("#02050a"))
	theme.set_constant("outline_size", "ProgressBar", 3)


func _build_scrollbars(theme: Theme) -> void:
	var track := _flat(Color(0.020, 0.038, 0.056, 0.9), TRANSPARENT, 0, 0, Vector4.ZERO)
	var grabber := _flat(Color("#2e4257"), TRANSPARENT, 0, 0, Vector4.ZERO)
	var highlight := _flat(Color("#4a6278"), TRANSPARENT, 0, 0, Vector4.ZERO)
	var pressed := _flat(GOLD, TRANSPARENT, 0, 0, Vector4.ZERO)
	for type_name in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", type_name, track)
		theme.set_stylebox("grabber", type_name, grabber)
		theme.set_stylebox("grabber_highlight", type_name, highlight)
		theme.set_stylebox("grabber_pressed", type_name, pressed)
		theme.set_stylebox("scroll_focus", type_name, _flat(TRANSPARENT, TRANSPARENT, 0, 0, Vector4.ZERO))


func _build_tabs(theme: Theme) -> void:
	# 选中页只留一道金色下划线，像夹在纸页里的刀镡。
	var unselected := _flat(TRANSPARENT, TRANSPARENT, 0, 0, Vector4(14, 8, 14, 8))
	var hovered := _flat(Color(0.72, 0.80, 0.88, 0.06), TRANSPARENT, 0, 0, Vector4(14, 8, 14, 8))
	var selected := _flat(TRANSPARENT, GOLD, 0, 0, Vector4(14, 8, 14, 8))
	selected.border_width_bottom = 2
	var panel := _flat(Color(0.025, 0.045, 0.066, 0.97), TRANSPARENT, 0, 0, Vector4(14, 12, 14, 12))
	theme.set_stylebox("tab_unselected", "TabContainer", unselected)
	theme.set_stylebox("tab_hovered", "TabContainer", hovered)
	theme.set_stylebox("tab_selected", "TabContainer", selected)
	theme.set_stylebox("tab_disabled", "TabContainer", unselected)
	theme.set_stylebox("tab_focus", "TabContainer", _flat(TRANSPARENT, GOLD, 0, 0, Vector4(14, 8, 14, 8)))
	theme.set_stylebox("panel", "TabContainer", panel)
	for key in ["font_selected_color", "font_hovered_color", "font_unselected_color", "font_disabled_color"]:
		theme.set_color(key, "TabContainer", INK if not key.ends_with("disabled_color") else MUTED)
	theme.set_color("font_outline_color", "TabContainer", Color("#02050a"))
	theme.set_constant("outline_size", "TabContainer", 3)


func _flat(bg: Color, border: Color, border_width: int, radius: int, margins: Vector4) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margins.x
	box.content_margin_top = margins.y
	box.content_margin_right = margins.z
	box.content_margin_bottom = margins.w
	return box
