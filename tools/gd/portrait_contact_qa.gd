extends SceneTree
## 仅生成原版/候选对照缩略图，不改写素材或计为新美术。
const DIGITS := ["111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001", "111100111001111", "111100111101111", "111001001001001", "111101111101111", "111101111001111"]

func _initialize() -> void:
	_run.call_deferred()

func _label(canvas: Image, position: Vector2i, value: int) -> void:
	var offset := 0
	for character in str(value):
		var pattern: String = DIGITS[int(character)]
		for y in range(5):
			for x in range(3):
				if pattern[y * 3 + x] == "1":
					canvas.fill_rect(Rect2i(position.x + offset + x * 3, position.y + y * 3, 3, 3), Color.WHITE)
		offset += 12

func _image(path: String) -> Image:
	var result := Image.new()
	if result.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	result.convert(Image.FORMAT_RGBA8)
	return result

func _run() -> void:
	var file := FileAccess.open("res://art/production/catalog.json", FileAccess.READ)
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	var portraits := {}
	for asset in catalog.assets:
		if str(asset.category) == "officers":
			portraits[int(asset.sourceId)] = asset
	for page in range(5):
		var canvas := Image.create(1056, 1536, false, Image.FORMAT_RGBA8)
		canvas.fill(Color("26231f"))
		for cell in range(24):
			var id := page * 24 + cell
			if not portraits.has(id):
				continue
			var asset: Dictionary = portraits[id]
			var x0 := (cell % 3) * 352
			var y0 := (cell / 3) * 192
			_label(canvas, Vector2i(x0 + 6, y0 + 4), id)
			var source := _image("res://art/production/references/officer-%03d-source.png" % id)
			source.resize(118, 148, Image.INTERPOLATE_NEAREST)
			canvas.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(x0 + 20, y0 + 28))
			var target_path := "res://" + str(asset.target).trim_prefix("godot/chibi_remake/")
			if not FileAccess.file_exists(target_path):
				continue
			var target := _image(target_path)
			if target == null:
				continue
			target.resize(176, 176, Image.INTERPOLATE_LANCZOS)
			canvas.blit_rect(target, Rect2i(Vector2i.ZERO, target.get_size()), Vector2i(x0 + 162, y0 + 16))
		var destination := "res://../../docs/img/officer-qa-%02d.png" % page
		assert(canvas.save_png(ProjectSettings.globalize_path(destination)) == OK)
	print("Five portrait QA contact sheets saved; left=source, right=current candidate, number=stable source ID.")
	quit()
