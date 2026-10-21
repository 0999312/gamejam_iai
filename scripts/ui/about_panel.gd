class_name AboutPanel
extends UIPanel

## 游戏内「关于」页（UIManager 面板）：作品信息、东方 Project 二次创作声明、
## 制作名单、AI 使用说明、技术与素材来源。
##
## 合规要求（docs/gamejam/constraints.md §2、AGENTS.md §2）：
## 二次创作声明必须出现在游戏内「关于」页与提交 README，禁止暗示官方授权。
## 本页文案由 AI 起草、人类（射命丸政）2026-10-21 指示按实际开发情况采用，
## 记录见 docs/gamejam/ai-disclosure.md。

const FONT := preload("res://assets/fonts/MiSans-Semibold.otf")
const CLICK := preload("res://assets/audio/sfx/sfx_ui_click.ogg")

## 版本号：与 `project.godot` 的 `config/version` 保持一致（发布版本语义化）。
const VERSION_TEXT := "0.1.0"

const TEXT_COLOR := Color("#e9eef5")
const MUTED_COLOR := Color("#9aa7b8")
const ACCENT_COLOR := Color("#ffd36e")

var _back_button: Button


func _on_init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _enter_tree() -> void:
	EventBus.subscribe(&"LanguageChangedEvent", _on_language_changed)


func _ready() -> void:
	_build_ui()


func _exit_tree() -> void:
	EventBus.unsubscribe(&"LanguageChangedEvent", _on_language_changed)


func _on_open(_data: Dictionary = {}) -> void:
	call_deferred("_focus_default")


func _focus_default() -> void:
	if _back_button != null:
		_back_button.grab_focus()


func _on_language_changed(_event: Event) -> void:
	if not is_inside_tree():
		return
	_build_ui()
	call_deferred("_focus_default")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_back_button = null

	var bg := ColorRect.new()
	bg.color = Color("#0b0e13")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = _tr("about.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 26
	title.offset_bottom = 86
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 140
	scroll.offset_right = -140
	scroll.offset_top = 100
	scroll.offset_bottom = -88
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)

	_add_body(box, _tr("about.theme_label") + "：" + _tr("about.theme"), MUTED_COLOR, 18)
	_add_rule(box)
	# 二创声明单独高亮并置于前列：这是合规红线，不能藏在页脚。
	_add_body(box, _tr("about.derivative"), ACCENT_COLOR, 20)
	_add_body(box, _tr("about.disclaimer"), MUTED_COLOR, 16)
	_add_rule(box)
	_add_section(box, "about.credits_title", "about.credits")
	_add_section(box, "about.ai_title", "about.ai_body")
	_add_section(box, "about.tech_title", "about.tech")
	_add_rule(box)
	_add_body(box, "v%s · Godot 4.7.2" % VERSION_TEXT, MUTED_COLOR, 14)

	_back_button = Button.new()
	_back_button.text = _tr("about.back")
	_back_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_back_button.offset_left = -120
	_back_button.offset_right = 120
	_back_button.offset_top = -72
	_back_button.offset_bottom = -24
	_back_button.add_theme_font_override("font", FONT)
	_back_button.add_theme_font_size_override("font_size", 20)
	_back_button.pressed.connect(_on_back_pressed)
	UiFocus.prepare(_back_button)
	add_child(_back_button)


func _add_section(parent: VBoxContainer, title_key: String, body_key: String) -> void:
	_add_body(parent, _tr(title_key), TEXT_COLOR, 22)
	_add_body(parent, _tr(body_key), MUTED_COLOR, 16)


## 正文统一走这个入口：自动换行 + 左对齐；字号与颜色显式给，避免主题漂移。
func _add_body(parent: VBoxContainer, text: String, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _add_rule(parent: VBoxContainer) -> void:
	var rule := ColorRect.new()
	rule.color = Color("#1b2230")
	rule.custom_minimum_size = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(rule)


func _on_back_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	UIManager.back(UILayer.NORMAL)


func _tr(key: String) -> String:
	var text := I18NManager.get_text(key)
	if text == key:
		return "[占位] " + key
	return text
