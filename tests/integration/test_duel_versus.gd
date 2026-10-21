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


func test_versus_restart_keeps_mode() -> void:
	_controller.sim.opening_lock_frames = 0
	_controller.sim.p2.hp = 0
	_controller.sim.finished = true
	_controller.sim.winner = DuelTypes.Side.P1
	_controller._on_restart_pressed()
	await wait_physics_frames(3)
	assert_not_null(_controller.sim)
	assert_eq(_controller.sim.p2.hp, 30)
