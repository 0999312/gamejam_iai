extends GutTest

## 多语言：第二语言可加载，通用 UI 已翻译，内容仍保持占位。


func after_each() -> void:
	I18NManager.set_language("zh_CN")


func test_english_locale_loads() -> void:
	assert_true(I18NManager.load_translation("en", "res://localization/en.json"))
	I18NManager.set_language("en")
	assert_eq(I18NManager.get_text("menu.settings"), "Settings")
	assert_eq(I18NManager.get_text("ui.result_lose"), "Defeat")
	assert_true(I18NManager.get_text("upgrade.u01.name").begins_with("[PLACEHOLDER]"))


func test_english_has_all_generic_keys() -> void:
	I18NManager.set_language("en")
	for key in ["settings.keys", "settings.language", "shop.section.character", "pause.resume", "state.guard_rec"]:
		assert_ne(I18NManager.get_text(key), key)
