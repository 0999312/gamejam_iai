shader_type canvas_item;
render_mode blend_add;

// 发光叠加：贴图本身是纯白 + alpha（Kenney Particle Pack），颜色一律来自
// COLOR（Sprite2D 的 modulate 或粒子的 ParticleProcessMaterial.color）。
//
// 与「半透明」的区别在于两条：
// 1) render_mode blend_add：亮度直接加到背景上，暗场里会「亮起来」而不是蒙一层；
// 2) 高 alpha 的核心再向纯白推一档（hot），中心过曝成白芯、边缘保留方色，
//    读作「发光」，而不是整片均匀的半透明色块。
//
// glow 控制整体亮度，core 控制白芯占比，alpha_gain 留给低强度爆发压淡。
uniform float glow : hint_range(0.0, 4.0) = 1.35;
uniform float core : hint_range(0.0, 1.0) = 0.5;
uniform float alpha_gain : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float mask = tex.a;
	float hot = smoothstep(0.35, 0.95, mask) * core;
	vec3 rgb = COLOR.rgb * tex.rgb * glow;
	rgb = mix(rgb, vec3(1.0), hot);
	COLOR = vec4(rgb, mask * COLOR.a * alpha_gain);
}
