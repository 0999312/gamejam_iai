extends GutTest

## 雨夜背景与战败表现：背景必须是程序化 shader、铺满舞台且不抢输入；
## 战败由 siwang 骨架接管时，不能再叠旧灰盒「倒地小人」。

const BG_PATH := "res://scenes/duel/rainy_night.tscn"
const SHADER_PATH := "res://resources/shaders/rainy_night.gdshader"


func _make_view() -> DuelView:
	var view := preload("res://scenes/duel/duel_view.tscn").instantiate() as DuelView
	add_child_autofree(view)
	return view


func _pair() -> DuelSim:
	return DuelSim.new(FighterData.player_a(), FighterData.player_b(), 3)


func test_ready_builds_a_full_screen_rainy_night_layer() -> void:
	var view := _make_view()
	await wait_process_frames(1)
	var background := view.get("_background") as ColorRect
	assert_not_null(background, "DuelView 入树后必须挂上雨夜背景")
	if background == null:
		return
	assert_eq(background.name, "RainyNight")
	assert_eq(background.get_parent(), view)
	assert_eq(background.size, Vector2(1280.0, 720.0), "固定铺满 1280×720 舞台")
	assert_true(background.show_behind_parent, "背景要画在 DuelView 自绘层之后")
	assert_lt(background.z_index, 0, "负 z_index 保证不盖住角色与判定提示")
	assert_eq(background.mouse_filter, Control.MOUSE_FILTER_IGNORE, "背景不能拦截输入")


func test_rainy_night_uses_the_rain_shader_and_stage_uniforms() -> void:
	var view := _make_view()
	await wait_process_frames(1)
	var background := view.get("_background") as ColorRect
	assert_not_null(background)
	if background == null:
		return
	var material := background.material as ShaderMaterial
	assert_not_null(material, "背景必须挂 ShaderMaterial")
	if material == null:
		return
	assert_not_null(material.shader)
	if material.shader == null:
		return
	assert_eq(material.shader.resource_path, SHADER_PATH)
	# 地面与两名角色的 x 位置必须跟 DuelView 的常量对齐，否则雨夜里的
	# 湿反光会漂到人物旁边。
	assert_almost_eq(float(material.get_shader_parameter("ground_y")), 540.0 / 720.0, 0.0001)
	assert_almost_eq(float(material.get_shader_parameter("focus_left")), 430.0 / 1280.0, 0.0001)
	assert_almost_eq(float(material.get_shader_parameter("focus_right")), 850.0 / 1280.0, 0.0001)


func test_background_scene_is_self_contained_and_pointer_transparent() -> void:
	var scene := load(BG_PATH) as PackedScene
	assert_not_null(scene)
	if scene == null:
		return
	var background := scene.instantiate() as ColorRect
	assert_not_null(background)
	if background == null:
		return
	assert_eq(background.size, Vector2(1280.0, 720.0))
	assert_eq(background.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(background.z_index, -1)
	background.free()


func test_defeat_is_left_to_siwang_instead_of_the_graybox() -> void:
	if not SpineFighterView.is_supported():
		pending("未安装 spine-godot GDExtension，跳过战败骨架测试")
		return
	var view := _make_view()
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
	assert_eq(p1.current_animation(), "siwang", "战败播 siwang，而不是继续站立/灰盒")
	assert_true(p1.visible, "siwang 必须可见")
	assert_false(bool(view.call("_draws_graybox", sim.p1)),
			"Spine 已接管时不能再画灰盒倒地小人")
