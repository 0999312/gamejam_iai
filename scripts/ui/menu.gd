extends Control

## 灰盒主菜单：角色选择 / 单人阶梯 / 本地双人 / 商店 / 设置 / 退出。
## 文本全部走 I18N 占位键，正式文案由人类替换。

const FONT := preload("res://assets/fonts/MiSans-Semibold.otf")
const DUEL_SCENE := "res://scenes/duel/duel.tscn"
const CLICK := preload("res://assets/audio/sfx/sfx_ui_click.ogg")

var _gold_label: Label
var _char_option: OptionButton


func _ready() -> void:
	_build_ui()
	# 菜单是常驻基座：商店/设置以面板叠加在上面，返回时本场景不重建。
	# 所以金币、可选角色、文案都必须靠事件刷新。
	EventBus.subscribe(&"LanguageChangedEvent", _on_language_changed)
	EventBus.subscribe(&"UnlockPurchasedEvent", _on_unlock_purchased)


func _exit_tree() -> void:
	EventBus.unsubscribe(&"LanguageChangedEvent", _on_language_changed)
	EventBus.unsubscribe(&"UnlockPurchasedEvent", _on_unlock_purchased)


func _on_language_changed(_event: Event) -> void:
	# 只有在焦点本来就在菜单上时才抢焦点：设置/商店/关于页打开时切语言，
	# 菜单重建不能把焦点从正在操作的面板里抢走（审计 P3）。
	var viewport := get_viewport()
	var owner := viewport.gui_get_focus_owner() if viewport != null else null
	var had_focus := owner != null and is_ancestor_of(owner)
	_build_ui(had_focus)


func _on_unlock_purchased(_event: Event) -> void:
	_refresh_gold()
	_populate_characters()


func _build_ui(restore_focus: bool = true) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_gold_label = null
	_char_option = null

	var bg := ColorRect.new()
	bg.color = Color("#0b0e13")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = _tr("menu.title")
	title.position = Vector2(0, 46)
	title.size = Vector2(1280, 66)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#e9eef5"))
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = _tr("menu.subtitle")
	subtitle.position = Vector2(0, 116)
	subtitle.size = Vector2(1280, 28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", FONT)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("#9aa7b8"))
	add_child(subtitle)

	_gold_label = Label.new()
	_gold_label.position = Vector2(940, 24)
	_gold_label.size = Vector2(300, 30)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_label.add_theme_font_override("font", FONT)
	_gold_label.add_theme_font_size_override("font_size", 20)
	_gold_label.add_theme_color_override("font_color", Color("#e9eef5"))
	add_child(_gold_label)
	_refresh_gold()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 副标题底边约在 144px：把内容区起点压到 150，避免竖排按钮把
	# CenterContainer 撑高后与标题/副标题重叠（用户 2026-10-21 反馈）。
	center.offset_top = 150.0
	add_child(center)

	var box := VBoxContainer.new()
	# 只给宽度下限，高度交给内容：写死 430 时按钮一多就会顶到标题带。
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var char_row := HBoxContainer.new()
	char_row.custom_minimum_size = Vector2(420, 44)
	char_row.add_theme_constant_override("separation", 10)
	box.add_child(char_row)

	var char_label := Label.new()
	char_label.text = _tr("menu.character")
	char_label.custom_minimum_size = Vector2(100, 44)
	char_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	char_label.add_theme_font_override("font", FONT)
	char_label.add_theme_font_size_override("font_size", 20)
	char_label.add_theme_color_override("font_color", Color("#c7d2df"))
	char_row.add_child(char_label)

	_char_option = OptionButton.new()
	_char_option.custom_minimum_size = Vector2(300, 44)
	_char_option.add_theme_font_override("font", FONT)
	_char_option.add_theme_font_size_override("font_size", 18)
	_char_option.item_selected.connect(_on_character_selected)
	UiFocus.prepare(_char_option)
	char_row.add_child(_char_option)
	_populate_characters()

	var char_hint := Label.new()
	char_hint.text = _tr("menu.character_hint")
	char_hint.custom_minimum_size = Vector2(420, 22)
	char_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_hint.add_theme_font_override("font", FONT)
	char_hint.add_theme_font_size_override("font_size", 14)
	char_hint.add_theme_color_override("font_color", Color("#7f8b9c"))
	box.add_child(char_hint)

	# 模式选择收进二级菜单：主菜单只留一个「开始游戏」，
	# 避免六个按钮竖排后与标题/副标题重叠（用户 2026-10-21 反馈）。
	var start_button := _make_button(box, _tr("menu.start"))
	start_button.pressed.connect(_on_start_pressed)

	var shop_button := _make_button(box, _tr("menu.shop"))
	shop_button.pressed.connect(_on_shop_pressed)

	var settings_button := _make_button(box, _tr("menu.settings"))
	settings_button.pressed.connect(_on_settings_pressed)

	var quit_button := _make_button(box, _tr("menu.quit"))
	quit_button.pressed.connect(_on_quit_pressed)

	var hint := Label.new()
	hint.text = _tr("menu.hint")
	hint.position = Vector2(0, 660)
	hint.size = Vector2(1280, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("#7f8b9c"))
	add_child(hint)

	if restore_focus:
		start_button.grab_focus()


func _make_button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(420, 56)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 22)
	UiFocus.prepare(button)
	parent.add_child(button)
	return button


func _populate_characters() -> void:
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	var ids := Unlocks.character_ids(meta)
	_char_option.clear()
	if ids.is_empty():
		# 正常路径不会发生（char_a 恒可用）；防御未初始化注册表时越界。
		return
	var selected := 0
	for i in ids.size():
		var id := ids[i]
		_char_option.add_item(_tr("menu.%s" % String(id)))
		_char_option.set_item_metadata(i, String(id))
		if id == GameBootstrap.pending_character:
			selected = i
	_char_option.select(selected)
	GameBootstrap.pending_character = ids[selected]


func _on_character_selected(index: int) -> void:
	var id := String(_char_option.get_item_metadata(index))
	GameBootstrap.pending_character = StringName(id)
	SoundManager.play_ui_sound(CLICK)


func _refresh_gold() -> void:
	var gold := 0
	if GameBootstrap.meta != null:
		gold = GameBootstrap.meta.gold
	_gold_label.text = "%s %d" % [_tr("menu.gold"), gold]


func _on_start_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	var panel := UIManager.open_panel(PanelIds.mode_select()) as ModeSelectPanel
	if panel == null:
		return
	panel.mode_chosen.connect(_on_mode_chosen)


func _on_mode_chosen(mode: StringName) -> void:
	GameBootstrap.pending_mode = mode
	if UIManager.is_panel_open(PanelIds.mode_select()):
		UIManager.close_panel(PanelIds.mode_select())
	_go_duel()


func _on_shop_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	UIManager.open_panel(PanelIds.shop())


func _on_settings_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	UIManager.open_panel(PanelIds.settings())


func _on_quit_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	get_tree().quit()


func _go_duel() -> void:
	var error := get_tree().change_scene_to_file(DUEL_SCENE)
	if error != OK:
		push_error("Menu: 无法载入对局场景 %s（错误码 %d）" % [DUEL_SCENE, error])


func _tr(key: String) -> String:
	var text := I18NManager.get_text(key)
	if text == key:
		return "[占位] " + key
	return text
