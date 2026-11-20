extends RefCounted
const UnitQueries = preload("res://app/read_models/unit_queries.gd")
const MapQueries = preload("res://app/read_models/map_queries.gd")
const CommandQueries = preload("res://app/read_models/command_queries.gd")
const BattleStatusQueries = preload("res://app/read_models/battle_status_queries.gd")
## Battle queries expose scalar values and owned projections.
## The live reader belongs to the scene. A staging reader belongs to its candidate view.
## The host is held weakly: after it is released every query returns the empty value of
## its own type and the contract reports the failure, so teardown can never dereference a
## freed node. Read models must stay usable after `queue_free` of their host.
const Contract = preload("res://composition_contract.gd")
var _data: WeakRef
var _reported := false
var _unit_projection := preload("res://app/read_models/unit_projection.gd").new()
var _context_projection := preload("res://app/read_models/context_projection.gd").new()

var unit: UnitQueries
var map: MapQueries
var commands: CommandQueries
var status: BattleStatusQueries

func _init(data: Object) -> void:
	_data = weakref(data)
	var read_live := Callable(self, "_live")
	unit = UnitQueries.new(read_live, _unit_projection)
	map = MapQueries.new(read_live, _context_projection, preload("res://app/read_models/resource_projection.gd").new())
	commands = CommandQueries.new(read_live, _context_projection)
	status = BattleStatusQueries.new(read_live, _context_projection)

## Return the live host or report the first expiry.
func _live() -> Object:
	var data: Object = _data.get_ref() if _data != null else null
	if data == null and not _reported:
		_reported = true
		Contract.abort_if_broken("battle read model", [{"provider": "battle read model", "method": "provider lifetime"}])
	return data

func projection_counters() -> Dictionary:
	var result := _unit_projection.metrics.duplicate()
	result.merge(_context_projection.metrics)
	return result

var cli_mode:
	get:
		var data := _live()
		return data.cli_mode if data != null else null

var cnt_enemy:
	get:
		var data := _live()
		return data.cnt_enemy if data != null else 0

var cnt_enemy_buildings:
	get:
		var data := _live()
		return data.cnt_enemy_buildings if data != null else 0

var cnt_player:
	get:
		var data := _live()
		return data.cnt_player if data != null else 0

var food:
	get:
		var data := _live()
		return data.food if data != null else 0.0

var game_end:
	get:
		var data := _live()
		return data.game_end if data != null else 0

var gold:
	get:
		var data := _live()
		return data.gold if data != null else 0.0

var map_id:
	get:
		var data := _live()
		return data.map_id if data != null else ""

var officer_policy:
	get:
		var data := _live()
		return data.officer_policy if data != null else ""

var player_owner:
	get:
		var data := _live()
		return data.player_owner if data != null else 0

var resource_revision:
	get:
		var data := _live()
		return data.resource_revision if data != null else 0

var scenario_mission:
	get:
		var data := _live()
		return data.scenario_mission if data != null else -1

var scenario_source:
	get:
		var data := _live()
		return data.scenario_source if data != null else ""

var sim_tick:
	get:
		var data := _live()
		return data.sim_tick if data != null else 0

var stone:
	get:
		var data := _live()
		return data.stone if data != null else 0.0

var tile_hh:
	get:
		var data := _live()
		return data.tile_hh if data != null else 0.0

var tile_hw:
	get:
		var data := _live()
		return data.tile_hw if data != null else 0.0

var tile_w:
	get:
		var data := _live()
		return data.tile_w if data != null else 0.0

var wood:
	get:
		var data := _live()
		return data.wood if data != null else 0.0
