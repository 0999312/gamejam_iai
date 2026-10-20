extends GutTest

## RunState：金币、残心、HP 跨场、三选一与心得数据。

var run: RunState


func before_each() -> void:
	run = RunState.new(12345)


func test_run_starts_at_first_stage() -> void:
	assert_eq(run.stage_index, 0)
	assert_eq(run.player_hp, 3)
	assert_eq(run.gold, 0)
	assert_eq(run.zanshin, 0)
	assert_eq(run.phase, RunState.Phase.DUEL)
	assert_eq(run.enemy_data().max_hp, 3)


func test_win_awards_gold_and_zanshin_and_heals() -> void:
	run.player_hp = 2
	run.on_duel_finished(DuelTypes.Side.P1)
	assert_eq(run.gold, 14, "10 基础 + 2 HP×2")
	assert_eq(run.zanshin, 1)
	assert_eq(run.player_hp, 3, "每胜回复 1")
	assert_eq(run.phase, RunState.Phase.REWARD)
	assert_eq(run.offers.size(), 3)


func test_heal_bonus_upgrade_heals_two() -> void:
	run.upgrades.append(&"u10")
	run.player_hp = 1
	run.on_duel_finished(DuelTypes.Side.P1)
	assert_eq(run.player_hp, 3, "复元：每胜回复 2（1 + 2 被 max_hp 截到 3）")


func test_heal_bonus_is_capped_by_max_hp() -> void:
	run.upgrades.append(&"u10")
	run.player_hp = 3
	run.on_duel_finished(DuelTypes.Side.P1)
	assert_eq(run.player_hp, 3, "满血时复元不会溢出")


func test_flawless_win_awards_bonus() -> void:
	run.player_hp = 3
	run.on_duel_finished(DuelTypes.Side.P1)
	assert_eq(run.gold, 26, "10 + 无伤 10 + 3 HP×2")
	assert_eq(run.zanshin, 2)
	assert_true(run.last_flawless)


func test_loss_ends_run_without_gold_loss() -> void:
	run.gold = 40
	run.zanshin = 3
	run.player_hp = 1
	run.on_duel_finished(DuelTypes.Side.P2)
	assert_eq(run.phase, RunState.Phase.FAILED)
	assert_eq(run.gold, 40)
	assert_eq(run.zanshin, 0)


func test_apply_offer_advances_stage() -> void:
	run.on_duel_finished(DuelTypes.Side.P1)
	var chosen: StringName = run.offers[0]
	assert_true(run.apply_offer(0))
	assert_eq(run.stage_index, 1)
	assert_eq(run.phase, RunState.Phase.DUEL)
	assert_true(run.has_upgrade(chosen))
	assert_eq(run.offers.size(), 0)
	assert_eq(run.enemy_data().max_hp, 3)


func test_boss_clear_ends_run() -> void:
	run.stage_index = 4
	run.player_hp = 3
	run.on_duel_finished(DuelTypes.Side.P1)
	assert_eq(run.phase, RunState.Phase.CLEAR)
	assert_eq(run.gold, 56, "10 + 无伤 10 + 3 HP×2 + 关底 30")


func test_upgrade_data_modifiers() -> void:
	run.upgrades = [&"u01", &"u02", &"u04"]
	var data := run.player_data()
	assert_eq(data.guard_duration_base, 14)
	assert_eq(data.base_commit, 16)
	assert_eq(data.start_flow, 50)


func test_upgrade_runtime_mods() -> void:
	run.upgrades = [&"u03", &"u05", &"u06", &"u07", &"u08", &"u09"]
	var mods := run.mods()
	assert_eq(mods["perfect_gain"], 18)
	assert_true(mods["see_through"])
	assert_true(mods["pursuit"])
	assert_true(mods["guts"])
	assert_eq(mods["opening_commit"], -3)
	assert_eq(mods["hint_lead"], 4)


func test_zanshin_adds_starting_flow() -> void:
	run.zanshin = 2
	assert_eq(run.player_data().start_flow, 56)
	run.zanshin = 99
	assert_eq(run.player_data().start_flow, 64, "残心上限 3 层")


func test_zanshin_guarantees_flow_floor() -> void:
	var base := run.player_data()
	assert_eq(base.flow_floor, 15)
	assert_eq(base.flow_loss_reduction, 0, "没有残心时受击心流照常损失")

	run.zanshin = 3
	var reinforced := run.player_data()
	assert_eq(reinforced.flow_floor, 33, "3 层残心的下限直接越过最低档上限")
	assert_eq(reinforced.flow_loss_reduction, 9, "受击只掉 6 心流")
	assert_eq(reinforced.guard_duration_base, 15, "同时多 3f 架窗")


func test_restart_keeps_gold() -> void:
	run.gold = 77
	run.zanshin = 2
	run.stage_index = 3
	run.restart_run()
	assert_eq(run.gold, 77)
	assert_eq(run.stage_index, 0)
	assert_eq(run.zanshin, 0)
	assert_eq(run.player_hp, 3)
	assert_eq(run.phase, RunState.Phase.DUEL)
