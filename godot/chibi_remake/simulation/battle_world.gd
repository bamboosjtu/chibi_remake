extends RefCounted
## Scene-free domain graph shared by gameplay and snapshot candidates.
var definition: Dictionary = {}
var state := preload("res://simulation/battle_state.gd").new()
var _modules: Dictionary = {}
var _access: Dictionary = {}

func _init() -> void:
	state.simulation_rng.seed = 0x4348494249
	_access["ai"] = preload("res://simulation/ports/ai_access.gd").new(state)
	_access["command_rules"] = preload("res://simulation/ports/command_rules_access.gd").new(state)
	_access["construction_interior"] = preload("res://simulation/ports/construction_interior_access.gd").new(state)
	_access["economy"] = preload("res://simulation/ports/economy_access.gd").new(state)
	_access["fire_fields"] = preload("res://simulation/ports/fire_fields_access.gd").new(state)
	_access["harvesting"] = preload("res://simulation/ports/harvesting_access.gd").new(state)
	_access["player_commands"] = preload("res://simulation/ports/player_commands_access.gd").new(state)
	_access["projectiles"] = preload("res://simulation/ports/projectiles_access.gd").new(state)
	_access["scenario_rules"] = preload("res://simulation/ports/scenario_rules_access.gd").new(state)
	_access["stratagem_rules"] = preload("res://simulation/ports/stratagem_rules_access.gd").new(state)
	_access["transports"] = preload("res://simulation/ports/transports_access.gd").new(state)
	state.economy = preload("res://simulation/systems/economy.gd").new(self)
	state.projectiles = preload("res://simulation/systems/projectiles.gd").new(self)
	state.fire_fields = preload("res://simulation/systems/fire_fields.gd").new(self)
	state.transports = preload("res://simulation/systems/transports.gd").new(self)
	state.harvesting = preload("res://simulation/systems/harvesting.gd").new(self)
	state.construction = preload("res://simulation/systems/construction_interior.gd").new(self)
	state.stratagems = preload("res://simulation/systems/stratagem_rules.gd").new(self)
	_modules["abilities"] = preload("res://simulation/battle/abilities.gd").new(state)
	_modules["ai_economy"] = preload("res://simulation/battle/ai_economy.gd").new(state)
	_modules["ai_orders"] = preload("res://simulation/battle/ai_orders.gd").new(state)
	_modules["battle_simulation"] = preload("res://simulation/battle/battle_simulation.gd").new(state)
	_modules["campaign"] = preload("res://simulation/battle/campaign.gd").new(state)
	_modules["cheat_rules"] = preload("res://simulation/battle/cheat_rules.gd").new(state)
	_modules["combat"] = preload("res://simulation/battle/combat.gd").new(state)
	_modules["command_groups"] = preload("res://simulation/battle/command_groups.gd").new(state)
	_modules["construction_orders"] = preload("res://simulation/battle/construction_orders.gd").new(state)
	_modules["entity_factory"] = preload("res://simulation/battle/entity_factory.gd").new(state)
	_modules["harvest_orders"] = preload("res://simulation/battle/harvest_orders.gd").new(state)
	_modules["interaction_paths"] = preload("res://simulation/battle/interaction_paths.gd").new(state)
	_modules["movement"] = preload("res://simulation/battle/movement.gd").new(state)
	_modules["officer_pool"] = preload("res://simulation/battle/officer_pool.gd").new(state)
	_modules["officer_teams"] = preload("res://simulation/battle/officer_teams.gd").new(state)
	_modules["production"] = preload("res://simulation/battle/production.gd").new(state)
	_modules["selection"] = preload("res://simulation/battle/selection.gd").new(state)
	_modules["spatial_index"] = preload("res://simulation/battle/spatial_index.gd").new(state)
	_modules["technology"] = preload("res://simulation/battle/technology.gd").new(state)
	_modules["transport_orders"] = preload("res://simulation/battle/transport_orders.gd").new(state)
	_modules["unit_actions"] = preload("res://simulation/battle/unit_actions.gd").new(state)
	_modules["world_orders"] = preload("res://simulation/battle/world_orders.gd").new(state)

func connect_services(label: String) -> Dictionary:
	return preload("res://composition_contract.gd").wire(_modules, label, _access)

func simulation_access(domain: String) -> RefCounted:
	return _access[domain]

func dispose() -> void:
	state.effects.invalidate()
	if state.player_commands != null: state.player_commands.clear()
	for service in _modules.values(): service.ports.disconnect_services()
	for access in _access.values(): access.disconnect_services()
	_modules.clear()

func set_definition(data: Dictionary) -> void:
	definition = preload("res://simulation/definitions/frozen_data.gd").copy(data)
