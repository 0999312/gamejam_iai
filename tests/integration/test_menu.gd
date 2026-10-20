extends GutTest

## 主菜单：金币显示、三个入口按钮、占位文本已走 I18N。

const MENU_SCENE := preload("res://scenes/menu/menu.tscn")

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


func test_menu_shows_gold_and_five_entries() -> void:
	assert_string_contains(_menu._gold_label.text, "7")
	var buttons := _menu.find_children("*", "Button", true, false)
	# 5 个入口按钮 + 角色 OptionButton（OptionButton 继承 Button）。
	assert_true(buttons.size() >= 5)
	var has_shop := false
	var has_settings := false
	for button in buttons:
		assert_string_contains((button as Button).text, "[占位]")
		if (button as Button).text.contains("商店"):
			has_shop = true
		if (button as Button).text.contains("设置"):
			has_settings = true
	assert_true(has_shop)
	assert_true(has_settings)
