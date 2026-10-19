# 信号契约测试：先 watch_signals，再断言发射次数与参数。
# 不要断言信号连接顺序，只断言「发了几次、带了什么、有没有多发」。
extends GutTest

# 占位被测组件；真实项目里换成 preload 你的 scripts/combat/health_component.gd。
class HealthComponent:
	extends Node

	signal damaged(amount: int, remaining: int)
	signal died

	@export var max_health: int = 10
	var health: int = 10

	func take_damage(amount: int) -> void:
		if amount <= 0:
			return
		health = maxi(0, health - amount)
		damaged.emit(amount, health)
		if health == 0:
			died.emit()


var target: HealthComponent = null


func before_each() -> void:
	target = HealthComponent.new()
	target.max_health = 10
	target.health = 10
	add_child_autofree(target)


func test_damage_emits_once_with_parameters() -> void:
	watch_signals(target)

	target.take_damage(3)

	assert_signal_emitted(target, "damaged")
	assert_signal_emit_count(target, "damaged", 1)
	assert_signal_emitted_with_parameters(target, "damaged", [3, 7])
	assert_signal_not_emitted(target, "died", "非致死伤害不应发 died")


func test_zero_damage_emits_nothing() -> void:
	watch_signals(target)

	target.take_damage(0)

	assert_signal_emit_count(target, "damaged", 0)
	assert_eq(target.health, 10, "0 伤害不应扣血")


func test_lethal_damage_emits_died_exactly_once() -> void:
	watch_signals(target)

	target.take_damage(99)
	target.take_damage(99)

	assert_eq(target.health, 0)
	assert_signal_emit_count(target, "died", 1, "血量归零后不应重复广播死亡")
	var params: Array = get_signal_parameters(target, "damaged", 0)
	assert_eq(params[1], 0, "首次受伤后剩余血量应为 0")
