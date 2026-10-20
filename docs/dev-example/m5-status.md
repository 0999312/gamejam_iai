# M5 状态：UI 去占位、多语言、按键改键、商店目录化

日期：2026-10-20
范围：M4 后的可用性/扩展性准备；不含新玩法与正式美术。

## 已完成

- **通用 UI 去占位**：`localization/zh_CN.json` 中 HUD、菜单、商店、设置、暂停、结算等通用标签不再带 `[占位]`；剧情/教程/心得/商店条目名与描述仍保留 `[占位]`，由人类撰写。
- **多语言**：新增 `localization/en.json`（122 个展平键，与中文键完全对齐）；`GameBootstrap` 启动加载中英两套，按 `MetaSave.settings.language` 选择；设置页可切换语言并即时重载。
- **按键改键**：新增 `scripts/core/key_bindings.gd`；默认 P1 J/K、P2 小键盘 1/2（或 I/O）、R 重开、Esc 暂停；设置页可逐项改键、检测冲突、恢复默认；绑定写入 `MetaSave.settings.keys`，对决控制器按存档构建 GUIDE 动作。
- **全手柄 UI**：新增 `scripts/ui/ui_focus.gd`；`GameBootstrap` 启动时给内置 `ui_accept`/`ui_cancel` 追加手柄 A/B，方向键/左摇杆使用内置 UI 映射；菜单、商店、设置、暂停、奖励三选一都有初始焦点与金色焦点环；设置页等待改键时按 Back 取消。Esc/Start 仍可暂停。
- **手柄**：新增 `scripts/core/input_devices.gd`；P1 键盘/鼠标 + 手柄 1 的 A/B，P2 键盘 + 手柄 2 的 A/B（检测到第二手柄时）；同一动作可同时挂键盘、鼠标、手柄多条 GUIDE 映射；设置页显示已连接手柄数与 P2 输入来源。
- **手柄改键**：设置页每个动作增加手柄列，可逐项改绑；`MetaSave.settings.joy_buttons` 持久化；同一手柄作用域内冲突拒绝（P1 动作互斥、P2 动作互斥、暂停/重开为全局键），P1 与 P2 可共用 A/B。
- **手柄热插拔**：`DuelController` 监听 `Input.joy_connection_changed`，重连/断开时重建 GUIDE 上下文并按新设备数重新分配 P1/P2；对局状态不重置。设置页同时刷新手柄数与 P2 来源。
- **HUD 操作提示**：按当前绑定动态生成，不再固定显示 J/K/R。
- **商店完全数据驱动**：`res://resources/unlocks/*.tres` 为唯一数据源，`GameBootstrap` 扫描后注册到 MSF `"unlock"` 注册表；`Unlocks.catalog()` 只读注册表，新增条目只需新增 `.tres`，不改代码/UI。
- **测试**：119/119 GUT 通过（22 个脚本，368 asserts）；菜单、商店、设置、对决 headless 均 exit 0；中英键用脚本校验完全对齐（122/122）；`test_ui_gamepad.gd` 覆盖 UI 手柄事件、菜单方向键移动焦点、商店/设置/暂停初始焦点，`test_duel_gamepad.gd` 覆盖 GUIDE 映射、原始事件兜底与玩家隔离。

## 文件

- `scripts/core/key_bindings.gd`
- `scripts/core/input_devices.gd`
- `scripts/core/unlock_item.gd`
- `scripts/core/unlocks.gd`（重构为注册表读取）
- `scripts/core/meta_save.gd`（`language`、`keys` 默认值）
- `scripts/core/game_bootstrap.gd`（双语加载、语言切换、扫描 `resources/unlocks`）
- `resources/unlocks/*.tres`（4 个商店条目，唯一数据源）
- `scripts/ui/settings.gd`（语言选择、改键、手柄状态、手柄改键）
- `scripts/ui/shop.gd`（注册表目录驱动、分组）
- `scripts/ui/ui_focus.gd`（焦点环与初始焦点）
- `scripts/duel/duel_controller.gd`（按绑定建输入；键鼠+手柄并存；全手柄 UI 动作）
- `scripts/duel/duel_hud.gd`（动态操作提示）
- `localization/zh_CN.json`、`localization/en.json`
- `tests/unit/test_key_bindings.gd`、`test_i18n.gd`、`test_shop_catalog.gd`、`test_input_devices.gd`、`tests/integration/test_settings.gd`、`test_duel_gamepad.gd`、`test_ui_gamepad.gd`

## 验证

```powershell
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

结果：119/119 passed（22 脚本，368 asserts）。

### 手柄输入兜底（2026-10-20 修复）

- 根因候选：GUIDE 的 `joy_index -> device_id` 表在 autoload 初始化帧可能为空；已连接手柄不会再触发 `joy_connection_changed`，导致 `joy_index=0` 永远找不到设备。
- 修复：`GameBootstrap` 在下一帧再刷新 GUIDE 手柄表；`DuelController` 不依赖启动枚举，始终给 P1 建“第一个手柄”、双人给 P2 建“第二个手柄”映射；`DuelController._input` 增加按 `event.device` 的原始手柄兜底（P1/P2 按设备隔离），GUIDE 正常时两条路径只置位队列，不会重复出招。
- UI：`ui_accept`/`ui_cancel` 及 `ui_up/down/left/right` 追加 `device=-1` 的手柄事件，任意手柄都能操作界面；暂停键有 200ms 去抖，避免 GUIDE 与原始事件同时触发。
- 验证：新增 `test_duel_context_always_contains_p1_joy_mapping`、`test_raw_joy_fallback_sets_p1_queue`、`test_raw_joy_fallback_keeps_players_separate`；UI 测试用 `device=1` 验证确认/方向键，GUT 119/119。真实手柄仍需人类实机复测。

## 导出（2026-10-20）

- 预设：`export_presets.cfg`「Windows Desktop」，`binary_format/embed_pck=true`，单文件 EXE。
- 命令：

```powershell
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . --export-release "Windows Desktop" build/windows/iai.exe
```

- 产物：`build/windows/iai.exe`（123,619,784 B，2026-10-20 14:05）。
- 验证：`iai.exe --headless --quit-after 60` 退出码 0；日志 `Language [zh_CN]/[en] loaded successfully with 122 entries`。
- 说明：导出日志仍有两条重复字体 UID 警告（`assets/MiSans-Semibold.*` 与 `assets/fonts/MiSans-Semibold.*` 重复），不影响运行；`.cs` 已从导出排除，避免 mono 模板要求 `.sln` 的报错。`build/` 不入库。

### GitHub Release 版本（2026-10-20）

- `.github/workflows/build.yml` 在 push `main` 或手动触发时导出 Windows EXE，并创建 GitHub Release。
- 构建号格式 `YYYY-MM-DD-NN`（UTC 日期，NN 从 01 起；按当天已有 tag 递增）；tag、Release 标题与附件均使用该构建号。
- 语义化版本默认 `0.0.0`：`project.godot` 的 `config/version`、`export_presets.cfg` 的 `file_version/product_version`、Release notes 的 `Semantic version` 行三处一致。
- 导出产物只作为 Release 附件/Artifact，不提交到仓库。

## 限制 / 待人类

- `en.json` 的通用 UI 为功能性英文标签；剧情、教程、心得、商店条目描述为 `[PLACEHOLDER]`，需人类翻译/改写。
- 通用中文 UI 标签由 AI 起草、按人类指示去占位；若主办方严格按「UI 文字也必须人类撰写」审核，需人类再过一遍。
- 未做分辨率设置（按人类指示）；未做键位预设/多套方案。热插拔重建由单元/集成测试覆盖（直接调用回调），真实手柄插拔仍需人类试玩确认。
- 全手柄 UI 由 `Input.parse_input_event` 的单元/集成测试覆盖（方向键焦点、初始焦点、A/B 映射）；真实手柄的方向键/摇杆手感与长按重复仍需人类实机确认。手柄原始事件兜底按 `event.device` 分发，已覆盖“GUIDE 枚举为空”的情况，但真实设备枚举失败仍需人类复测。
- GitHub Actions/Release 尚未在远端实际跑通；首次 push 后需观察 `build-windows` 运行结果。
- 商店条目新增只需在 `resources/unlocks/` 放一个 `.tres`；名称/描述仍在 I18N 的 `shop.item.<id>.name/desc`。
