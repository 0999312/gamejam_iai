# GUT 9.6 速查

## 骨架

```gdscript
extends GutTest

func before_all() -> void: pass      # 整套件一次
func before_each() -> void: pass     # 每个测试前
func after_each() -> void: pass
func after_all() -> void: pass

func test_something() -> void:
	assert_eq(1 + 1, 2)
```

测试方法名必须以 `test_` 开头才会被收集；辅助方法随意命名。

## 断言

| 断言 | 说明 |
| :--- | :--- |
| `assert_eq(got, expected, text="")` | 相等（值比较） |
| `assert_eq_deep(v1, v2)` | 数组/字典深比较 |
| `assert_true(v)` / `assert_false(v)` | 布尔 |
| `assert_null(v)` / `assert_not_null(v)` | 空值 |
| `assert_almost_eq(got, expected, interval)` | 浮点容差 |
| `assert_gt(a, b)` / `assert_lt(a, b)` / `assert_between(v, lo, hi)` | 数值区间 |
| `assert_has(container, item, text="")` | 数组/字典包含 |
| `assert_string_contains(text, sub)` | 字符串包含 |
| `assert_freed(obj)` / `assert_not_freed(obj)` | 对象是否已释放 |
| `assert_no_new_orphans(text="")` | 本测试未泄漏节点 |
| `pass_test(text)` / `fail_test(text)` / `pending(text)` | 手动结论 |

## 信号

```gdscript
watch_signals(target)
target.take_damage(3)
assert_signal_emitted(target, "damaged")
assert_signal_emit_count(target, "damaged", 1)
assert_signal_emitted_with_parameters(target, "damaged", [3, 7])
var params: Array = get_signal_parameters(target, "damaged", 0)
```

## 双倍

```gdscript
var dbl = double(SomeDep.new())
stub(dbl, "value").to_return(42)
stub(dbl, "value").when_passed(1).to_return(10)
assert_eq(dbl.value(1), 10)
assert_called(dbl, "value", [1])
assert_called_count(dbl.value, 1)
```

## 异步

```gdscript
await wait_frames(2)
await wait_physics_frames(3)
await wait_seconds(0.25)
var ok: bool = await wait_for_signal(node.some_signal, 1.0)
```

## 节点管理

```gdscript
var n := Node2D.new()
add_child_autofree(n)   # 进树 + 测试结束自动释放
var m := autofree(Node.new())   # 不进树，只登记释放
autoqfree(obj)          # queue_free 版
```

## 命令行

```powershell
# 全部
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
# 单文件
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_x.gd -gexit
# 按名字筛选
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gselect=damage -gexit
# 日志更详细
... -glog=2
# JUnit 报告
... -gjunit_xml_file=res://test-results.xml
```

常用参数：`-gdir`、`-ginclude_subdirs`、`-gtest`、`-gprefix`、`-gsuffix`、`-gselect`、`-gunit_test_name`、`-gexit`、`-gexit_on_success`、`-glog=0..3`、`-gignore_pause`、`-ghide_orphans`。
默认前缀 `test_`、后缀 `.gd`；配置文件 `.gutconfig.json` 存在时会被自动读取（用 `-gconfig=` 关闭）。
