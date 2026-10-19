# 2D 物理测试：碰撞层/掩码、Area 重叠、direct space state 查询。
# 物理状态需要至少 1 个物理帧才生效：add_child 之后先 await wait_physics_frames(1)。
extends GutTest

const HIT_LAYER: int = 1
const HURT_LAYER: int = 2


func _make_area(radius: float, position: Vector2, layer: int, mask: int = 0) -> Area2D:
	var area := Area2D.new()
	area.position = position
	area.collision_layer = layer
	area.collision_mask = mask
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	return area


func test_overlap_detected_when_mask_matches() -> void:
	var hitbox: Area2D = _make_area(16.0, Vector2.ZERO, HIT_LAYER)
	var hurtbox: Area2D = _make_area(16.0, Vector2(10.0, 0.0), HURT_LAYER, HIT_LAYER)
	add_child_autofree(hitbox)
	add_child_autofree(hurtbox)

	await wait_physics_frames(2)

	assert_true(hurtbox.get_overlapping_areas().has(hitbox), "掩码匹配时应检测到重叠")


func test_no_overlap_when_masks_mismatch() -> void:
	var hitbox: Area2D = _make_area(16.0, Vector2.ZERO, HIT_LAYER)
	var hurtbox: Area2D = _make_area(16.0, Vector2.ZERO, HURT_LAYER)
	add_child_autofree(hitbox)
	add_child_autofree(hurtbox)

	await wait_physics_frames(2)

	assert_eq(hurtbox.get_overlapping_areas().size(), 0, "掩码不匹配时不应重叠")


func test_distance_closes_the_overlap() -> void:
	var hitbox: Area2D = _make_area(8.0, Vector2.ZERO, HIT_LAYER)
	var hurtbox: Area2D = _make_area(8.0, Vector2(100.0, 0.0), HURT_LAYER, HIT_LAYER)
	add_child_autofree(hitbox)
	add_child_autofree(hurtbox)

	await wait_physics_frames(2)

	assert_eq(hurtbox.get_overlapping_areas().size(), 0, "距离超出半径和时不应重叠")


func test_shape_query_finds_body_by_mask() -> void:
	var body := CharacterBody2D.new()
	body.collision_layer = HURT_LAYER
	body.position = Vector2(24.0, 0.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16.0, 16.0)
	shape.shape = rect
	body.add_child(shape)
	add_child_autofree(body)
	await wait_physics_frames(2)

	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	query.shape = circle
	query.transform = Transform2D(0.0, Vector2.ZERO)
	query.collision_mask = HURT_LAYER
	var hits := get_viewport().world_2d.direct_space_state.intersect_shape(query, 8)

	assert_gt(hits.size(), 0, "shape query 应命中掩码匹配的 body")
