# fixture 工厂：把「一份合法测试数据」集中在一处构造，避免每个测试各写一份。
# 工厂本身不是测试文件（无 test_ 前缀，不会被 GUT 收集），可放 res://tests/fixtures/。
extends GutTest

class FighterData:
	extends RefCounted

	var display_name: String = ""
	var max_hp: int = 3
	var stance: String = "water"
	var tags: PackedStringArray = PackedStringArray()

	static func make(hp: int = 3) -> FighterData:
		var f := FighterData.new()
		f.max_hp = hp
		return f


class FighterFactory:
	func duelist(display_name: String, hp: int = 3) -> FighterData:
		var f: FighterData = FighterData.make(hp)
		f.display_name = display_name
		f.tags.append("duelist")
		return f


var factory: FighterFactory = null


func before_each() -> void:
	factory = FighterFactory.new()


func test_factory_builds_valid_fixture() -> void:
	var fighter: FighterData = factory.duelist("reimu", 4)

	assert_eq(fighter.display_name, "reimu")
	assert_eq(fighter.max_hp, 4)
	assert_has(fighter.tags, "duelist", "fixture 应带 duelist 标签")


func test_fixtures_do_not_share_state() -> void:
	var a: FighterData = factory.duelist("a")
	var b: FighterData = factory.duelist("b")

	a.max_hp = 1

	assert_eq(b.max_hp, 3, "两次构造的 fixture 必须是独立对象")


func test_default_fixture_is_playable() -> void:
	var fighter: FighterData = factory.duelist("default")

	assert_between(fighter.max_hp, 1, 5, "默认血量应落在可玩区间")
	assert_eq(fighter.stance, "water", "默认构型应为水之型")
