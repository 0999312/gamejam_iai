extends GutTest

## 选择角色面板：单人只选 P1 角色；双人各自选角色与输入方式，支持双方手柄。

const SCENE := preload("res://scenes/ui/character_select.tscn")

var _panel: CharacterSelectPanel
var _old_meta: MetaSave
var _old_character: StringName
var _old_character_p2: StringName
var _old_input_p1: StringName
var _old_input_p2: StringName


func before_each() -> void:
	_old_meta = GameBootstrap.meta
	_old_character = GameBootstrap.pending_character
	_old_character_p2 = GameBootstrap.pending_character_p2
	_old_input_p1 = GameBootstrap.pending_input_p1
	_old_input_p2 = GameBootstrap.pending_input_p2
	GameBootstrap.meta = MetaSave.new()
	GameBootstrap.pending_character = &"char_a"
	GameBootstrap.pending_character_p2 = &"char_a"
	GameBootstrap.pending_input_p1 = &"keyboard"
	GameBootstrap.pending_input_p2 = &"keyboard"
	_panel = SCENE.instantiate() as CharacterSelectPanel
	add_child_autofree(_panel)
	await wait_process_frames(1)


func after_each() -> void:
	GameBootstrap.meta = _old_meta
	GameBootstrap.pending_character = _old_character
	GameBootstrap.pending_character_p2 = _old_character_p2
	GameBootstrap.pending_input_p1 = _old_input_p1
	GameBootstrap.pending_input_p2 = _old_input_p2


func test_solo_only_shows_p1_character() -> void:
	_panel._on_open({"mode": &"run"})
	await wait_process_frames(1)
	assert_not_null(_panel._p1_character, "单人也要选玩家角色")
	assert_null(_panel._p2_character, "单人不应出现 2P 角色")
	assert_null(_panel._p1_input, "单人不选输入方式")


func test_versus_has_two_characters_and_two_input_rows() -> void:
	_panel._on_open({"mode": &"versus"})
	await wait_process_frames(1)
	assert_not_null(_panel._p1_character)
	assert_not_null(_panel._p2_character)
	assert_not_null(_panel._p1_input)
	assert_not_null(_panel._p2_input)
	assert_eq(_panel._p1_input.item_count, 2, "输入方式只有键鼠 / 手柄")
	assert_eq(_panel._p2_input.item_count, 2)


func test_both_players_can_choose_gamepad() -> void:
	_panel._on_open({"mode": &"versus"})
	await wait_process_frames(1)

	_panel._p1_input.select(1)
	_panel._on_input_selected(1, _panel._p1_input)
	assert_eq(_panel._selected_input(_panel._p1_input), &"gamepad")
	assert_eq(_panel._selected_input(_panel._p2_input), &"keyboard", "P2 默认键鼠，但不被强制")

	_panel._p2_input.select(1)
	_panel._on_input_selected(1, _panel._p2_input)
	assert_eq(_panel._selected_input(_panel._p2_input), &"gamepad")
	assert_eq(_panel._selected_input(_panel._p1_input), &"gamepad", "双方手柄不能被互斥规则重置")


func test_confirm_writes_both_gamepads() -> void:
	_panel._on_open({"mode": &"versus"})
	await wait_process_frames(1)
	watch_signals(_panel)

	_panel._p1_input.select(1)
	_panel._on_input_selected(1, _panel._p1_input)
	_panel._p2_input.select(1)
	_panel._on_input_selected(1, _panel._p2_input)
	_panel._on_start_pressed()

	assert_signal_emitted(_panel, "character_confirmed")
	assert_eq(GameBootstrap.pending_input_p1, &"gamepad")
	assert_eq(GameBootstrap.pending_input_p2, &"gamepad")


func test_confirm_writes_pending_selection() -> void:
	_panel._on_open({"mode": &"versus"})
	await wait_process_frames(1)
	watch_signals(_panel)

	var p2_index := _panel._p2_character.item_count - 1
	_panel._p2_character.select(p2_index)
	var expected_p2 := StringName(_panel._p2_character.get_item_metadata(p2_index))
	_panel._p2_input.select(1)
	_panel._on_input_selected(1, _panel._p2_input)

	_panel._on_start_pressed()

	assert_signal_emitted(_panel, "character_confirmed")
	assert_eq(GameBootstrap.pending_character, &"char_a")
	assert_eq(GameBootstrap.pending_character_p2, expected_p2)
	assert_eq(GameBootstrap.pending_input_p1, &"keyboard")
	assert_eq(GameBootstrap.pending_input_p2, &"gamepad")
