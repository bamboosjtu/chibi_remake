extends "res://named_port.gd"
## Explicit sibling capabilities for controller.

func _build_campaign_dialog() -> void:
	var provider = _require(_provider_campaign_dialog, "campaign_dialog")
	if provider == null: return
	provider._build_campaign_dialog()

func _build_level_dialog() -> void:
	var provider = _require(_provider_level_dialog, "level_dialog")
	if provider == null: return
	provider._build_level_dialog()

func _build_styles() -> void:
	var provider = _require(_provider_menu_styles, "menu_styles")
	if provider == null: return
	provider._build_styles()

func _campaign_alias(s: String) -> String:
	var provider = _require(_provider_campaign_dialog, "campaign_dialog")
	if provider == null: return ""
	return provider._campaign_alias(s)

func _fill_level_list() -> void:
	var provider = _require(_provider_level_dialog, "level_dialog")
	if provider == null: return
	provider._fill_level_list()

func _first_row() -> Button:
	var provider = _require(_provider_level_dialog, "level_dialog")
	if provider == null: return null
	return provider._first_row()

func _focus_row(n: int) -> void:
	var provider = _require(_provider_level_dialog, "level_dialog")
	if provider == null: return
	provider._focus_row(n)

func _move_campaign(d: int) -> void:
	var provider = _require(_provider_campaign_dialog, "campaign_dialog")
	if provider == null: return
	provider._move_campaign(d)

func _refresh_campaign_cursor() -> void:
	var provider = _require(_provider_campaign_dialog, "campaign_dialog")
	if provider == null: return
	provider._refresh_campaign_cursor()

func _release_focus() -> void:
	var provider = _require(_provider_campaign_dialog, "campaign_dialog")
	if provider == null: return
	provider._release_focus()

func _report_campaign_dialog() -> void:
	var provider = _require(_provider_automation_driver, "automation_driver")
	if provider == null: return
	provider._report_campaign_dialog()

func _report_level_dialog() -> void:
	var provider = _require(_provider_automation_driver, "automation_driver")
	if provider == null: return
	provider._report_level_dialog()

func _report_scroll_state() -> void:
	var provider = _require(_provider_automation_driver, "automation_driver")
	if provider == null: return
	provider._report_scroll_state()

func _run_keytest() -> void:
	var provider = _require(_provider_automation_driver, "automation_driver")
	if provider == null: return
	provider._run_keytest()

func _run_mouse_click(target: String) -> void:
	var provider = _require(_provider_automation_driver, "automation_driver")
	if provider == null: return
	provider._run_mouse_click(target)

func _run_mouse_matrix() -> void:
	var provider = _require(_provider_automation_driver, "automation_driver")
	if provider == null: return
	provider._run_mouse_matrix()

func _scroll_by(delta: int) -> void:
	var provider = _require(_provider_level_dialog, "level_dialog")
	if provider == null: return
	provider._scroll_by(delta)

func _scroll_to(pos: int) -> void:
	var provider = _require(_provider_level_dialog, "level_dialog")
	if provider == null: return
	provider._scroll_to(pos)

func _set_campaign(camp: String, refresh: bool) -> void:
	var provider = _require(_provider_campaign_dialog, "campaign_dialog")
	if provider == null: return
	provider._set_campaign(camp, refresh)

func _set_title_visible(v: bool) -> void:
	var provider = _require(_provider_campaign_dialog, "campaign_dialog")
	if provider == null: return
	provider._set_title_visible(v)

const CONTRACTS := {"automation_driver": ["_report_campaign_dialog", "_report_level_dialog", "_report_scroll_state", "_run_keytest", "_run_mouse_click", "_run_mouse_matrix"], "campaign_dialog": ["_build_campaign_dialog", "_campaign_alias", "_move_campaign", "_refresh_campaign_cursor", "_release_focus", "_set_campaign", "_set_title_visible"], "level_dialog": ["_build_level_dialog", "_fill_level_list", "_first_row", "_focus_row", "_scroll_by", "_scroll_to"], "menu_styles": ["_build_styles"]}
var _provider_automation_driver: WeakRef
var _provider_campaign_dialog: WeakRef
var _provider_level_dialog: WeakRef
var _provider_menu_styles: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_automation_driver = weakref(services["automation_driver"]) if services.get("automation_driver") != null else null
	_provider_campaign_dialog = weakref(services["campaign_dialog"]) if services.get("campaign_dialog") != null else null
	_provider_level_dialog = weakref(services["level_dialog"]) if services.get("level_dialog") != null else null
	_provider_menu_styles = weakref(services["menu_styles"]) if services.get("menu_styles") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_automation_driver = null
	_provider_campaign_dialog = null
	_provider_level_dialog = null
	_provider_menu_styles = null
