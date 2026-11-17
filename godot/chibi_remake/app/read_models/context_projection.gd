extends RefCounted
## Value caches for stateful services. Keys contain identities and displayed
## values only; cached records never retain a world, service or source array.
const Frozen = preload("res://simulation/definitions/frozen_data.gd")
var _cache := {}
var metrics := {"visibilityBuilds":0,"clockBuilds":0,"optionBuilds":0,"effectBuilds":0}

func _same(name: String, key: Array) -> bool:
	return _cache.has(name) and _cache[name].key == key

func _store(name: String, key: Array, value):
	Frozen.freeze(value); key.make_read_only()
	_cache[name] = {"key":key,"value":value}
	return value

func visibility(data: Object) -> Dictionary:
	var service = data.visibility
	var key := [data.world.get_instance_id(),service.get_instance_id(),service.revision,service.width,service.height]
	if _same("visibility",key): return _cache.visibility.value
	metrics.visibilityBuilds += 1
	# Strings are immutable. Packed arrays inside read-only dictionaries are not.
	return _store("visibility",key,{"key":key,"size":Vector2i(service.width,service.height),"cell":Vector2(service.CELL),
		"current":Marshalls.raw_to_base64(service.current),"explored":Marshalls.raw_to_base64(service.explored)})

func clock(data: Object) -> Dictionary:
	var key := [data.world.get_instance_id(),data.clock.get_instance_id(),data.clock.speed_index]
	if _same("clock",key): return _cache.clock.value
	metrics.clockBuilds += 1
	return _store("clock",key,{"speed_index":int(data.clock.speed_index),"period":float(data.clock.period()),"labels":data.clock.LABELS.duplicate()})

func options(data: Object) -> Array:
	var key := [data.world.get_instance_id(),data.build_types.hash()]
	if _same("options",key): return _cache.options.value
	var result := []
	for source in data.build_types:
		var row := {}
		for field in ["unit","name","gold","wood","food","stone"]:
			if source.has(field): row[field] = source[field]
		result.append(row)
	metrics.optionBuilds += 1
	return _store("options",key,result)

func effects(data: Object) -> Dictionary:
	var key := [data.world.get_instance_id(),data.projectiles.get_instance_id(),data.fire_fields.get_instance_id(),
		data.visibility.get_instance_id(),data.visibility.revision,data.nav.get_instance_id(),data.nav.geometry_revision]
	# Both effect tables have a domain limit of 100. Inspect only render scalars;
	# manual service updates also invalidate, even without advancing sim_tick.
	for source in data.projectiles.active:
		for field in ["kind","x","y","tx","ty","travel"]: key.append(source[field])
	key.append("fires")
	for source in data.fire_fields.active:
		key.append(int(source.a)); key.append(int(source.b)); key.append(int(source.age))
	if _same("effects",key): return _cache.effects.value
	var projectiles := []
	for source in data.projectiles.active:
		var point: Vector2 = data.projectiles.position_of(source)
		projectiles.append({"kind":str(source.kind),"point":point,"direction":Vector2(source.tx-source.x,source.ty-source.y).normalized(),
			"ratio":float(source.travel)/maxf(1.0,float(data.projectiles.distance(source))),"visible":bool(data.visibility.is_visible(point))})
	var fires := []
	for source in data.fire_fields.active:
		var point: Vector2 = data.nav.anchor_of(int(source.a),int(source.b))
		fires.append({"point":point,"age":int(source.age),"visible":bool(data.visibility.is_visible(point))})
	metrics.effectBuilds += 1
	return _store("effects",key,{"projectiles":projectiles,"fires":fires})
