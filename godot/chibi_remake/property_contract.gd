extends RefCounted
## Let native properties fall through to Godot; unknown script fields fail loudly.
static var _native: Dictionary = {}
static func reject(owner: Object, key: StringName) -> void:
	var native_class := owner.get_class()
	if not _native.has(native_class):
		var fields := {}
		for property in ClassDB.class_get_property_list(native_class): fields[property.name] = true
		_native[native_class] = fields
	if _native[native_class].has(key) or ClassDB.class_has_method(native_class,"get_"+str(key)) or ClassDB.class_has_method(native_class,"set_"+str(key)): return
	preload("res://composition_contract.gd").abort_if_broken("unknown state property",[{"provider":owner.get_script().resource_path,"method":str(key)}])
