# AI 使用披露（AI Disclosure）

> 主办方要求：使用 AI 编写代码**必须披露**——「使用的 AI 产品及 AI 率等指标」，可通过日志披露，可提供仓库权限以便审查（参与指南:99）。
> 本文件既是规范说明，也是**随开发滚动维护的披露日志**，提交时附在作品说明里或提供仓库链接。
> 维护频率：**每个功能/模块完成后即时追加一行**；不要攒到截止前补写（补写会失真，也可能漏项）。

## 1. 允许 / 禁止（一句话版）

- 允许：用 AI **写代码**（GDScript、C#、shader、场景结构、工具与测试脚本）。
- 禁止：用 AI 生成**美术、音乐、音效、文案**（剧情、对白、UI 文字、道具描述、作品 README、宣发文案）。
- 必须：记录 AI 产品与 AI 率；**AI 不能替代人类决策**，玩法、创意、内容取舍由人决定并负责。

## 2. 披露要素

| 要素 | 说明 |
|------|------|
| AI 产品 | 名称 + 版本/型号（如 DeepSeek Harness Web 端的编码代理，模型 deepseek-flash） |
| 用途范围 | 具体做了什么（例：实现弹幕发射与碰撞、重构状态机、写 GUT 测试） |
| AI 率 | 见 §3 计算口径；按模块/文件给出近似百分比 |
| 人类复核 | 谁审过、改了什么（关键逻辑是否被人工重写） |
| 艺术资产声明 | 明确写出：美术 / 音乐 / 音效 / 文案 **0% AI 生成**，均为人类创作或第三方授权素材 |

## 3. AI 率计算口径（团队自定，声明一种即可）

采用**按模块近似百分比**口径：

- `100%`：整个文件/模块由 AI 首次生成，人类仅做少量修正或未改。
- `50–90%`：AI 打底，人类做了结构性修改或重写关键部分。
- `<50%`：人类主导，AI 仅补全片段/查错。
- `0%`：纯人工编写（不含 AI 生成内容的文件也值得记录，用于证明非 AI 部分）。

统计范围：**代码与工程文件**（`.gd`/`.cs`/`.glsl`/`.tscn`/`.tres`/构建脚本）。艺术资产一律 `0%`（因为禁止 AI 生成），无需逐项统计，只在 §5 声明。

## 4. 披露日志

> 新行追加在表格末尾；同一模块多次迭代可累计到同一行，用「备注」记录增量。

| 日期 | 模块 / 文件 | AI 产品 | 用途 | AI 率 | 人类复核 | 备注 |
|------|-------------|---------|------|-------|----------|------|
| 2026-10-19 | `AGENTS.md`、`docs/gamejam/*.md`（工程内部文档，非作品内容） | DeepSeek Harness（deepseek-flash） | 整理参与指南约束、生成披露与检查清单模板、记录主题与项目方向 | 100% | 待人工校对 | 不出现在作品中，不构成艺术资产 |
| 2026-10-19 | `docs/dev-example/design.md`（策划/工程规格，非作品内容） | DeepSeek Harness（deepseek-flash） | 汇总人类拍板的 17 项决策，整理玩法、帧数据、判定矩阵、AI、Roguelike、架构、测试与里程碑规格 | 100% | 待人工复核（决策由人类拍板） | 不出现在作品中；角色名、UI、台词等均为 PLACEHOLDER，由人类撰写；v0.2 按人类指示改为无背景玩法 Demo（不绑定东方 IP） |
| 2026-10-19 | `docs/audio-assets-plan.md`、`assets/audio/_sources/*`（工程/采购文档与本地试听库，非作品内容） | DeepSeek Harness（deepseek-flash） | 检索并下载 CC0/可商用音频候选、核对许可、整理选型与导入规范 | 100% | 待人类试听选型 | **音频 0% AI 生成**；原始文件不入库；Mixkit 仅作试听参考 |
| 2026-10-19 | `scripts/duel/duel_types.gd`、`fighter_data.gd`、`fighter_state.gd`、`duel_sim.gd`（判定核心） | DeepSeek Harness（deepseek-flash） | 实现 60Hz 内在帧判定、心流、HP、输入缓冲 | 100% | 待人工试玩复核 | 数值来自 `design.md`；AI 未生成任何文案/美术 |
| 2026-10-19 | `scripts/duel/ai_profile.gd`、`duel_ai.gd`（对手 AI） | DeepSeek Harness（deepseek-flash） | 实现教学对手决策、虚招、架招、惩罚窗与开场礼让 | 100% | 待试玩调参 | 不读玩家输入；反应下限与参数见设计 §7 |
| 2026-10-19 | `scripts/duel/duel_view.gd`、`duel_hud.gd`、`duel_controller.gd`、`scenes/duel/*.tscn`（灰盒表现/场景/输入） | DeepSeek Harness（deepseek-flash） | 灰盒绘制、HUD、GUIDE J/K/R 接入、主场景启动 | 100% | 待人工目视/试玩 | UI 文本全部 `PH_` 占位，由人类替换 |
| 2026-10-19 | `tests/unit/test_duel_sim.gd`、`test_duel_ai.gd`、`tests/integration/test_duel_input.gd`（GUT） | DeepSeek Harness（deepseek-flash） | 29 项 GUT 测试：判定矩阵、心流、缓冲、AI、GUIDE 注入输入 | 100% | 待人工复核 | 29/29 通过（headless） |
| 2026-10-19 | `docs/dev-example/m1-status.md`、`project.godot`（工程记录/接线） | DeepSeek Harness（deepseek-flash） | 记录 M1 状态与运行方式；接线 GUIDE autoload 与主场景 | 100% | 待人工复核 | 不改插件源码 |
| 2026-10-19 | `scripts/run/run_state.gd`、`scripts/duel/duel_controller.gd`、`duel_hud.gd`、`ai_profile.gd`、`duel_ai.gd`、`fighter_data.gd`、`duel_sim.gd`（M2 局内闭环） | DeepSeek Harness（deepseek-flash） | 实现 5 场阶梯、金币/残心、10 心得三选一、HUD 奖励/结果、关底二阶段、心得运行时 mods | 100% | 待人工试玩复核 | 51 项 GUT 全过；UI 文本与心得名/描述仍为 `PH_` 占位，由人类撰写 |
| 2026-10-19 | `tests/unit/test_run_state.gd`、`test_upgrades.gd`、`tests/integration/test_duel_hud.gd`、`test_duel_run.gd`、`docs/dev-example/m2-status.md`（M2 测试与记录） | DeepSeek Harness（deepseek-flash） | 金币/残心/三选一/心得/HUD/场景串联测试与状态记录 | 100% | 待人工复核 | 测试数 29→51 |
| 2026-10-19 | `scripts/core/game_bootstrap.gd`、`scripts/run/upgrade_data.gd`、`scripts/run/run_state.gd`、`scripts/duel/duel_hud.gd`（MSF 注册表/I18N 接线） | DeepSeek Harness（deepseek-flash） | 用 `RegistryManager` 注册 10 个心得、用 `I18NManager` 加载 `zh_CN.json`；HUD/心得文本改为查 I18N 键，不再硬编码 `PH_` 键名 | 100% | 待人工复核 | 代码 100% AI；文本值全部为 `[占位]`，非正式文案 |
| 2026-10-19 | `scripts/core/meta_save.gd`、`scripts/core/game_bootstrap.gd`、`scripts/run/run_state.gd`（M3 局外存档/金币持久化） | DeepSeek Harness（deepseek-flash） | 实现 `MetaSave` JSON 存档、默认值/损坏回退、扣费/解锁/统计；金币从存档带入局内并每场写回 | 100% | 待人工复核 | 存档 `user://meta_save.json`；测试不污染玩家存档 |
| 2026-10-19 | `scripts/ui/menu.gd`、`scenes/menu/menu.tscn`、`scripts/duel/duel_controller.gd`、`duel_hud.gd`、`localization/zh_CN.json`（M3 主菜单/本地双人） | DeepSeek Harness（deepseek-flash） | 主菜单（单人/双人/退出）、`pending_mode` 切换、P2 小键盘 1/2（或 I/O）、Esc 返回菜单、双人 HUD | 100% | 待人工试玩 | 菜单与双人文本均为 `[占位]`；双人镜像角色 A |
| 2026-10-19 | `tests/unit/test_meta_save.gd`、`test_run_meta.gd`、`tests/integration/test_menu.gd`、`test_duel_versus.gd`、`docs/dev-example/m3-status.md`（M3 测试/记录） | DeepSeek Harness（deepseek-flash） | 存档往返/损坏回退/扣费/统计、金币带入、菜单按钮、P2 提交与重开 | 100% | 待人工复核 | 测试数 51→67，67/67 通过（headless） |
| 2026-10-20 | `scripts/duel/fighter_data.gd`、`fighter_state.gd`、`duel_sim.gd`、`ai_profile.gd`、`duel_ai.gd`、`duel_controller.gd`、`duel_view.gd`、`duel_hud.gd`、`localization/zh_CN.json`、`tests/unit/test_duel_sim.gd`、`test_duel_ai.gd`、`test_upgrades.gd`、`tests/integration/test_duel_hud.gd`、`docs/dev-example/design.md`、`balance-pass-01.md`（平衡调整 01 + 开始提示/AI 间合） | DeepSeek Harness（deepseek-flash） | 按人类试玩反馈实现心流自然恢复、出刀扣心流、降低对手攻击欲/虚招率、礼让 180f、关底 HP 4、COMMIT 气环；追加礼让结束「开始」提示与 AI 命中后间合 | 100% | 待人工试玩复核 | 数值为初版调参；文本仍为 `[占位]`；GUT 69/69 |
| 2026-10-20 | `scripts/audio/duel_audio.gd`、`scripts/duel/duel_controller.gd`、`scripts/duel/duel_hud.gd`、`scripts/ui/menu.gd`、`project.godot`、`assets/audio/sfx/*`、`assets/audio/amb/*`（音频接入第一版） | DeepSeek Harness（deepseek-flash） | 接入 `SoundManager`；把斩/拔刀/被架/完美格挡/刃鸣/受击/衣料/开始提示/UI 点击/环境风声映射到判定信号；修复环境音退出泄漏 | 100% | 待人工试听/试玩 | **音效与环境音 0% AI 生成**，均为 Kenney / OGA（SketchMan3）CC0；来源见 `assets/audio/CREDITS.md`；GUT 69/69 |
| 2026-10-20 | `scripts/duel/fighter_data.gd`、`scripts/run/run_state.gd`、`scripts/core/meta_save.gd`、`game_bootstrap.gd`、`scripts/core/unlocks.gd`、`scripts/ui/menu.gd`、`shop.gd`、`settings.gd`、`pause_menu.gd`、`scripts/duel/duel_controller.gd`、`localization/zh_CN.json`、`scenes/ui/*`、`tests/unit/test_characters.gd`、`test_unlocks.gd`、`test_meta_save.gd`、`test_duel_pause.gd`、`tests/integration/test_menu.gd`（M4） | DeepSeek Harness（deepseek-flash） | 实现角色 B/C、局外解锁商店、困难模式、起始心得槽、设置页、暂停层、P2 镜像角色；音频总线与 headless 无音频处理 | 100% | 待人工试玩复核 | 代码 100% AI；玩家可见文本仍全部 `[占位]`；GUT 81/81 |
| 2026-10-20 | `scripts/core/key_bindings.gd`、`unlock_item.gd`、`unlocks.gd`、`meta_save.gd`、`game_bootstrap.gd`、`scripts/ui/settings.gd`、`shop.gd`、`menu.gd`、`scripts/duel/duel_controller.gd`、`duel_hud.gd`、`localization/zh_CN.json`、`localization/en.json`、`tests/unit/test_key_bindings.gd`、`test_i18n.gd`、`test_shop_catalog.gd`、`tests/integration/test_settings.gd`（M5） | DeepSeek Harness（deepseek-flash） | 通用 UI 去占位、中英双语与语言切换、按键改键/冲突检测/恢复默认、HUD 动态操作提示、商店目录化（`UnlockItem`/`Unlocks.catalog()`） | 100% | 通用 UI 标签由人类指示去占位（m02521），待人类最终复核；内容文案仍为占位 | 代码 100% AI；**通用中文 UI 标签为功能性术语，由 AI 起草、人类明确指示采用**；剧情/教程/心得/商店条目/英文内容仍为占位；GUT 95/95 |
| 2026-10-20 | `scripts/core/input_devices.gd`、`resources/unlocks/*.tres`、`game_bootstrap.gd`、`unlocks.gd`、`shop.gd`、`duel_controller.gd`、`settings.gd`、`tests/unit/test_input_devices.gd`、`test_game_data.gd`、`tests/integration/test_duel_gamepad.gd`（数据驱动商店 + 手柄） | DeepSeek Harness（deepseek-flash） | 商店改为 MSF 注册表数据驱动；键鼠/手柄同一动作并存映射；P2 第二手柄检测；虚拟手柄注入测试 | 100% | 待人类测试真实手柄与商店追加流程 | 代码 100% AI；当时代码固定 A/B/Start/Back；手柄改键见下一行；GUT 102/102 |
| 2026-10-20 | `scripts/core/key_bindings.gd`、`meta_save.gd`、`input_devices.gd`、`scripts/ui/settings.gd`、`scripts/duel/duel_controller.gd`、`localization/zh_CN.json`、`localization/en.json`、`tests/unit/test_key_bindings.gd`、`test_input_devices.gd`、`tests/integration/test_settings.gd`、`test_duel_gamepad.gd`（手柄改键 + 热插拔） | DeepSeek Harness（deepseek-flash） | 手柄键逐项改绑、冲突检测、`settings.joy_buttons` 持久化、手柄热插拔重建 GUIDE 上下文并重新分配 P1/P2 | 100% | 待人类插拔真实手柄复核 | 代码 100% AI；通用 UI 文本为功能性标签；GUT 110/110 |
| 2026-10-20 | `scripts/ui/ui_focus.gd`、`scripts/core/game_bootstrap.gd`、`scripts/ui/menu.gd`、`shop.gd`、`settings.gd`、`pause_menu.gd`、`scripts/duel/duel_hud.gd`、`localization/zh_CN.json`、`localization/en.json`、`tests/integration/test_ui_gamepad.gd`（全手柄 UI） | DeepSeek Harness（deepseek-flash） | 内置 `ui_accept`/`ui_cancel` 追加手柄 A/B；菜单/商店/设置/暂停/奖励初始焦点与金色焦点环；方向键导航；改键等待时 Back 取消 | 100% | 待人类用真实手柄复核 | 代码 100% AI；通用 UI 文本为功能性标签；GUT 116/116 |
| 2026-10-20 | `export_presets.cfg`、`.github/workflows/build.yml`、`build/windows/iai.exe`（不入库）、`docs/dev-example/m5-status.md`（导出段） | DeepSeek Harness（deepseek-flash） | 生成 Windows 导出预设与 GitHub Actions 工作流；本机导出 EXE 并做 headless 冒烟 | 100% | 待人类在非开发机与远端 CI 验证 | 代码/构建配置 100% AI；导出产物在 `build/` 且已 gitignore；GUT 116/116 |
| 2026-10-20 | `scripts/duel/duel_controller.gd`、`scripts/core/game_bootstrap.gd`、`tests/integration/test_duel_gamepad.gd`、`tests/integration/test_ui_gamepad.gd`（手柄兜底） | DeepSeek Harness（deepseek-flash） | 修复真实手柄失效：GUIDE 手柄表延迟刷新、P1/P2 映射不依赖启动枚举、按 `event.device` 原始兜底、UI 动作 `device=-1`、暂停去抖 | 100% | 待人类用真实手柄复测 | 代码 100% AI；GUT 119/119 |
| 2026-10-20 | `.github/workflows/build.yml`、`project.godot`、`export_presets.cfg`（Release 版本） | DeepSeek Harness（deepseek-flash） | 构建号 `YYYY-MM-DD-NN`（UTC，01 起）、语义化版本 `0.0.0`；Action 导出 EXE 并创建 GitHub Release | 100% | 待远端首次运行验证 | 构建配置 100% AI；Release notes 仅含版本/构建号/commit 元数据 |
| 2026-10-20 | `README.md`、`docs/dev-example/design.md`（v0.15）、`docs/dev-example/m5-status.md`（CI/README 段）、`docs/gamejam/submission-checklist.md`（构建/README 项） | DeepSeek Harness（deepseek-flash） | 编写**工程开发说明** README（环境/命令/架构/扩展/构建/限制）；同步最终状态 | 100% | 待人类复核；提交用作品 README 未写，仍由人类撰写 | 仅工程/构建说明，非玩家文案；AI 未生成美术/音频/剧情；GUT 119/119 |
| 2026-10-20 | `scripts/duel/duel_types.gd`、`fighter_data.gd`、`fighter_state.gd`、`spell_card.gd`、`duel_sim.gd`、`duel_ai.gd`、`duel_view.gd`、`duel_hud.gd`、`duel_controller.gd`、`scripts/run/run_state.gd`、`scripts/core/key_bindings.gd`、`tests/unit/test_spell_cards.gd`、`test_duel_ai.gd`、`test_duel_sim.gd`、`test_run_state.gd`、`test_key_bindings.gd`、`tests/integration/test_settings.gd`、`test_duel_input.gd`（v0.16 攻防窗口重做 + 符卡系统） | DeepSeek Harness（deepseek-flash） | 按人类四条试玩反馈实现：防御窗加宽（12f 基准 + 0/4/8 心流偏移、气环全程可见、架剩余弧）、进攻端心流权重加倍（+6/0/−6f，下限 8f）、重剑 2 伤害 + 12f 破势、AI 防御时序修复（按 `commit_total - cover` 排期）、每角色 1 张硬绑定符卡（架势/穿防/崩势）、残心改为心流保证（下限 +6/层、中刀 −3/层、架 +1f/层）；清理 `start_flow()` 与 `GUARD_TIER_FRAMES` 双路径 | 100% | 数值与取舍由人类拍板（m00052/m00248）；待人工试玩复核手感 | 代码 100% AI；**符卡名与描述未写任何文案**，6 个 `spell.*` 键留空由人类提供，HUD 回退显示 `[占位] <key>`（PH-18）；GUT 132/132（416 asserts） |
| 2026-10-20 | `scripts/duel/spell_card.gd`、`fighter_data.gd`、`duel_sim.gd`、`ai_profile.gd`、`duel_ai.gd`、`duel_view.gd`、`duel_hud.gd`、`scripts/audio/duel_audio.gd`、`tests/unit/test_spell_cards.gd`（v0.17 符卡表现 + 关底符卡） | DeepSeek Harness（deepseek-flash） | 按人类反馈「注意符卡表现，敌人也应有符卡（只有关底 BOSS 需要）」实现：新增 `spell_boss`（穿防 3 伤 + 破势、14f 蓄力、仅第 5 场持有）、`DuelAi._try_spell` 三个时刻择机发动、蓄力被命中即驱散（`spell_interrupted`）、`SPELL` 光柱/双环/扩散环/降调音效/HUD 报幕；`SpellCardData.unblockable` 改为数据字段 | 100% | 人类决定「小兵不用、只给关底」（m00575）；待人工试玩复核关底难度 | 代码 100% AI；**未新增任何玩家可见文案**，报幕只显示符卡名、`spell.spell_boss.name|desc` 2 键留空由人类提供（PH-18 现 8 键）；GUT 136/136（434 asserts） |
| 2026-10-20 | `scripts/duel/duel_types.gd`、`fighter_data.gd`、`duel_sim.gd`、`duel_view.gd`、`scripts/audio/duel_audio.gd`、`tests/unit/test_duel_sim.gd`、`tests/unit/test_spell_cards.gd`、`docs/dev-example/design.md`（v0.18 可读性） | DeepSeek Harness（deepseek-flash） | 按人类反馈「敌人出刀仍比肉眼看上去快，看见闪光后按键有延迟、架不住」：对手前兆 12–15f 统一抬到 18–20f（旧值低于视觉反应 + 1f 输入延迟 + 1f 起架的实际开销）、`guard_startup` 2f→1f/重剑 3f→2f、新增 `DuelTypes.SLASH_WARN_FRAMES=8` 与 `DuelSim.slash_imminent` 信号、气环在落刀前 8f 转白并呼吸式加粗、`sfx_block` 升至 1.52–1.66 倍音高做「叮」 | 100% | 人类提出该手感问题（m00793）；数值方向由 AI 提出、待人工试玩确认是否偏慢（design.md §17 第 14 项） | 代码 100% AI；**未新增任何玩家可见文案**；GUT 136/136（434 asserts） |
| 2026-10-20 | `scripts/duel/fighter_data.gd`、`duel_sim.gd`、`scripts/duel/duel_controller.gd`、`tests/unit/test_duel_ai.gd`、`tests/unit/test_run_state.gd`、`docs/dev-example/design.md`（v0.19 快斩与回血） | DeepSeek Harness（deepseek-flash） | 按人类反馈「有时敌人会以几乎无法反应的时间快斩一刀」与「恢复 2 血量的加成似乎没有正常触发」：定位到 AI 心流进「流」档后吃 −6f 偏移把前摇压到 12f，新增 `FighterData.flow_speeds_commit` 让对手只吃低心流惩罚；复元回血逻辑本身正确但奖励界面 HUD 读的是未同步的 `sim.p1.hp`，结算后补同步 | 100% | 人类提出两个现象（m00941）；「AI 不吃心流加速」为 AI 提出的修复方向，待人工试玩确认 | 代码 100% AI；**未新增任何玩家可见文案**；GUT 139/139（439 asserts） |
| 2026-10-20 | `scripts/duel/spell_card.gd`、`fighter_state.gd`、`duel_sim.gd`、`duel_hud.gd`、`duel_view.gd`、`tests/unit/test_spell_cards.gd`、`project.godot`、`docs/dev-example/design.md`（v0.20 符卡重做） | DeepSeek Harness（deepseek-flash） | 按人类反馈「符卡效果感觉不到对战局的影响」「符卡应是一局一次性技能，收益与风险都比较大」重做三张符卡：① 收益由数值级改规则级（`spell_a` 60f 必完美格挡、`spell_b`/`spell_c` 蓄力后自动落刀并穿防）；② 风险改明牌（可见 `SPELL` 蓄力 8–20f，可被抢刀打断，打断加 12f 惩罚硬直）；③ 修「按了没反应」（4f 输入缓冲、非 IDLE 不再静默丢弃、HUD 四态与失败闪红 16f）；④ 修开局发不出（`spell_c` 40→34、关底 45→40，新增回归测试锁住「成本 ≤ 起始心流」）；⑤ 帧率固定（`physics_ticks_per_second=60`、`max_physics_steps_per_frame=8`、`physics_jitter_fix=0.0`） | 100% | 人类提出「符卡感知不到」与「一次性、高收益高风险」两条方向（m01037 / m01058），并选定「每场对决一次 + 按方案全改」；具体数值待人工试玩 | 代码 100% AI；**未新增任何玩家可见文案**（蓄力态只用 `▶`/`×` 符号标示）；GUT 141/141 |
| 2026-10-20 | `localization/zh_CN.json`、`localization/en.json`、`tests/unit/test_i18n.gd`、`docs/dev-example/design.md`、`docs/gamejam/submission-checklist.md`（v0.21 占位补齐） | DeepSeek Harness（deepseek-flash） | 按人类指示「给当前没有占位文本的地方先上占位文本」：把 v0.20 新增的 8 个符卡键（`spell.*.name|desc`）与 `state.spell` 的**显式占位条目**写入中英两份 JSON（键数 122→131，两语言键集合一致），使 HUD 显示 `[占位] 符卡 A` 而不是 `[占位] spell.spell_a.name`；新增 `test_spell_and_spell_state_have_explicit_placeholders` 锁住这 9 个键 | 100% | 人类提出补齐占位（m01297）；占位文字由人类要求、内容仅为「符卡 A/B/C/关底」编号标记 | **新增内容全部是 PLACEHOLDER 标记，不是玩家可见文案**；无效果描述、无名称创意；GUT 142/142（468 asserts） |
| 2026-10-21 | `scripts/duel/fighter_data.gd`、`ai_profile.gd`、`duel_ai.gd`、`duel_sim.gd`、`fighter_state.gd`、`spell_card.gd`、`match_setup.gd`（新）、`duel_controller.gd`、`duel_view.gd`、`scripts/run/run_state.gd`、`tests/unit/test_characters.gd`、`test_duel_sim.gd`、`test_duel_ai.gd`、`test_run_state.gd`、`test_spell_cards.gd`、`test_upgrades.gd`、`tests/integration/test_duel_run.gd`、`test_duel_versus.gd`、`docs/dev-example/balance-pass-02-plan.md`、`balance-pass-02.md`（平衡调整 02：反应窗/难度双档/HP×10/多角色基础） | DeepSeek Harness（deepseek-flash） | 按第三方试玩 5 条反馈与人类批复（`m00251`）：① 对手前摇 18–20f → 28–30f（467–500ms）、架窗 11–14f → 18–22f，可挡区间改为毫秒基准；② 拆出 NORMAL/HARD 双档（旧数值 + 旧帧数表回滚为 HARD）；③ HP ×10、伤害 10/7/15、符卡与追击伤害同步放大、HP 改连续血条；④ 八人 `FighterData`（3 玩家 + 5 对手）与 `persona_id`、`MatchSetup`、`roster()`/`select_character()`/`stage_cast()`，为「收服敌人当可操作角色」打好基础；⑤ 礼让期内不再自然恢复心流；⑥ 反斩（`riposte_commit_bonus`）、连斩惩罚（`repeat_commit_penalty`）、AI 确定反与起构安全判断；⑦ 顺手修复 AI 读招骰子粘滞 bug（无脑连砍的真因） | 100% | 数值与取舍由人类拍板（`m00240`/`m00251`）；待人工试玩复核手感与难度 | 代码 100% AI；**未新增任何玩家可见文案**（AI profile 的 `display_name` 仍是 `PLACEHOLDER`）；GUT 159/159（556 asserts） |
| 2026-10-21 | `scripts/duel/fighter_data.gd`（`cancel_window` 10f）、`duel_sim.gd`（`GUARD_COUNTER_WINDOW`/`GUARD_COUNTER_COMMIT_BONUS`/`_try_counter_strike`/`_guard_to_attack`/`_buffer`/`_enter_commit`）、`fighter_state.gd`（`counter_until_frame`/`pending_commit_bonus`）、`tests/unit/test_duel_sim.gd`、`docs/dev-example/balance-pass-03.md`（新）（平衡调整 03：打通攻↔防变招） | DeepSeek Harness（deepseek-flash） | 按第三方反馈（`m00672`）「攻击转防、防御转攻在实际游戏中打不出来」：① 构→架取消窗 5f → 10f（167ms）；② 架中按斩立即收架出刀（扣 5 心流）；③ 架住后 30f（500ms）反击预备窗 + 顺势斩前摇 −6f；④ 输入缓冲改为活过整段硬直（旧 4f 缓冲 < 7–9f 收架，预输入必然过期）；⑤ 架住反击不吃反斩，避免「架=白送一刀」 | 100% | 数值与窗口由人类拍板（`m00672` 反馈，取舍待人工试玩确认）；「只架不攻」对 NORMAL AI 仍 100% 胜，已列为遗留风险 | 代码 100% AI；**未新增任何玩家可见文案**；GUT 163/163（568 asserts） |

## 5. 艺术资产声明（提交时填写并保留）

> 请在提交前由团队负责人确认后勾选：

- [ ] 本作**美术**（角色、场景、UI 视觉、特效贴图、封面）全部由人类制作，**未使用任何 AI 生成工具**。
- [ ] 本作**音乐 / 音效 / 配音**全部由人类制作或使用合法授权的第三方素材，**未使用任何 AI 生成工具**。
- [ ] 本作**文案**（剧情、对白、旁白、道具与技能描述、UI 文字、作品 README、宣发文案）全部由人类撰写，**未使用任何 AI 生成工具**。
- [ ] 本作代码允许使用 AI 辅助，明细见 §4。
- [ ] 本作**未使用**东方 Project 原作游戏素材（截图/游玩视频仅用于宣传）。
- [ ] （仅当采用东方 IP 时）已在游戏内「关于」页与提交 README 中注明「本作是东方 Project 二次创作」。

> 注（2026-10-20）：通用功能性 UI 标签（如「设置」「生命」「金币」）按人类指示由 AI 起草并去除 `[占位]`；剧情、教程、心得、商店条目与英文内容仍为占位。提交前需人类复核这些标签是否可接受，必要时由人类改写。

## 6. 第三方素材来源表

| 素材 | 来源 / 作者 | 许可 | 使用位置 | 致谢方式 |
|------|-------------|------|----------|----------|
| MiSans 字体 | 小米（模板自带 `assets/fonts/`） | 待核对（MiSans 许可协议） | UI 全局字体 | README 致谢 |
| 单色 SVG 图标（220 个） | 模板自带 `assets/icons/`，来源待核对 | 待核对 | UI 图标 | README 致谢 |
| Kenney 界面音效 | Kenney（CC0） | CC0，可商用 | UI 交互音效 | README 致谢 |
| 主题资源 `minimal_vector.tres` / `modern_flat.tres` | 模板自带 | 待核对 | 全局 Theme | README 致谢 |
| Kenney Impact Sounds | Kenney（CC0） | CC0，可商用 | 已入库：被架/刃鸣/受击/踏地（`impactMetal_medium/heavy`、`impactPlate_medium/heavy`、`impactPunch_heavy`、`impactSoft_heavy`、`footstep_wood`） | README 致谢（可选） |
| Kenney RPG Audio | Kenney（CC0） | CC0，可商用 | 已入库：斩/拔刀/开始/衣料/UI 点击（`knifeSlice`、`knifeSlice2`、`drawKnife1`、`drawKnife2`、`cloth1`、`cloth2`、`metalClick`） | README 致谢（可选） |
| OGA `wind whoosh loop` | SketchMan3（CC0） | CC0，可商用 | 已入库：`assets/audio/amb/amb_wind_loop.ogg` | README 致谢（可选） |
| OGA Winter Wind / Loopable Dungeon Ambience | OpenGameArt 各词条作者 | CC0（逐条核对） | 仅本地候选，未入库 | 如采用再补 |
| Mixkit 剑音/风声候选 | Mixkit | Mixkit Sound Effects Free License（仅试听参考，未入库/未用于构建） | 写实剑音与风声参考 | 若采用需人类确认，且不随源文件再分发 |
| （新增素材逐行补充） | | | | |

## 7. 审查配合

主办方如需审查：提供仓库读权限 + 本披露文件 + Git 提交记录（提交时间可证明内容均在 2026-10-17 10:00 之后产出）。主办方承诺保护参与团队隐私（参与指南:99）。
