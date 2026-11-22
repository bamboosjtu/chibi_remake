extends RefCounted
const GRID_FALLBACK := 8

## Simulation angles start at east and run clockwise; source sprite rows start north.
static func sprite_direction(screen_direction: int) -> int:
	return (screen_direction + 2) & 7
static func screenshot(node: Node) -> void:
	if DisplayServer.get_name() == "headless":
		print("screenshot skipped (headless)")
		return
	await RenderingServer.frame_post_draw
	var vp_tex: ViewportTexture = node.get_viewport().get_texture()
	if vp_tex == null:
		print("screenshot skipped (no viewport texture)")
		return
	var img: Image = vp_tex.get_image()
	if img == null:
		print("screenshot skipped (no image)")
		return
	img.save_png("user://chibi_shot.png")
	print("screenshot saved: ", OS.get_user_data_dir(), "/chibi_shot.png")

# ------------------------------------------------- unit nodes & frames (A/B) ----

static func frame_rect(u: Dictionary, f: int) -> Rect2:
	var k: float = float(u.get("k", 1.0))
	var w: float = float(u.w)
	var h: float = float(u.h)
	var grid: int = maxi(1, int(u.get("grid", GRID_FALLBACK)))
	return Rect2((f % grid) * w * k, (f / grid) * h * k, w * k, h * k)

## 某剪辑某朝向的帧序列（无数据返回空数组）。静态：死亡时序在 main._die_step 里要用它，
## 而模拟必须能没有 view 实例地跑完。

static func clip_dir(u: Dictionary, clip: String, dir: int) -> Array:
	var clips = u.get("clips", null)
	if not (clips is Dictionary) or not clips.has(clip):
		return []
	var d = clips[clip]
	if not (d is Array) or d.is_empty():
		return []
	var list = d[dir % d.size()]
	return list if list is Array else []

## 取一帧；无数据返回 -1（调用方回退）

static func clip_frame(u: Dictionary, clip: String, dir: int, step: int) -> int:
	var list: Array = clip_dir(u, clip, dir)
	return -1 if list.is_empty() else int(list[step % list.size()])

# ------------------------------------------------- selection marquee (E) ----
