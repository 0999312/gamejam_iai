class_name UiFocus
extends RefCounted

## 统一 UI 焦点可视化：所有可交互控件都能用键盘/手柄导航。
## 无边框取向：焦点只在左侧留一道刀鞘金，不画整圈高亮框、不染文字。

const FOCUS_TINT := Color.WHITE


static func prepare(control: Control) -> void:
	control.focus_mode = Control.FOCUS_ALL
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	ring.border_color = Color("#c8a063")
	ring.border_width_bottom = 2
	ring.set_corner_radius_all(0)
	control.add_theme_stylebox_override("focus", ring)
	control.focus_entered.connect(_on_focus_entered.bind(control))
	control.focus_exited.connect(_on_focus_exited.bind(control))
	control.modulate = Color.WHITE


static func _on_focus_entered(control: Control) -> void:
	control.modulate = FOCUS_TINT


static func _on_focus_exited(control: Control) -> void:
	control.modulate = Color.WHITE
