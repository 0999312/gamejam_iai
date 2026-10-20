extends GutTest

## HUD 三选一与运行信息（不依赖真实输入）。


func _make_hud() -> DuelHud:
	var hud := preload("res://scenes/duel/hud.tscn").instantiate() as DuelHud
	add_child_autofree(hud)
	return hud


func test_reward_buttons_show_offers_and_emit() -> void:
	var hud := _make_hud()
	await wait_process_frames(1)
	var run := RunState.new(1)
	run.phase = RunState.Phase.REWARD
	run.offers = [&"u01", &"u02", &"u03"]
	var sim := DuelSim.new(FighterData.player_a(), FighterData.player_a(), 1)
	hud.set_run(run)
	hud.bind(sim)

	watch_signals(hud)
	hud.show_rewards(run.offers)
	assert_true(hud._reward_box.visible)
	assert_true(hud._reward_buttons[0].text.begins_with("1. [占位]"))
	assert_eq(hud._reward_buttons[0].visible, true)

	hud._reward_buttons[1].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "offer_chosen", [1])


func test_result_text_for_loss() -> void:
	var hud := _make_hud()
	await wait_process_frames(1)
	var run := RunState.new(1)
	run.phase = RunState.Phase.FAILED
	var sim := DuelSim.new(FighterData.player_a(), FighterData.player_a(), 1)
	sim.p1.hp = 0
	sim.finished = true
	sim.winner = DuelTypes.Side.P2
	hud.set_run(run)
	hud.bind(sim)
	assert_true(hud._result.visible)
	assert_eq(hud._result.text, "败北")


func test_start_cue_visible_after_opening_lock() -> void:
	var hud := _make_hud()
	await wait_process_frames(1)
	var sim := DuelSim.new(FighterData.player_a(), FighterData.player_a(), 1)
	sim.opening_lock_frames = 180
	sim.frame = 200
	hud.bind(sim)
	hud.refresh()
	assert_true(hud._start_cue.visible)
	assert_eq(hud._start_cue.text, "开始")
