# 应用图标与窗口标题（2026-11-06）

> 本轮按人类指令把应用图标改成「红染阴阳」，并让窗口标题 / 导出元数据跟随游戏标题（本地化 `menu.title`）。
> **图标属于素材拼接，不是 AI 生成美术**：底板沿用原 `icon.svg`，阴阳取自人类提供的 `temp_assets/Yin_yang.svg`，只改了填充色与合成位置。

## 1. 目标与输入

| 项 | 内容 |
|----|------|
| 基准素材 | `temp_assets/Yin_yang.svg`（人类提供，viewBox `-40 -40 80 80`，默认黑阴阳 + 白鱼身 + 5px 白点/黑点） |
| 底板来源 | 原 `icon.svg` 的 `<rect width=128 height=128 rx=16 fill="#2c3e50"/>`（深蓝圆角底板，保留不动） |
| 要求 | ① 黑色阴阳改红色且不刺眼；② 用阴阳替换原图标的 X；③ 窗口标题等同步为游戏标题；④ 改完本地构建并推送远端 |
| 合规口径 | 人类明确判定为**素材拼接**，不属于 AI 生成美术；`ai-disclosure` 按「美术 0% AI」记录 |

## 2. 图标实现（`icon.svg`）

最终内容（`viewBox="0 0 128 128"`）：

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="16" fill="#2c3e50"/>
  <g transform="translate(64 64)">
    <circle r="39" fill="#8e3b3b"/>
    <path fill="#ffffff" d="M0,38a38,38 0 0 1 0,-76a19,19 0 0 1 0,38a19,19 0 0 0 0,38"/>
    <circle r="5" cy="19" fill="#ffffff"/>
    <circle r="5" cy="-19" fill="#8e3b3b"/>
  </g>
</svg>
```

- **黑色 → 红色**：阴阳底色由默认黑改为 `#8e3b3b`（HSL 约 0°/37%/40%，低饱和砖红）。对比原 X 用的 `#e74c3c`（0°/72%/60%），新色明度与饱和度都压了约一半，避免在深蓝底板上「跳」。
- **替换 X**：删除原两条 `stroke-width="16"` 的对角线，换成 `translate(64 64)` 居中的 39px 阴阳；鱼身 path 与两点直接取自 Yin_yang.svg，坐标未缩放（基准本来就是 80 单位、圆半径 39，放进 128 画布留 25px 边距）。
- **对称细节**：上方白点（`cy=19`）落在红底上、下方红点（`cy=-19`）落在白鱼身上，与原素材方向一致，未做旋转/镜像。
- 未新增任何文字或图形元素，未使用位图。

### 视觉验证

1. 临时脚本 `tools/_icon_preview.gd` 用 `Image.load_svg_from_string(svg, 4.0)` 渲染 512×512，确认「深蓝圆角 + 红白阴阳」与配色；
2. `--headless --import` 后用 `tools/_icon_check.gd` 读回导入纹理（128px），确认导入结果一致；
3. 导出后从 `iai.exe` 提取关联图标（.NET `ExtractAssociatedIcon`，32px），确认为红白阴阳 + 深蓝底板。
   （两个临时脚本在验证后删除，不留入库。）

## 3. 标题与元数据

| 位置 | 原值 | 现值 |
|------|------|------|
| `project.godot` `application/config/name` | `godot_dsh_test` | `刀剑 · 心流` |
| `export_presets.cfg` `product_name` / `file_description` | `godot_dsh_test` / 空 | `刀剑 · 心流` / `刀剑 · 心流` |
| `export_presets.cfg` `application/modify_resources` | `false` | `true`（Godot 4.7 内置写 PE 资源，不需要 rcedit） |
| `file_version` / `product_version` | `0.0.0` | `0.1.0.0` |
| 窗口标题（运行时） | 工程名 | `I18NManager.get_text("menu.title")`（zh「刀剑 · 心流」/ en「Sword · Flow」） |

窗口标题实现（`scripts/core/game_bootstrap.gd`）：

```gdscript
func _ready() -> void:
	# ...（原有本地化初始化）
	EventBus.subscribe(&"LanguageChangedEvent", _on_language_changed)
	_apply_window_title()

func _apply_window_title() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var title := I18NManager.get_text("menu.title")
	if title.is_empty() or title == "menu.title":
		title = String(ProjectSettings.get_setting("application/config/name", ""))
	DisplayServer.window_set_title(title)

func _on_language_changed(_event: Event) -> void:
	_apply_window_title()
```

- 不新增 `app.title` 键：`menu.title` 已是最终定稿标题，避免两份真相。
- 缺键时回退 `application/config/name`，不让窗口出现裸 key。
- headless（CI / 冒烟）直接返回，避免无显示服务器时报错。
- 切换语言（设置页 / `I18NManager.set_language`）会发 `LanguageChangedEvent`，标题随之刷新。

### user:// 路径迁移

`config/name` 同时决定默认 `user://` 目录，改名会让存档「消失」。因此固定用户目录：

```ini
[application]
config/use_custom_user_dir=true
config/custom_user_dir_name="iai"
```

并把旧档 `%APPDATA%/Godot/app_userdata/godot_dsh_test/meta_save.json`（及 `.bak`，各 862 B）复制到新目录 `%APPDATA%/iai/`。

## 4. 验证数据

| 项 | 结果 |
|----|------|
| GUT 全量 | **311/311 通过，1309 asserts，37 脚本，退出码 0**（仅既有 `2 ObjectDB instances were leaked at exit`） |
| `--headless --import` | 退出码 0 |
| `--export-release "Windows Desktop"` | 退出码 0；`build/windows/iai.exe` **119,893,104 B** + `libspine_godot.windows.template_release.x86_64.dll` 1,774,592 B |
| `build/windows/windows.zip` | **48,302,523 B**（deflate 9；exe 47,621,766 + dll 680,469） |
| 产物冒烟 `--headless --quit-after 300` | 退出码 0；`Language [zh_CN]/[en] ... 165 entries`；无 `SCRIPT ERROR` |
| exe 版本资源 | ProductName / FileDescription = 刀剑 · 心流；FileVersion / ProductVersion = 0.1.0.0 |
| exe 图标 | ExtractAssociatedIcon 取到红白阴阳 + 深蓝底板 |

冒烟日志里的 `Failed to open user://logs/...` 与 `Failed to read the root certificate store` 两条，在上一轮同一构建（`build/windows/smoke2.log`，15:26）中同样出现，属本机导出环境既有现象，不是本轮引入。

## 5. 坑：改完 SVG 必须重导入

- **现象**：曾出现「运行中的窗口/任务栏图标仍是旧图（黑阴阳）」，一度被误判为 `icon.svg` 没改红。
- **原因**：Godot 的 `icon.svg` 有导入缓存（`.godot/imported/*.ctex`），直接运行/导出会沿用旧缓存，窗口图标取的是导入纹理而不是 SVG 源文件。
- **处置**：改完 SVG 后先 `--headless --import`（或编辑器内重导入），再运行/导出。本轮最终导入纹理与 exe 图标均已确认为红染版。
- 另外 Windows 资源管理器会缓存 exe 图标，覆盖同名 exe 后可能仍显示旧图，属系统缓存，与工程无关。

## 6. 合规与致谢

- 图标 = 人类提供的 `Yin_yang.svg` + 原 `icon.svg` 底板，AI 只做了「改填充色 + 平移到 128 画布」的素材拼接，**不属于 AI 生成美术**；`docs/gamejam/ai-disclosure.md` 按此口径记录（美术 0%）。
- 未新增玩家可见文案；窗口标题复用既有 `menu.title` 定稿。
- 若后续调整红色明度或底板透明度，只需改 `icon.svg` 的 `fill`/`rect`，并重跑导入 + 导出。
