extends Node

## 开发期截图：以临时主场景运行（autoload 正常加载），拍菜单 / 设置 / HUD。
## 用法：godot --path . res://tools/theme_preview.tscn


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var menu := (load("res://scenes/menu/menu.tscn") as PackedScene).instantiate() as Control
	add_child(menu)
	for i in 24:
		await get_tree().process_frame
	if not await _save("res://docs/dev-example/theme-menu.png"):
		return

	var panel := UIManager.open_panel(PanelIds.settings())
	if panel != null:
		for i in 12:
			await get_tree().process_frame
		if not await _save("res://docs/dev-example/theme-settings.png"):
			return
		UIManager.close_panel(PanelIds.settings())
		for i in 4:
			await get_tree().process_frame
	else:
		push_warning("theme_preview: 设置面板未打开")

	menu.queue_free()
	for i in 4:
		await get_tree().process_frame

	var view := (load("res://scenes/duel/duel_view.tscn") as PackedScene).instantiate() as DuelView
	add_child(view)
	var sim := DuelSim.new(FighterData.player_a(), FighterData.player_b(), 3)
	view.bind(sim)
	var hud := (load("res://scenes/duel/hud.tscn") as PackedScene).instantiate() as DuelHud
	add_child(hud)
	hud.set_run(RunState.new(3))
	hud.bind(sim)
	for i in 24:
		await get_tree().process_frame
	if not await _save("res://docs/dev-example/theme-duel-hud.png"):
		return
	get_tree().quit(0)


func _save(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("theme_preview: 取不到视口画面")
		get_tree().quit(1)
		return false
	var error := image.save_png(path)
	if error != OK:
		push_error("theme_preview: 写成 PNG 失败，错误码 %d" % error)
		get_tree().quit(1)
		return false
	print("theme_preview: 已写入 %s（%d×%d）" % [path, image.get_width(), image.get_height()])
	return true
