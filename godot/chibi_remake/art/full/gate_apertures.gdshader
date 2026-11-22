shader_type canvas_item;
render_mode unshaded;
uniform int gate_count = 0;
// world top-left, width, height; slope follows the existing 2:1 wall face.
uniform vec4 gates[32];
uniform float slopes[32];
varying vec2 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
	for (int i=0; i<gate_count; i++) {
		vec2 p = world_position-gates[i].xy;
		float y = p.y-p.x*slopes[i];
		if (p.x>0.0 && p.x<gates[i].z && y>0.0 && y<gates[i].w) discard;
	}
	COLOR = texture(TEXTURE,UV);
}
