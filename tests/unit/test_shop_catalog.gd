extends GutTest

## 商店目录：数据驱动、可排序、类别完整。


func test_catalog_is_sorted_and_grouped() -> void:
	var items := Unlocks.catalog()
	assert_eq(items.size(), 4)
	assert_eq(items[0].id, &"char_b")
	assert_eq(items[0].category, &"character")
	assert_eq(items[2].id, &"start_slot")
	assert_eq(items[2].category, &"perk")
	assert_eq(items[3].id, &"hard_mode")
	assert_eq(items[3].category, &"mode")
	for item in items:
		assert_true(item.cost >= 0)
		assert_false(Unlocks.section_key(item.category).is_empty())


func test_toggle_requires_unlock() -> void:
	var meta := MetaSave.new()
	assert_false(Unlocks.set_toggle(meta, &"hard_mode", true))
	meta.add_unlock(&"hard_mode")
	assert_true(Unlocks.set_toggle(meta, &"hard_mode", true))
	assert_true(bool(meta.settings["hard_mode"]))


func test_character_ids_follow_catalog() -> void:
	var meta := MetaSave.new()
	assert_eq(Unlocks.character_ids(meta), [&"char_a"] as Array[StringName])
	meta.add_unlock(&"char_c")
	assert_true(Unlocks.character_ids(meta).has(&"char_c"))
