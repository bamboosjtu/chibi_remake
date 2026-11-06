extends SceneTree
## 制作绘画参考预览：原图只作最近邻放大，绝不作为正式高清交付。
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/production/catalog.json"))
	var output := "res://../../_work/remaster-final/pose-references/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var count := 0
	for page in catalog.pages:
		if int(page.sourceId) < 33 or int(page.sourceId) == 52: continue
		var source := Image.new()
		assert(source.load(str(page.reference)) == OK)
		if page.has("renderColumns") and int(page.sourceId) >= 34:
			var packed := Image.create(int(page.renderColumns)*int(page.frameWidth), int(page.renderRows)*int(page.frameHeight), false, Image.FORMAT_RGBA8)
			for frame in range(int(page.sourceFrameCount)):
				var dest := int(page.renderFrameMap[frame])
				if dest < 0: continue
				var shape := Vector2i(int(page.frameWidth), int(page.frameHeight))
				packed.blit_rect(source, Rect2i(Vector2i(frame % int(page.columns), frame / int(page.columns))*shape, shape), Vector2i(dest % int(page.renderColumns), dest / int(page.renderColumns))*shape)
			source = packed
		var factor := minf(8.0, 2560.0 / maxf(source.get_width(), source.get_height()))
		source.resize(maxi(1, roundi(source.get_width()*factor)), maxi(1, roundi(source.get_height()*factor)), Image.INTERPOLATE_NEAREST)
		assert(source.save_png(ProjectSettings.globalize_path(output + str(page.assetId) + ".png")) == OK)
		count += 1
	# 单个正面角色仅传递服装材质，避免大幅 HD 页覆盖动作参考的方向顺序。
	var hero := Image.new()
	assert(hero.load(ProjectSettings.globalize_path("res://art/full/units/033/page-00-v2.png")) == OK)
	var cell := Vector2i(hero.get_width()/5, hero.get_height()/4)
	assert(hero.get_region(Rect2i(0, 3*cell.y, cell.x, cell.y)).save_png(ProjectSettings.globalize_path(output + "units-033-style.png")) == OK)
	print("REFERENCE PREVIEWS ONLY: ",count)
	quit()
