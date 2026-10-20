class_name InputDevices
extends RefCounted

## 输入设备检测。GUIDE 的 joy_index 使用“第几个已连接手柄”（0=第一个，1=第二个），
## 不是 Godot 的 device id；这里按连接顺序分配。
## 设备映射是“追加”而非替换：键盘/鼠标与手柄可以同时驱动同一动作。

const P1_ATTACK_BUTTON := JOY_BUTTON_A
const P1_GUARD_BUTTON := JOY_BUTTON_B
const P1_PAUSE_BUTTON := JOY_BUTTON_START
const P1_RESTART_BUTTON := JOY_BUTTON_BACK


static func count() -> int:
	return Input.get_connected_joypads().size()


static func p1_joy() -> int:
	return p1_joy_of(Input.get_connected_joypads())


static func p2_joy() -> int:
	return p2_joy_of(Input.get_connected_joypads())


## 返回 GUIDE 使用的连接序号，而不是 Godot 的 device id。
static func p1_joy_of(pads: Array[int]) -> int:
	return 0 if pads.size() >= 1 else -1


static func p2_joy_of(pads: Array[int]) -> int:
	return 1 if pads.size() >= 2 else -1


static func p2_uses_gamepad() -> bool:
	return p2_joy() >= 0


static func p2_source_key() -> String:
	return "settings.gamepad_p2_pad" if p2_uses_gamepad() else "settings.gamepad_p2_keyboard"
