extends GutTest

## 窗口模式判定：同一模式不重复同步；最小化时不抢恢复；
## 没有请求（-1）时不碰 DisplayServer（审计 P0-1）。


func test_same_mode_needs_no_change() -> void:
	assert_false(GameBootstrap.call("_needs_window_mode_change",
			DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_WINDOWED))


func test_switching_to_fullscreen_needs_a_change() -> void:
	assert_true(GameBootstrap.call("_needs_window_mode_change",
			DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN))
	assert_true(GameBootstrap.call("_needs_window_mode_change",
			DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_WINDOWED))


func test_minimized_window_is_left_alone() -> void:
	assert_false(GameBootstrap.call("_needs_window_mode_change",
			DisplayServer.WINDOW_MODE_MINIMIZED, DisplayServer.WINDOW_MODE_FULLSCREEN))
	assert_false(GameBootstrap.call("_needs_window_mode_change",
			DisplayServer.WINDOW_MODE_MINIMIZED, DisplayServer.WINDOW_MODE_WINDOWED))


func test_no_request_needs_no_change() -> void:
	assert_false(GameBootstrap.call("_needs_window_mode_change",
			DisplayServer.WINDOW_MODE_WINDOWED, -1))
