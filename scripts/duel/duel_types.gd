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
}

enum Action {
	NONE,
	ATTACK,
	GUARD,
}

enum Tier {
	SPREAD,
	CALM,
	FLOW,
}

## 心流档位对「构」前摇的偏移（帧）。
const COMMIT_TIER_OFFSET := [2, 0, -2]

## 心流档位对「架」持续时间的帧数。
const GUARD_TIER_FRAMES := [10, 12, 14]

## 看破提示相对真实前兆的提前量（帧）；表现层使用，逻辑层不做真假标记。
const HINT_TIER_LEAD := [0, 6, 10]

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
		_:
			return "UNKNOWN"
