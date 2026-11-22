extends SceneTree
## Derive compact minimap terrain from the same packaged HD chunks as the world.
## Runs offline once; runtime never decodes all map chunks to draw a minimap.
func _initialize() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.substr(9)
	assert(output!="")
	var maps := {}
	var directory:=DirAccess.open("res://data")
	for filename in directory.get_files():
		if not filename.begins_with("chibi") or not filename.ends_with(".json"):continue
		var id:=filename.trim_suffix(".json")
		var file:=FileAccess.open("res://art/full/terrain_chunks/%s/manifest.json"%id,FileAccess.READ)
		assert(file!=null)
		var manifest: Dictionary=JSON.parse_string(file.get_as_text())
		var factor:=384.0/maxf(float(manifest.worldWidth),float(manifest.worldHeight))
		var canvas:=Image.create(ceili(float(manifest.worldWidth)*factor),ceili(float(manifest.worldHeight)*factor),false,Image.FORMAT_RGB8)
		canvas.fill(Color.BLACK)
		for chunk in manifest.chunks:
			var image:=Image.new()
			var source:=str(chunk.lods["1"].texture)
			var bytes:=FileAccess.get_file_as_bytes(source)
			var error:=image.load_jpg_from_buffer(bytes) if source.ends_with(".bin") else image.load_png_from_buffer(bytes)
			assert(error==OK,source)
			var rect: Array=chunk.rect
			var origin:=Vector2i(roundi(float(rect[0])*factor),roundi(float(rect[1])*factor))
			var end:=Vector2i(roundi((float(rect[0])+float(rect[2]))*factor),roundi((float(rect[1])+float(rect[3]))*factor))
			image.resize(maxi(1,end.x-origin.x),maxi(1,end.y-origin.y),Image.INTERPOLATE_LANCZOS)
			image.convert(Image.FORMAT_RGB8)
			canvas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),origin)
		maps[id]={"width":canvas.get_width(),"height":canvas.get_height(),"png":Marshalls.raw_to_base64(canvas.save_png_to_buffer())}
		print("MINIMAP GENERATED ",id," ",canvas.get_size())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	assert(file!=null);file.store_string(JSON.stringify({"source":"Offline downsample of packaged HD terrain LOD1; generate_minimap_terrain.gd","maps":maps}))
	assert(maps.size()==34)
	print("MINIMAP TERRAIN PASS 34 HD thumbnails")
	quit()
