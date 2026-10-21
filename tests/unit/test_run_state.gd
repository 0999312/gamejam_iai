extends GutTest

## RunState：金币、残心、HP 跨场、三选一、心得数据与难度双档。
## 自平衡 02 起：血量 ×10（30/40），金币与回复都按血量比例结算。

var run: RunState


func before_each() -> void:
	run = RunState.new(12345)


func test_run_starts_at_first_stage() -> void:
	assert_eq(run.stage_index, 0)
	assert_eq(run.player_hp, 30)
	assert_eq(run.max_hp, 30)
	assert_eq(run.gold, 0)
	assert_eq(run.zanshin, 0)
	assert_eq(run.phase, RunState.Phase.DUEL)
	assert_eq(run.enemy_data().max_hp, 30)


func test_win_awards_gold_and_zanshin_and_heals() -> void:
	run.player_hp = 10
	run.on_duel_finished(DuelTypes.Side.P1)
	assert_eq(run.gold, 12, "10 基础 + 残血 1/3 → 2")
	assert_eq(run.zanshin, 1)
	assert_eq(run.player_hp, 20, "治疗 = 1/3 最大血量")
	assert_eq(run.phase, RunState.Phase.REWARD)
	assert_eq(run.offers.size(), 3)


func test_heal_bonus_upgrade_heals_two() -> void:
	run.upgrades.append(&"u10")
	run.player_hp = 1
	run.on_duel_finished(DuelTypes.Side.P1)
	assert_eq(run.player_hp, 21, "复元：治疗翻倍（10 → 20）")


func test_heal_bonus_is_capped_by_max_hp() -> void:
	run.upgrades.append(&"u10")
	run.player_hp = 30
	run.on_duel_finished(DuelTypes.Side.P1)
	assert_eq(run.player_hp, 30, "满血时复元不会溢出")


func test_flawless_win_awards_bonus() -> void:
	run.player_hp = 30
	run.on_duel_finished(DuelTypes.Side.P1)
	assert_eq(run.gold, 26, "10 + 无伤 10 + 满血 6")
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
	assert_eq(run.enemy_data().max_hp, 30)


func test_boss_clear_ends_run() -> void:
	run.stage_index = 4
	run.player_hp = 30
	run.on_duel_finished(DuelTypes.Side.P1)
	assert_eq(run.phase, RunState.Phase.CLEAR)
	assert_eq(run.gold, 56, "10 + 无伤 10 + 满血 6 + 关底 30")


func test_upgrade_data_modifiers() -> void:
	run.upgrades = [&"u01", &"u02", &"u04"]
	var data := run.player_data()
	assert_eq(data.guard_duration_base, 27)
	assert_eq(data.base_commit, 11, "基础 14f − 心得 3f")
	assert_eq(data.start_flow, 50)


func test_upgrade_runtime_mods() -> void:
	run.upgrades = [&"u03", &"u05", &"u06", &"u07", &"u08", &"u09"]
	var mods := run.mods()
	assert_eq(mods["perfect_gain"], 18)
	assert_true(mods["see_through"])
	assert_true(mods["pursuit"])
	assert_true(mods["guts"])
	assert_eq(mods["opening_commit"], -3)
	assert_eq(mods["hint_lead"], 6)


func test_zanshin_adds_starting_flow() -> void:
	run.zanshin = 2
	assert_eq(run.player_data().start_flow, 56)
	run.zanshin = 99
	assert_eq(run.player_data().start_flow, 64, "残心上限 3 层")


func test_zanshin_guarantees_flow_floor() -> void:
	var base := run.player_data()
	assert_eq(base.flow_floor, 15)
	assert_eq(base.flow_loss_reduction, 0, "没有残心时受击心流照常损失")
	assert_eq(base.riposte_commit_bonus, -4, "反斩是基础增强：-4f")

	run.zanshin = 3
	var reinforced := run.player_data()
	assert_eq(reinforced.flow_floor, 33, "3 层残心的下限直接越过最低档上限")
	assert_eq(reinforced.flow_loss_reduction, 9, "受击只掉 6 心流")
	assert_eq(reinforced.guard_duration_base, 27, "同时多 3f 架窗")
	assert_eq(reinforced.riposte_commit_bonus, -10, "反斩随残心成长到 -10f")


func test_restart_keeps_gold() -> void:
	run.gold = 77
	run.zanshin = 2
	run.stage_index = 3
	run.restart_run()
	assert_eq(run.gold, 77)
	assert_eq(run.stage_index, 0)
	assert_eq(run.zanshin, 0)
	assert_eq(run.player_hp, 30)
	assert_eq(run.phase, RunState.Phase.DUEL)


func test_normal_mode_is_the_new_default() -> void:
	# 反馈 2：现在的节奏当作困难模式，默认档要更宽松。
	assert_eq(run.difficulty_tier(), AiProfile.TIER_NORMAL)
	var normal := run.enemy_profile()
	var hard_run := RunState.new(12345, MetaSave.new(), &"char_a", true)
	var hard := hard_run.enemy_profile()
	assert_eq(hard_run.difficulty_tier(), AiProfile.TIER_HARD)
	assert_lt(normal.aggression, hard.aggression, "默认档的对手更保守")
	assert_lt(normal.decision_interval, hard.decision_interval,
			"默认档决策更勤：前摇拉长后用更快的判断补回节奏")
	assert_gt(normal.guard_chance, hard.guard_chance, "默认档更愿意架")


func test_hard_mode_rolls_back_legacy_numbers() -> void:
	var hard := RunState.new(12345, MetaSave.new(), &"char_a", true)
	assert_eq(hard.player_data().guard_duration_base, 12, "困难档沿用 02 之前的架窗")
	assert_eq(hard.enemy_data().base_commit, 20, "困难档沿用 02 之前的前摇")
	assert_eq(hard.enemy_data().max_hp, 40, "对手血量同样 ×10 再加困难档")


func test_build_match_wires_both_characters() -> void:
	# 多角色基础：一场对局 = 两个角色 + 一个性格，谁都能当 P1。
	var setup := run.build_match()
	assert_eq(setup.p1_character_id(), &"char_a")
	assert_eq(setup.p2_character_id(), FighterData.stage_enemy_id(0))
	assert_not_null(setup.p2_profile)
	assert_false(setup.is_hard())
	var swapped := setup.swapped()
	assert_eq(swapped.p1_character_id(), setup.p2_character_id())
	assert_eq(swapped.p2_character_id(), setup.p1_character_id())
