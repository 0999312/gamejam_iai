# 场景测试基类模板：复制到 res://tests/fixtures/scene_test_base.gd 后使用。
# 用法：测试文件写 extends "res://tests/fixtures/scene_test_base.gd"（该类本身继承 GutTest）。
extends GutTest

const READY_SETTLE_FRAMES: int = 2


# 把节点挂进测试树，等 _ready + 1 帧物理稳定后返回。
func mount(node: Node) -> Node:
	add_child_autofree(node)
	await wait_frames(READY_SETTLE_FRAMES)
	await wait_physics_frames(1)
	return node


# 加载并挂载一个 PackedScene；路径不存在时直接给出可读失败信息。
func mount_scene(path: String) -> Node:
	assert_true(ResourceLoader.exists(path), "场景不存在: " + path)
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed, "不是 PackedScene: " + path)
	return await mount(packed.instantiate())


# 等到角色速度收敛（例如落地、位移结束），超时则失败。
func assert_body_settles(body: CharacterBody2D, max_frames: int = 30) -> void:
	for i in max_frames:
		await wait_physics_frames(1)
		if body.velocity.length() < 0.01:
			return
	fail_test("body 在 %d 个物理帧内未静止（velocity=%s）" % [max_frames, body.velocity])


func test_base_class_is_mountable() -> void:
	var node: Node = await mount(Node2D.new())

	assert_true(node.is_inside_tree())
