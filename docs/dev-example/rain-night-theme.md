# 雨夜主题与 CC0 雨声环境音（2026-11-04）

## 1. 需求与边界

人类原始需求（m00800）：

> 不使用原来的风声作为背景氛围音效，使用 temp_assets 里的 Ambiance_Rain_Calm_Loop_Stereo.wav，该音效为 CC0 协议。
> 然后重做游戏的 theme，使其和背景能很好融合在一起且必要信息高度可读。

随后补充（m01037）：

> 注意：减少 AI 风格，考虑主题和游戏类型。考虑无边框设计。

本轮只改「听」与「看」的表现层：环境音、主题资源、HUD 可读性、设置页开关排布。
不动判定、状态机、GUIDE 输入、存档结构；音频仍走 SoundManager，UI 仍由既有脚本建节点。
美术 0% AI：没有生成任何贴图/图标/背景图；雨夜背景与主题都是代码/资源参数。

## 2. 视觉取向：墨蓝纸面，不是玻璃卡片

第一版主题是「深色玻璃卡片 + 圆角 + 阴影 + 整圈金色焦点」，截图后像通用 SaaS 面板，和居合对决的克制感相反。
现在改成三条约束：

1. **无边框**：Button / OptionButton / CheckBox / CheckButton 的 normal 态完全透明，没有圆角、没有阴影；
   按钮靠文字、字距和留白成组。只有 hover（钢色 7%）与 pressed（淡金 13%）给一点触碰反馈。
2. **文字优先**：默认 MiSans-Semibold 18px；Label/RichTextLabel 用近白字 + `#02050a` 4px 描边，
   雨线穿过 HUD 时字仍然立得住。Button 用 2px 描边。
3. **焦点是一道刀鞘金下划线**：不再画整圈框，只在控件底边留 2px `#c8a063`。它像夹在纸页里的刀镡，
   不会把按钮重新变成「卡片」。

调色板与对比度（相对页面底色 `#060a10`，WCAG 对比度）：

| 角色 | 色值 | 对比度 |
|---|---|---|
| 主文字 INK | `#e9f0f7` | 17.26:1 |
| 次文字 INK_SOFT | `#c3d0dd` | 12.65:1 |
| 弱文字 MUTED | `#8b9bac` | 6.97:1 |
| 焦点/强调 GOLD | `#c8a063` | 8.18:1 |
| 页面底 NIGHT_0 | `#060a10` | — |
| 面板/输入底 NIGHT_1 | `#0a111a` | — |
| 分隔线 LINE | `#22303f` | — |

所有正文色都超过 4.5:1；弱文字 6.97:1，用于「更多角色在商店解锁」这类辅助句。

## 3. 主题资源与生成方式

- 生成器：`tools/build_rain_night_theme.gd`（`extends SceneTree`，用 ResourceSaver 保存）。
- 产物：`assets/theme/rain_night.tres`（约 21 KB，含 StyleBoxFlat 子资源）。
- 接线：`project.godot` 的 `gui/theme/custom` 指向 `res://assets/theme/rain_night.tres`。
- 重新生成：
  ```powershell
  & "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . -s tools/build_rain_night_theme.gd
  ```

生成器负责「静态主题」；`scripts/ui/ui_focus.gd` 负责运行时焦点环。两者必须一致：
早期 `UiFocus` 会在 focus_entered 时新建 3px 圆角整圈 StyleBox，把主题里的下划线覆盖掉，
菜单第一项又变回「金框按钮」。现在 `UiFocus` 只保留 `border_width_bottom = 2`、`border_color = #c8a063`、
圆角 0、背景透明，并且只做焦点提示，不改变控件底色。

输入类控件保留一条底边作为「可点」暗示：OptionButton / LineEdit 常态 1px `#22303f`，聚焦时 `#e8c98e`。
ProgressBar 用 `#05090f` 深轨 + `#e8f2fb` 近白填充；HUD 仍按心流档位 `modulate` 整条染色，不把档位色写进主题。

### 设置页开关排布

CheckButton 原先带整行底色，视觉上像两个孤立胶囊，且和左侧「主音量」不在同一基线。
本轮在 `scripts/ui/settings.gd` 的 `_add_check_row` 中把开关改为：

- `alignment = HORIZONTAL_ALIGNMENT_LEFT`
- `custom_minimum_size = Vector2(0, 42)`
- `size_flags_horizontal = SIZE_SHRINK_BEGIN`

主题里 CheckButton 的 normal/hover/pressed margin 左侧改为 0（`Vector4(0, 10, 8, 10)`），
文字与音量标签统一落在 x=170，开关图标紧跟文字。

## 4. HUD 可读性：两条 scrim，不挡角色

雨线是屏幕空间高频细节，直接压在 24px 血量与 16px 操作提示上会「字里有雨」。
`scripts/duel/duel_hud.gd` 在 `HudRoot` 下加了两层 `TextureRect`：

| 节点 | 位置 | 尺寸 | 渐变 |
|---|---|---|---|
| TopScrim | (0, 0) | 1280×190 | 深色 rgba(0.006,0.012,0.022) alpha 0.66 → 0 |
| BottomScrim | (0, 600) | 1280×120 | 同上，从底部向上淡出 |

两层都 `mouse_filter = IGNORE`，且在 `_reward_dim` 之前加入，奖励三选一的遮罩仍能压住它们。
中间 190–600 的角色区不加遮罩，避免把雨夜压成一块平板。
文字本身还有主题描边兜底，所以 scrim 只做「减噪」，不是唯一可读性来源。

## 5. 雨声环境音

### 素材与许可

- 人类提供：`temp_assets/Ambiance_Rain_Calm_Loop_Stereo.wav`，声明为 **CC0**。
- 实测：2 声道、24-bit、48000 Hz、1,440,000 帧、30.0 秒、8,640,784 B。
- 入库：`assets/audio/amb/rain_calm_loop.wav`（同字节复制，未转码）。
- 原始下载页 URL 暂未提供；`assets/audio/CREDITS.md` 中登记为「人类提供，URL 待补」，不编造来源链接。

### 运行时

`scripts/audio/duel_audio.gd`：

```gdscript
const RAIN_AMBIENT := preload("res://assets/audio/amb/rain_calm_loop.wav")
const RAIN_VOLUME_DB := -17.0
```

- `_ready()` 先 `duplicate()`，再设 `loop_mode = LOOP_FORWARD`、`loop_begin = 0`、
  `loop_end = int(round(get_length() * mix_rate))`。直接改 `load()` 缓存资源会污染其他引用。
- `start_ambient()` 调 `SoundManager.play_ambient_sound(_rain, 2.0)`：第二个参数是 2 秒淡入，不是音量；
  返回的播放器再设 `volume_db = -17.0`，压在心流提示音之下。
- `stop_ambient(false)` 用 `SoundManager.stop_ambient_sound(_rain, 0.3)` 淡出；`immediate` 只 `stop()` 不置空 stream，
  避免 SoundManager 池回收时对 null 取 `resource_path`。
- 只在 `DisplayServer.get_name() != "headless"` 时启动，GUT/CI 不残留 playback。
- 旧 `assets/audio/amb/amb_wind_loop.ogg` 已无代码引用，保留在磁盘作为历史素材；是否删除由人类决定。

### 为什么用 WAV 而不是 OGG

尝试用本机 Python/soundfile 把 30 秒整段转 OGG，进程静默退出（exit 127），只留下半成品；
已删除半成品与临时脚本。继续用 WAV 的三个理由：

1. 30 秒立体声 24-bit 约 8.2 MB，对桌面构建可接受；
2. 不引入转码后的循环点偏移与二次有损；
3. Godot 的 `AudioStreamWAV` 可直接设采样级 loop 点，行为可测。

代价是包体变大；若最终需要压体积，应由人类用正式编码器转 OGG，并在导入后重新试听循环接缝。

## 6. 验证

- 全量 GUT：**279/279 passed、1068 asserts、35 脚本、退出码 0**（本轮新增 8 例 45 asserts；后续刀光/主菜单改动再 +2 例，P2 图集再 +1，当前 **280/280、1077 asserts**）。
- 新增/更新：
  - `tests/integration/test_rain_night_theme.gd`：5 例 17 asserts。项目主题路径、按钮 normal 透明、
    焦点只有底边 2px、ProgressBar 亮填充、CheckButton 按下色偏暖。
  - `tests/integration/test_duel_audio.gd`：2 例 10 asserts。WAV 路径/循环/时长、启动后播放器 stream
    与音量、且播放的是 duplicate 而非共享资源。
  - `tests/integration/test_duel_hud.gd`：新增 scrim 1 例 18 asserts，HUD 共 4 例 26 asserts。
- 目视截图（1280×720）：
  - `docs/dev-example/theme-menu.png`（2026-11-04 后续已补上主菜单雨夜背景）
  - `docs/dev-example/theme-settings.png`
  - `docs/dev-example/theme-duel-hud.png`

截图由 `tools/theme_preview.tscn` + `tools/theme_preview.gd` 生成。它走正常主场景/autoload 加载，
不能像纯 SceneTree 脚本那样绕过 GameBootstrap：

```powershell
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --path . res://tools/theme_preview.tscn
```

## 7. 限制

- 全部 UI 仍按 1280×720 逻辑坐标写死；未在非 16:9 / 非开发机验证。scrim 高度、菜单按钮宽度都是常量。
- 雨声循环接缝、整体音量与「雨声是否盖过刀音」尚未人耳终混；设置页的「环境音」滑条控制 ambient 总线，
  但没有单独的雨声强度/开关。
- CheckButton 图标仍是主题 fallback 的小圆点；`icon_max_width=26` 只能限制上限，不能把 16px 内置图标放大成设计稿尺寸。
  若要更好的开关形态，需要人类提供/指定图标资源。
- 主题由生成器产出；手改 `rain_night.tres` 会在下次生成时被覆盖。调色/边距应改 `tools/build_rain_night_theme.gd` 后重跑。
- 对比度按纯色 sRGB 计算，未覆盖半透明 hover/pressed 叠加后的实际像素；最终仍以截图目视和真机为准。
- 雨声原始 URL 未提供，CC0 依据目前来自人类声明与 `temp_assets` 文件本身；提交前应补齐来源页或授权说明。
