extends GutTest

## 雨夜背景改为「固定 1280×720 的 SubViewport + 放大 TextureRect」：
## 全屏时只放大一张 1280×720 的图，不再逐像素跑满 2560×1600（审计 P2）。

const BG_PATH := "res://scenes/duel/rainy_night.tscn"
const SHADER_PATH := "res://resources/shaders/rainy_night.gdshader"


func _make() -> RainyNightBackdrop:
	var bg := load(BG_PATH).instantiate() as RainyNightBackdrop
	add_child_autofree(bg)
	return bg


func test_scene_renders_the_shader_into_a_1280x720_viewport() -> void:
	var bg := _make()
	await wait_process_frames(2)
	assert_not_null(bg)
	if bg == null:
		return
	var viewport := bg.get_node("SubViewport") as SubViewport
	assert_not_null(viewport)
	if viewport == null:
		return
	assert_eq(viewport.size, Vector2i(1280, 720), "雨夜固定按 1280×720 渲染")
	assert_eq(viewport.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	var display := bg.get_node("Display") as TextureRect
	assert_not_null(display)
	if display == null:
		return
	assert_true(display.texture is ViewportTexture, "展示层必须取 SubViewport 的纹理")
	var material := bg.get_shader_material()
	assert_not_null(material)
	if material == null:
		return
	assert_not_null(material.shader)
	if material.shader == null:
		return
	assert_eq(material.shader.resource_path, SHADER_PATH)


func test_shader_parameter_proxy_updates_only_the_rain_material() -> void:
	var bg := _make()
	await wait_process_frames(2)
	bg.set_shader_parameter("ground_y", 0.25)
	var material := bg.get_shader_material()
	assert_not_null(material)
	if material == null:
		return
	assert_almost_eq(float(material.get_shader_parameter("ground_y")), 0.25, 0.0001)
	assert_null(bg.material, "根 Control 不应挂 CanvasItem 材质，材质只属于雨层")


func test_instances_do_not_share_the_rain_material() -> void:
	var a := _make()
	var b := _make()
	await wait_process_frames(2)
	a.set_shader_parameter("pool_strength", 0.0)
	b.set_shader_parameter("pool_strength", 0.8)
	var mat_a := a.get_shader_material()
	var mat_b := b.get_shader_material()
	assert_not_null(mat_a)
	assert_not_null(mat_b)
	if mat_a == null or mat_b == null:
		return
	assert_almost_eq(float(mat_a.get_shader_parameter("pool_strength")), 0.0, 0.0001)
	assert_almost_eq(float(mat_b.get_shader_parameter("pool_strength")), 0.8, 0.0001)
