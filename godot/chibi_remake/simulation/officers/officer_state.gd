extends RefCounted
## Officer roster, progression and team records.

static func set_team_kind(unit: Dictionary, value: Variant) -> void:
	unit.team_kind = value

static func set_officer_pool(battle: Object, value: Variant) -> void:
	battle._officer_pool = value

static func set_officer_initial_state(battle: Object, value: Variant) -> void:
	battle._officer_initial_state = value

static func set_officer_policy(battle: Object, value: Variant) -> void:
	battle.officer_policy = value

static func set_level(officer: Dictionary, value: Variant) -> void:
	officer.level = value

static func set_join_target_uid(unit: Dictionary, value: Variant) -> void:
	unit.join_target_uid = value

static func set_group_officer(unit: Dictionary, value: Variant) -> void:
	unit.group_officer = value

static func set_officer_progress_entry(battle: Object, index: int, value: Variant) -> void:
	battle.officer_progress[index] = value

static func set_officer(unit: Dictionary, value: Variant) -> void:
	unit.officer = value

static func set_officer_might(unit: Dictionary, value: Variant) -> void:
	unit.officer_might = value

static func set_officer_intellect(unit: Dictionary, value: Variant) -> void:
	unit.officer_intellect = value
