extends GutTest

## 输入设备检测：键鼠与手柄并存、P2 第二手柄判定。


func test_no_gamepad() -> void:
	var pads: Array[int] = []
	assert_eq(InputDevices.p1_joy_of(pads), -1)
	assert_eq(InputDevices.p2_joy_of(pads), -1)


func test_one_gamepad_goes_to_p1() -> void:
	var pads: Array[int] = [0]
	assert_eq(InputDevices.p1_joy_of(pads), 0)
	assert_eq(InputDevices.p2_joy_of(pads), -1)


func test_two_gamepads_split_between_players() -> void:
	var pads: Array[int] = [0, 1]
	assert_eq(InputDevices.p1_joy_of(pads), 0)
	assert_eq(InputDevices.p2_joy_of(pads), 1)


func test_connection_indices_are_used() -> void:
	var pads: Array[int] = [2, 5]
	assert_eq(InputDevices.p1_joy_of(pads), 0)
	assert_eq(InputDevices.p2_joy_of(pads), 1)


func test_p2_source_key_follows_detection() -> void:
	assert_eq(InputDevices.p2_source_key(), "settings.gamepad_p2_pad" if InputDevices.p2_uses_gamepad() else "settings.gamepad_p2_keyboard")
