# 参数模糊测试：用固定种子扫输入空间，专找「边界值导致崩溃/非法返回」。
# 必须固定 seed，否则失败无法复现；每个失败用例都打印输入。
extends GutTest

const FUZZ_ITERATIONS: int = 500
const FUZZ_SEED: int = 0xC0FFEE

# 占位被测函数；真实项目里换成被测脚本的静态方法。
class DamageMath:
	extends RefCounted

	const ARMOR_MAX: int = 100

	static func apply_armor(raw: int, armor: int) -> int:
		if armor < 0 or armor > ARMOR_MAX:
			return -1
		return maxi(0, raw - armor)


var _rng: RandomNumberGenerator = null


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = FUZZ_SEED


func test_apply_armor_never_returns_negative_damage() -> void:
	for i in FUZZ_ITERATIONS:
		var raw: int = _rng.randi_range(-100, 500)
		var armor: int = _rng.randi_range(-10, 150)
		var damage: int = DamageMath.apply_armor(raw, armor)

		if armor < 0 or armor > DamageMath.ARMOR_MAX:
			assert_eq(damage, -1, "非法护甲应返回 -1（raw=%d armor=%d）" % [raw, armor])
		else:
			assert_true(damage >= 0, "合法输入不应产生负伤害（raw=%d armor=%d）" % [raw, armor])
			assert_true(damage <= maxi(0, raw), "减伤不应把伤害变大（raw=%d armor=%d）" % [raw, armor])


func test_same_seed_reproduces_same_sequence() -> void:
	var first: Array[int] = []
	for i in 10:
		first.append(_rng.randi_range(0, 1000))

	_rng.seed = FUZZ_SEED
	var second: Array[int] = []
	for i in 10:
		second.append(_rng.randi_range(0, 1000))

	assert_eq(first, second, "同一种子必须复现同一序列")
