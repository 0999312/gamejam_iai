extends GutTest

## 主菜单：金币显示、四个一级入口、模式/角色选择已收进二级面板。
## 2026-10-21：原先六个按钮竖排会与标题 / 副标题重叠（用户反馈），
## 「本地双人」并入模式选择面板、「关于」移入设置页。
## 2026-11-05：角色选择也从主菜单抽到「选择角色」面板。

const MENU_SCENE := preload("res://scenes/menu/menu.tscn")
const MODE_SCENE := preload("res://scenes/ui/mode_select.tscn")

var _old_meta: MetaSave
var _menu: Control


func before_each() -> void:
	_old_meta = GameBootstrap.meta
	GameBootstrap.meta = MetaSave.new()
	GameBootstrap.meta.gold = 7
	_menu = MENU_SCENE.instantiate() as Control
	add_child_autofree(_menu)
	await wait_process_frames(1)


func after_each() -> void:
	GameBootstrap.meta = _old_meta


func test_menu_shows_gold_and_four_entries() -> void:
	assert_string_contains(_menu._gold_label.text, "7")
	var buttons := _menu.find_children("*", "Button", true, false)
	# 4 个入口按钮（开始 / 商店 / 设置 / 退出）；角色选择已移入二级面板。
	assert_eq(buttons.size(), 4, "主菜单应只有四个一级入口")
	var texts: Array[String] = []
	for button in buttons:
		texts.append((button as Button).text)
	assert_true(texts.has("开始游戏"), "开始入口应打开模式选择面板")
	assert_true(texts.has("商店 / 解锁"))
	assert_true(texts.has("设置"))
	assert_true(texts.has("退出"))
	assert_false(texts.has("本地双人"), "本地双人已并入模式选择面板")
	assert_false(texts.has("关于"), "关于已移入设置页")
	assert_false(texts.has("角色"), "角色选择已移入选择角色面板")


func test_menu_has_a_full_screen_rainy_night_backdrop() -> void:
	var bg := _menu.get("_background") as ColorRect
	assert_not_null(bg, "主菜单必须有雨夜背景层")
	assert_eq(bg.get_parent(), _menu)
	assert_eq(bg.get_index(), 0, "背景必须是第一个子节点，标题/按钮压在它上面")
	assert_eq(bg.size, Vector2(1280, 720), "背景铺满 1280×720 画布")
	assert_true(bg.show_behind_parent)
	assert_lt(bg.z_index, 0, "背景不能盖住 UI")
	assert_eq(bg.mouse_filter, Control.MOUSE_FILTER_IGNORE, "背景不得拦截菜单点击")
	var mat := bg.material as ShaderMaterial
	assert_not_null(mat)
	assert_eq(mat.shader.resource_path, "res://resources/shaders/rainy_night.gdshader")
	assert_almost_eq(float(mat.get_shader_parameter("ground_y")), 0.96, 0.0001,
			"菜单地平线压到底部提示下方")
	assert_almost_eq(float(mat.get_shader_parameter("pool_strength")), 0.0, 0.0001,
			"菜单没有角色，不应出现脚下湿反光")


func test_mode_select_panel_emits_mode() -> void:
	var panel := MODE_SCENE.instantiate() as ModeSelectPanel
	add_child_autofree(panel)
	await wait_process_frames(1)
	watch_signals(panel)
	panel._on_solo_pressed()
	assert_signal_emitted_with_parameters(panel, "mode_chosen", [&"run"])
	panel._on_versus_pressed()
	assert_signal_emitted_with_parameters(panel, "mode_chosen", [&"versus"])


func test_mode_select_panel_has_three_buttons() -> void:
	var panel := MODE_SCENE.instantiate() as ModeSelectPanel
	add_child_autofree(panel)
	await wait_process_frames(1)
	var texts: Array[String] = []
	for node in panel.find_children("*", "Button", true, false):
		texts.append((node as Button).text)
	assert_true(texts.has("单人阶梯"))
	assert_true(texts.has("本地双人"))
	assert_true(texts.has("返回"))
