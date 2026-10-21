extends GutTest

## 角色 A/B/C 的帧数据、HP 与 RunState 选择。
## 自平衡 02 起：id 统一为 char_*（对手为 opponent_*），血量 ×10。


func test_character_b_is_faster_and_weaker() -> void:
	var a := FighterData.for_character(&"char_a")
	var b := FighterData.for_character(&"char_b")
	assert_eq(b.id, &"char_b")
	assert_lt(b.base_commit, a.base_commit)
	assert_lt(b.whiff_recovery, a.whiff_recovery)
	assert_lt(b.blocked_recovery, a.blocked_recovery)
	assert_lt(b.hit_damage, a.hit_damage)
	assert_true(b.start_flow >= a.start_flow)
	# 快剑不靠加血补偿：血量与均衡一致，弱项用伤害与帧数表达。
	assert_eq(b.max_hp, a.max_hp)
	assert_eq(b.max_hp, 30)


func test_character_c_is_heavier() -> void:
	var a := FighterData.for_character(&"char_a")
	var c := FighterData.for_character(&"char_c")
	assert_eq(c.id, &"char_c")
	assert_gt(c.max_hp, a.max_hp)
	assert_eq(c.max_hp, 40)
	assert_gt(c.base_commit, a.base_commit)
	assert_gt(c.blocked_recovery, a.blocked_recovery)
	assert_lt(c.start_flow, a.start_flow)
	assert_gt(c.hit_damage, a.hit_damage)


func test_damage_is_scaled_with_hp() -> void:
	# 血量 ×10 后伤害同步放大：10 / 7 / 15 是「几刀带走」的手感标定。
	assert_eq(FighterData.for_character(&"char_a").hit_damage, 10)
	assert_eq(FighterData.for_character(&"char_b").hit_damage, 7)
	assert_eq(FighterData.for_character(&"char_c").hit_damage, 15)


func test_guard_window_is_per_character() -> void:
	# 反馈 1：架窗差异是做角色身份的主要手段（宽 → 好防，窄 → 靠猜）。
	var a := FighterData.for_character(&"char_a").guard_duration_base
	var b := FighterData.for_character(&"char_b").guard_duration_base
	var c := FighterData.for_character(&"char_c").guard_duration_base
	assert_gt(a, b)
	assert_gt(c, a)


func test_for_character_falls_back_to_a() -> void:
	assert_eq(FighterData.for_character(&"nope").id, &"char_a")
	assert_eq(FighterData.for_character(&"char_b").id, &"char_b")


func test_opponents_are_characters_too() -> void:
	# 多角色基础：对手也是完整角色，可以用同一个工厂造出来当 P1。
	for id in FighterData.ALL_IDS:
		var data := FighterData.for_character(id)
		assert_eq(data.id, id, "%s 应当能从 for_character 取到" % id)
		assert_true(data.max_hp > 0)
	var boss := FighterData.for_character(&"opponent_5_boss")
	assert_eq(boss.spell_id, &"spell_boss")
	assert_ne(boss.persona_id, &"")
	# 对手不吃「流」档加速，否则玩家看不清前摇。
	assert_false(boss.flow_speeds_commit)


func test_stage_enemy_ids_are_stable() -> void:
	var ids: Array[StringName] = []
	for stage in RunState.STAGE_COUNT:
		ids.append(FighterData.stage_enemy_id(stage))
	assert_eq(ids.size(), RunState.STAGE_COUNT)
	for id in ids:
		assert_true(FighterData.ALL_IDS.has(id), "%s 应当是已注册角色" % id)


func test_run_state_uses_selected_character() -> void:
	var meta := MetaSave.new()
	meta.add_unlock(&"char_c")
	var run := RunState.new(1, meta, &"char_c")
	assert_eq(run.player_data().id, &"char_c")
	assert_eq(run.max_hp, 40)
	assert_eq(run.player_hp, 40)


func test_run_state_roster_respects_unlocks() -> void:
	var meta := MetaSave.new()
	var run := RunState.new(1, meta, &"char_a")
	assert_eq(run.roster(), [&"char_a"] as Array[StringName])
	# 未解锁的角色不能被选中。
	assert_false(run.select_character(&"char_c"))
	assert_eq(run.character_id, &"char_a")
	meta.add_unlock(&"char_c")
	assert_true(run.select_character(&"char_c"))
	assert_eq(run.character_id, &"char_c")
	assert_true(run.roster().has(&"char_c"))


func test_stage_cast_lists_both_sides() -> void:
	# 「每局其实就是两种可操作角色的博弈」：一场对局的两个角色都能拿到。
	var run := RunState.new(1, MetaSave.new(), &"char_a")
	var cast := run.stage_cast(4)
	assert_eq(cast.size(), 2)
	assert_eq(cast[0], &"char_a")
	assert_eq(cast[1], FighterData.stage_enemy_id(4))


func test_start_slot_grants_one_upgrade() -> void:
	var meta := MetaSave.new()
	meta.add_unlock(&"start_slot")
	var run := RunState.new(1, meta, &"char_a")
	assert_eq(run.upgrades.size(), 1)
	assert_true(RunState.UPGRADE_IDS.has(run.upgrades[0]))
