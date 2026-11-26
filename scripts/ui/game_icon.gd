class_name GameIcon
extends Control
## 게임 목록 카드에 들어가는 그림 아이콘 (코드로 그림)
## 바탕은 한 번만 그리고, 움직이는 것은 따로 그려 둔 조각의 자리 · 각도만 옮겨요. 화면 밖 아이콘은 쉼

var kind: String = "wall"
var accent: Color = Color("#FF8A65")
var _t: float = 0.0
var _key: Array = []
var _parts: Array[Node2D] = []     # 움직이는 조각
var _r := Rect2()                  # 안쪽 그림 자리
var _flip_side: bool = true
var _doodle_k: float = -1.0
var _blink: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if not is_visible_in_tree() or not get_global_rect().intersects(get_viewport_rect()):
		return
	var key := [size, kind, accent]
	if key != _key:
		_key = key
		_build()
	_animate()


func _layout() -> Rect2:
	var s := minf(size.x, size.y)
	return Rect2((size - Vector2(s, s)) / 2.0, Vector2(s, s * 0.95))


func _draw() -> void:
	var rect := _layout()
	var s := rect.size.x
	UIKit.draw_rbox(self, Rect2(rect.position + Vector2(0, s * 0.05), rect.size), accent.darkened(0.25), s * 0.26)
	UIKit.draw_rbox(self, rect, accent, s * 0.26)
	var r := Rect2(rect.position + Vector2(s * 0.17, s * 0.15), Vector2(s * 0.66, s * 0.66))
	match kind:
		"wall", "wall2":
			_draw_wall(r)
		"omok":
			_draw_omok(r)
		"reversi":
			_draw_flip(r)
		"davinci":
			for i in [0, 1, 3]:
				_draw_code_tile(self, r, i, Vector2.ZERO)
		"rummy":
			_draw_rummy(r)
		"hero":
			_draw_hero_chess(r)
		"fruit":
			pass
		"draw":
			_draw_paper(r)


# ── 움직이는 조각 ──────────────────────────────────────
func _part(at: Vector2, painter: Callable) -> Node2D:
	var n := Node2D.new()
	n.position = at
	n.draw.connect(func() -> void: painter.call(n))
	add_child(n)
	_parts.append(n)
	return n


func _piece(at: Vector2, rad: float, color: Color, phase: float, happy: bool = false, square: bool = false) -> void:
	var p := PieceNode.new(color, phase, happy, square)
	p.r = rad
	p.position = at
	add_child(p)
	_parts.append(p)


func _build() -> void:
	for n in _parts:
		n.queue_free()
	_parts.clear()
	_doodle_k = -1.0
	queue_redraw()
	var rect := _layout()
	var s := rect.size.x
	_r = Rect2(rect.position + Vector2(s * 0.17, s * 0.15), Vector2(s * 0.66, s * 0.66))
	var o := _r.position
	var c := _r.size.x
	match kind:
		"wall", "wall2":
			var k := c / 3.0
			_piece(o + Vector2(0.5, 0.5) * k, k * 0.34, UIKit.PLAYER_COLORS[0], 0.0, true, kind == "wall2")
			_piece(o + Vector2(2.5, 2.5) * k, k * 0.34, UIKit.PLAYER_COLORS[1], 1.0)
			if kind == "wall2":
				_piece(o + Vector2(2.5, 0.5) * k, k * 0.3, UIKit.PLAYER_COLORS[2], 2.0, false, true)
		"reversi":
			var k := c / 4.0
			_part(o + Vector2(3.5, 1.5) * k, func(n: Node2D) -> void:
				n.draw_circle(Vector2.ZERO, k * 0.38, Color("#2B2B3A") if _flip_side else Color("#FFFFFF"), true, -1.0, true))
		"liar":
			_piece(o + Vector2(c * 0.16, c * 0.8), c * 0.15, UIKit.PLAYER_COLORS[1], 0.0, true)
			_piece(o + Vector2(c * 0.84, c * 0.8), c * 0.15, UIKit.PLAYER_COLORS[3], 2.0, true)
			_piece(o + Vector2(c * 0.5, c * 0.84), c * 0.2, Color("#3D3450"), 1.0)
			_part(o + Vector2(c * 0.5, c * 0.28), _draw_balloon)
		"davinci":
			_part(o, func(n: Node2D) -> void: _draw_code_tile(n, _r, 2, -o))
		"rummy":
			_part(o + Vector2(c * 0.8, c * 0.2), _draw_joker)
		"hero":
			var cr := Rect2(o + Vector2(c * 0.33, -c * 0.02), Vector2(c, c) * 0.34)
			_part(cr.position, func(n: Node2D) -> void:
				HeroArt.draw_flag(n, Vector2(0.5, 0.34) * cr.size.x, cr.size.x, UIKit.player_color(1), _t))
			for h in [[Vector2(0.27, 0.72), HeroLogic.Kind.MAGICIAN, 0.0, true], [Vector2(0.74, 0.74), HeroLogic.Kind.KNIGHT, 1.0, false]]:
				var hr := c * 0.15
				_part(o + (h[0] as Vector2) * c, func(n: Node2D) -> void: PieceArt.draw_shadow(n, Vector2.ZERO, hr, 0.0))
				_part(o + (h[0] as Vector2) * c, func(n: Node2D) -> void:
					HeroArt.draw_hero(n, Vector2.ZERO, hr, h[1], UIKit.player_color(0), 0.0, h[2], 0.0, h[3], false, false, false, int(_blink), true, false))
		"fruit":
			var cw := c * 0.42
			for k: int in [3, 2]:
				_part(o + Vector2(c * (0.02 if k == 3 else 0.56), c * 0.02) + Vector2(cw, cw * 1.38) / 2.0, func(n: Node2D) -> void:
					FruitArt.draw_card(n, Rect2(-Vector2(cw, cw * 1.38) / 2.0, Vector2(cw, cw * 1.38)), FruitLogic.card(FruitLogic.Fruit.STRAWBERRY, k)))
			var bc := o + Vector2(c * 0.5, c * 0.8)
			_part(bc, func(n: Node2D) -> void: FruitArt.draw_bell_base(n, Vector2.ZERO, c * 0.24))
			_part(bc, func(n: Node2D) -> void: FruitArt.draw_bell_top(n, Vector2.ZERO, c * 0.24))
		"draw":
			var paper := Rect2(Vector2(0, c * 0.04), Vector2(c, c * 0.8))
			_part(o, func(n: Node2D) -> void:
				DrawDoodles.draw(n, DrawDoodles.strokes("사과"), paper.grow(-c * 0.1), minf(_doodle_k, 1.0), maxf(2.5, c * 0.045)))
			_part(o + Vector2(c * 0.86, c * 0.72), func(n: Node2D) -> void:
				n.draw_line(Vector2.ZERO, Vector2(c * 0.22, -c * 0.32), Color("#FFC93C"), c * 0.1, true)
				n.draw_line(Vector2.ZERO, Vector2(c * 0.05, -c * 0.07), Color("#3D3450"), c * 0.1, true))


func _animate() -> void:
	var o := _r.position
	var c := _r.size.x
	var bob := sin(_t * 3.0) * 0.5 + 0.5
	match kind:
		"wall", "wall2":
			(_parts[0] as PieceNode).pose(_t, bob * 0.3)
			(_parts[1] as PieceNode).pose(_t, 0.3 - bob * 0.3)
			if kind == "wall2":
				(_parts[2] as PieceNode).pose(_t, bob * 0.18)
		"reversi":
			var flip := sin(_t * 2.0)
			_parts[0].scale.x = maxf(0.08, absf(flip))
			if (flip > 0.0) != _flip_side:
				_flip_side = flip > 0.0
				_parts[0].queue_redraw()
		"liar":
			(_parts[0] as PieceNode).pose(_t, bob * 0.2)
			(_parts[1] as PieceNode).pose(_t, (1.0 - bob) * 0.2)
			(_parts[2] as PieceNode).pose(_t)
			_parts[3].position.y = o.y + c * 0.28 - bob * c * 0.04
		"davinci":
			_parts[0].position.y = o.y - (sin(_t * 3.5) * 0.5 + 0.5) * c * 0.08
		"rummy":
			_parts[0].rotation = -0.25 + sin(_t * 2.5) * 0.06
		"hero":
			if Engine.get_process_frames() % 3 == 0:
				_parts[0].queue_redraw()   # 깃발
			var blink := PieceArt.blinking(_t, 1.0)
			if blink != _blink:
				_blink = blink
				_parts[4].queue_redraw()
			var hr := c * 0.15
			for k in 2:
				var lift := (bob if k == 0 else 1.0 - bob) * 0.25
				var base := o + Vector2(0.27 if k == 0 else 0.74, 0.72 if k == 0 else 0.74) * c
				_parts[2 + k * 2].position = base - Vector2(0, lift * hr * 0.9)
				_parts[1 + k * 2].scale = Vector2.ONE * (0.95 - lift * 0.3) / 0.95
				_parts[1 + k * 2].position = base + Vector2(0, hr * 0.82) * (1.0 - _parts[1 + k * 2].scale.y)
		"fruit":
			var wob := sin(_t * 2.5) * 0.06
			_parts[0].rotation = -0.18 + wob
			_parts[1].rotation = 0.16 - wob
			_parts[3].position.x = o.x + c * 0.5 + (sin(_t * 60.0) * c * 0.24 * 0.05 if fmod(_t, 2.2) < 0.4 else 0.0)
		"draw":
			var k := minf(snappedf(fmod(_t * 0.5, 1.6), 0.02), 1.0)
			if k != _doodle_k:
				_doodle_k = k
				_parts[0].queue_redraw()


func _draw_wall(r: Rect2) -> void:
	var n := 3
	var c := r.size.x / n
	var g := c * 0.16
	UIKit.draw_rbox(self, r.grow(g), Color("#F6D2A2"), c * 0.3)
	for y in n:
		for x in n:
			var col := Color("#D3E3FF")
			if x < 2 and y < 2:
				col = Color("#FFD3D3")
			UIKit.draw_rbox(self, Rect2(r.position + Vector2(x, y) * c + Vector2(g, g) * 0.5, Vector2(c - g, c - g)), col, c * 0.22)
	var wall := Color("#4A3F5C")
	UIKit.draw_rbox(self, Rect2(r.position.x + 2 * c - g * 0.5, r.position.y - g * 0.5, g, c * 2 + g), wall, g * 0.5)
	UIKit.draw_rbox(self, Rect2(r.position.x - g * 0.5, r.position.y + 2 * c - g * 0.5, c * 2 + g, g), wall, g * 0.5)


func _draw_omok(r: Rect2) -> void:
	UIKit.draw_rbox(self, r.grow(r.size.x * 0.06), Color("#F3C77B"), r.size.x * 0.12)
	var n := 5
	var step := r.size.x / (n - 1)
	var line := Color("#9C6B3A")
	for i in n:
		draw_line(r.position + Vector2(i * step, 0), r.position + Vector2(i * step, r.size.y), line, 2.0, true)
		draw_line(r.position + Vector2(0, i * step), r.position + Vector2(r.size.x, i * step), line, 2.0, true)
	var stones := [[1, 1, 0], [2, 2, 1], [3, 1, 0], [2, 1, 1], [1, 3, 0], [3, 3, 1]]
	for st in stones:
		var p: Vector2 = r.position + Vector2(st[0], st[1]) * step
		var col := Color("#2B2B3A") if int(st[2]) == 0 else Color("#FFFFFF")
		draw_circle(p + Vector2(0, step * 0.06), step * 0.36, Color(0, 0, 0, 0.2), true, -1.0, true)
		draw_circle(p, step * 0.36, col, true, -1.0, true)


func _draw_flip(r: Rect2) -> void:
	UIKit.draw_rbox(self, r.grow(r.size.x * 0.06), Color("#2E9E62"), r.size.x * 0.12)
	var n := 4
	var c := r.size.x / n
	for i in range(1, n):
		draw_line(r.position + Vector2(i * c, 0), r.position + Vector2(i * c, r.size.y), Color(0, 0, 0, 0.2), 2.0, true)
		draw_line(r.position + Vector2(0, i * c), r.position + Vector2(r.size.x, i * c), Color(0, 0, 0, 0.2), 2.0, true)
	var discs := [[1, 1, 0], [2, 1, 1], [1, 2, 1], [2, 2, 0]]   # 오른쪽 위 [3, 1]은 뒤집히는 조각
	for d in discs:
		var p: Vector2 = r.position + (Vector2(d[0], d[1]) + Vector2(0.5, 0.5)) * c
		var col := Color("#2B2B3A") if int(d[2]) == 0 else Color("#FFFFFF")
		draw_circle(p, c * 0.38, col, true, -1.0, true)


## 물음표 말풍선
func _draw_balloon(n: Node2D) -> void:
	var c := _r.size.x
	n.draw_colored_polygon(PackedVector2Array([Vector2(-c * 0.06, c * 0.14), Vector2(c * 0.06, c * 0.14), Vector2(0, c * 0.25)]), Color.WHITE)
	n.draw_circle(Vector2.ZERO, c * 0.2, Color.WHITE, true, -1.0, true)
	var f := UIKit.font(900)
	var fs := int(c * 0.3)
	var w := f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	n.draw_string(f, Vector2(-w / 2.0, (f.get_ascent(fs) - f.get_descent(fs)) / 2.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#FF5E5E"))


func _draw_code_tile(ci: CanvasItem, r: Rect2, i: int, off: Vector2) -> void:
	var c := r.size.x
	var tw := c * 0.22
	var th := tw * 1.42
	var f := UIKit.font(900)
	var num: int = [1, 4, -1, 9][i]
	var tr := Rect2(r.position + off + Vector2(i * (tw + c * 0.04), c * 0.5 - th / 2.0), Vector2(tw, th))
	var body := Color("#2B2B3A") if i % 2 == 0 else Color("#FBFAFD")
	var ink := Color("#F4F1F8") if i % 2 == 0 else Color("#2B2B3A")
	UIKit.draw_rbox(ci, Rect2(tr.position + Vector2(0, th * 0.07), tr.size), body.darkened(0.35), tw * 0.22)
	UIKit.draw_rbox(ci, tr, body, tw * 0.22)
	var s := "?" if num < 0 else str(num)
	var fs := int(th * 0.5)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(f, tr.get_center() + Vector2(-w / 2.0, (f.get_ascent(fs) - f.get_descent(fs)) / 2.0), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#FFC93C") if num < 0 else ink)


func _draw_hero_chess(r: Rect2) -> void:
	var c := r.size.x
	UIKit.draw_rbox(self, r.grow(c * 0.06), Color("#93D99A"), c * 0.12)
	for i in 3:
		for j in 3:
			if (i + j) % 2 == 0:
				draw_rect(Rect2(r.position + Vector2(i, j) * c / 3.0, Vector2(c, c) / 3.0), Color("#86CF8D"))
	HeroArt.draw_castle(self, Rect2(r.position + Vector2(c * 0.33, -c * 0.02), Vector2(c, c) * 0.34), UIKit.player_color(1), 3, 0.0, 0.0, false)


func _draw_rummy(r: Rect2) -> void:
	var c := r.size.x
	var tw := c * 0.27
	var th := tw * 1.36
	var f := UIKit.font(900)
	var nums := [3, 4, 5]
	for i in 3:
		var tr := Rect2(r.position + Vector2(c * 0.02 + i * (tw + c * 0.03), c * 0.52 - th / 2.0), Vector2(tw, th))
		UIKit.draw_rbox(self, Rect2(tr.position + Vector2(0, th * 0.07), tr.size), Color("#E0C9A2"), tw * 0.2)
		UIKit.draw_rbox(self, tr, Color("#FFF8EC"), tw * 0.2)
		var s := str(nums[i])
		var fs := int(th * 0.5)
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(tr.get_center().x - w / 2.0, tr.position.y + th * 0.42 + (f.get_ascent(fs) - f.get_descent(fs)) / 2.0), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#E8505B"))
		draw_circle(Vector2(tr.get_center().x, tr.position.y + th * 0.8), tw * 0.1, Color("#E8505B"), true, -1.0, true)


## 조커 한 장 (살짝 기울어져 통통)
func _draw_joker(n: Node2D) -> void:
	var tw := _r.size.x * 0.27
	var th := tw * 1.36
	var jt := Rect2(-tw / 2.0, -th / 2.0, tw, th)
	UIKit.draw_rbox(n, Rect2(jt.position + Vector2(0, th * 0.07), jt.size), Color("#E0C9A2"), tw * 0.2)
	UIKit.draw_rbox(n, jt, Color("#FFF8EC"), tw * 0.2)
	n.draw_circle(Vector2(0, -th * 0.05), tw * 0.3, UIKit.GOLD, true, -1.0, true)
	n.draw_circle(Vector2(-tw * 0.11, -th * 0.09), tw * 0.045, Color("#3D3450"), true, -1.0, true)
	n.draw_circle(Vector2(tw * 0.11, -th * 0.09), tw * 0.045, Color("#3D3450"), true, -1.0, true)
	n.draw_arc(Vector2(0, -th * 0.04), tw * 0.15, 0.3, PI - 0.3, 10, Color("#3D3450"), 2.0, true)


func _draw_paper(r: Rect2) -> void:
	var c := r.size.x
	var paper := Rect2(r.position + Vector2(0, c * 0.04), Vector2(c, c * 0.8))
	UIKit.draw_rbox(self, Rect2(paper.position + Vector2(0, c * 0.04), paper.size), Color(0, 0, 0, 0.15), c * 0.12)
	UIKit.draw_rbox(self, paper, Color.WHITE, c * 0.12)
