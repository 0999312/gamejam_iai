extends GutTest

## 多语言：第二语言可加载，通用 UI 已翻译，内容仍保持占位（2026-10-21：占位保留，描述同步实际数值）。


func after_each() -> void:
	I18NManager.set_language("zh_CN")


func test_english_locale_loads() -> void:
	assert_true(I18NManager.load_translation("en", "res://localization/en.json"))
	I18NManager.set_language("en")
	assert_eq(I18NManager.get_text("menu.settings"), "Settings")
	assert_eq(I18NManager.get_text("ui.result_lose"), "Defeat")
	assert_eq(I18NManager.get_text("upgrade.u01.name"), "Iron Wall")


func test_english_has_all_generic_keys() -> void:
	I18NManager.set_language("en")
	for key in ["settings.keys", "settings.language", "shop.section.character", "pause.resume", "state.guard_rec"]:
		assert_ne(I18NManager.get_text(key), key)


func test_visible_keys_added_2026_11_05_are_localized() -> void:
	# 设置页「使用符卡」、状态兜底、角色选择面板都必须在两份 JSON 里有真实值，
	# 不能靠 _tr() 回退成原始 key。
	var keys: Array[String] = [
		"settings.key_spell_p1", "settings.key_spell_p2", "state.unknown",
		"menu.char_select_title", "menu.char_select_hint_solo", "menu.char_select_hint_versus",
		"menu.p1_character", "menu.p2_character", "menu.p1_input", "menu.p2_input",
		"menu.input_keyboard", "menu.input_gamepad", "menu.start_duel",
	]
	I18NManager.set_language("zh_CN")
	for key in keys:
		assert_ne(I18NManager.get_text(key), key, "中文缺失: %s" % key)
	I18NManager.set_language("en")
	for key in keys:
		assert_ne(I18NManager.get_text(key), key, "英文缺失: %s" % key)


func test_spell_and_spell_state_have_final_copy() -> void:
	# 2026-11-06：符卡键与 SPELL 状态名已按定稿回填（不再带占位前缀），且不能靠 _tr() 回退成键名。
	var keys: Array[String] = [
		"spell.spell_a.name", "spell.spell_a.desc",
		"spell.spell_b.name", "spell.spell_b.desc",
		"spell.spell_c.name", "spell.spell_c.desc",
		"spell.spell_boss.name", "spell.spell_boss.desc",
		"state.spell",
	]
	for key in keys:
		var zh := I18NManager.get_text(key)
		assert_ne(zh, key, "中文缺文案: %s" % key)
		assert_false(zh.begins_with("[占位]"), "中文仍是占位: %s" % key)
	I18NManager.set_language("en")
	for key in keys:
		var en := I18NManager.get_text(key)
		assert_ne(en, key, "英文缺文案: %s" % key)
		assert_false(en.begins_with("[PLACEHOLDER]"), "英文仍是占位: %s" % key)
