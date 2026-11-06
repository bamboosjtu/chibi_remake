extends "res://named_port.gd"
## Explicit capabilities used by the simulation's cheat/idle-control rules.
const CONTRACTS := {"abilities":["_jimou_caster_for_selection"],"officer_pool":["_sync_officer_to_pool"],"combat":["_nearest_enemy"],"command_groups":["_cancel_unit_command"]}
var _provider_abilities: WeakRef
var _provider_officer_pool: WeakRef
var _provider_combat: WeakRef
var _provider_command_groups: WeakRef
func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_abilities = weakref(services.abilities) if services.get("abilities") != null else null
	_provider_officer_pool = weakref(services.officer_pool) if services.get("officer_pool") != null else null
	_provider_combat = weakref(services.combat) if services.get("combat") != null else null
	_provider_command_groups = weakref(services.command_groups) if services.get("command_groups") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing
func disconnect_services() -> void:
	_provider_abilities = null
	_provider_officer_pool = null
	_provider_combat = null
	_provider_command_groups = null
func selected_officer() -> Dictionary:
	var provider = _require(_provider_abilities,"abilities")
	if provider == null: return {}
	return provider._jimou_caster_for_selection()
func sync_officer(officer: Dictionary) -> void:
	var provider = _require(_provider_officer_pool,"officer_pool")
	if provider == null: return
	provider._sync_officer_to_pool(officer)
func nearest(unit: Dictionary, distance: float) -> Dictionary:
	var provider = _require(_provider_combat,"combat")
	if provider == null: return {}
	return provider._nearest_enemy(unit,distance)
func attack(unit: Dictionary, target: Dictionary) -> void:
	var provider = _require(_provider_command_groups,"command_groups")
	if provider == null: return
	provider._cancel_unit_command(unit)
	unit.target = target
	unit.state = "attack"
	unit.repath = 0.0
