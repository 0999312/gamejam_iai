class_name UpgradeData
extends Resource

## 心得（升级）静态数据：注册表条目 + I18N 键 + 效果声明。
## 效果由 RunState 解释；表现层只读 name_key / desc_key，不硬编码文案。

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var effect: StringName = &""
@export var amount: int = 0
