class_name DavinciBoard
extends Control
## 비밀 숫자 판 – 상대 줄 · 가운데 더미 · 내 줄 그리기와 터치
## viewer: 지금 폰을 보고 있는 사람 (그 사람 타일만 숫자가 보임)

signal tile_tapped(p: int, i: int)
signal pile_tapped(color: int)

enum Tap { NONE, PILE, TARGET, OWN }

const BLACK := Color("#2B2B3A")
const BLACK_EDGE := Color("#121219")
const WHITE := Color("#FBFAFD")
const WHITE_EDGE := Color("#C4BBD2")
const OPEN := Color("#FF9F43")
const FLIP_TIME := 0.4
const RATIO := 0.7          # 타일 가로 / 세로

var logic: DavinciLogic
var viewer: int = 0
var colors: Array = []
var names: Array = []
var input_mode: int = Tap.NONE
var target_key: int = -1
var reveal_all: bool = false

var _t: float = 0.0
var _flip: Dictionary = {}      # 키 -> 시작 시각
var _pop: Dictionary = {}       # 키 -> 시작 시각
var _bubble: Dictionary = {}    # {key, num, t, res(0 대기 / 1 정답 / 2 땡)}
var _hit_tiles: Array = []      # [Rect2, p, i]
var _hit_piles: Array = []      # [Rect2, color]
var _key_rects: Dictionary = {}


func setup(L: DavinciLogic, cols: Array, nms: Array) -> void:
	logic = L
	colors = cols
	names = nms
	target_key = -1
	reveal_all = false
	input_mode = Tap.NONE
	_flip.clear()
	_pop.clear()
	_bubble = {}


func flip(k: int) -> void:
	_flip[k] = _t


func pop(k: int) -> void:
	_pop[k] = _t


func show_bubble(k: int, num: int) -> void:
	_bubble = {"key": k, "num": num, "t": _t, "res": 0}


func resolve_bubble(ok: bool) -> void:
	if not _bubble.is_empty():
		_bubble["res"] = 1 if ok else 2
		_bubble["rt"] = _t


func clear_bubble() -> void:
	_bubble = {}


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	if logic == null or size.x < 20.0:
		return
	_hit_tiles.clear()
	_hit_piles.clear()
	_key_rects.clear()
	var W := size.x
	var H := size.y
	var n := logic.n
	var opp: Array = []
	for k in range(1, n):
		opp.append((viewer + k) % n)
	var gap := 12.0
	var my_h := clampf(H * 0.27, 150.0, 230.0)
	var pool_h := clampf(H * 0.17, 104.0, 150.0)
	var free_h := H - my_h - pool_h - gap * (opp.size() + 1)
	var row_h := minf(free_h / maxf(1.0, opp.size()), 210.0)
	var total := row_h * opp.size() + gap * (opp.size() + 1) + pool_h + my_h
	var y := maxf(0.0, (H - total) / 2.0)
	for p in opp:
		_draw_row(p, Rect2(0, y, W, row_h), false)
		y += row_h + gap
	_draw_pool(Rect2(0, y, W, pool_h))
	y += pool_h + gap
	_draw_row(viewer, Rect2(0, y, W, my_h), true)
	_draw_bubble()


func _draw_row(p: int, r: Rect2, mine: bool) -> void:
	var col: Color = colors[p] if p < colors.size() else UIKit.player_color(p)
	var is_out: bool = logic.out[p]
	var active := not logic.is_over() and logic.current == p
	var bg := col.lerp(Color.WHITE, 0.78)
	if is_out:
		bg = Color("#ECE8F0")
	UIKit.draw_rbox(self, Rect2(r.position + Vector2(0, 6), r.size), Color(0.3, 0.2, 0.35, 0.1), 28)
	if active:
		UIKit.draw_rbox(self, r.grow(4), col, 32)
	UIKit.draw_rbox(self, r, bg, 28)

	# 이름표 + 숨은 개수
	var nm: String = names[p] if p < names.size() else str(p)
	_chip(Vector2(r.position.x + 14, r.position.y + 22), nm, 21, col.darkened(0.12) if not is_out else UIKit.GREY)
	var info := "탈락!" if is_out else "숨은 타일 %d" % logic.hidden_count(p)
	_text_right(Vector2(r.end.x - 16, r.position.y + 22), info, 20, UIKit.INK_SOFT if not is_out else UIKit.player_dark(0))

	# 타일 크기
	var h: Array = logic.hands[p]
	var count := h.size()
	var has_drawn := logic.drawn >= 0 and logic.current == p
	var slots := count + (1 if has_drawn else 0)
	var area := Rect2(r.position.x + 14, r.position.y + 44, r.size.x - 28, r.size.y - 54)
	var th := minf(area.size.y, 150.0 if mine else 118.0)
	var tw := th * RATIO
	var step := tw + 8.0
	var extra := 14.0 if has_drawn else 0.0
	if slots * step + extra > area.size.x:
		step = (area.size.x - extra) / slots
		tw = step - maxf(3.0, step * 0.1)
		th = tw / RATIO
	var row_w := slots * step - (step - tw) + extra
	var x0 := area.position.x + (area.size.x - row_w) / 2.0
	var ty := area.position.y + (area.size.y - th) / 2.0 + 2.0
	var bob_on := (input_mode == Tap.TARGET and not mine) or (input_mode == Tap.OWN and mine)
	for i in count:
		var k: int = h[i]
		var tr := Rect2(x0 + i * step, ty, tw, th)
		var rev: bool = logic.revealed[p][i]
		var face := rev or p == viewer or reveal_all
		var lift := 0.0
		if bob_on and not rev and not is_out:
			lift = (sin(_t * 4.0 + i * 0.7) * 0.5 + 0.5) * th * 0.06
		if k == target_key:
			lift = th * 0.12
		_draw_tile_anim(tr, k, face, rev, p == viewer, lift, k == target_key)
		_hit_tiles.append([tr.grow(3), p, i])
		_key_rects[k] = tr
	if has_drawn:
		var dr := Rect2(x0 + count * step + extra, ty, tw, th)
		var dl := (sin(_t * 3.0) * 0.5 + 0.5) * th * 0.08
		UIKit.draw_rbox(self, dr.grow(5), Color(UIKit.GOLD, 0.55), tw * 0.25)
		_draw_tile_anim(dr, logic.drawn, p == viewer or reveal_all, false, p == viewer, dl, false)
		_key_rects[logic.drawn] = dr
		var f := UIKit.font(800)
		var lw := f.get_string_size("뽑음", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 16
		var pill := Rect2(Vector2(dr.get_center().x - lw / 2.0, dr.position.y - dl - 13), Vector2(lw, 24))
		UIKit.draw_rbox(self, pill, UIKit.ORANGE, 12)
		_text(pill.get_center(), "뽑음", 16, Color.WHITE)
	if is_out:
		_stamp(r.get_center() + Vector2(0, 12), minf(r.size.y * 0.32, 46.0))


## 탈락 도장
func _stamp(center: Vector2, fs: float) -> void:
	var f := UIKit.font(900)
	var red := Color("#FF5E5E")
	var w := f.get_string_size("탈락", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x + fs * 1.2
	var h := fs * 1.5
	draw_set_transform(center, -0.12, Vector2.ONE)
	UIKit.draw_rbox(self, Rect2(-w / 2.0 - 5, -h / 2.0 - 5, w + 10, h + 10), red, h * 0.3)
	UIKit.draw_rbox(self, Rect2(-w / 2.0, -h / 2.0, w, h), Color(1, 1, 1, 0.92), h * 0.25)
	_text(Vector2.ZERO, "탈락", int(fs), red, 900)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pool(r: Rect2) -> void:
	var piles := [0, 1]
	var pw := minf(r.size.y * 0.62 * RATIO, 70.0)
	var ph := pw / RATIO
	var gapx := 120.0
	var cx := r.get_center().x
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	for c in piles:
		var cnt := logic.pool_count(c)
		var center := Vector2(cx + (-1 if c == 0 else 1) * (gapx * 0.5 + pw * 0.5), r.get_center().y - 8)
		var base := Rect2(center - Vector2(pw, ph) / 2.0, Vector2(pw, ph))
		var can := input_mode == Tap.PILE and cnt > 0
		if can:
			UIKit.draw_rbox(self, base.grow(8 + pulse * 4), Color(UIKit.GOLD, 0.35 + 0.35 * pulse), pw * 0.3)
		if cnt == 0:
			UIKit.draw_rbox(self, base, Color(0.4, 0.3, 0.5, 0.12), pw * 0.2)
		else:
			var layers := mini(3, cnt)
			for j in range(layers - 1, -1, -1):
				_draw_tile(Rect2(base.position + Vector2(j * 3, j * 4), base.size), c, false, false, false, 1.0)
		_hit_piles.append([base.grow(16), c])
		var label := "%s ×%d" % ["검정" if c == 0 else "하양", cnt]
		_text(Vector2(center.x + 4, base.end.y + 22), label, 21, UIKit.INK if cnt > 0 else UIKit.INK_SOFT)
	if logic.pool.is_empty():
		_text(Vector2(cx, r.get_center().y - 8), "더미 끝!", 22, UIKit.INK_SOFT)


func _draw_tile_anim(r: Rect2, k: int, face: bool, rev: bool, mine: bool, lift: float, hl: bool) -> void:
	var sx := 1.0
	var scale := 1.0
	var f := face
	var o := rev
	if _flip.has(k):
		var t := (_t - float(_flip[k])) / FLIP_TIME
		if t >= 1.0:
			_flip.erase(k)
		else:
			sx = absf(cos(t * PI))
			lift += sin(t * PI) * r.size.y * 0.15
			if t < 0.5:
				f = mine or reveal_all
				o = false
	if _pop.has(k):
		var t2 := (_t - float(_pop[k])) / 0.35
		if t2 >= 1.0:
			_pop.erase(k)
		else:
			scale = UIKit.ease_out_back(clampf(t2, 0.0, 1.0))
	var rr := Rect2(r.position - Vector2(0, lift), r.size)
	if hl:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		UIKit.draw_rbox(self, rr.grow(6 + pulse * 2), Color(UIKit.GOLD, 0.85), r.size.x * 0.3)
	draw_set_transform(rr.get_center(), 0.0, Vector2(maxf(sx, 0.04) * scale, scale))
	_draw_tile(Rect2(-rr.size / 2.0, rr.size), DavinciLogic.color_of(k), f, o, mine and not o, DavinciLogic.num_of(k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 타일 하나 (r 은 현재 변환 기준)
func _draw_tile(r: Rect2, color: int, face: bool, is_open: bool, secret: bool, num: float) -> void:
	var body := BLACK if color == 0 else WHITE
	var edge := BLACK_EDGE if color == 0 else WHITE_EDGE
	var ink := Color("#F4F1F8") if color == 0 else BLACK
	var rad := r.size.x * 0.2
	UIKit.draw_rbox(self, Rect2(r.position + Vector2(0, r.size.y * 0.09), r.size), Color(0.1, 0.05, 0.15, 0.16), rad)
	if is_open:
		UIKit.draw_rbox(self, Rect2(r.position + Vector2(0, r.size.y * 0.05), r.size).grow(4), OPEN, rad + 4)
		UIKit.draw_rbox(self, r.grow(4), OPEN, rad + 4)
	UIKit.draw_rbox(self, Rect2(r.position + Vector2(0, r.size.y * 0.05), r.size), edge, rad)
	UIKit.draw_rbox(self, r, body, rad)
	# 윗면 반짝
	UIKit.draw_rbox(self, Rect2(r.position + Vector2(r.size.x * 0.14, r.size.y * 0.07), Vector2(r.size.x * 0.32, r.size.y * 0.06)),
		Color(1, 1, 1, 0.16 if color == 0 else 0.9), r.size.y * 0.03)
	if face:
		var s := str(int(num))
		var fs := int(r.size.y * (0.52 if s.length() == 1 else 0.44))
		_text(r.get_center() + Vector2(0, -r.size.y * 0.02), s, fs, ink, 900)
		if int(num) == 6 or int(num) == 9:
			var uw := r.size.x * 0.3
			draw_rect(Rect2(r.get_center() + Vector2(-uw / 2.0, r.size.y * 0.27), Vector2(uw, maxf(2.0, r.size.y * 0.04))), ink)
		if secret:
			# 나만 아는 숫자: 아래쪽 작은 자물쇠 점
			draw_circle(r.get_center() + Vector2(0, r.size.y * 0.38), maxf(2.0, r.size.x * 0.06), Color(ink, 0.35), true, -1.0, true)
	else:
		var inner := r.grow(-r.size.x * 0.2)
		var pat := Color(1, 1, 1, 0.08) if color == 0 else Color(0.35, 0.25, 0.5, 0.08)
		UIKit.draw_rbox(self, inner, pat, inner.size.x * 0.3)
		_text(r.get_center(), "?", int(r.size.y * 0.34), Color(ink, 0.22), 900)


func _draw_bubble() -> void:
	if _bubble.is_empty() or not _key_rects.has(int(_bubble["key"])):
		return
	var tr: Rect2 = _key_rects[int(_bubble["key"])]
	var age := _t - float(_bubble["t"])
	var k := UIKit.ease_out_back(clampf(age / 0.3, 0.0, 1.0))
	var res: int = _bubble["res"]
	var txt := "%d?" % int(_bubble["num"])
	var bg := Color.WHITE
	var fg := UIKit.INK
	if res == 1:
		txt = "%d 정답!" % int(_bubble["num"])
		bg = UIKit.GREEN
		fg = Color.WHITE
	elif res == 2:
		txt = "%d 땡!" % int(_bubble["num"])
		bg = Color("#FF5E5E")
		fg = Color.WHITE
	var fs := 30
	var f := UIKit.font(900)
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 34
	var hgt := 54.0
	var tip := Vector2(tr.get_center().x, tr.position.y - 14)
	var box := Rect2(tip - Vector2(w / 2.0, hgt + 12), Vector2(w, hgt))
	box.position.x = clampf(box.position.x, 4.0, size.x - w - 4.0)
	if box.position.y < 0.0:
		tip = Vector2(tr.get_center().x, tr.end.y + 14)
		box = Rect2(Vector2(box.position.x, tip.y + 12), Vector2(w, hgt))
	draw_set_transform(tip, 0.0, Vector2(k, k))
	var local := Rect2(box.position - tip, box.size)
	var tail_y := local.end.y if local.position.y < 0 else local.position.y
	var tail_dir := 1.0 if local.position.y < 0 else -1.0
	UIKit.draw_rbox(self, Rect2(local.position + Vector2(0, 5), local.size), Color(0, 0, 0, 0.15), 24)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, tail_y - tail_dir * 2), Vector2(12, tail_y - tail_dir * 2), Vector2(0, tail_y + tail_dir * 12)]), bg)
	UIKit.draw_rbox(self, local, bg, 24)
	_text(local.get_center(), txt, fs, fg, 900)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── 글자 도우미 ────────────────────────────────────────
func _text(center: Vector2, s: String, fs: int, col: Color, weight: int = 800) -> void:
	if fs < 4:
		return
	var f := UIKit.font(weight)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := center.y + (f.get_ascent(fs) - f.get_descent(fs)) / 2.0
	draw_string(f, Vector2(center.x - w / 2.0, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _text_right(right_center: Vector2, s: String, fs: int, col: Color) -> void:
	var f := UIKit.font(800)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_text(Vector2(right_center.x - w / 2.0, right_center.y), s, fs, col)


func _chip(left_center: Vector2, s: String, fs: int, bg: Color) -> void:
	var f := UIKit.font(800)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 1.2
	var h := fs * 1.45
	UIKit.draw_rbox(self, Rect2(left_center.x, left_center.y - h / 2.0, w, h), bg, h / 2.0)
	_text(Vector2(left_center.x + w / 2.0, left_center.y), s, fs, Color.WHITE)


# ── 입력 ───────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if logic == null:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if input_mode == Tap.PILE:
		for hp in _hit_piles:
			if (hp[0] as Rect2).has_point(mb.position):
				pile_tapped.emit(int(hp[1]))
				return
		return
	if input_mode == Tap.TARGET or input_mode == Tap.OWN:
		for ht in _hit_tiles:
			if (ht[0] as Rect2).has_point(mb.position):
				tile_tapped.emit(int(ht[1]), int(ht[2]))
				return
