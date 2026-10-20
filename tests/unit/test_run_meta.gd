extends GutTest

## RunState 与局外存档的联动：金币带入、胜利同步、失败/通关统计。


func test_gold_loads_from_meta() -> void:
	var meta := MetaSave.new()
	meta.gold = 55
	var run := RunState.new(1, meta)
	assert_eq(run.gold, 55)


func test_win_syncs_gold_to_meta() -> void:
	var meta := MetaSave.new()
	var run := RunState.new(1, meta)
	run.player_hp = 3
	run.on_duel_finished(DuelTypes.Side.P1)
	assert_eq(meta.gold, run.gold)
	assert_gt(meta.gold, 0)


func test_loss_records_run_without_taking_gold() -> void:
	var meta := MetaSave.new()
	meta.gold = 30
	var run := RunState.new(1, meta)
	run.stage_index = 2
	run.on_duel_finished(DuelTypes.Side.P2)
	assert_eq(run.gold, 30)
	assert_eq(meta.stats["runs"], 1)
	assert_eq(meta.stats["best_index"], 3)
	assert_eq(meta.stats["clears"], 0)


func test_clear_records_clear() -> void:
	var meta := MetaSave.new()
	var run := RunState.new(1, meta)
	run.stage_index = RunState.STAGE_COUNT - 1
	run.player_hp = 3
	run.on_duel_finished(DuelTypes.Side.P1)
	assert_eq(meta.stats["clears"], 1)
	assert_eq(meta.stats["best_index"], 5)


func test_new_run_after_meta_gold_is_loaded() -> void:
	var meta := MetaSave.new()
	meta.gold = 12
	var first := RunState.new(1, meta)
	first.player_hp = 3
	first.on_duel_finished(DuelTypes.Side.P1)
	var second := RunState.new(2, meta)
	assert_eq(second.gold, meta.gold)
	assert_gt(second.gold, 12)
