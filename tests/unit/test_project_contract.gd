extends GutTest
## 开发契约守卫（见 docs/dev-contract.md §4）。
##
## 目的：把「插件优先」从口头约定变成会失败的测试。扫描 res://scripts/ 下全部 .gd，
## 命中禁止 API 即失败；同时校验关键插件仍挂在 project.godot 的 autoload 上。
## 新增规则时先改 docs/dev-contract.md §4，再改这里的 _BANNED，最后修代码。
##
## 2026-10-21 重写（审计 P1-7）：原实现是子串匹配，`var i := Input` 后
## `i.is_action_pressed()`、`Input . is_action_pressed()`、`Input.get_vector()` 都能绕过，
## 且目录打不开时直接「零违规」通过。现在改为：
##   1. 正则 + 标识符边界，覆盖别名外的常见变体；
##   2. 扫描前剥离注释与字符串，避免把注释里的示例当违规；
##   3. 扫描失败（目录空/文件读不到）直接 fail；
##   4. 扫描器本身有自检用例。

const SCRIPT_ROOT := "res://scripts"

## 脚本根之外、同样受契约约束的文件。
const _EXTRA_FILES: Array[String] = [
	"res://tools/generate_guide_context.gd",
]

## 禁止写法（正则）→ 应改用的插件。
const _BANNED: Array[Dictionary] = [
	{
		"pattern": "(?<![\\w.])Input\\.(is_action_|get_axis\\(|get_vector\\(|get_joy_axis\\(|get_action_strength\\(|get_action_raw_strength\\()",
		"reason": "输入必须经 GUIDE 上下文（GUIDEAction / GUIDEMappingContext）",
	},
	{
		"pattern": "(?m)^\\s*var\\s+\\w+\\s*:?=\\s*Input\\s*(#.*)?$",
		"reason": "不得把 Input 单例整个赋给变量来绕过直读检查",
	},
	{
		"pattern": "AudioStreamPlayer(2D|3D)?\\.new\\(",
		"reason": "音频必须经 SoundManager",
	},
	{
		"pattern": "TranslationServer\\.",
		"reason": "翻译必须经 I18NManager",
	},
	{
		"pattern": "GUIDEMappingContext\\.new\\(",
		"reason": "GUIDE 上下文必须是 res://input/contexts 下的资源（用 InputGuide.context_for 载入），不得在代码里现搭",
		# 包装层只把资源复制成对局独占实例，不定义任何动作/输入；
		# 生成器本来就是产出资源的工具。
		"allow": ["res://scripts/core/input_guide.gd", "res://tools/generate_guide_context.gd"],
	},
	{
		"pattern": "AudioServer\\.set_bus_(volume_db|mute)\\(",
		"reason": "音频总线音量应经 SoundManager；插件缺 Master/mute API 的豁免见 docs/dev-contract.md §3.1",
		"allow": ["res://scripts/core/game_bootstrap.gd"],
	},
	{
		"pattern": "InputMap\\.action_add_event\\(",
		"reason": "运行时改 InputMap 只允许在 GameBootstrap 里为内置 ui_* 动作补手柄事件（§3.1 豁免）",
		"allow": ["res://scripts/core/game_bootstrap.gd"],
	},
	{
		"pattern": "GUIDE\\._input_state",
		"reason": "GUIDE 的私有成员只允许在 GameBootstrap 的热插拔兜底里访问（§3.1 豁免）",
		"allow": ["res://scripts/core/game_bootstrap.gd"],
	},
	{
		"pattern": "config\\._(bind|unbind)\\(",
		"reason": "GUIDERemappingConfig._bind/_unbind 是插件私有 API，只允许 input_guide 包装层调用（§3.1 豁免）",
		"allow": ["res://scripts/core/input_guide.gd"],
	},
]

## 必须保持启用的插件单例。
const _REQUIRED_AUTOLOADS: Array[String] = [
	"GUIDE",
	"SoundManager",
	"I18NManager",
	"RegistryManager",
	"EventBus",
	"UIManager",
]

## 输入资源的固定位置（生成器见 tools/generate_guide_context.gd）。
const _INPUT_CONTEXTS: Array[String] = [
	"res://input/contexts/duel_run.tres",
	"res://input/contexts/duel_versus.tres",
]


func test_scripts_do_not_bypass_plugins() -> void:
	var files := _collect_files()
	# 扫描不到文件不是「零违规」，是守卫失效（审计 P1-7）。
	assert_gt(files.size(), 20, "守卫扫描到的脚本数异常偏少，规则已失效")
	var offenders: Array[String] = []
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		assert_false(text.is_empty(), "无法读取 %s，守卫不能静默跳过" % path)
		offenders.append_array(_scan_text(path, text))
	assert_eq(offenders.size(), 0,
			"检测到绕过插件的写法，规则见 docs/dev-contract.md §4：\n" + "\n".join(offenders))


## 扫描器自检：这些写法必须被抓到。
func test_scanner_detects_known_bypasses() -> void:
	var samples: Array[String] = [
		"func f() -> void:\n\tvar i := Input\n\ti.is_action_pressed(\"x\")\n",
		"func f() -> void:\n\tif Input.is_action_just_pressed(\"x\"):\n\t\tpass\n",
		"func f() -> void:\n\tvar v := Input.get_vector(\"a\", \"b\", \"c\", \"d\")\n",
		"func f() -> void:\n\tvar p := AudioStreamPlayer.new()\n",
		"func f() -> void:\n\tvar t := TranslationServer.translate(\"x\")\n",
		"func f() -> void:\n\tvar c := GUIDEMappingContext.new()\n",
		"func f() -> void:\n\tAudioServer.set_bus_mute(0, true)\n",
		"func f() -> void:\n\tInputMap.action_add_event(\"ui_accept\", InputEventKey.new())\n",
		"func f() -> void:\n\tGUIDE._input_state._refresh_joy_device_ids(0, 0)\n",
	]
	for sample in samples:
		assert_gt(_scan_text("res://scripts/unit_test_fake.gd", sample).size(), 0,
				"扫描器漏报：%s" % sample)


## 注释与字符串里的示例代码不得算违规。
func test_scanner_ignores_comments_and_strings() -> void:
	var samples: Array[String] = [
		"# 旧写法：Input.is_action_pressed(\"attack\") 已废弃\nfunc f() -> void:\n\tpass\n",
		"func f() -> String:\n\treturn \"AudioStreamPlayer.new() 是禁止的\"\n",
	]
	for sample in samples:
		assert_eq(_scan_text("res://scripts/unit_test_fake.gd", sample).size(), 0,
				"扫描器误报注释/字符串：%s" % sample)


func test_required_plugins_are_enabled() -> void:
	for autoload_name in _REQUIRED_AUTOLOADS:
		assert_true(ProjectSettings.has_setting("autoload/" + autoload_name),
				"插件单例 %s 必须在 project.godot 启用（docs/dev-contract.md §3）" % autoload_name)


func test_input_contexts_are_resources() -> void:
	for path in _INPUT_CONTEXTS:
		assert_true(ResourceLoader.exists(path), "缺少 GUIDE 上下文资源：%s" % path)
		var context := load(path) as GUIDEMappingContext
		assert_not_null(context, "%s 必须能载入为 GUIDEMappingContext" % path)
		if context == null:
			continue
		assert_gt(context.mappings.size(), 0, "%s 里必须有动作映射" % path)
		for mapping in context.mappings:
			assert_not_null(mapping.action, "%s 里有映射没绑动作" % path)
			assert_gt(mapping.input_mappings.size(), 0,
					"%s 的动作 %s 没有输入" % [path, mapping.action.name])


## 纯函数：返回该文件命中的违规描述（不读文件，便于自检）。
func _scan_text(path: String, text: String) -> Array[String]:
	var offenders: Array[String] = []
	var clean := strip_noise(text)
	for rule in _BANNED:
		if path in rule.get("allow", []):
			continue
		var regex := RegEx.new()
		if regex.compile(String(rule["pattern"])) != OK:
			offenders.append("规则正则编译失败：%s" % rule["pattern"])
			continue
		if regex.search(clean) != null:
			offenders.append("%s 命中「%s」→ %s" % [path, rule["pattern"], rule["reason"]])
	return offenders


## 去掉行注释与双引号字符串内容，避免把示例代码当成真实违规。
static func strip_noise(text: String) -> String:
	var out := ""
	var i := 0
	var n := text.length()
	var in_string := false
	var in_comment := false
	while i < n:
		var ch := text[i]
		if in_comment:
			if ch == "\n":
				in_comment = false
				out += ch
			i += 1
			continue
		if in_string:
			if ch == "\\":
				i += 2
				continue
			if ch == "\"":
				in_string = false
			i += 1
			continue
		if ch == "#":
			in_comment = true
			i += 1
			continue
		if ch == "\"":
			in_string = true
			i += 1
			continue
		out += ch
		i += 1
	return out


func _collect_files() -> Array[String]:
	var files := _gd_files(SCRIPT_ROOT)
	for extra in _EXTRA_FILES:
		if FileAccess.file_exists(extra):
			files.append(extra)
	return files


## 递归收集 .gd 文件（不依赖编辑器状态，headless 可用）。
func _gd_files(root: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := root.path_join(entry)
			if dir.current_is_dir():
				found.append_array(_gd_files(full))
			elif entry.ends_with(".gd"):
				found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
