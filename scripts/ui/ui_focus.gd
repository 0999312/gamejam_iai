class_name UiFocus
extends RefCounted

## 统一 UI 焦点可视化：所有可交互控件都能用键盘/手柄导航。
## 只改 modulate，不覆盖主题，避免不同控件类型各写一套 focus stylebox。

const FOCUS_TINT := Color(1.0, 0.86, 0.52)


static func prepare(control: Control) -> void:
	control.focus_mode = Control.FOCUS_ALL
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	ring.border_color = Color("#ffd166")
	ring.set_border_width_all(3)
	ring.set_corner_radius_all(6)
	control.add_theme_stylebox_override("focus", ring)
	control.focus_entered.connect(_on_focus_entered.bind(control))
	control.focus_exited.connect(_on_focus_exited.bind(control))
	control.modulate = Color.WHITE


static func _on_focus_entered(control: Control) -> void:
	control.modulate = FOCUS_TINT


static func _on_focus_exited(control: Control) -> void:
	control.modulate = Color.WHITE
