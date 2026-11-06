# 刀剑 · 心流（gamejam_iai）— 开发说明

> 本文件是**工程开发说明**，供内部开发与外部协作者了解结构、运行、测试和构建；**不是** GameJam 提交用的作品 README。
> 提交用 README 必须由人类按 `docs/gamejam/submission-checklist.md` §4 撰写，不得由 AI 代写。
> 当前所有玩家可见文案仍有 44 处 `[占位]`（作品名、角色名、心得名/描述、教程与台词等），不能作为正式文案发布。

## 当前状态

- 引擎：Godot **4.7.2 stable mono**（GDScript 为主，未使用 C# 脚本）。
- 版本：**`0.1.0`**（首个「操作与难度经人工简测通过」的里程碑；`project.godot` 的 `config/version` 与此一致，游戏内「关于」页显示同一版本号）。此前文档里的 `v0.20`–`v0.29` 是开发期迭代号，不再使用。
- 内容：局内 5 场阶梯、3 位角色、10 个心得、4 张符卡、商店/解锁、设置、暂停、本地双人、键鼠 + 手柄、中英双语；主菜单为二级结构（单人阶梯 / 本地双人收在「开始游戏」下），设置页含「关于本作」与「清除存档」；对局与主菜单背景为同一套程序化雨夜 shader，无外部背景贴图；环境音为 CC0 雨声，主题为无边框雨夜主题；斩击刀光已离开刀身并在挥砍中段做切向拉长、径向收薄与轻微剪切；P2 使用独立的蓝色衣装图集（同骨架、同动作，按席位切换）；心流在礼让结束后待机自然恢复（+1/24f），长时间待机不再转为惩罚；防御/蓄力特效为白→金渐变 + 加法发光着色器，看破方多一段冷白预读弧。
- 测试：**311/311 GUT**（37 个脚本、1270 asserts，退出码 0）。
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
| 主题 | `assets/theme/rain_night.tres`（由 `tools/build_rain_night_theme.gd` 生成） |
| 角色动画 | Spine 4.3 运行时（`addons/spine_godot`，GDExtension，只装了 Windows 库） |

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
| 斩 | `J` / 鼠标左键 | 小键盘 `1` / `I` | A |
| 架 | `K` / 鼠标右键 | 小键盘 `2` / `O` | B |
| 符卡 | `L` / 鼠标中键 | 小键盘 `3` / `P` | Y |
| 暂停 | `Esc` | `Esc` | Start |
| 重开（失败/通关后） | `R` | `R` | Back |
| 选心得 | 鼠标点击 / `1` `2` `3` | 同左 | 方向键 + A |

- 键位与手柄键均可在「设置 → 按键与手柄」中修改；单人时键盘、鼠标、手柄可同时映射同一动作。
- 本地双人在角色选择面板各自选角色与输入方式：双方键鼠、一人键鼠一人手柄，或双方手柄（P1 用第一只手柄、P2 用第二只；双方键鼠时鼠标只给 P1）。面板不检测手柄是否已接入。
- 双人开局时若双方都选键鼠，中途插入的手柄默认归 P1（键鼠留给 P2）；已显式选手柄时保留选择，第二只插入后自动补齐 P2，拔掉一只时不会把剩下的手柄错绑给另一席。手柄热插拔会重建 GUIDE 上下文，不需要重启游戏。

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
resources/spine/   Spine 骨架（skeleton.spine-json / skeleton.atlas / skeleton.png）、P2 图集（skeleton_p2.atlas / skeleton_p2.png）、单人前四关敌方配色（skeleton_e1..e4.atlas / .png）与每角色档案 <id>.tres
localization/      zh_CN.json、en.json
tests/             unit / integration（GUT）
tools/             一次性脚本（GUIDE 上下文生成、平衡模拟器、逐帧追踪）
docs/              设计、阶段状态、审计报告、GameJam 合规与占位清单
assets/            字体、主题、图标、CC0 音效、CC0 粒子贴图
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
| 新角色 | `scripts/duel/fighter_data.gd` 增加 `player_d()` 一类的静态工厂与 `for_character()` 分支；角色选择面板列表来自 `Unlocks.character_ids()` |
| 新对手/难度 | `FighterData.opponent_for_stage()`、`AiProfile.for_stage()`；AI 参数在 `ai_profile.gd` |
| 新心得 | `GameBootstrap.UPGRADE_DEFS` + `RunState` 的 effect 解释 + 中英 JSON |
| 新商店条目 | 在 `resources/unlocks/` 放一个 `UnlockItem` `.tres`，补 `shop.item.<id>.name/desc` |
| 新语言 | `GameBootstrap.I18N_FILES` + `localization/<lang>.json`（键与 zh_CN 对齐） |
| 新音效 | 放进 `assets/audio/sfx|amb/`，在 `DuelAudio` 预加载/映射；来源登记到 `assets/audio/CREDITS.md` |
| 新粒子贴图 | 放进 `assets/particles/<用途>/`（`slash`/`impact`/`guard`/`spell`/`dust`/`glow`），同步 `assets/particles/CREDITS.md` 与 `docs/particle-assets-plan.md` 的「事件 → 贴图」表 |
| 改战斗特效 | 命中/对刀/架防的贴图、尺寸、颜色、粒子数在 `scripts/duel/duel_fx.gd` 的 `_spec()` 与 `burst_*()`；挥砍刀光（`pose_slash`，`twirl_03`）与符卡爆环（`burst_spell`，`circle_02` 紫）同文件；触发点在 `scripts/duel/duel_view.gd` 的信号回调与 `_update_slash_fx()`；改完跑 `tools/capture_fx_preview.gd` 出两张图对照 |
| 新按键/手柄键 | `KeyBindings.DEFAULT_KEYS` / `DEFAULT_JOY_BUTTONS`，并补设置页行 |
| 换 Spine 素材/动画 | 骨架 JSON 必须叫 `*.spine-json`（普通 `.json` 不会被导入）并放在 `resources/spine/`；每角色档案 `resources/spine/<角色 id>.tres`（`SpineFighterProfile`）里改 `skeleton_file`/`atlas_file`/`animation_map`/`target_height`/`offset`；改名或换素材后跑一次 `--import`（**改 `.atlas` 也必须重导入**，否则运行时仍读旧 `.spatlas`，region 名对不上会让扩展段错误）。美术导出若带 `images/` 目录前缀，region 名要与 JSON 附件名对齐。**3.8 导出必须先跑 `tools/upgrade_legacy_spine_json.gd`：版本 + 旧 `ik` → `constraints`，并把旧 3.8 贝塞尔曲线重算为 4.3 绝对控制点；只改版本号会丢 IK（四肢不动），不转曲线会在非末帧曲线处 signal 11**。P2 的蓝色衣装不走角色档案：`DuelView.P2_ATLAS_PATH` 固定指向 `resources/spine/skeleton_p2.atlas`，同一角色站 P2 时自动克隆档案换图集；换 2P 贴图只需同步改该 atlas 首行页名与 PNG，不要把 `char_b.tres` 改成 P2 图集（否则它当 P1 时也会变蓝）。细节见 `docs/dev-example/spine-integration.md` §4.3、§6.1 |

## 测试约定

- 只用 GUT：`extends GutTest`，`res://tests/unit|integration|fixtures`。
- 异步用 `await wait_process_frames(n)` / `wait_physics_frames(n)`，不用 `OS.delay_*`。
- 新增 `class_name` 后先 `--import` 再跑 GUT，否则会出现 “does not extend GutTest” 的误报。
- 输入相关测试用 `GUIDE.inject_input` + `await wait_process_frames(2)` + `wait_physics_frames(2)`；或 `GutInputFactory`。
- 随机只经 `RandomNumberGenerator` 并固定 seed。
- Spine 相关断言在 `SpineSprite` 存在时才生效（`SpineFighterView.is_supported()` 为假则 `pending()`）；`SpineSprite` 释放会留下扩展内部的 orphan，全量测试不启 `-gfail_on_orphans`。素材回归必须断言 `get_ik_constraints().size() == 10`，否则 3.8 旧约束会在 4.3 下静默丢失；同时断言五条动画名与时长，防止换素材后映射悄悄回退；P2 图集另有断言（资源路径、贴图页名、P1/P2 不共享图集）。

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
- 对局与主菜单背景共用固定 1280×720 的程序化雨夜 shader（`resources/shaders/rainy_night.gdshader`）：雨线为屏幕空间、无地面溅射/闪电；对局改站位时要同步 `DuelView._apply_background_focus()`，主菜单地平线/湿反光参数在 `menu.gd` 单独复制材质后设置；未做低端机性能剖析。
- 玩家可见文案仍有 44 处占位（作品名、角色名、心得名/描述、教程、台词等）；正式美术/封面未提供。
- 7 个 `.tscn` 目前是「只有根节点 + 脚本」的空壳，节点树在 `_ready()` / `_build_ui()` 里建；`%UniqueName` 全项目未使用。功能正常，但不满足 `AGENTS.md` §8「复杂 UI 独立子场景」的实质要求。
- 战斗音效来自 Kenney CC0；对局环境音为人类提供的 CC0 雨声 WAV（`assets/audio/amb/rain_calm_loop.wav`），旧风声 `amb_wind_loop.ogg` 已退役且无代码引用；未做人耳试听与音量终混，缺呼吸/心跳/收刀/室内底噪。
- 背景音乐未做；本地双人已支持各自选角色与双方键鼠 / 一人键鼠一人手柄 / 双方手柄；双方手柄需接入两只手柄，不足时先回退键鼠并在第二只插入后自动补齐。真实手柄热插拔与双手柄手感待实机复测。
- 字体 UID 导出警告为重复资源（`assets/MiSans-Semibold.*` 与 `assets/fonts/` 下同名同尺寸两份，合计约 29 MB），不影响运行，待清理。
- `DuelView` 的判定/绘制联动主要由集成测试覆盖（背景层已有 `test_duel_view_background.gd` 直接断言，主菜单背景有 `test_menu.gd`，刀光外移/形变有 `test_duel_fx.gd`，P2 蓝色图集有 `test_duel_view_spine.gd`）；`DuelAudio` 已有 WAV 循环/启动测试（`test_duel_audio.gd`），主题有 `test_rain_night_theme.gd`。
- **Spine 运行时授权未解决**：`addons/spine_godot/` 采用 Spine Runtimes License，使用需持有对应 Spine 授权；当前仅作内部测试，公开仓库分发 DLL 或对外分发构建**需人类拍板**（见 `docs/dev-example/spine-integration.md` §10）。
- Spine 素材是美术提供的**测试 chibi**（32 骨骼 / 33 槽位 / 10 IK / 1323×1537 图集），不是最终角色；当前五条动画为 `zhanli` 站立、`gongji` 攻击、`bei_gongji` 受击、`fangyu` 防御、`siwang` 战败，已分别接到 IDLE / COMMIT·SLASH·RECOVERY / HITSTUN / GUARD·GUARD_REC·CLASH / DOWN。仍无符卡动画（`SPELL` 回退 `zhanli`），对刀暂借 `fangyu`；`siwang` 播完停末帧。P2 的蓝色衣装是同一副骨架的独立图集（`skeleton_p2.png`，1323×1537、同 26 region），不是第二套骨骼。正式资产需美术用 Spine 4.3 重导。
- 未安装 macOS/Linux/Android/iOS/Web 的 Spine 库：`.gdextension` 仍列着这些平台路径，在非 Windows 机器上打开工程会报 “Can't open dynamic library”。

## 合规与来源

- AI 使用边界、披露记录：`docs/gamejam/ai-disclosure.md`（只写代码；不生成美术/音乐/音效/文案）。
- 占位登记：`docs/gamejam/submission-checklist.md` §7（`PH-01` … `PH-18`）。
- 音频来源与许可：`assets/audio/CREDITS.md`、`docs/audio-assets-plan.md`。
- 粒子贴图来源与许可：`assets/particles/CREDITS.md`、`docs/particle-assets-plan.md`（Kenney Particle Pack 1.1，CC0 1.0）。
- 东方 Project 二创声明：游戏内「关于」页已写明「本作是东方 Project 二次创作，版权归上海爱丽丝幻乐团及 ZUN 所有」与「与官方无任何关联、未使用原作游戏素材」；提交用 README 仍须由人类按 `docs/gamejam/submission-checklist.md` §4 撰写并同样注明。详见 `docs/gamejam/README.md` 与 `docs/gamejam/constraints.md`。
- 提交清单：`docs/gamejam/submission-checklist.md`；活动硬约束：`docs/gamejam/constraints.md`。

## 相关文档

- [设计文档](docs/dev-example/design.md)
- [M5 状态](docs/dev-example/m5-status.md)
- [GameJam 说明](docs/gamejam/README.md)
- [提交清单](docs/gamejam/submission-checklist.md)
- [AI 披露](docs/gamejam/ai-disclosure.md)
- [音频计划](docs/audio-assets-plan.md)
- [Spine 接入](docs/dev-example/spine-integration.md)
- [雨夜背景与战败表现](docs/dev-example/rainy-night-background.md)
- [雨夜主题与 CC0 雨声](docs/dev-example/rain-night-theme.md)
- [工作流开发经验（工程文档）](docs/workflow-development-experience.md)
