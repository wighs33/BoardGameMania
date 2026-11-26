class_name Confetti
extends Control
## 승리 축하 꽃가루

var _parts: Array = []
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func burst(count: int = 140) -> void:
	var area := get_viewport_rect().size
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cols: Array = UIKit.PLAYER_COLORS + [UIKit.PURPLE, Color("#FF7EB6")]
	for i in count:
		_parts.append({
			"p": Vector2(rng.randf_range(0.0, area.x), rng.randf_range(-area.y * 0.7, -20.0)),
			"v": Vector2(rng.randf_range(-50.0, 50.0), rng.randf_range(160.0, 380.0)),
			"rot": rng.randf() * TAU,
			"spin": rng.randf_range(-7.0, 7.0),
			"sway": rng.randf() * TAU,
			"s": rng.randf_range(12.0, 22.0),
			"c": cols[rng.randi() % cols.size()],
		})


func _process(delta: float) -> void:
	_t += delta
	var limit := get_viewport_rect().size.y + 40.0
	for i in range(_parts.size() - 1, -1, -1):
		var p: Dictionary = _parts[i]
		var v: Vector2 = p["v"]
		p["p"] = (p["p"] as Vector2) + v * delta + Vector2(sin(_t * 3.0 + float(p["sway"])) * 50.0 * delta, 0.0)
		p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
		if (p["p"] as Vector2).y > limit:
			_parts.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		var s: float = p["s"]
		var rot: float = p["rot"]
		draw_set_transform(p["p"], rot, Vector2(1.0, absf(sin(rot * 1.3)) * 0.8 + 0.2))
		draw_rect(Rect2(-s * 0.5, -s * 0.3, s, s * 0.6), p["c"])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
