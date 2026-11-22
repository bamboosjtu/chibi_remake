extends RefCounted
## Opening scenario and base terrain.

static func set_terrain_base(battle: Object, value: Variant) -> void:
	battle.terrain_base = value

static func set_scenario_source(battle: Object, value: Variant) -> void:
	battle.scenario_source = value

static func set_scenario_mission(battle: Object, value: Variant) -> void:
	battle.scenario_mission = value

static func set_scenario_avi(battle: Object, value: Variant) -> void:
	battle.scenario_avi = value

static func set_scenario_sides(battle: Object, value: Variant) -> void:
	battle.scenario_sides = value
