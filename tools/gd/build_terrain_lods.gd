extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var manifest := ""
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--manifest="): manifest = arg.substr(11)
		if arg.begins_with("--output="): output = arg.substr(9)
	var maps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest)).maps
	for id in maps:
		var directory := output.path_join("art/full/terrain_chunks/" + id)
		if DirAccess.make_dir_recursive_absolute(directory) != OK: quit(1); return
		var data: Dictionary = maps[id]
		var record := {"schemaVersion":1,"map":id,"worldWidth":data.worldWidth,"worldHeight":data.worldHeight,"budgetBytes":402653184,"tileWorldSize":256,"chunks":[]}
		for q in range(4):
			var source := Image.new()
			if source.load(str(data.terrainHD[q])) != OK: quit(1); return
			var origin := Vector2(float(data.worldWidth)*0.5*(q%2),float(data.worldHeight)*0.5*(q/2))
			for y in range(0,source.get_height(),1024):
				for x in range(0,source.get_width(),1024):
					var size := Vector2i(mini(1024,source.get_width()-x),mini(1024,source.get_height()-y))
					var base := source.get_region(Rect2i(x,y,size.x,size.y))
					var chunk := {"rect":[origin.x+x/4.0,origin.y+y/4.0,size.x/4.0,size.y/4.0],"lods":{}}
					for scale in [4,2,1]:
						var tile: Image = base.duplicate()
						if scale<4: tile.resize(maxi(1,size.x*scale/4),maxi(1,size.y*scale/4),Image.INTERPOLATE_LANCZOS)
						# Preserve the established q95 source -> q78 transport sequence.
						var jpeg: PackedByteArray = tile.save_jpg_to_buffer(0.95)
						var decoded := Image.new()
						if decoded.load_jpg_from_buffer(jpeg) != OK: quit(1); return
						var name := "%d_%d_%d_%d.bin" % [q,x,y,scale]
						if decoded.save_jpg(directory.path_join(name),0.78) != OK: quit(1); return
						chunk.lods[str(scale)] = {"texture":"res://art/full/terrain_chunks/"+id+"/"+name,"scale":scale,"bytes":tile.get_width()*tile.get_height()*4}
					record.chunks.append(chunk)
		FileAccess.open(directory.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(record))
		print("TERRAIN LODS PASS ",id," chunks=",record.chunks.size())
	quit()
