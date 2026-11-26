class_name HeroHearts
extends Control
## 플레이어 카드에 넣는 성 하트 줄 (하트를 잃으면 잠깐 흔들림)

var lives: int = 3
var max_lives: int = 3
var _lost_t: float = -10.0
var _t: float = 0.0


func set_lives(n: int, m: int) -> void:
	if n < lives:
		_lost_t = _t
	if n != lives or m != max_lives:
		queue_redraw()
	lives = n
	max_lives = m


func _process(delta: float) -> void:
	_t += delta
	if _t - _lost_t < 0.7:   # 하트를 잃고 흔들리는 동안만
		queue_redraw()


func _draw() -> void:
	var s := minf(size.y * 0.78, size.x / (max_lives * 1.2))
	for i in max_lives:
		var c := Vector2(s * 0.62 + i * s * 1.18, size.y * 0.52)
		var age := _t - _lost_t
		if i == lives and age < 0.6:
			c += Vector2(sin(age * 50.0) * s * 0.08 * (1.0 - age / 0.6), 0)
			HeroArt.draw_heart(self, c, s * (1.0 + 0.3 * (1.0 - age / 0.6)), false)
		else:
			HeroArt.draw_heart(self, c, s, i < lives)
