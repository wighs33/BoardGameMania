class_name FruitTable
extends Control
## 과일 종치기 탁자 – 카드 · 종 그리기, 펼치기 · 가져가기 애니메이션, 여러 손가락 터치
## 친구와 2인(face_to_face)이면 위쪽 사람 자리는 거꾸로 그려서 마주 보고 할 수 있어요
## 종은 하나: 2인 모드에서는 종의 아래 반쪽 = 아래 사람, 위 반쪽 = 위 사람
## 발열 줄이기: 층을 나눠 바뀐 층만 다시 그리고, 카드는 미리 그려 둔 그림(FruitAtlas)으로 찍어요

signal deck_tapped(p: int)
signal bell_tapped(p: int)

const FELT := Color("#7FC8A9")
const FELT_DARK := Color("#5FAF8E")

var logic: FruitLogic
var input_enabled: bool = false
var face_to_face: bool = false
var names: Array = []
var colors: Array = []
var human: int = 0                 # AI 대전에서 내 자리 (-1 = 없음)

var _time: float = 0.0
var _anims: Array = []             # {k, card, a, b, t0, d, rot}
var _hide_top: Dictionary = {}     # 자리 -> 펼치는 중이라 숨길 맨 위 카드 수
var _bell_t: float = -10.0
var _bell_ok: bool = true
var _bell_by: int = -1
var _msgs: Array = []              # {text, color, t0}
var _R: float = 80.0
var _cw: float = 120.0
var _ch: float = 166.0
var _key: int = 0                  # 판 모습 (바뀌었을 때만 다시 그리기)
var _flying: bool = false          # 지난 프레임에 날아가는 카드가 있었는지
var _ringing: bool = false         # 지난 프레임에 종이 흔들리고 있었는지
var _atlas: FruitAtlas
# 아래에서 위로 쌓인 층 (맨 아래 탁자는 이 노드가 직접 그림)
var _glow: Control                 # 차례 표시 (계속 반짝임)
var _cards: Control                # 펼친 카드 · 엎은 더미
var _labels: Control               # 탈락 · 이름
var _hint: Control                 # '눌러서 펼치기!'
var _bell: Control
var _fly: Control                  # 날아가는 카드
var _note: Control                 # 2인 모드 알림


func _init() -> void:
	_atlas = FruitAtlas.new()
	add_child(_atlas)
	var mat := UIKit.premult_material()
	_glow = _add_layer(_draw_glow)
	_cards = _add_layer(_draw_cards, mat)
	_labels = _add_layer(_draw_labels)
	_hint = _add_layer(_draw_hint)
	_bell = _add_layer(_draw_bell)
	_fly = _add_layer(_draw_fly, mat)
	_note = _add_layer(_draw_note)


func _add_layer(painter: Callable, mat: Material = null) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.material = mat
	c.draw.connect(painter)
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func setup(L: FruitLogic) -> void:
	logic = L
	_anims.clear()
	_hide_top.clear()
	_msgs.clear()
	_bell_t = -10.0
	_sync()


func _process(delta: float) -> void:
	_time += delta
	for i in range(_anims.size() - 1, -1, -1):
		var a: Dictionary = _anims[i]
		if _time > float(a["t0"]) + float(a["d"]):
			if a.has("unhide"):
				var p: int = a["unhide"]
				_hide_top[p] = maxi(0, int(_hide_top.get(p, 0)) - 1)
			_anims.remove_at(i)
	_sync()
	# 계속 움직이는 것만 매 프레임
	_glow.queue_redraw()
	_hint.modulate.a = 0.6 + 0.4 * _pulse()
	if _flying or not _anims.is_empty():
		_flying = not _anims.is_empty()
		_fly.queue_redraw()
	if _ringing or _bell_shake() > 0.0:
		_ringing = _bell_shake() > 0.0
		_bell.queue_redraw()
	if _note.visible:
		_note.modulate.a = clampf((1.6 - (_time - float(_msgs[0]["t0"]))) / 0.3, 0.0, 1.0) if not _msgs.is_empty() else 0.0
		_note.visible = _note.modulate.a > 0.0


func _pulse() -> float:
	return 0.5 + 0.5 * sin(_time * 6.0)


func _bell_shake() -> float:
	return clampf(1.0 - (_time - _bell_t) / 0.55, 0.0, 1.0)


## 판 모습이 바뀌었으면 배치를 다시 잡고 가만히 있는 층들을 다시 그림
func _sync() -> void:
	if logic == null or size.x < 10.0 or not is_inside_tree():
		return
	var px := get_viewport_transform().get_scale().x
	var look: Array = [size, px, logic.n, logic.current, logic.over, logic.out, logic.decks, face_to_face, human, names, colors, _hide_top]
	for p in logic.n:
		var pile: Array = logic.piles[p]
		look.append(pile.size())
		look.append(pile.slice(-4))
	var key := hash(look)
	if key == _key:
		return
	_key = key
	_layout()
	_atlas.prepare(Vector2(_cw, _ch), px)
	queue_redraw()
	for c in [_cards, _labels, _hint, _bell]:
		(c as Control).queue_redraw()


# ── 자리 배치 ─────────────────────────────────────────
func _layout() -> void:
	var n := logic.n if logic != null else 2
	_R = minf(size.x * 0.12, size.y * 0.085)
	_cw = minf(size.x * (0.17 if n == 4 else 0.2), 140.0)
	var avail := size.y * 0.5 - _R - 20.0
	var need := 16.0 + _cw * 1.38 * 2.0 + 20.0 + 46.0
	if need > avail:
		_cw *= avail / need
	_ch = _cw * 1.38


## 자리 정보 {pile, deck, rot, label, side}  (side: 0 아래, 1 위, 2 왼쪽, 3 오른쪽)
func seat(p: int) -> Dictionary:
	var n := logic.n
	var c := size / 2.0
	var side := 0
	var x := c.x
	if p > 0:
		match n:
			2:
				side = 1
			3:
				side = 1
				x = c.x + (-1.0 if p == 1 else 1.0) * size.x * 0.25
			4:
				side = [0, 2, 1, 3][p]
	var py := _R + 16.0 + _ch * 0.5
	var dy := py + _ch + 18.0
	match side:
		0:
			return {"pile": Vector2(x, c.y + py), "deck": Vector2(x, c.y + dy), "rot": 0.0,
				"label": Vector2(x, c.y + dy + _ch * 0.5 + 24.0), "side": 0}
		1:
			var rot := PI if face_to_face else 0.0
			return {"pile": Vector2(x, c.y - py), "deck": Vector2(x, c.y - dy), "rot": rot,
				"label": Vector2(x, c.y - dy - _ch * 0.5 - 24.0), "side": 1}
		_:
			var sx := -1.0 if side == 2 else 1.0
			var px := c.x + sx * (_R + 30.0 + _cw * 0.5)
			return {"pile": Vector2(px, c.y - _ch * 0.12), "deck": Vector2(px + sx * (_cw * 0.18), c.y + _ch * 0.98), "rot": 0.0,
				"label": Vector2(px + sx * (_cw * 0.18), c.y + _ch * 0.98 + _ch * 0.5 + 22.0), "side": side}


func _card_rect(center: Vector2) -> Rect2:
	return Rect2(center - Vector2(_cw, _ch) / 2.0, Vector2(_cw, _ch))


# ── 애니메이션 요청 ────────────────────────────────────
func anim_flip(p: int, card: int) -> void:
	var s := seat(p)
	_hide_top[p] = int(_hide_top.get(p, 0)) + 1
	_anims.append({"k": "flip", "card": card, "a": s["deck"], "b": s["pile"], "t0": _time, "d": 0.24, "rot": s["rot"], "unhide": p})
	_sync()


## 맞게 친 사람이 펼친 카드를 가져감. taken: [[주인, 장수, 맨 위 카드]…]
func anim_collect(taken: Array, winner: int) -> void:
	var to: Vector2 = seat(winner)["deck"]
	var i := 0
	for t in taken:
		var s := seat(int(t[0]))
		for j in mini(int(t[1]), 3):
			var front := j == 0
			_anims.append({"k": "fly", "card": int(t[2]) if front else -1, "a": s["pile"], "b": to, "t0": _time + 0.12 + i * 0.06 + j * 0.05,
				"d": 0.45, "rot": s["rot"]})
		i += 1
	_sync()


## 틀리게 친 사람이 한 장씩 나눠 줌
func anim_give(from: int, to_list: Array) -> void:
	var a: Vector2 = seat(from)["deck"]
	var i := 0
	for q in to_list:
		_anims.append({"k": "fly", "card": -1, "a": a, "b": seat(int(q))["deck"], "t0": _time + 0.15 + i * 0.1, "d": 0.42, "rot": 0.0})
		i += 1
	_sync()


func bell(p: int, ok: bool) -> void:
	_bell_t = _time
	_bell_ok = ok
	_bell_by = p
	_bell.queue_redraw()


## 2인 모드 알림 (양쪽 방향으로)
func say(text: String, color: Color = Color(0.24, 0.2, 0.31)) -> void:
	_msgs = [{"text": text, "color": color, "t0": _time}]
	_note.visible = true
	_note.modulate.a = 1.0
	_note.queue_redraw()


func busy_time() -> float:
	var left := 0.0
	for a in _anims:
		left = maxf(left, float(a["t0"]) + float(a["d"]) - _time)
	return left


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	if logic == null or size.x < 10.0:
		return
	var c := size / 2.0
	# 탁자
	var table := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	UIKit.draw_rbox(self, Rect2(table.position + Vector2(0, 8), table.size), Color(0.3, 0.2, 0.25, 0.15), 48)
	UIKit.draw_rbox(self, table, FELT_DARK, 48)
	UIKit.draw_rbox(self, table.grow(-10), FELT, 40)
	if face_to_face:
		for i in 14:
			var x := table.position.x + 30.0 + i * (table.size.x - 60.0) / 13.0
			draw_circle(Vector2(x, c.y), 3.0, Color(1, 1, 1, 0.45), true, -1.0, true)
	# 카드 놓는 자리
	for p in logic.n:
		var s := seat(p)
		UIKit.draw_rbox(self, _card_rect(s["pile"]).grow(4), Color(1, 1, 1, 0.22), _cw * 0.16)


func _draw_glow() -> void:
	if logic == null or size.x < 10.0:
		return
	var p := logic.current
	if not logic.over and not logic.out[p]:
		var pulse := _pulse()
		UIKit.draw_rbox(_glow, _card_rect(seat(p)["deck"]).grow(9.0 + 3.0 * pulse), Color(colors[p], 0.45 + 0.35 * pulse), _cw * 0.2)
	for q in logic.n:
		if (logic.decks[q] as Array).is_empty():
			UIKit.draw_rbox(_glow, _card_rect(seat(q)["deck"]), Color(1, 1, 1, 0.18), _cw * 0.14)


func _draw_cards() -> void:
	if logic == null or size.x < 10.0:
		return
	for p in logic.n:
		var s := seat(p)
		var rot: float = s["rot"]
		# 펼친 카드 (맨 위 두 장까지 살짝 겹쳐 보임)
		var pile: Array = logic.piles[p]
		var shown := pile.size() - int(_hide_top.get(p, 0))
		for j in range(maxi(0, shown - 3), shown):
			var depth := shown - 1 - j
			var off := Vector2(sin(j * 2.1) * 4.0, cos(j * 1.7) * 3.0) * float(depth)
			_atlas.draw_face(_cards, (s["pile"] as Vector2) + off, int(pile[j]), rot + sin(j * 1.3) * 0.06 * float(depth))
		# 엎은 카드 더미
		var layers := mini(5, int(ceil((logic.decks[p] as Array).size() / 6.0)))
		for j in layers:
			_atlas.draw_back(_cards, (s["deck"] as Vector2) - Vector2(0, (layers - 1 - j) * 3.0), rot)


func _draw_labels() -> void:
	if logic == null or size.x < 10.0:
		return
	for p in logic.n:
		var s := seat(p)
		var rot: float = s["rot"]
		if logic.out[p]:
			var dr := _card_rect(s["deck"])
			UIKit.draw_rbox(_labels, dr.grow(4), Color(0.25, 0.2, 0.3, 0.55), _cw * 0.16)
			_text(_labels, "탈락", dr.get_center(), 30, Color.WHITE, rot)
		_chip(_labels, "%s · %d장" % [names[p], logic.card_count(p)], s["label"], colors[p], rot)


func _draw_hint() -> void:
	if logic == null or size.x < 10.0 or logic.over:
		return
	var p := logic.current
	var s := seat(p)
	if face_to_face:
		var pos: Vector2 = s["deck"] + Vector2(_cw * 0.5 + 70.0, 0) * (1.0 if p == 0 else -1.0)
		_text(_hint, "펼치기!", pos, 24, Color.WHITE, s["rot"])
	elif p == human and not logic.out[p]:
		_text(_hint, "눌러서 펼치기!", (s["deck"] as Vector2) + Vector2(0, _ch * 0.5 + 58.0), 22, Color.WHITE, 0.0)


func _draw_bell() -> void:
	if logic == null or size.x < 10.0:
		return
	var c := size / 2.0
	var shake := _bell_shake()
	FruitArt.draw_bell(_bell, c, _R, shake, _time, face_to_face)
	if shake > 0.0:
		var k := 1.0 - shake
		var dir := -1.0
		var rot := 0.0
		if face_to_face and _bell_by == 1:
			dir = 1.0
			rot = PI
		var pos := c + Vector2(0, dir * (_R * 1.25 + 30.0 * k))
		var col := Color("#FFB61E") if _bell_ok else Color("#FF4F5E")
		for i in 10:
			var a := TAU * i / 10.0
			_bell.draw_line(c + Vector2(cos(a), sin(a)) * _R * (1.05 + 0.3 * k), c + Vector2(cos(a), sin(a)) * _R * (1.25 + 0.5 * k),
				Color(col, shake), 5.0 * shake + 1.0, true)
		_text(_bell, "땡!" if _bell_ok else "삑!", pos, int(46 + 14 * k), Color(col.darkened(0.15), shake), rot, true)


func _draw_fly() -> void:
	for a in _anims:
		if _time < float(a["t0"]):
			continue
		var k := clampf((_time - float(a["t0"])) / float(a["d"]), 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var pos: Vector2 = (a["a"] as Vector2).lerp(a["b"], e) - Vector2(0, sin(k * PI) * _ch * 0.18)
		var rot: float = a["rot"]
		if str(a["k"]) == "flip":
			var sx := maxf(0.02, absf(cos(k * PI)))
			if k < 0.5:
				_atlas.draw_back(_fly, pos, rot, sx)
			else:
				_atlas.draw_face(_fly, pos, int(a["card"]), rot, sx)
		elif int(a["card"]) >= 0:
			_atlas.draw_face(_fly, pos, int(a["card"]), rot + k * 0.6)
		else:
			_atlas.draw_back(_fly, pos, rot + k * 0.6)


## 2인 모드 알림 (흐려지는 건 층 투명도로)
func _draw_note() -> void:
	var c := size / 2.0
	for m in _msgs:
		var col: Color = m["color"]
		_pill(_note, str(m["text"]), c + Vector2(0, _R * 1.05 + 40.0), Color(col, 0.92), 0.0)
		_pill(_note, str(m["text"]), c - Vector2(0, _R * 1.05 + 40.0), Color(col, 0.92), PI)


func _text(ci: CanvasItem, t: String, pos: Vector2, fs: int, col: Color, rot: float, outline: bool = false) -> void:
	var f := UIKit.font(900)
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_set_transform(pos, rot, Vector2.ONE)
	var base := Vector2(-w / 2.0, fs * 0.35)
	if outline:
		ci.draw_string_outline(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(1, 1, 1, col.a))
	ci.draw_string(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _chip(ci: CanvasItem, t: String, pos: Vector2, col: Color, rot: float) -> void:
	var f := UIKit.font(800)
	var fs := 24
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 30.0
	ci.draw_set_transform(pos, rot, Vector2.ONE)
	UIKit.draw_rbox(ci, Rect2(Vector2(-w / 2.0, -20 + 3), Vector2(w, 40)), col.darkened(0.25), 20)
	UIKit.draw_rbox(ci, Rect2(Vector2(-w / 2.0, -20), Vector2(w, 40)), col, 20)
	ci.draw_string(f, Vector2(-w / 2.0 + 15.0, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pill(ci: CanvasItem, t: String, pos: Vector2, col: Color, rot: float) -> void:
	var f := UIKit.font(800)
	var fs := 26
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 40.0
	ci.draw_set_transform(pos, rot, Vector2.ONE)
	UIKit.draw_rbox(ci, Rect2(Vector2(-w / 2.0, -24), Vector2(w, 48)), col, 24)
	ci.draw_string(f, Vector2(-w / 2.0 + 20.0, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, col.a))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── 입력 (여러 손가락: 먼저 누른 사람이 이김) ──────────
func _input(event: InputEvent) -> void:
	if not input_enabled or logic == null or not is_visible_in_tree():
		return
	var pos := Vector2.ZERO
	var st := event as InputEventScreenTouch
	var mb := event as InputEventMouseButton
	if st != null and st.pressed:
		pos = st.position
	elif mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.device != InputEvent.DEVICE_ID_EMULATION:
		pos = mb.position
	else:
		return
	var local := get_global_transform_with_canvas().affine_inverse() * pos
	if not Rect2(Vector2.ZERO, size).has_point(local):
		return
	var c := size / 2.0
	if local.distance_to(c) <= _R * 1.3:
		var who := human
		if face_to_face:
			who = 0 if local.y >= c.y else 1
		bell_tapped.emit(who)
		get_viewport().set_input_as_handled()
		return
	for p in logic.n:
		if _card_rect(seat(p)["deck"]).grow(18.0).has_point(local):
			deck_tapped.emit(p)
			get_viewport().set_input_as_handled()
			return
