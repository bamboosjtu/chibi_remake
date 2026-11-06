shader_type canvas_item;
uniform vec4 team_color : source_color = vec4(0.10, 0.70, 0.92, 1.0);
uniform sampler2D team_ramp : filter_linear, repeat_disable;
uniform bool use_source_palette = false;
uniform bool use_redrawn_blue = false;
uniform sampler2D team_mask : filter_nearest, repeat_disable;
void fragment() {
	// fragment COLOR 已含默认纹理采样；再次相乘会错误压暗材质。
	// https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html#color-and-texture
	vec4 base = COLOR;
	vec4 mask_value = texture(team_mask, UV);
	// 导入器可扩展透明边缘的 RGB，透明度必须同时参与遮罩。
	float team_region = mask_value.r * mask_value.a;
	// 重绘画面的布料边缘不再与旧像素遮罩重合。高清母版约定：青蓝色只用于
	// 阵营部件；从实际绘画取色区，保留金属、皮肤和透明边缘。
	if (use_redrawn_blue) {
		float blue_chroma = max(base.g, base.b) - base.r;
		team_region = smoothstep(0.04, 0.22, blue_chroma) * smoothstep(0.01, 0.09, base.b - base.r) * base.a;
	}
	float intensity = max(base.r, max(base.g, base.b));
	vec3 mapped = team_color.rgb * intensity;
	if (use_source_palette) {
		float light = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
		mapped = texture(team_ramp, vec2(light, 0.5)).rgb;
	}
	base.rgb = mix(base.rgb, mapped, team_region);
	COLOR = base;
}
