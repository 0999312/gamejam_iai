shader_type canvas_item;
render_mode blend_add;

// 挥砍月牙的「扇形消失」：月牙保持不动，刀锋角（`head`）随挥砍进度
// 从月牙的上端扫到下端；刀已经扫过的那一侧（角度小于 `head`）立刻塌掉，
// 于是可见段像扇面一样从刀尾往刀锋收，收到最后一小截时整体淡出。
//
// 角度用贴图本地极角（`atan(UV - 0.5)`，UV 的 y 朝下）：
// 实测月牙亮带在 -80°…+28°，所以 `head` 从 -83° 扫到 +29°。
// `tail_span` 是「刀锋身后还留多少弧度」——留得越少，塌得越干脆；
// 0.16 rad ≈ 9°，只够让边缘有一点软过渡，不会再留下整段旧弧。

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float head_from = -1.449;   // -83°
uniform float head_to = 0.506;      // +29°
uniform float tail_span = 0.16;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float ang = atan(d.y, d.x);
	float head = mix(head_from, head_to, progress);
	// behind > 0 表示这个角度已经被刀扫过，越靠后越该消失。
	float behind = head - ang;
	float fade = 1.0 - smoothstep(-0.06, tail_span, behind);
	COLOR *= texture(TEXTURE, UV);
	COLOR.a *= fade;
}
