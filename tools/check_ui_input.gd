extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for action in ["ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right"]:
		print(action, " exists=", InputMap.has_action(action))
		if InputMap.has_action(action):
			for event in InputMap.action_get_events(action):
				print("  ", event.as_text())
	quit()
