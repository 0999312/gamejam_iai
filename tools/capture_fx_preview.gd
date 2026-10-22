extends SceneTree

## 开发期截图工具：把特效摆到同一帧，用来人工复核尺寸、配色与可读性
## （相对 46×150 的角色有多大）。
##
## 用法（需要有显示设备，不能加 --headless）：
##   godot --path . -s tools/capture_fx_preview.gd
## 产物：
##   docs/dev-example/duel-fx-preview.png   命中 / 对刀 / 架住 / 完美格挡（粒子）
##   docs/dev-example/duel-fx-slash.png     挥砍月牙（twirl_03）+ 符卡爆环（circle_02 紫）
##   docs/dev-example/duel-fx-charge.png    「构」的脚下法阵（circle_02 + circle_05）
##   docs/dev-example/duel-fx-sweep.png     刀光 0/35/70/100% 四格连拍（看扇形怎么塌）
## 不参与游戏运行，也不被 GUT 引用。

const OUT_PARTICLES := "res://docs/dev-example/duel-fx-preview.png"
const OUT_SLASH := "res://docs/dev-example/duel-fx-slash.png"
const OUT_CHARGE := "res://docs/dev-example/duel-fx-charge.png"
const OUT_SWEEP := "res://docs/dev-example/duel-fx-sweep.png"
const P1_BLUE := Color("#6fc3ff")
const P2_CORAL := Color("#ff8a72")
const GROUND_Y := 540.0
const BODY_H := 150.0
## 等几帧再拍：one-shot 爆发需要时间张开，0 帧拍到的是原点。
const SETTLE_FRAMES := 7
## 符卡环要等它推到能看清的尺寸再拍（约 0.2s / 半径 ~200）。
const SPELL_SETTLE_FRAMES := 12


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://scenes/duel/duel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 3:
		await process_frame
	var view := scene.get_node_or_null("DuelView") as DuelView
	if view == null:
		push_error("capture_fx_preview: 场景里找不到 DuelView")
		quit(1)
		return
	var fx := view.get("_fx") as DuelFx
	if fx == null:
		push_error("capture_fx_preview: DuelView 没有装配 DuelFx")
		quit(1)
		return

	var chest := GROUND_Y - BODY_H * 0.62
	fx.burst_hit(Vector2(430.0, chest), P1_BLUE)
	fx.burst_clash(Vector2(640.0, GROUND_Y - BODY_H * 0.66))
	fx.burst_block(Vector2(850.0 - 36.0, GROUND_Y - BODY_H * 0.63), P2_CORAL, false)
	fx.burst_block(Vector2(1010.0, chest), P1_BLUE, true)
	for i in SETTLE_FRAMES:
		await process_frame
	if not await _save(OUT_PARTICLES):
		return

	# 第二张：刀光与符卡爆环。刀光由 `_update_slash_fx()` 每帧按 sim 状态喂，
	# 截图里 sim 是「待机」，所以先停掉 view 的 `_process` 再手动摆一次，
	# 否则下一帧就被 `hide_slash()` 收走；符卡环自己会长，等它张开再拍。
	fx.clear_all()
	view.set_process(false)
	fx.pose_slash(DuelTypes.Side.P1, Vector2(430.0 + 28.0, GROUND_Y - BODY_H + 2.0 + 70.0), 0.0)
	fx.burst_spell(Vector2(1010.0, GROUND_Y - 90.0))
	for i in SPELL_SETTLE_FRAMES:
		await process_frame
	if not await _save(OUT_SLASH):
		return

	# 第三张：攻击前摇的蓄力环（替换原先自绘的收束弧），与心流圆环同心。
	# 左＝构刚起手（白、小），右＝快出刀（亮金、胀满并呼吸）。
	fx.clear_all()
	fx.pose_charge(DuelTypes.Side.P1, Vector2(430.0, GROUND_Y - 90.0), 59.0,
			Color("#fffdf7").lerp(Color("#ffc94a"), 0.35) * Color(1, 1, 1, 0.50), 0.4)
	fx.pose_charge(DuelTypes.Side.P2, Vector2(850.0, GROUND_Y - 90.0), 138.0,
			Color("#ffc94a") * Color(1, 1, 1, 0.88), 1.6)
	fx.pose_slash(DuelTypes.Side.P1, Vector2(640.0, 300.0), 0.95)
	for i in SETTLE_FRAMES:
		await process_frame
	if not await _save(OUT_CHARGE):
		return

	# 第四张：刀光 0→1 的四格连拍。位图池只有两枚月牙，这里按同一套参数
	# 复制出额外的 Sprite（工具专用，不进游戏），用来核「扇形是否沿刀向塌」。
	fx.clear_all()
	var base := (fx.get("_slash") as Array)[0] as Sprite2D
	var steps: Array[float] = [0.0, 0.35, 0.7, 1.0]
	for i in steps.size():
		fx.pose_slash(DuelTypes.Side.P1, Vector2(230.0 + 280.0 * i, 300.0), steps[i])
		if i < steps.size() - 1:
			var ghost := base.duplicate() as Sprite2D
			ghost.name = "SweepGhost%d" % i
			ghost.material = (base.material as Material).duplicate()
			fx.add_child(ghost)
	for i in SETTLE_FRAMES:
		await process_frame
	if not await _save(OUT_SWEEP):
		return
	quit(0)


func _save(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		push_error("capture_fx_preview: 取不到视口画面")
		quit(1)
		return false
	var error := image.save_png(path)
	if error != OK:
		push_error("capture_fx_preview: 写成 PNG 失败，错误码 %d" % error)
		quit(1)
		return false
	print("capture_fx_preview: 已写入 %s（%d×%d）" % [path, image.get_width(), image.get_height()])
	return true
