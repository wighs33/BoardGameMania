class_name ReversiBoard
extends Control
## 리버시 판 – 그리기(뒤집기 애니메이션 포함)와 터치 입력 담당

signal cell_tapped(c: Vector2i)

const FELT := Color("#33B06E")
const FELT_LIGHT := Color("#3CBD79")
const FELT_DARK := Color("#1F7F4D")
const LINE := Color("#1E6E43")
const BLACK := Color("#2B2B3A")
const WHITE := Color("#FBFAFD")
const MARK := Color("#FF5E5E")
const FLIP_TIME := 0.32

var logic: ReversiLogic
var input_enabled: bool = false
var hints: Array[Vector2i] = []
var hint_player: int = 0

var _flip: Dictionary = {}       # 칸 -> [시작 시각, 원래 색(0/1), 바뀔 색(0/1)]
var _placed: Dictionary = {}     # 칸 -> 놓인 시각
var _shake: Dictionary = {}      # 칸 -> 잘못 누른 시각
var _time: float = 0.0
var _rect := Rect2()
var _origin := Vector2.ZERO
var _cell: float = 0.0


func setup(L: ReversiLogic) -> void:
	logic = L
	hints = []
	reset_anims()


func reset_anims() -> void:
	_flip.clear()
	_placed.clear()
	_shake.clear()


## 돌을 놓고 뒤집히는 돌들이 놓은 자리에서부터 차례로 물결처럼 뒤집힘
func animate_move(c: Vector2i, flips: Array, player: int) -> void:
	_placed[c] = _time
	for q in flips:
		var dist := maxi(absi(q.x - c.x), absi(q.y - c.y))
		_flip[q] = [_time + 0.08 + 0.07 * (dist - 1), 1 - player, player]


func flash_bad(c: Vector2i) -> void:
	_shake[c] = _time


## 진행 중인 뒤집기 애니메이션이 끝나는 데 남은 시간
func anim_time_left() -> float:
	var left := 0.0
	for q in _flip:
		left = maxf(left, float(_flip[q][0]) + FLIP_TIME - _time)
	return left


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ── 레이아웃 ───────────────────────────────────────────
func _layout() -> void:
	var side := minf(size.x, size.y - 12.0)
	_rect = Rect2((size - Vector2(side, side)) / 2.0 - Vector2(0, 4), Vector2(side, side))
	var pad := side * 0.04
	_cell = (side - pad * 2.0) / float(logic.size)
	_origin = _rect.position + Vector2(pad, pad)


func _center(c: Vector2i) -> Vector2:
	return _origin + (Vector2(c) + Vector2(0.5, 0.5)) * _cell


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	if logic == null or size.x < 10.0:
		return
	_layout()
	var n := logic.size
	var rad := _rect.size.x * 0.05
	UIKit.draw_rbox(self, Rect2(_rect.position + Vector2(0, 14), _rect.size), Color(0.1, 0.3, 0.2, 0.18), rad)
	UIKit.draw_rbox(self, Rect2(_rect.position + Vector2(0, 7), _rect.size), FELT_DARK, rad)
	UIKit.draw_rbox(self, _rect, FELT, rad)

	# 칸 (살짝 체크무늬) + 격자
	for y in n:
		for x in n:
			if (x + y) % 2 == 0:
				draw_rect(Rect2(_origin + Vector2(x, y) * _cell, Vector2(_cell, _cell)), FELT_LIGHT)
	for i in n + 1:
		var wid := 3.0 if i == 0 or i == n else 2.0
		draw_line(_origin + Vector2(i * _cell, 0), _origin + Vector2(i * _cell, n * _cell), LINE, wid, true)
		draw_line(_origin + Vector2(0, i * _cell), _origin + Vector2(n * _cell, i * _cell), LINE, wid, true)
	for s in [Vector2(2, 2), Vector2(6, 2), Vector2(2, 6), Vector2(6, 6)]:
		draw_circle(_origin + s * _cell, _cell * 0.07, LINE, true, -1.0, true)

	# 둘 수 있는 곳 안내
	if input_enabled:
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		var hc := BLACK if hint_player == 0 else WHITE
		for c in hints:
			draw_circle(_center(c), _cell * (0.13 + 0.03 * pulse), Color(hc, 0.35 + 0.2 * pulse), true, -1.0, true)

	# 돌
	var r := _cell * 0.4
	for y in n:
		for x in n:
			var c := Vector2i(x, y)
			var s := logic.stone(c)
			if s == 0:
				continue
			var player := s - 1
			var sx := 1.0
			var lift := 0.0
			if _flip.has(c):
				var f: Array = _flip[c]
				var t := (_time - float(f[0])) / FLIP_TIME
				if t < 0.0:
					player = f[1]
				elif t < 1.0:
					sx = absf(cos(t * PI))
					player = f[1] if t < 0.5 else f[2]
					lift = sin(t * PI) * 0.25
				else:
					_flip.erase(c)
			var pop := 1.0
			if _placed.has(c):
				var k := clampf((_time - float(_placed[c])) / 0.25, 0.0, 1.0)
				pop = UIKit.ease_out_back(k)
				if k >= 1.0 and _time - float(_placed[c]) > 1.0:
					_placed.erase(c)
			_draw_disc(_center(c), r * pop, player, sx, lift)

	# 마지막 수 표시
	var lm := logic.last_move()
	if lm.x >= 0:
		var pulse2 := 0.5 + 0.5 * sin(_time * 5.0)
		draw_circle(_center(lm), r * (0.18 + 0.05 * pulse2), MARK, true, -1.0, true)

	# 잘못 누른 자리
	for c in _shake.keys():
		var age := _time - float(_shake[c])
		if age > 0.45:
			_shake.erase(c)
			continue
		var p := _center(c) + Vector2(sin(age * 60.0) * 4.0, 0)
		var k := _cell * 0.18
		var col := Color(MARK, 1.0 - age / 0.45)
		draw_line(p - Vector2(k, k), p + Vector2(k, k), col, 5.0, true)
		draw_line(p + Vector2(-k, k), p + Vector2(k, -k), col, 5.0, true)


func _draw_disc(p: Vector2, r: float, player: int, sx: float, lift: float) -> void:
	if r <= 0.5:
		return
	draw_set_transform(p + Vector2(0, r * 0.16), 0.0, Vector2(maxf(sx, 0.15), 1.0))
	draw_circle(Vector2.ZERO, r, Color(0.05, 0.2, 0.1, 0.35), true, -1.0, true)
	var top := p - Vector2(0, lift * r)
	draw_set_transform(top, 0.0, Vector2(maxf(sx, 0.06), 1.0))
	if player == 0:
		draw_circle(Vector2(0, r * 0.1), r, Color("#15151F"), true, -1.0, true)
		draw_circle(Vector2.ZERO, r, BLACK, true, -1.0, true)
		draw_circle(Vector2(-r * 0.12, -r * 0.14), r * 0.7, Color(1, 1, 1, 0.07), true, -1.0, true)
		draw_circle(Vector2(-r * 0.36, -r * 0.4), r * 0.18, Color(1, 1, 1, 0.45), true, -1.0, true)
	else:
		draw_circle(Vector2(0, r * 0.1), r, Color("#C9C1D6"), true, -1.0, true)
		draw_circle(Vector2.ZERO, r, WHITE, true, -1.0, true)
		draw_circle(Vector2(-r * 0.36, -r * 0.4), r * 0.18, Color(1, 1, 1), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── 입력 ───────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if not input_enabled or logic == null:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var rel := (mb.position - _origin) / _cell
		var c := Vector2i(floori(rel.x), floori(rel.y))
		if logic.in_bounds(c):
			cell_tapped.emit(c)
		accept_event()
