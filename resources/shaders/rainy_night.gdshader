shader_type canvas_item;

// 雨夜背景：全部由程序生成，不依赖贴图。
// 参考 temp_assets/shader.txt（Brian Smith, MIT）的雨线分格做法，
// 这里改成「远/近两层雨 + 低雨雾 + 重暗角 + 湿地反光」，
// 让画面中心留给角色，四周逐渐没入看不清的夜雨里。
//
// 这个 shader 挂在 1280×720 的 ColorRect 上；DuelView 会把
// ground_y / focus_left / focus_right 三个 uniform 对齐到自己的场地常量。

uniform vec4 sky_top : source_color = vec4(0.010, 0.016, 0.030, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.055, 0.075, 0.100, 1.0);
uniform vec4 fog_color : source_color = vec4(0.085, 0.105, 0.130, 1.0);
uniform vec4 rain_color : source_color = vec4(0.62, 0.72, 0.82, 1.0);

uniform float rain_amount : hint_range(20.0, 240.0) = 150.0;
uniform float rain_speed : hint_range(0.0, 2.0) = 0.60;
uniform float rain_slant : hint_range(-0.8, 0.8) = 0.20;
uniform float rain_alpha : hint_range(0.0, 1.0) = 0.55;
uniform float fog_amount : hint_range(0.0, 1.0) = 0.48;
uniform float edge_darkness : hint_range(0.0, 1.0) = 0.94;

uniform float ground_y : hint_range(0.0, 1.0) = 0.75;
uniform float focus_left : hint_range(0.0, 1.0) = 0.336;
uniform float focus_right : hint_range(0.0, 1.0) = 0.664;
// 角色脚下的湿反光强度；主菜单没有角色，设为 0 就不会凭空多两片亮斑。
uniform float pool_strength : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * value_noise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		amp *= 0.5;
	}
	return v;
}

// 一层雨：按 x 分格，每格一根雨线；y 方向用 fract 循环下落。
// width 是「格宽的比例」，0.1 表示只占一格的 10%，不是整格都涂亮。
// 这样 1280 宽下每根雨线约 1px，远看是雨，而不是一根根竖条。
float rain_layer(vec2 uv, float amount, float speed, float slant, float length, float width, float seed) {
	float cell = 1.0 / amount;
	float offset = uv.x - uv.y * slant + seed;
	float remainder = mod(offset, cell);
	float column = offset - remainder;
	float rnd = fract(sin(column * 91.7 + seed * 13.1) * 43758.5453);
	float head = fract(uv.y + rnd - TIME * speed * (0.72 + 0.56 * rnd));
	float streak_len = length * (0.55 + 0.75 * rnd);
	float streak = smoothstep(1.0 - streak_len, 1.0, head);
	float center_dist = abs(remainder / cell - 0.5) * 2.0;
	float slim = 1.0 - smoothstep(0.0, width, center_dist);
	return streak * slim * (0.38 + 0.62 * rnd);
}

void fragment() {
	vec2 uv = UV;

	// 夜空：上黑下灰，地平线附近稍微透一点冷光。
	vec3 col = mix(sky_top.rgb, sky_horizon.rgb, smoothstep(0.04, 0.72, uv.y));
	float horizon = exp(-pow((uv.y - 0.70) * 5.2, 2.0));
	col += vec3(0.040, 0.052, 0.068) * horizon;

	// 低频雨雾：从中心向四周都压一层，越靠下越重。
	float fog = fbm(vec2(uv.x * 3.4 + TIME * 0.018, uv.y * 2.1 - TIME * 0.009));
	fog = smoothstep(0.34, 0.78, fog);
	float fog_band = smoothstep(0.18, 0.92, uv.y);
	col = mix(col, fog_color.rgb, fog * fog_amount * (0.30 + 0.70 * fog_band));

	// 远雨 + 近雨：两层不同密度/速度，才有纵深。
	float far_rain = rain_layer(uv, rain_amount * 0.68, rain_speed * 0.72,
			rain_slant * 1.35, 0.10, 0.060, 17.0);
	float near_rain = rain_layer(uv, rain_amount, rain_speed, rain_slant,
			0.28, 0.10, 0.0);
	col = mix(col, rain_color.rgb, far_rain * rain_alpha * 0.60);
	col = mix(col, rain_color.rgb, near_rain * rain_alpha);

	// 地面：从 GROUND_Y 开始压暗，并让两名角色脚下各有一小片湿反光。
	float ground = smoothstep(ground_y - 0.004, ground_y + 0.035, uv.y);
	vec3 ground_col = mix(vec3(0.016, 0.022, 0.030), vec3(0.030, 0.040, 0.052),
			smoothstep(ground_y, 1.0, uv.y));
	float pool_left = exp(-pow((uv.x - focus_left) * 7.0, 2.0))
			* exp(-pow((uv.y - ground_y) * 20.0, 2.0));
	float pool_right = exp(-pow((uv.x - focus_right) * 7.0, 2.0))
			* exp(-pow((uv.y - ground_y) * 20.0, 2.0));
	ground_col += vec3(0.045, 0.060, 0.080) * (pool_left + pool_right) * pool_strength;
	col = mix(col, ground_col, ground);

	// 地平线：一条很薄的水光，帮玩家把脚底和背景分开。
	col += vec3(0.060, 0.075, 0.095) * exp(-abs(uv.y - ground_y) * 520.0);

	// 四周暗角：中心保留可读性，越靠边越像被雨幕吞掉。
	vec2 p = uv * 2.0 - 1.0;
	p.x *= 0.92;
	float edge = smoothstep(0.34, 1.20, length(p));
	col *= mix(1.0, 1.0 - edge_darkness, edge);

	COLOR = vec4(col, 1.0);
}
