class_name Unlocks
extends RefCounted

## 局外解锁目录：只做「能否买 / 扣费 / 记录解锁」的纯逻辑。
## 正式名称/描述走 I18N，避免把文案写进代码。

const ITEMS: Array[Dictionary] = [
	{"id": &"char_b", "cost": 40, "kind": &"character", "requires_clear": false},
	{"id": &"char_c", "cost": 70, "kind": &"character", "requires_clear": false},
	{"id": &"start_slot", "cost": 50, "kind": &"upgrade", "requires_clear": false},
	{"id": &"hard_mode", "cost": 0, "kind": &"mode", "requires_clear": true},
]


static func get_item(id: StringName) -> Dictionary:
	for item in ITEMS:
		if item["id"] == id:
			return item
	return {}


static func is_unlocked(meta: MetaSave, id: StringName) -> bool:
	if meta == null:
		return false
	return meta.has_unlock(id)


static func can_buy(meta: MetaSave, id: StringName) -> bool:
	if meta == null:
		return false
	var item := get_item(id)
	if item.is_empty() or meta.has_unlock(id):
		return false
	if bool(item.get("requires_clear", false)) and int(meta.stats.get("clears", 0)) <= 0:
		return false
	return meta.gold >= int(item["cost"])


static func buy(meta: MetaSave, id: StringName) -> bool:
	if not can_buy(meta, id):
		return false
	var item := get_item(id)
	if not meta.spend(int(item["cost"])):
		return false
	meta.add_unlock(id)
	meta.save()
	return true


static func set_hard_mode(meta: MetaSave, enabled: bool) -> bool:
	if meta == null or not meta.has_unlock(&"hard_mode"):
		return false
	meta.settings["hard_mode"] = enabled
	meta.save()
	return true


static func character_ids(meta: MetaSave) -> Array[StringName]:
	var result: Array[StringName] = [&"char_a"]
	if meta != null:
		if meta.has_unlock(&"char_b"):
			result.append(&"char_b")
		if meta.has_unlock(&"char_c"):
			result.append(&"char_c")
	return result
