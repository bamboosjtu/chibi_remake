extends Object
## duel controller: composed battle behavior.
const State = preload("res://simulation/state/battle_state.gd")
var battle: State:
	get: return node.state

const SceneServices = preload("res://app/battle/runtime/battle_scene_state.gd")
var scene: SceneServices
var node: Node2D

func _init(services: SceneServices, surface: Node2D) -> void:
	scene = services
	node = surface

func _present_duel(outcome: String, onm: String, enm: String) -> void:
	var movie := "res://media/videos/LDAN.AVI"
	var spans:Array=[[24.0,38.0],[78.0,87.0]] if outcome=="draw" else [[24.0,38.0],[99.0,106.0],[125.0,132.066667]]
	var heading := "%s　对阵　%s" % [onm, enm]
	var ending := heading + "\n" + ("双方交锋，未分胜负" if outcome == "draw" else "%s胜出，%s退阵" % ([onm, enm] if outcome == "win" else [enm, onm]))
	if scene.view != null and scene.view.event_view != null:
		scene.view.event_view.play_media(movie, Callable(), heading, ending, 14.0, spans)
