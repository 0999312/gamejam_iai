extends GutTest

## SpineFighterProfile 的纯数据规则：状态→动画映射、缺键回退、循环判定。


func _profile(map: Dictionary, loops: PackedStringArray = PackedStringArray()) -> SpineFighterProfile:
	var profile := SpineFighterProfile.new()
	profile.animation_map = map
	profile.looping_animations = loops
	return profile


func test_has_resources_requires_both_files() -> void:
	var profile := SpineFighterProfile.new()
	assert_false(profile.has_resources(), "空档案不算可用")
	profile.skeleton_file = Resource.new()
	assert_false(profile.has_resources(), "只有骨架也不算可用")
	profile.atlas_file = Resource.new()
	assert_true(profile.has_resources())


func test_mapped_state_wins() -> void:
	var profile := _profile({"IDLE": "idle", "SLASH": "slash"})
	assert_eq(profile.animation_for_state(DuelTypes.State.SLASH), "slash")


func test_unmapped_state_falls_back_to_idle() -> void:
	var profile := _profile({"IDLE": "idle"})
	assert_eq(profile.animation_for_state(DuelTypes.State.HITSTUN), "idle",
			"没配的状态回退到待机，而不是把人物冻住")


func test_no_idle_means_no_animation() -> void:
	var profile := _profile({"SLASH": "slash"})
	assert_eq(profile.animation_for_state(DuelTypes.State.HITSTUN), "",
			"连 IDLE 都没配时返回空串，表示这一段不播")


func test_empty_string_mapping_is_treated_as_missing() -> void:
	var profile := _profile({"IDLE": "idle", "SLASH": ""})
	assert_eq(profile.animation_for_state(DuelTypes.State.SLASH), "idle",
			"显式留空等于没配")


func test_looping_lookup() -> void:
	var profile := _profile({"IDLE": "idle", "SLASH": "slash"}, PackedStringArray(["idle"]))
	assert_true(profile.is_looping("idle"))
	assert_false(profile.is_looping("slash"))


func test_declared_animations_are_deduped_and_sorted() -> void:
	var profile := _profile({"IDLE": "idle", "COMMIT": "atk", "SLASH": "atk", "DOWN": ""})
	assert_eq(Array(profile.declared_animations()), ["atk", "idle"])


func test_profile_path_uses_convention() -> void:
	assert_eq(SpineProfiles.profile_path(&"char_a"), "res://resources/spine/char_a.tres")


func test_resolve_returns_null_for_unknown_id() -> void:
	assert_null(SpineProfiles.resolve(&"no_such_character"))


func test_resolve_finds_shipped_profiles() -> void:
	var profile := SpineProfiles.resolve(&"char_a")
	assert_not_null(profile, "占位角色的 Spinal 档案必须能按约定路径找到")
	if profile != null:
		assert_eq(profile.animation_for_state(DuelTypes.State.IDLE), "zhanli")
