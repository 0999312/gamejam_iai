extends GutTest

## DuelView ↔ DuelFx 接线：`DuelSim` 的信号要真的把粒子点起来，
## 暂停/换局要真的能拦住。只验接线，不验像素（像素看
## `docs/dev-example/duel-fx-preview.png`）。


func _make_view() -> DuelView:
	var view := preload("res://scenes/duel/duel_view.tscn").instantiate() as DuelView
	add_child_autofree(view)
	return view


func _sim_pair() -> DuelSim:
	return DuelSim.new(FighterData.player_a(), FighterData.player_a(), 1)


func _fx_of(view: DuelView) -> DuelFx:
	var fx := view.get("_fx") as DuelFx
	assert_not_null(fx, "DuelView 必须自带 DuelFx")
	return fx


func _emitting(view: DuelView) -> Array[GPUParticles2D]:
	var out: Array[GPUParticles2D] = []
	var fx := _fx_of(view)
	if fx == null:
		return out
	for child in fx.get_children():
		var particles := child as GPUParticles2D
		if particles != null and particles.emitting:
			out.append(particles)
	return out


func test_hit_signal_spawns_a_burst() -> void:
	var view := _make_view()
	view.bind(_sim_pair())
	view.sim.hit_landed.emit(DuelTypes.Side.P1, DuelTypes.Side.P2, 3)
	assert_eq(_emitting(view).size(), 1)


func test_clash_signal_uses_the_clash_texture() -> void:
	var view := _make_view()
	view.bind(_sim_pair())
	view.sim.clash_happened.emit(DuelTypes.Side.P1, DuelTypes.Side.P2)
	var nodes := _emitting(view)
	assert_eq(nodes.size(), 1)
	assert_eq(nodes[0].texture, DuelFx.TEX_CLASH)


func test_perfect_block_uses_the_perfect_texture() -> void:
	var view := _make_view()
	view.bind(_sim_pair())
	view.sim.attack_blocked.emit(DuelTypes.Side.P1, DuelTypes.Side.P2, true)
	var nodes := _emitting(view)
	assert_eq(nodes.size(), 1)
	assert_eq(nodes[0].texture, DuelFx.TEX_PERFECT)


func test_normal_block_uses_the_ring_texture() -> void:
	var view := _make_view()
	view.bind(_sim_pair())
	view.sim.attack_blocked.emit(DuelTypes.Side.P1, DuelTypes.Side.P2, false)
	var nodes := _emitting(view)
	assert_eq(nodes.size(), 1)
	assert_eq(nodes[0].texture, DuelFx.TEX_BLOCK)


func test_rebind_clears_previous_bursts() -> void:
	var view := _make_view()
	view.bind(_sim_pair())
	view.sim.hit_landed.emit(DuelTypes.Side.P1, DuelTypes.Side.P2, 3)
	assert_eq(_emitting(view).size(), 1, "先确认这一发真的点着了")
	view.bind(_sim_pair())
	assert_eq(_emitting(view).size(), 0, "换局不得带着上一局的粒子")


func test_view_pause_reaches_the_particles() -> void:
	var view := _make_view()
	view.bind(_sim_pair())
	var fx := _fx_of(view)
	view.set_paused(true)
	assert_true(fx.is_paused())
	view.set_paused(false)
	assert_false(fx.is_paused())


func _slash_of(fx: DuelFx, side: int) -> Sprite2D:
	var sprites := fx.get("_slash") as Array
	return sprites[0 if side == DuelTypes.Side.P1 else 1] as Sprite2D


func _charge_of(fx: DuelFx, side: int) -> Sprite2D:
	var sprites := fx.get("_charge") as Array
	return sprites[0 if side == DuelTypes.Side.P1 else 1] as Sprite2D


func _burst_ring_of(fx: DuelFx) -> Sprite2D:
	return fx.get("_burst_ring") as Sprite2D


func test_spell_cast_spawns_the_purple_ring() -> void:
	var view := _make_view()
	view.bind(_sim_pair())
	view.sim.spell_cast.emit(DuelTypes.Side.P2, 0)
	var ring := _burst_ring_of(_fx_of(view))
	assert_true(ring.visible)
	assert_eq(ring.texture, DuelFx.TEX_SPELL_RING, "符卡爆环用 circle_02")
	assert_almost_eq(ring.modulate.b, DuelFx.SPELL_RING_COLOR.b, 0.01, "用紫色")


func test_spell_interrupt_uses_a_dimmer_ring() -> void:
	var view := _make_view()
	view.bind(_sim_pair())
	view.sim.spell_interrupted.emit(DuelTypes.Side.P1)
	var ring := _burst_ring_of(_fx_of(view))
	assert_true(ring.visible)
	assert_lt(ring.modulate.a, 0.62, "被打断时的环不该和成功发动一样亮")


func test_swing_state_poses_the_slash_crescent() -> void:
	var view := _make_view()
	view.bind(_sim_pair())
	view.sim.p1.state = DuelTypes.State.SLASH
	view.sim.p1.state_frame = 0
	view._update_slash_fx()
	var slash := _slash_of(_fx_of(view), DuelTypes.Side.P1)
	assert_true(slash.visible, "挥砍期必须出现刀光")
	assert_eq(slash.texture, DuelFx.TEX_SLASH, "刀光用 twirl_03")
	assert_false(_slash_of(_fx_of(view), DuelTypes.Side.P2).visible)


func test_idle_state_hides_the_slash() -> void:
	var view := _make_view()
	view.bind(_sim_pair())
	view.sim.p1.state = DuelTypes.State.SLASH
	view._update_slash_fx()
	view.sim.p1.state = DuelTypes.State.IDLE
	view._update_slash_fx()
	assert_false(_slash_of(_fx_of(view), DuelTypes.Side.P1).visible)


func test_commit_state_poses_the_charge_circle_at_the_feet() -> void:
	var view := _make_view()
	view.bind(_sim_pair())
	view.sim.p1.state = DuelTypes.State.COMMIT
	view.sim.p1.state_frame = 0
	view.sim.p1.commit_total = 18
	view._update_charge_fx()
	var ring := _charge_of(_fx_of(view), DuelTypes.Side.P1)
	assert_true(ring.visible, "起构期必须出现蓄力环")
	assert_eq(ring.texture, DuelFx.TEX_CHARGE, "蓄力环用 light_03")
	assert_almost_eq(ring.position.y, 450.0, 0.001, "与心流圆环同心（GROUND_Y - 90）")
	assert_almost_eq(ring.position.x, 430.0, 0.001, "同心＝不吃 COMMIT 的前倾")
	assert_false(_charge_of(_fx_of(view), DuelTypes.Side.P2).visible)


func test_commit_progress_brightens_and_grows_the_charge_ring() -> void:
	var view := _make_view()
	view.bind(_sim_pair())
	view.sim.p1.state = DuelTypes.State.COMMIT
	view.sim.p1.commit_total = 18
	view.sim.p1.state_frame = 0
	view._update_charge_fx()
	var ring := _charge_of(_fx_of(view), DuelTypes.Side.P1)
	var early_alpha := ring.modulate.a
	var early_scale := ring.scale.x
	view.sim.p1.state_frame = 17
	view._update_charge_fx()
	assert_gt(ring.modulate.a, early_alpha, "越接近出刀，蓄力环越亮")
	assert_gt(ring.scale.x, early_scale, "越接近出刀，环由小长大")


func test_leaving_commit_hides_the_charge_ring() -> void:
	var view := _make_view()
	view.bind(_sim_pair())
	view.sim.p1.state = DuelTypes.State.COMMIT
	view._update_charge_fx()
	view.sim.p1.state = DuelTypes.State.IDLE
	view._update_charge_fx()
	assert_false(_charge_of(_fx_of(view), DuelTypes.Side.P1).visible, "出刀后蓄力环要收掉")


func test_rebind_clears_slash_and_spell_rings() -> void:
	var view := _make_view()
	view.bind(_sim_pair())
	view.sim.p1.state = DuelTypes.State.SLASH
	view._update_slash_fx()
	view.sim.spell_cast.emit(DuelTypes.Side.P1, 0)
	view.bind(_sim_pair())
	assert_false(_slash_of(_fx_of(view), DuelTypes.Side.P1).visible)
	assert_false(_burst_ring_of(_fx_of(view)).visible)
