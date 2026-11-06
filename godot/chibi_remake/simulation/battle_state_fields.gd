extends RefCounted
## All BattleState fields must be assigned a policy before a snapshot can load.
## INPUTS are copied deeply into a candidate; restored objects/indices are fresh.
## PRESERVED retains live signal/command ownership; READ_ONLY is navigation data.
const INPUTS := [
	"_officer_pool",
	"player_owner",
	"cheats_enabled",
	"auto_control",
	"cheat_build_any",
	"cheat_invulnerable",
	"cheat_reveal",
	"trainings",
	"player_tech",
	"tech_progress",
	"research_jobs",
	"army_tech",
	"scenario_sides",
	"game_end",
	"feedback_text",
	"feedback_until",
	"_officer_initial_state",
	"map_data",
	"map_id",
	"ev_count",
	"sec_visible",
	"drag_pan",
	"selecting",
	"sel_start",
	"sel_end",
	"gold",
	"wood",
	"food",
	"stone",
	"resource_revision",
	"sheet_by_unit",
	"train_types",
	"build_types",
	"next_uid",
	"_foot_cache",
	"cnt_player",
	"cnt_enemy",
	"scenario_source",
	"scenario_mission",
	"scenario_avi",
	"ai_res",
	"sim_acc",
	"sim_tick",
	"simtest_seconds",
	"cnt_enemy_buildings",
	"task_latches",
	"terrain_changes",
	"terrain_base",
	"officer_progress",
	"task_events",
	"objective_done",
	"officer_policy",
	"cli_mode",
	"jimou_pending",
	"jimou_caster",
	"duel_pending",
	"cmd_pending",
	"cmd_pending_data",
	"decor_targets",
	"decor_cells",
	"control_groups",
	"_input_command",
]
const RESTORED := [
	"units",
	"selected",
	"_cell_index",
	"_cell_index_cell",
	"_cell_index_layer",
	"_cell_index_cells",
	"_index_unit_id",
	"_targets",
	"_target_owner",
	"_index_units_ref",
	"_index_units_size",
]
const OBJECTS := [
	"session",
	"economy",
	"clock",
	"nav",
	"visibility",
	"projectiles",
	"fire_fields",
	"transports",
	"harvesting",
	"construction",
	"ai",
	"simulation_rng",
	"rules",
	"command_rules",
	"stratagems",
	"automatic_gates",
]
const PRESERVED := [
	"effects",
	"player_commands",
]
const READ_ONLY := [
	"tile_w",
	"tile_hw",
	"tile_hh",
]

static func omissions(source: RefCounted) -> Array:
	var expected: Array = INPUTS + RESTORED + OBJECTS + PRESERVED + READ_ONLY
	var missing: Array = []
	for property in source.get_property_list():
		var key := str(property.name)
		if int(property.usage) & (PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP): continue
		if key == "script": continue
		if not expected.has(key): missing.append(key)
		else: expected.erase(key)
	missing.append_array(expected)
	return missing

static func copy_inputs(source: RefCounted, target: RefCounted) -> void:
	for key in INPUTS:
		var value = source.get(key)
		target.set(key, value.duplicate(true) if value is Array or value is Dictionary else value)
