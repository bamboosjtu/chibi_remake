extends RefCounted
## Scene-free domain graph shared by gameplay and snapshot candidates.
const Nav = preload("res://simulation/navigation/nav.gd")
var economy: RefCounted
var projectiles: RefCounted
var fire_fields: RefCounted
var transports: RefCounted
var harvesting: RefCounted
var construction: RefCounted
var stratagems: RefCounted
var command_rules: RefCounted
var rules: RefCounted:
	set(value):
		rules = value
		if campaign != null: campaign._rules = value
var ai: RefCounted:
	set(value):
		ai = value
		if ai_economy != null: ai_economy._ai = value
		if battle_simulation != null: battle_simulation._ai = value
		if production != null: production._ai = value
var effects = preload("res://simulation/ports/battle_events.gd").new()
var nav := Nav.new()                                # 拥有 AStarGrid2D 与瓦片尺寸（tile_w/tile_hw/tile_hh）
var visibility = preload("res://simulation/systems/battle_visibility.gd").new()
var automatic_gates = preload("res://simulation/navigation/automatic_gates.gd").new()
var clock = preload("res://simulation/systems/battle_clock.gd").new()

var definition: Dictionary = {}
var state := preload("res://simulation/state/battle_state.gd").new()
const AbilitiesService = preload("res://simulation/battle/abilities.gd")
var abilities: AbilitiesService
const AiEconomyService = preload("res://simulation/battle/ai_economy.gd")
var ai_economy: AiEconomyService
const AiOrdersService = preload("res://simulation/battle/ai_orders.gd")
var ai_orders: AiOrdersService
const BattleSimulationService = preload("res://simulation/world/battle_simulation.gd")
var battle_simulation: BattleSimulationService
const CampaignService = preload("res://simulation/battle/campaign.gd")
var campaign: CampaignService
const CheatRulesService = preload("res://simulation/battle/cheat_rules.gd")
var cheat_rules: CheatRulesService
const CombatService = preload("res://simulation/battle/combat.gd")
var combat: CombatService
const CommandGroupsService = preload("res://simulation/battle/command_groups.gd")
var command_groups: CommandGroupsService
const ConstructionOrdersService = preload("res://simulation/battle/construction_orders.gd")
var construction_orders: ConstructionOrdersService
const EntityFactoryService = preload("res://simulation/battle/entity_factory.gd")
var entity_factory: EntityFactoryService
const HarvestOrdersService = preload("res://simulation/battle/harvest_orders.gd")
var harvest_orders: HarvestOrdersService
const InteractionPathsService = preload("res://simulation/battle/interaction_paths.gd")
var interaction_paths: InteractionPathsService
const MovementService = preload("res://simulation/battle/movement.gd")
var movement: MovementService
const OfficerPoolService = preload("res://simulation/battle/officer_pool.gd")
var officer_pool: OfficerPoolService
const OfficerTeamsService = preload("res://simulation/battle/officer_teams.gd")
var officer_teams: OfficerTeamsService
const ProductionService = preload("res://simulation/battle/production.gd")
var production: ProductionService
const SelectionService = preload("res://simulation/battle/selection.gd")
var selection: SelectionService
const SpatialIndexService = preload("res://simulation/battle/spatial_index.gd")
var spatial_index: SpatialIndexService
const TechnologyService = preload("res://simulation/battle/technology.gd")
var technology: TechnologyService
const TransportOrdersService = preload("res://simulation/battle/transport_orders.gd")
var transport_orders: TransportOrdersService
const UnitActionsService = preload("res://simulation/battle/unit_actions.gd")
var unit_actions: UnitActionsService
const WorldOrdersService = preload("res://simulation/battle/world_orders.gd")
var world_orders: WorldOrdersService
const PlayerCommandsService = preload("res://simulation/systems/player_commands.gd")
var player_commands: PlayerCommandsService
var _disposed := false

func _init() -> void:
	if not preload("res://simulation/definitions/rule_catalog.gd").is_ready():
		preload("res://composition_contract.gd").abort_if_broken("battle rules", [{"provider":"rule catalog", "method":"startup initialization"}])
		return
	state.geometry = nav.state
	state.simulation_rng.seed = 0x4348494249
	abilities = AbilitiesService.new(state)
	ai_economy = AiEconomyService.new(state)
	ai_orders = AiOrdersService.new(state)
	battle_simulation = BattleSimulationService.new(state)
	campaign = CampaignService.new(state)
	cheat_rules = CheatRulesService.new(state)
	combat = CombatService.new(state)
	command_groups = CommandGroupsService.new(state)
	construction_orders = ConstructionOrdersService.new(state)
	entity_factory = EntityFactoryService.new(state)
	harvest_orders = HarvestOrdersService.new(state)
	interaction_paths = InteractionPathsService.new(state)
	movement = MovementService.new(state)
	officer_pool = OfficerPoolService.new(state)
	officer_teams = OfficerTeamsService.new(state)
	production = ProductionService.new(state)
	selection = SelectionService.new(state)
	spatial_index = SpatialIndexService.new(state)
	technology = TechnologyService.new(state)
	transport_orders = TransportOrdersService.new(state)
	unit_actions = UnitActionsService.new(state)
	world_orders = WorldOrdersService.new(state)
	player_commands = PlayerCommandsService.new(state, get_instance_id())
	economy = preload("res://simulation/systems/economy.gd").new(self)
	projectiles = preload("res://simulation/systems/projectiles.gd").new(self)
	fire_fields = preload("res://simulation/systems/fire_fields.gd").new(self)
	transports = preload("res://simulation/systems/transports.gd").new(self)
	harvesting = preload("res://simulation/systems/harvesting.gd").new(self)
	construction = preload("res://simulation/systems/construction_interior.gd").new(self)
	stratagems = preload("res://simulation/systems/stratagem_rules.gd").new(self)
	command_rules = preload("res://simulation/systems/command_rules.gd").new(self)
	rules = preload("res://simulation/systems/scenario_rules.gd").new(self)
	for service in _owned_services().values():
		if service != null and service.has_method("bind_dependencies"): service.bind_dependencies(self)
	set_ai_enabled(true)

func set_ai_enabled(enabled: bool) -> void:
	if not enabled: ai = null
	elif ai == null: ai = preload("res://simulation/systems/ai.gd").new(self)

func prepare_map() -> void:
	nav.setup(state.map_data)
	visibility.setup(Vector2(float(state.map_data.terrainW), float(state.map_data.terrainH)))

func seed_map_units() -> bool:
	if not state.units.is_empty(): return false
	for index in range(state.map_data.objects.size()):
		var unit: Dictionary = entity_factory._make_unit(state.map_data.objects[index], true)
		unit.map_index = index
		state.units.append(unit)
	return true

func validate_services(label: String, application_services: Dictionary = {}, fail_fast := true) -> Dictionary:
	var services := _owned_services()
	services.merge(application_services)
	var report: Dictionary=preload("res://composition_contract.gd").wire(services, label, fail_fast)
	return report

func dispose() -> void:
	if _disposed: return
	_disposed = true
	# Presentation listeners are closed even on a partially initialized world.
	effects.close()
	if battle_simulation == null: return
	player_commands.retire()
	battle_simulation.disconnect_native()
	nav.release_runtime_queries()
	# Dictionary targets can form cycles even after the world owner is released.
	for unit in state.units:
		for field in ["target","gather_obj","build_target","repair_target","board_target"]:
			if unit.get(field) is Dictionary:unit[field]=null
	# Domain behaviors are world-owned Objects. Their links to peers are
	# borrowed, so mutually recursive calls do not create ownership cycles.
	ai = null
	for service in _owned_services().values():
		if service is Object and not service is RefCounted:
			service.free()

func set_definition(data: Dictionary) -> void:
	definition = preload("res://simulation/definitions/frozen_data.gd").copy(data)

func _owned_services() -> Dictionary:
	return {
		"abilities": abilities,
		"ai_economy": ai_economy,
		"ai_orders": ai_orders,
		"battle_simulation": battle_simulation,
		"campaign": campaign,
		"cheat_rules": cheat_rules,
		"combat": combat,
		"command_groups": command_groups,
		"construction_orders": construction_orders,
		"entity_factory": entity_factory,
		"harvest_orders": harvest_orders,
		"interaction_paths": interaction_paths,
		"movement": movement,
		"officer_pool": officer_pool,
		"officer_teams": officer_teams,
		"production": production,
		"selection": selection,
		"spatial_index": spatial_index,
		"technology": technology,
		"transport_orders": transport_orders,
		"unit_actions": unit_actions,
		"world_orders": world_orders,
		"player_commands": player_commands,
		"economy": economy,
		"projectiles": projectiles,
		"fire_fields": fire_fields,
		"transports": transports,
		"harvesting": harvesting,
		"construction": construction,
		"stratagems": stratagems,
		"command_rules": command_rules,
		"rules": rules,
		"nav": nav,
		"visibility": visibility,
		"automatic_gates": automatic_gates,
		"clock": clock,
		"effects": effects,
	}
