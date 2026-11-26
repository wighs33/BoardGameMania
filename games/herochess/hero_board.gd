class_name HeroBoard
extends Control
## 히어로 체스 판 – 그리기(영웅 · 유령 · 지뢰 · 벽 · 성 하트)와 터치 입력. 공격 효과 모양은 HeroFx
## 발열 줄이기: 영웅 · 성 · 벽 · 지뢰는 HeroSprites 가 그려 둔 그림으로 찍고(모습이 바뀔 때만 다시 그림),
## 날개 · 깃발 같은 작은 흔들림은 5단계 그림을 돌려 씀. 층을 나눠 바뀐 층만 다시 그림. 움직임 · 효과는 그대로 매 프레임

signal cell_tapped(c: Vector2i)

const GRASS_A := Color("#93D99A")
const GRASS_B := Color("#86CF8D")
const FRAME := Color("#E7B57A")
const FRAME_DARK := Color("#C98F55")
const MOVE_C := Color("#2FBF71")
const ATTACK_C := Color("#FF4F5E")
const SKILL_C := Color("#FFB61E")
const SWAP_C := Color("#A77BFF")
const SHIELD_C := Color("#4FB3FF")
const DELETE_C := Color("#6B3FA0")
const SUMMON_C := Color("#FFC93C")
const GOLD := Color("#FFC93C")
const PURPLE_DARK := Color("#5A2D82")

var logic: HeroLogic
var input_enabled: bool = false
var selected: int = -1
var marks: Dictionary = {}         # 칸 -> 표시 종류 (move/attack/castle/stay/swap/barrier/exorcise/wall/summon/place …)
var pickable: Array = []           # 고를 수 있는 영웅 (살짝 반짝)
var info_id: int = -1              # 정보 칸에 보여 주는 영웅 (테두리)
var hide_team: int = -1            # 배치 중 숨기는 팀
var home_glow: int = -1            # 배치 중 밝게 보여 줄 끝줄의 주인
var castle_glow: int = -1          # 소환할 수 있는 성
var flip: bool = false             # 판을 180° 돌려 보여 줌 (온라인 대전에서 위쪽 자리인 사람: 내 성이 아래로)

var _draw_pos: Dictionary = {}     # 영웅 -> 그릴 위치(칸 좌표)
var _slides: Dictionary = {}       # 영웅 -> [경로(Array[Vector2]), 시작 시각, 걸리는 시간]
var _poofs: Array = []             # [{id, cell, t0}]
var _spawns: Dictionary = {}       # 영웅 -> 나타난 시각
var _fx: Array = []                # [{k, a, b, t0, d, c}]
var _castle_hit: Array = [-10.0, -10.0]
var _hop: Dictionary = {}          # 영웅 -> 시각
var _wall_seen: Dictionary = {}    # 벽 키 -> 처음 보인 시각
var _time: float = 0.0
var _origin := Vector2.ZERO
var _cell: float = 0.0
var _frame := Rect2()
# 유령 (쓰러진 영웅): 그 영웅 그림을 투명한 팀 색으로
var _ghost_draw: Dictionary = {}   # 유령 -> 그릴 위치(칸 좌표)
var _cross_draw: Dictionary = {}   # 플레이어 -> [쓰러진 천사의 십자가 자리(칸 좌표), 나타난 시각]
var _gslides: Dictionary = {}      # 유령 -> [경로, 시작 시각, 걸리는 시간]
var _ghost_born: Dictionary = {}   # 유령 -> 나타난 시각

const DARK_HZ := 12.0              # 흑기사의 불꽃을 1초에 다시 그리는 횟수
const PULSE_HZ := 12.0             # 반짝이는 표시를 1초에 다시 그리는 횟수
# 그림 번호. 하나에 8장씩: 흔들림 5단계(0~4) · 잠깐 모습(5: 눈 감음 · 움직이는 중) · 표식(6)
const S_GHOST := 200               # 영웅은 0~159
const S_CASTLE := 400
const S_TURRET := 420
const S_CROSS := 440
const S_MINE := 460
const S_WALL := 470
const S_STAR := 480                # 작은 별 · 큰 별
const S_BUBBLE := 482
const V_MOMENT := 5
const V_BADGE := 6
const BOX_MOMENT := 1.7            # 튀어 오르거나 기운이 퍼지는 모습은 크게
const BOX_SMALL := 1.2             # 성 · 포탑 · 벽 · 지뢰 · 십자가
const STAR_SMALL := 0.0561         # 별 반지름 (칸 단위): 무력 · 배리어 / 스턴
const STAR_BIG := 0.1

var _sprites: HeroSprites
# 아래에서 위로 쌓인 층 (맨 아래 판은 이 노드가 직접 그림)
var _low: Control                  # 배치 줄 · 소환할 성의 빛
var _objs: Control                 # 성 · 포탑 · 지뢰 · 십자가
var _under: Control                # 말 아래 표시
var _heroes: Control
var _walls: Control
var _over: Control                 # 말 위 표시 · 사라지는 영웅 · 효과
var _ghosts: Control
var _keys: Dictionary = {}         # 층 -> 마지막으로 그린 모습
var _order: Array = []             # 그리는 순서의 영웅
var _order_pos: Dictionary = {}    # 순서를 정했을 때의 자리
var _ghost_sprite: Dictionary = {} # 유령 -> 지금 그림 번호
var _ghosts_shown: bool = false    # 지난 프레임에 유령이 있었는지
var _cells_key: int = 0            # 벽 · 포탑 · 지뢰가 바뀌었는지
var _wall_list: Array = []         # [그림 번호, 벽 키, 시작 모서리, 끝 모서리, 주인]
var _turret_list: Array = []       # [칸 번호, 주인]
var _mine_list: Array = []         # [칸 번호, 주인]


func _init() -> void:
	_sprites = HeroSprites.new()
	add_child(_sprites)
	var mat := UIKit.premult_material()
	_low = _add_layer(_draw_low)
	_objs = _add_layer(_draw_objs, mat)
	_under = _add_layer(_draw_under)
	_heroes = _add_layer(_draw_heroes, mat)
	_walls = _add_layer(_draw_walls, mat)
	_over = _add_layer(_draw_over)
	_ghosts = _add_layer(_draw_ghosts, mat)


func _add_layer(painter: Callable, mat: Material = null) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.material = mat
	c.draw.connect(painter)
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func setup(L: HeroLogic) -> void:
	logic = L
	selected = -1
	marks = {}
	pickable = []
	info_id = -1
	_slides.clear()
	_poofs.clear()
	_spawns.clear()
	_fx.clear()
	_hop.clear()
	_wall_seen.clear()
	_castle_hit = [-10.0, -10.0]
	_keys.clear()
	_cells_key = 0
	sync()
	_mark_walls_seen()


## 그림 위치를 로직 위치에 맞춤
func sync() -> void:
	_draw_pos.clear()
	_slides.clear()
	_ghost_draw.clear()
	_gslides.clear()
	for id in HeroLogic.KINDS * 2:
		if logic.alive(id):
			_draw_pos[id] = Vector2(logic.pos[id])
		elif logic.has_ghost(id):
			_ghost_draw[id] = Vector2(logic.ghost_pos[id])
	_cross_draw.clear()
	for p in 2:
		if logic.cross[p] >= 0:
			_cross_draw[p] = [Vector2(logic.cross_cell(p)), -10.0]


# ── 쓰러진 천사의 십자가 ───────────────────────────────
func cross_spawn(p: int, cell: Vector2i, delay: float = 0.0) -> void:
	_cross_draw[p] = [Vector2(cell), _time + delay]


func cross_gone(p: int) -> void:
	_cross_draw.erase(p)


# ── 유령 ───────────────────────────────────────────────
func ghost_spawn(id: int, cell: Vector2i, delay: float = 0.0) -> void:
	_ghost_draw[id] = Vector2(cell)
	_ghost_born[id] = _time + delay


func ghost_slide(id: int, cells: Array, dur: float) -> void:
	var pts: Array[Vector2] = []
	for c in cells:
		pts.append(Vector2(c))
	_gslides[id] = [pts, _time, dur]
	_ghost_draw[id] = pts[0]


func ghost_poof(id: int) -> void:
	if _ghost_draw.has(id):
		var c: Vector2 = _ghost_draw[id]
		_fx.append({"k": "spook", "a": c, "b": c, "t0": _time, "d": 0.8, "c": Color("#B9C6FF")})
	_ghost_draw.erase(id)
	_gslides.erase(id)


## 유령 색: 반투명한 팀 색
func ghost_tint(id: int) -> Color:
	return Color(UIKit.player_color(HeroLogic.owner_of(id)).lerp(Color.WHITE, 0.1), 0.52)


## 유령을 그릴 자리 [칸 가운데에서 비켜난 정도(칸 단위), 크기]. 부활시키러 온 천사와 같은 칸이면 구석에 작게
func _ghost_spot(id: int) -> Array:
	var gc: Vector2i = logic.ghost_pos[id]
	if gc != HeroLogic.NONE and Vector2(gc) == _ghost_draw[id] and logic.at(gc) >= 0:
		return [Vector2(-0.29, 0.25), 0.2]
	return [Vector2(0, 0.06), 0.33]


## 영웅 또는 유령이 그려지는 위치 (없으면 null)
func _any_pos(id: int) -> Variant:
	if _draw_pos.has(id):
		return _draw_pos[id]
	if _ghost_draw.has(id):
		return _ghost_draw[id]
	return null


func _mark_walls_seen() -> void:
	for i in HeroLogic.W * HeroLogic.H:
		if logic.wall_v[i] != 0:
			_wall_seen["v%d" % i] = -10.0
		if logic.wall_h[i] != 0:
			_wall_seen["h%d" % i] = -10.0


# ── 애니메이션 요청 ────────────────────────────────────
func slide(id: int, from: Vector2i, to: Vector2i, dur: float = 0.28, delay: float = 0.0) -> void:
	slide_path(id, [from, to], dur, delay)


func slide_path(id: int, cells: Array, dur: float, delay: float = 0.0) -> void:
	var pts: Array[Vector2] = []
	for c in cells:
		pts.append(Vector2(c))
	_slides[id] = [pts, _time + delay, dur]
	_draw_pos[id] = pts[0]
	_hop[id] = _time + delay


## 영웅이 사라지는 효과 (지금 그려진 자리에서)
func poof(id: int, delay: float = 0.0) -> void:
	var at: Vector2 = _draw_pos.get(id, Vector2(-5, -5))
	_poofs.append({"id": id, "cell": at, "t0": _time + delay})
	_draw_pos.erase(id)
	_slides.erase(id)


## 부활 · 소환으로 나타남
func spawn(id: int, cell: Vector2i, delay: float = 0.0) -> void:
	_draw_pos[id] = Vector2(cell)
	_spawns[id] = _time + delay
	fx("rise", cell, cell, GOLD, delay)


func fx(kind: String, a: Vector2i, b: Vector2i = Vector2i(-99, -99), color: Color = Color.WHITE, delay: float = 0.0,
		dur: float = -1.0) -> void:
	if b == Vector2i(-99, -99):
		b = a
	var d := dur if dur > 0.0 else _fx_dur(kind)
	_fx.append({"k": kind, "a": Vector2(a), "b": Vector2(b), "t0": _time + delay, "d": d, "c": color})


func _fx_dur(kind: String) -> float:
	match kind:
		"holy", "rise", "reap", "spook", "boom":
			return 0.8
		"heart":
			return 0.9
		"dust", "smoke":
			return 0.55
	return 0.6


## 공격 효과: 영웅마다 다르게 (style = 공격에 쓴 능력 종류)
func attack_fx(style: int, from: Vector2i, cell: Vector2i, delay: float = 0.0) -> void:
	var K := HeroLogic.Kind
	match style:
		K.KNIGHT:
			fx("lance", from, cell, GOLD, delay, 0.35)
			fx("burst", cell, cell, GOLD, delay + 0.18)
		K.SOLDIER:
			fx("slash", cell, cell, Color.WHITE, delay)
		K.ANGEL:
			fx("holy", cell, cell, GOLD, delay)
		K.MAGICIAN:
			fx("fireball", from, cell, Color("#FF8A3D"), delay, 0.7)
			fx("stars", cell, cell, Color("#FF7EB6"), delay + 0.4)
		K.REAPER:
			fx("reap", cell, cell, Color.WHITE, delay)
		K.PRIEST:
			fx("crosshit", from, cell, Color("#FFD34D"), delay, 0.5)
			fx("cross", cell, cell, Color("#FFF3B0"), delay + 0.2)
		K.WARRIOR:
			fx("shock", cell, cell, Color("#E0884A"), delay)
		_:
			fx("burst", cell, cell, ATTACK_C, delay)


func castle_hit(p: int, delay: float = 0.0) -> void:
	_castle_hit[p] = _time + delay
	fx("heart", HeroLogic.CASTLE[p], HeroLogic.CASTLE[p], HeroArt.HEART, delay)


func hop(id: int) -> void:
	_hop[id] = _time


func _process(delta: float) -> void:
	_time += delta
	for id in _slides.keys():
		var s: Array = _slides[id]
		var pts: Array = s[0]
		var k := clampf((_time - float(s[1])) / float(s[2]), 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var segs := pts.size() - 1
		var f := e * segs
		var i := mini(int(f), segs - 1)
		_draw_pos[id] = (pts[i] as Vector2).lerp(pts[i + 1], f - i)
		if k >= 1.0:
			_draw_pos[id] = pts[-1]
			_slides.erase(id)
	for id in _gslides.keys():
		var gs: Array = _gslides[id]
		var gpts: Array = gs[0]
		var gk := clampf((_time - float(gs[1])) / float(gs[2]), 0.0, 1.0)
		var gsegs := gpts.size() - 1
		if gsegs <= 0:
			_gslides.erase(id)
			continue
		var gf := gk * gsegs
		var gi := mini(int(gf), gsegs - 1)
		_ghost_draw[id] = (gpts[gi] as Vector2).lerp(gpts[gi + 1], gf - gi)
		if gk >= 1.0:
			_ghost_draw[id] = gpts[-1]
			_gslides.erase(id)
	# 끝난 움직임 · 효과 지우기
	for id in _hop.keys():
		if _time - float(_hop[id]) >= 0.32:
			_hop.erase(id)
	for id in _spawns.keys():
		if _time - float(_spawns[id]) >= 0.4:
			_spawns.erase(id)
	for id in _ghost_born.keys():
		if _time - float(_ghost_born[id]) >= 0.45:
			_ghost_born.erase(id)
	for i in range(_poofs.size() - 1, -1, -1):
		if _time - float(_poofs[i]["t0"]) > 0.5:
			_poofs.remove_at(i)
	for i in range(_fx.size() - 1, -1, -1):
		if _time - float(_fx[i]["t0"]) >= float(_fx[i]["d"]):
			_fx.remove_at(i)
	if logic != null and size.x >= 10.0 and is_visible_in_tree():
		_refresh()


## 남은 애니메이션 시간
func busy_time() -> float:
	var left := 0.0
	for id in _slides:
		var s: Array = _slides[id]
		left = maxf(left, float(s[1]) + float(s[2]) - _time)
	for id in _gslides:
		var gs: Array = _gslides[id]
		left = maxf(left, float(gs[1]) + float(gs[2]) - _time)
	for f in _poofs:
		left = maxf(left, float(f["t0"]) + 0.55 - _time)
	for f in _fx:
		left = maxf(left, float(f["t0"]) + float(f["d"]) * 0.7 - _time)
	return left


# ── 레이아웃 ───────────────────────────────────────────
func _layout() -> void:
	var pad := 0.18
	_cell = minf(size.x / (HeroLogic.W + pad * 2.0), (size.y - 8.0) / (HeroLogic.H + pad * 2.0))
	var board := Vector2(HeroLogic.W, HeroLogic.H) * _cell
	_origin = (size - board) / 2.0 - Vector2(0, 3)
	_frame = Rect2(_origin - Vector2(pad, pad) * _cell, board + Vector2(pad, pad) * 2.0 * _cell)


func cell_rect(c: Vector2i) -> Rect2:
	if flip:
		c = Vector2i(HeroLogic.W - 1 - c.x, HeroLogic.H - 1 - c.y)
	return Rect2(_origin + Vector2(c) * _cell, Vector2(_cell, _cell))


func _center(p: Vector2) -> Vector2:
	if flip:
		p = Vector2(HeroLogic.W - 1, HeroLogic.H - 1) - p
	return _origin + (p + Vector2(0.5, 0.5)) * _cell


## 칸 모서리 좌표(x, y는 0~W, 0~H) → 화면 위치
func _pt(v: Vector2) -> Vector2:
	if flip:
		v = Vector2(HeroLogic.W, HeroLogic.H) - v
	return _origin + v * _cell


# ── 바뀐 것만 다시 그리기 ───────────────────────────────
func _refresh() -> void:
	_layout()
	_sprites.prepare(_cell, get_viewport_transform().get_scale().x)
	var place: Array = [size, flip]
	_redraw_if(self, place)
	_scan_cells()
	var pulse_step := int(_time * PULSE_HZ)
	_redraw_if(_low, place + [home_glow, castle_glow, pulse_step if home_glow >= 0 or castle_glow >= 0 else 0])
	_redraw_if(_objs, [_bake_objs(), place])
	# 말 아래 표시
	var spots: Array = []
	var cursed := false
	for id in _ghost_draw:
		spots.append(_ghost_spot(id))
		spots.append(logic.has_ghost(id))
		cursed = cursed or logic.cursed_by[id] >= 0
	var pulsing := cursed or selected >= 0 or castle_glow >= 0 or not pickable.is_empty() or not marks.is_empty()
	_redraw_if(_under, place + [hash(_ghost_draw), hash(_draw_pos), spots, hash(logic.cursed_by) if cursed else 0, pickable, selected, info_id,
		castle_glow, hash(marks), pulse_step if pulsing else 0])
	_redraw_if(_heroes, [_bake_heroes(), place])
	# 벽: 세워지는 중인 벽은 위층에서 그림
	var popping := 0
	var still: Array = []
	for w in _wall_list:
		if _time - float(_wall_seen.get(w[1], -10.0)) < 0.3:
			popping += 1
		else:
			_bake_wall(w[0], w[4])
			still.append([w[0], (_pt(w[2]) + _pt(w[3])) / 2.0])
	_redraw_if(_walls, [still, place])
	var moving := popping > 0 or not _poofs.is_empty() or not _fx.is_empty()
	_redraw_if(_over, place + [_time if moving else 0.0, hash(marks), selected, _draw_pos.get(selected), pulse_step if not marks.is_empty() else 0])
	_bake_ghosts()
	# 유령이 모두 사라진 판(무르기 · 새 게임)도 한 번은 다시 그려야 지난 그림이 안 남음
	if _ghosts_shown or not _ghost_draw.is_empty():
		_ghosts.queue_redraw()
	_ghosts_shown = not _ghost_draw.is_empty()


func _redraw_if(layer: Control, key: Array) -> void:
	if _keys.get(layer) != key:
		_keys[layer] = key
		layer.queue_redraw()


## 벽 · 포탑 · 지뢰 목록 (판이 바뀌었을 때만 다시 훑음)
func _scan_cells() -> void:
	var key := hash([logic.get_instance_id(), logic.wall_v, logic.wall_h, logic.turret, logic.mines])
	if key == _cells_key:
		return
	_cells_key = key
	_wall_list.clear()
	_turret_list.clear()
	_mine_list.clear()
	var seen := {}
	for i in HeroLogic.W * HeroLogic.H:
		var x := i % HeroLogic.W
		var y := i / HeroLogic.W
		if logic.wall_v[i] != 0:
			var p: int = logic.wall_v[i] - 1
			seen["v%d" % i] = _wall_seen.get("v%d" % i, _time)
			_wall_list.append([S_WALL + p * 2 + 1, "v%d" % i, Vector2(x + 1, y), Vector2(x + 1, y + 1), p])
		if logic.wall_h[i] != 0:
			var p: int = logic.wall_h[i] - 1
			seen["h%d" % i] = _wall_seen.get("h%d" % i, _time)
			_wall_list.append([S_WALL + p * 2, "h%d" % i, Vector2(x, y + 1), Vector2(x + 1, y + 1), p])
		var c := Vector2i(x, y)
		if logic.turret_at(c) >= 0:
			_turret_list.append([i, logic.turret_at(c)])
		if logic.mine_at(c) >= 0:
			_mine_list.append([i, logic.mine_at(c)])
	_wall_seen = seen


func _pulse() -> float:
	return 0.5 + 0.5 * sin(_time * 5.0)


## sin(t × omega)의 흔들림을 5단계로 (0~4), 그 단계를 그릴 시각
func _wave(omega: float, t: float) -> int:
	return roundi(asin(sin(t * omega)) / (PI / 2.0) * 2.0) + 2


func _wave_time(omega: float, level: int) -> float:
	return (level - 2) * PI / 4.0 / omega


# ── 성 · 포탑 · 지뢰 · 십자가 ──────────────────────────
## 그릴 것 [[그림 번호, 자리], …]
func _bake_objs() -> Array:
	var list: Array = []
	for p in 2:
		var lives: int = logic.lives[p]
		var hit := clampf(1.0 - (_time - float(_castle_hit[p])) / 0.6, 0.0, 1.0) if _time >= float(_castle_hit[p]) else 0.0
		var omega := 9.0 if lives == 1 else 4.0   # 목숨 1 이면 불꽃이 빠르게 일렁임
		var lv := _wave(omega, _time) if lives > 0 else 2
		var n := S_CASTLE + p * 8 + (V_MOMENT if hit > 0.0 else lv)
		var key := [lives, hit, lv]
		if _sprites.changed(n, key):
			_sprites.bake(n, key, _paint_castle.bind(p, hit, _wave_time(omega, lv)), Color.WHITE, BOX_SMALL)
		list.append([n, cell_rect(HeroLogic.CASTLE[p]).get_center()])
	for tu in _turret_list:
		var i: int = tu[0]
		var lv := _wave(4.0, _time + i % HeroLogic.W * 0.4)
		var n := S_TURRET + int(tu[1]) * 8 + lv
		if _sprites.changed(n, [1]):
			_sprites.bake(n, [1], _paint_turret.bind(int(tu[1]), _wave_time(4.0, lv)), Color.WHITE, BOX_SMALL)
		list.append([n, _center(Vector2(i % HeroLogic.W, i / HeroLogic.W))])
	for mi in _mine_list:
		var i: int = mi[0]
		var on := HeroArt.mine_on(_time + i % HeroLogic.W * 0.3)
		var n := S_MINE + int(mi[1]) * 2 + int(on)
		if _sprites.changed(n, [1]):
			_sprites.bake(n, [1], _paint_mine.bind(int(mi[1]), on), Color.WHITE, BOX_SMALL)
		list.append([n, _center(Vector2(i % HeroLogic.W, i / HeroLogic.W))])
	for p: int in _cross_draw:
		var grow := clampf((_time - float(_cross_draw[p][1])) / 0.4, 0.0, 1.0)
		if grow <= 0.0:
			continue
		var lv := _wave(2.4, _time + p)
		var n := S_CROSS + p * 8 + (V_MOMENT if grow < 1.0 else lv)
		var key := [grow, lv]
		if _sprites.changed(n, key):
			_sprites.bake(n, key, _paint_cross.bind(p, grow, _wave_time(2.4, lv)), Color.WHITE, BOX_SMALL)
		list.append([n, _center(_cross_draw[p][0])])
	return list


func _paint_castle(ci: CanvasItem, p: int, hit: float, t: float) -> void:
	var o := Vector2(-0.5, -0.5) * _cell
	HeroArt.draw_castle(ci, Rect2(o + Vector2(_cell * 0.08, _cell * 0.2), Vector2(_cell, _cell) * 0.84),
		UIKit.player_color(p), logic.lives[p], t, hit)
	HeroArt.draw_hearts(ci, o + Vector2(_cell * 0.5, _cell * 0.14), _cell * 0.27, logic.lives[p], HeroLogic.START_LIVES)


func _paint_turret(ci: CanvasItem, p: int, t: float) -> void:
	HeroArt.draw_turret(ci, Vector2.ZERO, _cell, UIKit.player_color(p), t)


func _paint_mine(ci: CanvasItem, p: int, on: bool) -> void:
	HeroArt.draw_mine(ci, Vector2.ZERO, _cell, UIKit.player_color(p), on)


func _paint_cross(ci: CanvasItem, p: int, grow: float, t: float) -> void:
	HeroArt.draw_cross(ci, Vector2.ZERO, _cell * grow, UIKit.player_color(p), t)


# ── 영웅 ───────────────────────────────────────────────
## 그릴 것 [[그림 번호, 자리, 크기, 색], …]
func _bake_heroes() -> Array:
	# 아래 줄일수록 나중에 그려서 위 칸 말의 몸을 살짝 가림
	if _order_pos != _draw_pos:
		for id: int in _order_pos:
			if not _draw_pos.has(id):
				_sprites.drop(id * 8, id * 8 + 7)
		_order_pos = _draw_pos.duplicate()
		_order = _draw_pos.keys()
		_order.sort_custom(func(a: int, b: int) -> bool: return (_draw_pos[a] as Vector2).y < (_draw_pos[b] as Vector2).y)
	var list: Array = []
	for id: int in _order:
		if HeroLogic.owner_of(id) != hide_team:
			_bake_hero(id, list)
	return list


func _bake_hero(id: int, list: Array) -> void:
	var lift := 0.0
	if _hop.has(id):
		var k := (_time - float(_hop[id])) / 0.32
		if k > 0.0 and k < 1.0:
			lift = sin(k * PI) * 0.6
	var sc := 1.0
	if _spawns.has(id):
		sc = clampf((_time - float(_spawns[id])) / 0.4, 0.0, 1.0)
		sc = sc * (1.0 + 0.3 * sin(sc * PI))
	var kind := _shown_kind(id)
	var live := logic.alive(id)
	var bound: bool = live and logic.disabled_by[id] >= 0
	var shield: bool = live and logic.barrier[id] != 0
	var horse: bool = live and logic.horse[id] != 0
	var dark: bool = live and logic.dark[id] != 0
	var cursed: bool = live and logic.cursed_by[id] >= 0
	var stunned: bool = live and logic.stunned[id] != 0
	var shared: bool = live and _shares_cell(id)
	var badges: Array = [cursed, stunned, live and logic.sealed[id] != 0, kind != HeroLogic.kind_of(id), live and _checked(id)]
	# 흔들림 단계
	var omega := HeroArt.sway(kind)
	if omega == 0.0:
		omega = 3.0 if horse else 4.0 if cursed else 1.5 if kind != HeroLogic.kind_of(id) else 0.0
	var lv := 2
	var t := 0.0
	if kind == HeroLogic.Kind.ROBOT:
		lv = int(HeroArt.robot_on(_time))
		t = 0.0 if lv == 1 else 0.7
	elif omega > 0.0:
		lv = _wave(omega, _time)
		t = _wave_time(omega, lv)
	var blink := PieceArt.blinking(_time, id * 0.9)
	var look: Array = [kind, live, bound, shield, horse, dark, shared, badges]
	var n := id * 8 + lv
	if blink or dark or shared or lift > 0.0 or sc != 1.0:
		n = id * 8 + V_MOMENT
		look.append_array([lift, sc, lv, blink, int(_time * DARK_HZ) if dark else 0])
		if dark:
			t = _time
	if _sprites.changed(n, look):
		_sprites.bake(n, look, _paint_hero.bind(id, kind, t, lift, sc, blink), Color.WHITE, BOX_MOMENT if n % 8 == V_MOMENT else HeroSprites.BOX)
	var p := _center(_draw_pos[id])
	list.append([n, p, 1.0, Color.WHITE])
	if not (bound or shield or stunned):
		return
	# 움직이는 것은 따로 얹음: 도는 별, 배리어 테두리
	var r := _cell * 0.33 * sc * (0.78 if shared else 1.0)
	var body := p + Vector2(0, _cell * 0.1) + (Vector2(0.22, -0.24) * _cell if shared else Vector2.ZERO)
	body -= Vector2(0, r * ((0.22 if horse else 0.0) + lift * 0.9))
	var zoom := r / (_cell * 0.33)
	if bound:
		for i in 3:
			list.append([_star_sprite(0), body + HeroArt.bound_star(_time, i) * r, zoom, HeroArt.GOLD])
	if shield:
		var wob := 1.0 + 0.035 * sin(_time * 4.0 + id * 0.9)
		var bc := body + Vector2(0, -r * 0.12)
		if _sprites.changed(S_BUBBLE, [1]):
			_sprites.bake(S_BUBBLE, [1], _paint_bubble, Color.WHITE, 1.15)
		list.append([S_BUBBLE, bc, zoom * wob, Color.WHITE])
		for i in 3:
			list.append([_star_sprite(0), bc + HeroArt.bubble_star(_time, id * 0.9, i) * r * 1.46 * wob, zoom, Color(0.95, 0.95, 0.95, 0.95)])
		if badges.has(true):
			# 표식은 배리어 테두리보다 위
			var bn := id * 8 + V_BADGE
			var bkey := badges + [lv]
			if _sprites.changed(bn, bkey):
				_sprites.bake(bn, bkey, _paint_badges.bind(id, t))
			list.append([bn, p, 1.0, Color.WHITE])
	if stunned:
		for i in 3:
			var sa := _time * 4.0 + TAU * i / 3.0
			list.append([_star_sprite(1), p + Vector2(cos(sa) * 0.22, -0.36 + sin(sa) * 0.08) * _cell, 1.0, GOLD])


func _star_sprite(big: int) -> int:
	var n := S_STAR + big
	if _sprites.changed(n, [1]):
		var rad := STAR_BIG if big == 1 else STAR_SMALL
		_sprites.bake(n, [1], _paint_star.bind(rad), Color.WHITE, rad * 2.6)
	return n


func _paint_star(ci: CanvasItem, rad: float) -> void:
	HeroArt._star(ci, Vector2.ZERO, _cell * rad, Color.WHITE)


func _paint_bubble(ci: CanvasItem) -> void:
	var r := _cell * 0.33
	HeroArt._bubble(ci, Vector2.ZERO, r * 1.46, r)


## 그려지는 모습 (따라 한 모습을 유지하는 닌자는 그 영웅)
func _shown_kind(id: int) -> int:
	var kind := HeroLogic.kind_of(id)
	if kind == HeroLogic.Kind.NINJA and logic.alive(id):
		var form: int = logic.ninja_form[HeroLogic.owner_of(id)]
		if form >= 0:
			return form
	return kind


## 천사가 영웅 칸에 잠깐 함께 서 있는지
func _shares_cell(id: int) -> bool:
	return logic.at(logic.pos[id]) != id


## 이번 차례에 이미 행동했는지 (체크 표시)
func _checked(id: int) -> bool:
	return logic.phase == HeroLogic.Phase.ACT and HeroLogic.owner_of(id) == logic.current and logic.has_acted(id) and logic.act_hero != id


func _paint_hero(ci: CanvasItem, id: int, kind: int, t: float, lift: float, sc: float, blink: bool) -> void:
	var owner := HeroLogic.owner_of(id)
	var live := logic.alive(id)
	var at := Vector2(0, _cell * 0.1)
	# 천사가 영웅 칸에 잠깐 함께 서 있으면 살짝 위로 비켜 그림
	if live and _shares_cell(id):
		at += Vector2(_cell * 0.22, -_cell * 0.24)
		sc *= 0.78
	var body_col := UIKit.player_color(owner)
	if live and logic.dark[id] != 0:
		# 흑기사: 보라 불꽃 기운 + 어두운 몸
		var ac := at + Vector2(0, -_cell * 0.02)
		ci.draw_circle(ac, _cell * (0.44 + 0.03 * sin(t * 5.0)), Color(0.25, 0.08, 0.4, 0.45), true, -1.0, true)
		for j in 8:
			var fa := TAU * j / 8.0 + t * 1.4
			var fl := _cell * (0.12 + 0.05 * sin(t * 7.0 + j * 1.7))
			var fb := ac + Vector2(cos(fa), sin(fa)) * _cell * 0.4
			ci.draw_line(fb, fb + Vector2(0, -fl), Color("#B45CFF"), maxf(2.0, _cell * 0.06), true)
		body_col = body_col.lerp(Color("#170F26"), 0.5)
	var shield: bool = live and logic.barrier[id] != 0
	HeroArt.draw_hero(ci, at, _cell * 0.33 * sc, kind, body_col, t, float(id) * 0.9, lift, false,
		live and logic.disabled_by[id] >= 0, shield, live and logic.horse[id] != 0, int(blink), false)
	if live and not shield:
		_paint_badges(ci, id, t)


## 영웅에 붙는 표식: 저주 · 스턴 · 봉인 · 닌자 · 행동함
func _paint_badges(ci: CanvasItem, id: int, t: float) -> void:
	if logic.cursed_by[id] >= 0:
		# 저주: 머리 위에서 일렁이는 보라색 해골
		ci.draw_arc(Vector2(0, _cell * 0.02), _cell * 0.45, 0, TAU, 32, Color(PURPLE_DARK, 0.55 + 0.25 * sin(t * 4.0)), maxf(2.0, _cell * 0.05), true)
		_skull(ci, Vector2(_cell * 0.3, -_cell * (0.3 + 0.03 * sin(t * 4.0))), _cell * 0.14)
	if logic.stunned[id] != 0:
		# 스턴: 머리 위 소용돌이 (도는 노란 별 셋은 따로 얹음)
		ci.draw_arc(Vector2(0, -_cell * 0.36), _cell * 0.17, 0, TAU, 24, Color(GOLD, 0.6), maxf(1.5, _cell * 0.03), true)
	if logic.sealed[id] != 0:
		# 봉인: 아래 옆에 자물쇠
		_lock(ci, Vector2(_cell * 0.32, _cell * 0.28), _cell * 0.13)
	if _shown_kind(id) != HeroLogic.kind_of(id):
		# 다른 영웅 모습의 닌자: 작은 표창
		var bp := Vector2(-_cell * 0.3, -_cell * 0.28)
		ci.draw_circle(bp, _cell * 0.15, Color(0.17, 0.15, 0.22, 0.85), true, -1.0, true)
		HeroArt._shuriken(ci, bp, _cell * 0.12, t)
	if _checked(id):
		_draw_check(ci, Vector2(_cell * 0.3, -_cell * 0.3))


# ── 유령 ───────────────────────────────────────────────
## 모양 전체에 반투명한 팀 색을 입혀 그려 둠
func _bake_ghosts() -> void:
	for id: int in _ghost_sprite.keys():
		if not _ghost_draw.has(id):
			_ghost_sprite.erase(id)
			_sprites.drop(S_GHOST + id * 8, S_GHOST + id * 8 + 7)
	for id: int in _ghost_draw:
		var kind := HeroLogic.kind_of(id)
		var r := _cell * float(_ghost_spot(id)[1])
		var omega := HeroArt.sway(kind)
		var lv := 2
		var t := 0.0
		if kind == HeroLogic.Kind.ROBOT:
			lv = int(HeroArt.robot_on(_time))
			t = 0.0 if lv == 1 else 0.7
		elif omega > 0.0:
			lv = _wave(omega, _time)
			t = _wave_time(omega, lv)
		var blink := PieceArt.blinking(_time, kind * 0.7)
		var n := S_GHOST + id * 8 + (V_MOMENT if blink else lv)
		var key := [r, lv]
		if _sprites.changed(n, key):
			_sprites.bake(n, key, _paint_ghost.bind(kind, r, t, blink), ghost_tint(id))
		_ghost_sprite[id] = n


func _paint_ghost(ci: CanvasItem, kind: int, r: float, t: float, blink: bool) -> void:
	HeroArt.draw_hero(ci, Vector2.ZERO, r, kind, Color.WHITE, t, float(kind) * 0.7, 0.0, false, false, false, false, int(blink))


# ── 벽 ─────────────────────────────────────────────────
func _wall_ends(a: Vector2, b: Vector2) -> Array:
	var sh := (b - a).normalized() * _cell * 0.08
	return [a + sh, b - sh]


func _bake_wall(n: int, p: int) -> void:
	if _sprites.changed(n, [1]):
		_sprites.bake(n, [1], _paint_wall.bind(p, (n - S_WALL) % 2 == 1), Color.WHITE, BOX_SMALL)


func _paint_wall(ci: CanvasItem, p: int, vertical: bool) -> void:
	var half := (Vector2(0, 0.5) if vertical else Vector2(0.5, 0)) * _cell
	var e := _wall_ends(-half, half)
	HeroArt.draw_wall(ci, e[0], e[1], maxf(4.0, _cell * 0.16), 1.0, Color(UIKit.player_color(p), 1.0))


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	if logic == null or size.x < 10.0:
		return
	_layout()
	var rad := _cell * 0.35
	UIKit.draw_rbox(self, Rect2(_frame.position + Vector2(0, 10), _frame.size), Color(0.25, 0.15, 0.05, 0.16), rad)
	UIKit.draw_rbox(self, Rect2(_frame.position + Vector2(0, 5), _frame.size), FRAME_DARK, rad)
	UIKit.draw_rbox(self, _frame, FRAME, rad)
	# 잔디 칸
	for y in HeroLogic.H:
		for x in HeroLogic.W:
			draw_rect(cell_rect(Vector2i(x, y)), GRASS_A if (x + y) % 2 == 0 else GRASS_B)
	for p in 2:
		draw_rect(cell_rect(HeroLogic.CASTLE[p]), Color("#CFC6B4"))


func _draw_low() -> void:
	if logic == null or _cell <= 0.0:
		return
	if home_glow >= 0:
		for c in logic.back_row_cells(home_glow):
			_low.draw_rect(cell_rect(c).grow(-2.0), Color(1, 1, 1, 0.12 + 0.08 * _pulse()))
	if castle_glow >= 0:
		_low.draw_rect(cell_rect(HeroLogic.CASTLE[castle_glow]).grow(-2.0), Color(SUMMON_C, 0.3 + 0.25 * _pulse()))


func _draw_list(layer: Control) -> void:
	var key: Variant = _keys.get(layer)
	if key == null:
		return
	for e: Array in (key as Array)[0]:
		if e.size() > 2:
			_sprites.draw(layer, e[0], e[1], e[2], e[3])
		else:
			_sprites.draw(layer, e[0], e[1])


func _draw_objs() -> void:
	_draw_list(_objs)


func _draw_heroes() -> void:
	_draw_list(_heroes)


func _draw_walls() -> void:
	_draw_list(_walls)


func _draw_ghosts() -> void:
	if logic == null or _cell <= 0.0:
		return
	for id: int in _ghost_draw:
		var sc := 1.0
		if _ghost_born.has(id):
			sc = clampf((_time - float(_ghost_born[id])) / 0.45, 0.0, 1.0)
		if sc > 0.0:
			var bob := sin(_time * 2.2 + id) * _cell * 0.05
			_sprites.draw(_ghosts, _ghost_sprite.get(id, -1), _center(_ghost_draw[id]) + (_ghost_spot(id)[0] as Vector2) * _cell + Vector2(0, bob), sc)


func _draw_under() -> void:
	if logic == null or _cell <= 0.0:
		return
	var pulse := _pulse()
	if castle_glow >= 0:
		_under.draw_arc(cell_rect(HeroLogic.CASTLE[castle_glow]).get_center(), _cell * 0.55, 0, TAU, 32, SUMMON_C, 3.0 + 2.0 * pulse, true)
	# 유령: 밝은 빛 무리를 깔아 반투명한 팀 색이 판 색과 섞여 탁해지지 않게 (유령 그림은 맨 위층)
	for id in _ghost_draw:
		var spot := _ghost_spot(id)
		_under.draw_circle(_center(_ghost_draw[id]) + (spot[0] as Vector2) * _cell, _cell * float(spot[1]) * 1.12, Color(1, 1, 1, 0.26), true, -1.0, true)
		if logic.cursed_by[id] >= 0 and logic.has_ghost(id):
			# 저주 걸린 유령: 보라색 고리와 해골
			var gcp := _center(_ghost_draw[id])
			_under.draw_arc(gcp + Vector2(0, _cell * 0.04), _cell * 0.43, 0, TAU, 32, Color(PURPLE_DARK, 0.5 + 0.25 * sin(_time * 4.0)), maxf(2.0, _cell * 0.05), true)
			_skull(_under, gcp + Vector2(_cell * 0.32, -_cell * (0.32 + 0.03 * sin(_time * 4.0 + id))), _cell * 0.13)
	# 고를 수 있는 영웅 · 선택 · 표시 (말 아래)
	for id in pickable:
		var pp: Variant = _any_pos(id)
		if pp != null and id != selected:
			_under.draw_circle(_center(pp) + Vector2(0, _cell * 0.24), _cell * (0.36 + 0.03 * pulse), Color(1, 1, 1, 0.3 + 0.22 * pulse), true, -1.0, true)
	var sp: Variant = _any_pos(selected) if selected >= 0 else null
	if sp != null:
		var sc := _center(sp) + Vector2(0, _cell * 0.24)
		_under.draw_circle(sc, _cell * 0.42, Color(1, 0.85, 0.3, 0.55), true, -1.0, true)
		_under.draw_arc(sc, _cell * 0.42, 0, TAU, 32, SKILL_C, 3.0, true)
	var ip: Variant = _any_pos(info_id) if info_id >= 0 and info_id != selected else null
	if ip != null:
		_under.draw_arc(_center(ip) + Vector2(0, _cell * 0.24), _cell * 0.4, 0, TAU, 32, Color(1, 1, 1, 0.9), 2.5, true)
	_draw_marks_under(_under, pulse)


func _draw_over() -> void:
	if logic == null or _cell <= 0.0:
		return
	# 세워지는 중인 벽
	for w in _wall_list:
		var pop := (_time - float(_wall_seen.get(w[1], -10.0))) / 0.3
		if pop < 1.0:
			var e := _wall_ends(_pt(w[2]), _pt(w[3]))
			HeroArt.draw_wall(_over, e[0], e[1], maxf(4.0, _cell * 0.16), pop, Color(UIKit.player_color(w[4]), 1.0))
	_draw_marks_over(_over, _pulse())
	# 사라지는 영웅
	var r := _cell * 0.33
	for i in range(_poofs.size() - 1, -1, -1):
		var f: Dictionary = _poofs[i]
		var age := _time - float(f["t0"])
		var id0: int = f["id"]
		var cp := _center(f["cell"]) + Vector2(0, _cell * 0.1)
		if age < 0.0:
			HeroArt.draw_hero(_over, cp, r, HeroLogic.kind_of(id0), UIKit.player_color(HeroLogic.owner_of(id0)), _time, 0.0)
			continue
		var k := minf(age / 0.5, 1.0)
		var col := Color(UIKit.player_color(HeroLogic.owner_of(id0)), 1.0 - k)
		HeroArt.draw_hero(_over, cp - Vector2(0, k * _cell * 0.3), r * (1.0 - k * 0.7), HeroLogic.kind_of(id0), col, _time, 0.0)
		for j in 8:
			var a := TAU * j / 8.0 + 0.3
			_over.draw_circle(cp + Vector2(cos(a), sin(a)) * _cell * (0.2 + 0.4 * k), _cell * 0.06 * (1.0 - k), Color(1, 1, 1, 1.0 - k), true, -1.0, true)
	# 효과
	for i in range(_fx.size() - 1, -1, -1):
		var e: Dictionary = _fx[i]
		var k := (_time - float(e["t0"])) / float(e["d"])
		if k >= 0.0 and k < 1.0:
			HeroFx.draw(_over, str(e["k"]), _center(e["a"]), _center(e["b"]), _cell * 1.2, k, e["c"])


func _draw_check(ci: CanvasItem, p: Vector2) -> void:
	var s := _cell * 0.13
	ci.draw_circle(p, s * 1.2, Color(0.24, 0.2, 0.31, 0.75), true, -1.0, true)
	ci.draw_polyline(PackedVector2Array([p + Vector2(-s * 0.55, 0), p + Vector2(-s * 0.1, s * 0.45), p + Vector2(s * 0.6, -s * 0.45)]),
		Color.WHITE, maxf(1.5, s * 0.35), true)


## 말 아래에 그리는 표시 (이동 점 · 소환 칸)
func _draw_marks_under(ci: CanvasItem, pulse: float) -> void:
	for c in marks:
		var p := _center(Vector2(c))
		match str(marks[c]):
			"move":
				ci.draw_circle(p, _cell * (0.13 + 0.03 * pulse), Color(MOVE_C, 0.88), true, -1.0, true)
			"stay":
				ci.draw_arc(p + Vector2(0, _cell * 0.24), _cell * 0.44, 0, TAU, 32, MOVE_C, 3.0 + 2.0 * pulse, true)
			"advance":
				# 전사: 한 칸 더 전진
				ci.draw_rect(cell_rect(c).grow(-3.0), Color(SKILL_C, 0.16 + 0.12 * pulse))
				ci.draw_circle(p, _cell * (0.15 + 0.03 * pulse), Color(SKILL_C, 0.95), true, -1.0, true)
			"copy":
				# 닌자: 눌러서 이동과 능력을 따라 할 앞 줄 영웅
				ci.draw_rect(cell_rect(c).grow(-3.0), Color(GOLD, 0.16 + 0.12 * pulse))
				ci.draw_circle(p, _cell * (0.16 + 0.03 * pulse), Color(GOLD, 0.95), true, -1.0, true)
				ci.draw_arc(p + Vector2(0, _cell * 0.24), _cell * 0.44, 0, TAU, 32, GOLD, 3.0 + 2.0 * pulse, true)
			"revive":
				ci.draw_circle(p, _cell * 0.5, Color(SUMMON_C, 0.12 + 0.1 * pulse), true, -1.0, true)
				ci.draw_arc(p + Vector2(0, _cell * 0.24), _cell * 0.46, 0, TAU, 32, SUMMON_C, 3.0 + 2.0 * pulse, true)
			"summon", "place", "rise", "return":
				var col := Color.WHITE if str(marks[c]) == "place" else SUMMON_C
				ci.draw_rect(cell_rect(c).grow(-3.0), Color(col, 0.22 + 0.14 * pulse))
				ci.draw_circle(p, _cell * 0.1, Color(col, 0.8), true, -1.0, true)
			"mine":
				ci.draw_rect(cell_rect(c).grow(-3.0), Color(SKILL_C, 0.16 + 0.12 * pulse))
				ci.draw_circle(p, _cell * 0.15, Color(0.22, 0.2, 0.28, 0.45 + 0.2 * pulse), true, -1.0, true)
				ci.draw_arc(p, _cell * 0.3, 0, TAU, 28, SKILL_C, 2.5 + 1.5 * pulse, true)
			"mine_off":
				# 이미 지뢰가 있는 칸: 지뢰끼리 터져서 사라짐
				ci.draw_rect(cell_rect(c).grow(-3.0), Color(ATTACK_C, 0.14 + 0.1 * pulse))
				ci.draw_arc(p, _cell * 0.3, 0, TAU, 28, ATTACK_C, 2.5 + 1.5 * pulse, true)
				var q := _cell * 0.14
				ci.draw_line(p + Vector2(-q, -q), p + Vector2(q, q), ATTACK_C, 2.5 + pulse, true)
				ci.draw_line(p + Vector2(-q, q), p + Vector2(q, -q), ATTACK_C, 2.5 + pulse, true)


## 말 위에 그리는 표시 (공격 · 능력 대상 · 벽 자리)
func _draw_marks_over(ci: CanvasItem, pulse: float) -> void:
	var from: Vector2 = _draw_pos.get(selected, Vector2(-5, -5))
	for c0 in marks:
		var c: Vector2i = HeroLogic.real_cell(c0)
		var p := _center(Vector2(c))
		var kind := str(marks[c0])
		match kind:
			"attack", "castle", "fire", "sweep":
				ci.draw_rect(cell_rect(c).grow(-3.0), Color(ATTACK_C, 0.16 + 0.12 * pulse))
				ci.draw_arc(p, _cell * 0.42, 0, TAU, 32, ATTACK_C, 3.0 + 2.0 * pulse, true)
			"swap", "barrier", "exorcise", "carry", "push", "pull", "land", "warp", "curse", "doom", "seal":
				var col: Color = {"swap": SWAP_C, "barrier": SHIELD_C, "exorcise": DELETE_C, "carry": SUMMON_C,
					"push": SKILL_C, "pull": SUMMON_C, "land": MOVE_C, "warp": SWAP_C, "curse": PURPLE_DARK, "doom": ATTACK_C, "seal": SWAP_C}[kind]
				ci.draw_rect(cell_rect(c).grow(-3.0), Color(col, 0.16 + 0.12 * pulse))
				ci.draw_arc(p, _cell * 0.44, 0, TAU, 32, col, 3.0 + 2.0 * pulse, true)
				if kind == "swap" or kind == "warp":
					_arrows(ci, p + Vector2(0, -_cell * 0.42), _cell * 0.16, col)
				elif kind == "seal":
					_lock(ci, p + Vector2(0, -_cell * 0.42), _cell * 0.13)
				elif kind == "exorcise" or kind == "curse" or kind == "doom":
					_skull(ci, p + Vector2(0, -_cell * 0.42), _cell * 0.13)
			"wall", "unwall", "break", "turret":
				if from.x < -1.0:
					continue
				var a := _center(from)
				var mid := (a + p) / 2.0
				var perp := Vector2((p - a).y, -(p - a).x).normalized() * _cell * 0.42
				var col := Color("#B8754A") if kind == "wall" else ATTACK_C
				ci.draw_line(mid - perp, mid + perp, Color(col, 0.45 + 0.35 * pulse), maxf(4.0, _cell * 0.16), true)
				if kind != "wall":
					var s := _cell * 0.12
					ci.draw_line(mid + Vector2(-s, -s), mid + Vector2(s, s), Color.WHITE, 3.0, true)
					ci.draw_line(mid + Vector2(-s, s), mid + Vector2(s, -s), Color.WHITE, 3.0, true)
				ci.draw_rect(cell_rect(c).grow(-3.0), Color(col, 0.1 + 0.08 * pulse))


func _arrows(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(p, s * 1.3, Color.WHITE, true, -1.0, true)
	ci.draw_arc(p, s * 0.75, PI * 0.15, PI * 1.05, 10, col, maxf(2.0, s * 0.3), true)
	ci.draw_arc(p, s * 0.75, PI * 1.15, PI * 2.05, 10, col, maxf(2.0, s * 0.3), true)


## 자물쇠 (봉인)
func _lock(ci: CanvasItem, p: Vector2, s: float) -> void:
	ci.draw_circle(p, s * 1.35, Color.WHITE, true, -1.0, true)
	ci.draw_arc(p + Vector2(0, -s * 0.15), s * 0.5, PI, TAU, 14, PURPLE_DARK, maxf(1.5, s * 0.26), true)
	ci.draw_rect(Rect2(p + Vector2(-s * 0.72, -s * 0.15), Vector2(s * 1.44, s * 1.0)), PURPLE_DARK)
	ci.draw_circle(p + Vector2(0, s * 0.3), s * 0.2, Color.WHITE, true, -1.0, true)


func _skull(ci: CanvasItem, p: Vector2, s: float) -> void:
	ci.draw_circle(p, s * 1.15, Color.WHITE, true, -1.0, true)
	ci.draw_circle(p + Vector2(-s * 0.38, -s * 0.05), s * 0.28, PURPLE_DARK, true, -1.0, true)
	ci.draw_circle(p + Vector2(s * 0.38, -s * 0.05), s * 0.28, PURPLE_DARK, true, -1.0, true)
	ci.draw_rect(Rect2(p + Vector2(-s * 0.35, s * 0.45), Vector2(s * 0.7, s * 0.3)), PURPLE_DARK)


# ── 입력 ───────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if not input_enabled or logic == null:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var rel := (mb.position - _origin) / _cell
		var c := Vector2i(floori(rel.x), floori(rel.y))
		if flip:
			c = Vector2i(HeroLogic.W - 1 - c.x, HeroLogic.H - 1 - c.y)
		if logic.in_bounds(c):
			cell_tapped.emit(c)
		accept_event()
