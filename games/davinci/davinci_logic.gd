class_name DavinciLogic
extends RefCounted
## 비밀 숫자 – 규칙 엔진 (다빈치 코드와 같은 규칙, 조커 없음)
## 타일 키 = 숫자 * 2 + 색 (0 = 검정, 1 = 하양)
##  → 키 순서가 곧 줄 세우는 순서 (같은 숫자면 검정이 왼쪽)

enum Phase { DRAW, GUESS, DECIDE, REVEAL_OWN, OVER }

const MAX_NUM := 11
const TILE_COUNT := 24

var n: int = 2
var hands: Array = []        # p -> Array (정렬된 키)
var revealed: Array = []     # p -> Array (bool, hands 와 같은 순서)
var pool: Array = []         # 아직 안 뽑은 키
var current: int = 0
var phase: int = Phase.DRAW
var drawn: int = -1          # 이번 차례에 뽑은 타일 (아직 줄에 안 넣음)
var out: Array = []          # p -> 탈락 여부
var out_order: Array = []    # 탈락한 순서
var wrong: Dictionary = {}   # 키 -> 틀린 추측 숫자 목록 (모두가 들은 정보)
var winner: int = -1
var last: Dictionary = {}    # 마지막 사건 (화면 연출용)
var hits: Array = []         # p -> 맞힌 횟수
var misses: Array = []       # p -> 틀린 횟수
var guesses_this_turn: int = 0


static func num_of(k: int) -> int:
	return k >> 1


static func color_of(k: int) -> int:
	return k & 1


static func key_of(num: int, color: int) -> int:
	return num * 2 + color


func setup(players: int, rng: RandomNumberGenerator, first: int = 0) -> void:
	n = players
	pool = []
	for k in TILE_COUNT:
		pool.append(k)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: int = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	hands = []
	revealed = []
	out = []
	hits = []
	misses = []
	var per := 4 if n <= 3 else 3
	for p in n:
		var h: Array = []
		for i in per:
			h.append(pool.pop_back())
		h.sort()
		hands.append(h)
		var rv: Array = []
		rv.resize(per)
		rv.fill(false)
		revealed.append(rv)
		out.append(false)
		hits.append(0)
		misses.append(0)
	out_order = []
	wrong = {}
	winner = -1
	last = {}
	current = first % n
	_begin_turn()


func clone() -> DavinciLogic:
	var c := DavinciLogic.new()
	c.n = n
	c.hands = hands.duplicate(true)
	c.revealed = revealed.duplicate(true)
	c.pool = pool.duplicate()
	c.current = current
	c.phase = phase
	c.drawn = drawn
	c.out = out.duplicate()
	c.out_order = out_order.duplicate()
	c.wrong = wrong.duplicate(true)
	c.winner = winner
	c.hits = hits.duplicate()
	c.misses = misses.duplicate()
	c.guesses_this_turn = guesses_this_turn
	return c


# ── 상태 조회 ──────────────────────────────────────────
func pool_count(color: int) -> int:
	var c := 0
	for k in pool:
		if color_of(k) == color:
			c += 1
	return c


func hidden_count(p: int) -> int:
	var c := 0
	for r in revealed[p]:
		if not r:
			c += 1
	return c


func alive_count() -> int:
	var c := 0
	for o in out:
		if not o:
			c += 1
	return c


func is_over() -> bool:
	return phase == Phase.OVER


## p 의 i 번째 타일을 지금 차례인 사람이 맞히려고 고를 수 있나
func can_target(p: int, i: int) -> bool:
	if phase != Phase.GUESS and phase != Phase.DECIDE:
		return false
	if p == current or p < 0 or p >= n or out[p]:
		return false
	if i < 0 or i >= hands[p].size():
		return false
	return not revealed[p][i]


## viewer 가 보기에 확실히 아닌 숫자들 (보이는 같은 색 타일 + 이 타일에 대해 틀렸던 추측)
func excluded_for(viewer: int, p: int, i: int) -> Array:
	var k: int = hands[p][i]
	var col := color_of(k)
	var outl: Array = []
	for q in n:
		for j in hands[q].size():
			var kk: int = hands[q][j]
			if color_of(kk) != col:
				continue
			if q == viewer or revealed[q][j]:
				outl.append(num_of(kk))
	if current == viewer and drawn >= 0 and color_of(drawn) == col:
		outl.append(num_of(drawn))
	for num in wrong.get(k, []):
		if not outl.has(num):
			outl.append(num)
	return outl


func index_of_key(p: int, k: int) -> int:
	return (hands[p] as Array).find(k)


# ── 진행 ───────────────────────────────────────────────
func _begin_turn() -> void:
	drawn = -1
	guesses_this_turn = 0
	phase = Phase.DRAW if not pool.is_empty() else Phase.GUESS


## 원하는 색의 타일을 하나 뽑음 (그 색이 없으면 다른 색). 뽑은 키를 돌려줌
func draw(color: int, rng: RandomNumberGenerator) -> int:
	if phase != Phase.DRAW or pool.is_empty():
		return -1
	var col := color if pool_count(color) > 0 else 1 - color
	var idxs: Array = []
	for i in pool.size():
		if color_of(pool[i]) == col:
			idxs.append(i)
	var pick: int = idxs[rng.randi() % idxs.size()]
	drawn = pool[pick]
	pool.remove_at(pick)
	phase = Phase.GUESS
	last = {"type": "draw", "by": current, "color": col}
	return drawn


## 상대 p 의 i 번째 숨은 타일이 num 이라고 맞혀 봄
func guess(p: int, i: int, num: int) -> bool:
	if not can_target(p, i):
		return false
	var k: int = hands[p][i]
	var by := current
	guesses_this_turn += 1
	if num_of(k) == num:
		hits[by] += 1
		revealed[p][i] = true
		last = {"type": "hit", "by": by, "p": p, "key": k, "num": num}
		if hidden_count(p) == 0:
			_eliminate(p)
			last["out"] = p
		if alive_count() <= 1:
			_finish()
		else:
			phase = Phase.DECIDE
		return true
	misses[by] += 1
	var wl: Array = wrong.get(k, [])
	if not wl.has(num):
		wl.append(num)
	wrong[k] = wl
	last = {"type": "miss", "by": by, "p": p, "key": k, "num": num}
	if drawn >= 0:
		last["placed"] = drawn
		_insert(current, drawn, true)
		drawn = -1
		_end_turn()
	else:
		phase = Phase.REVEAL_OWN
	return false


## 맞힌 뒤 멈추기: 뽑은 타일을 숨긴 채로 내 줄에 넣고 차례 끝
func stop() -> bool:
	if phase != Phase.DECIDE:
		return false
	if drawn >= 0:
		last = {"type": "stop", "by": current, "placed": drawn}
		_insert(current, drawn, false)
		drawn = -1
	else:
		last = {"type": "stop", "by": current}
	_end_turn()
	return true


## 더미가 비어서 뽑지 못한 채로 틀렸을 때: 내 숨은 타일 하나 공개
func reveal_own(i: int) -> bool:
	if phase != Phase.REVEAL_OWN:
		return false
	if i < 0 or i >= hands[current].size() or revealed[current][i]:
		return false
	revealed[current][i] = true
	var me := current
	last = {"type": "reveal_own", "by": me, "key": hands[me][i]}
	if hidden_count(me) == 0:
		_eliminate(me)
		last["out"] = me
	if alive_count() <= 1:
		_finish()
	else:
		_end_turn()
	return true


func _insert(p: int, k: int, rev: bool) -> int:
	var h: Array = hands[p]
	var idx := h.bsearch(k)
	h.insert(idx, k)
	(revealed[p] as Array).insert(idx, rev)
	return idx


func _eliminate(p: int) -> void:
	if not out[p]:
		out[p] = true
		out_order.append(p)


func _end_turn() -> void:
	if phase == Phase.OVER:
		return
	var p := current
	for step in n:
		p = (p + 1) % n
		if not out[p]:
			break
	current = p
	_begin_turn()


func _finish() -> void:
	phase = Phase.OVER
	if drawn >= 0:
		_insert(current, drawn, false)   # 이긴 사람이 뽑아 둔 타일은 숨긴 채로 넣음
		drawn = -1
	for p in n:
		if not out[p]:
			winner = p


## 1등부터 순서 (마지막까지 남은 사람 → 늦게 탈락한 사람 순)
func ranking() -> Array:
	var r: Array = []
	if winner >= 0:
		r.append(winner)
	for k in range(out_order.size() - 1, -1, -1):
		r.append(out_order[k])
	return r
