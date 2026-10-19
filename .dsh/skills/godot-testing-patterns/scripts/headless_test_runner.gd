# Headless CI 门控参考（本文件不是测试用例，GUT 不会收集它）。
#
# 命令（工作目录 = 工程根）：
#   godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
#
# 契约：
#   0 = 全部测试通过
#   1 = 存在失败（含 GUT 内部错误）
#   必须带 -gexit，否则进程跑完不退出，CI 会一直挂到超时。
#
# 注意：
#   - 不要解析 stdout 文本判断成败，日志格式不保证稳定；只看退出码。
#   - 需要报告时加 -gjunit_xml_file=res://test-results.xml。
#   - 失败排查加 -glog=2；CI 里不要用 pause_before_teardown（或加 -gignore_pause）。
#   - 优先调用 scripts/run_tests.ps1，避免参数抄错。
extends RefCounted

const TEST_DIR: String = "res://tests"


static func build_command(godot_exe: String, project_path: String, select_filter: String = "") -> PackedStringArray:
	var args := PackedStringArray([
		"--headless",
		"--path", project_path,
		"-s", "addons/gut/gut_cmdln.gd",
		"-gdir=" + TEST_DIR,
		"-ginclude_subdirs",
		"-gexit",
	])
	if select_filter != "":
		args.append("-gselect=" + select_filter)
	return args


# CI 里失败时应返回非 0；调用方据此决定是否中断流水线。
static func is_success_exit_code(code: int) -> bool:
	return code == 0
