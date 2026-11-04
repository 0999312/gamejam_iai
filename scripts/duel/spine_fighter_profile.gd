class_name SpineFighterProfile
extends Resource

## 一个角色的 Spine 表现档案：骨架/图集引用、状态→动画映射、版面参数。
##
## 设计约束（为什么这么切）：
## - 档案是**纯数据**，美术换角色只换 .tres + 两个资源文件，不碰代码；
## - 档案缺失、资源缺失、扩展缺失时 DuelView 一律回退灰盒，灰盒永远是保底；
## - 映射按 `DuelTypes.state_name()` 的字符串键，避免把枚举序号写进资源。

## 骨架文件（SpineSkeletonFileResource，导入自 .spine-json）。
@export var skeleton_file: Resource

## 图集文件（SpineAtlasResource，导入自 .atlas）。
@export var atlas_file: Resource

## 状态名（"IDLE"/"COMMIT"/"SLASH"/"RECOVERY"/"GUARD"/"GUARD_REC"/"HITSTUN"/"CLASH"/"SPELL"/"DOWN"）
## → 骨架里的动画名。缺某个状态时回退到 "IDLE" 的动画。
@export var animation_map: Dictionary = {}

## 这些动画会循环播放；其余动画一次性播完（并按状态剩余帧数重定时）。
@export var looping_animations: PackedStringArray = PackedStringArray()

## 把骨架 setup 姿态的高度缩放到这个像素高度；<= 0 表示不缩放。
## 灰盒身位高 150 px，盖住它才不会出现「Spine 人物比判定盒大两圈」。
@export var target_height: float = 150.0

## 缩放对位之后再做的一次像素级平移（x 右、y 下）。
@export var offset: Vector2 = Vector2.ZERO

## 朝左站时水平镜像（右脚位的角色要翻过来）。
@export var flip_when_facing_left: bool = true

## 非循环动画按动作窗口重定时：判定窗最窄只有 5 帧（83 ms），
## 让美术原速播会让「刀已收回、判定还在」或反过来，必须对齐。
## 攻击按「构 + 斩 + 空挥收招」的整刀窗口算，不是只看构。
@export var sync_animation_to_state: bool = true

## 受击染色：非受击状态恢复为纯白。
@export var hitstun_tint: Color = Color(1.0, 0.74, 0.74)

const FALLBACK_STATE := "IDLE"


## 档案是否指向了可用的资源。
func has_resources() -> bool:
	return skeleton_file != null and atlas_file != null


## 状态 → 动画名；没映射时回退 "IDLE"；连 "IDLE" 也没有时返回空串（表示不播）。
func animation_for_state(state: int) -> String:
	var key := DuelTypes.state_name(state)
	var mapped: Variant = animation_map.get(key, null)
	if mapped is String and not (mapped as String).is_empty():
		return mapped
	var fallback: Variant = animation_map.get(FALLBACK_STATE, null)
	if fallback is String:
		return fallback
	return ""


## 该动画是否循环。
func is_looping(animation: String) -> bool:
	return looping_animations.has(animation)


## 档案里声明过的全部动画名（去重、排序），给体检工具/测试用。
func declared_animations() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for value: Variant in animation_map.values():
		if value is String and not (value as String).is_empty() and not out.has(value):
			out.append(value)
	out.sort()
	return out
