extends GutTest

## HUD 三选一与运行信息（不依赖真实输入）。


func _make_hud() -> DuelHud:
	var hud := preload("res://scenes/duel/hud.tscn").instantiate() as DuelHud
	add_child_autofree(hud)
	return hud


## 收集 HUD 当前所有可见 Label 的文本，用于断言「任何位置都不出现某词」。
func _hud_texts(hud: DuelHud) -> Array[String]:
	var texts: Array[String] = []
	for node in hud.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.visible:
			texts.append(label.text)
	return texts


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
	assert_true(hud._reward_buttons[0].text.begins_with("1. 铁壁"))
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


func test_scrims_soften_the_rain_behind_hud_bands() -> void:
	var hud := _make_hud()
	await wait_process_frames(1)
	var root := hud.get_child(0) as Control
	var top := hud.get("_top_scrim") as TextureRect
	var bottom := hud.get("_bottom_scrim") as TextureRect
	assert_not_null(top)
	assert_not_null(bottom)
	assert_eq(top.get_parent(), root)
	assert_eq(bottom.get_parent(), root)

	assert_eq(top.position, Vector2.ZERO)
	assert_eq(top.size, Vector2(1280, 190))
	assert_eq(bottom.position, Vector2(0, 600))
	assert_eq(bottom.size, Vector2(1280, 120))
	assert_eq(top.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(bottom.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	var top_tex := top.texture as GradientTexture2D
	var bottom_tex := bottom.texture as GradientTexture2D
	assert_not_null(top_tex)
	assert_not_null(bottom_tex)
	assert_almost_eq(top_tex.gradient.colors[0].a, 0.66, 0.01)
	assert_almost_eq(top_tex.gradient.colors[1].a, 0.0, 0.01)
	assert_almost_eq(bottom_tex.gradient.colors[0].a, 0.0, 0.01)
	assert_almost_eq(bottom_tex.gradient.colors[1].a, 0.66, 0.01)

	# 遮罩必须先于 HUD 文字与奖励遮罩加入，不能盖住信息。
	var dim := hud.get("_reward_dim") as ColorRect
	assert_true(top.get_index() < dim.get_index())
	assert_true(bottom.get_index() < dim.get_index())


## 反馈 01：HUD 任何位置（含结算页）都不再显示残心层数，机制仍照常记数。
## 2026-11-06：A 符卡定稿名就是「残心」，所以只禁止"层数"形态，不禁止符卡名本身。
func test_zanshin_count_is_hidden_everywhere_in_hud() -> void:
	var hud := _make_hud()
	await wait_process_frames(1)
	var run := RunState.new(1)
	run.zanshin = 2
	var sim := DuelSim.new(FighterData.player_a(), FighterData.player_a(), 1)
	hud.set_run(run)
	hud.bind(sim)
	hud.refresh()
	assert_false(hud._run_info.text.contains("残心"), "局内不显示残心")
	for text in _hud_texts_without_spell_row(hud):
		assert_false(_shows_zanshin_count(text), "局内任何标签都不显示残心层数: %s" % text)

	run.phase = RunState.Phase.CLEAR
	sim.finished = true
	sim.winner = DuelTypes.Side.P1
	hud.refresh()
	assert_true(hud._result.visible, "结算页仍显示败北/胜利")
	for text in _hud_texts_without_spell_row(hud):
		assert_false(_shows_zanshin_count(text), "结算页也不显示残心层数: %s" % text)
	assert_eq(run.zanshin, 2, "残心机制照常记数")


## 符卡行「残心 ×1 (30)」里的数字是符卡次数与耗心流，不属于残心层数，检查层数时排除。
func _hud_texts_without_spell_row(hud: DuelHud) -> Array[String]:
	var skip: Array[Label] = [hud._p1_spell, hud._p2_spell]
	var texts: Array[String] = []
	for node in hud.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.visible and not skip.has(label):
			texts.append(label.text)
	return texts


## 「残心」后面紧跟数字/乘号才算层数显示；单独的符卡名「残心」不算。
func _shows_zanshin_count(text: String) -> bool:
	var regex := RegEx.new()
	regex.compile("残心\\s*[×xX:：]?\\s*\\d")
	return regex.search(text) != null


## 反馈 02：操作行补上开符卡的键，玩家不必翻设置才知道 L 能放符卡。
func test_controls_line_mentions_spell_key() -> void:
	var hud := _make_hud()
	await wait_process_frames(1)
	var run := RunState.new(1)
	var sim := DuelSim.new(FighterData.player_a(), FighterData.player_a(), 1)
	hud.set_run(run)
	hud.bind(sim)
	hud.refresh()
	assert_true(hud._controls.text.contains("L"), "单人操作行要有 L 键")
	assert_true(hud._controls.text.contains("发动符卡"), "并且说清 L 是开符卡")
	assert_false(hud._controls.text.contains("%s"), "占位符必须全部替换")


func test_controls_line_follows_p1_gamepad() -> void:
	var hud := _make_hud()
	await wait_process_frames(1)
	var meta := GameBootstrap.meta
	var sim := DuelSim.new(FighterData.player_a(), FighterData.player_a(), 1)
	hud.set_versus(true)
	hud.set_input_methods(true, false)
	hud.bind(sim)
	assert_true(hud._controls.text.contains(KeyBindings.label_joy(meta, &"attack_p1")), "P1 手柄时显示手柄攻击键")
	assert_true(hud._controls.text.contains(KeyBindings.label_joy(meta, &"spell_p1")), "P1 手柄时显示手柄符卡键")
	assert_false(hud._controls.text.contains(KeyBindings.label(meta, &"attack_p1")), "不再显示已解绑的 P1 键盘攻击键")


func test_controls_line_follows_p2_gamepad() -> void:
	var hud := _make_hud()
	await wait_process_frames(1)
	var meta := GameBootstrap.meta
	var sim := DuelSim.new(FighterData.player_a(), FighterData.player_a(), 1)
	hud.set_versus(true)
	hud.set_input_methods(false, true)
	hud.bind(sim)
	assert_true(hud._controls.text.contains(KeyBindings.label_joy(meta, &"attack_p2")), "P2 手柄时显示手柄攻击键")
	assert_true(hud._controls.text.contains(KeyBindings.label_joy(meta, &"spell_p2")), "P2 手柄时显示手柄符卡键")
	assert_false(hud._controls.text.contains(KeyBindings.label(meta, &"attack_p2")), "不再显示已解绑的 P2 键盘攻击键")
