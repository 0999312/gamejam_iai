class_name UnlockPurchasedEvent
extends Event

## 局外解锁发生变化（买到 / 切换开关）。
## 商店发布，主菜单与商店自己订阅：面板常驻后金币与可选角色必须靠事件刷新，
## 而不是重开场景。

var unlock_id: StringName


func _init(p_unlock_id: StringName = &"") -> void:
	unlock_id = p_unlock_id
