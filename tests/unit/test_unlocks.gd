extends GutTest

## 局外解锁目录：扣费、解锁、困难模式前置。


func test_buy_character_b() -> void:
	var meta := MetaSave.new()
	meta.gold = 50
	assert_true(Unlocks.can_buy(meta, &"char_b"))
	assert_true(Unlocks.buy(meta, &"char_b"))
	assert_eq(meta.gold, 10)
	assert_true(meta.has_unlock(&"char_b"))
	assert_false(Unlocks.can_buy(meta, &"char_b"))


func test_cannot_buy_without_gold() -> void:
	var meta := MetaSave.new()
	meta.gold = 10
	assert_false(Unlocks.can_buy(meta, &"char_c"))
	assert_false(Unlocks.buy(meta, &"char_c"))
	assert_eq(meta.gold, 10)


func test_hard_mode_requires_clear() -> void:
	var meta := MetaSave.new()
	assert_false(Unlocks.can_buy(meta, &"hard_mode"))
	meta.stats["clears"] = 1
	assert_true(Unlocks.can_buy(meta, &"hard_mode"))
	assert_true(Unlocks.buy(meta, &"hard_mode"))
	assert_true(meta.has_unlock(&"hard_mode"))


func test_set_hard_mode_requires_unlock() -> void:
	var meta := MetaSave.new()
	assert_false(Unlocks.set_hard_mode(meta, true))
	meta.add_unlock(&"hard_mode")
	assert_true(Unlocks.set_hard_mode(meta, true))
	assert_true(bool(meta.settings["hard_mode"]))


func test_character_ids_respects_unlocks() -> void:
	var meta := MetaSave.new()
	assert_eq(Unlocks.character_ids(meta), [&"char_a"] as Array[StringName])
	meta.add_unlock(&"char_b")
	meta.add_unlock(&"char_c")
	assert_eq(Unlocks.character_ids(meta), [&"char_a", &"char_b", &"char_c"] as Array[StringName])
