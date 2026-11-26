class_name ReversiAI
extends RefCounted
## 리버시 AI
##  - 쉬움: 많이 뒤집는 수를 좋아하는 초보 스타일 (+ 랜덤)
##  - 보통: 3수 앞까지 탐색, 자리 가치 + 둘 수 있는 곳 수(기동력)로 평가
##  - 어려움: 시간 안에서 최대한 깊게 탐색, 빈칸 12개 이하면 끝까지 정확히 계산
##  - 빠른 계산을 위해 테두리를 둘러친 10×10 1차원 판을 따로 씀
##  - 스레드에서 돌릴 수 있도록 자기만의 판 복사본만 건드림

enum Level { EASY, NORMAL, HARD }

const OFFS := [-11, -10, -9, -1, 1, 9, 10, 11]
const BORDER := 3
## 칸별 가치: 귀(모서리)는 최고, 귀 옆(X·C 칸)은 위험
const W8 := [
	100, -20, 10, 5, 5, 10, -20, 100,
	-20, -50, -2, -2, -2, -2, -50, -20,
	10, -2, 1, 1, 1, 1, -2, 10,
	5, -2, 1, 0, 0, 1, -2, 5,
	5, -2, 1, 0, 0, 1, -2, 5,
	10, -2, 1, 1, 1, 1, -2, 10,
	-20, -50, -2, -2, -2, -2, -50, -20,
	100, -20, 10, 5, 5, 10, -20, 100,
]

var level: int = Level.NORMAL
var rng := RandomNumberGenerator.new()

var b := PackedByteArray()
var w := PackedFloat32Array()
var valid := PackedInt32Array()
var corners: Array = []
var _deadline: int = 0
var _aborted: bool = false
var _nodes: int = 0


func _init(p_level: int = Level.NORMAL) -> void:
	level = p_level
	rng.randomize()
	w.resize(100)
	w.fill(0.0)
	for y in 8:
		for x in 8:
			var i := _idx(x, y)
			valid.append(i)
			w[i] = W8[y * 8 + x]
	corners = [
		[_idx(0, 0), [_idx(1, 0), _idx(0, 1), _idx(1, 1)]],
		[_idx(7, 0), [_idx(6, 0), _idx(7, 1), _idx(6, 1)]],
		[_idx(0, 7), [_idx(0, 6), _idx(1, 7), _idx(1, 6)]],
		[_idx(7, 7), [_idx(6, 7), _idx(7, 6), _idx(6, 6)]],
	]


static func _idx(x: int, y: int) -> int:
	return (y + 1) * 10 + x + 1


static func _xy(i: int) -> Vector2i:
	return Vector2i(i % 10 - 1, i / 10 - 1)


func _load(L: ReversiLogic) -> void:
	b.resize(100)
	b.fill(BORDER)
	for y in 8:
		for x in 8:
			b[_idx(x, y)] = L.cells[y * 8 + x]


# ── 판 조작 (p: 1 = 흑, 2 = 백) ─────────────────────────
func _moves(p: int) -> Array:
	var o := 3 - p
	var out: Array = []
	for i in valid:
		if b[i] != 0:
			continue
		for d in OFFS:
			var j: int = i + d
			if b[j] != o:
				continue
			j += d
			while b[j] == o:
				j += d
			if b[j] == p:
				out.append(i)
				break
	return out


func _count_moves(p: int) -> int:
	var o := 3 - p
	var n := 0
	for i in valid:
		if b[i] != 0:
			continue
		for d in OFFS:
			var j: int = i + d
			if b[j] != o:
				continue
			j += d
			while b[j] == o:
				j += d
			if b[j] == p:
				n += 1
				break
	return n


func _do(i: int, p: int) -> PackedInt32Array:
	var o := 3 - p
	var flipped := PackedInt32Array()
	for d in OFFS:
		var j: int = i + d
		var n := 0
		while b[j] == o:
			j += d
			n += 1
		if n > 0 and b[j] == p:
			var k: int = i + d
			while k != j:
				b[k] = p
				flipped.append(k)
				k += d
	b[i] = p
	return flipped


func _undo(i: int, p: int, flipped: PackedInt32Array) -> void:
	b[i] = 0
	var o := 3 - p
	for k in flipped:
		b[k] = o


func _empties() -> int:
	var n := 0
	for i in valid:
		if b[i] == 0:
			n += 1
	return n


# ── 평가 ───────────────────────────────────────────────
func _eval(p: int) -> float:
	var o := 3 - p
	var s := 0.0
	for i in valid:
		var v := b[i]
		if v == p:
			s += w[i]
		elif v == o:
			s -= w[i]
	# 귀가 이미 찼으면 그 옆 칸은 더 이상 위험하지 않음
	for cr in corners:
		if b[cr[0]] != 0:
			for a in cr[1]:
				if b[a] == p:
					s -= w[a]
				elif b[a] == o:
					s += w[a]
	s += 6.0 * float(_count_moves(p) - _count_moves(o))
	return s


## 게임이 끝났을 때: 이기면 아주 큰 점수 + 돌 차이
func _final(p: int) -> float:
	var o := 3 - p
	var diff := 0
	for i in valid:
		if b[i] == p:
			diff += 1
		elif b[i] == o:
			diff -= 1
	if diff > 0:
		return 100000.0 + diff * 100.0
	elif diff < 0:
		return -100000.0 + diff * 100.0
	return 0.0


func _ordered(moves: Array) -> Array:
	var out := moves.duplicate()
	out.sort_custom(func(a: int, c: int) -> bool: return w[a] > w[c])
	return out


func _negamax(p: int, depth: int, alpha: float, beta: float, passed: bool) -> float:
	_nodes += 1
	if (_nodes & 127) == 0 and Time.get_ticks_msec() > _deadline:
		_aborted = true
	if _aborted:
		return 0.0
	if depth <= 0:
		return _eval(p)
	var moves := _moves(p)
	if moves.is_empty():
		if passed:
			return _final(p)
		return -_negamax(3 - p, depth, -beta, -alpha, true)
	var best := -INF
	for m in _ordered(moves):
		var f := _do(m, p)
		var v := -_negamax(3 - p, depth - 1, -beta, -alpha, false)
		_undo(m, p, f)
		if v > best:
			best = v
		if v > alpha:
			alpha = v
		if alpha >= beta:
			break
	return best


# ── 결정 ───────────────────────────────────────────────
func choose(L: ReversiLogic, me: int) -> Vector2i:
	_load(L)
	var p := me + 1
	var moves := _moves(p)
	if moves.is_empty():
		return Vector2i(-1, -1)
	if moves.size() == 1:
		return _xy(moves[0])
	match level:
		Level.EASY:
			return _xy(_easy(moves, p))
		Level.NORMAL:
			return _xy(_search(p, moves, 3, 300))
		_:
			if _empties() <= 12:
				var exact := _solve_end(p, moves, 2500)
				if exact >= 0:
					return _xy(exact)
			return _xy(_search(p, moves, 8, 900))


func _easy(moves: Array, p: int) -> int:
	if rng.randf() < 0.3:
		return moves[rng.randi() % moves.size()]
	var best: int = moves[0]
	var best_v := -INF
	for m in moves:
		var f := _do(m, p)
		var n := f.size()
		_undo(m, p, f)
		var v := n + w[m] * 0.03 + rng.randf_range(0.0, 3.0)
		if v > best_v:
			best_v = v
			best = m
	return best


## 반복 심화: 1수, 2수, … 시간 안에 끝낸 가장 깊은 탐색 결과 사용
func _search(p: int, moves: Array, max_depth: int, ms: int) -> int:
	_deadline = Time.get_ticks_msec() + ms
	_nodes = 0
	var order := _ordered(moves)
	var best_move: int = order[0]
	for depth in range(1, max_depth + 1):
		_aborted = false
		var alpha := -INF
		var cur_best: int = order[0]
		var cur_val := -INF
		var vals := {}
		for m in order:
			var f := _do(m, p)
			var v := -_negamax(3 - p, depth - 1, -INF, -alpha, false)
			_undo(m, p, f)
			if _aborted:
				break
			if level == Level.NORMAL:
				v += rng.randf_range(0.0, 2.0)  # 같은 판에서도 조금씩 다르게
			vals[m] = v
			if v > cur_val:
				cur_val = v
				cur_best = m
			if v > alpha:
				alpha = v
		if _aborted:
			break
		best_move = cur_best
		order.sort_custom(func(a: int, c: int) -> bool: return float(vals.get(a, -INF)) > float(vals.get(c, -INF)))
		if Time.get_ticks_msec() > _deadline:
			break
	return best_move


## 끝내기 완전 계산. 시간 안에 못 끝내면 -1
func _solve_end(p: int, moves: Array, ms: int) -> int:
	_deadline = Time.get_ticks_msec() + ms
	_nodes = 0
	_aborted = false
	var best := -1
	var best_v := -INF
	var alpha := -INF
	for m in _ordered(moves):
		var f := _do(m, p)
		var v := -_negamax(3 - p, 64, -INF, -alpha, false)
		_undo(m, p, f)
		if _aborted:
			return -1
		if v > best_v:
			best_v = v
			best = m
		if v > alpha:
			alpha = v
	return best
