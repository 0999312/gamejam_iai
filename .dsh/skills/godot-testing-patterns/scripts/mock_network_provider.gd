# 离线 multiplayer 对端：测 RPC 时不要拉起真实 ENet，先换 OfflineMultiplayerPeer。
# 本项目为单机双人对决，网络相关测试仅在接入联机时才需要。
extends GutTest

# 建议复制到 res://tests/fixtures/offline_multiplayer.gd 作为测试辅助。
class OfflineMultiplayerHelper:
	extends RefCounted

	static func enable_offline(tree: SceneTree) -> void:
		tree.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	static func disable(tree: SceneTree) -> void:
		tree.multiplayer.multiplayer_peer = null


var _original_peer: MultiplayerPeer = null


func before_each() -> void:
	_original_peer = get_tree().multiplayer.multiplayer_peer
	OfflineMultiplayerHelper.enable_offline(get_tree())
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(_original_peer):
		get_tree().multiplayer.multiplayer_peer = _original_peer
	else:
		OfflineMultiplayerHelper.disable(get_tree())


func test_offline_peer_reports_server_identity() -> void:
	assert_true(get_tree().multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	assert_true(multiplayer.is_server(), "离线对端下应视为 server")


func test_offline_peer_has_no_remote_peers() -> void:
	var peers: PackedInt32Array = multiplayer.get_peers()
	assert_eq(peers.size(), 0, "离线对端不应有远端连接")


func test_rpc_to_missing_peer_fails_safely() -> void:
	# 无真实对端时，rpc 到不存在的 peer 应安静失败而不是崩溃。
	var target := Node.new()
	add_child_autofree(target)
	target.rpc_id(99, "notify", 1)
	await wait_frames(1)
	assert_true(is_instance_valid(target), "无对端时 rpc 不应导致节点被销毁")
