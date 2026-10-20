extends Control

## 局外商店：解锁角色 B/C、起始心得槽、困难模式。
## 目录在 Unlocks；本脚本只做展示与按钮状态。

const FONT := preload("res://assets/fonts/MiSans-Semibold.otf")
const MENU_SCENE := "res://scenes/menu/menu.tscn"
const CLICK := preload("res://assets/audio/sfx/sfx_ui_click.ogg")

var _gold_label: Label
var _rows: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0b0e13")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = _tr("shop.title")
	title.position = Vector2(0, 42)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 40)
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
	box.custom_minimum_size = Vector2(760, 460)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	for item in Unlocks.ITEMS:
		var id: StringName = item["id"]
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(760, 88)
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)

		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(540, 88)
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)

		var name_label := Label.new()
		name_label.text = _tr("shop.item.%s.name" % String(id))
		name_label.add_theme_font_override("font", FONT)
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color("#e9eef5"))
		info.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = _tr("shop.item.%s.desc" % String(id))
		desc_label.add_theme_font_override("font", FONT)
		desc_label.add_theme_font_size_override("font_size", 15)
		desc_label.add_theme_color_override("font_color", Color("#9aa7b8"))
		info.add_child(desc_label)

		var action := Button.new()
		action.custom_minimum_size = Vector2(200, 56)
		action.add_theme_font_override("font", FONT)
		action.add_theme_font_size_override("font_size", 18)
		action.pressed.connect(_on_action_pressed.bind(id))
		row.add_child(action)

		_rows[id] = {"action": action, "name": name_label}

	var back := Button.new()
	back.text = _tr("shop.back")
	back.custom_minimum_size = Vector2(240, 52)
	back.add_theme_font_override("font", FONT)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_on_back_pressed)
	box.add_child(back)


func _refresh() -> void:
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if meta == null:
		return
	_gold_label.text = "%s %d" % [_tr("shop.gold"), meta.gold]
	for item in Unlocks.ITEMS:
		var id: StringName = item["id"]
		if not _rows.has(id):
			continue
		var action: Button = _rows[id]["action"]
		if meta.has_unlock(id):
			if id == &"hard_mode":
				var enabled := bool(meta.settings.get("hard_mode", false))
				action.text = _tr("shop.hard_on" if enabled else "shop.hard_off")
				action.disabled = false
			else:
				action.text = _tr("shop.owned")
				action.disabled = true
		elif bool(item.get("requires_clear", false)) and int(meta.stats.get("clears", 0)) <= 0:
			action.text = _tr("shop.requires_clear")
			action.disabled = true
		elif meta.gold < int(item["cost"]):
			action.text = "%s (%d)" % [_tr("shop.insufficient"), int(item["cost"])]
			action.disabled = true
		else:
			action.text = "%s (%d)" % [_tr("shop.buy"), int(item["cost"])]
			action.disabled = false


func _on_action_pressed(id: StringName) -> void:
	var meta := GameBootstrap.meta
	if meta == null:
		return
	SoundManager.play_ui_sound(CLICK)
	if id == &"hard_mode" and meta.has_unlock(id):
		var enabled := bool(meta.settings.get("hard_mode", false))
		Unlocks.set_hard_mode(meta, not enabled)
		GameBootstrap.apply_settings()
	elif Unlocks.buy(meta, id):
		GameBootstrap.save_meta()
	_refresh()


func _on_back_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	get_tree().change_scene_to_file(MENU_SCENE)


func _tr(key: String) -> String:
	var text := I18NManager.get_text(key)
	if text == key:
		return "[占位] " + key
	return text
