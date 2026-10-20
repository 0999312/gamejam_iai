extends GutTest

## 验证 MSF 注册表 + I18N 接线：心得数据来自注册表，文本来自本地化文件。


func test_upgrade_registry_contains_ten_entries() -> void:
	var registry := RegistryManager.get_registry("upgrade")
	assert_not_null(registry)
	assert_eq(registry.get_all_keys().size(), 10)

	var data := registry.get_entry(ResourceLocation.new("iai", "u01")) as UpgradeData
	assert_not_null(data)
	assert_eq(data.effect, &"guard_duration")
	assert_eq(data.amount, 2)


func test_upgrade_text_comes_from_i18n_placeholder() -> void:
	assert_true(I18NManager.get_text("upgrade.u01.name").begins_with("[占位]"))
	assert_true(I18NManager.get_text("upgrade.u01.desc").begins_with("[占位]"))
	assert_true(I18NManager.get_text("tutorial.start").begins_with("[占位]"))


func test_generic_ui_text_is_plain() -> void:
	assert_eq(I18NManager.get_text("ui.result_lose"), "败北")
	assert_eq(I18NManager.get_text("menu.settings"), "设置")
	assert_eq(I18NManager.get_text("settings.title"), "设置")


func test_unlock_registry_is_data_driven() -> void:
	var registry := RegistryManager.get_registry("unlock")
	assert_not_null(registry)
	assert_eq(registry.get_all_keys().size(), 4)
	var item := registry.get_entry(ResourceLocation.new("iai", "char_b")) as UnlockItem
	assert_not_null(item)
	assert_eq(item.category, &"character")
	assert_eq(item.cost, 40)
	assert_eq(item.order, 10)
	var ids: Array[StringName] = []
	for entry in Unlocks.catalog():
		ids.append(entry.id)
	assert_eq(ids, [&"char_b", &"char_c", &"start_slot", &"hard_mode"] as Array[StringName])
