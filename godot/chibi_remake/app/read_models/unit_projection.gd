extends RefCounted
## Owned value records, not copies of unit dictionaries. This object never
## retains a world, a source unit, navigation, or a service.
const Frozen = preload("res://simulation/definitions/frozen_data.gd")
const FIELDS := ["uid","unit","owner","name","alive","die_t","is_building","ax","ay","A","B",
	"hp","maxhp","w","h","k","grid","count","build_frame","state","dir","moved","walk_tick",
	"move_facing","move_started","move_turning","action_phase","attached","site_inside_uid","site_follow_uid",
	"site","gate_open","carry","carry_kind","carry_n","carry_hp","group_officer","officer_might",
	"officer_intellect","mou","status_173","attack","defence","atk_range","vision"]
const OFFICER_FIELDS := ["index","name","tier","level","exp","hasExp","might","intellect","heroType"]
const ROSTER_FIELDS := ["uid","unit","owner","name","alive","die_t","is_building","ax","ay","A","B","hp","maxhp","w","h","attached","site_inside_uid","group_officer"]
const VISUAL_FIELDS := ["uid","unit","owner","alive","die_t","is_building","ax","ay","hp","maxhp","w","h","k","grid","count","build_frame","state","dir","moved","walk_tick","move_facing","action_phase","attached","site_inside_uid","site","gate_open","carry","carry_kind"]
var _world := -1
var _revision := 0
var _units_key: Array = []
var _units: Array = []
var _selected_key: Array = []
var _selected: Array = []
var _sprites := {}
var _footprints := {}
var _indices := {}
var _visuals := {}
var _empty_geometry := Frozen.copy({"cells":[],"outline":[]})
var metrics := {"unitBuilds":0,"selectionBuilds":0,"spriteBuilds":0,"visualBuilds":0}

func invalidate() -> void:
	if _units_key.is_empty(): return
	_revision += 1
	_units_key = []
	_visuals.clear()

func _ensure(data: Object) -> void:
	var identity: int = data.world.get_instance_id()
	if identity == _world: return
	_world = identity
	_units_key = []; _units = []; _selected_key = []; _selected = []
	_sprites.clear(); _footprints.clear(); _indices.clear(); _visuals.clear()

func units(data: Object) -> Array:
	_ensure(data)
	var key := [_world, data.sim_tick, data.units.size(), _revision, data.nav.get_instance_id(), data.nav.geometry_revision]
	if key == _units_key: return _units
	var result := []
	var members := {}
	_indices.clear(); _visuals.clear()
	for unit: Dictionary in data.units:
		_indices[int(unit.uid)] = result.size()
		var row := _scalars(unit,ROSTER_FIELDS)
		var officer: Dictionary = unit.get("officer",{})
		row.officer = {"index":int(officer.index),"name":str(officer.get("name",""))} if not officer.is_empty() else {}
		row.officer.make_read_only(); row.make_read_only()
		result.append(row); members[int(unit.uid)] = true
	for uid in _footprints.keys():
		if not members.has(uid): _footprints.erase(uid)
	result.make_read_only()
	_units_key = key; _units = result; metrics.unitBuilds += 1
	return result

func selection(data: Object) -> Array:
	_ensure(data)
	# Selection/health may change while paused, outside a simulation update.
	# Compare only displayed scalars; never key a cache with source dictionaries.
	var key: Array = [_world,data.nav.get_instance_id(),data.nav.geometry_revision]
	for unit: Dictionary in data.selected:
		for field in FIELDS: key.append(unit.get(field))
		for field in OFFICER_FIELDS: key.append(unit.get("officer",{}).get(field))
		key.append(unit.get("path",[]).size())
	if key == _selected_key: return _selected
	var result := []
	for unit: Dictionary in data.selected: result.append(_record(data,unit))
	result.make_read_only()
	_selected_key = key; _selected = result; metrics.selectionBuilds += 1
	return result

func visual(data: Object, uid: int) -> Dictionary:
	units(data) # Rebuild scalar UID -> array-index lookup at the same boundary.
	if _visuals.has(uid): return _visuals[uid]
	var index: int = _indices.get(uid,-1)
	if index<0 or index>=data.units.size(): return Frozen.copy({})
	var source: Dictionary = data.units[index]
	if int(source.uid) != uid:
		invalidate(); return visual(data,uid)
	var result := _scalars(source,VISUAL_FIELDS)
	result.clips = _sprite(source)
	var footprint := _footprint(data,source)
	result.occupied_cells = footprint.cells
	result.footprint_outline = footprint.outline
	result.make_read_only()
	_visuals[uid] = result; metrics.visualBuilds += 1
	return result

func _scalars(unit: Dictionary, fields: Array) -> Dictionary:
	var result := {"world_id":_world}
	for field in fields:
		if unit.has(field): result[field] = unit[field]
	return result

func _record(data: Object, unit: Dictionary) -> Dictionary:
	var result := _scalars(unit,FIELDS)
	result.path_count = unit.get("path",[]).size()
	var source_officer: Dictionary = unit.get("officer",{})
	var officer := {}
	for field in OFFICER_FIELDS:
		if source_officer.has(field): officer[field] = source_officer[field]
	result.officer = officer
	officer.make_read_only()
	result.make_read_only()
	return result

func _sprite(unit: Dictionary) -> Dictionary:
	var key := [unit.unit,unit.w,unit.h,unit.grid,unit.count,unit.k]
	if not _sprites.has(key):
		_sprites[key] = Frozen.copy(unit.get("clips",{}))
		metrics.spriteBuilds += 1
	return _sprites[key]

func _footprint(data: Object, unit: Dictionary) -> Dictionary:
	if not unit.is_building: return _empty_geometry
	var cells: Array = unit.get("occupied_cells",[])
	var key := [unit.unit,unit.ax,unit.ay,unit.w,data.nav.get_instance_id(),data.nav.geometry_revision,cells.hash()]
	var uid := int(unit.uid)
	if _footprints.has(uid) and _footprints[uid].key == key: return _footprints[uid].value
	if cells.is_empty(): cells = data.nav.building_footprint(int(unit.unit),Vector2(unit.ax,unit.ay),float(unit.w))
	var outline := Array(data.nav.footprint_outline(cells))
	if not outline.is_empty(): outline.append(outline[0])
	var value := {"cells":cells.duplicate(),"outline":outline}
	Frozen.freeze(value)
	_footprints[uid] = {"key":key,"value":value}
	return value

func motion(data: Object) -> Array:
	var result := []
	for unit: Dictionary in data.units:
		result.append({"uid":int(unit.uid),"is_building":bool(unit.is_building),"ax":float(unit.ax),"ay":float(unit.ay),"walk_tick":float(unit.get("walk_tick",0))})
	Frozen.freeze(result)
	return result

func training(data: Object) -> Array:
	var result := []
	for order in data.trainings:
		result.append({"buildingUid":int(order.b.uid),"unit":int(order.unit),"t":float(order.t)})
	Frozen.freeze(result)
	return result

func work(data: Object, uid: int) -> Dictionary:
	for source: Dictionary in data.units:
		if int(source.uid) != uid: continue
		var research: Dictionary = data.commands.technology._research_for_building(source)
		var result := {"busy":bool(data.commands.technology._building_work_busy(source)),"research":{}}
		for field in ["tech","t","owner"]:
			if research.has(field): result.research[field] = research[field]
		Frozen.freeze(result)
		return result
	return Frozen.copy({"busy":false,"research":{}})
