# 变更记录（CHANGELOG）

本文件记录**已交付的变更**，按版本倒序。开发期的中间迭代号（`v0.20`–`v0.29`）只出现在 `docs/dev-example/design.md` 的历史行与阶段状态文档里，不再作为发布版本号使用；自本条起使用语义化版本。

格式：`版本 / 日期`，下分「修复」「机制」「文档」三组。每条给出**问题 → 修法 → 验证**，不写「优化了体验」这类无法核对的话。

---

## 未发布 — 2026-11-07（单人前四关敌方骨骼材质）

把人类提供的四张骨骼配色分配给单人阶梯第 1–4 关的敌人；第 5 关 BOSS 与本地双人继续用 P2 蓝色衣装。

### 机制
- **问题** 单人 5 关的敌人此前共用原色图集（`skeleton.atlas` / `skeleton.png`），关与关之间只有数值与 AI
  档位差异，战斗外观完全相同，看不出「一路打到关底」的推进感。
  → **修法** 新增 `resources/spine/skeleton_e1..e4.png` 与同名 `.atlas`（以 `skeleton_p2.atlas`
  为模板，仅页名分别改成 `skeleton_eN.png`，26 个 region 坐标不变；PNG 为人类素材原样复制，未改像素）。
  `DuelController.STAGE_ENEMY_ATLASES` 只登记前四关；`enemy_atlas_for_stage()` 越界（含 BOSS 关
  `stage_index == 4`）返回 `null`。`_start_stage()` 在绑定对局前调 `DuelView.set_seat_atlas()`，
  指定该关右侧席位的图集；`_start_versus()` 传 `null` 复位，双人仍是 P2。
  → **验证** `--import` 退出码 0，`.ctex`/`.spatlas` 产物齐全；GUT **314/314（1344 asserts，37 脚本，
  退出码 0）**，其中 `test_duel_view_spine.gd` 定向 **11/11（60 asserts）**。

### 表现
- **问题** 席位图集原先只按 P2 写死，缓存键只有档案 `instance_id`；若直接复用，换关时会让第 2 关仍显示
  第 1 关的克隆。
  → **修法** `DuelView` 增加 `set_seat_atlas(atlas)` 与 `_seat_atlas`，优先级为「按关覆盖 →
  `p2_atlas_file` → 约定 P2 路径」；克隆缓存键改为「档案 `instance_id` + 图集 `instance_id`」，
  并在已绑局时立即重挂。图集缺失 `push_warning` 后回退默认 P2 图集，不阻断开局。
  → **验证** 新增 3 例：四关映射与越界 `null`、按关覆盖只染 P2（P1 仍 `skeleton.atlas`）、换图集重建克隆；
  原有「双人 P2 用 `skeleton_p2.atlas`」用例保持通过。

### 构建
- **问题** 上一版产物 `build/windows/iai.exe`（119,893,104 B）不含四张新配色图集。
  → **修法** `--headless --export-release "Windows Desktop" build/windows/iai.exe`（单文件嵌入 PCK）。
  → **验证** `iai.exe` **121,225,120 B** + `libspine_godot.windows.template_release.x86_64.dll` 1,774,592 B；
  产物 `--headless --quit-after 300` 退出码 0，中英各 165 条；日志里 `user://logs` 写入与根证书两条
  ERROR 与 2026-11-06 的 `smoke2.log` 完全一致，属既有环境侧问题，与本次改动无关。

### 文档
- `docs/dev-example/spine-integration.md` §6.2（新）、§7 步骤 3、§8.1 计数；
  `docs/dev-example/development-log.md` §18；`README.md` 资源目录；本文件与
  `docs/gamejam/ai-disclosure.md`、`docs/gamejam/submission-checklist.md` M7.8。
- 美术 0% AI：四张 PNG 由人类提供；AI 只复制文件、改 atlas 页名文本与接线，未改像素，未新增玩家可见文案。

---

## 未发布 — 2026-11-06（提交前打包验证，20:00）

截止前一日打包：不改功能，只重导出、重打包、复测。

### 构建
- **问题** 19:22 打出的 `windows.zip` 早于 19:23 的图标提交，无法证明包内 exe 与 HEAD `ce7c1cf` 一致。
  → **修法** 从 HEAD 重新 `--export-release "Windows Desktop"`，再重打 zip。
  → **验证** `iai.exe` **119,893,104 B**（与旧产物尺寸一致，说明图标提交未改变构建结果）、dll 1,774,592 B；`windows.zip` **48,490,953 B**；干净目录 `%TEMP%/iai_final_check` 中 `--headless --quit-after 300` 退出码 0，中英各 165 条，ERROR 与 SCRIPT ERROR 均 0；GUT **311/311（1309 asserts，37 脚本，退出码 0，5.5s）**。

### 合规
- 「关于」页二创声明 `about.derivative` 在位；中英各 165 键，仅 `spell_a.desc` 一条无显示路径的占位。
- 记录见 `docs/gamejam/submission-checklist.md` §3 与 `docs/gamejam/ai-disclosure.md` §4。

---

## 未发布 — 2026-11-06（红染阴阳图标 / 窗口标题随本地化）

本轮把应用图标换成「红染阴阳」，并让窗口标题、导出 exe 的名称与版本资源跟随游戏标题。

### 图标：以 Yin_yang.svg 为底重制 icon.svg

- **问题** 原 `icon.svg` 是深蓝圆角底板 + 红蓝两条 X 线，与「剑术 · 心流 / 阴阳」的主题符号无关。
  → **修法** 保留原 128×128、`rx=16`、`#2c3e50` 底板（即原图标的背景不动），删掉两条 `stroke-width="16"` 的 X 线，改为 `translate(64 64)` 居中的阴阳：外圆 `r=39` 由黑改 `#8e3b3b`（低饱和砖红，比原 X 的 `#e74c3c` 明度/饱和度各压约一半），白色鱼身与两点取自人类提供的 `temp_assets/Yin_yang.svg`（未改形状、未缩放）。
  → **验证** `Image.load_svg_from_string(svg, 4.0)` 渲染 512px 预览 → `--headless --import` 后读回 128px 导入纹理 → 导出后从 exe 提取图标（ExtractAssociatedIcon），三处均确认红白阴阳 + 深蓝底板。

### 标题：窗口标题 / exe 元数据跟随 menu.title

- **问题** `config/name` 仍是工程名 `godot_dsh_test`，窗口标题、exe 的 ProductName / FileDescription 全是工程名，与游戏标题脱节。
  → **修法** ① `project.godot` `config/name` 改「刀剑 · 心流」；② `export_presets.cfg` 的 `product_name` / `file_description` 同步，开启 `application/modify_resources`（实测 Godot 4.7 内置写 PE 资源，无需 rcedit），版本资源 `0.1.0.0`；③ `GameBootstrap` 新增 `_apply_window_title()`，取 `I18NManager.get_text("menu.title")`（zh「刀剑 · 心流」/ en「Sword · Flow」），缺键回退 `application/config/name`，headless 跳过，并订阅 `LanguageChangedEvent` 随语言刷新；④ 因 `config/name` 会改变默认 `user://` 目录，设置 `use_custom_user_dir=true` + `custom_user_dir_name="iai"` 固定存档路径，并把旧档 `%APPDATA%/Godot/app_userdata/godot_dsh_test/meta_save.json`（含 `.bak`）复制到 `%APPDATA%/iai/`。
  → **验证** GUT **311/311（1309 asserts，37 脚本，退出码 0）**；`--import` 与 `--export-release` 退出码 0；`iai.exe` **119,893,104 B**，`windows.zip` **48,302,523 B**；产物 `--headless --quit-after 300` 退出码 0、中英各 165 条；exe 版本资源读出「刀剑 · 心流」/ 0.1.0.0。

### 坑：改完 icon.svg 必须重导入

- 现象：导入缓存未刷新时，运行中的窗口/任务栏仍显示旧图标，容易被误判为「颜色没改」。处置：改 SVG 后先 `--headless --import`（或编辑器重导入）再运行/导出；Windows 资源管理器另有 exe 图标缓存，覆盖同名 exe 后可能仍显示旧图。
- 细节与验证数据见 `docs/dev-example/icon-and-window-title.md`。

### 合规

- 图标为**素材拼接**（原底板 + 人类提供的 Yin_yang.svg，仅改填充色/平移），**不属于 AI 生成美术**；`ai-disclosure` 按「美术 0% AI」记录，新增来源行。
- 未新增玩家可见文案；标题复用既有 `menu.title` 定稿。

### 仍待人类处理

- 红色明度（`#8e3b3b`）与深蓝底板是否保留，可由人类一句话微调（改 `icon.svg` 后重导入 + 重导出即可）。
- Spine 运行时授权仍未解决，对外分发前须人类决定。

---

## 未发布 — 2026-11-06（44 条定稿文案回填 / 资源精简 / 发布构建）

本轮把人类定稿表里的 44 条玩家可见文案落进本地化文件，并把工程资源与大包体积压下来、产出可提交的 Windows 构建。

### 内容：44 条占位按定稿回填

- **问题** `localization/zh_CN.json` / `en.json` 中 44 条玩家可见文案仍是 `[占位]` / `[PLACEHOLDER]`；`tests/` 里 5 处断言以「必须以占位开头」为前提，直接替换会让测试变红。
  → **修法** 按 `docs/gamejam/44条本地化占位-定稿.md` 逐键精确替换（先命中 zh 36 / en 31，再补 en 5 条前缀差异项）；顺手去掉 en `ui.controls` / `ui.controls_versus` 的残留前缀。改写 5 处断言：`test_game_data.gd` 升级文案用例改名并断言「铁壁 / +3 / 屏息凝神，尚待剑发」，`test_i18n.gd` 断言 `Iron Wall` 与 9 个符卡键「非键名、非占位」，`test_duel_hud.gd` 奖励按钮改判 `1. 铁壁` 前缀。残心用例因定稿把 A 符卡命名为「残心」而与 HUD 符卡行 `残心 ×1 (30)` 撞车，改为**排除 `_p1_spell`/`_p2_spell` 后**再用 `残心\s*[×xX:：]?\s*\d` 判层数形态。
  → **验证** 两份 JSON 各 165 键、解析通过；GUT **311/311（1309 asserts，37 脚本，退出码 0）**。`tutorial.spell` 是唯一剩余占位条目（定稿表未提供该条）；同日收尾后其显示路径已删除（见下）。

### 构建：资源精简 + 换非 mono 模板 + 打包

- **问题** 旧 `build/windows/iai.exe` 129,180,864 B（pck ≈19.5 MB）；字体在 `assets/` 根与 `assets/fonts/` 各存 otf+ttf（合计约 29 MB）；粒子贴图 36 张里 29 张零引用；工程无 `.csproj` 却用 mono 模板导出，平白引入 .NET 运行时依赖。
  → **修法** ① python 静态审计全库 `res://` 引用（全部为静态 `preload`，无动态拼接）后，把 33 个零引用文件移入 `temp_assets/_unused_2026-11-06/`（不入库不导出），`assets/particles/` 只剩 `duel_fx.gd` 用到的 7 张；② 字体去重，只留 `assets/fonts/MiSans-Semibold.otf`（6,530,232 B）；③ 从官方 tpz 抽出 `windows_release_x86_64.exe`（109,268,480 B）临时顶替 mono 模板导出，导出后自动还原；④ `windows.zip` 用 deflate level 9 重打。
  → **验证** `iai.exe` **119,757,264 B**（pck ≈10.49 MB），`windows.zip` **48,226,367 B**（原 57,402,956 B）。关键结论：**Godot 4.7 Windows 模板本身约 109 MB**（mono 与非 mono 只差约 245 KB），减体积只能从 pck 下手，换模板换来的是「不依赖 .NET」。`--headless --import`、`--export-release` 退出码 0，无资源缺失；产物 `--headless --quit-after 300` 冒烟退出码 0，无 `SCRIPT ERROR`。

### 收尾：按人类指令清掉剩余占位痕迹

- **问题** 首轮回填后仍有玩家可见的占位痕迹：`tutorial.spell` 在开局 6 秒弹出；商店按钮写「困难模式：开/关」而商店条目叫「修罗模式」；角色下拉写「B · 快剑 / C · 重剑」而商店叫「快刀/重刀」；8 个 UI 脚本的 `_tr()` 在缺键时输出 `"[占位] " + key`。
  → **修法** ① `duel_hud._tutorial_text()` 删除 `tutorial.spell` 分支（底部操作行 `ui.controls` 已含「L 发动符卡」）；② `shop.hard_on/off` →「修罗模式：开/关」、「Asura Mode: ON/OFF」；③ `menu.char_b/c` →「B · 快刀 / C · 重刀」、「B · Swift Blade / C · Heavy Blade」；④ 8 处 `_tr()` 缺键改为 `push_warning` + 返回空串，`settings.gd` 空绑定显示 `—`；⑤ `spell_card.gd` 注释同步。
  → **验证** GUT **311/311（1309 asserts，37 脚本，退出码 0）**；重新导出 `iai.exe` **119,757,696 B**（pck 10,489,216 B）、`windows.zip` **48,226,724 B**；包内字节校验「修罗模式」「快刀」「重刀」各命中、旧「困难模式 / 快剑 / 重剑」0 次；干净目录 `%TEMP%/iai_clean3` 冒烟退出码 0，中英各 165 条。

### 仍待人类处理

- 人类复核 `spell_a.desc` 的 45 帧措辞（AI 按既有机制改写，见 `docs/dev-example/localization-final-copy-and-release-build.md` §3）。
- `tutorial.spell` 键保留在 JSON（无显示路径），定稿表补文案后可替换或删除。
- `spell.*.desc` 4 条无显示路径，按人类指令「先记着」保留。
- Spine 运行时授权未解决，但**已随构建分发**，对外发布前必须由人类决定（移除/购买/不公开）。

---

## 未发布 — 2026-11-05（工程文档：工作流开发经验）

本轮不改任何 `.gd` / `.tscn` 代码，只把项目积累的工作流经验整理成可复用的工程文档。

### 文档：工作流经验沉淀为 11 章文档

- **问题** 18 个会话、90 turn、6415 次工具调用积累的经验散落在 `docs/dev-contract.md`、`docs/dev-example/development-log.md`、`balance-pass-*.md` 与 CHANGELOG 里，没有任何一处回答「这个项目的工作流是什么、为什么这样、换一个项目怎么迁移」；新会话必须靠重读多个长文档重建上下文。
  → **修法** 新增 `docs/workflow-development-experience.md`（1059 行）：§0 阅读指南、§1 项目与角色、§2 工作流总览（七阶段 + 三个反馈闭环）、§3 十条核心经验 E01–E10、§4 分阶段操作手册、§5 案例库 C01–C20、§6 反模式 12 条、§7 可复用模板 7 份、§8 会话记录取数方法（zstd 多帧）、§9 度量体系、§10 迁移清单、§11 遗留与证据索引；并在 `docs/dev-example/development-log.md` §21 与 `docs/gamejam/ai-disclosure.md` §4 留痕。
  → **验证** 未改代码；GUT **311/311、1270 asserts、37 脚本、退出码 0**；`--headless --import` 退出码 0；`--quit-after 240` 无头冒烟退出码 0、stderr 无 ERROR（仅既有 WARNING）。

### 文档：会话复盘取数方法可复用

- **问题** 上一轮统计 18 个会话的工具分布用的是一次性脚本；Node 的 zstd 解压只解第一帧的坑也没有记录，换人做同一件事会重踩。
  → **修法** 文档 §8 给出按魔数 `28 B5 2F FD` 切帧逐帧解压的代码、事件结构表（user / assistant / tool-call / tool-result）与统计口径（会话数 / turn / 人类消息 / 工具调用）。
  → **验证** 本项目 2844 帧全部解压成功，约 2100 万字符；统计结果与 §1.4 的量化画像一致。

---

## 未发布 — 2026-11-05（角色选择抽离 / 可见 key 补全 / 双人输入方式与双方手柄）

本轮把「选角色」从主菜单拆到模式选择之后，并让本地双人各自选角色与输入方式（双方键鼠、一人键鼠一人手柄、双方手柄均可）；同时补齐设置页等界面漏掉的本地化 key。

### 机制：角色选择独立成面板，双人各自选人

- **问题** 主菜单用一行角色下拉框选人，双人开局时 `DuelController._start_versus()` 把同一个 `pending_character` 同时交给 P1/P2，双人只能镜像同角色；角色选择与「开始游戏」的流程也混在菜单里。
  → **修法** 新增 `scripts/ui/character_select.gd`（`CharacterSelectPanel`）与 `scenes/ui/character_select.tscn`，注册为 `PanelIds.character_select()`。流程改为：主菜单「开始游戏」→ 模式选择 → 角色选择 → 对局。单人只显示 P1 角色；双人显示 P1/P2 两行角色。确认时写入 `GameBootstrap.pending_character` / `pending_character_p2`；`DuelController._start_versus()` 用 `FighterData.for_character(pending_character_p2)` 生成 P2 数据，HP/初始心流取各自角色的值。
  → **验证** 新增 `tests/integration/test_character_select.gd`（单人只出 P1 角色、双人两角色两输入行、双方可同时选手柄、确认写回字段并发出信号，共 6 例）；`test_duel_versus` 增加「P1 选 char_a、P2 选 char_c 后 P2 HP=40」用例。

### 机制：双人键鼠 / 手柄自由组合，支持双方手柄

- **问题** 原逻辑按接入的手柄数量固定分配（P1 第一个手柄、P2 第二个手柄），玩家不能在选人时决定谁用手柄；未接入第二个手柄时 P2 只能用键盘，也无法预先选好手柄等中途接入。初版角色面板还加了「输入互斥」，直接否定双方手柄，与多手柄需求冲突。
  → **修法** 角色面板双人模式各给一个「输入方式」下拉（键鼠 / 手柄），默认双方键鼠；两方独立选择，**允许双方手柄**。`InputGuide.build_remap_config()` 增加 `versus / p1_gamepad / p2_gamepad` 参数：手柄方三个玩家动作只保留 `index 0` 的 `GUIDEInputJoyButton`（只有一方手柄时 `joy_index = 0`；双方手柄时 P1 = 0、P2 = 1），其余槽解绑；键鼠方按原键槽绑定 `KeyBindings.get_keys()`，鼠标只绑给键鼠方（P1 键鼠用原鼠标槽；P1 手柄时 P2 键鼠借用 P2 原手柄槽 `index 2` 绑鼠标）。`DuelController` 读 `pending_input_p1/p2` 决定 raw 手柄事件路由与 HUD 提示；`_resolve_gamepad_assignment()` 按「偏好 + 当前手柄数」计算实际席位，手柄不足时先回退键鼠。
  → **验证** `tests/unit/test_input_guide.gd` 覆盖 P1 键鼠/P2 手柄、P1 手柄/P2 键鼠、双方键鼠、**双方手柄（P1 joy 0 / P2 joy 1）**、单人、全局暂停，共 6 例；`test_duel_gamepad` 新增双方手柄 raw 分席、「松 P1 手柄不清 P2 架子」2 例，并在热插拔重建用例中断言旧的「按住架」会被复位；`test_duel_versus` 新增席位 resolver 与双人偏好保留 2 例；`test_duel_hud` 2 例断言操作提示会按手柄/键鼠切换键名。

### 机制：中途接入手柄默认归 P1

- **问题** 对局中接入新手柄时，原实现只重建 GUIDE 上下文，不改变双方输入方式；双方都用键鼠开局时，新手柄没有明确归属；双方手柄拔掉一只时也可能把剩下的手柄错绑给 P1。
  → **修法** `DuelController._on_joy_connection_changed()` 在双人模式且「双方都未选择手柄」时，把新接入的手柄分配给 P1、键鼠留给 P2，并写回 `GameBootstrap.pending_input_p1/p2`。若玩家已显式选择手柄（含双方手柄），保留偏好，按「偏好 + 当前手柄数」重新计算：第二只插入后自动补齐 P2；拔掉一只时若剩下的正是 P2 的设备则保留 P2 席位，不重组；无手柄时暂时回退双方键鼠，重新插入后恢复。单人模式保持键鼠 + 手柄并存的旧行为。
  → **验证** `test_duel_gamepad` 的 raw 分席、分设备松架、热插拔重建（含复位旧按压）用例通过；席位 resolver 的 0/1/2 手柄分支由 `test_duel_versus` 覆盖；热插拔路径尚无真实手柄实机复测（仅模拟事件）。

### 本地化：补全可见 key

- **问题** 设置页按 `KeyBindings.ACTION_ORDER` 生成 8 行动作，但 `settings.key_spell_p1` / `settings.key_spell_p2` 未定义，两行「使用符卡」直接显示原始 key；HUD 的 `state.unknown` 也缺；新增角色面板的标题/提示/选项同样没有文案。
  → **修法** 中英各补 13 个键：`menu.char_select_title`、`menu.char_select_hint_solo`、`menu.char_select_hint_versus`、`menu.p1_character`、`menu.p2_character`、`menu.p1_input`、`menu.p2_input`、`menu.input_keyboard`、`menu.input_gamepad`、`menu.start_duel`、`settings.key_spell_p1`、`settings.key_spell_p2`、`state.unknown`。两语言键集保持一致，现各 165 键。
  → **验证** `test_i18n` 新增用例检查上述 13 键中英均存在且不等于 key 本身；全量扫描 `_tr/get_text` 字面 key 无缺失（动态前缀 `state.`、`menu.%s`、`shop.item.%s.*` 除外）；新增可见文案均登记在 `ai-disclosure.md`，属功能性 UI 标签，待人类最终确认。

### 文档与验证

- 全量 GUT：**311/311、1270 asserts、37 脚本、退出码 0**；`--import` 退出码 0。
- 无头冒烟：`godot.exe --headless --path . --quit-after 240` 退出码 0，stderr 为空。
- 新建 `docs/dev-example/character-select-and-input.md`；同步 `README.md`、`docs/gamejam/ai-disclosure.md`、`docs/gamejam/submission-checklist.md`、`docs/dev-example/development-log.md` §20。双方手柄的输入槽位、席位回退与热插拔边界见该文档 §3/§4。

---

## 未发布 — 2026-11-04（防御特效白→金 / 发光叠加 / 看破预读弧）

试玩反馈指出两件事：起构/防御特效「一亮就是纯金」，看破（提前 6f 看到收束环）因此失去可读价值；光效只是半透明叠加，没有「发光」的观感。

### 表现：蓄力环恢复白→金渐变，看破多一段预读弧

- **问题** `duel_view.gd` 的 `_update_charge_fx()` 在 `imminent`（临刀 8f 内）把整环直接写成 `CHARGE_GOLD`，头顶进度点也直接变纯白——玩家只看到「一亮就是金」，无法从颜色判断还剩多久；看破给的 6f 提前量没有对应的视觉差异，等于白给。
  → **修法** 抽 `charge_color(progress, imminent, pulse)`：颜色按 `smoothstep(0.12,1.0,p)` 从近白 `#fffdf7` 过渡到亮金 `#ffc94a`，`imminent` 只做 `lerp(GOLD.lightened(0.18), 0.7)` 与 alpha 呼吸，不再硬切；圆点改为 `CHARGE_WHITE.lerp(CHARGE_GOLD, progress)`。`_commit_state()` 暴露 `lead`/`span`，`_draw_fighter()` 在 COMMIT 时于环外画一段冷白预读弧（长度 = `lead/span`、半径随进度外扩、24 段、alpha 0.55、线宽 2），只有带 `hint_lead` 的一方可见。
  → **验证** `test_charge_color_keeps_a_white_phase_before_gold` 锁「起手近白 → 中段仍偏白 → 末段转金」；截图 `duel-fx-charge.png`（左白右金）与 `duel-fx-read.png`（P2 环外冷白弧、P1 无）人工目视。

### 表现：粒子/切块改加法发光着色器

- **问题** 命中、对刀、架住、爆环、蓄力环原本用 `CanvasItemMaterial(blend_mode=ADD)`，只是「叠亮」，亮部没有白芯，整体仍像半透明贴图。
  → **修法** 新增 `resources/shaders/glow_add.gdshader`（`canvas_item` + `render_mode blend_add`）：以贴图 alpha 为掩码，`rgb = 源色 × 贴图色 × glow`，再按 `smoothstep(0.35,0.95,alpha) × core` 混入白色热芯，输出 alpha 乘 `alpha_gain`；`duel_fx.gd` 的 `_make_sprite()` / `_make_node()` 统一走 `_make_glow_material()`，删除原 `CanvasItemMaterial` 分支。
  → **验证** `test_block_burst_and_charge_use_glow_shader` 断言爆环/蓄力环材质是 `ShaderMaterial` 且 `shader == DuelFx.GLOW_SHADER`；截图 `duel-fx-preview.png` 可见命中白芯。

### 文档与验证

- 全量 GUT：**292/292、1123 asserts、35 脚本、退出码 0**；`--import` 退出码 0。
- 同步 `docs/particle-assets-plan.md` §6.6/§6.8、`docs/dev-example/design.md` §6.9、`development-log.md` §19、`ai-disclosure.md`、`submission-checklist.md` M7.7、`README.md`、新建 `playtest-07.md`。

---

## 未发布 — 2026-11-04（心流待机恢复）

按人类反馈反转上一轮「用进废退」的待机惩罚。结论：问题不在「待机恢复」本身，而在「3 秒后转惩罚」——它让心流在实战里只降不升，符卡从关键资源变成开局一次性资源。

### 机制：礼让结束后待机恢复，删除无输入惩罚

- **问题** 心流是符卡唯一资源，符卡成本 30–40；出刀 −4、中刀 −15、被架/空架 −8。旧实现只在前 180f 有操作时每 24f +1，超过后每 20f −1、下限 15；中局只要出过几刀、挨过一刀，就再也回不到符卡费用，玩家与关底 AI（`_try_spell` 只检查 `me.flow >= card.flow_cost`）都无法主动使用符卡（人类 `m01751`）。
  → **修法** `duel_sim.gd` 删除 `NO_INPUT_GRACE` / `NO_INPUT_PENALTY_INTERVAL` 与 `_passive_flow()` 的惩罚分支；改为 `frame >= opening_lock_frames` 且 `IDLE` 时每 `flow_regen_interval`（24f）+1，礼让期内不计、礼让结束后从 0 累计。`set_input()` 不再写 `last_input_frame`，`fighter_state.gd` 删除该字段。对手「构中待机每 20f +1、上限 +15」保持不变。
  → **验证** `test_opening_lock_grants_no_flow` 改为锁「礼让期不涨、结束后从零累计、不会反转成惩罚」；`test_no_input_penalty_after_grace` 改名 `test_idle_recovers_flow_without_penalty`，400f 后 56；`test_spell_cards.test_idle_recovery_makes_spell_available_again` 从 20 恢复到 40，能发 A 符卡，付 30 后受 `flow_floor` 夹到 15。定向 `duel_sim` 47/47、`spell_cards` 22/22。

### 文档与验证

- 全量 GUT：**290/290 passed、1115 asserts、35 脚本、退出码 0**。
- `docs/dev-example/design.md` 新增 D27、改写 §6.3/§6.6 与变更记录 v0.31；同步 `README.md`、`docs/gamejam/ai-disclosure.md`、`submission-checklist.md` M7.6、`development-log.md` §18。
- 旧「用进废退」的 CHANGELOG 与开发日志保留为历史记录；本轮是对该设计判断的明确反转，不删除旧条目。

---

## 未发布 — 2026-11-04（试玩反馈 01–03：残心隐藏 / L 键提示 / A 符卡重设计）

把第二轮试玩的三条反馈落地。三条都不改变按键与基本规则，只调「显示什么」「提示什么」「A 的符卡是什么」。

### 机制：A 符卡改「瞬发自动架刀 + 反斩」

- **问题** 旧 A「发动后 60f 内任意架必完美」必须先按架才生效，量化净收益仅 +5 心流差（0 伤害、开局净耗 25 心流、被砍中断还吃 12f 硬直），与 B/C 的自动出刀不在一个量级；试玩反馈「没有实际意义」。
  → **修法** `spell_card.gd` 新增 `auto_guard_frames = 45`、`counter_damage = 10`、`empty_refund_flow = 10`；A 改 `cast_frames = 0`、`amount = 0`。`duel_sim.gd`：按 L 当帧进入 45f `SPELL` 窗口并直接完成防御动画（Spine 冻结 `fangyu` 末帧）；窗口内受刀自动完美弹开并反斩 10 伤（穿防）；窗口内按斩 = 放弃保险自己出刀；45f 无人出刀返还 10 心流；关底 BOSS 穿防不穿透（只弹开不反斩），玩家 B/C 穿防仍可穿透；被穿防/主动出刀不返还。
  → **验证** `tests/unit/test_spell_cards.gd` 新增 6 例（瞬发姿态 / 自动弹开+反斩 / 到期返还 / 按斩取消 / BOSS 穿透例外 / 玩家穿防穿透）、改写 2 例；视图 2 例、HUD 1 例。

### 机制：残心退出 HUD（含结算页）

- **问题** 局内顶部常驻「残心 N」是未解释的持久计数器，新手不知道它是什么、也不影响按键，增加入门门槛。
  → **修法** `duel_hud.gd` 的 `_run_info` 去掉残心段；结算页也不显示残心（人类 `m00653` 明确「结算页也不应该保留」，`_result_detail` 整行未保留）。残心机制（心流保证/加成）不变，只改显示。
  → **验证** `tests/integration/test_duel_hud.gd` 新增 1 例：扫描 HUD 全部可见 Label，对局中与结算页都不含「残心」，且 `run.zanshin` 仍为 2（机制照常记数）。

### 机制：操作行与教程补 L 键

- **问题** 操作行只列斩/架/重开/暂停，玩家不知道符卡键存在；教程也没有符卡提示。
  → **修法** 操作行模板新增 `%s`/`%S`（P1/P2 符卡键），`zh_CN` 三条与 `controls_versus` 写入「L 发动符卡」与 P2「P 发动符卡」；开局 6 秒内符卡可用时教程提示 `tutorial.spell`。中文文案已定稿，英文同步 `[PLACEHOLDER]` 并登记待人类定稿。
  → **验证** `test_duel_hud.gd` 新增 1 例：`_controls.text` 含 `L` 与「发动符卡」、不含未替换的 `%s`。

### 表现：SPELL 映射与冻结末帧

- 8 份 `resources/spine/*.tres` 的 `animation_map` 补 `"SPELL": "fangyu"`（此前回退待机 `zhanli`）；`spine_fighter_view.gd` 在 A 窗口内把 `fangyu` 定位到末帧并 `time_scale = 0`，窗口结束恢复待机。新增 2 例视图测试。

### 文档

- `docs/dev-example/design.md` §6.11 / §9 数值表、`balance-pass-06-plan.md`（v4 + 落地记录）、`playtest-06.md`、`development-log.md`、`submission-checklist.md`（占位 45、PH-19 映射）、`README.md`（测试数）。

### 验证

- 全量 GUT：**289/289 passed、1111 asserts、35 脚本、退出码 0**；`--import` 退出码 0。
## 未发布 — 2026-11-04（P2 蓝色衣装图集）

把人类提供的 `skeleton_p2.png` 接成 P2 专属贴图：同一副骨架、同一套动作，按“席位”换图集，P1 不受影响。

### 机制：P2 按席位换图集

- **问题** P1/P2 共用 `resources/spine/skeleton.atlas`，本地双人又是同角色镜像，画面上两边同色，难以分清席位；只改 `char_b.tres` 会让 `char_b` 站 P1 时也变蓝。
  → **修法** 新增 `resources/spine/skeleton_p2.atlas`（以原 atlas 为模板，仅首行页名改为 `skeleton_p2.png`，26 个 region 坐标不变）和人类提供的 `skeleton_p2.png`（1323×1537，蓝色衣装）。`DuelView` 新增 `P2_ATLAS_PATH`、`p2_atlas_file` 覆盖与 `_profile_for_side()`：P2 首次绑定时克隆原档案、只替换 `atlas_file`，按原档案 `instance_id` 缓存；P1 仍用原档案。图集缺失/导入失败时回退原图集，不崩。
  → **验证** `tests/integration/test_duel_view_spine.gd` 新增 1 例：双方同选 `char_a` 时，P1 `skeleton.atlas`、P2 `skeleton_p2.atlas` 且不是同一资源，P2 贴图页为 `skeleton_p2.png`，动作映射与原档案一致；定向 8/8。
  → **截图** `docs/dev-example/rainy-night-preview.png` 重拍（1280×720）：P1 棕色、P2 蓝色，同骨架同动作。

### 验证与文档

- 全量 GUT：**280/280 passed、1077 asserts、35 脚本、退出码 0**；`--import` 退出码 0（新图集/贴图已导入），仅既有字体 UID duplicate 警告。
- `README.md` 同步 280/1077、P2 图集说明；`docs/dev-example/spine-integration.md` 增加 §6.1；`docs/dev-example/development-log.md` 追加 §15；`docs/gamejam/ai-disclosure.md`、`docs/gamejam/submission-checklist.md` 登记本轮。
- **美术 0% AI**：蓝色贴图由人类提供，AI 只复制文件、生成同坐标 atlas 文本并接线；未改像素、未重拓扑。

---

## 未发布 — 2026-11-04（刀光形变、主菜单雨夜、心流核查）

把斩击月牙从刀身上移开，并让它在挥砍中段做形变；主菜单接入同一套程序化雨夜；核对「长时间待机心流下跌」后确认是设计而非 BUG，只修正了过时注释。

### 机制：刀光外移与挥砍形变

- **问题** 旧月牙以 `SLASH_RADIUS=122` 贴在刀身/旧判定弧上，视觉上像刀身上长出一条白边；Sprite2D 只整体旋转/缩放，挥砍中段没有「甩出去」的形变。
  → **修法** `scripts/duel/duel_fx.gd` 把 `SLASH_RADIUS` 提到 **136**（月牙亮带离刀身约 14px，弧心不变），新增 `SLASH_ARC_STRETCH=0.13`、`SLASH_RADIAL_SQUASH=0.07`、`SLASH_SKEW=0.10`；`pose_slash()` 用 `whip=sin(p*PI)` 在中段把贴图切向拉长 13%、径向收薄 7%、轻微剪切 0.10，起手/收刀回原形。位置、旋转、alpha 与 `slash_sweep.gdshader` 的 `progress` 不变。
  → **验证** `tests/unit/test_duel_fx.gd` 新增 1 例：`SLASH_RADIUS>122`、p=0 正圆、p=0.5 横向更大/纵向更薄/skew>0、p=1 回正；定向 21/21、83 asserts。
  → **截图** `docs/dev-example/duel-fx-slash.png`（249,246 B）与 `duel-fx-sweep.png`（237,872 B），均 1280×720；月牙已离开刀身，四格扫掠形变正常。

### 机制：主菜单接入雨夜背景

- **问题** 主菜单仍是 `#0b0e13` 纯色底，与对局的雨夜断层；`menu.gd` 的 `_build_ui()` 会清空子节点，直接往场景树塞背景会被下一次重建抹掉。
  → **修法** `resources/shaders/rainy_night.gdshader` 新增 `pool_strength`（默认 1.0，地面湿反光乘它）；`scripts/ui/menu.gd` 新增 `BG_SCENE`、`MENU_GROUND_Y=0.96`、`MENU_POOL_STRENGTH=0.0`，在 `_build_ui()` 清空后先 `_build_background()`：实例化 `rainy_night.tscn`、`PRESET_FULL_RECT`、`show_behind_parent`、`z_index=-1`、鼠标穿透；**`material = material.duplicate()`** 后再写 `ground_y=0.96`、`pool_strength=0`，避免与 `DuelView` 共享材质互相污染；场景缺失时回退纯色。
  → **验证** `tests/integration/test_menu.gd` 新增 1 例：背景父节点/索引 0/1280×720/层级/鼠标穿透、shader 路径、`ground_y=0.96`、`pool_strength=0`；定向 4/4、24 asserts。
  → **截图** `docs/dev-example/theme-menu.png`（234,882 B，1280×720）已目视：雨线/暗角在菜单后，标题与四个入口清晰，焦点仍是底边金线；地平线压到底部提示下方。

### 核查：长时间待机心流下跌

- **问题** 人类观察到「长时间待机反而自然跌到低水平」，怀疑是 BUG。
  → **结论** 不是 BUG，是 `_passive_flow()` 的「用进废退」设计：IDLE 且最近 180 帧内有操作时每 24 帧 +1；超过 180 帧无输入后每 20 帧 -1，下限 15。起手 40/46/36，约 3 秒后到 47，再以 -3/秒跌到 15，总计约 13.7 秒。目的：防止龟缩等对手出刀成为最优解，让心流成为主动资源。依据见 `docs/dev-example/design.md` 与 `tests/unit/test_duel_sim.gd` 的 400 tick 断言。
  → **修法** 只把 `duel_sim.gd` 里过时的「每 30f -1（约 -2/秒）」注释改为「每 20f -1（-3/秒），扣到 flow_floor 为止；这是用进废退设计，不是自然恢复的反向 bug」；数值与行为未改。

### 验证与文档

- 全量 GUT：**279/279 passed、1068 asserts、35 脚本、退出码 0**；`--import` 退出码 0，仅既有字体 UID duplicate 警告。
- `README.md` 同步 279/1068、主菜单雨夜与刀光形变说明；`docs/particle-assets-plan.md` 记录 136 半径与 §6.7；`docs/dev-example/rainy-night-background.md` 增加主菜单接线与 `pool_strength`；`docs/dev-example/development-log.md` 追加 §14；`docs/gamejam/ai-disclosure.md`、`docs/gamejam/submission-checklist.md` 登记本轮。

---

## 未发布 — 2026-11-04（雨声环境音与无边框雨夜主题）

把对局环境音从旧风声换成人类提供的 CC0 雨声，并把浅色纸面主题重做为「墨蓝纸面 + 无边框 + 刀鞘金下划线」，
让菜单/设置/HUD 与程序化雨夜背景融合，同时保证 HUD 文字在雨线上仍可读。

### 机制：CC0 雨声替换风声

- **问题** 旧环境音是 `assets/audio/amb/amb_wind_loop.ogg`（OpenGameArt CC0 风声），与雨夜背景的听觉语义不一致；
  用户指定改用 `temp_assets/Ambiance_Rain_Calm_Loop_Stereo.wav`（CC0）。
  → **修法** 复制为 `assets/audio/amb/rain_calm_loop.wav`（2 声道 / 24-bit / 48 kHz / 30.0 s / 8,640,784 B），
  `DuelAudio` 预加载 WAV，运行时 `duplicate()` 后设 `LOOP_FORWARD`、`loop_begin=0`、
  `loop_end=int(round(get_length()*mix_rate))`；`start_ambient()` 走 `SoundManager.play_ambient_sound(_rain, 2.0)`
  （2 秒淡入）并把播放器 `volume_db` 压到 `-17.0`；停止走 `SoundManager.stop_ambient_sound(_rain, 0.3)`。
  旧 `_wind/_wind_player` 已移除，`amb_wind_loop.ogg` 无代码引用，保留在磁盘待人类决定是否删除。
  → **验证** `test_duel_audio.gd` 2 例 10 asserts：WAV 路径/循环模式/时长、启动后播放器 stream 与音量、
  且播放的是 duplicate 而非共享资源；GUT 在 headless 不启动环境音，无残留 playback。
  → **注意** 30 秒整段转 OGG 在本机以 exit 127 静默失败，已放弃转码、直接用 WAV；包体增加约 8.2 MB，
  循环接缝与整体音量仍待人类试听终混。

### 机制：无边框雨夜主题与 HUD 可读性

- **问题** 旧主题 `minimal_vector.tres` 是浅米色纸面 + 4px 黑边 + 圆角按钮，与雨夜背景冲突；
  第一版深色主题又用了圆角玻璃卡片、整圈金色焦点与阴影，偏「通用 AI 面板」。
  用户明确要求「减少 AI 风格，考虑主题和游戏类型，无边框设计」。
  → **修法** 新增生成器 `tools/build_rain_night_theme.gd`，产出 `assets/theme/rain_night.tres`；
  `project.godot` 的 `gui/theme/custom` 切到新主题。按钮正常态完全透明，只有 hover（钢色 7%）与
  pressed（淡金 13%）反馈；焦点改为底边 2px `#c8a063` 下划线，无圆角/无阴影；Label 用近白字 +
  `#02050a` 4px 描边；OptionButton/LineEdit 只留 1px 底边；ProgressBar 深轨 + 近白填充，HUD 仍按心流档位染色。
  `scripts/ui/ui_focus.gd` 同步改为只画底边 2px 金线，避免运行时把主题焦点覆盖回整圈圆角框。
  设置页 CheckButton 改为左对齐、`custom_minimum_size=(0,42)`、`SIZE_SHRINK_BEGIN`，
  主题 margin 左侧归零，使「静音/全屏」与「主音量」同基线。
  `DuelHud` 在 `HudRoot` 下新增顶部 190px / 底部 120px 两层 `GradientTexture2D` scrim
  （alpha 0.66 → 0，鼠标穿透，位于 `_reward_dim` 之前），只压 HUD 带、不挡中间角色。
  → **验证** 新增 `test_rain_night_theme.gd` 5 例 17 asserts（主题路径、按钮透明、焦点仅底边 2px、
  ProgressBar 亮填充、CheckButton 按下色）；`test_duel_hud.gd` 新增 scrim 1 例 18 asserts；
  全量 GUT **277/277（1050 asserts，35 脚本，退出码 0）**；三张 1280×720 截图
  `docs/dev-example/theme-menu.png`、`theme-settings.png`、`theme-duel-hud.png` 已目视：
  无边框、文字优先、HUD 雨线被压住、角色区仍通透。
  → **限制** UI 仍按 1280×720 写死，未在非开发机/不同宽高比验证；CheckButton 图标仍是 fallback 小圆点；
  `rain_night.tres` 由生成器覆盖，调色/边距应改生成器后重跑；对比度按纯色 sRGB 计算，半透明叠加态仍需目视。

### 文档

- 新增 `docs/dev-example/rain-night-theme.md`：设计取舍、调色与对比度、主题接线、HUD scrim、雨声循环与限制。
- README 同步测试数 277/277、35 脚本、1050 asserts、主题路径与雨声说明；
  新增 `docs/dev-example/rain-night-theme.md` 索引。
- `docs/gamejam/ai-disclosure.md` 追加本轮 AI 代码/文档披露；`docs/gamejam/submission-checklist.md` 增加 M7.2；
  `docs/audio-assets-plan.md`、`assets/audio/CREDITS.md` 登记雨声来源与旧风声退役；
  `docs/dev-example/development-log.md` 追加 §13。

---

## 未发布 — 2026-11-04（雨夜背景与战败表现）

把对局背景改为 shader 实时生成的雨夜，并去掉战败后叠在 Spine `siwang` 上的灰盒「倒地小人」。

### 修复：战败灰盒与 `siwang` 重叠 / 无 DOWN 映射时两边都不画

- **问题** 旧 `DuelView._draw_fighter()` 在 `State.DOWN` 分支无条件调用 `_draw_down()`（140×26 矩形 + 圆头），
  而此时 `SpineFighterView` 已把骨架隐藏；换成五动作后 `siwang` 本应保持可见，灰盒矩形反而叠在单膝跪地的
  人物上。更隐蔽的是：`_draws_graybox()` 最初只判断「Spine 是否激活」，当档案没有 `DOWN` 映射时
  骨架隐藏、灰盒也判 false，**战败后两边都不画**。
  → **修法** `DuelView` 的 DOWN 分支只在 `_draws_graybox(fighter)` 为真时画旧剪影；`_draws_graybox()` 改为
  「Spine 未接管 → true；已接管 → 看该视图是否有 DOWN 动画」。`SpineFighterView` 新增公开
  `has_animation_for_state(state)`，包装既有的 `_has_state_animation()`（显式映射 + 动画存在性检查）。
  → **验证** 新增 `test_missing_down_animation_falls_back_to_graybox()`：复制 `char_a.tres` 并 `erase("DOWN")`，
  断言骨架隐藏且 `_draws_graybox()==true`；背景/战败 4 例断言 `siwang` 可见且 `_draws_graybox()==false`。
  全量 GUT **269/269（1005 asserts，33 脚本，退出码 0）**；战败图 `docs/dev-example/rainy-night-defeat.png`
  可看到 P1 单膝跪地、刀落地，无矩形/圆头。

### 机制：程序化雨夜背景

- **问题** 旧背景只有 `#0b0e13` 纯色 + 一条地平线 + 21 根刻线，没有雨夜氛围；用户要求「看不清四周的雨夜」，
  并允许借鉴 `temp_assets/shader.txt`。
  → **修法** 新增 `resources/shaders/rainy_night.gdshader`（`canvas_item`）：夜空渐变 + 4 octave fbm 雨雾 +
  远/近两层雨 + 地平线水光 + 双人脚下湿反光 + 重暗角；新增 `scenes/duel/rainy_night.tscn`（1280×720
  `ColorRect`、`z_index=-1`、`show_behind_parent`、鼠标穿透、`ShaderMaterial`）。`DuelView._ready()`
  先 `_build_background()`，把 `ground_y=540/720`、`focus_left=430/1280`、`focus_right=850/1280` 写进材质；
  `_draw()` 只在背景为空时回退旧纯色/地平线。
  → **验证** `test_duel_view_background.gd` 4 例 23 asserts（层级/尺寸/鼠标穿透、shader 路径与三项 uniform、
  场景自包含、DOWN 播 `siwang` 且不画灰盒）；`--import` 退出码 0；预览
  `docs/dev-example/rainy-night-preview.png` 与 `rainy-night-defeat.png` 均 1280×720。
  → **注意** 首版把 `rain_layer` 的 `width` 当像素用（`step(remainder * amount, width)`），整格发亮，
  屏幕变成一根根粗竖条；改为「格内中心距 + `smoothstep`」后才成为细线（`width` 是格宽比例）。
  参考文件为 Brian Smith 的 MIT 示例，只借「x 分格 + y 方向 `fract` 下落 + 拖尾」思路，雾/暗角/地面反光/
  两层雨为独立实现；若后续直接复制其代码，需在仓库补 MIT 许可文本与署名。
  → **限制** 背景固定 1280×720、雨线为屏幕空间，无地面溅射/闪电/设置开关；改站位或分辨率要同步
  `_apply_background_focus()`；未做低端机性能剖析。

### 文档

- 新增 `docs/dev-example/rainy-night-background.md`（参数表、`rain_layer` 细节、接线与层级、战败三条路径、
  测试与限制）；同步 `README.md`（269/1005、程序化背景说明与文档链接）、`docs/dev-example/spine-integration.md`
  （测试数与 DOWN 回退说明）、`docs/gamejam/submission-checklist.md`（M7.1）、`docs/dev-example/development-log.md`
  （§12）、`docs/gamejam/ai-disclosure.md`。
- **美术 0% AI**：雨夜为自写 shader 实时生成，无外部背景贴图；两张预览是游戏内真实渲染，不是生成式美术；
  未新增任何玩家可见文案。

---

## 未发布 — 2026-11-04（Spine 五动作素材）

用美术新导出的 Spine 素材替换旧骨架，并把攻击/受击/防御/战败/站立五条动画接入战斗状态。判定层零改动。

### 素材更新：五动作版（32 骨骼 / 33 槽位 / 10 IK）

- **问题** 用户提供的新素材 `temp_assets/test_spine/` 为 `skeleton.json` 26454 B（仍 3.8.75）、`skeleton.atlas` 2685 B、`skeleton.png` 424741 B / **1323×1537**；动画从两段变为五段：`zhanli` 0.6667s、`gongji` 1.0000s、`bei_gongji` 1.3333s、`fangyu` 0.6667s、`siwang` 0.8333s。旧项目仍是 19 骨骼 / 28 槽位 / 5 IK / 1671×777 / 两段动画。
  → **修法** 旧三件套备份到 `temp_assets/_prev_spine_1104/`；覆盖 `resources/spine/skeleton.atlas` 与 `skeleton.png`（页名 `skeleton.png`、26 regions 与 JSON 附件名全部匹配，**未改文本或像素**）；用提版工具重新生成 `skeleton.spine-json`（65551 B）；`--import` 重建 `.spatlas`/`.spjson`/`.ctex`；8 份 `resources/spine/*.tres` 的 `animation_map` 统一改为 IDLE `zhanli`、COMMIT/SLASH/RECOVERY `gongji`、GUARD/GUARD_REC/CLASH `fangyu`、HITSTUN `bei_gongji`、DOWN `siwang`。
  → **验证** 数据层 32 骨骼 / 33 槽位 / 10 IK / 5 动画；`get_bounds()` = `Rect2(P(834.392,236.278), S(748.007,943.600))`，`fit_scale = 150 / 943.6001 ≈ 0.15897`；全量 GUT **264/264（977 asserts，32 脚本，退出码 0）**；五动作真实渲染预览见 `docs/dev-example/spine-animation-preview.png`。
  → **注意** 素材没有符卡与专门的对刀动画：`SPELL` 回退 `zhanli`，`CLASH` 借 `fangyu`；`siwang` 播完停末帧。正式资产仍应由美术用 Spine 4.3 重导。

### 修复：3.8 贝塞尔曲线在 4.3 下 signal 11

- **问题** 新骨架即使改到 4.3.00、迁移完 10 条 IK，`gongji`/`bei_gongji`/`fangyu`/`siwang` 一加载就崩溃（exit 139 / signal 11，栈顶 `set_atlas_res`；实际崩在 spine-cpp 解析动画），只有 `zhanli` 能加载。
  → **根因** 3.8 把曲线写成 `curve: <number>` + `c2/c3/c4`（归一化、四字段共用一条曲线），4.3 运行时却把 `curve` 当**每分量绝对控制点数组**读取；数字被当数组解引用。**末帧曲线会被忽略**，所以只有“曲线在非末帧”的动画崩，表现为“坏一部分”。本素材共 38 段 float 曲线 + 2 段 stepped。
  → **修法** 扩展 `tools/upgrade_legacy_spine_json.gd`：新增 `_convert_legacy_curves()` 及 bones/slots/IK/deform 分支，按 `cx = t1 + c1x*(t2-t1)`、`cy = v1 + c1y*(v2-v1)` 换算绝对控制点；rotate 4 个数、translate/scale/shear 每分量 4 个（共 8）、color 16 个、deform 固定 0…1 的 4 个数。
  → **验证** 工具输出「已转换 3.8 贝塞尔曲线：38 段」，退出码 0；探针 `load_from_file` 返回 0、`is_skeleton_data_loaded() == true`；五条动画均可加载并按轨推进。

### 机制：动作映射与重定时

- **问题** 旧逻辑把未映射状态回退 `IDLE`，且倒地直接隐藏骨架；攻击动画只压进 COMMIT 前摇，SLASH/RECOVERY 保持末帧，看起来像“刀没挥完”。
  → **修法** `SpineFighterProfile` 映射补齐五动作；`SpineFighterView` 在 DOWN 有显式映射且动画存在时播放 `siwang` 并保持可见，无映射才隐藏回退灰盒；COMMIT 的重定时窗口改为 `commit_total + slash_frames + whiff_recovery`，让 `gongji` 覆盖整刀；每次进入 COMMIT 从第 0 帧重播，构→斩→收招不重启。
  → **验证** 新增 5 动画名/时长、10 IK、GUARD/HITSTUN/CLASH/DOWN 映射、整刀窗口重定时、DOWN 可见用例；全量 GUT 264/264（977 asserts）。

### 文档

- 重写 `docs/dev-example/spine-integration.md`：三道硬门槛（版本 / 约束 / 曲线）、五动作表、当前 bounds 与 fit、映射与重定时、已知限制；同步 `README.md`、`docs/gamejam/submission-checklist.md`、`placeholder-inventory.md`、`ai-disclosure.md`。

---

## 未发布 — 2026-10-29

Spine 角色接入批次：用美术提供的 Spine 素材（JSON + atlas + PNG）替换两个灰盒占位角色，接入 spine-godot 4.3 GDExtension；表现层做成「有档案就接管、无档案/无扩展回退灰盒」的可插拔结构，判定层零改动。

### 修复：3.8 IK 约束被 4.3 静默丢弃（2026-10-31）

- **问题** 用户实机反馈「并没有看到 gongji 和 zhanli 动画被正确导入和播放」；探针显示 `track_time` 正常递增，但四肢始终接近 setup pose，`SpineSkeletonDataResource.get_ik_constraints().size() == 0`。
  → **根因** spine-godot 用 Spine C++ 4.3 的 `SkeletonJson::readSkeletonData()` 读骨架；4.3 只认顶层 `constraints` 数组（每项必须 `type:"ik"`），3.8 导出的顶层 `"ik"` 数组被**完全忽略**。只改 `skeleton.spine` 版本号只能骗过版本校验，5 条 IK 约束全部丢失：动画只平移不可见的 IK target，四肢骨骼没被驱动，所以看起来像“动画没播”。
  → **修法** 扩展 `tools/upgrade_legacy_spine_json.gd`：新增 `_convert_legacy_constraints()`，把 `ik`/`transform`/`path`/`physics` 旧数组迁到 `constraints`，缺 `type` 的按来源键补上；重新生成 `resources/spine/skeleton.spine-json`（输出「已迁移旧约束：5 条」）并 `--import`。
  → **验证** 数据层 `DATA IK COUNT=5`、`SKELETON IK COUNT=5`，5 条约束 `active=true mix=1.0`；gongji t=0→0.333s 的骨骼旋转实测变化（`zuoshou dabi` 2.088→2.651 rad、`youjiao2` 1.468→0.915、`zuoxiaotui` 1.672→2.400）；真实 `duel_view.tscn` 逐 process 帧截图 idle/commit 各 6/8 帧，四肢随 IK 移动。新增 GUT `test_skeleton_data_keeps_ik_constraints`，全量 **261/261（949 asserts，32 脚本，退出码 0）**。截图 `docs/dev-example/spine-takeover.png` 与 `spine-animation-preview.png` 已换为 IK 修复后版本。
  → **注意** 素材源动画仍只有 `bones.translate`：gongji 是 0.333s 的身体压低/前移 + 抬脚，**不是完整挥刀**；要真正的斩击动作，需美术补旋转关键帧或用 Spine 4.3 重导。正式资产不要再依赖提版工具。

### 素材更新（2026-10-30 18:56 版：头发 / 衣服 / 蝴蝶结）

- **问题** 美术重新导出的三件套为 `skeleton.json` 9233 B（仍 3.8.75）、`skeleton.atlas` 2267 B、`skeleton.png` 324062 B / **1671×777**；相比 10-29 版（8051 B / 2630 B / 215935 B / 1400×778）新增 `前发`/`后发`/`耳发`/`蝴蝶结`/`衣服`/`袖子右`/`袖子左边` 七个槽位，槽位总数 21 → 28、附件/region 24 → 22 且一一匹配。
  → **修法** 旧三件套备份到 `temp_assets/_prev_spine_1029/`；用 `tools/upgrade_legacy_spine_json.gd` 把新 JSON 提版为 4.3.00（18673 B）；直接复制新 atlas 与 PNG（本次页名已是 `skeleton.png`、region 无 `images/` 前缀，**未改任何文本/像素**）；`--import` 重新生成 `.spatlas`（2555 B）、`.spjson`（18673 B）、`.ctex`（250298 B）。
  → **验证** 加载 `VERSION=4.3.00`、19 骨骼 / 28 槽位、`zhanli` 1.3333s / `gongji` 0.3333s；`get_bounds()` = `Rect2(P(987.044,241.589), S(540.917,933.250))`，`fit_scale = 150 / 933.25 ≈ 0.16073`；真实 `duel_view.tscn` 截图确认两人都被新素材接管（新增头发/耳朵/蝴蝶结/衣服/袖子可见），P1 按攻击后状态进 COMMIT 且动画切到 `gongji`；GUT **256/256（931 asserts，退出码 0）**。
  → **注意** 档案 `.tres` 无需改动（仍指向同一骨架/图集）；`skeleton.spine-json` 仍是 3.8 数据体提版，正式资产应由 4.3 编辑器重导。

### 动画播放加固（2026-10-31）

- **问题** 档案已把 IDLE -> zhanli、COMMIT/SLASH/RECOVERY -> gongji 接上，但缺少「动画真的在播」的回归断言：待机是否推进、攻击是否按构窗口重定时、从收招直接再进构时会不会因为「同名动画不重启」而卡在末帧，都没有用例覆盖。
  -> **修法** SpineFighterView._play_state() 增加「进入 COMMIT 视为新一次攻击」的强制重播；其余相邻状态（构 -> 斩 -> 收招）继续共用 gongji，不重启；新增 playback_time_scale() 暴露当前倍率；补 4 例 GUT（待机推进、攻击重定时、构 -> 斩不重启、再次进构重播）。
  -> **验证** 240 帧探针里 zhanli 的 track_time 从 0.1535 -> 0.3536 持续递增；gongji 在 14f 构下倍率 1.4284（0.3333 / (14/60)）；全量 GUT **260/260（944 asserts，32 脚本，退出码 0）**；新增逐帧预览 docs/dev-example/spine-animation-preview.png（上排 zhanli、下排 gongji）。
  -> **注意** 当前只把攻击动画压进 COMMIT 前摇，SLASH/RECOVERY 阶段保持末帧；若美术要求攻击动作覆盖到斩击结束，需要调整重定时目标（档案加字段，不动判定层）。

### 素材更新（2026-10-29 04:16 版：gongji / zhanli）

- **问题** 美术重新导出的 `skeleton.json` 仍是 **3.8.75**；新图集 1400×778 的页名是 `images.png`，24 个 region 全部带 `images/` 前缀，而 JSON 附件名不带前缀，匹配数为 0。
  → **修法** 重跑 `tools/upgrade_legacy_spine_json.gd` 提版；atlas 首页行改为 `skeleton.png`（匹配实际文件名）；24 个 region 去掉 `images/` 前缀（**只改文本元数据，像素与拓扑未动**）；随后 `--import`。
  → **验证** 首次改完 atlas 未重导入，运行时仍读旧 `.spatlas`，第一帧直接 `CrashHandlerException: Program crashed with signal 11`（栈顶 `libspine_godot.windows.editor.x86_64.dll+fc02a`），无 region-not-found 文字；重导入后 1400×778 图集正常渲染，真实 `duel_view.tscn` 截图 + A/B 两帧确认 `gongji` 在播（脚部 IK 位移/头部朝向变化）、`zhanli` 在 IDLE 循环；GUT **256/256（931 asserts，退出码 0）**。
  → **教训** `.atlas` 由 `spine.atlas` 导入器缓存成 `.spatlas`，**改 atlas 文本后必须 `--import`**；region 名与附件名不匹配会在渲染阶段让 spine-cpp 段错误，而不是优雅报错。

### 修复

- **问题** 美术提供的 `skeleton.json` 是 Spine **3.8.75** 导出，4.3 运行时在 `update_skeleton_data()` 直接拒绝：`ERROR: Error message: Skeleton version 3.8.75 does not match runtime version 4.3`（`SpineSkeletonDataResource.cpp:307`），角色完全加载不出来。
  → **修法** 新增 `tools/upgrade_legacy_spine_json.gd`，只改写 `skeleton.spine` 字段为 `4.3.00` 后另存（数据体原样保留），产出 `resources/spine/skeleton.spine-json`；工具注释与文档均标明这是过渡手段，正式资产应由美术在 Spine 4.3 编辑器重导。
  → **验证** 加载成功（`is_skeleton_data_loaded()` 真、版本 `4.3.00`、19 骨骼 / 28 槽位 / 2 段动画全部可用），旧格式 atlas 也被 4.3 解析器接受；截图见 `docs/dev-example/spine-takeover.png`。
- **问题** 骨架文件若仍叫 `.json` 则**不会**生成 `.import`，扩展只认 `.spine-json`；改名后未重新导入还会出现 `get_animation_state() == null`，极易误判成「headless 不支持 Spine」。
  → **修法** 骨架统一用 `.spine-json` 扩展名，改名后强制 `--import`；文档把「改名 → 重导入」写成硬步骤。
  → **验证** headless 与窗口模式都能跑通动画（`track_time` 递增），GUT 集成用例在 headless 下通过。
- **问题** 灰盒视图每帧只读状态、没有可插拔的人物表现层，直接改 `_draw_fighter()` 会让灰盒回退路径丢失。
  → **修法** 新增 `SpineFighterView` 子节点叠加在灰盒之上，`_draw_fighter()` 仅在 Spine 激活时跳过「躯干/头/刀」，判定提示层（构的进度点、架窗弧、符卡光柱与双环、架势安全区环、血条、档位条）**照旧用 `draw_*` 画在人物之上**。
  → **验证** 无档案角色、无扩展环境均回退灰盒（`test_duel_view_spine.gd` 的 unknown character 用例），Spine 场景下判定提示未丢失（截图）。

### 机制

- **扩展装配** spine-godot 4.3（Godot 4.7.2 构建）装到 `addons/spine_godot/bin/`，只复制 Windows 三份 DLL（editor / template_debug / template_release，合计 6.2 MB）；`export_presets.cfg` 无需改动——导出时 Godot 自动把 `template_release` 库带成 `libspine_godot.windows.template_release.x86_64.dll`。
- **素材入库** 美术提供的 `temp_assets/test_spine/`（skeleton.json / skeleton.atlas / skeleton.png，2026-10-30 18:56 版为 1671×777）复制到 `resources/spine/`；`skeleton.spine-json` 由提版工具生成。旧 1653×381 与 1400×778 两版分别备份在 `temp_assets/_old_spine/`、`temp_assets/_prev_spine_1029/`（均 gitignored）。
- **可插拔档案** 新增 `SpineFighterProfile`（`class_name`，`Resource`）：`skeleton_file`/`atlas_file`/`animation_map`（键=`DuelTypes.state_name`）/`looping_animations`/`target_height`/`offset`/`flip_when_facing_left`/`sync_animation_to_state`/`hitstun_tint`；缺键回退 `IDLE`，`IDLE` 也缺则播放保持。约定路径 `res://resources/spine/<角色 id>.tres`（`SpineProfiles.resolve`），`DuelView.spine_profiles` 字典可显式覆盖。
- **8 份档案** `char_a`/`char_b`/`char_c` + 5 个对手，均指向同一副测试骨架：`IDLE→zhanli`、`COMMIT/SLASH/RECOVERY→gongji`，其余状态回退待机；对手复用玩家骨架是测试期替身，正式素材到位后只换 `.tres`，代码不动。
- **视图** `SpineFighterView` 用 `ClassDB.instantiate("SpineSprite")`（不硬引用扩展类型，未装扩展的机器也能解析脚本）；`SpineSkeletonDataResource` 按「骨架实例 id + 图集实例 id」静态缓存，两个角色共享一份；包围盒自动对位（中心 x=0、脚底 y=0）并按 `target_height / bounds.size.y` 缩放（2026-10-30 18:56 版素材 `150 / 933.25 ≈ 0.16073`）；朝左水平镜像；`DOWN` 隐藏骨架；缺动画 `push_warning` + 发 `animation_missing` 一次；暂停走 `SpineAnimationState.set_time_scale(0/1)`。
- **帧同步** 非循环动画按 `time_scale = 动画时长 / (状态帧数 / 60)` 重定时（`gongji` 0.333s 对 14f 构约 1.428×）；相邻状态映射到同一段动画时**不重启**（构 → 斩 → 收招共用 `gongji`），但每次进入 `COMMIT` 强制从第 0 帧重播。`zhanli` 循环、保持原生速度。
- **接线** `DuelView`：`_ready()` 先建两个 `SpineFighterView`（在 `_fx` 之下）、`bind()` → `_bind_spine()`（允许先 bind 再入树，供 headless 截图链路）、`_process()` → `_update_spine()`（P1 不镜像、P2 镜像）、`set_paused()` 透传。
  → **验证** GUT **256/256（931 asserts，退出码 0）**：`test_spine_fighter_profile.gd` 10 例、`test_spine_fighter_view.gd` 11 例、`test_duel_view_spine.gd` 6 例（含先 bind 后入树、未知角色回退、显式字典覆盖、暂停透传、换局不重复挂节点）。
  → **验证** 截图 `docs/dev-example/spine-takeover.png`（1280×720，真实 `duel_view.tscn`，2026-10-30 18:56 素材版）：两人脚踩 `GROUND_Y=540`，P1 处于构（暖金蓄力环 + 进度点），灰盒躯干/头/刀消失，新增头发/衣服/蝴蝶结正常显示。
  → **验证** Windows 导出退出码 0（2026-10-30 18:56 素材版复验），产物 `iai.exe` 127,489,544 B + `libspine_godot.windows.template_release.x86_64.dll` 1,774,592 B；导出 EXE headless 冒烟 120 帧退出码 0。

### 文档

- 新增 `docs/dev-example/spine-integration.md`（11 节）：扩展装配 / 导入管线与四条实测坑 / 3.8→4.3 版本硬门槛与提版命令 / 素材实测数据 / 档案字段与回退规则 / 视图生命周期 / 帧同步公式 / `DuelView` 接线 / 回退表 / 动画映射 / 美术替换 6 步 / 验证与命令速查。
- `CHANGELOG.md`、`README.md`（测试计数、环境表、目录、扩展点、已知限制）、`docs/gamejam/ai-disclosure.md`（§4 一行、§6 第三方表）、`docs/gamejam/submission-checklist.md`（Spine 授权确认项与测试 chibi 占位登记）同步更新。
- 本次 **美术仍为 0% AI**：Spine 素材（骨架、图集、贴图）由美术提供，AI 未生成、未改像素，只写了代码与文档；`skeleton.spine-json` 仅是版本号提版的派生文件，像素与拓扑未动。

### 已知未修

- **Spine 运行时授权**：spine-godot 采用 Spine Runtimes License，使用需持有对应 Spine 授权；团队已明确无预算购买。当前接入属**内部测试**，公开仓库分发 `addons/spine_godot/` 与对外分发构建的合规性**必须由人类拍板**（详见 `docs/dev-example/spine-integration.md` §10）。
- 素材只有两段动画（`zhanli`/`gongji`）且只有 bones 轨道：受击 / 架防 / 倒地 / 符卡全部回退待机，`DOWN` 直接隐藏骨架，没有倒地动画。
- 未使用挂点（`SpineSlotNode`/`SpineBoneNode`），刀光与命中点仍按灰盒几何位置算；多页图集、法线贴图、皮肤切换未验证。
- 3.8 提版工具会改版本字符串并迁移旧约束结构（`ik`/`transform`/`path`/`physics` → `constraints`），但不保证 3.8 全部特性在 4.3 下语义一致；正式资产必须由 Spine 4.3 编辑器重新导出。
- SpineSprite 释放时每实例留下 21 个扩展内部对象（GUT 报 orphan，扩展自身行为，非本项目泄漏；未开 `-gfail_on_orphans`）。

---

## 未发布 — 2026-10-23

素材入库、粒子接线与刀光/符卡爆环批次：把第三方粒子素材包筛成可用的 36 张贴图，接入命中 / 对刀 / 架防三类战斗事件，再用 `twirl_03` 与 `circle_02` 替换自绘的挥砍弧与符卡爆环，同时把临时素材暂存区从 Godot 的扫描范围与版本控制里摘出去。

### 修复

- **问题** 临时素材包放在工程内会被 Godot 全量扫描导入：`temp_assets/` 有 195 个文件 / 15.2 MB，其中 160 张 512×512 PNG 会被逐个生成 `.ctex`，拖慢首次导入、污染 `.godot/imported`，还会让该目录出现在 FileSystem 面板与导出候选里。
  → **修法** 新增 `temp_assets/.gdignore`（Godot 见到该文件即整目录跳过，不导入、列不出、不导出）；`.gitignore` 追加 `/temp_assets/` 并写明用途。
  → **验证** 重新导入后 `temp_assets/` 内 `*.import` / `*.uid` 均为 0；80 张里**未被选中的 25 个代表文件**（`flame_01`、`muzzle_01`、`window_01`、`symbol_01`、`scratch_01`、`smoke_01`、`dirt_02`、`circle_01`、`star_01`、`spark_03`、`scorch_02`、`trace_01`、`magic_04` 等）在 `.godot/imported/` 中查无对应 `.ctex`，即该目录确实从未被扫描。

### 机制

- **素材入库** 从 Kenney Particle Pack 1.1（CC0 1.0）的 `PNG (Transparent)` 80 张里挑 36 张，按用途放 `assets/particles/{slash,impact,guard,spell,dust,glow}/`（7/10/3/6/7/3）。文件名保留 Kenney 原名、像素未改（纯白 + alpha），运行时用现有调色板上色：`COLOR_P1/P2`、`COLOR_FLOW_LOW/MID/HIGH`、`COLOR_SPELL_P1/P2`——**不为粒子新增颜色**。
  → **验证** 36 张 `.png.import` 与对应 `.ctex` 全部生成；`assets/particles/CREDITS.md` 记录来源包、许可原文要点、未取用子集（黑底版 / Rotated / Unity samples）。
- **粒子接线（第一批）** 新增 `scripts/duel/duel_fx.gd` + `scenes/duel/duel_fx.tscn`：`GPUParticles2D` one-shot 固定池（4 类 × 3 个，只 `restart()` 复用，不在战斗帧新建节点），`DuelView` 在 `_ready()` 装配、在 `hit_landed` / `clash_happened` / `attack_blocked` 三处点火。染色走人类拍板的「攻击方制」：命中=出刀方色、架住=防守方色、对刀=暖白 `#fff3c4`、完美格挡=心流青 `#9ff0d0`（全部取自 `duel_view.gd` 既有调色板）。尺寸按设计像素：命中 110 / 对刀 140 / 架住 170 / 完美 220（对刀与架住按首轮截图从 190/150 收回，避免叠加成一团白）。36 张 `.png.import` 全部开 mipmaps，节点配 `Linear Mipmap` 过滤以消除缩小闪烁；暂停时 `speed_scale = 0` 冻结、`bind()` 换局 `clear_all()`、预留 0–1 强度接口；全屏暖闪 alpha 0.55 → 0.28 降为辅助。
  → **验证** GUT **212/212（811 asserts，退出码 0）**，新增 `tests/unit/test_duel_fx.gd`（10 例）与 `tests/integration/test_duel_view_fx.gd`（7 例：信号→贴图、换局清空、暂停透传）；`tools/capture_fx_preview.gd` 出图 `docs/dev-example/duel-fx-preview.png`（1280×720，四类特效并排）；headless 240 帧冒烟无错误。
- **刀光与符卡爆环（第二批）** `duel_view.gd` 里 `draw_arc(122, ±51.5°)` 的白色挥砍弧换成 `slash/twirl_03` 贴图，`_draw_spell_burst()` 的两道自绘扩散环换成 `guard/circle_02` 紫色 `#b79bff`。
  → **问题** 贴图不是可缩放的整环：`twirl_03` 的亮带在半径 175–231 / 512、张角 -80°…+28°（中心 -26°），直接 `Sprite2D` 摆上去既对不上 122 半径，也朝错方向。
  → **修法** 用实测量化对位——缩放 `122/203 ≈ 0.60` 让亮带压在旧弧上，旋转 `+26°`（P2 再 +180°）把带中心转到出刀方向，弧心复用 `_draw_fighter()` 的 lean/crouch；挥砍是持续 4–6 帧的连续态，因此每帧调 `pose_slash()` 摆位而不是发一次性粒子，旋转随进度前扫 17°、alpha 按 `0.85×(1-p²×0.85)` 淡出。符卡环按 `circle_02` 外缘 172 / 512 缩放，内外两枚由 36 推到 366、0.62s、ease-out，被打断乘 0.6。
  → **验证** GUT **224/224（847 asserts，退出码 0）**（`test_duel_fx.gd` 18 例、`test_duel_view_fx.gd` 11 例，含刀光朝向/缩放/淡出与紫环扩张/寿命）；新截图 `docs/dev-example/duel-fx-slash.png`；`duel_sim.gd` / `fighter_data.gd` 零改动，判定层不受影响；headless 240 帧冒烟无错误。
- **第三批（人类三点反馈）** ① 符卡爆环看起来像 `circle_03`——核实贴图确实是 `circle_02`（MD5 与源包一致），真因是**内外两枚 0.72 倍叠加**被读成厚环，改为**单枚**；② 刀光要「扇形随挥刀方向消失」——新增 `resources/shaders/slash_sweep.gdshader`，刀锋角 `head` 由 -83° 扫到 +29°，扫过的角度在片元里抹掉，`modulate.a = 0.9×(1-0.35p²)` 只管整体衰减；③ 攻击前摇要有圆形特效件，且是**替换**自绘收束弧而不是叠加——`_draw_fighter()` 里两道 `draw_arc` 整段删除，改由 `DuelFx.pose_charge()` 摆一枚 `spell/light_03`（`CHARGE_TEX_RADIUS = 208`），半径 20 → 132 由小长大、`#fffdf7` → `#ffc94a` 由白转亮金、alpha 0.32 → 0.82，圆心取 `_draw_aura()` 的 `(x, GROUND_Y - 90)` 与心流圆环同心（不吃 COMMIT 前倾/下蹲）；临刀只让金色 alpha 呼吸，不掺白（掺白会洗成米色）。
  → **问题** 初版 shader 的 `tail_span` 取 1.35 rad（77°），比月牙总张角 108° 还宽 ⇒ 永不塌陷，肉眼只见整体变淡；蓄力环初版用「收紧」与去饱和的金，观感偏暗且与心流环不同心（圆心偏 14px、低 16px）。
  → **验证** GUT **229/229（871 asserts，退出码 0）**（新增刀光 shader 进度/前扫断言、单枚爆环 ≠ null、蓄力环同心且随进度变大变亮）；四格连拍 `docs/dev-example/duel-fx-sweep.png` 证明 0% 全弧 → 35% 上端消失 → 70% 半截 → 100% 收尾；新增 `docs/dev-example/duel-fx-charge.png`；headless 240 帧冒烟无错误。

### 文档

- 新增 `docs/particle-assets-plan.md`：边界（AI 不生成美术）、目录约定、贴图规格、**游戏事件 → 贴图对照表**（出刀/连斩/命中/对刀/被架/完美格挡/空架/符卡蓄力/发动/打断/落地/收刀/心流氛围）、导入设置建议、接入方案、44 张未选贴图的理由。
- `docs/particle-assets-plan.md` §6 改写为「已接入（第一、二批）」+ §6.5「刀光与符卡爆环」记录对位数学（半径/朝向/弧心三列）与取舍，§5 尺寸表标注定稿值，§8 补 8.1/8.2 两轮验证；`docs/dev-example/development-log.md` 新增 §9（粒子接线）与 §10（刀光/爆环）记录口径与踩坑；新增 `docs/dev-example/duel-fx-preview.png` 与 `duel-fx-slash.png` 两张验收截图（非游戏资源）。
- `AGENTS.md` §4 补 `assets/particles/` 与 `temp_assets/` 两条约定；`assets/particles/CREDITS.md` 新增；`docs/gamejam/ai-disclosure.md` §4 追加一行、§6 补素材来源行；`docs/gamejam/submission-checklist.md` 补粒子贴图许可勾选项。
- 本次 **美术仍为 0% AI**：贴图是第三方 CC0 素材，AI 只做筛选、复制归档与写文档，未绘制、未改像素。

### 已知未修

- 战斗事件已接：命中 / 对刀 / 架防三类粒子，外加挥砍刀光（`twirl_03` + `slash_sweep.gdshader`）、符卡爆环（单枚 `circle_02` 紫）、起构蓄力环（`light_03`，已替掉自绘收束弧）；**未接**：符卡蓄力法阵与光柱、落地扬尘、空架、收刀、心流氛围，贴图已备在 `assets/particles/` 对应子目录，映射见 `docs/particle-assets-plan.md` §5。
- 判定类提示中，**预警收束弧已由蓄力环接管**；架窗环、血条仍走 `draw_*`，**不交给粒子**：人手要读的是几何形状，不是光效。连斩第 2 段起换 `twirl_01/02` 也未做。
- `DuelFx.set_strength()` 只有接口，尚未进设置页（0 = 完全关闭）。
- 贴图的 mipmaps 已开启并配对 `Linear Mipmap` 过滤；若后续在低分辨率窗口下仍见闪烁，优先怀疑 `ParticleProcessMaterial` 的 scale 曲线而不是导入设置。

---

## 0.1.0 — 2026-10-21

首个语义化版本。判定依据：基本操作可确定（键鼠 + 手柄、暂停/恢复、改键、存档/清档全链路）且难度经人工简测通过。此前全部代码在这一天经历了**一次全量审计 + 六批修复**，下面按批次记录。

### 批次一：全量代码审计（只读，`docs/audit/code-audit-2026-10-21.md`）

四路并行审计（判定/表现层、核心/存档/输入/音频、UI 层、测试层），产出 1 条 P0、9 条 P1、22 条 P2、30+ 条 P3，每条都带 `file:line` 与证据三级标注（实测 / 静态精读 / 推断）。审计结论中**没有**发现崩溃路径、导出缺资源、判定层逻辑错误、插件源码被改。

### 批次二：P0 + 存档可靠性 + 种子 + AI 性格（`a9fcb5c`）

- **修复（P0）音量滑条完全无效**：`settings.gd` 把 I18N 键 `settings.master` 当作设置键传入，显示与存储一职两用，而 `apply_settings()` 读的是 `volume_master`。→ 拆成 `label_key` / `setting_key` 两个参数，三个滑条分别写 `volume_master`/`volume_sfx`/`volume_ambient`；`_load_values()` 改用 `set_value_no_signal`，避免打开设置页触发 5 次 `apply_settings()` + 5 次落盘。
- **修复（P1）存档三条同源缺陷**：`FileAccess.WRITE` 截断写无备份；损坏档回落默认值后下次 `save()` 直接覆盖原档；`version` 因等于默认值被 `MapCodec` 裁剪，文件里从来没有版本号。→ 改为三步原子写（`.tmp` → 旧档转 `.bak` → 转正，失败回滚）；坏档改名 `.corrupt` 隔离；`version` 改为默认 `0` 并在 `_from_dict` 记录来源版本，`_migrate()` 按来源版本补缺键；新增 `MetaSave.wipe()`。
- **机制** 种子随机化：`duel_controller` 原来写死 `12345`，导致每局三选一/AI 序列完全相同。→ 新增 `_new_seed()`（`randi_range(1, 2147483646)`，避开 0 哨兵）与 `_stage_seed(stage_index)`（线性同余，保证同局内各关可复现）。
- **机制** AI 性格正式生效：`ai_profile.gd` 的 `_BASE["counter"]` 五个值从未被读取（两分支都硬编码 `counter_chance = 1.0`），`flow_speeds_commit` 也是死字段。→ 删死字段；新增 `counter_delay_frames = maxi(6, roundi((1.0 - counter) * 14.0))`（6–8 帧，认招快慢的差异），`_try_counter` 用它做迟滞。
- **机制**「关于」页：新建 `scenes/ui/about.tscn` + `scripts/ui/about_panel.gd`，含东方 Project 二创声明、与官方无关联声明、AI 使用说明、素材来源、版本号；主菜单入口。
- **机制** 人工清档：设置页「清除存档」二次确认（3 秒内按两次），删 `.json`/`.tmp`/`.bak`/`.corrupt` 四类。
- **文档** `docs/dev-contract.md` §3.1 登记 5 项插件豁免（AudioServer Master/mute、`InputMap` 的 `ui_*` 手柄补充、`GUIDE._input_state`、`GUIDERemappingConfig._bind/_unbind`、`Input.get_connected_joypads()` 只读），并附 SoundManager 上游 v2.6.2 仍无 master/mute 的证据。
- **验证** GUT 185/185（723 asserts）、headless 冒烟 240 帧无错误、本地化 147 键中英一致。

### 批次三：架防按住不生效 + 主菜单二级化（`2b15e04`）

- **修复** 「按住防御仍挨打」：`_apply_pending_input` 只把「按下那一帧的上升沿」交给 `_apply_action`，`_guard_held` 从不参与起架，所以礼让期内按住、硬直中按住、架满自动收架后仍按住，三种情况都永不生效。→ 在 `action == NONE` 分支补「仍按住且 `IDLE` → 补发 GUARD」。**只补 `IDLE` 是刻意的**：`COMMIT` 中按防是「取消出刀转架」，必须一次明确的新按下，否则按住防御就永远出不了刀。
- **机制** 主菜单二级化：一级入口 6 → 4（开始游戏 / 商店 / 设置 / 退出），「单人阶梯」「本地双人」收进「开始游戏」的 `mode_select` 面板；「关于」移到设置页。解决 6 个按钮在 720p 下重叠。
- **文档** 新建 `docs/dev-example/balance-pass-05.md`（架防根因链、未采用的三种做法、验证与遗留）。
- **验证** GUT 190/190（731 asserts）、冒烟 151 键 × 2 语言。

### 批次四：空架手感与难度单一真相（`2a7e205`、`8c30dd5`）

- **机制** 空架收势 8/7/9f → **2/1/4f**（均衡/快剑/重剑）：架窗按满却没挡到，仍扣 8 心流、断完美连击，但不再「罚站」到被对手确定惩罚。人类原话（`m01110`）：「可以缩短到 1 到 2 帧，重剑最多 4 帧。然后扣除心流……至少架防过期可以让人无感切换，但总有操作空间，也便于区分角色。」
- **修复** `GameBootstrap.hard_mode` 缓存副本与 `meta.settings` 脱钩，测试替换 `GameBootstrap.meta` 后第 2 关敌人血量被错算成 40。→ 删除缓存字段，改为只从 `meta.settings["hard_mode"]` 读一处真相。
- **修复** AI 反斩骰子被白白消费：`_counter_will = false` 在 `press(ATTACK)` 之前无条件执行，自身还在硬直时按键被丢弃且进入冷却。→ 改为「真正起构才消费」。
- **文档** 更正 `docs/gamejam/ai-disclosure.md` 早期「只架不攻必赢」的结论：`_check_end()` 只看 HP、格挡不造成伤害，该说法在代码上不成立；`balance-pass-05.md` §7 记录。
- **验证** GUT 191/191（736 asserts）。

### 批次五：文案占位与描述对齐（`e1fc420` 前半）

- **修复** 7 条升级描述与实际不符：u03 是绝对值 18（基础 12，描述没写）；u05「看破」描述为看对手，实际 `hint_lead` 只提前**自己**的收束环；u06 漏写「消耗 30 心流」；u07 描述 +1 伤害实际 **+10**；u08 描述 2 秒实际 **5 秒**；u09 描述「开场 3 秒」实际第 180–479 帧；u10 描述「+2 生命」实际**回复量翻倍**。→ 按实际数值重写 10 条描述（中英），保留 `[占位]` / `[PLACEHOLDER]` 前缀（人类 `m01536`：文案仍在开发期，保持占位等人类定稿）。
- **修复** u03 的 `perfect_gain` 会同时作用于双方（P2 完美格挡也吃 18）。→ `_do_block` 只对 P1 读 `mods`，P2 恒用基础值 12。
- **修复** u05 对对手无效，名实不符。→ `duel_view` 的 `hint_lead` 改为**对 P2 的收束环也提前**，玩家能更早看到对手出刀。
- **调整** 难度回落：`SLASH_WARN_FRAMES` 8 → 16；玩家架窗 20/18/22 → 24/22/26；空挥收招 20/16/24 → 14/12/18；被架收招 32/24/36 → 28/22/32；`cancel_cost` 5 → 10；AI `guard_chance` 下调到 0.18/0.15/0.24/0.24/0.28。
- **验证** GUT 192/192（738 asserts）。

### 批次六：难度量化 + 收招取消（`6f36b27`）

- **工具** 新增 `tools/sim_balance.gd`（5 关 × 60 局自动对战，输出胜率 + 反应延迟曲线 + 架刀率消融）与 `tools/sim_trace.gd`（单局逐帧日志，定位「按了没反应」）。这是把「我觉得难」变成可复现数字的关键一步。
- **发现** 三个结构性根因：① 出刀总硬直（前摇 + 5f 判定 + 收招 20f）里攻击/防御输入被**静默丢弃且无缓冲**，玩家体感「按了没反应」；② AI 前摇 28–30f 几乎等于玩家「看到起手才反应」的最快反应时间（18–30f），`SLASH_WARN_FRAMES` 是唯一公平预警；③ AI 架刀吃满（`guard_chance` 0.45 + 「看到出刀再架」的对策），架住即白送一刀。
- **机制** 收招取消：`RECOVERY` 第 2 帧起按防可转架，代价 10 心流 + 架窗减半（`_guard_held` 也扩展到 `RECOVERY` 以支持按住）。把「出刀 = 必被惩罚」改成「出刀 = 可买保险」。
- **验证** 模拟器在延迟 4–12 帧全 100%（旧参数在延迟 10 帧只有 13%）；GUT 195/195（746 asserts）、冒烟 151 键 × 2 语言。
- **遗留** 模拟器假设玩家永不主动进攻，偏保守；「延迟 4–12f 全 100% 是否偏松」「早按空架 -8 心流是否可学」待人类试玩。

### 文档与工程

- 新建 `CHANGELOG.md`（本文件）；`README.md` 状态节重写（版本、测试数、目录结构、存档机制、已知限制、合规入口）。
- `docs/dev-contract.md` 追加第二至第七轮记录；`docs/gamejam/ai-disclosure.md` 逐轮追加披露行。
- `AGENTS.md` 修正两处过期：§5 删掉未随仓库保留的 `docs/dev-example/README.md`、`docs/agent-prompts/`、`feature-brief-example.md` 引用，改为指向 `CHANGELOG.md` / `balance-pass-*.md` / `development-log.md`；§7 的「外部程序执行受限、需审批」改为实测可直接执行（2026-10-21 复核）。
- 版本号统一为 `0.1.0`：`project.godot` 的 `config/version` 与「关于」页 `VERSION_TEXT`。

### 已知未修

- 7 个 `.tscn` 是空壳，节点树由代码建，`%UniqueName` 未使用（不满足 §8 实质要求，功能不受影响）。
- 字体重复：`assets/MiSans-Semibold.*` 与 `assets/fonts/` 同名同尺寸各一份（约 29 MB），导出有 UID 重复警告。
- `DuelView` 与 `DuelAudio` 无直接测试。
- 未在非开发机 / 不同分辨率验证；未做 10 分钟长跑。
- 44 条玩家可见文案仍为占位。

---

## 0.0.0 — 2026-10-17 ～ 2026-10-20（开发期）

M1–M5 五个阶段的实现记录见 `docs/dev-example/m1-status.md` … `m5-status.md`，战斗数值与机制迭代见 `docs/dev-example/design.md` 的版本表（`v0.1` ～ `v0.29`）与 `docs/dev-example/balance-pass-01.md` … `balance-pass-05.md`。要点：

- 居合判定（前摇 / 判定帧 / 收招 / 硬直 / 无输入惩罚）。
- 心流资源（40–46 起手、100 上限、15 下限、攻击与受击消耗、待机回复）。
- 架刀与完美格挡（架窗按心流档位加宽、完美窗 3–5f、连击加成上限 +9）。
- 8 位角色固定数据、4 张符卡、10 个心得、商店解锁、阶梯 5 场。
- 本地双人、键鼠 + 手柄、GUIDE 上下文输入、SoundManager 音频、I18N、UIManager 面板栈、Codec 存档。
- GUT 从 0 到 169 用例（636 asserts）。
