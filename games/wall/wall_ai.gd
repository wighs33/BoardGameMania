class_name WallAI
extends RefCounted
## 벽 땅따먹기 AI (룰 1 · 룰 2, 2인/3인 공용)
##  - 평가: '보로노이 영역'(각 칸을 더 가까운 말의 주인 땅으로 가정) + 확정 땅 보너스
##    여러 상대가 있으면 가장 앞선 상대와의 차이를 봄
##  - 벽 부수기는 아껴 쓰도록 사용 비용을 둠
##  - 쉬움: 가끔 엉뚱한 수 + 큰 랜덤 / 보통: 1수 앞 최선 / 어려움: 다음 사람의 응수까지 2수 앞
##  - 스레드에서 돌릴 수 있도록 넘겨받은 WallLogic 복사본만 건드림

enum Level { EASY, NORMAL, HARD }

const BREAK_COST := 5.0

var level: int = Level.NORMAL
var rng := RandomNumberGenerator.new()


func _init(p_level: int = Level.NORMAL) -> void:
	level = p_level
	rng.randomize()


static func evaluate(L: WallLogic, me: int, allow_terminal: bool = true) -> float:
	var n := L.size
	var info := L.regions()
	var owners: Array = info["owners"]
	var cells: Array = info["cells"]
	var sure := PackedInt32Array()
	sure.resize(L.num_players)
	sure.fill(0)
	var finished := true
	for r in owners.size():
		var ow: Array = owners[r]
		if ow.size() > 1:
			finished = false
		elif ow.size() == 1:
			var o: int = ow[0]
			sure[o] += int(cells[r])
	var other_sure := 0
	for p in L.num_players:
		if p != me:
			other_sure = maxi(other_sure, sure[p])

	if finished and allow_terminal:
		var diff := sure[me] - other_sure
		if diff > 0:
			return 1000.0 + diff * 10.0
		elif diff < 0:
			return -1000.0 + diff * 10.0
		return 0.0

	# 보로노이 BFS (동시에 퍼지는 다중 시작점)
	var total := n * n
	var dist := PackedInt32Array()
	dist.resize(total)
	dist.fill(1 << 20)
	var own := PackedInt32Array()
	own.resize(total)
	own.fill(-1)
	var queue: Array[Vector2i] = []
	for i in L.piece_pos.size():
		var c := L.piece_pos[i]
		var idx := c.y * n + c.x
		dist[idx] = 0
		own[idx] = L.piece_owner[i]
		queue.append(c)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var idx := c.y * n + c.x
		var o := own[idx]
		var nd := dist[idx] + 1
		for d in 4:
			if L.is_wall(c, d):
				continue
			var nb: Vector2i = c + WallLogic.DIRS[d]
			var ni := nb.y * n + nb.x
			if nd < dist[ni]:
				dist[ni] = nd
				own[ni] = o
				queue.append(nb)
			elif nd == dist[ni] and own[ni] != o:
				own[ni] = -2  # 경합 지역
	var counts := PackedInt32Array()
	counts.resize(L.num_players)
	counts.fill(0)
	for k in total:
		if own[k] >= 0:
			counts[own[k]] += 1
	var best_other := 0
	for p in L.num_players:
		if p != me:
			best_other = maxi(best_other, counts[p])
	return float(counts[me] - best_other) + 0.6 * float(sure[me] - other_sure)


# ── 수 생성 ────────────────────────────────────────────
## [말 번호, 도착 칸, 벽 방향, 부순 벽 슬롯] 목록
func _moves(L: WallLogic, p: int) -> Array:
	var out: Array = []
	var can_break := L.breaks_left[p] > 0
	for i in L.pieces_of(p):
		var dests := L.destinations(i, can_break)
		for cell in dests:
			var broken: Vector2i = dests[cell]["broken"]
			for d in L.open_dirs_after(cell, broken):
				out.append([i, cell, d, broken])
	return out


## 되돌리기용 정보: [원래 위치, 부순 벽의 원래 값]
func _apply(L: WallLogic, mv: Array, p: int) -> Array:
	var i: int = mv[0]
	var cell: Vector2i = mv[1]
	var broken: Vector2i = mv[3]
	var saved := [L.piece_pos[i], 0]
	if broken.x >= 0:
		saved[1] = L.get_slot(broken)
		L.set_slot(broken, 0)
		L.breaks_left[p] -= 1
	L.piece_pos[i] = cell
	L.set_wall(cell, int(mv[2]), p + 1)
	return saved


func _undo(L: WallLogic, mv: Array, p: int, saved: Array) -> void:
	L.set_wall(mv[1], int(mv[2]), 0)
	L.piece_pos[int(mv[0])] = saved[0]
	var broken: Vector2i = mv[3]
	if broken.x >= 0:
		L.set_slot(broken, int(saved[1]))
		L.breaks_left[p] += 1


func _score(L: WallLogic, mv: Array, me: int) -> float:
	var saved := _apply(L, mv, me)
	var v := evaluate(L, me)
	_undo(L, mv, me, saved)
	if (mv[3] as Vector2i).x >= 0:
		v -= BREAK_COST
	return v


# ── 결정 ───────────────────────────────────────────────
func choose_move(L: WallLogic, me: int) -> Array:
	var moves := _moves(L, me)
	if moves.is_empty():
		return []
	if level == Level.EASY and rng.randf() < 0.3:
		var plain: Array = moves.filter(func(m: Array) -> bool: return (m[3] as Vector2i).x < 0)
		var pool: Array = plain if not plain.is_empty() else moves
		return pool[rng.randi() % pool.size()]

	var scored: Array = []
	for mv in moves:
		var v := _score(L, mv, me)
		if level == Level.EASY:
			v += rng.randf_range(-3.0, 3.0)
		else:
			v += rng.randf_range(0.0, 0.25)
		scored.append([v, mv])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	if level != Level.HARD:
		return scored[0][1]

	# 어려움: 상위 후보마다 다음 사람의 최선 응수를 가정 (2수 앞)
	var opp := (me + 1) % L.num_players
	var best_val := -INF
	var best_mv: Array = scored[0][1]
	for k in mini(10, scored.size()):
		var mv: Array = scored[k][1]
		if float(scored[k][0]) >= 900.0:
			return mv
		var saved := _apply(L, mv, me)
		var worst := INF
		var replies := _moves(L, opp)
		if replies.is_empty() or L.is_finished():
			worst = evaluate(L, me)
		else:
			for om in replies:
				var s2 := _apply(L, om, opp)
				var v := evaluate(L, me)
				_undo(L, om, opp, s2)
				if v < worst:
					worst = v
		_undo(L, mv, me, saved)
		if (mv[3] as Vector2i).x >= 0:
			worst -= BREAK_COST
		worst += float(scored[k][0]) * 0.001
		if worst > best_val:
			best_val = worst
			best_mv = mv
	return best_mv


## 말 놓기: [칸, 말 종류]
func choose_placement(L: WallLogic, me: int) -> Array:
	var kinds: Array = L.remaining_kinds(me)
	# 룰 2: 잘 움직이는 사각 말부터
	var kind: int = WallLogic.Kind.SQUARE if kinds.has(WallLogic.Kind.SQUARE) else int(kinds[0])
	var cands: Array = []
	var mid := (L.size - 1) / 2.0
	for y in L.size:
		for x in L.size:
			var c := Vector2i(x, y)
			if L.piece_at(c) != -1:
				continue
			L.piece_pos.append(c)
			L.piece_owner.append(me)
			L.piece_kind.append(kind)
			var v := evaluate(L, me, false)
			L.piece_pos.pop_back()
			L.piece_owner.resize(L.piece_owner.size() - 1)
			L.piece_kind.resize(L.piece_kind.size() - 1)
			v -= 0.15 * (absf(x - mid) + absf(y - mid))  # 가장자리보다 안쪽 선호
			v += rng.randf_range(0.0, 3.0 if level == Level.EASY else 0.3)
			cands.append([v, c])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var pick: Vector2i = cands[0][1]
	if level == Level.EASY:
		pick = cands[rng.randi() % mini(6, cands.size())][1]
	return [pick, kind]
