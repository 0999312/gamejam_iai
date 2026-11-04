extends SceneTree

## 把 Spine 3.8 导出的 JSON 升成 4.3 运行时可直接加载的骨架数据。
##
## 背景：art 侧的工程是 Spine 3.8.75，导出的 JSON 头里 `skeleton.spine` 写着 3.8.75；
## 4.3 运行时会以 `Skeleton version 3.8.75 does not match runtime version 4.3` 拒绝加载。
## 另外 4.3 的 C++ 运行时把旧版顶层的 `ik` / `transform` / `path` / `physics` 数组
## 改成了统一的 `constraints` 数组（每项带 `type`）。只改版本号会让约束被静默丢弃，
## 表现为骨骼动画在播、但 IK 完全不起作用。本工具同时做这两步结构迁移，
## 输出另一个文件供临时测试用。
## **正式美术资产仍应由 Spine 4.3 编辑器升级工程后重新导出**（见
## docs/dev-example/spine-integration.md §4），本工具是过渡手段。
##
## 用法：
##   godot --headless --path . -s tools/upgrade_legacy_spine_json.gd -- \
##       --src temp_assets/test_spine/skeleton.json \
##       --dst resources/spine/skeleton.spine-json
## 退出码：0 成功 / 1 读写失败 / 2 参数错误 / 3 JSON 不合法

const RUNTIME_VERSION := "4.3.00"
const LEGACY_CONSTRAINT_KEYS := ["ik", "transform", "path", "physics"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var src := ""
	var dst := ""
	for i in range(0, args.size() - 1):
		if args[i] == "--src":
			src = args[i + 1]
		elif args[i] == "--dst":
			dst = args[i + 1]
	if src.is_empty() or dst.is_empty():
		printerr("用法：--src <输入.json> --dst <输出.spine-json>")
		quit(2)
		return
	var text := FileAccess.get_file_as_string(src)
	if text.is_empty():
		printerr("读不到文件：", src)
		quit(1)
		return
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		printerr("不是合法的 JSON 对象：", src)
		quit(3)
		return
	var root: Dictionary = data
	var skeleton: Variant = root.get("skeleton", null)
	if typeof(skeleton) != TYPE_DICTIONARY:
		printerr("缺少 skeleton 段：", src)
		quit(3)
		return
	var head: Dictionary = skeleton
	var from_version := str(head.get("spine", "?"))
	head["spine"] = RUNTIME_VERSION
	root["skeleton"] = head
	var converted := _convert_legacy_constraints(root)
	var curves := _convert_legacy_curves(root)

	var out := FileAccess.open(dst, FileAccess.WRITE)
	if out == null:
		printerr("写不了文件：", dst)
		quit(1)
		return
	out.store_string(JSON.stringify(root, "\t", false))
	out.close()
	print("已升级骨架版本：", from_version, " → ", RUNTIME_VERSION)
	print("已迁移旧约束：", converted, " 条")
	print("已转换 3.8 贝塞尔曲线：", curves, " 段")
	print("输出：", dst)
	quit(0)


## 把 3.8 顶层的约束数组并入 4.3 的 `constraints`，并补上 `type`。
## 返回迁移的约束条数；没有旧约束时返回 0。
func _convert_legacy_constraints(root: Dictionary) -> int:
	var constraints: Array = []
	var existing: Variant = root.get("constraints", null)
	if typeof(existing) == TYPE_ARRAY:
		constraints = existing
	var converted := 0
	for key: String in LEGACY_CONSTRAINT_KEYS:
		var legacy: Variant = root.get(key, null)
		if typeof(legacy) != TYPE_ARRAY:
			continue
		for entry: Variant in legacy:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = entry
			if not item.has("type"):
				item["type"] = key
			constraints.append(item)
			converted += 1
		root.erase(key)
	if converted > 0:
		root["constraints"] = constraints
	return converted


## 3.8 的贝塞尔曲线是归一化的（curve/c2/c3/c4 共用一条曲线、相对时间与相对值），
## 4.3 运行时要求每个分量各自给出绝对值控制点；把 3.8 数据直接喂给 4.3 会在
## 加载时间轴时触发 signal 11（空指针）。这里按 4.x 规则重算：
##   cx = t1 + c1x * (t2 - t1)
##   cy = v1 + c1y * (v2 - v1)
## 其中 translate/scale/shear 的 x、y 各占一组四点，color 的 rgba 各占一组，
## deform 的进度固定为 0…1。步进曲线（"stepped"）原样保留。
func _convert_legacy_curves(root: Dictionary) -> int:
	var animations_v: Variant = root.get("animations", null)
	if typeof(animations_v) != TYPE_DICTIONARY:
		return 0
	var animations: Dictionary = animations_v
	var converted := 0
	for anim_key: Variant in animations.keys():
		var anim_v: Variant = animations[anim_key]
		if typeof(anim_v) != TYPE_DICTIONARY:
			continue
		var anim: Dictionary = anim_v
		converted += _convert_bone_curves(anim)
		converted += _convert_deform_curves(anim)
		converted += _convert_slot_curves(anim)
		converted += _convert_ik_curves(anim)
	return converted


func _convert_bone_curves(anim: Dictionary) -> int:
	var bones_v: Variant = anim.get("bones", null)
	if typeof(bones_v) != TYPE_DICTIONARY:
		return 0
	var bones: Dictionary = bones_v
	var converted := 0
	for bone_key: Variant in bones.keys():
		var tls_v: Variant = bones[bone_key]
		if typeof(tls_v) != TYPE_DICTIONARY:
			continue
		var tls: Dictionary = tls_v
		for tl_key: Variant in tls.keys():
			var frames_v: Variant = tls[tl_key]
			if typeof(frames_v) != TYPE_ARRAY:
				continue
			var timeline := str(tl_key)
			var frames: Array = frames_v
			if timeline == "rotate":
				converted += _convert_curve_frames(frames, PackedStringArray(["angle"]))
			elif timeline == "translate" or timeline == "scale" or timeline == "shear":
				converted += _convert_curve_frames(frames, PackedStringArray(["x", "y"]))
	return converted


func _convert_slot_curves(anim: Dictionary) -> int:
	var slots_v: Variant = anim.get("slots", null)
	if typeof(slots_v) != TYPE_DICTIONARY:
		return 0
	var slots: Dictionary = slots_v
	var converted := 0
	for slot_key: Variant in slots.keys():
		var tls_v: Variant = slots[slot_key]
		if typeof(tls_v) != TYPE_DICTIONARY:
			continue
		var tls: Dictionary = tls_v
		for tl_key: Variant in tls.keys():
			var frames_v: Variant = tls[tl_key]
			if typeof(frames_v) != TYPE_ARRAY:
				continue
			if str(tl_key) == "color":
				converted += _convert_curve_frames(frames_v, PackedStringArray(), true)
			elif str(tl_key) == "attachment":
				_strip_last_curve_fields(frames_v)
	return converted


func _convert_ik_curves(anim: Dictionary) -> int:
	var ik_v: Variant = anim.get("ik", null)
	if typeof(ik_v) != TYPE_DICTIONARY:
		return 0
	var ik: Dictionary = ik_v
	var converted := 0
	for key: Variant in ik.keys():
		var frames_v: Variant = ik[key]
		if typeof(frames_v) != TYPE_ARRAY:
			continue
		converted += _convert_curve_frames(frames_v, PackedStringArray(["mix"]))
	return converted


func _convert_deform_curves(anim: Dictionary) -> int:
	var deform_v: Variant = anim.get("deform", null)
	if typeof(deform_v) != TYPE_DICTIONARY:
		return 0
	var deform: Dictionary = deform_v
	var converted := 0
	for skin_key: Variant in deform.keys():
		var slots_v: Variant = deform[skin_key]
		if typeof(slots_v) != TYPE_DICTIONARY:
			continue
		var slots: Dictionary = slots_v
		for slot_key: Variant in slots.keys():
			var atts_v: Variant = slots[slot_key]
			if typeof(atts_v) != TYPE_DICTIONARY:
				continue
			var atts: Dictionary = atts_v
			for att_key: Variant in atts.keys():
				var frames_v: Variant = atts[att_key]
				if typeof(frames_v) == TYPE_ARRAY:
					converted += _convert_deform_frames(frames_v)
	return converted


func _convert_curve_frames(frames: Array, keys: PackedStringArray, color := false) -> int:
	_ensure_frame_times(frames)
	var count := frames.size()
	var converted := 0
	for i in range(count - 1):
		var frame_v: Variant = frames[i]
		var next_v: Variant = frames[i + 1]
		if typeof(frame_v) != TYPE_DICTIONARY or typeof(next_v) != TYPE_DICTIONARY:
			continue
		var frame: Dictionary = frame_v
		var next: Dictionary = next_v
		var curve: Variant = frame.get("curve", null)
		if not _is_legacy_curve(curve):
			continue
		var t1 := _as_float(frame.get("time", 0.0))
		var t2 := _as_float(next.get("time", t1))
		var dt := t2 - t1
		var c1x := _as_float(curve)
		var c1y := _as_float(frame.get("c2", 0.0))
		var c2x := _as_float(frame.get("c3", 0.0))
		var c2y := _as_float(frame.get("c4", 0.0))
		var values: Array = []
		if color:
			var from := _color_components(frame.get("color", "ffffffff"))
			var to := _color_components(next.get("color", "ffffffff"))
			for index in range(4):
				values.append_array(_curve_quad(t1, dt, c1x, c1y, c2x, c2y, from[index], to[index]))
		elif keys.size() == 1:
			var key := keys[0]
			var v1 := _as_float(frame.get(key, 0.0))
			var v2 := _as_float(next.get(key, 0.0))
			values.append_array(_curve_quad(t1, dt, c1x, c1y, c2x, c2y, v1, v2))
		else:
			for key: String in keys:
				var v1 := _as_float(frame.get(key, 0.0))
				var v2 := _as_float(next.get(key, 0.0))
				values.append_array(_curve_quad(t1, dt, c1x, c1y, c2x, c2y, v1, v2))
		frame["curve"] = values
		_erase_legacy_curve_fields(frame)
		converted += 1
	if count > 0:
		_strip_last_curve_fields(frames)
	return converted


func _convert_deform_frames(frames: Array) -> int:
	_ensure_frame_times(frames)
	var count := frames.size()
	var converted := 0
	for i in range(count - 1):
		var frame_v: Variant = frames[i]
		var next_v: Variant = frames[i + 1]
		if typeof(frame_v) != TYPE_DICTIONARY or typeof(next_v) != TYPE_DICTIONARY:
			continue
		var frame: Dictionary = frame_v
		var next: Dictionary = next_v
		var curve: Variant = frame.get("curve", null)
		if not _is_legacy_curve(curve):
			continue
		var t1 := _as_float(frame.get("time", 0.0))
		var t2 := _as_float(next.get("time", t1))
		var dt := t2 - t1
		frame["curve"] = [
			t1 + _as_float(curve) * dt,
			_as_float(frame.get("c2", 0.0)),
			t1 + _as_float(frame.get("c3", 0.0)) * dt,
			_as_float(frame.get("c4", 0.0)),
		]
		_erase_legacy_curve_fields(frame)
		converted += 1
	if count > 0:
		_strip_last_curve_fields(frames)
	return converted


func _curve_quad(t1: float, dt: float, c1x: float, c1y: float, c2x: float, c2y: float, v1: float, v2: float) -> Array:
	var dv := v2 - v1
	return [
		t1 + c1x * dt,
		v1 + c1y * dv,
		t1 + c2x * dt,
		v1 + c2y * dv,
	]


func _ensure_frame_times(frames: Array) -> void:
	for i in range(frames.size()):
		var frame_v: Variant = frames[i]
		if typeof(frame_v) == TYPE_DICTIONARY:
			var frame: Dictionary = frame_v
			if not frame.has("time"):
				frame["time"] = 0.0


func _is_legacy_curve(curve: Variant) -> bool:
	return typeof(curve) == TYPE_INT or typeof(curve) == TYPE_FLOAT


func _erase_legacy_curve_fields(frame: Dictionary) -> void:
	for key: String in ["c2", "c3", "c4", "c5"]:
		frame.erase(key)


func _strip_last_curve_fields(frames: Array) -> void:
	var frame_v: Variant = frames[frames.size() - 1]
	if typeof(frame_v) != TYPE_DICTIONARY:
		return
	var frame: Dictionary = frame_v
	frame.erase("curve")
	_erase_legacy_curve_fields(frame)


func _as_float(value: Variant, fallback := 0.0) -> float:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func _color_components(value: Variant) -> PackedFloat64Array:
	var text := str(value)
	if text.length() == 6:
		text += "ff"
	if text.length() < 8:
		return PackedFloat64Array([1.0, 1.0, 1.0, 1.0])
	var result := PackedFloat64Array()
	for i in range(0, 8, 2):
		result.append(float(text.substr(i, 2).hex_to_int()) / 255.0)
	return result

