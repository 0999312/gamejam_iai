# Spine 角色接入（spine-godot GDExtension）

> 状态：**五动作测试骨架已接入**（2026-11-04）。素材来自 `temp_assets/test_spine/`，
> 已是 32 骨骼 / 33 槽位 / 10 条 IK / 5 条动画 / 1323×1537 图集的新版本；
> 两条占位角色仍共用这一套**测试 chibi**，不是最终角色美术；P2 用同骨架的独立蓝色衣装图集。
> Spine 运行时的授权问题见 §10，公开分发前必须由人类拍板。

## 1. 结论摘要

| 项 | 结论 |
|---|---|
| 扩展 | spine-godot **4.3（对应 Godot 4.7.2）**，落在 `addons/spine_godot/bin/` |
| 素材 | 美术放在 `temp_assets/test_spine/` 的 JSON + atlas + PNG，复制到 `resources/spine/`；2026-11-04 版为 1323×1537 图集 |
| 硬门槛 | 3.8 运行时版本被 4.3 拒绝；骨架 JSON 需同时满足 `skeleton.spine = 4.3.00`、旧 `ik` → `constraints`、旧 3.8 贝塞尔曲线 → 4.3 绝对控制点，否则会丢 IK 或直接 signal 11（§4.3） |
| 接入点 | `DuelView` 在灰盒人物之上挂两个 `SpineFighterView`；有档案就接管，无档案/无扩展自动回退灰盒 |
| 动画表 | `zhanli` 站立 / `gongji` 攻击 / `bei_gongji` 受击 / `fangyu` 防御 / `siwang` 战败（§4.4） |
| 帧同步 | 非循环动画按「动画时长 ÷ 当前动作窗口帧数」缩放；攻击用「构 + 斩 + 空挥收招」整刀窗口（§5.4） |
| 测试 | GUT **280/280（1077 asserts，35 脚本，退出码 0）**，其中 Spine 相关 37 例（unit 10 / view 19 / duel_view 8） |
| 验证 | 五动作缩略图 `docs/dev-example/spine-animation-preview.png`；真实对局截图 `docs/dev-example/spine-takeover.png` |

## 2. 文件清单

```
addons/spine_godot/bin/
  spine_godot_extension.gdextension        # entry_symbol = spine_godot_library_init，compatibility_minimum 4.1
  windows/libspine_godot.windows.editor.x86_64.dll         2.36 MB
  windows/libspine_godot.windows.template_debug.x86_64.dll 2.20 MB
  windows/libspine_godot.windows.template_release.x86_64.dll 1.77 MB
resources/spine/
  skeleton.spine-json                      # 骨架 JSON（3.8 导出经提版/曲线转换，见 §4.3）
  skeleton.spine-json.import               # importer="spine.json" → .spjson
  skeleton.atlas                           # 图集描述（3.8 写法，4.3 运行时接受；由 spine.atlas 导入器缓存成 .spatlas）
  skeleton.atlas.import                    # importer="spine.atlas" → .spatlas；改 atlas 后必须 --import
  skeleton.png                             # 1323×1537 单页图集（2026-11-04 版，26 个 region）
  skeleton.png.import
  skeleton_p2.atlas                        # P2 图集：仅页名改 skeleton_p2.png，region 坐标与 skeleton.atlas 相同
  skeleton_p2.png                          # P2 蓝色衣装贴图（人类提供，1323×1537）
  skeleton_p2.png.import
  char_a.tres / char_b.tres / char_c.tres
  opponent_1_teaching.tres … opponent_5_boss.tres
scripts/duel/
  spine_fighter_profile.gd                 # class_name SpineFighterProfile extends Resource
  spine_profiles.gd                        # class_name SpineProfiles extends RefCounted
  spine_fighter_view.gd                    # class_name SpineFighterView extends Node2D
  duel_view.gd                             # 接线（_build_spine_views / _bind_spine / _update_spine）
tools/upgrade_legacy_spine_json.gd         # 3.8 → 4.3：版本号 + 旧约束 + 旧贝塞尔曲线迁移（过渡工具）
tests/unit/test_spine_fighter_profile.gd   # 10 例
tests/integration/test_spine_fighter_view.gd # 19 例（含 5 动画/10 IK/动作映射断言）
tests/integration/test_duel_view_spine.gd  # 8 例（含 P2 图集隔离）
```

## 3. 扩展装配

来源：`temp_assets/spine-godot-extension-4.3-4.7.2-stable.zip`（Spine 4.3 运行时 + Godot 4.7.2 构建）。
只复制了 **Windows** 库（`export_presets.cfg` 只有 Windows Desktop 预设）：

1. 解压 zip，把 `bin/` 整个复制成 `addons/spine_godot/bin/`；
2. 删掉 `macos/`、`linux/`、`android/`、`ios/`、`web/`（不需要，也省 11 MB）；
3. 保留 `.gdextension` 原文——它仍列着其它平台路径，在 Windows 上加载器只取 `windows.*`；
   如果以后在 macOS/Linux 打开工程，会报「Can't open dynamic library」，把对应平台目录补回来即可；
4. 重新导入：`godot.exe --headless --path . --import`。成功后 ClassDB 里出现
   `SpineSprite` / `SpineSkeletonFileResource` / `SpineAtlasResource` / `SpineAnimationState` 等类。

> 换 Godot 小版本或换 Spine 大版本时必须同时换扩展与导出器；容器版本与运行时版本不匹配会
> 在 `set_skeleton_data_res()` 处报 `Skeleton version X does not match runtime version Y`。

## 4. 素材导入管线

### 4.1 扩展名规则（实测）

| 源文件 | 导入器 | 结果 |
|---|---|---|
| `*.spine-json`（JSON 骨架） | `spine.json` | 生成 `.godot/imported/<name>.spjson`；**普通 `.json` 不会被识别** |
| `*.atlas` | `spine.atlas` | 缓存成 `.godot/imported/<name>.spatlas`；**运行时读的是缓存**，改 atlas 文本后必须重新 `--import`；源文件仍须随包分发，PNG 页走正常贴图导入 |
| `*.png` | 标准贴图 | 图集页；路径/页名必须与 `.atlas` 里的页名一致 |

### 4.2 实测坑

- 骨架文件改名后**必须重新 `--import`**，否则 `get_animation_state()` 可能是 `null`（看起来像 headless 不支持，其实是导入缓存没更新）。
- 图集页 PNG 若尚未导入，第一次扫描会报
  `ERROR: Can't load texture: "res://.../skeleton.png" at: GodotSpineTextureLoader::load (spine_godot\SpineAtlasResource.cpp:168)`，
  重跑一次导入即消失。
- `.atlas` 的 3.8 写法（`rotate/xy/size/orig/offset/index`）与 4.x 写法（`bounds/offsets`）**4.3 运行时都接受**。
- **改图集后不重新导入会崩，不是报错回退**：2026-10-29 版把 atlas 的 region 名剥掉 `images/` 前缀后没跑 `--import`，
  运行时仍读旧 `.spatlas`（region 名还是 `images/xxx`，与 JSON 附件名对不上），
  第一帧渲染直接 `CrashHandlerException: Program crashed with signal 11`，栈顶
  `libspine_godot.windows.editor.x86_64.dll+fc02a`/`+fccdb`，没有任何 region-not-found 文字。
  改完 atlas 后 `--import` 一次即恢复（当时截图与 A/B 两帧验证通过）。
- 美术导出若把图集页放进 `images/` 子目录，`.atlas` 的页名与 region 名都会带 `images/` 前缀；
  而 JSON 附件名不带前缀时两者匹配数为 0。处理：把页名改成实际 PNG 文件名、region 名去掉 `images/`
  （只改文本元数据，不动像素），或请美术导出时关闭目录前缀。
  2026-11-04 版已直接导出为 `skeleton.png` + 无前缀 region（26 个 region），本次无需改文本；
  但每次换素材仍要用 §4.4 的匹配检查确认一遍。
- 加载顺序：`SpineSkeletonFileResource` + `SpineAtlasResource` → `SpineSkeletonDataResource`（`update_skeleton_data()`）→ `SpineSprite.set_skeleton_data_res()` → 之后才能 `get_animation_state()`；
  `set_skeleton_data_res()` 要在 `add_child()` **之前**调用（实测顺序敏感）。
- headless 也能推进动画；截图取景要按 `SpineSkeleton.get_bounds()` 摆位（素材原点不一定在人物中心）。

### 4.3 3.8 素材的三道硬门槛（版本 + IK 约束 + 贝塞尔曲线）

美术给的 `skeleton.json` 头是 `"spine": "3.8.75"`，4.3 运行时第一道门直接拒绝：

```
ERROR: Error message: Skeleton version 3.8.75 does not match runtime version 4.3
   at: GodotSpineSkeletonDataResource::update_skeleton_data (spine_godot\SpineSkeletonDataResource.cpp:307)
```

**第二道门是 IK 约束结构。** 即使把 `skeleton.spine` 改成 `4.3.00`，3.8 的顶层 `"ik"` 数组也不会被 4.3 解析：
spine-godot 的 `SpineSkeletonDataResource.cpp` 用 `spine::SkeletonJson::readSkeletonData()` 读取，
而 Spine C++ 4.3 只读顶层 `"constraints"` 数组，且每项必须带 `"type": "ik"`。

症状很隐蔽：骨架能加载、`track_time` 正常递增，但
`SpineSkeletonDataResource.get_ik_constraints().size() == 0`；
动画只平移 IK target 骨骼（不可见），四肢骨骼没有被约束驱动，仍停在 setup pose，
所以看起来像“gongji / zhanli 没有播放”。最小夹具对照：

| 夹具 | 顶层约束写法 | `get_ik_constraints().size()` |
|---|---|---|
| `ik_min.spine-json` | 旧 `"ik": [...]` | **0** |
| `ik_min2.spine-json` | `"constraints": [{"type":"ik", ...}]` | **1** |

**第三道门是 3.8 的贝塞尔曲线。** 3.8 时间轴把曲线写成
`"curve": <number>, "c2":…, "c3":…, "c4":…`（归一化、四个字段共用一条曲线）；
4.3 运行时把 `curve` 当**每分量绝对控制点数组**读取。数字被当数组解引用，
在**非最后一帧**上直接触发 `signal 11`（最后一帧的曲线会被忽略，所以“只坏一部分动画”）。
本素材共 **38 段 float 曲线 + 2 段 stepped**；未转换时只有 `zhanli` 能加载，
`gongji`/`bei_gongji`/`fangyu`/`siwang` 全部在加载阶段崩溃。

提版工具现在一次做三件事：改 `skeleton.spine`、把旧 `ik`/`transform`/`path`/`physics`
数组迁到 `constraints`（缺 `type` 的补对应值）、把 3.8 曲线重算为 4.3 的绝对控制点：

```text
cx = t1 + c1x * (t2 - t1)
cy = v1 + c1y * (v2 - v1)
```

- `rotate` 每帧 4 个数；
- `translate`/`scale`/`shear` 的 x、y 各 4 个，共 8 个；
- `color` 的 rgba 各 4 个，共 16 个（hex/255）；
- `deform` 的进度固定为 0…1，每帧 4 个。

本素材迁移 10 条 IK、转换 38 段曲线：

```powershell
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . `
    -s tools/upgrade_legacy_spine_json.gd -- `
    --src temp_assets/test_spine/skeleton.json `
    --dst resources/spine/skeleton.spine-json
# 输出：已升级骨架版本：3.8.75 → 4.3.00
#       已迁移旧约束：10 条
#       已转换 3.8 贝塞尔曲线：38 段
# 退出码 0 成功 / 1 读写失败 / 2 参数错误 / 3 JSON 不合法
```

迁移后顶层键为 `skeleton,bones,slots,skins,animations,constraints`，
10 条 constraints 都是 `type:"ik"`（`youjiao` / `zuojiao ik` / `zuoshou-ik` / `zuoshou-ik2` /
`刀的目标` / `刀鞘目标` / `右手ik` / `右手手掌ik` / `右手袖子-ik` / `袖子左-ik`）。
重新 `--import` 后复测：`DATA IK COUNT=10`、`SKELETON IK COUNT=10`，10 条约束 `active=true mix=1.0`；
探针 `load_from_file` 返回 0，`is_skeleton_data_loaded() == true`。

> 这只是**过渡手段**：正式资产应由美术在 Spine 4.3 编辑器里升级工程后重新导出 JSON，
> 届时直接覆盖 `resources/spine/skeleton.spine-json`（保持文件名不变），不要再跑提版工具。
> 只要美术仍在用 3.8 导出，就必须用本工具重新生成，不能只改版本字符串。

### 4.4 本素材的实测数据

| 项 | 值 |
|---|---|
| 骨骼 / 槽位 / skin / IK | **32 / 33 / 1 / 10** |
| 动画 | **5 条**：`zhanli`（站立，0.6667s，循环）、`gongji`（攻击，1.0000s）、`bei_gongji`（受击，1.3333s）、`fangyu`（防御，0.6667s）、`siwang`（战败，0.8333s） |
| 轨道类型 | `zhanli` 9 骨骼；`gongji` 8 骨骼 + 1 deform；`bei_gongji` 19 骨骼；`fangyu` 8 骨骼 + 1 deform + 1 drawOrder；`siwang` 7 骨骼 |
| 图集 | 单页 **1323×1537**，**26 个 region**；页名 `skeleton.png`、region 无 `images/` 前缀 |
| `get_bounds()` | `Rect2(点(834.3921, 236.2775), 尺寸(748.0074, 943.6001))`，脚底 y≈1179.8776 |
| 适配缩放 | `target_height 150 / 943.6001 ≈ 0.158966`（运行时由包围盒自动算） |
| 文件 | `skeleton.json` 26454 B → 生成的 `skeleton.spine-json` 65551 B；`skeleton.atlas` 2685 B；`skeleton.png` 424741 B |
| 动作实质 | 五条动画都包含骨骼旋转/位移；`gongji` 有刀身 deform，`fangyu` 有 drawOrder（换手/换层），不再是旧版“只有 translate”的身体位移 |

### 4.5 动画表（源文件里的名字）

| 动画名 | 含义 | 时长 | 轨道 |
|---|---|---:|---|
| `zhanli` | 站立 / 待机 | 0.6667s | 9 骨骼 |
| `gongji` | 攻击 | 1.0000s | 8 骨骼 + 刀身 deform |
| `bei_gongji` | 受击 | 1.3333s | 19 骨骼 |
| `fangyu` | 防御 | 0.6667s | 8 骨骼 + deform + drawOrder |
| `siwang` | 战败 / 倒地 | 0.8333s | 7 骨骼 |

## 5. 代码结构

### 5.1 `SpineFighterProfile`（每角色一份 .tres）

| 字段 | 类型 | 说明 |
|---|---|---|
| `skeleton_file` | `Resource` | `SpineSkeletonFileResource` |
| `atlas_file` | `Resource` | `SpineAtlasResource` |
| `animation_map` | `Dictionary` | 键 = `DuelTypes.state_name(state)`（`"IDLE"`/`"COMMIT"`/…），值 = 动画名 |
| `looping_animations` | `PackedStringArray` | 哪些动画循环播放；默认 `["zhanli"]` |
| `target_height` | `float` | 屏幕目标身高（像素），默认 150，与灰盒 `BODY_H` 对齐 |
| `offset` | `Vector2` | 脚底对位微调（本次素材不需要） |
| `flip_when_facing_left` | `bool` | 朝左时水平镜像（默认 true） |
| `sync_animation_to_state` | `bool` | 非循环动画按状态帧数重定时（默认 true，§5.4） |
| `hitstun_tint` | `Color` | 受击染色，默认 `Color(1, 0.74, 0.74)` |

映射规则：状态在 `animation_map` 里且有非空值 → 用它；否则回退 `"IDLE"`；连 `IDLE` 都没配 → 返回空串（该段不播，保持上一段）。

### 5.2 `SpineProfiles`（约定路径）

`res://resources/spine/<角色 id>.tres`。`resolve(id)` 找不到返回 `null`。
角色 id 来自 `FighterState.data.id`（`FighterData.player_a()` 等）。

### 5.3 `SpineFighterView`（Node2D）

- `static is_supported()`：`ClassDB.class_exists("SpineSprite")` 且 `SpineSkeletonDataResource`——**不硬引用**扩展类型，
  没装扩展的机器也能解析脚本、跑灰盒。
- `setup(profile)`：先拆旧、再建 `SpineSprite`；数据资源用静态 `_data_cache` 按「骨架实例 id + 图集实例 id」缓存，
  两个角色共享同一份 `SpineSkeletonDataResource`。
- `apply(fighter, face_left)`：每帧调用；状态边沿才 `_play_state()`，受击按 `hitstun_tint` 染色。
  倒地是否隐藏由档案决定：映射了 `DOWN` 且骨架里存在该动画就播 `siwang` 并保持可见；
  没有映射才隐藏骨架、交回灰盒倒地剪影。
- 姿态：让包围盒**中心 x = 0、脚底 y = 0**，再乘 `target_height / bounds.size.y`；朝左时 `scale.x` 取负且 `position.x` 反号。
- 缺动画：`find_animation()` 查不到时 `push_warning` + 发 `animation_missing` **一次**，保持上一段继续跑，不崩。
- 暂停：`set_paused(true)` → `SpineAnimationState.set_time_scale(0)`；恢复置 `_base_time_scale`。

### 5.4 帧同步公式

非循环动画且 `sync_animation_to_state` 为真时：

```text
time_scale = 动画时长(秒) / (动作窗口帧数 / 60)
```

- **攻击**：`COMMIT` 的实际窗口是 `commit_total + slash_frames + whiff_recovery`，
  这样 `gongji` 1.0s 会覆盖「构 → 斩 → 空挥收招」整刀，而不是只压进前摇。
- **受击/防御/战败**：分别用 `HITSTUN`、`GUARD`/`GUARD_REC`、`DOWN` 的 `state_duration` 对齐。
- **待机**：`zhanli` 循环，保持美术原速，不缩放。
- **重启规则**：每次进入 `COMMIT` 都从第 0 帧重播（新一次攻击）；
  `COMMIT → SLASH → RECOVERY` 共用 `gongji`，这几跳不重启。

### 5.5 `DuelView` 接线

- `_ready()`：先 `_build_spine_views()`（两个 `SpineFighterView`，position 分别为 `(P1_X, GROUND_Y)`、`(P2_X, GROUND_Y)`），再建 `_fx`，保证人物在粒子**之下**；
- `bind(sim)` → `_bind_spine()`：按 `fighter.data.id` 解析档案并 `setup`；允许**先 bind 再入树**（headless 截图路径）；
- `_process()` → `_update_spine()`：P1 `face_left=false`、P2 `true`，每帧 `apply`；
- `_draw_fighter()`：Spine 接管时跳过灰盒的躯干/头/刀，并把 lean/crouch 归零；**叠加层照画**（构的进度点、架窗弧、符卡光柱/双环、架势安全区环、血条、档位条），
  这些是判定信息，不能交给美术资产；
- `set_paused()` 透传给两个视图；
- 显式覆盖：`DuelView.spine_profiles` 字典（键 = 角色 id 或 `StringName`，值 = `SpineFighterProfile`）优先于约定路径。

### 5.6 回退策略

| 情况 | 行为 |
|---|---|
| 未装 spine-godot | `is_supported()` 假 → 不建 Spine 节点，整局灰盒 |
| 角色没有 `.tres` 档案 | 该角色灰盒，另一个角色仍可 Spine |
| 档案缺骨架/图集 | `setup` 返回 false，灰盒 |
| 骨架里没有映射的动画 | 告警一次，保持上一段动画；不崩 |
| 倒地（DOWN）且档案没有 DOWN 映射 | 隐藏骨架；`DuelView._draws_graybox()` 返回 true，回退灰盒倒地剪影 |
| 倒地（DOWN）且映射了 `siwang` | 播 `siwang`，骨架保持可见 |

> `DuelView._draws_graybox()` 通过 `SpineFighterView.has_animation_for_state(DOWN)` 判断，避免
> 「Spine 已接管但无 DOWN 动画」时骨架隐藏、灰盒也不画的双重缺失。

## 6. 动画映射（当前 8 份档案）

| 状态 | 动画 | 说明 |
|---|---|---|
| `IDLE` | `zhanli` | 循环 |
| `COMMIT` / `SLASH` / `RECOVERY` | `gongji` | 同一段攻击动画；进入 `COMMIT` 重播，构→斩→收招不重启 |
| `GUARD` / `GUARD_REC` | `fangyu` | 防御/收架 |
| `CLASH` | `fangyu` | 对刀暂用防御动作（没有专门的 clash 动画） |
| `HITSTUN` | `bei_gongji` | 受击 |
| `DOWN` | `siwang` | 战败/倒地；有映射时保持骨架可见 |
| `SPELL` | 回退 `zhanli` | 素材没有符卡动画 |

8 份档案（`char_a`/`char_b`/`char_c` + 5 个对手）参数完全相同；**对手复用玩家骨架是测试期替身**，
正式素材到位后按角色分别替换 `.tres` 的 `skeleton_file`/`atlas_file` 与 `animation_map` 即可，代码不用改。

### 6.1 P2 蓝色衣装图集（按席位，不按角色 id）

本地双人模式双方可能选同一角色（`DuelSim.new(p1_data, p1_data, ...)`），只改 `char_b.tres` 会让 `char_b`
站 P1 时也变蓝。因此 P2 换装放在 `DuelView` 的表现层：

- `P2_ATLAS_PATH = "res://resources/spine/skeleton_p2.atlas"`；
- `_profile_for_side(profile, side)` 在 `side == P2` 时克隆原档案，只把 `atlas_file` 换成席位图集；
  缓存键是「档案 `instance_id` + 图集 `instance_id`」，换关换图集不会复用旧克隆；P1 直接返回原档案；
- `SpineFighterView._shared_data()` 的缓存键包含 atlas 的 `instance_id`，所以同角色 P1/P2 会命中
  两份不同的 `SpineSkeletonDataResource`，互不污染；
- 图集缺失或导入失败时返回 `null`，回退原图集，不会阻断开局；
- `p2_atlas_file` 是可选 `@export`，留空时走约定路径。

`tests/integration/test_duel_view_spine.gd` 有 1 例专注此事：双方同选 `char_a` 时，P1 仍是
`skeleton.atlas`、P2 是 `skeleton_p2.atlas`，两者不是同一资源，P2 的贴图页为 `skeleton_p2.png`，
且动作映射与原档案一致。

> 换 2P 贴图时只更新 `skeleton_p2.png` 与 `skeleton_p2.atlas` 首行页名，**不要把 `char_b.tres` 改成
> P2 图集**；2P 是席位，不是角色。

### 6.2 单人阶梯前四关的敌方图集

单人模式第 1–4 关的敌人是同一副骨架的不同配色（`skeleton_e1..e4.png`），第 5 关 BOSS 与本地双人
继续用 P2 蓝色衣装。图集仍是「按席位覆盖」，只是覆盖源由控制器按关卡提供：

- `duel_controller.gd` 的 `STAGE_ENEMY_ATLASES` 只列 4 项（`skeleton_e1.atlas`…`skeleton_e4.atlas`）；
- `static func enemy_atlas_for_stage(stage_index: int) -> Resource`：越界（含 BOSS 关 `stage_index == 4`）
  返回 `null`，路径缺失时 `push_warning` 后也返回 `null`，由 `DuelView` 回退默认 P2 图集；
- `_start_stage()` 在 `bind(sim)` 之前调 `_view.set_seat_atlas(enemy_atlas_for_stage(run.stage_index))`；
  `_start_versus()` 调 `_view.set_seat_atlas(null)` 复位，本地双人仍是 P2 蓝色；
- `DuelView.set_seat_atlas(atlas)` 只在值变化时记录，已绑局的会立即 `_bind_spine()` 重挂；
  `_resolve_seat_atlas()` 的优先级是「按关覆盖 → `p2_atlas_file` → 约定 P2 路径」。

四份新 `.atlas` 都以 `skeleton_p2.atlas` 为模板，仅页名改成 `skeleton_eN.png`，26 个 region 坐标不变；
PNG 由人类提供、同尺寸 1323×1537，AI 未改像素。换关时同角色也不会污染 P1：克隆键含图集
`instance_id`，`SpineFighterView._shared_data()` 按 atlas 分别缓存骨架数据。

## 7. 美术替换步骤（人类）

1. 在 **Spine 4.3** 里打开/升级工程，导出 **JSON**（不是二进制 `.skel`）+ atlas + PNG；
2. 骨架 JSON 改名成 `*.spine-json`（扩展名必须是这个）；
3. 覆盖 `resources/spine/` 下同名文件；图集页 PNG 名字若变了，同步改 `.atlas` 页名与 `.tres` 引用；
   若导出把图片放进子目录，`.atlas` 的 region 名会带 `images/` 前缀，必须与 JSON 附件名对齐（见 §4.2）；
   P2 蓝色衣装是独立图集 `skeleton_p2.png` / `skeleton_p2.atlas`，不进角色 `.tres`（见 §6.1）；
   单人前四关的敌方配色同理，是 `skeleton_e1..e4.png` / `.atlas`，由关卡表选图集（见 §6.2）；
4. 若角色有独立素材，按角色 id 新建/覆盖 `resources/spine/<id>.tres`，把 `animation_map` 按上表填好；
5. `godot.exe --headless --path . --import` 重新导入；
6. 跑 `godot.exe --path .` 进一局，确认脚底对齐（必要时调 `offset`）与五条动画切换。

## 8. 验证

### 8.1 GUT

- `tests/unit/test_spine_fighter_profile.gd`：10 例（映射/回退/空串/循环/去重排序/约定路径/resolve）。
- `tests/integration/test_spine_fighter_view.gd`：19 例（扩展注册、setup 接管、**10 条 IK 约束**、空档案拒绝、
  **5 条动画与时长**、GUARD/GUARD_REC/HITSTUN/CLASH/DOWN 各自映射、攻击切换、待机推进、
  攻击按整刀窗口重定时、构→斩不重启、再次进构重播、缺动画只报一次、镜像与关闭镜像、
  DOWN 播 siwang 且可见、无 DOWN 映射回退灰盒、暂停冻结、缩放、clear 释放）。
- `tests/integration/test_duel_view_spine.gd`：11 例（ready 后 bind 双人接管、先 bind 再入树、未知角色回退、
  显式字典覆盖、无 DOWN 映射回退灰盒、P2 图集隔离、**四关图集阶梯与越界回退**、
  **按关覆盖只染 P2**、**换关重建克隆**、暂停透传、换局不重复挂节点）。
- 全量：**314/314 passed，1344 asserts，37 脚本，退出码 0**（Spine 子集 40 例）。

> 注意：headless GUT 里 `wait_frames()` 只等物理帧，`_process` 可能跨十几帧才跑一次；
> 等动画要用 `await wait_process_frames(n)`，或直接调 `view.call("_update_spine")`。

### 8.2 截图

`docs/dev-example/spine-animation-preview.png`：**五动作缩略图**（站立 / 攻击 / 受击 / 防御 / 战败），
在同一副新骨架上分别把 track 时间停在 0.30 / 0.42 / 0.45 / 0.30 / 0.65s 后真实渲染，
不是暂停后手动改骨骼姿态；可看到 `gongji` 的刀身 deform、`fangyu` 的换手层、
`siwang` 的单膝跪倒。

`docs/dev-example/spine-takeover.png`：真实 `duel_view.tscn` 对局截图，两人脚踩 `GROUND_Y=540`，
灰盒躯干/头/刀被替换，血条/档位条/心流环位置不变。

`docs/dev-example/rainy-night-preview.png`：P2 蓝色衣装接入后的雨夜对局截图；P1 用 `skeleton.atlas`
（棕）、P2 用 `skeleton_p2.atlas`（蓝），动作与缩放参数完全一致。

### 8.3 Windows 导出

`godot.exe --headless --path . --export-release "Windows Desktop" build/spine_check/iai.exe`（退出码 0）：
导出目录必须**先存在**（否则报「给定的导出路径不存在」）；GDExtension 库由 Godot 自动带出到
`libspine_godot.windows.template_release.x86_64.dll`，无需手改 `export_presets.cfg`。
导出的 EXE headless 冒烟 120 帧退出码 0。

## 9. 已知限制

- 素材没有 **符卡（SPELL）** 专用动画，`SPELL` 仍回退 `zhanli`。
- `CLASH` 暂用 `fangyu`；如果美术补对刀动画，只需改档案映射。
- `siwang` 是 0.8333s 的倒地动作，但 `DOWN` 状态本身 `duration=0`（终局），所以播完会停在末帧；不做循环。
- 没有挂点（`SpineSlotNode`/`SpineBoneNode` 未使用），刀光/命中点仍按灰盒几何位置算。
- 多页图集、法线贴图、皮肤切换未验证。
- Spine 运行时会为每个 `SpineSprite` 留下内部对象，GUT 报每实例 **34 个 orphan**
  （1 个 SpineSprite + 33 个槽位对象；扩展内部行为，非本项目泄漏；未开 `-gfail_on_orphans`）。
- 3.8 提版工具会改版本字符串、迁移旧约束结构，并把旧贝塞尔曲线重算为 4.3 的绝对控制点；
  但正式资产仍必须由 Spine 4.3 编辑器重新导出，不能把提版结果当最终工程。

## 10. 授权与合规（**提交前必须由人类拍板**）

- spine-godot 使用 **Spine Runtimes License**：运行时的使用要求持有对应的 Spine 编辑器授权；
  团队已明确「没有预算购买授权」。
- 因此本接入目前只作为**内部测试**；若仓库公开或构建对外分发，`addons/spine_godot/`（含 DLL）的再分发条款需人类确认。
  可行路径：① 提交前移除 Spine 接入、回退灰盒；② 购买授权后保留；③ 仓库不公开且构建不对外分发。
- 本次 **美术 0% AI**：Spine 素材由美术提供，AI 未生成、未改像素、未重绘；AI 只写了代码与本文档。
- 测试用 chibi 不是最终美术，提交清单里按 `PLACEHOLDER` 登记；正式角色素材到位后按 §7 替换。

## 11. 命令速查

```powershell
# 重新导入（改名/换素材后必须）
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . --import

# 3.8 JSON 提版（过渡：版本 + 约束 + 曲线）
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . `
    -s tools/upgrade_legacy_spine_json.gd -- --src <in.json> --dst resources/spine/skeleton.spine-json

# 全量测试
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . `
    -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# 导出（目录必须先存在）
mkdir build/spine_check
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . `
    --export-release "Windows Desktop" build/spine_check/iai.exe
```
