shader_type canvas_item;
render_mode unshaded;
// source: Godot 4.5 CanvasItem shader reference; authored alpha-contour highlight.
// https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/canvas_item_shader.html
uniform bool highlighted = false;
uniform vec4 frame_uv;
uniform vec4 highlight_color : source_color = vec4(1.0, 0.76, 0.34, 0.82);

void fragment() {
	vec4 base = COLOR;
	if (highlighted) {
		vec2 step_size = TEXTURE_PIXEL_SIZE * 2.0;
		float around = 0.0;
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				vec2 point = UV + vec2(float(x), float(y)) * step_size;
				if (all(greaterThanEqual(point, frame_uv.xy)) && all(lessThanEqual(point, frame_uv.zw))) {
					around = max(around, texture(TEXTURE, point).a);
				}
			}
		}
		float edge = max(0.0, around - base.a) * highlight_color.a;
		float alpha = base.a + edge * (1.0 - base.a);
		vec3 rgb = (base.rgb * base.a + highlight_color.rgb * edge * (1.0 - base.a)) / max(alpha, 0.0001);
		COLOR = vec4(rgb, alpha);
	} else {
		COLOR = base;
	}
}
