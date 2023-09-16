shader_type canvas_item;

global uniform float ABILITY_ALPHA;

uniform float ability_alpha_weight : hint_range(0.0, 1.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform vec4 modulate_color : source_color = vec4(1.0);
uniform sampler2D modulate_map : repeat_enable;
uniform vec2 scroll = vec2(0.0);
uniform vec2 scale = vec2(1.0);

render_mode blend_add;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 mod_UV = UV * scale + scroll * TIME;

	vec4 mod_value = texture(modulate_map, mod_UV);
	COLOR = tex * (modulate_color + mod_value * mod_value) * opacity;
	COLOR.a *= mix(ABILITY_ALPHA, 1.0, 1.0 - ability_alpha_weight);
}
