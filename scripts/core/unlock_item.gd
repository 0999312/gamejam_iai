class_name UnlockItem
extends Resource

## 商店条目。新增条目只需在 res://resources/unlocks/ 下新增一个 .tres，
## GameBootstrap 会扫描并注册到 MSF 注册表，UI 按 category 分组、按 order 排序，不改代码。
## 名称/描述仍走 I18N：shop.item.<id>.name/desc。

@export var id: StringName
@export var category: StringName = &"perk"
@export var cost: int = 0
@export var requires_clear: bool = false
## 非空时表示这是一个可在商店里开关的持久设置（如困难模式）。
@export var toggle_setting: StringName = &""
@export var order: int = 0
