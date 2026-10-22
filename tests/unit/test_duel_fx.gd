extends GutTest

## DuelFx 的池化 / 暂停 / 强度 / 清空契约。
## 只断言节点属性与生命周期，不断言像素——headless 下没有真实渲染，
## 画面由 `tools/capture_fx_preview.gd` 的截图人工复核。

var _fx: DuelFx


func before_each() -> void:
	_fx = DuelFx.new()
	add_child_autofree(_fx)


func _particles() -> Array[GPUParticles2D]:
	var out: Array[GPUParticles2D] = []
	for child in _fx.get_children():
		var particles := child as GPUParticles2D
		if particles != null:
			out.append(particles)
	return out


func _emitting_nodes() -> Array[GPUParticles2D]:
	var out: Array[GPUParticles2D] = []
	for particles in _particles():
		if particles.emitting:
			out.append(particles)
	return out


func test_pool_is_prebuilt() -> void:
	assert_eq(_particles().size(), DuelFx.Kind.size() * DuelFx.POOL_PER_KIND,
			"每种特效预建固定池，战斗帧内不得新建节点")


func test_all_emitters_start_idle() -> void:
	var all_idle := true
	var all_one_shot := true
	for particles in _particles():
		all_idle = all_idle and not particles.emitting
		all_one_shot = all_one_shot and particles.one_shot
	assert_true(all_idle, "进场时全部不发光，避免空放")
	assert_true(all_one_shot, "命中/对刀/架防都是一次性爆发")


func test_hit_burst_starts_exactly_one_emitter() -> void:
	_fx.burst_hit(Vector2(430.0, 447.0), Color("#6fc3ff"))
	assert_eq(_emitting_nodes().size(), 1)


func test_zero_strength_emits_nothing() -> void:
	_fx.set_strength(0.0)
	_fx.burst_hit(Vector2(430.0, 447.0), Color.WHITE)
	_fx.burst_clash(Vector2(640.0, 440.0))
	assert_eq(_emitting_nodes().size(), 0, "强度 0 = 关闭特效")


func test_pause_freezes_bursts_and_speed() -> void:
	_fx.burst_hit(Vector2(430.0, 447.0), Color.WHITE)
	_fx.set_paused(true)
	assert_true(_fx.is_paused())
	for particles in _particles():
		assert_eq(particles.speed_scale, 0.0, "暂停时粒子必须冻住")
	_fx.burst_clash(Vector2(640.0, 440.0))
	assert_eq(_emitting_nodes().size(), 1, "暂停期间的新爆发直接丢弃")
	_fx.set_paused(false)
	assert_eq(_particles()[0].speed_scale, 1.0)


func test_clear_all_stops_every_emitter() -> void:
	_fx.burst_hit(Vector2(430.0, 447.0), Color.WHITE)
	_fx.burst_clash(Vector2(640.0, 440.0))
	_fx.burst_block(Vector2(886.0, 445.0), Color("#ff8a72"), true)
	_fx.clear_all()
	assert_eq(_emitting_nodes().size(), 0, "换局/重开必须清空")


func test_pool_reuses_nodes_instead_of_growing() -> void:
	var before := _fx.get_child_count()
	for i in 20:
		_fx.burst_hit(Vector2(430.0, 447.0), Color.WHITE)
	assert_eq(_fx.get_child_count(), before, "连击不得让节点数增长")


func test_block_kind_matches_perfect_flag() -> void:
	_fx.burst_block(Vector2(886.0, 445.0), Color("#ff8a72"), false)
	var normal := _emitting_nodes()
	assert_eq(normal.size(), 1)
	assert_eq(normal[0].texture, DuelFx.TEX_BLOCK, "普通架住用单环")
	_fx.clear_all()
	_fx.burst_block(Vector2(886.0, 445.0), Color("#ff8a72"), true)
	var perfect := _emitting_nodes()
	assert_eq(perfect.size(), 1)
	assert_eq(perfect[0].texture, DuelFx.TEX_PERFECT, "完美格挡用更亮的雾环")


func test_attacker_color_is_used_for_hit_spark() -> void:
	_fx.burst_hit(Vector2(430.0, 447.0), Color("#6fc3ff"))
	var nodes := _emitting_nodes()
	assert_eq(nodes.size(), 1)
	var mat := nodes[0].process_material as ParticleProcessMaterial
	assert_not_null(mat)
	assert_gt(mat.color.b, mat.color.r, "P1 出手时命中火花偏蓝（攻击方制）")


func test_clash_uses_warm_white_regardless_of_side() -> void:
	_fx.burst_clash(Vector2(640.0, 440.0))
	var nodes := _emitting_nodes()
	assert_eq(nodes.size(), 1)
	var mat := nodes[0].process_material as ParticleProcessMaterial
	assert_almost_eq(mat.color.r, DuelFx.CLASH_COLOR.r, 0.01)
	assert_almost_eq(mat.color.g, DuelFx.CLASH_COLOR.g, 0.01)
	assert_almost_eq(mat.color.b, DuelFx.CLASH_COLOR.b, 0.01)


## 放在单测内部调用：GUT 的 orphan 计数器只在「当前测试」期间有效。
func test_bursts_leave_no_orphans() -> void:
	_fx.burst_hit(Vector2(430.0, 447.0), Color.WHITE)
	_fx.burst_clash(Vector2(640.0, 440.0))
	_fx.burst_block(Vector2(886.0, 445.0), Color("#ff8a72"), true)
	_fx.clear_all()
	assert_no_new_orphans()


func _slash_of(side: int) -> Sprite2D:
	var sprites := _fx.get("_slash") as Array
	return sprites[0 if side == DuelTypes.Side.P1 else 1] as Sprite2D


func _charge_of(side: int) -> Sprite2D:
	var sprites := _fx.get("_charge") as Array
	return sprites[0 if side == DuelTypes.Side.P1 else 1] as Sprite2D


func _burst_ring() -> Sprite2D:
	return _fx.get("_burst_ring") as Sprite2D


func test_slash_and_spell_sprites_are_prebuilt_and_idle() -> void:
	assert_eq((_fx.get("_slash") as Array).size(), 2, "双方各一枚刀光，池化不新建")
	assert_eq((_fx.get("_charge") as Array).size(), 2, "双方各一枚起身法阵")
	assert_not_null(_burst_ring(), "符卡爆环只留一枚（双环会被读成 circle_03）")
	for side in [DuelTypes.Side.P1, DuelTypes.Side.P2]:
		assert_false(_slash_of(side).visible, "未挥砍时刀光不可见")
		assert_false(_charge_of(side).visible, "未起构时脚下法阵不可见")
	assert_false(_burst_ring().visible, "未发动符卡时爆环不可见")


func test_pose_slash_lays_crescent_on_the_old_arc() -> void:
	_fx.pose_slash(DuelTypes.Side.P1, Vector2(430.0, 460.0), 0.0)
	var sprite := _slash_of(DuelTypes.Side.P1)
	assert_true(sprite.visible)
	assert_eq(sprite.texture, DuelFx.TEX_SLASH, "刀光必须用 twirl_03")
	assert_eq(sprite.position, Vector2(430.0, 460.0), "弧心沿用躯干上方 70")
	assert_almost_eq(sprite.scale.x, DuelFx.SLASH_RADIUS / DuelFx.SLASH_TEX_BAND, 0.001,
			"缩放后月牙亮带落在旧弧的 122 半径上")
	assert_almost_eq(sprite.rotation,
			deg_to_rad(DuelFx.SLASH_TEX_CENTER_DEG) - 0.17, 0.001,
			"P1 朝右：贴图带中心 -26° 转到 0°，再按进度前扫")


func test_pose_slash_mirrors_toward_p2() -> void:
	_fx.pose_slash(DuelTypes.Side.P2, Vector2(850.0, 460.0), 0.0)
	var sprite := _slash_of(DuelTypes.Side.P2)
	assert_true(sprite.visible)
	assert_almost_eq(sprite.rotation,
			PI + deg_to_rad(DuelFx.SLASH_TEX_CENTER_DEG) - 0.17, 0.001,
			"P2 的月牙朝左")
	assert_false(_slash_of(DuelTypes.Side.P1).visible, "一侧挥砍不该点亮另一侧")


func test_slash_fades_over_the_swing_window() -> void:
	_fx.pose_slash(DuelTypes.Side.P1, Vector2(430.0, 460.0), 0.0)
	var first := _slash_of(DuelTypes.Side.P1).modulate.a
	_fx.pose_slash(DuelTypes.Side.P1, Vector2(430.0, 460.0), 1.0)
	var last := _slash_of(DuelTypes.Side.P1).modulate.a
	assert_gt(first, last, "收刀前必须淡出，不能啪地消失")
	assert_gt(last, 0.0, "最后一帧仍留一点残光")
	_fx.hide_slash(DuelTypes.Side.P1)
	assert_false(_slash_of(DuelTypes.Side.P1).visible)


func test_spell_burst_is_a_purple_ring_that_expands_then_hides() -> void:
	_fx.burst_spell(Vector2(430.0, 450.0))
	var ring := _burst_ring()
	assert_true(ring.visible)
	assert_eq(ring.texture, DuelFx.TEX_SPELL_RING, "符卡爆环必须用 circle_02")
	assert_almost_eq(ring.scale.x, DuelFx.SPELL_RING_START / DuelFx.SPELL_RING_TEX_RADIUS, 0.001,
			"起手半径 30，与旧绘制同量级")
	assert_almost_eq(ring.modulate.b, DuelFx.SPELL_RING_COLOR.b, 0.01, "用紫色")
	var start_scale := ring.scale.x
	_fx._process(0.3)
	assert_gt(ring.scale.x, start_scale, "环要向外推开")
	_fx._process(DuelFx.SPELL_BURST_TIME)
	assert_false(ring.visible, "寿命结束后必须自己消失")


func test_charge_ring_is_round_and_grows() -> void:
	_fx.pose_charge(DuelTypes.Side.P1, Vector2(430.0, 450.0), 20.0, Color(1.0, 0.99, 0.96, 0.32))
	var sprite := _charge_of(DuelTypes.Side.P1)
	assert_true(sprite.visible)
	assert_eq(sprite.texture, DuelFx.TEX_CHARGE, "蓄力环用 light_03，替掉原先自绘的弧")
	assert_eq(sprite.position, Vector2(430.0, 450.0), "与心流圆环同心")
	assert_almost_eq(sprite.scale.x, 20.0 / DuelFx.CHARGE_TEX_RADIUS, 0.001, "半径按贴图亮带换算")
	assert_almost_eq(sprite.scale.y, sprite.scale.x, 0.0001, "等比缩放，屏幕上必须是正圆")
	var small := sprite.scale.x
	_fx.pose_charge(DuelTypes.Side.P1, Vector2(430.0, 450.0), 120.0, Color(1.0, 0.79, 0.29, 0.9))
	assert_gt(sprite.scale.x, small, "越接近出刀，环越大")
	assert_almost_eq(sprite.scale.y, sprite.scale.x, 0.0001, "长大时也不能被压扁")
	_fx.hide_charge(DuelTypes.Side.P1)
	assert_false(sprite.visible)


func test_slash_shader_gets_progress_and_sweeps_forward() -> void:
	_fx.pose_slash(DuelTypes.Side.P1, Vector2(430.0, 460.0), 0.25)
	var sprite := _slash_of(DuelTypes.Side.P1)
	var mat := sprite.material as ShaderMaterial
	assert_not_null(mat, "刀光必须挂扇形消失的 shader")
	assert_almost_eq(float(mat.get_shader_parameter("progress")), 0.25, 0.001,
			"进度要喂给 shader，刀扫到哪就抹到哪")
	var early := sprite.rotation
	_fx.pose_slash(DuelTypes.Side.P1, Vector2(430.0, 460.0), 0.9)
	assert_gt(sprite.rotation, early, "刀光随挥砍方向前扫")


func test_clear_all_hides_slash_spell_and_charge() -> void:
	_fx.pose_slash(DuelTypes.Side.P1, Vector2(430.0, 460.0), 0.2)
	_fx.pose_charge(DuelTypes.Side.P2, Vector2(850.0, 534.0), 0.5, Color("#ff8a72"))
	_fx.burst_spell(Vector2(850.0, 450.0))
	_fx.clear_all()
	assert_false(_slash_of(DuelTypes.Side.P1).visible)
	assert_false(_charge_of(DuelTypes.Side.P2).visible, "换局不得带着上一局的起构法阵")
	assert_false(_burst_ring().visible, "换局不得带着上一局的刀光/爆环")


func test_pause_blocks_slash_charge_and_spell_burst() -> void:
	_fx.set_paused(true)
	_fx.pose_slash(DuelTypes.Side.P1, Vector2(430.0, 460.0), 0.5)
	_fx.pose_charge(DuelTypes.Side.P1, Vector2(430.0, 534.0), 0.5, Color.WHITE)
	_fx.burst_spell(Vector2(430.0, 450.0))
	assert_false(_slash_of(DuelTypes.Side.P1).visible, "暂停期间不摆刀光")
	assert_false(_charge_of(DuelTypes.Side.P1).visible, "暂停期间不摆起构法阵")
	assert_false(_burst_ring().visible, "暂停期间不发符卡爆环")
