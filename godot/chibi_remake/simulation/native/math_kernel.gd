extends RefCounted
## Optional pure math backend, installed explicitly by application startup.
static var force_script := false
static var _native: Object

static func shutdown() -> void:
	_native = null

static func install(provider: Object) -> void:
	assert(_native == null, "Native backend may only be installed at startup")
	_native = provider

static func get_kernel(for_connection := false) -> Object:
	if force_script and not for_connection: return null
	return _native
