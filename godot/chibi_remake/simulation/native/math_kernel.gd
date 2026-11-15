extends RefCounted
## Optional pure math backend. Both paths implement the same persistent state.
const Status=preload("res://simulation/definitions/status_fields.gd")
const Action=preload("res://simulation/definitions/action_visual.gd")
static var force_script := false
static var _tried := false
static var _native: Object
static func shutdown() -> void:
	_native=null;_tried=false

static func get_kernel(for_connection := false) -> Object:
	if force_script and not for_connection:return null
	if not _tried:
		_tried=true
		if not ClassDB.class_exists("ChibiSimulationMath") and OS.has_feature("windows"):
			var available:=FileAccess.file_exists("res://simulation/native/bin/ChibiSimulationMath.dll") or FileAccess.file_exists(OS.get_executable_path().get_base_dir().path_join("ChibiSimulationMath.dll"))
			if available:GDExtensionManager.load_extension("res://simulation/native/sim_math.gdextension")
		if ClassDB.class_exists("ChibiSimulationMath"):
			var provider: Object=ClassDB.instantiate("ChibiSimulationMath")
			if not provider.has_method("attack_fast"):return null
			var contract=JSON.parse_string(FileAccess.get_file_as_string("res://data/db/native_math.json"))
			if not contract is Dictionary or provider.fingerprint()!=contract.get("sourceSignature",""):
				push_error("Simulation math source/binary mismatch");return null
			var offsets: Array=[]
			for cls in range(4):
				for parity in range(2):offsets.append(preload("res://simulation/systems/unit_footprint.gd").offsets(cls,parity))
			provider.configure(Status.KEYS,Action.CLIP_NAME,Action.FRAME_TICKS,Status.CONFUSION,Status.ROLLING,preload("res://simulation/systems/unit_footprint.gd").CLASS_BY_UNIT,offsets,preload("res://simulation/battle_config.gd").NAVAL_UNITS)
			_native=provider
	return _native
