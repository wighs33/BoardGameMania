class_name OmokLogic
extends RefCounted
## 오목 규칙 엔진 – 화면과 분리된 순수 게임 로직
##
## 규칙
##  - 15×15 교차점에 흑(플레이어 0)부터 번갈아 돌을 놓는다.
##  - 가로·세로·대각선으로 5개 이상 이어지면 승리 (장목도 승리로 인정).
##  - '쌍삼 금지' 옵션: 열린 3을 동시에 두 개 만드는 자리는 흑·백 모두 둘 수 없다.
##    (단, 그 수로 오목이 완성되면 둘 수 있다)
##  - 판이 가득 차면 무승부.

const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]

## 한 방향 모양
enum Shape { NONE, THREE, OPEN_THREE, FOUR, OPEN_FOUR, FIVE }

var size: int = 15
var cells := PackedByteArray()      # 0 = 빈칸, 1 = 흑, 2 = 백
var current: int = 0                # 0 = 흑, 1 = 백
var history: Array[Vector2i] = []
var ban_double_three: bool = true
var over: bool = false
var winner: int = -1
var win_line: Array[Vector2i] = []


func setup(p_size: int = 15, p_ban: bool = true) -> void:
	size = p_size
	ban_double_three = p_ban
	cells.resize(size * size)
	cells.fill(0)
	current = 0
	history.clear()
	over = false
	winner = -1
	win_line.clear()


func clone() -> OmokLogic:
	var c := OmokLogic.new()
	c.size = size
	c.cells = cells.duplicate()
	c.current = current
	c.history = history.duplicate()
	c.ban_double_three = ban_double_three
	c.over = over
	c.winner = winner
	return c


# ── 조회 ───────────────────────────────────────────────
func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size and c.y < size


## 0 = 빈칸, 1 = 흑, 2 = 백, -1 = 판 밖
func stone(c: Vector2i) -> int:
	if not in_bounds(c):
		return -1
	return cells[c.y * size + c.x]


func is_empty(c: Vector2i) -> bool:
	return in_bounds(c) and cells[c.y * size + c.x] == 0


func stones_of(p: int) -> int:
	var n := 0
	for i in history.size():
		if i % 2 == p:
			n += 1
	return n


func last_move() -> Vector2i:
	return history[history.size() - 1] if not history.is_empty() else Vector2i(-1, -1)


# ── 모양 분석 ──────────────────────────────────────────
## c 에 p 의 돌이 있다고 가정한 한 줄 (중심 인덱스 5, 양쪽 5칸)
## 값: 1 = 내 돌, 0 = 빈칸, -1 = 상대 돌/판 밖
func _line(c: Vector2i, d: Vector2i, p: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(11)
	var me := p + 1
	for k in range(-5, 6):
		if k == 0:
			out[5] = 1
			continue
		var q := c + d * k
		if q.x < 0 or q.y < 0 or q.x >= size or q.y >= size:
			out[k + 5] = -1
		else:
			var s := cells[q.y * size + q.x]
			out[k + 5] = 0 if s == 0 else (1 if s == me else -1)
	return out


## i 를 지나는 연속된 내 돌 구간 [a, b]
static func _span(L: PackedInt32Array, i: int) -> Vector2i:
	var a := i
	while a > 0 and L[a - 1] == 1:
		a -= 1
	var b := i
	while b < L.size() - 1 and L[b + 1] == 1:
		b += 1
	return Vector2i(a, b)


## 한 수 더 두면 중심을 포함한 오목이 되는 빈칸 수
static func _five_points(L: PackedInt32Array) -> int:
	var n := 0
	for k in range(1, 10):
		if L[k] != 0:
			continue
		L[k] = 1
		var s := _span(L, k)
		if s.y - s.x >= 4 and s.x <= 5 and s.y >= 5:
			n += 1
		L[k] = 0
	return n


static func _shape(L: PackedInt32Array) -> int:
	var s := _span(L, 5)
	if s.y - s.x >= 4:
		return Shape.FIVE
	var fp := _five_points(L)
	if fp >= 2:
		return Shape.OPEN_FOUR
	if fp == 1:
		return Shape.FOUR
	# 한 수 더 두었을 때 열린 4가 되면 열린 3, 막힌 4가 되면 닫힌 3
	var best: int = Shape.NONE
	for k in range(1, 10):
		if L[k] != 0:
			continue
		L[k] = 1
		var fp2 := _five_points(L)
		L[k] = 0
		if fp2 >= 2:
			return Shape.OPEN_THREE
		if fp2 == 1:
			best = Shape.THREE
	return best


## c 에 p 가 두었을 때의 모양 요약 (실제로 두지는 않음)
## window: 중심을 포함한 5칸 창에 들어있는 내 돌 수 기반 위치 점수
func analyze(c: Vector2i, p: int) -> Dictionary:
	var res := {"five": false, "open_fours": 0, "fours": 0, "open_threes": 0, "threes": 0, "window": 0.0}
	var window := 0.0
	for d in DIRS:
		var L := _line(c, d, p)
		match _shape(L):
			Shape.FIVE:
				res["five"] = true
			Shape.OPEN_FOUR:
				res["open_fours"] += 1
			Shape.FOUR:
				res["fours"] += 1
			Shape.OPEN_THREE:
				res["open_threes"] += 1
			Shape.THREE:
				res["threes"] += 1
		for s in range(1, 6):
			var cnt := 0
			var blocked := false
			for k in range(s, s + 5):
				if L[k] == -1:
					blocked = true
					break
				cnt += L[k]
			if not blocked:
				window += cnt * cnt
	res["window"] = window
	return res


## c 에 p 가 둔 상태에서, 한 수 더 두면 c 를 포함한 오목이 되는 빈칸들
func five_points_at(c: Vector2i, p: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		var L := _line(c, d, p)
		for k in range(1, 10):
			if L[k] != 0:
				continue
			L[k] = 1
			var s := _span(L, k)
			L[k] = 0
			if s.y - s.x >= 4 and s.x <= 5 and s.y >= 5:
				var q: Vector2i = c + d * (k - 5)
				if not out.has(q):
					out.append(q)
	return out


## c 에 두면 4(막힌 4 포함)가 될 가능성이 있는지 빠르게 거르기
func may_make_four(c: Vector2i, p: int) -> bool:
	for d in DIRS:
		var L := _line(c, d, p)
		for s in range(1, 6):
			var cnt := 0
			for k in range(s, s + 5):
				if L[k] == -1:
					cnt = -10
					break
				cnt += L[k]
			if cnt >= 4:
				return true
	return false


## 쌍삼 금지 자리인지
func is_forbidden(c: Vector2i, p: int) -> bool:
	if not ban_double_three or not is_empty(c):
		return false
	var a := analyze(c, p)
	return not a["five"] and int(a["open_threes"]) >= 2


## 지금 p 가 둘 수 없는 자리 목록 (화면 표시용)
func forbidden_cells(p: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not ban_double_three:
		return out
	for c in candidates(2):
		if is_forbidden(c, p):
			out.append(c)
	return out


## 기존 돌 주변 r 칸 이내의 빈칸들
func candidates(r: int = 2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var mark := PackedByteArray()
	mark.resize(size * size)
	mark.fill(0)
	for i in size * size:
		if cells[i] == 0:
			continue
		var x := i % size
		var y := i / size
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= size or ny >= size:
					continue
				var ni := ny * size + nx
				if cells[ni] == 0 and mark[ni] == 0:
					mark[ni] = 1
					out.append(Vector2i(nx, ny))
	return out


# ── 진행 ───────────────────────────────────────────────
func can_place(c: Vector2i) -> bool:
	return not over and is_empty(c) and not is_forbidden(c, current)


func place(c: Vector2i) -> bool:
	if not can_place(c):
		return false
	cells[c.y * size + c.x] = current + 1
	history.append(c)
	var line := five_line(c, current)
	if not line.is_empty():
		over = true
		winner = current
		win_line = line
	elif history.size() >= size * size:
		over = true
		winner = -1
	else:
		current = 1 - current
	return true


func undo() -> bool:
	if history.is_empty():
		return false
	var c: Vector2i = history.pop_back()
	cells[c.y * size + c.x] = 0
	current = history.size() % 2
	over = false
	winner = -1
	win_line.clear()
	return true


## c 를 지나는 5개 이상 연속된 p 의 돌들 (없으면 빈 배열)
func five_line(c: Vector2i, p: int) -> Array[Vector2i]:
	var me := p + 1
	for d in DIRS:
		var cells_in_line: Array[Vector2i] = [c]
		for sgn in [-1, 1]:
			var q: Vector2i = c + d * sgn
			while in_bounds(q) and cells[q.y * size + q.x] == me:
				cells_in_line.append(q)
				q += d * sgn
		if cells_in_line.size() >= 5:
			cells_in_line.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
			return cells_in_line
	return []
