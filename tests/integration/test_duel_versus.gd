extends GutTest

## 本地双人：同一场景切换模式，P1/P2 都走人类输入。

const DUEL_SCENE := preload("res://scenes/duel/duel.tscn")

var _controller: Node2D


func before_each() -> void:
	GameBootstrap.pending_mode = &"versus"
	_controller = DUEL_SCENE.instantiate() as Node2D
	add_child_autofree(_controller)
	await wait_physics_frames(2)


func after_each() -> void:
	GameBootstrap.pending_mode = &"run"
	GameBootstrap.pending_character = &"char_a"
	GameBootstrap.pending_character_p2 = &"char_a"
	GameBootstrap.pending_input_p1 = &"keyboard"
	GameBootstrap.pending_input_p2 = &"keyboard"


func test_versus_has_no_run_and_both_same_hp() -> void:
	assert_null(_controller.run)
	assert_not_null(_controller.sim)
	assert_eq(_controller.sim.p1.hp, 30)
	assert_eq(_controller.sim.p2.hp, 30)
	assert_true(_controller._hud.versus)


func test_p2_can_commit() -> void:
	_controller.sim.opening_lock_frames = 0
	_controller._on_p2_attack_pressed()
	await wait_physics_frames(2)
	assert_eq(_controller.sim.p2.state, DuelTypes.State.COMMIT)


func test_versus_uses_each_players_character() -> void:
	GameBootstrap.pending_character = &"char_a"
	GameBootstrap.pending_character_p2 = &"char_c"
	_controller._start_versus()
	assert_eq(_controller.sim.p1.data.id, &"char_a")
	assert_eq(_controller.sim.p2.data.id, &"char_c")
	assert_eq(_controller.sim.p1.hp, 30)
	assert_eq(_controller.sim.p2.hp, 40)


func test_gamepad_assignment_resolution_supports_two_pads() -> void:
	assert_eq(_controller._resolve_gamepad_assignment(false, false, 2), Vector2i.ZERO)
	assert_eq(_controller._resolve_gamepad_assignment(true, false, 0), Vector2i.ZERO)
	assert_eq(_controller._resolve_gamepad_assignment(true, false, 1), Vector2i(1, 0))
	assert_eq(_controller._resolve_gamepad_assignment(false, true, 1), Vector2i(0, 1))
	assert_eq(_controller._resolve_gamepad_assignment(true, true, 1), Vector2i(1, 0))
	assert_eq(_controller._resolve_gamepad_assignment(true, true, 2), Vector2i(1, 1))


func test_both_gamepad_preferences_are_kept() -> void:
	GameBootstrap.pending_input_p1 = &"gamepad"
	GameBootstrap.pending_input_p2 = &"gamepad"
	_controller._read_input_assignment()
	assert_true(_controller._p1_wants_gamepad)
	assert_true(_controller._p2_wants_gamepad, "不能再用互斥规则否定 P2 手柄")


func test_versus_restart_keeps_mode() -> void:
	_controller.sim.opening_lock_frames = 0
	_controller.sim.p2.hp = 0
	_controller.sim.finished = true
	_controller.sim.winner = DuelTypes.Side.P1
	_controller._on_restart_pressed()
	await wait_physics_frames(3)
	assert_not_null(_controller.sim)
	assert_eq(_controller.sim.p2.hp, 30)
