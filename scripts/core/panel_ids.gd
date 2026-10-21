class_name PanelIds
extends RefCounted

## 面板 id 的唯一来源：UIRegistry 注册与 UIManager 打开都从这里取，
## 避免字符串散落各处拼错。

const SHOP := "iai:shop"
const SETTINGS := "iai:settings"
const PAUSE := "iai:pause"


static func shop() -> ResourceLocation:
	return ResourceLocation.from_string(SHOP)


static func settings() -> ResourceLocation:
	return ResourceLocation.from_string(SETTINGS)


static func pause() -> ResourceLocation:
	return ResourceLocation.from_string(PAUSE)
