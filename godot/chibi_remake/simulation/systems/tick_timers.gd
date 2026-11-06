extends RefCounted
## v6：这些字段只存逻辑 tick。旧存档的秒值在入档边界统一迁移。
## Fire fields have their own global update clock; old burn_t/burn_dps remain legacy-only.
const REST_PERIOD = preload("res://simulation/battle_config.gd").REST_TICKS
const BUILD_PERIOD = preload("res://simulation/battle_config.gd").BUILD_STEP_TICKS
const STATUS_DURATION := 800
const LEGACY_TICK_SECONDS := 1.0 / 30.0
const STATUS_KEYS := ["inspired_t", "haste_t", "slow_t", "farsight_t", "confused_t", "ambush_t", "rolling_t"]
const ELAPSED_PERIODS := {"rest_t": REST_PERIOD, "build_t": BUILD_PERIOD,"rolling_ticks":30}

static func valid_snapshot(state: Dictionary, version: int) -> bool:
	for key in STATUS_KEYS + ["hidden_t"] + ELAPSED_PERIODS.keys():
		if not state.has(key): continue
		var value = state[key]
		if value == null and version < 6: continue # 旧档缺省字段曾写为 null。
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0:
			return false
		var limit := STATUS_DURATION if key in STATUS_KEYS or key=="hidden_t" else int(ELAPSED_PERIODS[key])
		if version >= 6:
			if float(value) != floorf(float(value)): return false
			if float(value) > limit or (ELAPSED_PERIODS.has(key) and float(value) == limit): return false
		elif float(value) > limit * LEGACY_TICK_SECONDS + 0.000001:
			return false
	return true

static func restore(state: Dictionary, version: int, unit: Dictionary) -> void:
	for key in STATUS_KEYS + ELAPSED_PERIODS.keys():
		var value = state.get(key,state.get("hidden_t",0) if key=="ambush_t" else null)
		var ticks := 0
		if value != null:
			ticks = int(value) if version >= 6 else roundi(float(value) / LEGACY_TICK_SECONDS)
		var limit := STATUS_DURATION if key in STATUS_KEYS or key=="hidden_t" else int(ELAPSED_PERIODS[key]) - 1
		unit[key] = clampi(ticks, 0, limit)

static func step_statuses(unit: Dictionary) -> void:
	for key in STATUS_KEYS:
		unit[key] = maxi(0, int(unit.get(key, 0)) - 1)
