# 已入库粒子贴图来源与许可（Source Record）

> 工程/许可记录，**不是**游戏内 credits 文案；最终 credits 由人类撰写。
> 入库日期：2026-10-23。全部为 **CC0 1.0**：可商用、可修改、可再分发，署名非必需；下表用于致谢与审查。
> 原始素材包在 `temp_assets/kenney_particle-pack/`（该目录已 `.gitignore` + `.gdignore`，**不入库**）。
> 选型理由与「游戏事件 → 贴图」对照见 `docs/particle-assets-plan.md`。

## 1. 来源包

| 项 | 内容 |
|---|---|
| 素材包 | Kenney **Particle Pack 1.1** |
| 作者 | Kenney Vleugels（https://kenney.nl/assets/particle-pack） |
| 许可 | **CC0 1.0**（https://creativecommons.org/publicdomain/zero/1.0/），License.txt 原文：「You may use these assets in personal and commercial projects. Credit (Kenney or www.kenney.nl) would be nice but is not mandatory.」 |
| 取用子集 | `PNG (Transparent)` 中的 36 张（512×512，纯白图案 + alpha） |
| 未取用 | `PNG (Black background)`（带黑底，无法直接做粒子）、`Rotated`（旋转变体，需要时对原图旋转即可）、`Unity samples/*.unitypackage`（引擎专用示例） |
| 改动 | **无**。仅按用途复制归档，像素未改；运行时靠 `modulate` / 粒子 `color` 上色 |
| 许可原文 | 同目录 `LICENSE-kenney-particle-pack-1.1.txt`（从原包 `License.txt` 原样复制，供审查留档） |

## 2. 入库文件

全部位于 `assets/particles/<用途>/`，文件名保留 Kenney 原名，便于回查来源。

| 目录 | 文件（原名） | 张数 |
|---|---|---|
| `slash/` | `slash_01` `slash_02` `slash_03` `slash_04` `twirl_01` `twirl_02` `twirl_03` | 7 |
| `impact/` | `spark_01` `spark_02` `spark_07` `star_06` `star_07` `star_08` `star_09` `flare_01` `magic_03` `scorch_01` | 10 |
| `guard/` | `circle_02` `circle_03` `light_02` | 3 |
| `spell/` | `magic_01` `magic_02` `magic_05` `light_03` `trace_05` `trace_07` | 6 |
| `dust/` | `smoke_04` `smoke_06` `smoke_07` `smoke_08` `smoke_09` `dirt_01` `dirt_03` | 7 |
| `glow/` | `light_01` `circle_05` `star_05` | 3 |
| 合计 | | **36** |

- 总大小约 2.2 MB（PNG 未压缩改动，`.godot/imported` 里按 Godot 默认无损导入生成 `.ctex`）。
- 如需追加同包其它贴图：从 `temp_assets/kenney_particle-pack/PNG (Transparent)/` 复制，同步更新本表与 `docs/particle-assets-plan.md`。

## 3. 来源链接

- Kenney Particle Pack：https://kenney.nl/assets/particle-pack
- CC0 1.0：https://creativecommons.org/publicdomain/zero/1.0/
- Kenney 官网：https://kenney.nl
- 原包 `License.txt` 另列「filter templates」协作者：Indigo Ray、Craig Nisbet、Zoltan Erdokovy、Heliagon、ThreeDee、Killst4r、Tim2501（同属 CC0，署名非必需）。
