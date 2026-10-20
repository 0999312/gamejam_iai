extends Control

## 局外商店：目录由 Unlocks.catalog() 提供，按 category 自动分组。
## 新增条目只需改目录，本脚本不需要改。

const FONT := preload("res://assets/fonts/MiSans-Semibold.otf")
const MENU_SCENE := "res://scenes/menu/menu.tscn"
const CLICK := preload("res://assets/audio/sfx/sfx_ui_click.ogg")

var _gold_label: Label
var _rows: Dictionary = {}
var _back_button: Button


func _ready() -> void:
	_build_ui()
	_refresh()
	call_deferred("_focus_first")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0b0e13")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = _tr("shop.title")
	title.position = Vector2(0, 38)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("#e9eef5"))
	add_child(title)

	_gold_label = Label.new()
	_gold_label.position = Vector2(940, 24)
	_gold_label.size = Vector2(300, 30)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_label.add_theme_font_override("font", FONT)
	_gold_label.add_theme_font_size_override("font_size", 20)
	_gold_label.add_theme_color_override("font_color", Color("#e9eef5"))
	add_child(_gold_label)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 520)
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	var current_category: StringName = &""
	for item in Unlocks.catalog():
		if item.category != current_category:
			current_category = item.category
			var section := Label.new()
			section.text = _tr(Unlocks.section_key(item.category))
			section.custom_minimum_size = Vector2(760, 30)
			section.add_theme_font_override("font", FONT)
			section.add_theme_font_size_override("font_size", 22)
			section.add_theme_color_override("font_color", Color("#9aa7b8"))
			box.add_child(section)
		_add_row(box, item)

	var back := Button.new()
	back.text = _tr("shop.back")
	back.custom_minimum_size = Vector2(240, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_override("font", FONT)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_on_back_pressed)
	UiFocus.prepare(back)
	box.add_child(back)
	_back_button = back


func _add_row(parent: VBoxContainer, item: UnlockItem) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(760, 78)
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(540, 78)
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = _tr("shop.item.%s.name" % String(item.id))
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_color_override("font_color", Color("#e9eef5"))
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = _tr("shop.item.%s.desc" % String(item.id))
	desc_label.add_theme_font_override("font", FONT)
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color("#9aa7b8"))
	info.add_child(desc_label)

	var action := Button.new()
	action.custom_minimum_size = Vector2(200, 52)
	action.add_theme_font_override("font", FONT)
	action.add_theme_font_size_override("font_size", 17)
	action.pressed.connect(_on_action_pressed.bind(item.id))
	UiFocus.prepare(action)
	row.add_child(action)

	_rows[item.id] = {"action": action, "name": name_label, "desc": desc_label, "item": item}


func _refresh() -> void:
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if meta == null:
		return
	_gold_label.text = "%s %d" % [_tr("shop.gold"), meta.gold]
	for item in Unlocks.catalog():
		if not _rows.has(item.id):
			continue
		var action: Button = _rows[item.id]["action"]
		if meta.has_unlock(item.id):
			if item.toggle_setting != &"":
				var enabled := bool(meta.settings.get(String(item.toggle_setting), false))
				action.text = _tr("shop.hard_on" if enabled else "shop.hard_off")
				action.disabled = false
			else:
				action.text = _tr("shop.owned")
				action.disabled = true
		elif item.requires_clear and int(meta.stats.get("clears", 0)) <= 0:
			action.text = _tr("shop.requires_clear")
			action.disabled = true
		elif meta.gold < item.cost:
			action.text = "%s (%d)" % [_tr("shop.insufficient"), item.cost]
			action.disabled = true
		else:
			action.text = "%s (%d)" % [_tr("shop.buy"), item.cost]
			action.disabled = false


func _on_action_pressed(id: StringName) -> void:
	var meta := GameBootstrap.meta
	if meta == null:
		return
	var item := Unlocks.get_item(id)
	if item == null:
		return
	SoundManager.play_ui_sound(CLICK)
	if item.toggle_setting != &"" and meta.has_unlock(id):
		var enabled := bool(meta.settings.get(String(item.toggle_setting), false))
		Unlocks.set_toggle(meta, id, not enabled)
		GameBootstrap.apply_settings()
	elif Unlocks.buy(meta, id):
		GameBootstrap.save_meta()
	_refresh()


func _focus_first() -> void:
	for item in Unlocks.catalog():
		if not _rows.has(item.id):
			continue
		var action: Button = _rows[item.id]["action"]
		if action.visible and not action.disabled:
			action.grab_focus()
			return
	if _back_button != null:
		_back_button.grab_focus()


func _on_back_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	get_tree().change_scene_to_file(MENU_SCENE)


func _tr(key: String) -> String:
	var text := I18NManager.get_text(key)
	if text == key:
		return "[占位] " + key
	return text
