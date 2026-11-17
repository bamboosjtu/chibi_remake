extends RefCounted
## Bound reads before parsing; strip strings/scalars natively before counting
## nesting, so a normal save does not require a script loop over every byte.
const MAX_BYTES := 32 * 1024 * 1024
const MAX_DEPTH := 64
static var _non_structure: RegEx

static func valid_text(text: String) -> bool:
	if text.length() > MAX_BYTES or text.to_utf8_buffer().size() > MAX_BYTES: return false
	if _non_structure == null:
		_non_structure = RegEx.new()
		_non_structure.compile('"[^"\\\\]*(?:\\\\.[^"\\\\]*)*"|[^{}\\[\\]"]+')
	var structure := _non_structure.sub(text, "", true).to_utf8_buffer()
	var depth := 0
	for character in structure:
		if character in [123,91]:
			depth += 1
			if depth > MAX_DEPTH: return false
		elif character in [125,93]:
			depth -= 1
			if depth < 0: return false
	return depth == 0
