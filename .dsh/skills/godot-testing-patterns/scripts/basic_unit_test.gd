# 最小 GUT 单元测试：只测纯逻辑，不进场景树。
# 用法：复制到 res://tests/unit/test_<模块>.gd，把 DamageMath 换成被测脚本（preload/class_name）。
extends GutTest

# 占位被测对象；真实项目里删掉它、改为 preload("res://scripts/...")。
class DamageMath:
	static func compute(raw: int, multiplier: float) -> int:
		return maxi(0, roundi(float(raw) * multiplier))

	static func is_defeated(health: int) -> bool:
		return health <= 0


func test_damage_scales_with_multiplier() -> void:
	assert_eq(DamageMath.compute(10, 1.5), 15, "10 x 1.5 应为 15")


func test_damage_is_clamped_at_zero() -> void:
	assert_eq(DamageMath.compute(5, -2.0), 0, "负倍率应夹到 0")


func test_zero_health_is_defeated() -> void:
	assert_true(DamageMath.is_defeated(0), "0 血即败")
	assert_false(DamageMath.is_defeated(1), "1 血未败")
