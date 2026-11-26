class_name HeroPortrait
extends Control
## 정보 칸에 넣는 작은 초상화 (영웅 또는 성)

var kind: int = 0
var team: Color = Color.WHITE
var lives: int = 3
var _t: float = 0.0
var _key: Array = []


func _process(delta: float) -> void:
	_t += delta
	# 움직이는 소품이 있으면 1초에 10번, 없으면 바뀔 때만
	var step := int(_t * 10.0) if kind < 0 or HeroArt.sway(kind) > 0.0 else int(HeroArt.robot_on(_t))
	var key := [kind, team, lives, step]
	if key != _key:
		_key = key
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	if kind < 0:
		HeroArt.draw_castle(self, Rect2((size - Vector2(s, s) * 0.8) / 2.0, Vector2(s, s) * 0.8), team, lives, _t)
		return
	var r := s * 0.27
	HeroArt.draw_hero(self, size / 2.0 + Vector2(0, r * 0.35), r, kind, team, _t, 0.3, 0.0, true)
