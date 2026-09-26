shader_type canvas_item;
render_mode unshaded;
// Authored presentation only. Inverse of travel_world.gd's (180,100)/(-180,100) projection.
uniform vec2 view_size = vec2(1440.0, 700.0);
uniform vec2 camera_world = vec2(12.5, 62.5);
uniform vec2 camera_offset = vec2(0.0);
uniform float zoom_level = 1.0;
uniform sampler2D discovery_mask : filter_linear, repeat_disable;
uniform sampler2D ice_texture : filter_nearest, repeat_enable;
void fragment() {
	vec2 screen = UV * view_size;
	vec2 plane = (screen - view_size * 0.5 - camera_offset) / zoom_level;
	vec2 world = camera_world + vec2((plane.x / 180.0 + plane.y / 100.0) * 0.5, (plane.y / 100.0 - plane.x / 180.0) * 0.5);
	vec2 projected = vec2((world.x - world.y) * 180.0, (world.x + world.y) * 100.0);
	vec4 ground = texture(ice_texture, fract(projected / vec2(textureSize(ice_texture, 0))));
	float known = texture(discovery_mask, world / vec2(160.0, 73.0)).r;
	float inside = step(0.0, world.x) * step(0.0, world.y) * step(world.x, 160.0) * step(world.y, 73.0);
	known = smoothstep(0.08, 0.92, known) * inside;
	vec3 frost = ground.rgb * vec3(0.79, 0.87, 0.95);
	vec3 obscured = vec3(0.04, 0.075, 0.11) + ground.rgb * 0.075;
	COLOR = vec4(mix(obscured, frost, known), 1.0);
}
