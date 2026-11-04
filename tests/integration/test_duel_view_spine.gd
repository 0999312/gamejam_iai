extends GutTest

## DuelView ↔ Spine 接线：有档案就接管，没档案/没扩展一律回退灰盒。


func before_each() -> void:
	if not SpineFighterView.is_supported():
		pending("未安装 spine-godot GDExtension，跳过 Spine 接线测试")


func _make_view() -> DuelView:
	var view := preload("res://scenes/duel/duel_view.tscn").instantiate() as DuelView
	add_child_autofree(view)
	return view


func _pair() -> DuelSim:
	return DuelSim.new(FighterData.player_a(), FighterData.player_b(), 3)


func test_bind_after_ready_takes_over_both_fighters() -> void:
	var view := _make_view()
	view.bind(_pair())
	await wait_process_frames(2)
	assert_true(view.call("_is_spine_active", DuelTypes.Side.P1))
	assert_true(view.call("_is_spine_active", DuelTypes.Side.P2))
	var p1: SpineFighterView = view.get("_spine_p1")
	assert_not_null(p1)
	assert_eq(p1.current_animation(), "zhanli")


func test_bind_before_entering_tree_still_takes_over() -> void:
	var view := preload("res://scenes/duel/duel_view.tscn").instantiate() as DuelView
	view.bind(_pair())
	add_child_autofree(view)
	await wait_process_frames(2)
	assert_true(view.call("_is_spine_active", DuelTypes.Side.P1),
			"先 bind 再入树也要接管（headless 截图就是这条路）")


func test_unknown_character_keeps_the_graybox() -> void:
	var data := FighterData.new()
	data.id = &"no_such_character"
	var view := _make_view()
	view.bind(DuelSim.new(data, FighterData.player_b(), 3))
	await wait_process_frames(2)
	assert_false(view.call("_is_spine_active", DuelTypes.Side.P1),
			"找不到档案时必须回退灰盒，不能崩")
	assert_true(view.call("_is_spine_active", DuelTypes.Side.P2))


func test_explicit_profile_dictionary_overrides_convention() -> void:
	var data := FighterData.new()
	data.id = &"no_such_character"
	var view := _make_view()
	view.spine_profiles = {&"no_such_character": load("res://resources/spine/char_a.tres")}
	view.bind(DuelSim.new(data, FighterData.player_b(), 3))
	await wait_process_frames(2)
	assert_true(view.call("_is_spine_active", DuelTypes.Side.P1),
			"显式字典要能顶替约定路径")


## 档案没配 DOWN 动画时，SpineFighterView 会隐藏骨架；DuelView 必须同时
## 把灰盒倒地剪影画回来，不能两边都不画。
func test_missing_down_animation_falls_back_to_graybox() -> void:
	var profile := (load("res://resources/spine/char_a.tres") as SpineFighterProfile).duplicate() \
			as SpineFighterProfile
	assert_not_null(profile)
	if profile == null:
		return
	profile.animation_map = profile.animation_map.duplicate()
	profile.animation_map.erase("DOWN")
	var view := _make_view()
	view.spine_profiles = {&"char_a": profile}
	var sim := _pair()
	view.bind(sim)
	await wait_process_frames(2)
	sim.p1.state = DuelTypes.State.DOWN
	sim.p1.state_frame = 0
	sim.p1.state_duration = 0
	view.call("_update_spine")
	await wait_process_frames(1)
	var p1 := view.get("_spine_p1") as SpineFighterView
	assert_not_null(p1)
	if p1 == null:
		return
	var sprite := p1.get("_sprite") as CanvasItem
	assert_not_null(sprite)
	if sprite != null:
		assert_false(sprite.visible, "没有 DOWN 动画时骨架应隐藏")
	assert_true(bool(view.call("_draws_graybox", sim.p1)),
			"没有 DOWN 动画时必须回退灰盒倒地剪影")


## P2 是“席位”而不是角色：即使双方选同一个角色，也要换成蓝色 2P 图集，
## 且 P1 不能被污染。
func test_p2_uses_its_own_atlas_even_with_the_same_character() -> void:
	var view := _make_view()
	view.bind(DuelSim.new(FighterData.player_a(), FighterData.player_a(), 3))
	await wait_process_frames(2)
	var p1 := view.get("_spine_p1") as SpineFighterView
	var p2 := view.get("_spine_p2") as SpineFighterView
	assert_not_null(p1)
	assert_not_null(p2)
	if p1 == null or p2 == null or p1.profile == null or p2.profile == null:
		return
	assert_eq(p1.profile.atlas_file.resource_path, "res://resources/spine/skeleton.atlas",
			"P1 保持原色图集")
	assert_eq(p2.profile.atlas_file.resource_path, "res://resources/spine/skeleton_p2.atlas",
			"P2 换成蓝色图集")
	assert_ne(p1.profile.atlas_file, p2.profile.atlas_file,
			"不能共享同一个图集资源")
	assert_eq(p2.profile.animation_map, p1.profile.animation_map,
			"克隆档案不能丢动作映射")
	var textures: Array = p2.profile.atlas_file.call("get_textures")
	assert_eq(textures.size(), 1, "P2 图集应只有一张贴图")
	if not textures.is_empty():
		var texture := textures[0] as Texture2D
		assert_not_null(texture)
		if texture != null:
			assert_eq(texture.resource_path, "res://resources/spine/skeleton_p2.png")


func test_pause_reaches_the_spine_views() -> void:
	var view := _make_view()
	view.bind(_pair())
	await wait_process_frames(2)
	var p1: SpineFighterView = view.get("_spine_p1")
	view.set_paused(true)
	assert_true(p1.get("_paused"))
	view.set_paused(false)
	assert_false(p1.get("_paused"))


func test_rebind_swaps_profiles_without_duplicating_nodes() -> void:
	var view := _make_view()
	view.bind(_pair())
	await wait_process_frames(1)
	var before := view.get_child_count()
	view.bind(_pair())
	await wait_process_frames(1)
	assert_eq(view.get_child_count(), before, "换局不该越挂越多")
