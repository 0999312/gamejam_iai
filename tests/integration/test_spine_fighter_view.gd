extends GutTest

## SpineFighterView：真扩展、真骨架、真图集跑一遍。
## 没装 spine-godot 的机器跳过（不把「缺扩展」误判成失败）。

const PROFILE_PATH := "res://resources/spine/char_a.tres"


func before_each() -> void:
	if not SpineFighterView.is_supported():
		pending("未安装 spine-godot GDExtension，跳过 Spine 表现测试")


func _profile() -> SpineFighterProfile:
	return load(PROFILE_PATH) as SpineFighterProfile


func _view(profile: SpineFighterProfile = null) -> SpineFighterView:
	var view := SpineFighterView.new()
	add_child_autofree(view)
	var ok := view.setup(profile if profile != null else _profile())
	assert_true(ok, "setup 应当成功")
	return view


func _sim() -> DuelSim:
	return DuelSim.new(FighterData.player_a(), FighterData.player_b(), 5)


## 测试里要改映射/朝向时用副本，避免污染 load() 缓存、串到后面的用例。
func _profile_copy() -> SpineFighterProfile:
	var copy := (_profile() as Resource).duplicate() as SpineFighterProfile
	copy.animation_map = copy.animation_map.duplicate()
	return copy


func _sprite(view: SpineFighterView) -> Node2D:
	return view.get_child(0) as Node2D


func test_extension_registers_spine_sprite() -> void:
	assert_true(SpineFighterView.is_supported())
	assert_true(ClassDB.class_exists("SpineSprite"))


func test_setup_takes_over_and_plays_idle() -> void:
	var view := _view()
	assert_true(view.is_active())
	view.apply(_sim().p1, false)
	assert_eq(view.current_animation(), "zhanli")


## 3.8 JSON 的顶层 ik 数组不会被 4.3 运行时解析；迁移工具必须把它并入 constraints。
## 这里直接对实际档案做断言，防止「动画在播但四肢不跟随 IK」的静默回归。
func test_skeleton_data_keeps_ik_constraints() -> void:
	var view := _view()
	var data: Object = view.get("_data")
	var names: Array[String] = []
	for ik: Object in data.call("get_ik_constraints"):
		names.append(str(ik.call("get_constraint_name")))
	for expected: String in ["youjiao", "zuojiao ik", "zuoshou-ik", "zuoshou-ik2",
			"刀的目标", "刀鞘目标", "右手ik", "右手手掌ik", "右手袖子-ik", "袖子左-ik"]:
		assert_has(names, expected, "IK 约束 %s 不能丢" % expected)
	assert_eq(names.size(), 10, "当前测试骨架应保留全部 10 条 IK 约束")


func test_setup_refuses_empty_profile() -> void:
	var view := SpineFighterView.new()
	add_child_autofree(view)
	assert_false(view.setup(SpineFighterProfile.new()), "空档案不该假装接管")
	assert_false(view.is_active())


## 新素材的动画表：攻击 / 受击 / 防御 / 战败 / 站立五条都要真的加载进来。
func test_skeleton_data_has_the_five_action_animations() -> void:
	var view := _view()
	var data: Object = view.get("_data")
	var expected := {
		"gongji": 1.0,
		"bei_gongji": 1.3333,
		"fangyu": 0.6667,
		"siwang": 0.8333,
		"zhanli": 0.6667,
	}
	for anim_name: Variant in expected.keys():
		var animation: Variant = data.call("find_animation", anim_name)
		assert_not_null(animation, "骨架里应有动画 %s" % anim_name)
		if animation != null:
			assert_almost_eq(float(animation.call("get_duration")), float(expected[anim_name]),
					0.01, "动画 %s 时长应与导出表一致" % anim_name)


func test_action_states_use_their_own_animations() -> void:
	var view := _view()
	var sim := _sim()
	var cases: Array[Array] = [
		[DuelTypes.State.GUARD, "fangyu"],
		[DuelTypes.State.GUARD_REC, "fangyu"],
		[DuelTypes.State.HITSTUN, "bei_gongji"],
		[DuelTypes.State.CLASH, "fangyu"],
		[DuelTypes.State.DOWN, "siwang"],
	]
	for case: Array in cases:
		sim.p1.state = int(case[0])
		sim.p1.state_duration = 12
		view.apply(sim.p1, false)
		assert_eq(view.current_animation(), case[1],
				"%s 应播 %s" % [DuelTypes.state_name(case[0]), case[1]])


func test_apply_switches_attack_animation() -> void:
	var view := _view()
	var sim := _sim()
	view.apply(sim.p1, false)
	assert_eq(view.current_animation(), "zhanli")
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.COMMIT)
	view.apply(sim.p1, false)
	assert_eq(view.current_animation(), "gongji", "构/斩/收招共用攻击动画")


func test_idle_animation_advances_and_loops_at_native_speed() -> void:
	var view := _view()
	var sim := _sim()
	view.apply(sim.p1, false)
	var entry: Object = view.get("_anim_state").call("get_track", 0)
	var before: float = entry.call("get_track_time")
	assert_eq(view.playback_time_scale(), 1.0, "待机动画保持美术原速")
	await wait_process_frames(12)
	assert_gt(entry.call("get_track_time"), before, "待机动画必须真的在推进，而不是冻在第一帧")


func test_attack_animation_is_retimed_to_the_whole_attack_window() -> void:
	var view := _view()
	var sim := _sim()
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.COMMIT)
	view.apply(sim.p1, false)
	assert_eq(view.current_animation(), "gongji")
	var animation: Variant = view.get("_data").call("find_animation", "gongji")
	assert_not_null(animation)
	var window_frames := float(sim.p1.commit_total + sim.p1.data.slash_frames \
			+ sim.p1.data.whiff_recovery)
	var expected := float(animation.call("get_duration")) / (window_frames / 60.0)
	assert_almost_eq(view.playback_time_scale(), expected, 0.01,
			"gongji 要对齐「构 + 斩 + 收招」的整刀窗口，不只是构")


func test_attack_animation_continues_across_slash_without_restart() -> void:
	var view := _view()
	var sim := _sim()
	sim.p1.state = DuelTypes.State.COMMIT
	sim.p1.state_duration = 14
	view.apply(sim.p1, false)
	var entry: Object = view.get("_anim_state").call("get_track", 0)
	entry.call("set_track_time", 0.20)
	sim.p1.state = DuelTypes.State.SLASH
	sim.p1.state_duration = 5
	view.apply(sim.p1, false)
	assert_eq(view.current_animation(), "gongji")
	assert_almost_eq(entry.call("get_track_time"), 0.20, 0.001,
			"构→斩共用同一段攻击动画，不能从头重播")


func test_reentering_commit_restarts_the_attack_animation() -> void:
	var view := _view()
	var sim := _sim()
	sim.p1.state = DuelTypes.State.COMMIT
	sim.p1.state_duration = 14
	view.apply(sim.p1, false)
	var entry: Object = view.get("_anim_state").call("get_track", 0)
	entry.call("set_track_time", 0.20)
	sim.p1.state = DuelTypes.State.RECOVERY
	sim.p1.state_duration = 10
	view.apply(sim.p1, false)
	assert_almost_eq(entry.call("get_track_time"), 0.20, 0.001, "收招继续用同一段动画")
	sim.p1.state = DuelTypes.State.COMMIT
	sim.p1.state_duration = 14
	view.apply(sim.p1, false)
	var restarted: Object = view.get("_anim_state").call("get_track", 0)
	assert_lt(restarted.call("get_track_time"), 0.05, "新一次构必须从第 0 帧起手")


func test_missing_animation_warns_once_and_keeps_running() -> void:
	var profile := _profile_copy()
	profile.animation_map["COMMIT"] = "no_such_animation"
	var view := _view(profile)
	watch_signals(view)
	var sim := _sim()
	view.apply(sim.p1, false)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.tick()
	view.apply(sim.p1, false)
	view.apply(sim.p1, false)
	assert_signal_emit_count(view, "animation_missing", 1, "同一处缺失只报一次")
	assert_eq(view.current_animation(), "zhanli", "缺动画时保持上一段，不要停摆")


func test_facing_left_mirrors_scale() -> void:
	var view := _view()
	var sim := _sim()
	view.apply(sim.p1, true)
	assert_lt(_sprite(view).scale.x, 0.0, "朝左时水平镜像")
	view.apply(sim.p1, false)
	assert_gt(_sprite(view).scale.x, 0.0)


func test_facing_mirror_can_be_disabled() -> void:
	var profile := _profile_copy()
	profile.flip_when_facing_left = false
	var view := _view(profile)
	view.apply(_sim().p1, true)
	assert_gt(_sprite(view).scale.x, 0.0, "档案关掉镜像时保持原朝向")


func test_down_plays_death_animation_and_stays_visible() -> void:
	var view := _view()
	var sim := _sim()
	sim.p1.state = DuelTypes.State.DOWN
	view.apply(sim.p1, false)
	assert_eq(view.current_animation(), "siwang", "战败要播 siwang")
	assert_true(_sprite(view).visible, "有死亡动画时骨架不能藏")
	sim.p1.state = DuelTypes.State.IDLE
	view.apply(sim.p1, false)
	assert_true(_sprite(view).visible)


## 旧档案/旧素材没有 DOWN 动画时，仍回退灰盒倒地剪影，避免人物站着不动。
func test_down_without_mapping_falls_back_to_graybox_silhouette() -> void:
	var profile := _profile_copy()
	profile.animation_map.erase("DOWN")
	var view := _view(profile)
	var sim := _sim()
	sim.p1.state = DuelTypes.State.DOWN
	view.apply(sim.p1, false)
	assert_false(_sprite(view).visible, "没有死亡动画时交给灰盒剪影")


func test_pause_freezes_animation_time() -> void:
	var view := _view()
	var sim := _sim()
	view.apply(sim.p1, false)
	var state: Object = view.get("_anim_state")
	var entry: Object = state.call("get_track", 0)
	assert_not_null(entry, "待机动画应当占住 track 0")
	await wait_process_frames(4)
	var moving: float = entry.call("get_track_time")
	view.set_paused(true)
	var frozen: float = entry.call("get_track_time")
	await wait_process_frames(4)
	assert_almost_eq(entry.call("get_track_time"), frozen, 0.0001,
			"暂停后动画时间必须停住（moving=%f）" % moving)
	view.set_paused(false)
	await wait_process_frames(3)
	assert_gt(entry.call("get_track_time"), frozen, "恢复后从原处继续")


func test_fit_scale_matches_target_height() -> void:
	var view := _view()
	var bounds := view.bounds()
	assert_gt(bounds.size.y, 0.0)
	assert_almost_eq(bounds.size.y * view.fit_scale(), view.profile.target_height, 0.5,
			"缩放后身高要等于档案里的 target_height")


func test_clear_releases_the_sprite() -> void:
	var view := _view()
	view.clear()
	assert_false(view.is_active())
	assert_eq(view.get_child_count(), 0, "clear 后不该留着半截骨架")


## A 符卡：45f 自动架刀窗口内冻结在防御动画最后一帧（已经架住了，不再重播）。
func test_spell_auto_guard_holds_last_frame() -> void:
	var view := _view()
	var sim := _sim()
	sim.p1.flow = 60
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.SPELL)
	sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.SPELL)
	view.apply(sim.p1, false)
	assert_eq(view.current_animation(), "fangyu", "自动架刀播防御动画")
	assert_eq(view.playback_time_scale(), 0.0, "窗口内动画时间必须冻住")
	var entry: Object = view.get("_anim_state").call("get_track", 0)
	var animation: Variant = view.get("_data").call("find_animation", "fangyu")
	assert_almost_eq(float(entry.call("get_track_time")),
			float(animation.call("get_duration")), 0.02, "停在动画最后一帧")


func test_spell_window_end_resumes_idle_animation() -> void:
	var view := _view()
	var sim := _sim()
	sim.p1.flow = 60
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.SPELL)
	sim.tick()
	view.apply(sim.p1, false)
	for i in 45:
		sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.IDLE)
	view.apply(sim.p1, false)
	assert_eq(view.current_animation(), "zhanli", "窗口结束回到待机")
	assert_eq(view.playback_time_scale(), 1.0)
