// 사람 몸 둘레에 그리는 윤곽선 (뒷면만 그린 껍데기를 화면 기준으로 width_px 만큼 밀어냄).
// 화면 픽셀 단위라서 카메라를 당기거나 밀어도 선 굵기가 그대로입니다.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 line_color : source_color = vec4(1.0);
uniform float width_px = 2.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	vec2 dir = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	float len = length(dir);
	dir = len > 0.0001 ? dir / len : vec2(0.0);
	clip.xy += dir * width_px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
