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
	assert_true(I18NManager.get_text("ui.result_lose").begins_with("[占位]"))
