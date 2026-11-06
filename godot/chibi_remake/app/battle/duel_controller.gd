extends RefCounted
## duel controller: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://app/battle/ports/duel_controller_dependencies.gd")
var battle: State:
	get: return node.state
var ports := Dependencies.new()
const SceneServices = preload("res://app/battle_scene_state.gd")
var scene: SceneServices
var node: Node2D
const RemasterArt = preload("res://presentation/battle/art_catalog.gd")
const SaveSvc = preload("res://app/save_service.gd")    # ARCH-006：存档/读档编排
const View = preload("res://presentation/battle/battle_view.gd")        # ARCH-013：表现层（HUD/相机/单位外观/框选）

func _init(data: State, services: SceneServices, surface: Node2D) -> void:
	scene = services
	node = surface

func _present_duel(outcome: String, onm: String, enm: String, ticket: int) -> void:
	var settle := _complete_duel.bind(ticket, node.world.get_instance_id())
	# The result is rolled once in the simulation. Natural finish and skip use the same
	# one-shot settlement; pausing the tree keeps both combatants in this world.
	var movie := "res://media/videos/LDAN.AVI"
	var spans:Array=[[24.0,38.0],[78.0,87.0]] if outcome=="draw" else [[24.0,38.0],[99.0,106.0],[125.0,132.066667]]
	var heading := "%s　对阵　%s" % [onm, enm]
	var ending := heading + "\n" + ("双方交锋，未分胜负" if outcome == "draw" else "%s胜出，%s退阵" % ([onm, enm] if outcome == "win" else [enm, onm]))
	if scene.view != null and scene.view.event_view != null and scene.view.event_view.play_media(movie, settle, heading, ending, 14.0, spans): return
	settle.call() # Pure simulation or absent media still settles the exact same round.

func _complete_duel(ticket: int, epoch: int) -> void:
	if is_instance_valid(node) and node.world.get_instance_id() == epoch: node.commands.military._resolve_duel(ticket)
