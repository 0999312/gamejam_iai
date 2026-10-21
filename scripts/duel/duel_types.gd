class_name DuelTypes
extends RefCounted

## 对决逻辑的公共枚举与档位常量。
## 所有窗口都以 60 Hz 的整数帧表示；毫秒只在 UI/表现层换算。

enum Side {
	P1 = 0,
	P2 = 1,
}

enum State {
	IDLE,
	COMMIT,
	SLASH,
	RECOVERY,
	GUARD,
	GUARD_REC,
	HITSTUN,
	CLASH,
	DOWN,
	SPELL,
}

enum Action {
	NONE,
	ATTACK,
	GUARD,
	SPELL,
}

enum Tier {
	SPREAD,
	CALM,
	FLOW,
}

## 心流档位对「构」前摇的偏移（帧）。心流对攻防的影响以「进攻方为主」：
## 低心流出刀拖慢 6f（100ms），高心流出刀提前 6f，两端差 12f（200ms），
## 明显高于人类可感知窗口（约 150ms），而 ±2f 的旧值等于不存在。
const COMMIT_TIER_OFFSET: Array[int] = [6, 0, -6]

## 心流档位对「架」持续时间的加帧，相对 FighterData.guard_duration_base。
## 「防守方次要」：两端只差 8f（133ms），约为进攻端差距的 2/3。
## 用相对偏移而非固定表，U01（架窗 +2f）与残心加成才能叠加生效。
const GUARD_TIER_OFFSET: Array[int] = [0, 4, 8]

## 心流档位对「完美格挡」判定窗的加帧（相对 DuelSim.PERFECT_BLOCK_WINDOW）。
const PERFECT_TIER_OFFSET: Array[int] = [0, 1, 2]

## 出刀预警：COMMIT 剩余帧数降到该值时，通知表现层把气环转白并出声。
## 2026-10-21 由 8f（133ms）改为 16f（267ms）。原因：模拟实测「看到亮白再按」的
## 玩家如果按人类反应（150–250ms）会永远晚于判定，胜率从 100% 掉到 28%；
## 而架窗只有 18–22f，早按又会在对手 28–30f 前摇结束前过期。16f 把「确认点」
## 拉回人类反应窗内，架刀才有可操作的路径；真正的「看破」仍是提前读收束环。
const SLASH_WARN_FRAMES: int = 16

const FLOW_TIER_SPREAD_MAX := 33
const FLOW_TIER_CALM_MAX := 66


static func tier_for_flow(flow: int) -> int:
	if flow <= FLOW_TIER_SPREAD_MAX:
		return Tier.SPREAD
	if flow <= FLOW_TIER_CALM_MAX:
		return Tier.CALM
	return Tier.FLOW


static func state_name(state: int) -> String:
	match state:
		State.IDLE:
			return "IDLE"
		State.COMMIT:
			return "COMMIT"
		State.SLASH:
			return "SLASH"
		State.RECOVERY:
			return "RECOVERY"
		State.GUARD:
			return "GUARD"
		State.GUARD_REC:
			return "GUARD_REC"
		State.HITSTUN:
			return "HITSTUN"
		State.CLASH:
			return "CLASH"
		State.DOWN:
			return "DOWN"
		State.SPELL:
			return "SPELL"
		_:
			return "UNKNOWN"
