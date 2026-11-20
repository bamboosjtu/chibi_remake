extends RefCounted
## Optional backend discovery belongs to startup, never to a math/tick query.
const Kernel = preload("res://simulation/native/math_kernel.gd")
const Catalog = preload("res://simulation/definitions/rule_catalog.gd")
const Footprint = preload("res://simulation/navigation/unit_footprint.gd")
const Status = preload("res://simulation/definitions/status_fields.gd")
const Action = preload("res://simulation/definitions/timing/action_visual.gd")
static var _attempted := false
static var _errors: Array = []

static func initialize() -> Array:
	if not _attempted:
		_attempted = true
		_errors = _load()
	return _errors.duplicate()

static func _load() -> Array:
	if not ClassDB.class_exists("ChibiSimulationMath") and OS.has_feature("windows"):
		var available := FileAccess.file_exists("res://simulation/native/bin/ChibiSimulationMath.dll") or FileAccess.file_exists(OS.get_executable_path().get_base_dir().path_join("ChibiSimulationMath.dll"))
		if available:
			GDExtensionManager.load_extension("res://simulation/native/sim_math.gdextension")
			if not ClassDB.class_exists("ChibiSimulationMath"): return ["Simulation math backend failed to load"]
	if not ClassDB.class_exists("ChibiSimulationMath"): return []
	var provider: Object = ClassDB.instantiate("ChibiSimulationMath")
	for method in ["attack_fast", "fingerprint", "configure"]:
		if not provider.has_method(method): return ["Simulation math backend lacks " + method]
	if provider.fingerprint() != Catalog.get_catalog("native_math.json").sourceSignature:
		return ["Simulation math source/binary mismatch"]
	var offsets: Array = []
	for cls in range(4):
		for parity in range(2): offsets.append(Footprint.offsets(cls, parity))
	provider.configure(Status.KEYS, Action.CLIP_NAME, Action.FRAME_TICKS, Status.CONFUSION, Status.ROLLING, Footprint.CLASS_BY_UNIT, offsets, preload("res://simulation/definitions/unit_roles.gd").ids("naval"), preload("res://simulation/definitions/unit_roles.gd").transport_id())
	Kernel.install(provider)
	return []
