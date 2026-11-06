extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var battle = load("res://main.gd").new()
	var view := Node2D.new()
	var sound := Node.new()
	battle.scene.view = view
	battle.scene.sfx = sound
	var diagnostics = preload("res://presentation/battle/event_diagnostics.gd").new(false)
	battle._presentation_diagnostics = diagnostics
	var rng_before: int = battle.state.simulation_rng.state
	var tick_before: int = battle.state.sim_tick
	var gold_before: float = battle.state.gold
	battle._on_visual("unknown_visual", [])
	battle._on_visual("unknown_visual", [])
	battle._on_sound("unknown_sound", [])
	assert(diagnostics.snapshot() == {"visual:unknown_visual": 2, "sound:unknown_sound": 1})
	assert(battle.state.simulation_rng.state == rng_before and battle.state.sim_tick == tick_before and battle.state.gold == gold_before)
	var detached: Dictionary = diagnostics.snapshot()
	detached.clear()
	assert(diagnostics.snapshot().size() == 2)
	battle.dispose_services() # Emits the session summary once, including manual exit.
	diagnostics.report()
	view.free()
	sound.free()
	battle.free()
	print("PRESENTATION DIAGNOSTICS PASS release policy / real visual and sound routers / counts / no simulation mutation")
	quit()
