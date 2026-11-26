// 격투장 바닥: 옅은 점 격자(움직임이 눈에 보이게) + 둥근 경계선, 경계 밖은 조금 어둡게.
// 빛을 받는 재질이라 사람 그림자가 그대로 드리워집니다.
shader_type spatial;
render_mode specular_disabled;

uniform vec3 floor_color : source_color = vec3(0.93);
uniform vec3 dot_color : source_color = vec3(0.76);
uniform vec3 outside_color : source_color = vec3(0.7);
uniform vec3 ring_color : source_color = vec3(0.1);
uniform float radius = 9.0;
uniform float dot_gap = 1.2;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float r = length(p);
	float fw = fwidth(r);
	vec2 cell = (fract(p / dot_gap) - 0.5) * dot_gap;
	float dots = 1.0 - smoothstep(0.05, 0.05 + fw, length(cell));
	float inside = 1.0 - smoothstep(radius - fw, radius + fw, r);
	float ring = 1.0 - smoothstep(0.05, 0.05 + fw * 1.5, abs(r - radius));
	vec3 c = mix(outside_color, mix(floor_color, dot_color, dots), inside);
	ALBEDO = mix(c, ring_color, ring);
	ROUGHNESS = 1.0;
}
