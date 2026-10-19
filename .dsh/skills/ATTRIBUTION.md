# 技能目录来源与许可（.dsh/skills）

> 本目录是**第三方技能库的剪枝副本**，由 DSH 以项目级技能（`<projectRoot>/.dsh/skills`，发现优先级 100）自动加载。
> 技能正文为上游英文原文，未做翻译或改写；本项目只增删技能条目，不改技能内部文件。

## 1. 来源

| 项 | 值 |
|----|----|
| 上游仓库 | Game Dev Agentic Skills (GDAS) — https://github.com/thedivergentai/Game-Dev-Agentic-Skills |
| 上游提交 | `db004d74c40686ca2f7a35fe067b119a9cda593e`（main） |
| 上游版本 | 0.1.1（2026-10-16） |
| 许可 | **GNU LGPL-3.0**，全文见同目录 [`LICENSE`](LICENSE) |
| 引入日期 | 2026-10-19 |
| 本地副本 | 仓库外 `.research/Game-Dev-Agentic-Skills`（已 gitignore），仅作更新源 |

## 2. 剪枝规则（Godot 4.7 + 2D 项目）

上游共 **184** 个技能。本项目为 **2D 剑术对决（居合/心流）** 游戏，按以下规则裁剪，保留 **33** 个：

- 保留：Godot 4.7 的 2D 玩法、架构、表现、管线与格斗类型参考。
- 丢弃：`bevy-*` 全部（引擎不匹配）；3D 光照/材质/世界/物理；`adapt-*`（多端/3D 适配）；多人网络与服务器；移动/主机/VR 平台；`version-migration`；RPG 剧情/库存/经济/对话/任务；除格斗外的其他游戏类型；`monte-carlo-balancer`；`gdas-reader`/`rea` 工具链。
- 丢弃（体积大、按需再引入）：`godot-master`（4.6 MB 汇总枢纽）、`godot-analyst` / `godot-auditor` / `godot-builder`（人格技能）、`godot-project-templates`。
- 未改动任何保留技能的文件内容。

## 3. 已安装技能（33）

**架构与工程（9）**：`godot-project-foundations`、`godot-gdscript-mastery`、`godot-composition`、`godot-scene-management`、`godot-signal-architecture`、`godot-autoload-architecture`、`godot-state-machine-advanced`、`godot-resource-data-patterns`、`godot-shaders-basics`

**2D 玩法与表现（12）**：`godot-combat-system`、`godot-characterbody-2d`、`godot-2d-physics`、`godot-2d-animation`、`godot-animation-player`、`godot-tweening`、`godot-particles`、`godot-input-handling`、`godot-camera-systems`、`godot-ability-system`、`godot-raycasting-queries`、`godot-turn-system`

**UI / 音频 / 存档（4）**：`godot-ui-containers`、`godot-ui-theming`、`godot-audio-systems`、`godot-save-load-systems`

**构建与质量（6）**：`godot-testing-patterns`、`godot-debugging-profiling`、`godot-performance-optimization`、`godot-export-builds`、`godot-platform-desktop`、`godot-platform-web`

**类型参考（2）**：`godot-genre-fighting`、`godot-ai-navigation`

## 4. 更新方法

1. `git -C .research/Game-Dev-Agentic-Skills pull`（仓库外，需 DSH 外部命令审批）。
2. 按 §2 规则重新复制所选目录到 `.dsh/skills/`，更新本文件中的提交与版本号。
3. 提交后 DSH 会自动发现新技能（文件系统技能提供方会监听目录变化，无需重启）。

## 5. 免责

技能内容为上游作者作品，版权归其所有；本项目仅作开发参考。技能中的示例代码在采用前需按项目 `AGENTS.md` 规范审查（静态类型、GUIDE 输入、mc_game_framework 等），不得直接粘贴未经审查的代码。
