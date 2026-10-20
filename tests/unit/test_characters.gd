extends GutTest

## 角色 B/C 的帧数据、HP 与 RunState 选择。


func test_character_b_is_faster_and_weaker() -> void:
	var a := FighterData.player_a()
	var b := FighterData.player_b()
	assert_eq(b.id, &"player_b")
	assert_lt(b.base_commit, a.base_commit)
	assert_lt(b.whiff_recovery, a.whiff_recovery)
	assert_lt(b.blocked_recovery, a.blocked_recovery)
	assert_true(b.start_flow >= a.start_flow)
	assert_eq(b.max_hp, 3)


func test_character_c_is_heavier() -> void:
	var a := FighterData.player_a()
	var c := FighterData.player_c()
	assert_eq(c.id, &"player_c")
	assert_gt(c.max_hp, a.max_hp)
	assert_gt(c.base_commit, a.base_commit)
	assert_gt(c.blocked_recovery, a.blocked_recovery)
	assert_lt(c.start_flow, a.start_flow)


func test_for_character_falls_back_to_a() -> void:
	assert_eq(FighterData.for_character(&"nope").id, &"player_a")
	assert_eq(FighterData.for_character(&"char_b").id, &"player_b")


func test_run_state_uses_selected_character() -> void:
	var meta := MetaSave.new()
	meta.add_unlock(&"char_c")
	var run := RunState.new(1, meta, &"char_c")
	assert_eq(run.player_data().id, &"player_c")
	assert_eq(run.max_hp, 4)
	assert_eq(run.player_hp, 4)


func test_start_slot_grants_one_upgrade() -> void:
	var meta := MetaSave.new()
	meta.add_unlock(&"start_slot")
	var run := RunState.new(1, meta, &"char_a")
	assert_eq(run.upgrades.size(), 1)
	assert_true(RunState.UPGRADE_IDS.has(run.upgrades[0]))
