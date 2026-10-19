---
name: godot-testing-patterns
description: "GUT (Godot Unit Test) testing decision tree for this project: unit vs scene vs CI gates, headless runners, goldens, doubles and signal spies. Use when choosing a test layer, wiring headless CI, or validating signals, physics timing or input. Keywords: GUT, GutTest, gut_cmdln, assert_eq, watch_signals, double, stub, headless CI, golden snapshot, scene integration test, TDD."
---

# GUT 测试技能（本项目唯一测试框架）

> **硬性约定**：本项目测试只用 **GUT 9.6.0**（`res://addons/gut/`，已在 `project.godot` 启用）。
> **禁止**引入 GdUnit4、禁止在同一套件里混用两套断言 API、禁止为测试引入新插件。
> 本技能是上游 `godot-testing-patterns`（原 GdUnit4 版）的 **GUT 改写版**，改写记录见仓库 `.dsh/skills/ATTRIBUTION.md`。

## 决策树 → 脚本

| 需求 | 选择 | 脚本（选定即**必须**先读） |
| :--- | :--- | :--- |
| 纯逻辑 / 不碰场景树 | 单元 | [basic_unit_test.gd](scripts/basic_unit_test.gd)、[mock_dependency_test.gd](scripts/mock_dependency_test.gd)、[test_data_factory.gd](scripts/test_data_factory.gd) |
| 实例化后测节点交互 | 场景集成 | [scene_integration_test.gd](scripts/scene_integration_test.gd)、[integration_test_base.gd](scripts/integration_test_base.gd) |
| 信号契约（发没发、带什么参数） | 单元或场景 | [signal_emission_test.gd](scripts/signal_emission_test.gd) |
| 多帧 / 物理步进 | 异步场景 | [wait_for_frame_test.gd](scripts/wait_for_frame_test.gd)、[physics_collision_test.gd](scripts/physics_collision_test.gd) |
| 物理抖动 / 时序竞态 | 帧步进门控 | **必须** [wait_for_frame_test.gd](scripts/wait_for_frame_test.gd) — 用 `wait_frames` / `wait_physics_frames`，绝不用 `OS.delay_msec` / 墙钟 sleep |
| CI / 无显示器 | Headless 门控 | **必须** [headless_test_runner.gd](scripts/headless_test_runner.gd)、[run_tests.ps1](scripts/run_tests.ps1) |
| 存档 / UI 回归 | 金色快照 | **必须** [snapshot_tester.gd](scripts/snapshot_tester.gd) |
| 无真实对端测 RPC | 离线对端 | **必须** [mock_network_provider.gd](scripts/mock_network_provider.gd) |
| CI 里的性能预算 | 基准门控 | [performance_benchmark_runner.gd](scripts/performance_benchmark_runner.gd) |
| 套件结束后查泄漏 | 孤儿检测 | [memory_leak_detector.gd](scripts/memory_leak_detector.gd) |
| 输入空间边缘值 | 模糊测试 | [parameter_fuzz_tester.gd](scripts/parameter_fuzz_tester.gd) |

**不要**把断言大全、入门教程整篇读进上下文——选一行、读脚本、照着写。

## 目录与命名（本工程）

```
res://tests/
├── unit/            # 纯逻辑，test_*.gd
├── integration/     # 场景集成，test_*.gd
├── fixtures/        # 测试替身、数据工厂（非 test_ 前缀，不会被收集）
└── goldens/         # JSON / PNG 金色文件
```

- 文件名必须 `test_` 前缀、`.gd` 后缀（GUT 默认 `-gprefix=test_`、`-gsuffix=.gd`）；GUT 只收集 `test_*` 脚本，fixture 不会被误跑。
- 每个测试方法名也以 `test_` 开头；一个方法只验证一个行为。
- 生产代码放 `scripts/` / `scenes/`，测试代码只在 `tests/` 内。

## 运行

```powershell
# 编辑器内：GUT 面板 → Run All / Run Selected（开发时首选）
# 全部测试（headless，CI 用）
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
# 只跑某个文件 / 某个名字
... -gtest=res://tests/unit/test_damage.gd -gexit
... -gdir=res://tests -gselect=damage -gexit
... -gdir=res://tests -gunit_test_name=parry -gexit
```

- `-gexit`：跑完退出并设置 `OS.exit_code`（0 全过 / 1 有失败）。**CI 必须带 `-gexit`**，否则进程不退出。
- 失败排查加 `-glog=2`；`-ghide_orphans` 控制孤儿节点输出；导出 JUnit 用 `-gjunit_xml_file=res://test-results.xml`。
- 优先用仓库脚本 [run_tests.ps1](scripts/run_tests.ps1)，避免参数写错。
- **本项目 DSH 沙箱**：`godot.exe` 在默认沙箱下不可执行（`Access is denied`），需带 `sandbox_permissions` 审批；无审批时测试须由人在本机跑。

## 生命周期（GUT 9.6）

`before_all()` → 每个测试 `before_each()` → `test_*()` → `after_each()` → `after_all()`。

- 每个测试都从**干净状态**开始：在 `before_each()` 里 new 被测对象，在 `after_each()` 里 `autofree()` 或 `add_child_autofree()` 交给 GUT 回收。
- 异步测试直接写 `await`：`await wait_frames(2)`、`await wait_physics_frames(30)`、`await wait_seconds(0.1)`、`await wait_for_signal(obj.signal_name, 1.0)`。
- `pause_before_teardown()` 只在**本地交互调试**时用；CI 带 `-gignore_pause`。

## 必须触发的场景

- **CI / `--headless`**：先读 [headless_test_runner.gd](scripts/headless_test_runner.gd)，用 `-gexit` + 退出码判定，不要靠解析文本。
- **金色文件（存档/UI 回归）**：先读 [snapshot_tester.gd](scripts/snapshot_tester.gd)。**审批流程**：首次运行生成参考文件 → 有意改动后重新生成并人工 diff → 提交新金色文件；**绝不用手改 PNG/JSON 字节**。
- **任何 RPC / `MultiplayerSynchronizer` 测试**：先读 [mock_network_provider.gd](scripts/mock_network_provider.gd)，不要拉起真实 ENet 对端。
- **任何与 GUIDE 输入相关的测试**：用 `GutInputFactory` 构造事件 + 检查 `GUIDEAction` 状态，不要直接 `Input.parse_input_event` 绕过输入上下文（见 [expert-testing-patterns.md](references/expert-testing-patterns.md)）。
- **物理/判定帧相关**（居合的判定窗口、受击框激活帧）：必须用 `wait_physics_frames` 推进，断言帧号或帧区间，不要用毫秒估算。

## 可用脚本

| 脚本 | 用途 |
| :--- | :--- |
| [basic_unit_test.gd](scripts/basic_unit_test.gd) | 最小 `extends GutTest` 单元测试骨架 |
| [signal_emission_test.gd](scripts/signal_emission_test.gd) | `watch_signals` + 发射次数/参数断言 |
| [mock_dependency_test.gd](scripts/mock_dependency_test.gd) | `double()` / `stub()` / `assert_called` |
| [scene_integration_test.gd](scripts/scene_integration_test.gd) | 场景实例化、进树、跨帧断言 |
| [integration_test_base.gd](scripts/integration_test_base.gd) | 场景测试基类与挂载辅助方法 |
| [wait_for_frame_test.gd](scripts/wait_for_frame_test.gd) | 帧/物理帧步进与时序断言 |
| [physics_collision_test.gd](scripts/physics_collision_test.gd) | 碰撞、Area 重叠、射线查询 |
| [headless_test_runner.gd](scripts/headless_test_runner.gd) | CI 门控说明与退出码契约 |
| [run_tests.ps1](scripts/run_tests.ps1) | 可直接运行的 headless 测试脚本 |
| [snapshot_tester.gd](scripts/snapshot_tester.gd) | JSON 金色快照比对与更新流程 |
| [mock_network_provider.gd](scripts/mock_network_provider.gd) | 离线 multiplayer 对端 |
| [performance_benchmark_runner.gd](scripts/performance_benchmark_runner.gd) | 微秒计时 + Performance 监视器门控 |
| [memory_leak_detector.gd](scripts/memory_leak_detector.gd) | `assert_no_new_orphans()` 与孤儿监视 |
| [parameter_fuzz_tester.gd](scripts/parameter_fuzz_tester.gd) | 带种子的随机输入空间测试 |
| [test_data_factory.gd](scripts/test_data_factory.gd) | 可复用的 fixture 构造器 |

## NEVER（GUT 版）

- **NEVER** 混用 GUT 与 GdUnit4 的 API；本项目只有 GUT。
- **NEVER** 测试私有实现细节；只断言公开行为（输入 → 状态变化 → 信号/输出）。
- **NEVER** 在测试间共享可变状态；每个测试在 `before_each()` 重新构造。
- **NEVER** 用墙钟 `sleep` / `OS.delay_msec` 等帧；用 `wait_frames` / `wait_physics_frames`。
- **NEVER** 忘记回收节点；用 `autofree()` / `autoqfree()` / `add_child_autofree()`，并在 `after_all()` 里 `assert_no_new_orphans()`。
- **NEVER** 不设种子地测随机性；用固定 seed 的 `RandomNumberGenerator`。
- **NEVER** 断言信号而不先 `watch_signals(obj)`；否则 GUT 会判失败。
- **NEVER** 让测试依赖编辑器专属功能；CI 只跑 headless 兼容路径。
- **NEVER** 默认写整关集成测试；先单元 + 小场景，只有决策树指向时才升级。
- **NEVER** 在 fixture 里硬编码绝对文件路径；用 `res://` + `ProjectSettings.globalize_path()`。
- **NEVER** 测第三方插件内部（`addons/` 是 MIT/上游代码）；只测本工程对它的集成。
