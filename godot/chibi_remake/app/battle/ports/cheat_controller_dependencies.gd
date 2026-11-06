extends "res://named_port.gd"
## Scene actions and cheat rules are separate capabilities.
func action(command: String) -> String:
	var provider = _require(_provider_cheat_rules, "cheat_rules")
	if provider == null: return ""
	return provider._cheat_action(command)

func feedback(message: String) -> void:
	var provider = _require(_provider_battle_simulation, "battle_simulation")
	if provider == null: return
	provider._feedback(message)

func screenshot() -> void:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return
	provider._screenshot()

const CONTRACTS := {"battle_simulation": ["_feedback"], "cheat_rules": ["_cheat_action"], "scene_controller": ["_screenshot"]}
var _provider_battle_simulation: WeakRef
var _provider_cheat_rules: WeakRef
var _provider_scene_controller: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.get("battle_simulation") != null else null
	_provider_cheat_rules = weakref(services["cheat_rules"]) if services.get("cheat_rules") != null else null
	_provider_scene_controller = weakref(services["scene_controller"]) if services.get("scene_controller") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_battle_simulation = null
	_provider_cheat_rules = null
	_provider_scene_controller = null
