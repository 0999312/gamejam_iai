extends GutTest

## 主菜单：金币显示、四个一级入口、模式选择已收进二级面板。
## 2026-10-21：原先六个按钮竖排会与标题 / 副标题重叠（用户反馈），
## 「本地双人」并入模式选择面板、「关于」移入设置页。

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
	# 4 个入口按钮（开始 / 商店 / 设置 / 退出）+ 角色 OptionButton（继承 Button）。
	assert_eq(buttons.size(), 5, "主菜单应只有四个一级入口")
	var texts: Array[String] = []
	for button in buttons:
		texts.append((button as Button).text)
	assert_true(texts.has("开始游戏"), "开始入口应打开模式选择面板")
	assert_true(texts.has("商店 / 解锁"))
	assert_true(texts.has("设置"))
	assert_true(texts.has("退出"))
	assert_false(texts.has("本地双人"), "本地双人已并入模式选择面板")
	assert_false(texts.has("关于"), "关于已移入设置页")


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
