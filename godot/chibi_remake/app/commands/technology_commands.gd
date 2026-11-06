extends "res://named_port.gd"
## technology: explicit commands, validated once at the composition boundary.
const CONTRACTS := {"technology": ["_ai_side", "_apply_tech_bonuses", "_apply_tech_effects", "_building_work_busy", "_cancel_tech", "_combat_tech_category", "_combat_tech_value", "_is_melee_unit", "_is_worker_unit", "_player_unit_count", "_process_tech", "_queue_research", "_research_for_building", "_start_tech", "_tech_for", "_tech_line_of", "tech_block_reason", "tech_cost", "tech_cost_text", "tech_effect_desc", "tech_is_next", "tech_is_sell", "tech_research_active", "tech_research_name", "tech_research_remaining", "tech_row", "tech_rows_for_building", "tech_tip", "tech_unlocked"]}
var _provider_technology: WeakRef

func _is_worker_unit(u: Dictionary) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider._is_worker_unit(u)

func _ai_side(owner: int) -> Dictionary:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return {}
	return provider._ai_side(owner)

func tech_row(idx: int) -> Dictionary:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return {}
	return provider.tech_row(idx)

func tech_is_sell(idx: int) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider.tech_is_sell(idx)

func _tech_line_of(idx: int) -> String:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return ""
	return provider._tech_line_of(idx)

func tech_is_next(idx: int) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider.tech_is_next(idx)

func tech_rows_for_building(bid: int) -> Array:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return []
	return provider.tech_rows_for_building(bid)

func tech_cost(idx: int) -> Dictionary:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return {}
	return provider.tech_cost(idx)

func tech_cost_text(idx: int) -> String:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return ""
	return provider.tech_cost_text(idx)

func tech_effect_desc(idx: int) -> String:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return ""
	return provider.tech_effect_desc(idx)

func tech_tip(idx: int) -> String:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return ""
	return provider.tech_tip(idx)

func tech_block_reason(idx: int) -> String:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return ""
	return provider.tech_block_reason(idx)

func tech_unlocked(idx: int) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider.tech_unlocked(idx)

func _player_unit_count() -> int:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return 0
	return provider._player_unit_count()

func _research_for_building(building: Dictionary) -> Dictionary:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return {}
	return provider._research_for_building(building)

func _building_work_busy(building: Dictionary) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider._building_work_busy(building)

func _queue_research(owner: int, building: Dictionary, idx: int, ai_dispatch := false) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider._queue_research(owner, building, idx, ai_dispatch)

func _start_tech(idx: int) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider._start_tech(idx)

func _process_tech(_delta: float) -> void:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return
	provider._process_tech(_delta)

func _tech_for(owner: int) -> Dictionary:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return {}
	return provider._tech_for(owner)

func _apply_tech_effects(idx: int, owner := -1) -> void:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return
	provider._apply_tech_effects(idx, owner)

func _cancel_tech() -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider._cancel_tech()

func tech_research_active() -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider.tech_research_active()

func tech_research_name() -> String:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return ""
	return provider.tech_research_name()

func tech_research_remaining() -> int:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return 0
	return provider.tech_research_remaining()

func _is_melee_unit(u: Dictionary) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider._is_melee_unit(u)

func _apply_tech_bonuses(u: Dictionary) -> void:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return
	provider._apply_tech_bonuses(u)

func _combat_tech_category(unit_id: int) -> int:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return 0
	return provider._combat_tech_category(unit_id)

func _combat_tech_value(key: String, first_row: int, category: int, owner := -1) -> float:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return 0.0
	return provider._combat_tech_value(key, first_row, category, owner)

func connect_services(services: Dictionary) -> Array:
	_provider_technology = weakref(services["technology"]) if services.get("technology") != null else null
	return validate_services(services, CONTRACTS)

func disconnect_services() -> void:
	_provider_technology = null
