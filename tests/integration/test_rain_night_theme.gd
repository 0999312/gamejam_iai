extends GutTest

## 雨夜主题契约：深色纸面、无边框、亮字 + 强描边、刀鞘金焦点；项目设置必须指向它。
## 只断言可感知的样式，不复制生成器里的每个色值。

const THEME_PATH := "res://assets/theme/rain_night.tres"


func test_project_uses_the_rain_night_theme() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom"), THEME_PATH)
	var theme := load(THEME_PATH) as Theme
	assert_not_null(theme)
	assert_eq(theme.default_font_size, 18)


func test_label_text_is_bright_with_a_dark_outline() -> void:
	var theme := load(THEME_PATH) as Theme
	var ink := theme.get_color("font_color", "Label")
	var outline := theme.get_color("font_outline_color", "Label")
	assert_gt(ink.get_luminance(), 0.8, "正文必须接近白色")
	assert_lt(outline.get_luminance(), 0.05, "描边必须接近黑色")
	assert_gte(theme.get_constant("outline_size", "Label"), 4,
		"雨线会从文字后穿过，Label 至少 4px 描边")


func test_button_surface_is_borderless_and_focus_is_a_gold_underline() -> void:
	var theme := load(THEME_PATH) as Theme
	var normal := theme.get_stylebox("normal", "Button") as StyleBoxFlat
	var focus := theme.get_stylebox("focus", "Button") as StyleBoxFlat
	assert_not_null(normal)
	assert_not_null(focus)
	assert_almost_eq(normal.bg_color.a, 0.0, 0.01, "普通按钮必须完全透明，不能回到卡片框")
	assert_eq(focus.border_width_left, 0, "焦点不再画左侧竖条")
	assert_eq(focus.border_width_bottom, 2, "焦点只用底边一道 2px 金线")
	assert_gt(focus.border_color.r, focus.border_color.b, "焦点边应为暖金而非冷蓝")


func test_progress_fill_is_light_enough_to_modulate() -> void:
	var theme := load(THEME_PATH) as Theme
	var fill := theme.get_stylebox("fill", "ProgressBar") as StyleBoxFlat
	assert_not_null(fill)
	assert_gt(fill.bg_color.get_luminance(), 0.75, "心流条靠 modulate 染色，底色必须接近白")


func test_check_button_icon_is_scaled_for_dark_rows() -> void:
	var theme := load(THEME_PATH) as Theme
	assert_gte(theme.get_constant("icon_max_width", "CheckButton"), 20)
	assert_gt(theme.get_color("icon_normal_color", "CheckButton").r, 0.5)
	assert_gt(theme.get_color("font_pressed_color", "CheckButton").r, 0.5,
		"开启状态必须靠暖金文字与图标一起区分")
