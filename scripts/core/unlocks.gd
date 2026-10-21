class_name Unlocks
extends RefCounted

## 局外解锁目录：数据来自 MSF 注册表 "unlock"，由 GameBootstrap 扫描
## res://resources/unlocks/*.tres 注册。这里只做查询/购买/开关的纯逻辑。

const REGISTRY_NAME := "unlock"


static func catalog() -> Array[UnlockItem]:
	var items: Array[UnlockItem] = []
	var registry := _registry()
	if registry == null:
		return items
	for entry in registry.get_all_entries().values():
		if entry is UnlockItem:
			items.append(entry)
	items.sort_custom(func(a: UnlockItem, b: UnlockItem) -> bool: return a.order < b.order)
	return items


static func _registry() -> RegistryBase:
	if RegistryManager == null or not RegistryManager.has_registry(REGISTRY_NAME):
		return null
	return RegistryManager.get_registry(REGISTRY_NAME)


static func get_item(id: StringName) -> UnlockItem:
	for item in catalog():
		if item.id == id:
			return item
	return null


static func is_unlocked(meta: MetaSave, id: StringName) -> bool:
	if meta == null:
		return false
	return meta.has_unlock(id)


static func can_buy(meta: MetaSave, id: StringName) -> bool:
	if meta == null:
		return false
	var item := get_item(id)
	if item == null or meta.has_unlock(id):
		return false
	if item.requires_clear and int(meta.stats.get("clears", 0)) <= 0:
		return false
	return meta.gold >= item.cost


## 纯逻辑：改内存中的 meta 并返回结果，落盘由调用方统一决定一次。
## 这样商店一次购买只写一次档（此前 buy 内部写 + 调用方再写，审计 P2）。
static func buy(meta: MetaSave, id: StringName) -> bool:
	if not can_buy(meta, id):
		return false
	var item := get_item(id)
	if item == null or not meta.spend(item.cost):
		return false
	meta.add_unlock(id)
	return true


## 纯逻辑，同上：不落盘。
static func set_toggle(meta: MetaSave, id: StringName, enabled: bool) -> bool:
	if meta == null:
		return false
	var item := get_item(id)
	if item == null or item.toggle_setting == &"" or not meta.has_unlock(id):
		return false
	meta.settings[String(item.toggle_setting)] = enabled
	return true


static func set_hard_mode(meta: MetaSave, enabled: bool) -> bool:
	return set_toggle(meta, &"hard_mode", enabled)


static func character_ids(meta: MetaSave) -> Array[StringName]:
	var result: Array[StringName] = [&"char_a"]
	for item in catalog():
		if item.category == &"character" and meta != null and meta.has_unlock(item.id):
			result.append(item.id)
	return result


static func section_key(category: StringName) -> String:
	return "shop.section.%s" % String(category)
