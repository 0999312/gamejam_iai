# godot_dsh_test — 开发说明

> 本文件是**工程开发说明**，供内部开发与外部协作者了解结构、运行、测试和构建；**不是** GameJam 提交用的作品 README。
> 提交用 README 必须由人类按 `docs/gamejam/submission-checklist.md` §4 撰写，不得由 AI 代写。
> 当前所有玩家可见文案仍有 44 处 `[占位]`（作品名、角色名、心得名/描述、教程与台词等），不能作为正式文案发布。

## 当前状态

- 引擎：Godot **4.7.2 stable mono**（GDScript 为主，未使用 C# 脚本）。
- 版本：**`0.1.0`**（首个「操作与难度经人工简测通过」的里程碑；`project.godot` 的 `config/version` 与此一致，游戏内「关于」页显示同一版本号）。此前文档里的 `v0.20`–`v0.29` 是开发期迭代号，不再使用。
- 内容：局内 5 场阶梯、3 位角色、10 个心得、4 张符卡、商店/解锁、设置、暂停、本地双人、键鼠 + 手柄、中英双语；主菜单为二级结构（单人阶梯 / 本地双人收在「开始游戏」下），设置页含「关于本作」与「清除存档」。
- 测试：**195/195 GUT**（27 个脚本、746 asserts，退出码 0）。
- 构建：Windows 单文件 EXE 已导出；GitHub Actions `build-windows` 已跑通。
- 设计文档：`docs/dev-example/design.md`；阶段状态：`docs/dev-example/m1-status.md` … `m5-status.md`；变更总览：`CHANGELOG.md`。
- 合规：AI 只写代码；美术、音乐、音效、文案由人类提供或使用 CC0 素材，详见 `docs/gamejam/ai-disclosure.md`。

## 环境

| 项 | 值 |
|---|---|
| Godot | `E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe`（目录名为旧版遗留，实际为 4.7.2 mono） |
| 主场景 | `res://scenes/menu/menu.tscn` |
| 分辨率 | 1280×720，`canvas_items` 拉伸 |
| 测试框架 | GUT 9.6（`addons/gut`） |
| 字体 | `assets/fonts/MiSans-Semibold.otf` |
| 主题 | `assets/theme/minimal_vector.tres` |

不要求安装 .NET SDK；本工程没有 C# 脚本。打开工程后由 Godot 完成导入即可。

## 快速开始

```powershell
# 首次导入资源（新增 class_name 后也必须先跑一次，否则 GUT 可能识别不到脚本）
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . --import

# 运行游戏（主菜单）
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --path .

# 全量测试
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# 单场景冒烟
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . res://scenes/duel/duel.tscn --quit-after 120
```

## 操作

| 操作 | P1 | P2 | 手柄 |
|---|---|---|---|
| 斩 | `J` | 小键盘 `1` / `I` | A |
| 架 | `K` | 小键盘 `2` / `O` | B |
| 暂停 | `Esc` | `Esc` | Start |
| 重开（失败/通关后） | `R` | `R` | Back |
| 选心得 | 鼠标点击 / `1` `2` `3` | 同左 | 方向键 + A |

- 键位与手柄键均可在「设置 → 按键与手柄」中修改；键盘、鼠标、手柄可同时映射同一动作。
- P1 使用第一个手柄，P2 使用第二个手柄；未检测到第二手柄时 P2 只使用键盘。
- 手柄热插拔会重建 GUIDE 上下文，不需要重启游戏。

## 目录

```
scenes/
  menu/            主菜单
  duel/            对决场景、灰盒视图、HUD
  ui/              商店、设置、暂停、关于、模式选择
scripts/
  core/            GameBootstrap、MetaSave、解锁、按键、手柄设备、面板 ID
  duel/            DuelSim / FighterState / FighterData、AI、输入控制器、视图、HUD、音频
  run/             RunState、UpgradeData
  ui/              菜单、商店、设置、暂停、关于、模式选择、焦点环
  audio/           DuelAudio
input/             GUIDE 动作与上下文资源（actions/*.tres、contexts/*.tres）
resources/unlocks/ 商店条目（数据驱动，唯一数据源）
localization/      zh_CN.json、en.json
tests/             unit / integration（GUT）
tools/             一次性脚本（GUIDE 上下文生成、平衡模拟器、逐帧追踪）
docs/              设计、阶段状态、审计报告、GameJam 合规与占位清单
assets/            字体、主题、图标、CC0 音效
build/             本地导出产物与临时日志（gitignore，不入库）
CHANGELOG.md       已交付变更的逐批记录（问题 → 修法 → 验证）
```

## 架构要点

- **规则与表现分离**：`DuelSim` 是纯 `RefCounted` 逻辑，按 60Hz 整数帧推进，不依赖场景；`DuelController` 读输入并驱动 `DuelSim`/`DuelAi`；`DuelView`/`DuelHud` 只订阅信号做表现。因此判定矩阵可在 GUT 中无场景测试。
- **局内流程**：`RunState` 管理 5 场阶梯、HP、金币、残心、心得三选一、失败/通关；每场由 `DuelController._start_stage()` 创建新的 `DuelSim`。
- **数据驱动商店**：`resources/unlocks/*.tres`（`UnlockItem`）由 `GameBootstrap._register_unlocks()` 扫描并注册到 MSF 的 `"unlock"` 注册表；`Unlocks` 只读注册表，新增条目不需要改 UI 或硬编码列表。
- **心得**：`GameBootstrap.UPGRADE_DEFS` 注册 u01–u10 到 MSF `"upgrade"` 注册表；`RunState` 按 `UpgradeData.effect/amount` 解释效果，文案走 I18N。
- **输入**：GUIDE 负责映射上下文；`KeyBindings` 管理键盘/手柄绑定与冲突；`InputDevices` 返回 GUIDE 的连接序号（0/1，不是 Godot device id）；控制器为每个动作追加键盘、鼠标、手柄多条映射。
- **文案**：MSF `I18NManager` + `localization/*.json`；新增语言只需在 `GameBootstrap.I18N_FILES` 注册并补 JSON。
- **存档**：`MetaSave` 写 `user://meta_save.json`。写入是三步原子写（`.tmp` → 旧档转 `.bak` → 转正，任一步失败回滚），坏档（空文本 / JSON 解析失败 / 结构不对）会被**隔离为 `.corrupt` 而不是被默认值覆盖**；文件里带 `version` 字段（当前 `1`），读取时按来源版本走迁移补缺键。设置页的「清除存档」需要二次确认，会一并删掉 `.tmp`/`.bak`/`.corrupt`。
- **音频**：`SoundManager` autoload + `DuelAudio` 订阅判定信号；音频总线 `SFX`/`UI`/`Ambient`/`Music` 由 `GameBootstrap` 创建并应用设置。

## 扩展点

| 要加什么 | 改哪里 |
|---|---|
| 新角色 | `scripts/duel/fighter_data.gd` 增加 `player_d()` 一类的静态工厂与 `for_character()` 分支；菜单角色列表来自 `Unlocks.character_ids()` |
| 新对手/难度 | `FighterData.opponent_for_stage()`、`AiProfile.for_stage()`；AI 参数在 `ai_profile.gd` |
| 新心得 | `GameBootstrap.UPGRADE_DEFS` + `RunState` 的 effect 解释 + 中英 JSON |
| 新商店条目 | 在 `resources/unlocks/` 放一个 `UnlockItem` `.tres`，补 `shop.item.<id>.name/desc` |
| 新语言 | `GameBootstrap.I18N_FILES` + `localization/<lang>.json`（键与 zh_CN 对齐） |
| 新音效 | 放进 `assets/audio/sfx|amb/`，在 `DuelAudio` 预加载/映射；来源登记到 `assets/audio/CREDITS.md` |
| 新按键/手柄键 | `KeyBindings.DEFAULT_KEYS` / `DEFAULT_JOY_BUTTONS`，并补设置页行 |

## 测试约定

- 只用 GUT：`extends GutTest`，`res://tests/unit|integration|fixtures`。
- 异步用 `await wait_process_frames(n)` / `wait_physics_frames(n)`，不用 `OS.delay_*`。
- 新增 `class_name` 后先 `--import` 再跑 GUT，否则会出现 “does not extend GutTest” 的误报。
- 输入相关测试用 `GUIDE.inject_input` + `await wait_process_frames(2)` + `wait_physics_frames(2)`；或 `GutInputFactory`。
- 随机只经 `RandomNumberGenerator` 并固定 seed。

## 构建与发布

```powershell
# 本地导出（需要已安装 4.7.2 mono 导出模板）
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . --export-release "Windows Desktop" build/windows/iai.exe
```

- 导出预设：`export_presets.cfg`「Windows Desktop」，`binary_format/embed_pck=true`，单文件 EXE。
- `build/` 被 `.gitignore` 忽略；EXE 只作为 GitHub Release 附件 / Actions Artifact，不入库。
- CI：`.github/workflows/build.yml`，push `main` 或手动触发；构建号 `YYYY-MM-DD-NN`（UTC，01 起），语义化版本取 `project.godot` 的 `config/version`（当前 `0.1.0`）；tag/Release 自动创建。
- 已跑通：Release `2026-10-20-02`（EXE 118 MB，sha256 `db6fff55990cb30744f3a25d5f37bfc8dc1edf53455968f3b16a93f1a067397f`）。首次空 Release `2026-10-20-01` 保留未删。该 Release 的附件早于 `0.1.0`，重新导出后需另行核对大小与 sha256。
- 注意：之后每次 push `main` 都会触发一次构建/Release；纯文档提交可在提交信息加 `[skip ci]`。

## 已知限制 / 待人类

- 真实手柄的方向键/摇杆手感、热插拔与改键需人类实机复测；当前以模拟手柄事件测试。
- 未在非开发机/不同分辨率上验证；`submission-checklist` 相应项仍未勾。全部 UI 尺寸按 1280×720 逻辑坐标写死（`canvas_items` 拉伸在默认 aspect 下可用，非标准宽高比会留边/裁切）。
- 玩家可见文案仍有 44 处占位（作品名、角色名、心得名/描述、教程、台词等）；正式美术/封面未提供。
- 7 个 `.tscn` 目前是「只有根节点 + 脚本」的空壳，节点树在 `_ready()` / `_build_ui()` 里建；`%UniqueName` 全项目未使用。功能正常，但不满足 `AGENTS.md` §8「复杂 UI 独立子场景」的实质要求。
- 战斗音效来自 Kenney CC0，风声来自 OpenGameArt CC0；未做人耳试听与音量终混，缺呼吸/心跳/收刀/室内底噪。
- 背景音乐未做；本地双人为镜像同角色，无角色选择。
- 字体 UID 导出警告为重复资源（`assets/MiSans-Semibold.*` 与 `assets/fonts/` 下同名同尺寸两份，合计约 29 MB），不影响运行，待清理。
- `DuelView` 与 `DuelAudio` 没有直接测试（只被集成测试间接覆盖）。

## 合规与来源

- AI 使用边界、披露记录：`docs/gamejam/ai-disclosure.md`（只写代码；不生成美术/音乐/音效/文案）。
- 占位登记：`docs/gamejam/submission-checklist.md` §7（`PH-01` … `PH-18`）。
- 音频来源与许可：`assets/audio/CREDITS.md`、`docs/audio-assets-plan.md`。
- 东方 Project 二创声明：游戏内「关于」页已写明「本作是东方 Project 二次创作，版权归上海爱丽丝幻乐团及 ZUN 所有」与「与官方无任何关联、未使用原作游戏素材」；提交用 README 仍须由人类按 `docs/gamejam/submission-checklist.md` §4 撰写并同样注明。详见 `docs/gamejam/README.md` 与 `docs/gamejam/constraints.md`。
- 提交清单：`docs/gamejam/submission-checklist.md`；活动硬约束：`docs/gamejam/constraints.md`。

## 相关文档

- [设计文档](docs/dev-example/design.md)
- [M5 状态](docs/dev-example/m5-status.md)
- [GameJam 说明](docs/gamejam/README.md)
- [提交清单](docs/gamejam/submission-checklist.md)
- [AI 披露](docs/gamejam/ai-disclosure.md)
- [音频计划](docs/audio-assets-plan.md)
