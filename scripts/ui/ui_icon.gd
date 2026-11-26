class_name UiIcon
extends Control
## 버튼 안에 들어가는 간단한 벡터 아이콘 (back / play / help / restart / home / close)

var kind: String = "back"
var color: Color = Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var s := minf(size.x, size.y) * 0.24
	var c := size / 2.0
	var w := maxf(4.0, s * 0.42)
	match kind:
		"back":
			_stroke([c + Vector2(s * 0.35, -s * 0.85), c + Vector2(-s * 0.5, 0), c + Vector2(s * 0.35, s * 0.85)], w)
		"play":
			var pts := PackedVector2Array([c + Vector2(-s * 0.6, -s), c + Vector2(s, 0), c + Vector2(-s * 0.6, s)])
			draw_colored_polygon(pts, color)
			_stroke([pts[0], pts[1], pts[2], pts[0]], w * 0.6)
		"help":
			var f := UIKit.font(800)
			var fs := int(s * 3.0)
			draw_string(f, Vector2(0, c.y + fs * 0.36), "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, color)
		"restart":
			draw_arc(c, s * 0.9, -PI * 0.35, PI * 1.35, 24, color, w, true)
			var tip := c + Vector2(cos(-PI * 0.35), sin(-PI * 0.35)) * s * 0.9
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.55, -s * 0.15), tip + Vector2(s * 0.35, -s * 0.55), tip + Vector2(s * 0.25, s * 0.45)]), color)
		"home":
			_stroke([c + Vector2(-s, -s * 0.05), c + Vector2(0, -s * 0.95), c + Vector2(s, -s * 0.05)], w)
			_stroke([c + Vector2(-s * 0.65, -s * 0.2), c + Vector2(-s * 0.65, s * 0.85), c + Vector2(s * 0.65, s * 0.85), c + Vector2(s * 0.65, -s * 0.2)], w)
		"close":
			_stroke([c + Vector2(-s * 0.7, -s * 0.7), c + Vector2(s * 0.7, s * 0.7)], w)
			_stroke([c + Vector2(s * 0.7, -s * 0.7), c + Vector2(-s * 0.7, s * 0.7)], w)


func _stroke(points: Array, w: float) -> void:
	draw_polyline(PackedVector2Array(points), color, w, true)
	for p in points:
		draw_circle(p, w * 0.5, color, true, -1.0, true)
