extends RefCounted
## 探索状态不依赖渲染节点；读档、无视图模拟与小地图共用。
## 44×22 世界像素是一格等距地面，遮罩用半格采样，保持原版阶梯轮廓。
const CELL := Vector2(22, 11)
var width := 0
var height := 0
var explored := PackedByteArray()
var current := PackedByteArray()
var revision := 0
var reveals := PackedInt32Array()
var _sources := {}
var full_reveal := false

func set_full_reveal(enabled: bool) -> void:
	if full_reveal == enabled: return
	full_reveal = enabled
	for i in range(current.size()): current[i] = 1 if full_reveal or reveals[i] > 0 else 0
	revision += 1

func setup(size: Vector2) -> void:
	width = ceili(size.x / CELL.x); height = ceili(size.y / CELL.y)
	explored.resize(width * height); explored.fill(0)
	current.resize(width * height); current.fill(1 if full_reveal else 0)
	reveals.resize(width * height); reveals.fill(0)
	_sources.clear(); revision += 1

static func effective_vision(unit: Dictionary) -> float:
	return float(preload("res://simulation/systems/stratagem_rules.gd").config().farsightCells) if int(unit.get("farsight_t", 0)) > 0 else maxf(0.0, float(unit.get("vision", 0)))

func _cells(position: Vector2, vision: float) -> PackedInt32Array:
	var cells := PackedInt32Array()
	var radius := (vision + 0.5) * 2.0
	var centre := position / CELL
	for y in range(maxi(0, floori(centre.y - radius)), mini(height, ceili(centre.y + radius) + 1)):
		for x in range(maxi(0, floori(centre.x - radius)), mini(width, ceili(centre.x + radius) + 1)):
			if absf(x + 0.5 - centre.x) + absf(y + 0.5 - centre.y) <= radius:
				cells.append(y * width + x)
	return cells

func _reveal(cells: PackedInt32Array, change: int) -> bool:
	var changed := false
	for index in cells:
		reveals[index] += change
		var visible := 1 if reveals[index] > 0 else 0
		if current[index] != visible: changed = true
		current[index] = 1 if full_reveal else visible
		if visible == 1 and explored[index] == 0:
			explored[index] = 1; changed = true
	return changed

func update(units: Array, player: int) -> void:
	var active := {}
	var changed := false
	for i in range(units.size()):
		var unit: Dictionary = units[i]
		if not unit.alive or float(unit.get("die_t", -1)) >= 0 or int(unit.owner) != player or unit.get("attached", false): continue
		# 已建成建筑也提供视野（箭楼/城门/民居/基地）；工地不提供。
		if unit.is_building and bool(unit.get("site", false)): continue
		var key := "u%d" % int(unit.uid) if unit.has("uid") else "i%d" % i
		active[key] = true
		var position := Vector2(floorf(float(unit.ax) / 11) * 11, floorf(float(unit.ay) / 5.5) * 5.5)
		var vision := effective_vision(unit)
		var old: Dictionary = _sources.get(key, {})
		if not old.is_empty() and old.position == position and old.vision == vision: continue
		if not old.is_empty(): changed = _reveal(old.cells, -1) or changed
		var cells := _cells(position, vision)
		changed = _reveal(cells, 1) or changed
		_sources[key] = {"position":position,"vision":vision,"cells":cells}
	for key in _sources.keys():
		if active.has(key): continue
		changed = _reveal(_sources[key].cells, -1) or changed
		_sources.erase(key)
	if changed: revision += 1

func is_visible(pos: Vector2) -> bool:
	var x := floori(pos.x / CELL.x); var y := floori(pos.y / CELL.y)
	return x >= 0 and y >= 0 and x < width and y < height and current[y * width + x] != 0

func snapshot() -> String:
	return Marshalls.raw_to_base64(explored)

func valid_snapshot(encoded: Variant) -> bool:
	if not encoded is String: return false
	if encoded == "": return true # 旧 v4 快照没有探索字段。
	if encoded.length() != 4 * ceili(float(width * height) / 3.0): return false
	var syntax := RegEx.new()
	syntax.compile("^[A-Za-z0-9+/]*={0,2}$")
	if syntax.search(encoded) == null: return false
	var bytes := Marshalls.base64_to_raw(encoded)
	if bytes.size() != width * height: return false
	for b in bytes:
		if b > 1: return false
	return true

func restore(encoded: String, units: Array, player: int) -> void:
	explored.fill(0)
	if encoded != "": explored = Marshalls.base64_to_raw(encoded)
	current.fill(1 if full_reveal else 0); reveals.fill(0); _sources.clear()
	revision += 1; update(units, player)
