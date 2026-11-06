extends RefCounted
## Animation row queries shared by simulation death timing and presentation.
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
