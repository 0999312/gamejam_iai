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


func test_spell_and_spell_state_have_explicit_placeholders() -> void:
	# 符卡键与新增的 SPELL 状态名都必须在 JSON 里有显式占位，不能靠 _tr() 回退。
	var keys: Array[String] = [
		"spell.spell_a.name", "spell.spell_a.desc",
		"spell.spell_b.name", "spell.spell_b.desc",
		"spell.spell_c.name", "spell.spell_c.desc",
		"spell.spell_boss.name", "spell.spell_boss.desc",
		"state.spell",
	]
	for key in keys:
		assert_true(I18NManager.get_text(key).begins_with("[占位]"), "缺失中文占位: %s" % key)
	I18NManager.set_language("en")
	for key in keys:
		assert_true(I18NManager.get_text(key).begins_with("[PLACEHOLDER]"), "缺失英文占位: %s" % key)
