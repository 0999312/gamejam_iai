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

## 5. 艺术资产声明（提交时填写并保留）

> 请在提交前由团队负责人确认后勾选：

- [ ] 本作**美术**（角色、场景、UI 视觉、特效贴图、封面）全部由人类制作，**未使用任何 AI 生成工具**。
- [ ] 本作**音乐 / 音效 / 配音**全部由人类制作或使用合法授权的第三方素材，**未使用任何 AI 生成工具**。
- [ ] 本作**文案**（剧情、对白、旁白、道具与技能描述、UI 文字、作品 README、宣发文案）全部由人类撰写，**未使用任何 AI 生成工具**。
- [ ] 本作代码允许使用 AI 辅助，明细见 §4。
- [ ] 本作**未使用**东方 Project 原作游戏素材（截图/游玩视频仅用于宣传）。
- [ ] （仅当采用东方 IP 时）已在游戏内「关于」页与提交 README 中注明「本作是东方 Project 二次创作」。

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
