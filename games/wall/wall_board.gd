class_name WallBoard
extends Control
## 벽 땅따먹기 보드 – 그리기와 터치 입력 담당 (규칙 판단은 컨트롤러/로직에서)

signal cell_pressed(cell: Vector2i)
signal edge_pressed(dir: int)

const FRAME := Color("#F4BE86")
const FRAME_DARK := Color("#D9925A")
const CELL := Color("#FFF7EA")
const NEUTRAL := Color("#E4DCD2")
const TARGET := Color("#3DD6A0")
const BREAK := Color("#FF8A3D")

var logic: WallLogic
var input_enabled: bool = false
## 로직의 플레이어 번호 → 색 (비어 있으면 기본 플레이어 색)
var seat_colors: Array = []

# ── 화면 표시 상태 (컨트롤러가 설정) ──
var selectable: Array[int] = []
var selected: int = -1
var targets: Dictionary = {}        # 칸 -> {"path", "broken"}
var wall_cell: Vector2i = Vector2i(-1, -1)
var wall_dirs: Array[int] = []
var place_mode: bool = false

# ── 애니메이션 상태 ──
var draw_pos: Array[Vector2] = []
var hop := PackedFloat32Array()
var spawn_time := PackedFloat32Array()
var wall_anim: Dictionary = {}
var last_wall_key: String = ""
var _broken_fx: Array = []          # [시작 시각, 칸, 방향, 색]

var _time: float = 0.0
var _info: Dictionary = {}
var _inner := Rect2()
var _cell: float = 0.0
var _gap: float = 0.0
var _pad: float = 0.0


func setup(L: WallLogic, colors: Array = []) -> void:
	logic = L
	seat_colors = colors
	draw_pos.clear()
	hop = PackedFloat32Array()
	spawn_time = PackedFloat32Array()
	wall_anim.clear()
	_broken_fx.clear()
	last_wall_key = ""
	clear_hints()
	sync_pieces()
	refresh()


func clear_hints() -> void:
	selectable = []
	selected = -1
	targets = {}
	wall_cell = Vector2i(-1, -1)
	wall_dirs = []
	place_mode = false


func _pc(owner: int) -> Color:
	if owner >= 0 and owner < seat_colors.size():
		return seat_colors[owner]
	return UIKit.player_color(owner)


## 로직에 새로 생긴 말을 화면에도 추가
func sync_pieces() -> void:
	while draw_pos.size() < logic.piece_pos.size():
		var i := draw_pos.size()
		draw_pos.append(Vector2(logic.piece_pos[i]))
		hop.append(0.0)
		spawn_time.append(_time)


func snap_piece(i: int) -> void:
	draw_pos[i] = Vector2(logic.piece_pos[i])
	hop[i] = 0.0


func refresh() -> void:
	if logic != null:
		_info = logic.regions()
	queue_redraw()


func mark_wall(c: Vector2i, d: int) -> void:
	var key := logic.wall_key(c, d)
	wall_anim[key] = _time
	last_wall_key = key
	refresh()


## 부서진 벽이 조각나 흩어지는 효과
func mark_broken(slot: Vector2i, owner_value: int) -> void:
	var cd := logic.slot_cell_dir(slot)
	_broken_fx.append([_time, cd[0], cd[1], _pc(owner_value - 1).darkened(0.22) if owner_value > 0 else Color.GRAY])
	refresh()


## 경로를 따라 한 칸씩 폴짝폴짝 이동
func animate_move(i: int, path: Array) -> void:
	if path.is_empty():
		var t0 := create_tween()
		t0.tween_method(_hop_only.bind(i), 0.0, 1.0, 0.24)
		await t0.finished
		hop[i] = 0.0
		return
	for c in path:
		var from: Vector2 = draw_pos[i]
		var to := Vector2(c)
		var t := create_tween()
		t.tween_method(_step.bind(i, from, to), 0.0, 1.0, 0.17).set_trans(Tween.TRANS_SINE)
		await t.finished
	hop[i] = 0.0


func _step(k: float, i: int, from: Vector2, to: Vector2) -> void:
	draw_pos[i] = from.lerp(to, k)
	hop[i] = sin(k * PI) * 0.55


func _hop_only(k: float, i: int) -> void:
	hop[i] = sin(k * PI) * 0.7


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ── 레이아웃 ───────────────────────────────────────────
func _layout() -> void:
	var side := minf(size.x, size.y - 12.0)
	_pad = side * 0.035
	var inner_side := side - _pad * 2.0
	_cell = inner_side / float(logic.size)
	_gap = _cell * 0.17
	_inner = Rect2((size - Vector2(inner_side, inner_side)) / 2.0 - Vector2(0, 4), Vector2(inner_side, inner_side))


func _cell_center(v: Vector2) -> Vector2:
	return _inner.position + (v + Vector2(0.5, 0.5)) * _cell


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(_inner.position + Vector2(c) * _cell + Vector2(_gap, _gap) * 0.5, Vector2(_cell - _gap, _cell - _gap))


func _bar_rect(c: Vector2i, d: int, thick: float = 1.0) -> Rect2:
	var t := _gap * thick
	var ext := _gap * 0.42
	var x0 := _inner.position.x + c.x * _cell
	var y0 := _inner.position.y + c.y * _cell
	match d:
		0:
			return Rect2(x0 - ext, y0 - t * 0.5, _cell + ext * 2.0, t)
		2:
			return Rect2(x0 - ext, y0 + _cell - t * 0.5, _cell + ext * 2.0, t)
		3:
			return Rect2(x0 - t * 0.5, y0 - ext, t, _cell + ext * 2.0)
		_:
			return Rect2(x0 + _cell - t * 0.5, y0 - ext, t, _cell + ext * 2.0)


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	if logic == null or size.x < 10.0:
		return
	_layout()
	var n := logic.size
	var frame := _inner.grow(_pad)
	var fr := _pad * 1.6
	UIKit.draw_rbox(self, Rect2(frame.position + Vector2(0, _pad * 0.9), frame.size), Color(0.4, 0.2, 0.1, 0.16), fr)
	UIKit.draw_rbox(self, Rect2(frame.position + Vector2(0, _pad * 0.45), frame.size), FRAME_DARK, fr)
	UIKit.draw_rbox(self, frame, FRAME, fr)

	# 칸 (확정된 땅은 주인 색으로 물듦)
	var tint := logic.phase != WallLogic.Phase.PLACE
	var map: PackedInt32Array = _info.get("map", PackedInt32Array())
	var owners: Array = _info.get("owners", [])
	var cr := _cell * 0.17
	for y in n:
		for x in n:
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell)
			var col := CELL
			if tint and map.size() == n * n:
				var ow: Array = owners[map[y * n + x]]
				if ow.size() == 1:
					col = _pc(int(ow[0])).lerp(Color.WHITE, 0.72)
				elif ow.is_empty():
					col = NEUTRAL
			UIKit.draw_rbox(self, Rect2(rect.position + Vector2(0, _cell * 0.05), rect.size), col.darkened(0.09), cr)
			UIKit.draw_rbox(self, rect, col, cr)
			if place_mode and logic.piece_at(cell) == -1:
				var pulse := 0.5 + 0.5 * sin(_time * 4.0 + (x + y) * 0.5)
				draw_circle(rect.get_center(), _cell * (0.07 + 0.03 * pulse), Color(_pc(logic.current), 0.45), true, -1.0, true)

	# 이동 가능한 칸 (주황 = 벽을 부숴야 갈 수 있는 칸)
	var pulse_t := 0.5 + 0.5 * sin(_time * 5.0)
	for cell in targets:
		var rect := _cell_rect(cell)
		var brk := ((targets[cell] as Dictionary)["broken"] as Vector2i).x >= 0
		var tc := BREAK if brk else TARGET
		UIKit.draw_rbox(self, rect, Color(tc, 0.25 + 0.15 * pulse_t), cr)
		if selected >= 0 and cell != logic.piece_pos[selected]:
			draw_circle(rect.get_center(), _cell * (0.1 + 0.02 * pulse_t), tc.darkened(0.15), true, -1.0, true)

	# 벽
	for y in n - 1:
		for x in n:
			var v := logic.h_walls[y * n + x]
			if v > 0:
				_draw_wall(_bar_rect(Vector2i(x, y), 2), v - 1, "h%d" % (y * n + x))
	for y in n:
		for x in n - 1:
			var v := logic.v_walls[y * (n - 1) + x]
			if v > 0:
				_draw_wall(_bar_rect(Vector2i(x, y), 1), v - 1, "v%d" % (y * (n - 1) + x))

	# 부서진 벽 조각
	for i in range(_broken_fx.size() - 1, -1, -1):
		var fx: Array = _broken_fx[i]
		var age := _time - float(fx[0])
		if age > 0.8:
			_broken_fx.remove_at(i)
			continue
		var r := _bar_rect(fx[1], fx[2])
		var k := age / 0.8
		var col: Color = fx[3]
		col.a = 1.0 - k
		var horizontal := r.size.x > r.size.y
		for part in 3:
			var off := (part - 1) * (1.0 + k * 2.5)
			var pr: Rect2
			if horizontal:
				pr = Rect2(r.position + Vector2(r.size.x * part / 3.0 + off * 6.0, k * k * _cell * 0.6), Vector2(r.size.x / 3.2, r.size.y))
			else:
				pr = Rect2(r.position + Vector2(k * k * _cell * 0.3, r.size.y * part / 3.0 + off * 6.0), Vector2(r.size.x, r.size.y / 3.2))
			UIKit.draw_rbox(self, pr, col, minf(pr.size.x, pr.size.y) * 0.5)

	# 벽 세울 후보 (반짝반짝)
	if wall_cell.x >= 0:
		var pc := _pc(logic.current)
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		for d in wall_dirs:
			var r := _bar_rect(wall_cell, d, 1.25)
			var rad := minf(r.size.x, r.size.y) * 0.5
			UIKit.draw_rbox(self, r.grow(_gap * (0.15 + 0.12 * pulse)), Color(1, 1, 1, 0.75), rad * 1.4)
			UIKit.draw_rbox(self, r, Color(pc, 0.4 + 0.45 * pulse), rad)

	# 말 (아래쪽 말이 위에 겹치도록 y 순서로)
	var order := range(draw_pos.size())
	order.sort_custom(func(a: int, b: int) -> bool: return draw_pos[a].y < draw_pos[b].y)
	for i in order:
		_draw_piece(i, map, owners, tint)


func _draw_wall(rect: Rect2, owner: int, key: String) -> void:
	var col := _pc(owner).darkened(0.22)
	var r := rect
	if wall_anim.has(key):
		var age := _time - float(wall_anim[key])
		var k := clampf(age / 0.35, 0.0, 1.0)
		var s := UIKit.ease_out_back(k)
		r = Rect2(rect.get_center() - rect.size * s * 0.5, rect.size * s)
		if key == last_wall_key and age < 1.6:
			var glow := 1.0 - age / 1.6
			UIKit.draw_rbox(self, r.grow(_gap * 0.35 * glow), Color(1, 1, 1, 0.8 * glow), minf(r.size.x, r.size.y))
		if age > 2.0:
			wall_anim.erase(key)
	var rad := minf(r.size.x, r.size.y) * 0.5
	UIKit.draw_rbox(self, Rect2(r.position + Vector2(0, _gap * 0.2), r.size), col.darkened(0.35), rad)
	UIKit.draw_rbox(self, r, col, rad)
	UIKit.draw_rbox(self, Rect2(r.position + r.size * Vector2(0.12, 0.12), r.size * Vector2(0.76, 0.3)), Color(1, 1, 1, 0.22), rad * 0.5)


func _draw_piece(i: int, map: PackedInt32Array, owners: Array, tint: bool) -> void:
	var owner := logic.piece_owner[i]
	var col := _pc(owner)
	var center := _cell_center(draw_pos[i]) + Vector2(0, _cell * 0.02)
	var r := _cell * 0.33
	var sp := clampf((_time - spawn_time[i]) / 0.35, 0.0, 1.0)
	if sp < 1.0:
		r *= UIKit.ease_out_back(sp)
	var lift := hop[i]
	if i == selected:
		lift = maxf(lift, 0.3 + 0.15 * sin(_time * 7.0))
	if selected == -1 and selectable.has(i):
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		draw_arc(center, r * (1.28 + 0.08 * pulse), 0.0, TAU, 48, Color(col, 0.35 + 0.4 * pulse), _cell * 0.06, true)
	if i == selected:
		draw_arc(center, r * 1.32, 0.0, TAU, 48, Color.WHITE, _cell * 0.07, true)
	var happy := false
	if tint and map.size() > 0:
		var c := logic.piece_pos[i]
		happy = (owners[map[c.y * logic.size + c.x]] as Array).size() == 1
	var square := logic.rule == 2 and logic.piece_kind[i] == WallLogic.Kind.SQUARE
	PieceArt.draw_piece(self, center, r, col, _time, float(i), lift, happy, square)


# ── 입력 ───────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if not input_enabled or logic == null:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_tap(mb.position)
		accept_event()


func _tap(p: Vector2) -> void:
	# 벽 고르는 중: 말 기준으로 누른 방향과 가장 가까운 후보 변을 선택
	if wall_cell.x >= 0 and not wall_dirs.is_empty():
		var v := p - _cell_center(Vector2(wall_cell))
		if v.length() < _cell * 1.8 and v.length() > _cell * 0.1:
			var best := -1
			var best_dot := -2.0
			for d in wall_dirs:
				var dv := Vector2(WallLogic.DIRS[d])
				var dot := v.normalized().dot(dv)
				if dot > best_dot:
					best_dot = dot
					best = d
			if best >= 0 and best_dot > 0.35:
				edge_pressed.emit(best)
		return
	var rel := (p - _inner.position) / _cell
	var c := Vector2i(floori(rel.x), floori(rel.y))
	if logic.in_bounds(c):
		cell_pressed.emit(c)
