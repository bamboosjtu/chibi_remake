extends SceneTree
class Data extends RefCounted:
	var map_data := {"terrainW":320,"terrainH":240}
	var player_owner := 3
	var tile_w := 44.0
	var tile_hw := 22.0
	var tile_hh := 11.0
	var units := [
		{"owner":3,"is_building":false,"alive":true,"ax":10.0,"ay":20.0},
		{"owner":3,"is_building":false,"alive":true,"ax":14.0,"ay":16.0},
		{"owner":2,"is_building":false,"alive":true,"ax":100.0,"ay":100.0},
		{"owner":3,"is_building":true,"alive":true,"ax":200.0,"ay":200.0},
	]

func _initialize() -> void:
	var data := Data.new()
	var reader = load("res://app/read_models/battle_queries.gd").new(data)
	var bounds: Vector2 = reader.camera_bounds()
	var center: Vector2 = reader.opening_camera_position()
	var tiles: Vector3 = reader.camera_tile_geometry()
	assert(bounds==Vector2(320,240) and center==Vector2(12,18) and tiles==Vector3(44,22,11))
	bounds.x=-1; center.x=-1; tiles.x=-1
	assert(data.map_data.terrainW==320 and data.units[0].ax==10 and data.tile_w==44)
	data.map_data.terrainW=640; data.units[0].ax=20
	assert(reader.camera_bounds()==Vector2(640,240) and reader.opening_camera_position()==Vector2(17,18))
	data.units.clear()
	assert(reader.opening_camera_position()==Vector2(320,120))
	print("CAMERA READ MODEL PASS detached values / current world data / opening filter / empty army fallback")
	quit()
