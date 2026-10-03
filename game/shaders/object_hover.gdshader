shader_type canvas_item;
render_mode unshaded;
// source: authored registered selection matte, output/imagegen/engineer-mask-prompt.txt.
// Godot4.5 CanvasItem shader reference: TEXTURE_PIXEL_SIZE, UV, COLOR.
// source: Godot CanvasItem texture RGBA; wagon cutouts use alpha, engine-room mattes red.
uniform bool coverage_from_alpha = false;
uniform vec4 clip_bounds = vec4(0.0, 0.0, 1.0, 1.0);
void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	float center = coverage_from_alpha ? sample_color.a : sample_color.r;
	vec2 step_size = TEXTURE_PIXEL_SIZE;
	float surround = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec4 neighbour = texture(TEXTURE, UV + vec2(float(x), float(y)) * step_size);
			surround = max(surround, coverage_from_alpha ? neighbour.a : neighbour.r);
		}
	}
	float edge = max(0.0, surround - center);
	float inside = step(clip_bounds.x, UV.x) * step(clip_bounds.y, UV.y) * step(UV.x, clip_bounds.z) * step(UV.y, clip_bounds.w);
	COLOR = vec4(1.0, 0.81, 0.49, (edge * 0.72 + center * 0.07) * inside);
}
