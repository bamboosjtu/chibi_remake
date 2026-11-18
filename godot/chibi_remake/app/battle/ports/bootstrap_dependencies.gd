extends "res://named_port.gd"
## bootstrap: explicit callable dependencies; no battle scene reference.

func _apply_save() -> bool:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return false
	return provider._apply_save()

func _build_terrain() -> void:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return
	provider._build_terrain()

func _build_ui() -> void:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return
	provider._build_ui()

func _demo() -> void:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return
	provider._demo()

func _fatal(msg: String) -> void:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return
	provider._fatal(msg)

func _screenshot() -> void:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return
	provider._screenshot()

func _setup_camera() -> void:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return
	provider._setup_camera()

func _show_end(kind: int) -> void:
	var provider = _require(_provider_campaign, "campaign")
	if provider == null: return
	provider._show_end(kind)

func _write_smoke(ok: bool, why: String) -> void:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return
	provider._write_smoke(ok, why)

const CONTRACTS := {"campaign": ["_show_end"], "scene_controller": ["_apply_save", "_build_terrain", "_build_ui", "_demo", "_fatal", "_screenshot", "_setup_camera", "_write_smoke", "_schedule_failed_load_return"]}
var _provider_campaign: WeakRef
var _provider_scene_controller: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_campaign = weakref(services["campaign"]) if services.get("campaign") != null else null
	_provider_scene_controller = weakref(services["scene_controller"]) if services.get("scene_controller") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_campaign = null
	_provider_scene_controller = null

func _schedule_failed_load_return() -> void:
	var provider = _require(_provider_scene_controller, "scene_controller")
	if provider == null: return
	provider._schedule_failed_load_return()
