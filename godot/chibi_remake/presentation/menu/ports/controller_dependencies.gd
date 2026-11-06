extends "res://named_port.gd"
## Explicit sibling capabilities for controller.

func _build_campaign_dialog() -> void:
	_require(_provider_campaign_dialog, "campaign_dialog")._build_campaign_dialog()

func _build_level_dialog() -> void:
	_require(_provider_level_dialog, "level_dialog")._build_level_dialog()

func _build_styles() -> void:
	_require(_provider_menu_styles, "menu_styles")._build_styles()

func _campaign_alias(s: String) -> String:
	return _require(_provider_campaign_dialog, "campaign_dialog")._campaign_alias(s)

func _fill_level_list() -> void:
	_require(_provider_level_dialog, "level_dialog")._fill_level_list()

func _first_row() -> Button:
	return _require(_provider_level_dialog, "level_dialog")._first_row()

func _focus_row(n: int) -> void:
	_require(_provider_level_dialog, "level_dialog")._focus_row(n)

func _move_campaign(d: int) -> void:
	_require(_provider_campaign_dialog, "campaign_dialog")._move_campaign(d)

func _refresh_campaign_cursor() -> void:
	_require(_provider_campaign_dialog, "campaign_dialog")._refresh_campaign_cursor()

func _release_focus() -> void:
	_require(_provider_campaign_dialog, "campaign_dialog")._release_focus()

func _report_campaign_dialog() -> void:
	_require(_provider_automation_driver, "automation_driver")._report_campaign_dialog()

func _report_level_dialog() -> void:
	_require(_provider_automation_driver, "automation_driver")._report_level_dialog()

func _report_scroll_state() -> void:
	_require(_provider_automation_driver, "automation_driver")._report_scroll_state()

func _run_keytest() -> void:
	_require(_provider_automation_driver, "automation_driver")._run_keytest()

func _run_mouse_click(target: String) -> void:
	_require(_provider_automation_driver, "automation_driver")._run_mouse_click(target)

func _run_mouse_matrix() -> void:
	_require(_provider_automation_driver, "automation_driver")._run_mouse_matrix()

func _scroll_by(delta: int) -> void:
	_require(_provider_level_dialog, "level_dialog")._scroll_by(delta)

func _scroll_to(pos: int) -> void:
	_require(_provider_level_dialog, "level_dialog")._scroll_to(pos)

func _set_campaign(camp: String, refresh: bool) -> void:
	_require(_provider_campaign_dialog, "campaign_dialog")._set_campaign(camp, refresh)

func _set_title_visible(v: bool) -> void:
	_require(_provider_campaign_dialog, "campaign_dialog")._set_title_visible(v)

const CONTRACTS := {"automation_driver": ["_report_campaign_dialog", "_report_level_dialog", "_report_scroll_state", "_run_keytest", "_run_mouse_click", "_run_mouse_matrix"], "campaign_dialog": ["_build_campaign_dialog", "_campaign_alias", "_move_campaign", "_refresh_campaign_cursor", "_release_focus", "_set_campaign", "_set_title_visible"], "level_dialog": ["_build_level_dialog", "_fill_level_list", "_first_row", "_focus_row", "_scroll_by", "_scroll_to"], "menu_styles": ["_build_styles"]}
var _provider_automation_driver: WeakRef
var _provider_campaign_dialog: WeakRef
var _provider_level_dialog: WeakRef
var _provider_menu_styles: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_automation_driver = weakref(services["automation_driver"]) if services.has("automation_driver") else null
	_provider_campaign_dialog = weakref(services["campaign_dialog"]) if services.has("campaign_dialog") else null
	_provider_level_dialog = weakref(services["level_dialog"]) if services.has("level_dialog") else null
	_provider_menu_styles = weakref(services["menu_styles"]) if services.has("menu_styles") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_automation_driver = null
	_provider_campaign_dialog = null
	_provider_level_dialog = null
	_provider_menu_styles = null
