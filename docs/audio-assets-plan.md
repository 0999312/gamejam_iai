# 音频素材计划（Audio Assets Plan）

> 版本 v0.1（文档修订号，不是发布版本；发布版本见根目录 CHANGELOG.md） ｜ 2026-10-19 ｜ 性质：**内部工程/采购文档**，不是玩家可见文案。
> 目标：在 M1（10-21）前把「斩 / 被架 / 刃鸣 / 受击」四个核心音与风声底噪准备到**可试听、可入库**的状态，避免后期缺稿。
> 设计约束见 `docs/dev-example/design.md` §11.3 / §11.5；披露见 `docs/gamejam/ai-disclosure.md` §6。

---

## 1. 边界

- **AI 不生成音频**：本计划只做「检索 → 许可核对 → 下载 → 候选整理 → 命名/导入建议」；最终选型由人类试听拍板。
- 音效/环境音可以是 **CC0 / CC-BY / 明确可商用**的第三方素材；文案（含音频描述、 credits 文案）仍由人类撰写。
- 原始下载统一放 `assets/audio/_sources/`（**已 gitignore，不入库**）；最终选定文件复制到 `assets/audio/sfx/`、`assets/audio/amb/` 后再入库。
- 不下载来源不明的「免费音效站」；不使用 NC、仅个人使用、或无法确认许可的素材。

## 2. 许可策略（按优先级）

| 优先级 | 许可 | 可否入库 | 署名 | 备注 |
|---|---|---|---|---|
| 1 | **CC0 1.0** | 可 | 不需要（可选致谢） | 首选；Kenney、OGA CC0 条目 |
| 2 | **CC-BY 3.0/4.0** | 可 | **必须**（作者 + 许可 + 链接） | 需进 README / 游戏 credits |
| 3 | Mixkit Sound Effects Free License | **不入库**，仅构建产物 | 不要求 | 可商用、可用于游戏；但**禁止单独再分发 / 随源文件分发** |
| 4 | Pixabay Content License | **不入库**，仅构建产物 | 不要求 | 同上，禁止单独再分发 |
| — | Freesound | 逐条看 | 逐条 | 预览文件不视为授权；需登录下载原始文件 |
| — | OpenGameArt | 逐条看 | 逐条 | 必须以词条页显示的许可为准 |

**本项目的默认决定：优先只用 CC0/CC-BY 入库；Mixkit/Pixabay 仅作试听参考，不提交原始文件。** 若人类坚持采用 Mixkit 且希望入公开仓库，需要先确认「仅放入构建产物、仓库不含原始文件」的做法可接受。

## 3. 已准备的候选（2026-10-19）

### 3.1 Kenney（CC0 1.0，可安全入库）

| 包 | 文件数 | 本地路径 | 来源 |
|---|---|---|---|
| Impact Sounds | 133（含 License.txt） | `assets/audio/_sources/kenney_impact-sounds/` | https://kenney.nl/assets/impact-sounds |
| RPG Audio | 55（含 License.txt） | `assets/audio/_sources/kenney_rpg-audio/` | https://kenney.nl/assets/rpg-audio |

- License.txt 原文要点：CC0 1.0，可商用、可修改、可再分发，署名非必需。
- 可用项：`drawKnife1..3.ogg`、`knifeSlice.ogg`、`knifeSlice2.ogg`、`cloth1..4.ogg`、`clothBelt*.ogg`、`footstep_wood_000..004.ogg`、`impactMetal_heavy/medium/light_*.ogg`、`impactPlate_heavy/light_*.ogg`。
- 风险：音色偏「游戏化/卡通」，写实剑斗可能不够；人类试听后再定。

### 3.2 OpenGameArt（逐条 CC0，已核对）

| 候选 | 许可 | 本地文件 | 词条 |
|---|---|---|---|
| Wind whoosh loop | CC0 | `opengameart/amb_wind_whoosh_loop_cc0.ogg` | https://opengameart.org/content/wind-whoosh-loop |
| Winter Wind（长/短） | CC0 | `opengameart/amb_winter_wind_cc0.mp3`、`amb_winter_wind_short_cc0.mp3` | https://opengameart.org/content/winter-wind |
| Park ambiences（wind） | CC0 | 下载失败（0 字节，未保留） | https://opengameart.org/content/park-ambiences |
| Loopable Dungeon Ambience | CC0 | `opengameart/amb_dungeon_room_cc0.ogg` | https://opengameart.org/content/loopable-dungeon-ambience |
| Wind Loop | CC-BY 3.0（需署名） | 未下载 | https://opengameart.org/content/wind-loop |
| Birds and Wind | CC0（含鸟鸣/合成器，非纯风） | 未下载 | https://opengameart.org/content/birds-and-wind-ambient-birds-wind-and-synth |

- OGA 的许可以词条页为准；若采用 CC-BY，必须把作者与许可写进 credits。
- `Wind whoosh loop` 是短循环，适合做「风掠过」的纹理层；`Winter Wind` 更像持续风床，二者可叠。

### 3.3 Mixkit（可商用，但仅作试听参考，不入库）

| 候选 | ID | 用途 | 本地文件 |
|---|---|---|---|
| Fast sword whoosh | 2792 | 斩（轻） | `mixkit/sfx_sword_fast_whoosh_2792.mp3` |
| Sword slash swoosh | 1476 | 斩 | `mixkit/sfx_sword_slash_swoosh_1476.mp3` |
| Sword blade swish | 1506 | 斩/挥空 | `mixkit/sfx_sword_blade_swish_1506.mp3` |
| Metal hit woosh | 1485 | 刃鸣/擦刃 | `mixkit/sfx_metal_hit_woosh_1485.mp3` |
| Metallic sword strike | 2160 | 刃鸣 | `mixkit/sfx_metallic_sword_strike_2160.mp3` |
| Samurai Sword Impact | 2789 | 刃鸣/重击 | `mixkit/sfx_samurai_sword_impact_2789.mp3` |
| Sword strikes armor | 2765 | 被架 | `mixkit/sfx_sword_strikes_armor_2765.mp3` |
| Sword hits heavy metal | 2797 | 被架/刃鸣 | `mixkit/sfx_sword_hits_heavy_metal_2797.mp3` |
| Quick saber cut | 2158 | 斩中 | `mixkit/sfx_quick_saber_cut_2158.mp3` |
| Wind blowing ambience | 2658 | 风床（1:01） | `mixkit/amb_wind_blowing_2658.mp3` |
| Wind in the top of the mountain | 1267 | 山风 | `mixkit/amb_wind_mountain_1267.mp3` |
| Breeze through the trees | 2427 | 轻风 | `mixkit/amb_breeze_trees_2427.mp3` |
| Deep cinematic wind hum | 1177 | 低频风 | `mixkit/amb_deep_wind_hum_1177.mp3` |

- 许可核对自 https://mixkit.co/license/modal/sfxFree/ ：可商用、可用于游戏；**不可单独再分发、不可作为素材库/随源文件分发、不可声称为自有**。
- 直链规律：`https://assets.mixkit.co/active_storage/sfx/{id}/{id}-preview.mp3`。

## 4. 候选映射（初版，待人类试听）

| 游戏事件 | 首选（CC0） | 备选（CC0/参考） | 说明 |
|---|---|---|---|
| 斩（出刀 whoosh） | `knifeSlice.ogg` / `knifeSlice2.ogg` | OGA 无；Mixkit 2792/1476/1506 参考 | 单条 < 1s |
| 拔刀 / 收刀 | `drawKnife1..3.ogg` | — | 拔刀可作前兆音，收刀作胜负余韵 |
| 刃鸣（双方同时出刀） | `impactMetal_heavy_000..004` / `impactPlate_heavy_*` | Mixkit 2160/2789/1485 参考 | 要「金属长鸣」而非闷响 |
| 被架（斩被格挡） | `impactMetal_light/medium_*` / `impactPlate_light_*` | Mixkit 2765/2797 参考 | 与刃鸣明确区分 |
| 受击 | `impactWood_medium_*`（临时） | Mixkit 2788 参考（未下载） | 最终需「衣料/肉体」质感，CC0 待补 |
| 衣料 / 踏地 | `cloth1..4.ogg`、`footstep_wood_000..004.ogg` | — | 前兆/步法 |
| 呼吸 / 心跳 | 无 | 待 CC0 检索或人类录制 | 对峙「静」的关键，M2 前补 |
| 环境风声 loop | OGA `amb_wind_whoosh_loop_cc0.ogg` + `winter_wind` | Mixkit 2658/1267/2427/1177 参考 | 可两层叠加 |
| 室内底噪 loop | OGA `amb_dungeon_room_cc0.ogg` | — | 道场/室内场景 |
| UI | `addons/kenney_interface_sounds`（CC0） | — | 已在项目中 |

## 5. 命名与导入规范

- 命名：`assets/audio/sfx/sfx_<category>_<variant>.ogg`；环境：`assets/audio/amb/amb_<name>_loop.ogg`；UI 保持 Kenney 原名或复制到 `assets/audio/ui/`。
- 类别：`slash`、`clash`、`block`、`hit`、`draw`、`sheath`、`cloth`、`step`、`breath`、`heart`。
- 格式：OGG Vorbis 优先（Godot 原生循环支持好）；MP3 仅过渡用，注意编码器延迟导致的循环缝隙。
- 响度：SFX 约 -16 LUFS，峰值 ≤ -1 dBTP；环境约 -20 ~ -18 LUFS，默认音量再低 6 dB。
- 循环：环境音必须无缝；Godot 导入开启 `loop`，必要时用 `loop_offset` 微调；循环点不能有爆音。
- 总线：`Master / Music / SFX / Ambience / UI` 五条；设置页可分别调音量，可一键静音。
- 单条 SFX 时长 < 1 秒（拔刀/收刀可到 1.5 秒）；环境 loop 30–60 秒。

## 6. 工作流

1. **试听**：人类在文件管理器/Godot 里试听 §3 候选（每类至少 2 个）。
2. **选定**：在 §4 表里勾出最终文件；不确定的保留 2 个备选。
3. **入库**：复制到 `assets/audio/sfx|amb/`，按 §5 改名；原始文件留在 `_sources/`（不入库）。
4. **登记**：在 `docs/gamejam/ai-disclosure.md` §6 与作品 README 的 credits 写入来源/作者/许可/链接。
5. **接入**：M2 用 `sound_manager` 播放；事件与 `DuelSim` 信号对齐（`hit_landed` / `attack_blocked` / `clash` / `duel_finished`）。
6. **验收**：循环无爆音、四核心音可盲听区分、静音/音量设置有效。

## 7. 待办与时间

| 时间 | 事项 | 负责人 |
|---|---|---|
| 10-19 | 候选下载、许可核对、本计划（已完成） | AI（工程性检索/下载） |
| 10-20 | 试听并选定 4 核心音 + 风声 | **人类** |
| 10-21（M1） | 核心音接入灰盒（未选定则静音，不阻塞） | 开发 |
| 10-22 → 10-25（M2） | 全部 SFX/环境音接入、总线与音量 | 开发 |
| 10-30 → 11-01（M4） | 混音、响度、循环 QA | 开发 + 人类 |
| 11-04 | 音频冻结 | 全员 |

## 8. 风险

| 风险 | 影响 | 应对 |
|---|---|---|
| Mixkit 许可禁止随源文件再分发 | 公开仓库可能违规 | 原始 MP3 不入库；默认只用 CC0；如坚持用 Mixkit，仅放入构建产物并由人类确认 |
| 本机无 `ffmpeg` | 不能批量转 OGG/做无缝循环 | 优先用 OGA 的 OGG；其余由人类用 Audacity 转换，或后续安装 ffmpeg |
| Kenney 音色偏卡通 | 写实剑斗不够 | 人类试听后决定；必要时检索更多 CC0 写实剑音 |
| MP3 循环缝隙 | 风声 loop 有「咔哒」 | 用 OGG 循环；或做 1–2 秒交叉淡化 |
| 缺少呼吸/心跳/受击合适音 | 「静」的氛围不足 | M2 前补 CC0 检索或人类录制 |
| CC-BY 署名遗漏 | 许可不合规 | credits 表逐条登记；提交前核对 |

## 9. 链接汇总

- Kenney Impact Sounds：https://kenney.nl/assets/impact-sounds
- Kenney RPG Audio：https://kenney.nl/assets/rpg-audio
- Mixkit 许可：https://mixkit.co/license/modal/sfxFree/
- OGA Wind whoosh loop：https://opengameart.org/content/wind-whoosh-loop
- OGA Winter Wind：https://opengameart.org/content/winter-wind
- OGA Park ambiences：https://opengameart.org/content/park-ambiences
- OGA Loopable Dungeon Ambience：https://opengameart.org/content/loopable-dungeon-ambience
- OGA 搜索：https://opengameart.org/art-search?keys=wind+loop

## 10. 实际接入（2026-10-20，音频第一版）

**状态**：已接入灰盒；`SoundManager` 为 autoload；全部入库素材为 **CC0 1.0**，来源与作者见 `assets/audio/CREDITS.md`。人类试听/替换仍待做。

### 10.1 选定文件

| 事件 | 入库文件 | 来源 | 备注 |
|---|---|---|---|
| 斩（出刀） | `sfx_attack_01.ogg` / `sfx_attack_02.ogg` | Kenney RPG `knifeSlice` / `knifeSlice2` | 随机二选一 + 音高 0.96–1.06 |
| 拔刀/前兆 | `sfx_draw.ogg` | Kenney RPG `drawKnife1` | 进入 COMMIT 时播放 |
| 礼让结束/开始 | `sfx_start.ogg` | Kenney RPG `drawKnife2` | 与 HUD「开始」同步 |
| 被架 | `sfx_block_01.ogg` / `sfx_block_02.ogg` | Kenney Impact `impactMetal_medium_000` / `impactPlate_medium_000` | 普通格挡 |
| 完美格挡 | `sfx_clash_01.ogg` | Kenney Impact `impactMetal_heavy_000` | 比普通被架更亮 |
| 刃鸣 | `sfx_clash_01.ogg` / `sfx_clash_02.ogg` | Kenney Impact `impactMetal_heavy_000` / `impactPlate_heavy_000` | 随机二选一 |
| 受击 | `sfx_hit_01.ogg` / `sfx_hit_02.ogg` | Kenney Impact `impactPunch_heavy_000` / `impactSoft_heavy_000` | 与衣料层叠加 |
| 衣料 | `sfx_cloth_01.ogg` / `sfx_cloth_02.ogg` | Kenney RPG `cloth1` / `cloth2` | 受击/空架 |
| 踏地 | `sfx_step_01..03.ogg` | Kenney Impact `footstep_wood_001..003` | 已入库，当前未接 |
| UI 点击 | `sfx_ui_click.ogg` | Kenney RPG `metalClick` | 菜单/按钮 |
| 环境风声 | `amb_wind_loop.ogg` | OGA `wind whoosh loop`（SketchMan3, CC0） | 循环，淡入 0.6s，稳定 -14 dB |

### 10.2 运行时

- `scripts/audio/duel_audio.gd`（`DuelAudio`）：`bind(sim)` 订阅 `state_changed` / `hit_landed` / `attack_blocked` / `clash_happened` / `guard_whiffed`；每场重建 `DuelSim` 时重绑。
- `scripts/duel/duel_controller.gd`：创建 `DuelAudio`，在 `_start_stage()` / `_start_versus()` 绑定；礼让结束时 `play_start()`；退出时 `stop_ambient()`。
- `scripts/ui/menu.gd`、`duel_hud.gd`：按钮/选心得时 `SoundManager.play_ui_sound()`。
- `project.godot`：`[autoload] SoundManager="*res://addons/sound_manager/sound_manager.gd"`。
- 音量：环境 -14 dB；SFX/UI/Ambient/Music 四条子总线；设置页可调主音量/音效/环境音量并静音（M4 已接）。

### 10.3 仍缺

- 呼吸 / 心跳 / 收刀（sheath）/ 道场室内底噪；当前用静默或风声替代。
- 人类试听：Kenney 音色偏卡通，是否满足「写实剑斗」由人类拍板；`sfx_hit` 目前是拳击/软击，需换更「刀入肉/衣料」的 CC0。
- 混音/响度归一化、循环点试听、环境风声的无缝循环（当前 OGG 单层）。
- 正式 credits 文案（人类撰写）。

### 10.4 验证

- GUT 81/81（15 脚本，269 asserts）；`menu.tscn` 与 `duel.tscn` headless exit 0；语言日志 95 条。
- headless 下不启动环境循环（无音频设备），避免 OGG 播放器退出泄漏；窗口模式正常淡入。
- 退出泄漏已修：`DuelAudio.stop_ambient(true)` 显式 `stop()` + `stream=null`，`_exit_tree` 调用。

