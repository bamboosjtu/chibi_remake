shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// Shift red wood towards purple-red while preserving the brass studs.
	float wood = smoothstep(0.06,0.15,c.r-c.g) * (1.0-smoothstep(0.22,0.38,c.g));
	c.b = mix(c.b, max(c.b,c.r*0.82), wood*0.85);
	COLOR = c;
}
