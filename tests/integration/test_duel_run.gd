extends GutTest

## 对决场景的 M2 串联：胜利结算 → 三选一 → 下一场；失败 → R 重开。

var ctrl
var _old_meta: MetaSave


func before_each() -> void:
	_old_meta = GameBootstrap.meta
	GameBootstrap.meta = MetaSave.new()
	ctrl = preload("res://scenes/duel/duel.tscn").instantiate()
	add_child_autofree(ctrl)
	await wait_process_frames(2)
	await wait_physics_frames(2)


func after_each() -> void:
	GameBootstrap.meta = _old_meta


func test_win_settles_and_shows_rewards() -> void:
	ctrl.run.player_hp = 2
	ctrl.sim.p1.hp = 2
	ctrl.sim.p2.hp = 0
	ctrl.sim.finished = true
	ctrl.sim.winner = DuelTypes.Side.P1
	await wait_physics_frames(2)

	assert_eq(ctrl.run.phase, RunState.Phase.REWARD)
	assert_eq(ctrl.run.gold, 14)
	assert_eq(ctrl.run.player_hp, 3)
	assert_eq(ctrl.run.offers.size(), 3)
	assert_true(ctrl._hud._reward_box.visible)


func test_choose_offer_starts_next_stage() -> void:
	ctrl.sim.p2.hp = 0
	ctrl.sim.finished = true
	ctrl.sim.winner = DuelTypes.Side.P1
	await wait_physics_frames(2)

	ctrl._on_offer_chosen(0)
	await wait_physics_frames(1)
	assert_eq(ctrl.run.stage_index, 1)
	assert_eq(ctrl.run.phase, RunState.Phase.DUEL)
	assert_eq(ctrl.sim.p2.data.max_hp, 3)
	assert_eq(ctrl.sim.p1.hp, 3)


func test_loss_then_restart_keeps_gold() -> void:
	ctrl.run.gold = 30
	ctrl.sim.p1.hp = 0
	ctrl.sim.p2.hp = 2
	ctrl.sim.finished = true
	ctrl.sim.winner = DuelTypes.Side.P2
	await wait_physics_frames(2)

	assert_eq(ctrl.run.phase, RunState.Phase.FAILED)
	ctrl._on_restart_pressed()
	await wait_physics_frames(2)

	assert_eq(ctrl.run.stage_index, 0)
	assert_eq(ctrl.run.gold, 30)
	assert_eq(ctrl.run.phase, RunState.Phase.DUEL)
	assert_eq(ctrl.sim.p1.hp, 3)
