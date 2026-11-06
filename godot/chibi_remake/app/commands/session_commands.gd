extends "res://named_port.gd"
## session: explicit commands, validated once at the composition boundary.
const CONTRACTS := {"scene_controller": ["_apply_save", "_save_extra", "_save_game", "_screenshot", "_sheet", "_view_hud", "focus_group", "_notification", "_unhandled_input", "_process"], "cheat_controller": ["_cheat_adjacent_level", "_set_cheat_input", "handle_cheat_input"], "cheat_rules": ["_step_auto_control"], "bootstrap": ["_ready"], "duel_controller": ["_present_duel"]}
var _provider_scene_controller: WeakRef
var _provider_cheat_controller: WeakRef
var _provider_cheat_rules: WeakRef

var _provider_bootstrap: WeakRef

var _provider_duel_controller: WeakRef

func _sheet(p: String) -> Texture2D:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return null
	return provider._sheet(p)

func focus_group(n: int) -> bool:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return false
	return provider.focus_group(n)

func _apply_save() -> bool:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return false
	return provider._apply_save()

func _save_extra() -> Dictionary:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return {}
	return provider._save_extra()

func _save_game(slot := 0, title := "") -> bool:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return false
	return provider._save_game(slot, title)

func _view_hud() -> void:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return
	provider._view_hud()

func _screenshot() -> void:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return
	await provider._screenshot()

func _set_cheat_input(opened: bool) -> void:
	var provider = _require(_provider_cheat_controller, "cheat_controller")
	if provider == null: return
	provider._set_cheat_input(opened)

func handle_cheat_input(event: InputEvent) -> bool:
	var provider = _require(_provider_cheat_controller, "cheat_controller")
	if provider == null: return false
	return provider.handle_cheat_input(event)

func _step_auto_control() -> void:
	var provider = _require(_provider_cheat_rules, "cheat_rules")
	if provider == null: return
	provider._step_auto_control()

func _cheat_adjacent_level(levels: Array, current: String, direction: int) -> String:
	var provider = _require(_provider_cheat_controller, "cheat_controller")
	if provider == null: return ""
	return provider._cheat_adjacent_level(levels, current, direction)

func connect_services(services: Dictionary) -> Array:
	_provider_scene_controller = weakref(services["scene_controller"]) if services.get("scene_controller") != null else null
	_provider_cheat_controller = weakref(services["cheat_controller"]) if services.get("cheat_controller") != null else null
	_provider_cheat_rules = weakref(services["cheat_rules"]) if services.get("cheat_rules") != null else null
	_provider_bootstrap = weakref(services["bootstrap"]) if services.get("bootstrap") != null else null
	_provider_duel_controller = weakref(services["duel_controller"]) if services.get("duel_controller") != null else null
	return validate_services(services, CONTRACTS)

func disconnect_services() -> void:
	_provider_duel_controller = null
	_provider_bootstrap = null
	_provider_scene_controller = null
	_provider_cheat_controller = null
	_provider_cheat_rules = null

func bootstrap_ready() -> void:
	var provider = _require(_provider_bootstrap, "bootstrap")
	if provider == null: return
	await provider._ready()

func notify_window(what: int) -> void:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return
	provider._notification(what)

func unhandled_input(event: InputEvent) -> void:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return
	provider._unhandled_input(event)

func process_frame(delta: float) -> void:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return
	provider._process(delta)

func present_duel(outcome: String, onm: String, enm: String, ticket: int) -> void:
	var provider = _require(_provider_duel_controller, "duel_controller")
	if provider == null: return
	provider._present_duel(outcome, onm, enm, ticket)
