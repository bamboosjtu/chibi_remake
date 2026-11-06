extends RefCounted
const Textures = preload("res://presentation/battle/runtime_textures.gd")
var data: Dictionary
var commands := {}
var frames := {}
var textures := {}
var hotkeys: Array
var skin := preload("res://presentation/hud/battle_skin.gd").new()

func work_icon(row: Dictionary) -> Texture2D:
	var resource := str(row.get("sell", ""))
	if resource != "": return skin.texture_for("res_" + resource)
	return icon(164)

func decorate_sale(parent: Control, selling: bool) -> void:
	var coin := parent.get_node_or_null("SaleCoin") as TextureRect
	if coin == null and selling:
		coin = TextureRect.new()
		coin.name = "SaleCoin"
		coin.texture = skin.texture_for("res_gold")
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(coin)
		coin.anchor_left = 0.5; coin.anchor_right = 1.0
		coin.anchor_bottom = 0.5
	if coin != null: coin.visible = selling

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/commands.json"))
	hotkeys = data.hotkeys.order
	for entry in data.commands: commands[int(entry.command)] = entry
	for entry in data.registry: frames[int(entry.frame)] = entry

func spec(id: int) -> Dictionary:
	if not commands.has(id): return {"id":0,"f":0,"n":"","cmd":"","disabled":true}
	var row: Dictionary = commands[id]
	return {"id":id,"f":int(row.frame),"n":str(row.name),"cmd":str(data.runtimeActions.get(str(id),""))}

func panel(kind: String) -> Array:
	var out := []
	for id in data.panels.get(kind,data.panels.combat).slots: out.append(spec(int(id)) if id != null else spec(0))
	return out

func icon(frame: int, _state := 0) -> Texture2D:
	if frame in [123,124]:
		var key := "page%d" % frame
		if not textures.has(key):
			var image := Image.new()
			var points := "9,14 31,14 20,29" if frame == 123 else "9,27 31,27 20,12"
			image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 40 40"><rect x="1" y="1" width="38" height="38" fill="#252323" stroke="#b18b41" stroke-width="2"/><polygon points="%s" fill="#ffdc64" stroke="#fff2a0" stroke-width="2"/></svg>' % points)
			textures[key] = ImageTexture.create_from_image(image)
		return textures[key]
	if frame == 170:
		if not textures.has("cancel"):
			var image := Image.new()
			image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 40 40"><rect x="1" y="1" width="38" height="38" fill="#252323" stroke="#b18b41" stroke-width="2"/><path d="M11 11L29 29M29 11L11 29" stroke="#700000" stroke-width="9"/><path d="M10 10L28 28M28 10L10 28" stroke="#ff2424" stroke-width="6"/></svg>')
			textures.cancel = ImageTexture.create_from_image(image)
		return textures.cancel
	if frame in [167,168]:
		var key: String="form" if frame==167 else "join"
		if not textures.has(key):textures[key]=Textures.load_texture("res://art/full/ui/command-%s-hd-v2.png" % key,ResourceLoader.CACHE_MODE_REUSE,"formal")
		return textures[key]
	var cell := frame-98 if frame>=98 and frame<=106 else (frame-104 if frame>=113 and frame<=122 else (frame-135 if frame>=154 and frame<=169 else -1))
	if cell<0:return null
	if not textures.has("hd"):textures.hd=Textures.load_texture("res://art/full/ui/cmd-icons-redraw-v3.png",ResourceLoader.CACHE_MODE_REUSE,"formal")
	# Painted cells have measured separators, rather than a perfectly uniform grid.
	var xs := [0,212,430,644,862,1080,1294,1484]
	var ys := [0,210,420,621,825,1054]
	var col := cell%7
	var row := cell/7
	var atlas := AtlasTexture.new()
	atlas.atlas = textures.hd
	atlas.region = Rect2(xs[col],ys[row],xs[col+1]-xs[col],ys[row+1]-ys[row])
	atlas.filter_clip = true
	return atlas

func configure(specs: Array) -> Dictionary:
	var slots := [];slots.resize(int(data.panel_capacity));slots.fill({})
	var mask := 0
	for index in range(mini(slots.size(),specs.size())):
		var item: Dictionary=specs[index]
		slots[index]=item
		if bool(item.get("enabled",not item.get("disabled",false))) and str(item.get("n",item.get("text","")))!="":mask|=1<<index
	return {"slots":slots,"mask":mask}
