extends GutTest
## 开发契约守卫（见 docs/dev-contract.md §4）。
##
## 目的：把「插件优先」从口头约定变成会失败的测试。扫描 res://scripts/ 下全部 .gd，
## 命中禁止 API 即失败；同时校验关键插件仍挂在 project.godot 的 autoload 上。
## 新增规则时先改 docs/dev-contract.md §4，再改这里的 _BANNED，最后修代码。

const SCRIPT_ROOT := "res://scripts"

## 禁止写法 → 应改用的插件。
const _BANNED: Array[Dictionary] = [
	{
		"needle": "Input.is_action_",
		"reason": "输入必须经 GUIDE 上下文（GUIDEAction / GUIDEMappingContext）",
	},
	{
		"needle": "Input.get_axis(",
		"reason": "输入必须经 GUIDE 上下文",
	},
	{
		"needle": "Input.is_key_pressed",
		"reason": "输入必须经 GUIDE 上下文，不得硬编码键名",
	},
	{
		"needle": "Input.is_physical_key_pressed",
		"reason": "输入必须经 GUIDE 上下文，不得硬编码键名",
	},
	{
		"needle": "AudioStreamPlayer.new(",
		"reason": "音频必须经 SoundManager",
	},
	{
		"needle": "TranslationServer.",
		"reason": "翻译必须经 I18NManager",
	},
	{
		"needle": "GUIDEMappingContext.new(",
		"reason": "GUIDE 上下文必须是 res://input/contexts 下的资源（用 InputGuide.context_for 载入），不得在代码里现搭",
		# 唯一例外：包装层只把资源复制成对局独占实例，不定义任何动作/输入。
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
	var offenders: Array[String] = []
	for path in _gd_files(SCRIPT_ROOT):
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			continue
		for rule in _BANNED:
			if path in rule.get("allow", []):
				continue
			var needle: String = rule["needle"]
			if text.contains(needle):
				offenders.append("%s 含「%s」→ %s" % [path, needle, rule["reason"]])
	assert_eq(offenders.size(), 0,
			"检测到绕过插件的写法，规则见 docs/dev-contract.md §4：\n" + "\n".join(offenders))


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
