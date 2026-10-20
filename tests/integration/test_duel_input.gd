extends GutTest

## 集成测试：验证 GUIDE 键位真的能驱动灰盒场景里的 DuelSim。
## 不依赖窗口；GUT headless 下 GUIDE autoload 必须存在。

const DUEL_SCENE := preload("res://scenes/duel/duel.tscn")

var _scene: Node
var _sim: DuelSim


func before_each() -> void:
	_scene = DUEL_SCENE.instantiate()
	add_child_autofree(_scene)
	await wait_process_frames(2)
	await wait_physics_frames(2)
	_sim = _scene.get("sim") as DuelSim
	assert_not_null(_sim, "场景应当创建 DuelSim")
	# 集成测试要立即输入，跳过开场「礼」。
	_sim.opening_lock_frames = 0


func _tap_key(key: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = key
	down.physical_keycode = key
	down.pressed = true
	GUIDE.inject_input(down)
	# GUIDE 在 _process 汇总输入并发出 just_triggered，必须等 process 帧。
	await wait_process_frames(2)
	await wait_physics_frames(2)

	var up := InputEventKey.new()
	up.keycode = key
	up.physical_keycode = key
	up.pressed = false
	GUIDE.inject_input(up)
	await wait_process_frames(1)
	await wait_physics_frames(1)


func test_attack_key_enters_commit_or_slash() -> void:
	await _tap_key(KEY_J)
	var state: int = _sim.p1.state
	assert_true(
		state == DuelTypes.State.COMMIT or state == DuelTypes.State.SLASH,
		"按 J 后玩家应进入 COMMIT 或 SLASH，实际=%s" % DuelTypes.state_name(state)
	)


func test_guard_key_enters_guard() -> void:
	await _tap_key(KEY_K)
	assert_eq(
		_sim.p1.state,
		DuelTypes.State.GUARD,
		"按 K 后玩家应进入 GUARD"
	)


func test_teaching_ai_waits_during_opening_grace() -> void:
	await wait_physics_frames(30)
	assert_eq(
		_sim.p2.state,
		DuelTypes.State.IDLE,
		"教学对手在开场礼让帧内不应行动"
	)


func test_remapped_attack_key_drives_duel() -> void:
	var old_meta := GameBootstrap.meta
	GameBootstrap.meta = MetaSave.new()
	# 用一个没有默认绑定的键，避免和默认符卡键（L）撞车。
	KeyBindings.set_key(GameBootstrap.meta, &"attack_p1", KEY_Y)

	var scene := DUEL_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(2)
	await wait_physics_frames(2)
	var sim := scene.get("sim") as DuelSim
	sim.opening_lock_frames = 0

	var down := InputEventKey.new()
	down.keycode = KEY_Y
	down.physical_keycode = KEY_Y
	down.pressed = true
	GUIDE.inject_input(down)
	await wait_process_frames(2)
	await wait_physics_frames(2)

	assert_true(
		sim.p1.state == DuelTypes.State.COMMIT or sim.p1.state == DuelTypes.State.SLASH,
		"改键后按 Y 应进入 COMMIT 或 SLASH，实际=%s" % DuelTypes.state_name(sim.p1.state)
	)
	GameBootstrap.meta = old_meta
