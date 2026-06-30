shader_type canvas_item;

// 회오리 회전 속도 (음수 = 반시계 방향)
uniform float spin_speed : hint_range(-5.0, 5.0) = -1.0;
// 중심에서 멀수록 더 많이 회전 (나선 효과)
uniform float spiral_strength : hint_range(0.0, 3.0) = 0.8;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 uv = UV - center;

	float dist = length(uv);
	// 중심에서 멀수록 덜 회전, 가까울수록 더 회전 (빨려들어가는 느낌)
	float angle = TIME * spin_speed + (1.0 - dist) * spiral_strength;

	float cos_a = cos(angle);
	float sin_a = sin(angle);
	vec2 rotated_uv = vec2(
		uv.x * cos_a - uv.y * sin_a,
		uv.x * sin_a + uv.y * cos_a
	);

	rotated_uv += center;

	// 범위 밖은 투명 처리
	if (rotated_uv.x < 0.0 || rotated_uv.x > 1.0 || rotated_uv.y < 0.0 || rotated_uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, rotated_uv);
	}
}
