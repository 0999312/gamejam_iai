# 双倍（double / stub）测试：把跨边界依赖替换掉，只验证协作方式。
# 只给「时间、随机、存档、音频、外部服务」这类边界做替身；给内部纯逻辑做替身通常说明设计有问题。
extends GutTest

# 占位依赖；真实项目里换成 preload 你的 autoload 适配类。
class Scoreboard:
	extends RefCounted

	var total: int = 0

	func add(points: int) -> void:
		total += points

	func label() -> String:
		return "score:%d" % total


var dependency: Scoreboard = null
var dbl: Scoreboard = null


func before_each() -> void:
	dependency = autofree(Scoreboard.new())
	# 双倍不是 Scoreboard 的真实实例，保持 Variant 类型即可。
	dbl = double(dependency)


func test_stub_returns_configured_value() -> void:
	stub(dbl, "label").to_return("mocked")

	assert_eq(dbl.label(), "mocked", "stub 之后应返回替身值")
	assert_called(dbl, "label")


func test_stub_can_switch_on_arguments() -> void:
	stub(dbl, "label").when_passed().to_return("empty")

	assert_eq(dbl.label(), "empty", "when_passed() 无参分支")


func test_call_recording_with_arguments() -> void:
	stub(dbl, "add")

	dbl.add(3)
	dbl.add(4)

	assert_called(dbl, "add", [3])
	assert_called_count(dbl.add.bind(4), 1)   # 只统计参数为 4 的调用
	assert_not_called(dbl, "label")


func test_real_dependency_still_works() -> void:
	dependency.add(5)

	assert_eq(dependency.total, 5)
	assert_eq(dependency.label(), "score:5", "替身不应污染真实对象")
