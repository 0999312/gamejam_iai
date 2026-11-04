class_name SpineProfiles
extends RefCounted

## 角色档案的约定位置：`res://resources/spine/<角色 id>.tres`。
## DuelView 未显式指定档案时按这个路径查；查不到就用灰盒。

const PROFILE_DIR := "res://resources/spine"


static func profile_path(id: StringName) -> String:
	return "%s/%s.tres" % [PROFILE_DIR, String(id)]


static func resolve(id: StringName) -> SpineFighterProfile:
	var path := profile_path(id)
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as SpineFighterProfile
