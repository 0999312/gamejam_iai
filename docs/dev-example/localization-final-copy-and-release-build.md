# 定稿文案回填与发布构建（2026-11-06）

> 本次加载的技能：`godot-export-builds`、`godot-platform-desktop`；使用的插件：`I18NManager`（`localization/*.json` 经其加载，冒烟日志可见 `Language [zh_CN] loaded successfully with 165 entries`）、`SoundManager`/`UIManager`/`GUIDE`（未改动，随包运行）。未加载 `godot-testing-patterns` 的决策树是因为本轮只改断言文本、不新增测试层次；GUT 运行方式仍按该技能。
> 关联：`docs/gamejam/44条本地化占位-定稿.md`（人类定稿表格）、`docs/gamejam/placeholder-inventory.md`、`docs/gamejam/submission-checklist.md`、`CHANGELOG.md`。

## 1. 定稿文案回填（44 条）

### 问题
`localization/zh_CN.json` / `en.json` 里 44 条玩家可见文案大部分仍是 `[占位]` / `[PLACEHOLDER]`，且 `tests/` 有断言「这些键必须以占位开头」，直接替换会让测试变红。

### 修法
1. 按定稿表逐键精确替换（保持 JSON 原文格式与键序）：先命中 zh 36 条 / en 31 条。
2. en 侧 5 条因词条前缀差异未命中，补一次替换：`upgrade.u06.name`（See-Through）、`u07`（Pursuit）、`u08`（Guts）、`u09`（First Strike）、`u10`（`Slash windup -3 frames from second 3 to 8` 去前缀）。
3. 顺带把 en `ui.controls` / `ui.controls_versus` 残留的 `[PLACEHOLDER] ` 前缀去掉（zh 同键本来就无前缀，纯一致性）。
4. 改写 4 处以占位为前提的断言：
   - `tests/unit/test_game_data.gd:17` → `test_upgrade_text_comes_from_i18n`：断言 `upgrade.u01.name == "铁壁"`、desc 含 `"+3"`、`tutorial.start == "屏息凝神，尚待剑发"`。
   - `tests/unit/test_i18n.gd:15` → `get_text("upgrade.u01.name") == "Iron Wall"`（en）。
   - `tests/unit/test_i18n.gd:41` → `test_spell_and_spell_state_have_final_copy`：9 个符卡键改为「不等于键名且不以 `[占位]`/`[PLACEHOLDER]` 开头」。
   - `tests/integration/test_duel_hud.gd:35` → 奖励按钮文本 `begins_with("1. 铁壁")`（格式见 `scripts/duel/duel_hud.gd` 的 `"%d. %s\n%s"`）。
   - `tests/integration/test_duel_hud.gd:102` → `test_zanshin_count_is_hidden_everywhere_in_hud`。定稿把 A 符卡命名为「残心」，HUD 符卡行形如 `残心 ×1 (30)`（`scripts/duel/duel_hud.gd` 的 `_spell_text`：次数 + 耗心流）。测试必须**排除 `_p1_spell` / `_p2_spell` 两个 Label**（新增 `_hud_texts_without_spell_row(hud)`），再用正则 `残心\s*[×xX:：]?\s*\d` 判「层数形态」。两次失败教训：第一次只按文本含「残心」排除 → 仍命中；第二次用正则但没排除符卡行 → 命中 `残心 ×1 (30)`；符卡行里的数字是次数与消耗，不是残心层数。

### 验证
- 两份 JSON 均能解析，各 165 键；`tutorial.spell` 一处占位条目仍在数据里，但 2026-11-06 已按人类指令删除其显示路径（见 §3），玩家不可见。
- GUT **311/311 通过、1309 asserts、37 脚本、退出码 0**（命令：`godot.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`；仅剩既有的 `WARNING: 2 ObjectDB instances were leaked at exit`）。

## 2. 资源精简与发布构建

### 问题
旧产物 `build/windows/iai.exe` 129,180,864 B，其中 pck 约 19.5 MB；字体在 `assets/` 根与 `assets/fonts/` 各有一份（otf+ttf 共约 29 MB），粒子贴图 36 张里绝大多数没有代码引用。

### 修法
1. **字体去重**：只保留唯一被引用的 `assets/fonts/MiSans-Semibold.otf`（6,530,232 B）；根目录 4 个副本与 `assets/fonts/MiSans-Semibold.ttf` 移入 `temp_assets/_dedupe_2026-11-06/`（已 gitignore + .gdignore，不入库不导出）。
2. **未引用素材清理**：用 python 静态审计（扫描 `.gd`/`.tscn`/`.tres`/`.cfg`/`.godot`/`.gdextension`/`.json` 全文，比对 `res://` 路径与文件名）确认项目全部为静态 `preload`、无动态拼接，然后把 33 个零引用文件移到 `temp_assets/_unused_2026-11-06/`（保留目录结构）：`assets/audio/amb/amb_wind_loop.ogg`、`sfx_step_01..03.ogg`、29 张粒子贴图。`assets/particles/` 现存 7 张，正好是 `scripts/duel/duel_fx.gd` 的 7 个 `preload`。
3. **换非 mono 导出模板**：工程没有 `.csproj`、无 C# 编译，mono 模板只会带来 .NET 运行时依赖风险。从官方 `Godot_v4.7.2-stable_export_templates.tpz` 用 HTTP Range + zip 中央目录抽出 `templates/windows_release_x86_64.exe`（109,268,480 B，CRC 校验通过）到 `build/templates_nonmono/`；导出时临时覆盖 `%APPDATA%/Godot/export_templates/4.7.2.stable.mono/windows_release_x86_64.exe`，导出后立即还原（mono 原件备份在 `build/windows_release_x86_64.mono.bak.exe`）。
4. **压缩**：`build/windows/windows.zip` 用 `zipfile.ZIP_DEFLATED compresslevel=9` 重新打包（`iai.exe` + `libspine_godot.windows.template_release.x86_64.dll`）。

### 验证（体积对照）

| 产物 | 旧 | 新 |
|------|----|----|
| `build/windows/iai.exe` | 129,180,864 B | **119,757,696 B** |
| 其中 pck | ≈19.5 MB | ≈10.49 MB（119,757,696 − 109,268,480 = 10,489,216 B） |
| `build/windows/windows.zip` | 57,402,956 B | **48,226,724 B** |

- 关键结论：**Godot 4.7 的 Windows 导出模板本身约 109 MB**（mono 109,513,728 B vs 非 mono 109,268,480 B，只差约 245 KB），所以减体积的空间几乎全在 pck，换模板换来的是「不依赖 .NET 运行时」，不是体积。
- `--headless --import` 退出码 0，无资源缺失报错（反证移出的粒子/音频确实零引用）。
- 导出 `--export-release "Windows Desktop" build/windows/iai.exe` 退出码 0。
- 产物冒烟：`build/windows/iai.exe --headless --quit-after 300` **退出码 0**，无 `SCRIPT ERROR`；仅两条既有噪声（`user://logs/` 目录不存在导致日志写入失败、`Failed to read the root certificate store`，均为无头环境下的既有告警）。
- **干净目录验证**：把 `windows.zip` 解到 `%TEMP%/iai_clean`（没有 `.godot/` 导入缓存、不在工程目录内）后运行同一命令，**退出码 0**，日志显示 `Language [zh_CN] loaded successfully with 165 entries` / `Language [en] loaded successfully with 165 entries`——说明包内本地化、字体、主题、shader、Spine 图集均已进 pck，不依赖开发机导入缓存。
- zip 内容仅两个文件：`iai.exe`（119,757,696 B）与 `libspine_godot.windows.template_release.x86_64.dll`（1,774,592 B）；没有 `.console.exe`（`debug/export_console_wrapper=1` 未产出额外文件）。
- **未验证**：GUI（非 headless）下的实际渲染、另一台非开发机、10 分钟长跑——仍是提交清单 §2 的待办。

## 3. 剩余占位与收尾（2026-11-06 人类指令）

1. ~~`tutorial.spell` 显示~~ —— **已按人类指令删除显示路径**：`scripts/duel/duel_hud.gd` 的 `_tutorial_text()` 不再返回 `tutorial.spell`（原 `duel_hud.gd:511-516` 的「开局 6 秒提示符卡可用」分支移除），底部队操作行 `_controls` 已含「L 发动符卡」（`ui.controls` 硬编码文案与 `ui.controls_template` 的 `%s` 替换都覆盖），玩家仍看得到符卡键位。键本身保留在 `zh_CN.json` / `en.json`（值仍是 `[占位]`/`[PLACEHOLDER]`），作为「定稿表未提供、暂不显示」的记录；将来恢复教程时改 `_tutorial_text()` 并替换该键即可。
2. ~~定稿文案与实现数值冲突~~ —— **已解决**：按人类指令「修改 spell_a.desc 文案至符合代码」，中英改为 45 帧自动弹开 + 反斩 10 伤穿防 + 未接刀返还 10 心流 + 自己先出刀窗口作废；数值未动。
3. ~~`shop.hard_on/off` 与 `menu.char_b/c` 措辞不统一~~ —— **已同步定稿**：zh `shop.hard_on`「修罗模式：开」/ `hard_off`「修罗模式：关」、en「Asura Mode: ON/OFF」；`menu.char_b`「B · 快刀」/ `menu.char_c`「C · 重刀」、en「B · Swift Blade / C · Heavy Blade」，与商店的「快刀 / 重刀」一致。`menu.char_*` 由 `scripts/ui/character_select.gd:185-196` 的 `_tr("menu.%s" % id)` 生成下拉项，**有显示路径**（上一版文档「无代码引用」的判断不准确）。
4. ~~8 处代码兜底串~~ —— **已按人类指令取消占位前缀**：`scripts/ui/menu.gd`、`mode_select.gd`、`pause_menu.gd`、`settings.gd`、`shop.gd`、`about_panel.gd`、`character_select.gd` 与 `scripts/duel/duel_hud.gd` 的 `_tr()` 在缺键时 `push_warning` 并返回空串，不再输出 `"[占位] " + key`；`scripts/ui/settings.gd` 的键位按钮在 `KeyBindings.label()` 为空时显示 `—`（标识空键位）。`scripts/duel/spell_card.gd:6` 的注释同步。
5. `spell.*.desc` 4 条仍无显示路径（`scripts/duel/spell_card.gd` 只赋 `desc_key`，HUD 不读）；按人类指令「不显示就不显示，先记着」保留在 JSON 中。
6. 非文本占位（`docs/gamejam/placeholder-inventory.md` §5）：Spine 运行时授权、封面/README 等提交材料仍需人类确认；导出构建已产出，但 **Spine 运行时会随包分发**，对外发布前须先确认授权。
7. 重新导出后的验证：GUT 311/311（1309 asserts）；包内字节校验「修罗模式」「快刀」「重刀」各命中、旧「困难模式 / 快剑 / 重剑」0 次；干净目录 `%TEMP%/iai_clean3` 冒烟退出码 0，中英各 165 条加载。
