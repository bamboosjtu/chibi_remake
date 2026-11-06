extends "res://named_port.gd"
## projectiles: only the state and commands required by this system.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
var _state: WeakRef
var battle: State:
	get: return _state.get_ref()

func _init(data: State) -> void:
	_state = weakref(data)


const CombatRules = preload("res://simulation/systems/combat_rules.gd")

var map_data:
	get: return battle.map_data
	set(value): battle.map_data = value

func _cell_of_px(px: float, py: float) -> Vector2i:
	return _require(_provider_movement, "movement")._cell_of_px(px, py)

func _damage(a: Dictionary, d: Dictionary) -> float:
	return _require(_provider_combat, "combat")._damage(a, d)

func _projectile_arrived(effect: Dictionary) -> void:
	_require(_provider_combat, "combat")._projectile_arrived(effect)

const CONTRACTS := {"combat": ["_damage", "_projectile_arrived"], "movement": ["_cell_of_px"]}
var _provider_combat: WeakRef
var _provider_movement: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_combat = weakref(services["combat"]) if services.has("combat") else null
	_provider_movement = weakref(services["movement"]) if services.has("movement") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_combat = null
	_provider_movement = null
