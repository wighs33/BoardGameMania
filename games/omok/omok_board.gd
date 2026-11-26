class_name OmokBoard
extends Control
## 오목판 – 그리기와 터치 입력 담당

signal point_tapped(c: Vector2i)

const WOOD := Color("#F5CF86")
const WOOD_DARK := Color("#D99E52")
const LINE := Color("#8C5A2B")
const BLACK := Color("#2B2B3A")
const WHITE := Color("#FBFAFD")
const MARK := Color("#FF5E5E")

var logic: OmokLogic
var input_enabled: bool = false
var preview: Vector2i = Vector2i(-1, -1)
var preview_bad: bool = false
var preview_player: int = 0
var forbidden: Array[Vector2i] = []

var _stone_time: Dictionary = {}
var _win_time: float = -1.0
var _time: float = 0.0
var _rect := Rect2()
var _origin := Vector2.ZERO
var _step: float = 0.0


func setup(L: OmokLogic) -> void:
	logic = L
	_stone_time.clear()
	_win_time = -1.0
	clear_preview()
	forbidden = []


func clear_preview() -> void:
	preview = Vector2i(-1, -1)
	preview_bad = false


func mark_placed(c: Vector2i) -> void:
	_stone_time[c] = _time


func mark_win() -> void:
	_win_time = _time


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ── 레이아웃 ───────────────────────────────────────────
func _layout() -> void:
	var side := minf(size.x, size.y - 12.0)
	_rect = Rect2((size - Vector2(side, side)) / 2.0 - Vector2(0, 4), Vector2(side, side))
	var pad := side * 0.05
	_step = (side - pad * 2.0) / float(logic.size - 1)
	_origin = _rect.position + Vector2(pad, pad)


func _pt(c: Vector2i) -> Vector2:
	return _origin + Vector2(c) * _step


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	if logic == null or size.x < 10.0:
		return
	_layout()
	var n := logic.size
	var rad := _rect.size.x * 0.05
	UIKit.draw_rbox(self, Rect2(_rect.position + Vector2(0, 14), _rect.size), Color(0.4, 0.2, 0.1, 0.16), rad)
	UIKit.draw_rbox(self, Rect2(_rect.position + Vector2(0, 7), _rect.size), WOOD_DARK, rad)
	UIKit.draw_rbox(self, _rect, WOOD, rad)
	# 나뭇결
	for i in 7:
		var y := _rect.position.y + _rect.size.y * (0.1 + i * 0.13) + sin(i * 1.7) * 6.0
		draw_line(Vector2(_rect.position.x + rad, y), Vector2(_rect.end.x - rad, y + sin(i * 2.3) * 8.0), Color(0.75, 0.5, 0.25, 0.08), 6.0, true)

	# 격자
	var last := _pt(Vector2i(n - 1, n - 1))
	for i in n:
		var w := 3.0 if i == 0 or i == n - 1 else 1.6
		draw_line(_pt(Vector2i(i, 0)), _pt(Vector2i(i, n - 1)), LINE, w, true)
		draw_line(_pt(Vector2i(0, i)), _pt(Vector2i(n - 1, i)), LINE, w, true)
	for s in [Vector2i(3, 3), Vector2i(11, 3), Vector2i(7, 7), Vector2i(3, 11), Vector2i(11, 11)]:
		draw_circle(_pt(s), _step * 0.12, LINE, true, -1.0, true)

	# 금지 자리 표시 (쌍삼)
	if input_enabled:
		for c in forbidden:
			var p := _pt(c)
			var k := _step * 0.18
			draw_line(p - Vector2(k, k), p + Vector2(k, k), Color(MARK, 0.75), 3.0, true)
			draw_line(p + Vector2(-k, k), p + Vector2(k, -k), Color(MARK, 0.75), 3.0, true)

	# 돌
	var r := _step * 0.47
	for y in n:
		for x in n:
			var s := logic.stone(Vector2i(x, y))
			if s <= 0:
				continue
			var c := Vector2i(x, y)
			var pop := 1.0
			if _stone_time.has(c):
				var k := clampf((_time - float(_stone_time[c])) / 0.25, 0.0, 1.0)
				pop = UIKit.ease_out_back(k)
			_draw_stone(_pt(c), r * pop, s - 1, 1.0)

	# 마지막 수 표시
	var lm := logic.last_move()
	if lm.x >= 0 and not logic.over:
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		draw_circle(_pt(lm), r * (0.22 + 0.06 * pulse), MARK, true, -1.0, true)

	# 승리 줄
	if logic.over and logic.win_line.size() >= 5 and _win_time >= 0.0:
		var k := clampf((_time - _win_time) / 0.5, 0.0, 1.0)
		var a := _pt(logic.win_line[0])
		var b := _pt(logic.win_line[logic.win_line.size() - 1])
		var glow := 0.5 + 0.5 * sin(_time * 6.0)
		for c in logic.win_line:
			draw_arc(_pt(c), r * (1.05 + 0.08 * glow), 0.0, TAU, 32, Color(UIKit.GOLD, 0.9), _step * 0.1, true)
		draw_line(a, a.lerp(b, k), Color(MARK, 0.85), _step * 0.16, true)

	# 미리보기 돌 + 십자 안내선
	if preview.x >= 0:
		var p := _pt(preview)
		var guide := Color(UIKit.ORANGE if not preview_bad else MARK, 0.55)
		draw_line(Vector2(_origin.x, p.y), Vector2(last.x, p.y), guide, 3.0, true)
		draw_line(Vector2(p.x, _origin.y), Vector2(p.x, last.y), guide, 3.0, true)
		var bob := 1.0 + 0.06 * sin(_time * 8.0)
		_draw_stone(p, r * bob, preview_player, 0.6)
		if preview_bad:
			var k := r * 0.5
			draw_line(p - Vector2(k, k), p + Vector2(k, k), MARK, 5.0, true)
			draw_line(p + Vector2(-k, k), p + Vector2(k, -k), MARK, 5.0, true)


func _draw_stone(p: Vector2, r: float, player: int, alpha: float) -> void:
	if r <= 0.5:
		return
	draw_circle(p + Vector2(r * 0.08, r * 0.18), r, Color(0.25, 0.12, 0.05, 0.28 * alpha), true, -1.0, true)
	if player == 0:
		draw_circle(p, r, Color(BLACK, alpha), true, -1.0, true)
		draw_circle(p + Vector2(-r * 0.12, -r * 0.14), r * 0.72, Color(1, 1, 1, 0.07 * alpha), true, -1.0, true)
		draw_circle(p + Vector2(-r * 0.36, -r * 0.4), r * 0.2, Color(1, 1, 1, 0.45 * alpha), true, -1.0, true)
	else:
		draw_circle(p, r, Color(Color("#CFC8DA"), alpha), true, -1.0, true)
		draw_circle(p + Vector2(-r * 0.04, -r * 0.06), r * 0.92, Color(WHITE, alpha), true, -1.0, true)
		draw_circle(p + Vector2(-r * 0.36, -r * 0.4), r * 0.2, Color(1, 1, 1, alpha), true, -1.0, true)


# ── 입력 ───────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if not input_enabled or logic == null:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var rel := (mb.position - _origin) / _step
		var c := Vector2i(roundi(rel.x), roundi(rel.y))
		if logic.in_bounds(c) and (Vector2(c) - rel).length() < 0.75:
			point_tapped.emit(c)
		accept_event()
