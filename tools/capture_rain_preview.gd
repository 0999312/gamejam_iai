extends SceneTree

## 开发期截图工具：雨夜背景 + 双人待机 / 战败 siwang（验证不再叠灰盒小人）。
## 用法（需要显示设备，不能 --headless）：
##   godot --path . -s tools/capture_rain_preview.gd
## 产物：
##   docs/dev-example/rainy-night-preview.png
##   docs/dev-example/rainy-night-defeat.png
## 不参与游戏运行，也不被 GUT 引用。

const OUT_IDLE := "res://docs/dev-example/rainy-night-preview.png"
const OUT_DEFEAT := "res://docs/dev-example/rainy-night-defeat.png"
## 等雨线跑起来、骨架进入待机循环再拍。
const IDLE_FRAMES := 36
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := (load("res://scenes/duel/duel_view.tscn") as PackedScene).instantiate() as DuelView
	root.add_child(view)
	var sim := DuelSim.new(FighterData.player_a(), FighterData.player_b(), 3)
	view.bind(sim)
	for i in IDLE_FRAMES:
		await process_frame
	if not await _save(OUT_IDLE):
		return

	# 直接推进到战败：DuelView 只读状态，不会改判定；Spine 会播 siwang，
	# 同时灰盒判定为 false，旧的倒地矩形/圆头不再出现。
	sim.p1.state = DuelTypes.State.DOWN
	sim.p1.state_frame = 0
	sim.p1.state_duration = 0
	view.call("_update_spine")
	# 不依赖真实帧率等 0.833 秒：直接把 siwang 的轨道拨到末帧，
	# 截图工具在无 vsync/高帧率机器上也能稳定拍到跪地姿势。
	var p1 := view.get("_spine_p1") as SpineFighterView
	if p1 == null:
		push_error("capture_rain_preview: 找不到 SpineP1")
		quit(1)
		return
	var state := p1.get("_anim_state") as Object
	if state == null:
		push_error("capture_rain_preview: SpineP1 没有动画状态机")
		quit(1)
		return
	state.get_track(0).call("set_track_time", 0.8333)
	for i in 3:
		await process_frame
	print("capture_rain_preview: 战败动画 %s / track=%.3f" % [
			p1.current_animation(), float(state.get_track(0).call("get_track_time"))])
	if not await _save(OUT_DEFEAT):
		return
	quit(0)


func _save(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		push_error("capture_rain_preview: 取不到视口画面")
		quit(1)
		return false
	var error := image.save_png(path)
	if error != OK:
		push_error("capture_rain_preview: 写成 PNG 失败，错误码 %d" % error)
		quit(1)
		return false
	print("capture_rain_preview: 已写入 %s（%d×%d）" % [path, image.get_width(), image.get_height()])
	return true
