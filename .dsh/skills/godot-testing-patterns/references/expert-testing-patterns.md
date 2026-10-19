# Expert testing patterns (GUT 9.6)

本工程测试框架**固定为 GUT**（`res://addons/gut/`，版本 9.6.0）。
上游这篇参考原本是 GdUnit4 版，现已改写为 GUT；不要对照 GdUnit4 文档写断言。

## 分层（从便宜到昂贵）

| 层 | 测什么 | 代价 | 何时用 |
| :--- | :--- | :--- | :--- |
| 单元 | 纯函数、数据类、状态机转移表 | 毫秒级 | 默认起点 |
| 场景 | 单个 `.tscn` 进树后的行为、信号、生命周期 | 十毫秒级 | 节点交互、`_ready` 顺序、`%UniqueName` 接线 |
| 集成 | 两个以上系统串起来（判定 → 伤害 → UI） | 百毫秒级 | 只在单元 + 场景覆盖不到缝时 |
| 人工冒烟 | 手感、可读性、帧同步观感 | 分钟级 | 提交前，见 manual-testing-checklist.md |

**不要**用集成测试替代单元测试；先在单元层把规则钉死，再往上加。

## 双倍（doubles）

- `double(inst)` 生成完整替身（方法默认返回 null/0）；`partial_double(inst)` 保留真实实现，只覆盖指定方法。
- 引擎单例不能直接 `double(Engine)`，用 `double_singleton` / 静态替身；本工程更推荐**把单例调用收进自己的适配类**再替身适配类。
- `stub(dbl, "method").to_return(value)` 设定返回值；`stub(dbl, "method").when_passed(3).to_return(9)` 按参数返回。
- 交互断言：`assert_called(dbl, "method", [args])`、`assert_called_count(dbl.method.bind(args), 2)`。
- 只对**跨边界依赖**（时间、随机、存档、音频、外部输入）做替身；对纯内部逻辑做替身说明设计有问题。

## 信号

- 断言前必须 `watch_signals(obj)`；否则 `assert_signal_emitted` 之类的断言会失败。
- 常用：`assert_signal_emitted`、`assert_signal_not_emitted`、`assert_signal_emit_count`、`assert_signal_emitted_with_parameters(obj, "sig", [args])`。
- 取历史参数用 `get_signal_parameters(obj, "sig", 0)`（下标从 0 开始，返回 Array）。
- 不要断言“信号连接顺序”，只断言“发了几次、带了什么”。

## 帧与物理

- 渲染帧用 `await wait_frames(n)`，物理帧用 `await wait_physics_frames(n)`；默认 60 Hz 下 1 物理帧 ≈ 16.67 ms。
- 判定窗口（出刀激活帧、无敌帧、受击硬直）用**帧计数**断言，不要用毫秒估算：`Engine.get_physics_frames()` 前后取差。
- 物理生效需要至少 1 个物理帧：`add_child` 之后 `await wait_physics_frames(1)` 再查重叠/射线。
- 需要确定性的手感逻辑（居合窗口、双方同时命中）优先把规则放进纯数据/纯函数层，测试不必依赖物理。

## 输入（GUIDE + GutInputFactory）

本工程输入走 GUIDE 上下文系统，测试里：

1. 用 `GutInputFactory.action_down("attack")` / `action_up("attack")` 构造 `InputEventAction`；
2. `Input.parse_input_event(ev)` 后 `await wait_frames(1)`，让 GUIDE 在该帧轮询到；
3. 断言 GUIDE 的动作状态或角色状态机的转移，而不是断言引擎原始 `Input` 状态。

> 注意：GUIDE 的映射上下文必须在测试场景里被激活（把对应的 `GUIDEMappingContext` 挂到测试节点树内），否则动作名解析不到。
> 直接构造 `InputEventKey` 只适合测“键位绑定表”本身，不适合测玩法输入。

## 金色文件（存档 / UI 回归）

- 目录：`res://tests/goldens/`；JSON 用 `JSON.stringify(value, "\t")` 保证 diff 可读。
- 首次运行生成参考并 `pass_test()`；之后严格 `assert_eq`；有意变更时重新生成 + 人工 review + 提交新文件。
- 二进制（PNG）只做整文件比较，**绝不手改字节**；需要重生成就删掉旧文件重跑。

## Headless / CI

- `-gexit` 必带，退出码即结论（0 全过 / 1 有失败）；不要解析日志文本。
- `--headless` 下 `get_viewport().get_texture()` 之类的渲染结果不可靠；视觉断言放本地跑，CI 只跑逻辑与场景层。
- 无显示器时 `RenderingServer` 仍在，但 3D/GPU 相关只做“不崩”的冒烟断言。

## 性能

- 用 `Time.get_ticks_usec()` 做区间计时，用 `Performance.get_monitor(Performance.TIME_PROCESS)` 取引擎帧时间。
- 设**宽松**预算（例如 60 FPS 的 50%），并为首次运行保留预热帧；过紧的预算会变成 flaky 测试。
- 基准测试不阻塞 CI：结果超预算先告警（`pending`/日志），稳定后再升级为断言。

## 常见反模式

- 测试里 `OS.delay_msec(200)` 等真实时间 → CI 卡顿且 flaky。
- 一个测试断言五件事，失败时无法定位。
- `before_each` 里创建节点但不 `autofree` / `add_child_autofree` → 孤儿节点，`assert_no_new_orphans` 会报。
- 依赖测试执行顺序或共享 fixture 状态。
- 为了可测把生产代码改出 `if is_test` 分支——应改为依赖注入。
