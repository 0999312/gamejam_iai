extends GutTest

## 按键绑定：默认值、改键、冲突、恢复默认。


func test_defaults_are_available() -> void:
	var meta := MetaSave.new()
	assert_true(KeyBindings.get_keys(meta, &"attack_p1").has(KEY_J))
	assert_true(KeyBindings.get_keys(meta, &"guard_p1").has(KEY_K))
	assert_true(KeyBindings.get_keys(meta, &"attack_p2").has(KEY_KP_1))
	assert_false(KeyBindings.label(meta, &"attack_p1").is_empty())


func test_set_key_persists_to_settings() -> void:
	var meta := MetaSave.new()
	assert_true(KeyBindings.set_key(meta, &"attack_p1", KEY_Y))
	assert_true(KeyBindings.get_keys(meta, &"attack_p1").has(KEY_Y))
	assert_true(meta.settings["keys"].has("attack_p1"))


func test_conflicting_key_is_rejected() -> void:
	var meta := MetaSave.new()
	assert_false(KeyBindings.set_key(meta, &"guard_p1", KEY_J))
	assert_true(KeyBindings.get_keys(meta, &"guard_p1").has(KEY_K))


func test_reset_restores_defaults() -> void:
	var meta := MetaSave.new()
	KeyBindings.set_key(meta, &"attack_p1", KEY_Y)
	KeyBindings.reset(meta)
	assert_true(KeyBindings.get_keys(meta, &"attack_p1").has(KEY_J))
	assert_false(KeyBindings.get_keys(meta, &"attack_p1").has(KEY_Y))


func test_gamepad_defaults() -> void:
	var meta := MetaSave.new()
	assert_eq(KeyBindings.get_joy_button(meta, &"attack_p1"), JOY_BUTTON_A)
	assert_eq(KeyBindings.get_joy_button(meta, &"guard_p1"), JOY_BUTTON_B)
	assert_eq(KeyBindings.get_joy_button(meta, &"pause"), JOY_BUTTON_START)
	assert_false(KeyBindings.label_joy(meta, &"attack_p1").is_empty())


func test_gamepad_rebind_persists() -> void:
	var meta := MetaSave.new()
	assert_true(KeyBindings.set_joy_button(meta, &"guard_p1", JOY_BUTTON_X))
	assert_eq(KeyBindings.get_joy_button(meta, &"guard_p1"), JOY_BUTTON_X)
	assert_eq(KeyBindings.label_joy(meta, &"guard_p1"), "X")


func test_gamepad_conflict_within_player_scope() -> void:
	var meta := MetaSave.new()
	assert_false(KeyBindings.set_joy_button(meta, &"guard_p1", JOY_BUTTON_A))
	assert_true(KeyBindings.set_joy_button(meta, &"attack_p2", JOY_BUTTON_A))


func test_gamepad_global_conflicts_with_players() -> void:
	var meta := MetaSave.new()
	assert_false(KeyBindings.set_joy_button(meta, &"pause", JOY_BUTTON_A))
	assert_false(KeyBindings.set_joy_button(meta, &"restart", JOY_BUTTON_B))


func test_gamepad_reset_restores_defaults() -> void:
	var meta := MetaSave.new()
	KeyBindings.set_joy_button(meta, &"guard_p1", JOY_BUTTON_X)
	KeyBindings.reset(meta)
	assert_eq(KeyBindings.get_joy_button(meta, &"guard_p1"), JOY_BUTTON_B)
