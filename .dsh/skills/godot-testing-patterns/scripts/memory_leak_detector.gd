# 孤儿节点检测：GUT 自带 assert_no_new_orphans()，在 after_all 里统一兜底。
# 常见泄漏点：new 了节点但没进树、没 free / queue_free、信号连接持有引用。
extends GutTest

var _orphan_baseline: int = 0


func before_all() -> void:
	_orphan_baseline = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func after_all() -> void:
	assert_no_new_orphans("套件结束后仍有未释放的节点")


func test_free_keeps_orphan_count_flat() -> void:
	var node := Node.new()
	node.free()
	await wait_frames(1)

	var current: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	assert_true(current <= _orphan_baseline + 1, "free() 之后孤儿数不应上涨（当前 %d）" % current)


func test_add_child_autofree_cleans_up() -> void:
	var node := Node2D.new()
	add_child_autofree(node)
	await wait_frames(1)

	assert_true(is_instance_valid(node), "测试运行期间节点应有效")


func test_queue_free_releases_after_frames() -> void:
	var node := Node2D.new()
	add_child_autofree(node)
	await wait_frames(1)

	node.queue_free()
	await wait_frames(2)

	assert_freed(node, "queue_free 后应在数帧内释放")
