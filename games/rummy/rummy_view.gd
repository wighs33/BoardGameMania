class_name RummyView
extends Control
## 타일 러미 화면 – 위: 판(묶음들, 위아래로 밀어서 보기) / 아래: 내 받침대
## 누르기 → tapped(hit),  타일 끌어서 놓기 → dropped(타일들, 놓은 곳)
## hit / 놓은 곳: {kind: "tile"(tile, area "rack"/"table", set) | "set"(set) | "new" | "rack" | "none"}

signal tapped(hit: Dictionary)
signal dropped(tiles: Array, target: Dictionary)

const TILE_BG := Color("#FFF8EC")
const TILE_EDGE := Color("#E0C9A2")
const NUM_COLORS := [Color("#E8505B"), Color("#2F80ED"), Color("#EE9B00"), Color("#2B2B3A")]
const FELT := Color("#BFE8D4")
const FELT_DARK := Color("#9DD6BC")
const WOOD := Color("#DDA066")
const WOOD_DARK := Color("#B97A40")
const BAD := Color("#FF6B6B")

var table: Array = []
var rack: Array = []
var selected: Dictionary = {}
var fresh: Dictionary = {}
var pool_left: int = 0
var interactive: bool = false
var drag_filter: Callable = Callable()
var rack_label: String = "내 타일"

var _t: float = 0.0
var _scroll: float = 0.0
var _max_scroll: float = 0.0
var _table_rect := Rect2()
var _rack_rect := Rect2()
var _new_rect := Rect2()
var _tiles_hit: Array = []
var _sets_hit: Array = []
var _tw: float = 40.0
var _th: float = 54.0
var _rw: float = 50.0
var _rh: float = 68.0
var _press: bool = false
var _press_pos := Vector2.ZERO
var _press_hit: Dictionary = {}
var _drag: Array = []
var _drag_pos := Vector2.ZERO
var _scrolling: bool = false
var _pop: Dictionary = {}


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func pop(tile: int) -> void:
	_pop[tile] = _t


func scroll_to_end() -> void:
	_scroll = 1e9


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


# ══════════════════════════════════════════════════════
#  그리기
# ══════════════════════════════════════════════════════
func _draw() -> void:
	if size.x < 20.0:
		return
	_tiles_hit.clear()
	_sets_hit.clear()
	var W := size.x
	# 받침대 크기
	var per_row := maxi(8, ceili(rack.size() / 2.0))
	_rw = minf(54.0, (W - 28.0) / per_row - 4.0)
	_rh = _rw * 1.36
	var rack_h := 2.0 * (_rh + 10.0) + 40.0
	_rack_rect = Rect2(0, size.y - rack_h, W, rack_h)
	_table_rect = Rect2(0, 0, W, size.y - rack_h - 12.0)
	_tw = clampf(W / 17.5, 30.0, 42.0)
	_th = _tw * 1.36

	# 판 바탕
	UIKit.draw_rbox(self, Rect2(_table_rect.position + Vector2(0, 6), _table_rect.size), FELT_DARK, 30)
	UIKit.draw_rbox(self, _table_rect, FELT, 30)
	_draw_table()
	# 남은 더미
	var chip := "남은 타일 %d" % pool_left
	_chip_right(Vector2(_table_rect.end.x - 12, _table_rect.position.y + 22), chip, 20, Color(0.2, 0.45, 0.35, 0.85))
	_draw_rack()
	# 끌고 있는 타일
	if not _drag.is_empty():
		for i in _drag.size():
			var r := Rect2(_drag_pos + Vector2(-_rw / 2.0 + i * (_rw * 0.55), -_rh * 0.9), Vector2(_rw, _rh))
			_draw_tile(r, int(_drag[i]), true, false, 0.0)


func _draw_table() -> void:
	var pad := 14.0
	var top := 44.0
	var x := pad
	var y := top
	var row_h := _th + 24.0
	var layout: Array = []
	for si in table.size():
		var s: Array = table[si]
		var w := s.size() * (_tw + 3.0) - 3.0 + 16.0
		if x + w > _table_rect.size.x - pad and x > pad:
			x = pad
			y += row_h
		layout.append(Rect2(x, y, w, _th + 14.0))
		x += w + 10.0
	var show_new := interactive and (not selected.is_empty() or not _drag.is_empty())
	var new_w := 3.0 * (_tw + 3.0) + 13.0
	if x + new_w > _table_rect.size.x - pad and x > pad:
		x = pad
		y += row_h
	var new_local := Rect2(x, y, new_w, _th + 14.0)
	var content_h := y + row_h + pad
	_max_scroll = maxf(0.0, content_h - _table_rect.size.y)
	_scroll = clampf(_scroll, 0.0, _max_scroll)
	var off := Vector2(0, _table_rect.position.y - _scroll)

	if table.is_empty() and not show_new:
		_text(_table_rect.get_center(), "아직 판이 비어 있어요", 26, Color(0.2, 0.45, 0.35, 0.6))
	for si in table.size():
		var tr: Rect2 = layout[si]
		tr.position += off
		var s: Array = table[si]
		var ok: bool = RummyLogic.analyze(s)["ok"]
		var has_fresh := false
		for tl in s:
			if fresh.has(tl):
				has_fresh = true
		var tray := Color(1, 1, 1, 0.5)
		if not ok:
			tray = Color("#FFD9D9")
		UIKit.draw_rbox(self, tr.grow(3), BAD if not ok else (Color(UIKit.GOLD, 0.8) if has_fresh else Color(1, 1, 1, 0.0)), 16)
		UIKit.draw_rbox(self, tr, tray, 14)
		if tr.end.y >= _table_rect.position.y and tr.position.y <= _table_rect.end.y:
			_sets_hit.append([tr.grow(4), si])
		for i in s.size():
			var tl: int = s[i]
			if _drag.has(tl):
				continue
			var r := Rect2(tr.position + Vector2(8.0 + i * (_tw + 3.0), 7.0), Vector2(_tw, _th))
			var lift := 7.0 if selected.has(tl) else 0.0
			_draw_tile(r, tl, selected.has(tl), fresh.has(tl), lift)
			if r.end.y > _table_rect.position.y and r.position.y < _table_rect.end.y:
				_tiles_hit.append([r, tl, "table", si])
	_new_rect = Rect2()
	if show_new:
		var nr := new_local
		nr.position += off
		_new_rect = nr
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		UIKit.draw_rbox(self, nr, Color(1, 1, 1, 0.35 + 0.2 * pulse), 14)
		_dashed_rect(nr, Color(0.2, 0.5, 0.38, 0.7))
		_text(nr.get_center() + Vector2(0, -8), "+", 34, Color(0.2, 0.5, 0.38), 900)
		_text(nr.get_center() + Vector2(0, 20), "새 묶음", 18, Color(0.2, 0.5, 0.38))


func _draw_rack() -> void:
	var r := _rack_rect
	UIKit.draw_rbox(self, Rect2(r.position + Vector2(0, 6), r.size), WOOD_DARK, 26)
	UIKit.draw_rbox(self, r, WOOD, 26)
	# 선반 두 줄
	for row in 2:
		var sy := r.position.y + 34.0 + row * (_rh + 10.0) + _rh - 2.0
		UIKit.draw_rbox(self, Rect2(r.position.x + 10, sy, r.size.x - 20, 8), WOOD_DARK, 4)
	_text(Vector2(r.position.x + 70, r.position.y + 17), rack_label, 19, Color("#6B3F17"))
	var per_row := maxi(8, ceili(rack.size() / 2.0))
	var row_w := per_row * (_rw + 4.0) - 4.0
	var x0 := r.position.x + (r.size.x - row_w) / 2.0
	for i in rack.size():
		var tl: int = rack[i]
		var row := i / per_row
		var col := i % per_row
		var tr := Rect2(x0 + col * (_rw + 4.0), r.position.y + 32.0 + row * (_rh + 10.0), _rw, _rh)
		if _drag.has(tl):
			UIKit.draw_rbox(self, tr, Color(0, 0, 0, 0.12), _rw * 0.18)
			continue
		var lift := 10.0 if selected.has(tl) else 0.0
		var sc := 1.0
		if _pop.has(tl):
			var k := (_t - float(_pop[tl])) / 0.45
			if k >= 1.0:
				_pop.erase(tl)
			else:
				sc = UIKit.ease_out_back(clampf(k, 0.0, 1.0))
				lift += (1.0 - k) * 20.0
		if sc < 1.0:
			draw_set_transform(tr.get_center(), 0.0, Vector2(sc, sc))
			_draw_tile(Rect2(-tr.size / 2.0 - Vector2(0, lift), tr.size), tl, selected.has(tl), false, 0.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_draw_tile(tr, tl, selected.has(tl), false, lift)
		_tiles_hit.append([tr, tl, "rack", -1])


## 타일 하나
func _draw_tile(r0: Rect2, tl: int, sel: bool, is_fresh: bool, lift: float) -> void:
	var r := Rect2(r0.position - Vector2(0, lift), r0.size)
	var rad := r.size.x * 0.18
	UIKit.draw_rbox(self, Rect2(r.position + Vector2(0, r.size.y * 0.1), r.size), Color(0.2, 0.1, 0.05, 0.18), rad)
	if sel:
		UIKit.draw_rbox(self, r.grow(4), UIKit.GOLD, rad + 4)
	UIKit.draw_rbox(self, Rect2(r.position + Vector2(0, r.size.y * 0.06), r.size), TILE_EDGE, rad)
	UIKit.draw_rbox(self, r, TILE_BG if not is_fresh else Color("#FFF3C4"), rad)
	if RummyLogic.is_joker(tl):
		_draw_joker(r)
		return
	var col: Color = NUM_COLORS[RummyLogic.color_of(tl)]
	var s := str(RummyLogic.num_of(tl))
	var fs := int(r.size.y * (0.5 if s.length() == 1 else 0.44))
	_text(Vector2(r.get_center().x, r.position.y + r.size.y * 0.42), s, fs, col, 900)
	draw_circle(Vector2(r.get_center().x, r.position.y + r.size.y * 0.78), r.size.x * 0.11, Color(col, 0.85), true, -1.0, true)
	draw_circle(Vector2(r.get_center().x, r.position.y + r.size.y * 0.78), r.size.x * 0.05, TILE_BG, true, -1.0, true)


func _draw_joker(r: Rect2) -> void:
	var c := r.get_center() + Vector2(0, -r.size.y * 0.04)
	var rad := r.size.x * 0.32
	draw_circle(c, rad, UIKit.GOLD, true, -1.0, true)
	draw_arc(c, rad, 0, TAU, 24, Color("#E08E0B"), maxf(1.5, rad * 0.12), true)
	var ink := Color("#3D3450")
	draw_circle(c + Vector2(-rad * 0.36, -rad * 0.2), rad * 0.13, ink, true, -1.0, true)
	draw_circle(c + Vector2(rad * 0.36, -rad * 0.2), rad * 0.13, ink, true, -1.0, true)
	draw_arc(c + Vector2(0, rad * 0.05), rad * 0.5, 0.2, PI - 0.2, 12, ink, maxf(1.5, rad * 0.13), true)
	var cols := NUM_COLORS
	for i in 4:
		draw_circle(Vector2(r.position.x + r.size.x * (0.2 + i * 0.2), r.position.y + r.size.y * 0.86), r.size.x * 0.06, cols[i], true, -1.0, true)


func _dashed_rect(r: Rect2, col: Color) -> void:
	var dash := 9.0
	var pts := [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
		[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]
	for seg in pts:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var len := a.distance_to(b)
		var d := (b - a) / len
		var s := 6.0
		while s < len - 6.0:
			draw_line(a + d * s, a + d * minf(s + dash, len - 6.0), col, 3.0, true)
			s += dash * 2.0


func _text(center: Vector2, s: String, fs: int, col: Color, weight: int = 800) -> void:
	if fs < 4:
		return
	var f := UIKit.font(weight)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(center.x - w / 2.0, center.y + (f.get_ascent(fs) - f.get_descent(fs)) / 2.0), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _chip_right(right_center: Vector2, s: String, fs: int, bg: Color) -> void:
	var f := UIKit.font(800)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 1.2
	var h := fs * 1.5
	UIKit.draw_rbox(self, Rect2(right_center.x - w, right_center.y - h / 2.0, w, h), bg, h / 2.0)
	_text(Vector2(right_center.x - w / 2.0, right_center.y), s, fs, Color.WHITE)


# ══════════════════════════════════════════════════════
#  입력
# ══════════════════════════════════════════════════════
func _hit(pos: Vector2) -> Dictionary:
	for i in range(_tiles_hit.size() - 1, -1, -1):
		var h: Array = _tiles_hit[i]
		if (h[0] as Rect2).grow(2).has_point(pos):
			return {"kind": "tile", "tile": h[1], "area": h[2], "set": h[3]}
	if _new_rect.size.x > 0 and _new_rect.grow(6).has_point(pos):
		return {"kind": "new"}
	for sh in _sets_hit:
		if (sh[0] as Rect2).has_point(pos):
			return {"kind": "set", "set": sh[1]}
	if _rack_rect.has_point(pos):
		return {"kind": "rack"}
	return {"kind": "none"}


func _drop_target(pos: Vector2) -> Dictionary:
	if _rack_rect.grow(6).has_point(pos):
		return {"kind": "rack"}
	if _new_rect.size.x > 0 and _new_rect.grow(12).has_point(pos):
		return {"kind": "new"}
	for sh in _sets_hit:
		if (sh[0] as Rect2).grow(12).has_point(pos):
			return {"kind": "set", "set": sh[1]}
	if _table_rect.has_point(pos):
		return {"kind": "new"}
	return {"kind": "none"}


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_scroll = clampf(_scroll + (-50.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 50.0), 0.0, _max_scroll)
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press = true
			_press_pos = mb.position
			_press_hit = _hit(mb.position)
			_drag = []
			_scrolling = false
		else:
			if not _drag.is_empty():
				var tiles := _drag.duplicate()
				var target := _drop_target(mb.position)
				_drag = []
				dropped.emit(tiles, target)
			elif _press and not _scrolling:
				tapped.emit(_press_hit)
			_press = false
			_scrolling = false
		accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _press:
		if _drag.is_empty() and not _scrolling and mm.position.distance_to(_press_pos) > 14.0:
			var tl := int(_press_hit.get("tile", -1))
			if interactive and _press_hit.get("kind", "") == "tile" and (not drag_filter.is_valid() or drag_filter.call(tl)):
				if selected.has(tl):
					_drag = selected.keys()
				else:
					_drag = [tl]
			elif _table_rect.has_point(_press_pos):
				_scrolling = true
		if not _drag.is_empty():
			_drag_pos = mm.position
		elif _scrolling:
			_scroll = clampf(_scroll - mm.relative.y, 0.0, _max_scroll)
		accept_event()
