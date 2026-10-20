extends Control

## 灰盒主菜单：角色选择 / 单人阶梯 / 本地双人 / 商店 / 设置 / 退出。
## 文本全部走 I18N 占位键，正式文案由人类替换。

const FONT := preload("res://assets/fonts/MiSans-Semibold.otf")
const DUEL_SCENE := "res://scenes/duel/duel.tscn"
const SHOP_SCENE := "res://scenes/ui/shop.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings.tscn"
const CLICK := preload("res://assets/audio/sfx/sfx_ui_click.ogg")

var _gold_label: Label
var _char_option: OptionButton


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
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
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 430)
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

	var start_button := _make_button(box, _tr("menu.start"))
	start_button.pressed.connect(_on_start_pressed)

	var versus_button := _make_button(box, _tr("menu.versus"))
	versus_button.pressed.connect(_on_versus_pressed)

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
	GameBootstrap.pending_mode = &"run"
	_go_duel()


func _on_versus_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	GameBootstrap.pending_mode = &"versus"
	_go_duel()


func _on_shop_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	get_tree().change_scene_to_file(SHOP_SCENE)


func _on_settings_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func _on_quit_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	get_tree().quit()


func _go_duel() -> void:
	get_tree().change_scene_to_file(DUEL_SCENE)


func _tr(key: String) -> String:
	var text := I18NManager.get_text(key)
	if text == key:
		return "[占位] " + key
	return text
