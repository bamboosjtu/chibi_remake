extends "res://named_port.gd"
## Explicit capabilities used by the simulation's cheat/idle-control rules.
const CONTRACTS := {"abilities":["_jimou_caster_for_selection"],"officer_pool":["_sync_officer_to_pool"],"combat":["_nearest_enemy"],"command_groups":["_cancel_unit_command"]}
var _provider_abilities: WeakRef
var _provider_officer_pool: WeakRef
var _provider_combat: WeakRef
var _provider_command_groups: WeakRef
func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_abilities = weakref(services.abilities) if services.has("abilities") else null
	_provider_officer_pool = weakref(services.officer_pool) if services.has("officer_pool") else null
	_provider_combat = weakref(services.combat) if services.has("combat") else null
	_provider_command_groups = weakref(services.command_groups) if services.has("command_groups") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing
func disconnect_services() -> void:
	_provider_abilities = null
	_provider_officer_pool = null
	_provider_combat = null
	_provider_command_groups = null
func selected_officer() -> Dictionary:
	return _require(_provider_abilities,"abilities")._jimou_caster_for_selection()
func sync_officer(officer: Dictionary) -> void:
	_require(_provider_officer_pool,"officer_pool")._sync_officer_to_pool(officer)
func nearest(unit: Dictionary, distance: float) -> Dictionary:
	return _require(_provider_combat,"combat")._nearest_enemy(unit,distance)
func attack(unit: Dictionary, target: Dictionary) -> void:
	_require(_provider_command_groups,"command_groups")._cancel_unit_command(unit)
	unit.target = target
	unit.state = "attack"
	unit.repath = 0.0
