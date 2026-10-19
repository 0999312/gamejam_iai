# 场景集成测试：实例化 → 进树 → 等一帧 → 断言节点状态与信号。
# 关键点：用 add_child_autofree 进树并交给 GUT 回收；_ready 之后必须等至少 1 帧再断言物理/尺寸。
extends GutTest

# 占位场景部件；真实项目里换成 preload("res://scenes/combat/hitbox.tscn")。
class Hitbox:
	extends Area2D

	signal hit(target: Node)

	func _ready() -> void:
		monitoring = true
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		shape.shape = circle
		add_child(shape)


var hitbox: Hitbox = null


func before_each() -> void:
	hitbox = Hitbox.new()
	add_child_autofree(hitbox)
	await wait_frames(1)


func test_node_is_in_tree_and_ready() -> void:
	assert_true(hitbox.is_inside_tree(), "add_child_autofree 后应已进树")
	assert_true(hitbox.monitoring, "_ready 应打开 monitoring")
	assert_eq(hitbox.get_child_count(), 1, "_ready 应自动补一个 CollisionShape2D")


func test_signal_reaches_listener() -> void:
	watch_signals(hitbox)
	var target := Node2D.new()
	autofree(target)

	hitbox.hit.emit(target)

	assert_signal_emitted_with_parameters(hitbox, "hit", [target])


func test_queue_free_releases_the_node() -> void:
	var temp := Node2D.new()
	add_child_autofree(temp)
	await wait_frames(1)

	temp.queue_free()
	await wait_frames(2)

	assert_freed(temp, "queue_free 后应被释放")
