# 提交前检查清单（Submission Checklist）

> 目标：在 **2026-11-07 10:00** 之前完成符合全部规则的提交。官方建议**不晚于截止前 15–20 分钟**（即 **09:40** 前完成点击提交），以规避网络问题（参与指南:64）。
> 使用方式：逐项勾选，未勾选项即风险项；灰色「N/A」项说明理由。

## 0. 时间盒倒排（按 18 天剩余）

| 时间段 | 目标 |
|--------|------|
| 10-19 → 10-24 | 可玩闭环：开局 → 核心玩法 → 结束/失败判定 |
| 10-25 → 11-01 | 内容填充：关卡/敌人/角色/音画接入（人类制作的素材） |
| 11-02 → 11-04 | 打磨 + **功能冻结**（此后只改 bug） |
| 11-05 → 11-06 | 多设备测试、导出构建、写 README/封面、填披露 |
| 11-07 09:00 前 | 最终提交（**不晚于 09:40**） |

## 1. 合规（红线，任一不通过则不能提交）

- [ ] 作品内容围绕本期主题，能在 README 中用一句话说清「为什么契合主题」。
- [ ] 无 NSFW 内容、无违反公序良俗内容。
- [ ] **美术 0% AI**：立绘/场景/UI/图标/封面均为人类创作或授权素材（逐项核对 `ai-disclosure.md` §6）。
- [ ] **音乐/音效 0% AI**：均为人类创作或 CC0/授权素材。
- [ ] 音频素材许可已逐条登记（CC0/CC-BY/可商用），原始文件未入库，credits 完整（见 `docs/audio-assets-plan.md`）。
- [ ] 粒子贴图许可已登记：Kenney Particle Pack 1.1（**CC0 1.0**，可商用、署名非必需），36 张已入库 `assets/particles/**`，来源清单见 `assets/particles/CREDITS.md`；原始素材包留在本地 `temp_assets/`（已 `.gitignore` + `.gdignore`，不入库、不被 Godot 扫描）。**已接入**命中 / 对刀 / 架防三类（`scripts/duel/duel_fx.gd` + `scenes/duel/duel_fx.tscn`），并由 `slash/twirl_03` 替换挥砍弧、`guard/circle_02`（紫）替换符卡爆环（2026-10-23，验收截图 `docs/dev-example/duel-fx-preview.png` 与 `duel-fx-slash.png`）；符卡法阵/光柱、扬尘、空架、收刀、心流氛围仍待后续批次（映射见 `docs/particle-assets-plan.md` §5）。
- [ ] **文案 0% AI**：剧情、对白、旁白、道具/技能描述、README、宣发文案均人类撰写（AI 只可辅助内部工程文档）。通用 UI 功能性标签已按人类指示（2026-10-20）去占位，仍需人类最终确认/改写后再勾选。
- [ ] 无东方 Project **原作游戏素材**；无来源不明的同人素材。
- [x] （仅当采用东方 IP 时）游戏内「关于」页已含二次创作声明（「本作是东方 Project 二次创作，版权归上海爱丽丝幻乐团及 ZUN 所有」）与「未使用原作游戏素材、与官方无关联」声明（v0.24，`scenes/ui/about.tscn` / `scripts/ui/about_panel.gd`）；**README 的对应声明仍需人类确认后勾选**。
- [ ] 若最终提交为无背景 Demo（不套东方 IP）：已由人类确认活动主题仍成立，或已补齐可提交的 IP 皮肤。
- [ ] 未使用官方 LOGO、未暗示官方授权，署名方式已按团队约定确定（参与指南:62）。
- [ ] `docs/gamejam/ai-disclosure.md` §4 日志已更新到最新模块，§5 声明已勾选。
- [ ] **Spine 运行时授权已确认**（2026-10-29 新增）：`addons/spine_godot/` 采用 Spine Runtimes License，使用运行时的前提是持有 Spine 编辑器授权；团队已明确「没有预算购买」。**公开仓库/对外分发构建前必须由人类决定**：① 移除 Spine 接入回退灰盒；② 购买授权后保留；③ 仓库与构建都不对外分发。见 `docs/dev-example/spine-integration.md` §10。

## 2. 可玩性与稳定性（参与指南:91）

- [ ] 完整流程可跑通：启动 → 主菜单 → 游玩 → 胜利/失败 → 可重开。
- [x] 完整流程代码路径可跑通（2026-10-20）：主菜单 → 角色/模式 → 商店/设置 → 对决 → 结算/重开 → 暂停/返回；自动化测试覆盖。
- [x] M1 灰盒可运行（2026-10-19）：`duel.tscn` 启动即对局，J 斩 / K 架 / R 重开；`tests/` 29 项 GUT 全过（headless）。
- [x] M2 阶梯闭环逻辑可运行（2026-10-19）：5 场 + 金币/残心 + 三选一 + 关底二阶段；J/K/R/1–3；51 项 GUT 全过（headless），但三选一排版与手感待人类试玩。
- [x] M3 局外存档/主菜单/双人基础（2026-10-19）：主菜单可进单人/本地双人；金币写入 `user://meta_save.json`；Esc 返回菜单；67 项 GUT 全过（headless）。
- [x] M4 局外成长/设置/暂停/角色/音频（2026-10-20）：角色 B/C、商店解锁、困难模式、起始心得槽、设置页、暂停层、P2 镜像角色；81 项 GUT 全过（headless）；菜单/对决场景无 ERROR。
- [x] M5 通用 UI/多语言/改键/数据驱动商店/全手柄 UI（2026-10-20）：zh_CN 通用标签去占位、新增 en、按键绑定与冲突检测、手柄改键与热插拔、商店条目改为 `resources/unlocks/*.tres` + MSF 注册表、键鼠/手柄并存、全手柄 UI 导航（A 确认/B 返回/焦点环）；119 项 GUT 全过（headless，368 asserts）；四个场景 headless exit 0；中英各 122 键。手柄输入兜底与 Release 版本见 §3。
- [x] **M7 Spine 角色接入（测试性，2026-10-29）**：spine-godot 4.3 GDExtension（只 Windows 库）+ 美术提供的 JSON/atlas/PNG，替换两个灰盒占位角色；`DuelView` 在灰盒之上挂 `SpineFighterView`，无档案/无扩展自动回退；**264 项 GUT 全过（977 asserts，32 个脚本，退出码 0）**，新增 35 例；截图 `docs/dev-example/spine-takeover.png`；2026-10-31 动画播放加固：每次进入 COMMIT 从第 0 帧重播 `gongji`，新增 `playback_time_scale()` 与 4 例回归测试，逐帧预览图 `docs/dev-example/spine-animation-preview.png`；同日修复 **3.8 IK 约束被 4.3 静默丢弃**：提版工具把 5 条旧 `ik` 迁到 `constraints`，四肢现在随动画移动，新增保留 IK 的回归用例；2026-11-04 换入**五动作版**（32 骨骼 / 33 槽位 / 10 IK / 1323×1537，`zhanli`/`gongji`/`bei_gongji`/`fangyu`/`siwang`）：档案补齐 GUARD/HITSTUN/DOWN 映射，倒地播 `siwang` 不再隐藏骨架；提版工具新增 3.8 贝塞尔曲线转换（38 段），修复非末帧曲线导致的 signal 11；全量 GUT **264/264（977 asserts，32 脚本，退出码 0）**；Windows 导出退出码 0（18:56 素材版 127,489,544 B + `libspine_godot.windows.template_release.x86_64.dll` 1,774,592 B），导出 EXE headless 冒烟 120 帧退出码 0。**注意：Spine 运行时授权未解决，见 §1 对应勾选项。**
- [x] **M7.1 雨夜背景与战败去灰盒（2026-11-04）**：新增程序化雨夜（`resources/shaders/rainy_night.gdshader` + `scenes/duel/rainy_night.tscn`），`DuelView` 先建 1280×720 背景层（`z_index=-1`、鼠标穿透）并把 `ground_y/focus_left/focus_right` 对齐场地；删除 `DOWN` 的无条件灰盒——Spine 有 `siwang` 时保持骨架可见，无 Spine/无 DOWN 映射时回退旧剪影，修复「两边都不画」。**269 项 GUT 全过（1005 asserts，33 个脚本，退出码 0）**，本轮新增 5 例 28 asserts；截图 `docs/dev-example/rainy-night-preview.png` 与 `rainy-night-defeat.png`；**背景为自写 shader，无外部背景贴图，美术 0% AI**；细节见 `docs/dev-example/rainy-night-background.md`。
- [x] **M7.2 CC0 雨声与无边框雨夜主题（2026-11-04）**：环境音从旧风声换成人类提供的 CC0 WAV（`assets/audio/amb/rain_calm_loop.wav`，2 声道 / 24-bit / 48 kHz / 30 s）；`DuelAudio` duplicate 后设采样级 `LOOP_FORWARD`，经 `SoundManager` 2 秒淡入、`-17 dB`，旧风声零引用。主题改为 `assets/theme/rain_night.tres`（生成器 `tools/build_rain_night_theme.gd`）：按钮 normal 全透明、无圆角/阴影、焦点仅底边 2px 刀鞘金，`UiFocus` 同步；HUD 加顶 190px / 底 120px 渐变 scrim。**277 项 GUT 全过（1050 asserts，35 个脚本，退出码 0）**，本轮新增 8 例 45 asserts；截图 `docs/dev-example/theme-menu.png`、`theme-settings.png`、`theme-duel-hud.png`；雨声循环接缝/整体音量仍待人类试听（对应 §2「环境 loop 无接缝」）。细节见 `docs/dev-example/rain-night-theme.md`。
- [x] **M7.3 刀光形变、主菜单雨夜、心流核查（2026-11-04）**：`duel_fx.gd` 把月牙半径 122→136（离刀身约 14px），`pose_slash()` 在挥砍中段做切向拉长 13% / 径向收薄 7% / 剪切 0.10；主菜单在 `_build_ui()` 清空后先建 `RainyNight` 1280×720 背景层，duplicate 材质后写 `ground_y=0.96`、`pool_strength=0`，不与对局共享；心流待机下跌经核查为「用进废退」设计（180 帧宽限、之后每 20 帧 -1、下限 15），未改数值，只修正过时注释。**279 项 GUT 全过（1068 asserts，35 个脚本，退出码 0）**；截图 `docs/dev-example/theme-menu.png`、`duel-fx-slash.png`、`duel-fx-sweep.png`。
- [x] **M7.4 P2 蓝色衣装图集（2026-11-04）**：人类提供 `skeleton_p2.png`（1323×1537，蓝色衣装），按原 `skeleton.atlas` 生成 `skeleton_p2.atlas`（仅页名改 `skeleton_p2.png`，26 个 region 坐标不变）；`DuelView` 按席位给 P2 克隆档案并只替换 `atlas_file`，P1 保持原图集，同一角色双人同屏也分色；图集缺失回退原图集。**280 项 GUT 全过（1077 asserts，35 个脚本，退出码 0）**，Spine 子集 37 例；截图 `docs/dev-example/rainy-night-preview.png` 重拍。**美术 0% AI**：贴图由人类提供，AI 只复制/改 atlas 文本/接线。
- [x] **M7.5 A 符卡瞬发自动架刀 + 残心 HUD + L 键提示（2026-11-04）**：按试玩反馈 01–03 与人类拍板（`m00159`/`m00201`）落地：① HUD（顶部与结算页）删除全部「残心」显示，机制不动（`m00653`）；② 操作行模板加 `%s`/`%S`，中文「L 发动符卡」/ P2「P 发动符卡」，开局 6 秒教程提示 `tutorial.spell`；③ A 符卡改「按 L 瞬发 45f 自动架刀窗口」——受刀自动完美弹开 + 反斩 10 伤（穿防）、空放返还 10 心流、窗口内按斩放弃保险、BOSS 穿防不穿透、玩家 B/C 穿防可穿透；④ 8 份 Spine 档案补 `SPELL→fangyu`，窗口内冻结 `fangyu` 末帧。**289 项 GUT 全过（1111 asserts，35 个脚本，退出码 0）**，`--import` 退出码 0；新增/改写 11 例。**未做**：英文文案与 `tutorial.spell`/`spell_a.desc` 正式文本（仍占位）、非 16:9 目视、实机手感确认。
- [x] **M7.6 心流待机恢复（2026-11-04）**：按人类 `m01751` 反转 M7.3 的「用进废退」判断：删除 180f 后的 `-1/20f` 无输入惩罚；礼让结束后 `IDLE` 每 24f `+1`，礼让期内不计；删除 `FighterState.last_input_frame`。心流作为符卡唯一资源重新可用，玩家与 AI 共用该恢复路径，关底 `_try_spell` 的 `flow >= cost` 重新有机会满足。**290 项 GUT 全过（1115 asserts，35 脚本，退出码 0）**；新增/改写 3 例；已同步 `design.md` D27/v0.31。
- [x] **M7.7 防御特效白→金、加法发光与看破预读弧（2026-11-04）**：按人类 `m00720` 反馈：① 起构蓄力环在临刀时不再硬切纯金，改为 `smoothstep(0.12,1.0,p)` 白→金渐变，临刀只向金 `lerp 0.7` + alpha 呼吸；头顶进度点同步渐变；② `_commit_state()` 暴露 `lead`/`span`，环外新增冷白预读弧（只给带 `hint_lead` 的一方，把看破提前量画出来）；③ 新增 `resources/shaders/glow_add.gdshader`（`blend_add` + 白芯 + `glow=1.35`），`DuelFx` 的命中/对刀/架住/爆环/蓄力环统一改用 `_make_glow_material()`。**292 项 GUT 全过（1123 asserts，35 脚本，退出码 0）**，`--import` 退出码 0；新增 2 例；截图 `docs/dev-example/duel-fx-charge.png` / `duel-fx-read.png` / `duel-fx-preview.png` 重拍。**未做**：发光强度与预读弧粗细的实机确认、`alpha_gain` 接设置页。
- [x] **M6 全量审计与修复 / 0.1.0**（2026-10-21）：四路并行审计（判定/表现、核心与存档、UI、测试）产出 P0×1 / P1×9 / P2×22 / P3×30+；六批修复后 **195 项 GUT 全过（746 asserts，27 个测试脚本，退出码 0）**；headless 冒烟 240 帧退出码 0，stdout 只有两条语言加载行、stderr 空；中英各 **151 键**、剩余占位 44/44。逐批变更见根目录 `CHANGELOG.md`。仍需人类完成的是本节 39–44 行（长跑、非开发机、帧率、音频试听、退出残留）。
- [ ] 无崩溃：主流程连续跑 10 分钟无报错；Godot 输出无红色 ERROR 刷屏。
- [ ] 无阻塞性操作问题：键鼠/手柄输入均可完成全部操作；分辨率切换与窗口缩放下 UI 不溢出。
- [ ] 在**非开发机**（或不同设备/不同分辨率）上运行通过，记录设备与结果。
- [ ] 帧率可接受（目标 60 FPS，弹幕密集时不低于 30 FPS）。
- [ ] 音频音量合理，可静音；无爆音；环境 loop 无接缝/爆音。（设置页与静音已实现；待人类试听与 loop 验收）
- [ ] 退出游戏、返回桌面正常；无残留进程。

## 3. 构建与导出

- [x] 导出预设存在且导出成功（Windows exe 或 web，按主办方要求）。2026-10-20：`Windows Desktop`，`build/windows/iai.exe`，123,636,728 B，嵌入 PCK。2026-10-30（含 Spine，18:56 素材版）：`build/spine_check/iai.exe` **127,489,544 B** + 伴随的 `libspine_godot.windows.template_release.x86_64.dll`（1,774,592 B，Godot 自动带出，无需改 export_presets）；该目录被 `.gitignore` 忽略，仅本地验证用。
- [x] 导出包内资源齐全（字体、音效、主题、shader 无丢失；`.pck` 一并打包）。已确认中英 151 条在导出 EXE 中加载；2026-11-05 起本地化为 165 条（新增 13 条选人/输入/符卡/状态键），导出包需随下一项重导后复核（本地化 JSON 由 `all_resources` 打包，导出日志可检索到 `res://localization/*.json`）；字体/音效路径未报缺失（导出日志仍有两处重复字体 UID 警告，不影响运行）。
- [ ] **2026-11-04 主题/雨声替换后重新导出并核对**：上一项导出早于本轮 `rain_night.tres`、`rain_calm_loop.wav` 与 HUD scrim 改动；提交前需重导 Windows 构建，检查主题、雨声 WAV 与三张主题截图对应的 UI 均进包，并重新记录 EXE 大小/构建号。
- [ ] 在**干净目录**解压/运行一次，确认不依赖开发机环境。
- [x] 记录构建版本号与导出时间。Godot 4.7.2.stable.mono / 最新本地产物 2026-10-20 19:54；语义化版本 **`0.1.0`**（2026-10-21 起），构建号 `YYYY-MM-DD-NN`。
- [x] GitHub Action 自动导出并创建 Release（`.github/workflows/build.yml`）：构建号 `YYYY-MM-DD-NN`（UTC，01 起），tag/Release 标题/附件同名；EXE 只作 Release 附件与 Artifact，不入库。远端已于 2026-10-20 跑通，Release `2026-10-20-02` 带 118 MB EXE；首次空 Release `2026-10-20-01` 保留未删。
- [ ] 保留一份带 tag 的源码快照（如 `v0.9-submit`），避免提交后误改。
- [x] 开发说明 README 已写（`README.md`，仅工程/构建/测试说明，不是提交用作品 README）；提交用 README 仍须人类按 §4 撰写。

## 4. 提交材料

- [ ] 可运行构建（按主办方指定格式）。
- [ ] **README**（人类撰写）：一句话创意、玩法与操作说明、主题契合说明、亮点、截图、致谢（第三方素材 + AI 披露链接）。
- [ ] **封面图**（人类绘制或授权素材，非 AI）。
- [ ] `docs/gamejam/ai-disclosure.md`（或仓库链接 + 该文件）。
- [ ] 团队信息与署名。
- [ ] 全部 PLACEHOLDER 已替换为人类内容（见 §7）。
- [ ] （可选）`辉夜姬的五难题` 作答说明，如参加支线。
- [ ] 提交通道与所需字段已确认（主办方指定方法，参与指南:39）。

## 5. 提交当天

- [ ] 09:00 前完成全部材料打包并自测解压运行。
- [ ] **09:40 前**完成提交并截屏/留存提交成功凭证。
- [ ] 记录提交时间与凭证到本文件末尾。
- [ ] 提交后**冻结仓库**：不再迭代、不再补交（参与指南:40）。

## 6. 提交后（可选，鼓励）

- [ ] 报名 11-22 南昌线下展会免费摊位，准备试玩引导与一句话介绍（参与指南:50）。
- [ ] 为主办方线上宣发提供素材：封面、2–3 张截图、玩法简介、可玩链接。
- [ ] 归档源码与素材，整理致谢名单。

## 7. 占位（PLACEHOLDER）登记

> 规则：临时缺失的内容用显式 `PLACEHOLDER` 占位并在此登记；**不得用 AI 先写一版凑数**。提交前必须清零。
> 与设计文档 `docs/dev-example/design.md` §15.2 对应。
> 工程实现：所有玩家可见文字集中在 `localization/zh_CN.json`（I18N 键），通用标签已去占位；剩余 45 个内容占位仍以 `[占位]` 开头；英文 `localization/en.json` 有 47 个 `[PLACEHOLDER]`（比中文多 `ui.controls` / `ui.controls_versus` 两条操作行，中文已定稿、英文待译）。替换时只改 JSON，不改代码。v0.21 起 PH-18 的 8 个符卡键（含关底 `spell_boss`）与新增的 `state.spell` 都已写入**显式占位条目**，不再依赖 `DuelHud._tr()` 回退为 `[占位] spell.spell_a.name`。**占位条目里的描述已按当前实际机制写好效果说明**（A：按 L 瞬发 45f 自动架刀，受刀自动完美弹开并反斩 10 伤，空放返还 10 心流；B：蓄力 8f 后自动出刀、20 伤害、无视架；C：蓄力 20f 后自动出刀、30 伤害、无视架并追加 12f 硬直；关底同 C 但蓄力 14f），替换正式文案时保留效果、只改名称与措辞，**不要**写成「下一刀 +N 伤害」。
>
> **v0.24**：本地化键从 131 增至 **147**（新增「关于」页 12 条 + `menu.about` + 设置页清档 3 条），**新增的都不是占位**——「关于」页文案按人类 `m00319` 给出的职责与东方二创规约强制声明落笔，署名「射命丸政」，措辞待人类最终确认。剩余占位数量不变（44 / 44）。
>
> **0.1.0（2026-10-21）**：键数 147 → **151**（主菜单二级化新增 `menu.mode_*` 5 条、`settings.about` 1 条；删除 `menu.versus`/`menu.about` 2 条）。**剩余占位仍为 44 / 44**，集合未变——人类 `m01536` 明确文案仍在开发期、保持占位等定稿；按实际数值改写的 10 条升级描述与 4 条符卡描述都**保留** `[占位]` / `[PLACEHOLDER]` 前缀。`special`：`spell.*.desc` 四条目前**没有任何显示路径**（`spell_card.gd` 的 `desc_key` 只赋值不读取），替换时注意。

| 编号 | 位置 / 模块 | 占位内容 | 数量 | 负责人 | 状态 |
|---|---|---|---|---|---|
| PH-01 | 标题 / 关于页 / README | 作品名 | 1 | 人类 | 待提供 |
| PH-02 | 选人 / 战斗 | 玩家角色名（3 位） | 3 | 人类 | 待提供 |
| PH-03 | 阶梯 / 战斗 | 对手名（5 位；通用代号或最终 IP 名单） | 5 | 人类 | 待提供 |
| PH-04 | 心得三选一 | 心得名 + 描述 | 10 | 人类 | 待提供 |
| PH-05 | HUD / 调试 | 状态 / 招式显示名 | ~6 | 人类 | 待提供 |
| PH-06 | 菜单 / HUD / 结算 | UI 文案（通用标签已去占位；剧情/提示类见 PH-07/PH-14） | ~20 | 人类 | 通用已做，待人类确认 |
| PH-07 | 首战 | 教程提示（I18N `tutorial.*` 已接入灰盒） | ~6 | 人类 | 待提供 |
| PH-08 | 战斗 / 结算 | 台词 / 开场 / 胜利 | ~6 | 人类 | 待提供 |
| PH-09 | 关于页 | 二创声明以外的说明文本 | 1 | 人类 | 待提供 |
| PH-10 | 宣发 | 封面 | 1 | 人类 | 待提供 |
| PH-11 | 战斗 / 环境 | 战斗音效 + 环境风声（CC0 第一版已接，待人类试听替换） | 16 + 1 | 人类试听 | 已接占位，待选型 |
| PH-12 | 选人 / 阶梯 / 结算 | 角色立绘 / 剪影 | 若干 | 人类 | 待提供 |
| PH-13 | README / 游戏内 credits | 第三方音频署名（仅 CC-BY 时需要） | 1 | 人类 | 待定 |
| PH-14 | 全局 | `localization/zh_CN.json` 剩余 `[占位]`（标题/标语、教程、心得、商店条目、符卡） | 45 | 人类 | 待提供 |
| PH-15 | 战斗 | 礼让结束「开始」提示（`ui.round_start`） | 1 | 人类 | 待提供 |
| PH-16 | 商店 / 选人 | 商店条目与角色名称/描述 | 11 | 人类 | 待提供 |
| PH-17 | 多语言 | `localization/en.json` 内容占位（通用 UI 已英文，其余 `[PLACEHOLDER]`；含 `ui.controls` 两条） | 47 | 人类 | 待翻译/改写 |
| PH-18 | HUD / 符卡（v0.17 起含关底） | 符卡名 + 描述（`spell.spell_a/b/c/boss.name`、`spell.spell_a/b/c/boss.desc`） | 8 | 人类 | 待提供；v0.21 起已有 `[占位] 符卡 A/B/C/关底` 文本，替换为正式文案即可 |
| PH-19 | 战斗 / 角色表现（2026-10-29 新增） | 测试 chibi Spine 骨架（`resources/spine/skeleton.spine-json` / `.atlas` / `.png` + 8 份 `resources/spine/<id>.tres`） | 8 角色共用 1 套 | 人类（美术） | 已接入，2026-11-04 换入**五动作版**（32 骨骼 / 33 槽位 / 10 IK / 1323×1537 / 26 regions）：`zhanli` 站立、`gongji` 攻击、`bei_gongji` 受击、`fangyu` 防御、`siwang` 战败；档案映射为 IDLE / COMMIT·SLASH·RECOVERY / HITSTUN / GUARD·GUARD_REC·CLASH / DOWN，倒地播 `siwang` 并保持可见；`SPELL` 已映射 `fangyu`（A 窗口内冻结末帧）、`CLASH` 借 `fangyu`；3.8 导出经提版（10 条 `constraints` + 38 段曲线转换），正式素材需 4.3 重导；**不是最终美术**，替换见 `docs/dev-example/spine-integration.md` §7；是否随作品分发取决于 §1 授权决策 |

- [ ] 全部占位已替换为人类内容（§7 清零）。

## 提交记录

| 项 | 内容 |
|----|------|
| 提交时间 | （待填） |
| 提交方式 / 通道 | （待填） |
| 凭证位置 | （待填） |
| 构建版本 / tag | （待填） |
| 提交人 | （待填） |
