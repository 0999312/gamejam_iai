extends SceneTree

## 开发期截图工具：生成提交 README 用的实际运行画面（非 AI 生成图片）。
## 用法（需要显示设备，不能 --headless）：
##   godot --path . -s tools/capture_readme_shots.gd
## 产物：
##   docs/submit/shots/menu-16x9.png            主菜单
##   docs/submit/shots/duel-slash-guard-16x9.png 挥刀 + 完美架刀
##   docs/submit/shots/duel-clash-16x9.png       双方对刀
##   docs/submit/shots/duel-concept-3x4.png      3:4 竖版概念图（纯画面，无文字）
## 做法：实例化 DuelView + DuelSim，把双方状态摆到目标帧再拍，不跑完整对局；
## 只读表现层，不改任何判定。菜单直接实例化 menu.tscn。

const OUT_DIR := "res://docs/submit/shots"
const GROUND_Y := 540.0

var _fail := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _shot_menu()
	await _shot_duel(OUT_DIR + "/duel-slash-guard-16x9.png", false)
	await _shot_duel(OUT_DIR + "/duel-clash-16x9.png", true)
	await _shot_concept_3x4()
	quit(1 if _fail else 0)


func _shot_menu() -> void:
	var menu := (load("res://scenes/menu/menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	for i in 30:
		await process_frame
	await _save_root(OUT_DIR + "/menu-16x9.png")
	menu.queue_free()
	for i in 3:
		await process_frame


## 16:9：P1 出刀收势最后一帧 + P2 完美架刀最后一帧；clash=true 时改成双方对刀末帧。
func _shot_duel(path: String, clash: bool) -> void:
	var view := (load("res://scenes/duel/duel_view.tscn") as PackedScene).instantiate() as DuelView
	root.add_child(view)
	var sim := DuelSim.new(FighterData.player_a(), FighterData.player_b(), 20261019)
	view.bind(sim)
	for i in 24:
		await process_frame
	_pose_duel(sim, clash)
	# 等整段动画放完：防御 20f / 对刀 24f，留余量让 fangyu 停在最后一帧。
	for i in 30:
		await process_frame
	await _save_root(path)
	view.queue_free()
	for i in 3:
		await process_frame


## 3:4 竖版概念图：独立 SubViewport 960×1280，Camera2D 恰好铺满 720 高；纯画面，不叠标题。
func _shot_concept_3x4() -> void:
	var sub := SubViewport.new()
	sub.size = Vector2i(960, 1280)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.transparent_bg = false
	root.add_child(sub)

	var view := (load("res://scenes/duel/duel_view.tscn") as PackedScene).instantiate() as DuelView
	sub.add_child(view)
	var sim := DuelSim.new(FighterData.player_a(), FighterData.player_b(), 20261019)
	view.bind(sim)

	# 960/720 = 4:3 取景：zoom 1.6 时可见 600×800，两侧血条与双方都进画面。
	const ZOOM := 1.6
	var camera := Camera2D.new()
	camera.position = Vector2(640.0, 360.0)
	camera.zoom = Vector2(ZOOM, ZOOM)
	sub.add_child(camera)
	camera.make_current()
	for i in 24:
		await process_frame
	_fit_background(view, Rect2(640.0 - 480.0 / ZOOM, 360.0 - 640.0 / ZOOM, 960.0 / ZOOM, 1280.0 / ZOOM))

	_pose_duel(sim, false)
	for i in 30:
		await process_frame

	await RenderingServer.frame_post_draw
	var image := sub.get_texture().get_image()
	if image == null:
		push_error("capture_readme_shots: 3:4 取不到视口画面")
		_fail = true
	else:
		var error := image.save_png(OUT_DIR + "/duel-concept-3x4.png")
		if error != OK:
			push_error("capture_readme_shots: 3:4 写 PNG 失败，错误码 %d" % error)
			_fail = true
		else:
			print("capture_readme_shots: duel-concept-3x4.png %d×%d" % [image.get_width(), image.get_height()])
	view.queue_free()
	for i in 3:
		await process_frame
	sub.queue_free()


func _pose_duel(sim: DuelSim, clash: bool) -> void:
	sim.p1.hp = 30
	sim.p2.hp = 20
	sim.p1.flow = 78
	sim.p2.flow = 34
	# 出刀侧 / 防御侧都停在动画**最后一帧**：跑完整段再拍，姿态和特效才是收势后的样子。
	if clash:
		# 对刀：双方都停在 CLASH 末帧（互架），与「一方出刀、一方架住」区分开。
		sim.p1.state = DuelTypes.State.CLASH
		sim.p1.state_duration = 24
		sim.p1.state_frame = sim.p1.state_duration - 1
		sim.p2.state = DuelTypes.State.CLASH
		sim.p2.state_duration = 24
		sim.p2.state_frame = sim.p2.state_duration - 1
	else:
		sim.p1.state = DuelTypes.State.SLASH
		sim.p1.state_duration = maxi(1, sim.p1.data.slash_frames)
		sim.p1.state_frame = sim.p1.state_duration - 1
		# 正常架刀：动画会随 20f 窗口播完并停在 fangyu 最后一帧（刀完全架住）。
		sim.p2.state = DuelTypes.State.GUARD
		sim.p2.state_duration = 20
		sim.p2.state_frame = sim.p2.state_duration - 1
		sim.p2.guard_blocked = true


## 竖屏时相机可见范围超出 1280×720 的背景板，会露出视口清屏色；
## 把背景板按可见矩形重摆，并把三个以像素为基准的 uniform 换算成新的归一化值。
func _fit_background(view: DuelView, rect: Rect2) -> void:
	var bg := view.get("_background") as ColorRect
	if bg == null:
		return
	bg.position = rect.position
	bg.size = rect.size
	var material := bg.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("ground_y", (GROUND_Y - rect.position.y) / rect.size.y)
	material.set_shader_parameter("focus_left", (430.0 - rect.position.x) / rect.size.x)
	material.set_shader_parameter("focus_right", (850.0 - rect.position.x) / rect.size.x)


func _save_root(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		push_error("capture_readme_shots: 取不到视口画面")
		_fail = true
		return
	var error := image.save_png(path)
	if error != OK:
		push_error("capture_readme_shots: 写 PNG 失败 %s（%d）" % [path, error])
		_fail = true
		return
	print("capture_readme_shots: %s %d×%d" % [path, image.get_width(), image.get_height()])
