extends SceneTree
## 히어로 체스(3판 '이동 후 능력' 규칙) 로직/AI 헤드리스 테스트
## 실행: Godot_console.exe --headless --path . -s res://tests/test_hero_logic.gd

const K := HeroLogic.Kind
const ST := HeroLogic.Step
const STOP := HeroLogic.STOP
var _fail := 0


func _init() -> void:
	_test_setup_and_place()
	_test_place_list()
	_test_small_board()
	HeroLogic.set_rows(11)   # 아래 규칙 테스트는 자리가 넉넉한 11줄 판에서 (규칙은 줄 수와 상관없음)
	_test_turn_flow()
	_test_must_move()
	_test_knight()
	_test_soldier_mine()
	_test_angel()
	_test_magician()
	_test_flying_and_walls()
	_test_priest_barrier()
	_test_robot()
	_test_warrior()
	_test_ghost()
	_test_ninja()
	_test_reaper()
	_test_architect()
	_test_turret()
	_test_siege()
	_test_summon()
	_test_castle()
	_test_collapse()
	HeroLogic.set_rows(8)
	_match(HeroAI.Level.NORMAL, HeroAI.Level.EASY, 4)
	_match(HeroAI.Level.HARD, HeroAI.Level.NORMAL, 4)
	print("RESULT: ", "ALL PASSED" if _fail == 0 else "%d FAILED" % _fail)
	quit(1 if _fail > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fail += 1
		print("  FAIL: ", msg)


func _id(p: int, k: int) -> int:
	return p * HeroLogic.KINDS + k


## 판을 비우고 원하는 영웅만 놓기. heroes: [[주인, 종류, 칸], ...]
func _board(heroes: Array, cur: int = 0) -> HeroLogic:
	var L := HeroLogic.new()
	L.setup(cur)
	for id in HeroLogic.KINDS * 2:
		if L.alive(id):
			L.grid[L._i(L.pos[id])] = -1
			L.pos[id] = HeroLogic.NONE
	for h in heroes:
		L._place(_id(h[0], h[1]), h[2])
	L.start_play()
	L._update_disabled()
	return L


func _act(L: HeroLogic, id: int, taps: Array) -> Array:
	var ev: Array = []
	_check(L.begin_action(id), "begin %s" % HeroLogic.NAMES[HeroLogic.kind_of(id)])
	for t in taps:
		if t == STOP:
			ev.append_array(L.stop_action())
		else:
			ev.append_array(L.choose(t))
	return ev


func _test_setup_and_place() -> void:
	var L := HeroLogic.new()
	L.setup(0)
	_check(HeroLogic.W == 11 and HeroLogic.H == 8 and HeroLogic.CASTLE[0] == Vector2i(5, 7) and HeroLogic.CASTLE[1] == Vector2i(5, 0), "the board is 11 x 8, castles in the middle of the end rows")
	_check(L.count(0) == 10 and L.count(1) == 10, "10 heroes each")
	for p in 2:
		var seen := {}
		for id in L.heroes_of(p):
			seen[L.pos[id]] = true
			_check(L.pos[id].y == (7 if p == 0 else 0) and L.pos[id] != HeroLogic.CASTLE[p], "every hero starts in its own end row")
		_check(seen.size() == 10 and L.back_row_cells(p).size() == 10, "the end row is full: the castle and 10 heroes")
	_check(L.pos[_id(0, K.KNIGHT)].x == 10 - L.pos[_id(1, K.KNIGHT)].x, "top side is turned around")
	_check(L.phase == HeroLogic.Phase.PLACE, "starts in placement")
	var a: Vector2i = L.pos[_id(0, K.KNIGHT)]
	var b: Vector2i = L.pos[_id(0, K.ANGEL)]
	_check(L.place_swap(0, a, b) and L.pos[_id(0, K.KNIGHT)] == b and L.pos[_id(0, K.ANGEL)] == a, "two heroes change places")
	_check(not L.place_swap(0, b, Vector2i(b.x, 5)), "can't place outside the end row")
	_check(not L.place_swap(0, b, HeroLogic.CASTLE[0]), "can't place on castle")
	_check(not L.place_swap(0, L.pos[_id(1, K.SOLDIER)], L.pos[_id(1, K.ANGEL)]), "can't move enemy heroes")
	var rng := RandomNumberGenerator.new()
	for t in 20:
		L.random_formation(0, rng)
		L.random_formation(1, rng)
		var cells := {}
		for id in HeroLogic.KINDS * 2:
			cells[L.pos[id]] = true
			_check(L.is_back_row(HeroLogic.owner_of(id), L.pos[id]), "random formations stay in the end row")
		_check(cells.size() == 20, "nobody shares a cell")
	var f := {}
	for k in 10:
		f[k] = L.pos[k]
	_check(L.set_formation(0, f), "a received formation is accepted")
	f[0] = Vector2i(0, 5)
	_check(not L.set_formation(0, f), "but not outside the end row")
	L.start_play()
	_check(L.phase == HeroLogic.Phase.ACT and L.current == 0, "play starts")


## 11 × 8 판에서의 끝줄 · 성 주위 · 유령 · 소환
## 직전 배치 기억: 저장한 배치를 그대로 놓음, 어느 자리에서든 자기 쪽에서 본 모양이 같음
func _test_place_list() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for p in 2:
		var L := HeroLogic.new()
		L.setup(0)
		L.random_formation(p, rng)
		L.place_swap(p, L.pos[p * 10 + K.KNIGHT], L.pos[p * 10 + K.REAPER])
		var list := L.place_list(p)
		for q in 2:
			var M := HeroLogic.new()
			M.setup(0)
			_check(M.use_place_list(q, list) and M.place_list(q) == list, "the same placement from either side (%d -> %d)" % [p, q])
			for k in 10:
				var a: Vector2i = L.pos[p * 10 + k]
				var b: Vector2i = M.pos[q * 10 + k]
				_check(b.x == (a.x if p == q else HeroLogic.W - 1 - a.x) and b.y == HeroLogic.LAST_ROW[1 - q] and M.at(b) == q * 10 + k, "seen from its own castle")
	var B := HeroLogic.new()
	B.setup(0)
	var before := B.place_list(0)
	for bad: Variant in [[], [0, 1, 2], [0, 0, 2, 3, 4, 5, 6, 7, 8, 9], [0, 1, 2, 3, 4, 5, 6, 7, 8, 10], ["a", 1, 2, 3, 4, 5, 6, 7, 8, 9], null, "x"]:
		_check(not B.use_place_list(0, bad) and B.place_list(0) == before, "a broken list changes nothing")


func _test_small_board() -> void:
	var L := _board([[0, K.KNIGHT, Vector2i(5, 3)], [0, K.SOLDIER, Vector2i(0, 7)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_check(L.castle_ring_cells(0).size() == 5 and L.castle_ring_cells(0).has(Vector2i(4, 7)) and L.castle_ring_cells(0).has(Vector2i(5, 6)), "5 cells around my castle")
	_check(L.summon_ids().has(_id(0, K.SOLDIER)) and L.summon_ids().has(_id(0, K.KNIGHT)), "any hero of mine on the board can be summoned, end row or not")
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 1), Vector2i(5, 0)])
	_check(L.lives[1] == 2, "the castle is hit at (5, 0)")
	_check(not L.in_bounds(Vector2i(0, 8)) and L.in_bounds(Vector2i(10, 7)), "8 rows")
	# 유령: 천사가 그 칸에 오면 성 주위에 부활
	L = _board([[0, K.KNIGHT, Vector2i(2, 3)], [0, K.ANGEL, Vector2i(2, 5)], [1, K.SOLDIER, Vector2i(9, 0)]])
	L._kill(_id(0, K.KNIGHT), "attack")
	_act(L, _id(0, K.ANGEL), [Vector2i(2, 3), Vector2i(4, 6)])
	_check(L.alive(_id(0, K.KNIGHT)) and L.pos[_id(0, K.KNIGHT)] == Vector2i(4, 6) and not L.has_ghost(_id(0, K.KNIGHT)), "an angel revives a ghost next to my castle")


func _test_turn_flow() -> void:
	var L := _board([[0, K.SOLDIER, Vector2i(2, 8)], [0, K.ANGEL, Vector2i(4, 8)], [1, K.SOLDIER, Vector2i(2, 2)]])
	_act(L, _id(0, K.SOLDIER), [Vector2i(2, 6)])
	_check(L.act_step == ST.MINE and L.act_optional, "after moving the ability step follows, and it is optional")
	L.stop_action()
	_check(L.current == 0 and L.used == 1, "one action used, still my turn")
	_check(not L.can_act(_id(0, K.SOLDIER)), "same hero can't act twice")
	_act(L, _id(0, K.ANGEL), [Vector2i(4, 6)])
	_check(L.current == 1 and L.used == 0, "two actions end the turn (angel has nothing to revive)")
	L.lives[1] = 1
	_act(L, _id(1, K.SOLDIER), [Vector2i(2, 4), STOP])
	_check(L.current == 0, "only hero acted and no summon possible → turn ends by itself")
	_act(L, _id(0, K.ANGEL), [Vector2i(4, 4)])
	_check(L.end_turn() and L.current == 1, "end turn after one action")


func _test_must_move() -> void:
	# 사방이 막혀도 제자리에서 능력을 쓸 수 있음 (모든 영웅 제자리 허용)
	var L := _board([[0, K.SOLDIER, Vector2i(0, 10)], [0, K.PRIEST, Vector2i(1, 10)], [0, K.ARCHITECT, Vector2i(0, 9)],
		[1, K.SOLDIER, Vector2i(5, 3)]])
	_check(L.can_act(_id(0, K.SOLDIER)) and L.options_for(_id(0, K.SOLDIER), K.SOLDIER, ST.MOVE).keys() == [Vector2i(0, 10)], "a boxed-in hero can still stay and act")
	# 이동은 빈칸으로만 (적 칸 X)
	L = _board([[0, K.SOLDIER, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(5, 4)]])
	L.begin_action(_id(0, K.SOLDIER))
	var t := L.step_options()
	_check(not t.has(Vector2i(5, 4)), "moving never enters an enemy cell")
	_check(t.has(Vector2i(3, 5)) and t.has(Vector2i(4, 4)) and t.has(Vector2i(6, 6)) and not t.has(Vector2i(5, 3)),
		"soldier moves up to 2 (turns ok), not through heroes")
	_check(t.has(Vector2i(4, 5)) and t.has(Vector2i(5, 6)) and not t.has(Vector2i(5, 8)), "1 cell is fine too, never 3")
	_check(t.get(Vector2i(5, 5)) == "stay", "soldier can stay")
	L.choose(Vector2i(5, 5))
	_check(L.act_step == ST.MINE and L.pos[_id(0, K.SOLDIER)] == Vector2i(5, 5), "staying still counts as the move")
	# 건축가도 제자리에서 벽을 세울 수 있음
	L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.ARCHITECT), [Vector2i(5, 5)])
	_check(L.act_step == ST.WALL and L.pos[_id(0, K.ARCHITECT)] == Vector2i(5, 5), "architect can stay and build")


func _test_knight() -> void:
	var L := _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(2, 2)]])
	var t := L.options_for(_id(0, K.KNIGHT), K.KNIGHT, ST.MOVE)
	_check(t.has(Vector2i(4, 5)) and t.has(Vector2i(3, 5)) and t.has(Vector2i(5, 7)) and t.has(Vector2i(7, 5))
		and t.get(Vector2i(5, 5)) == "stay", "knight moves up to 2 in one straight line, or stays")
	_check(not t.has(Vector2i(4, 4)) and not t.has(Vector2i(6, 6)), "no turning")
	_check(not t.has(Vector2i(5, 3)) and not t.has(Vector2i(8, 5)), "not through heroes, not 3 cells")
	L._set_wall(Vector2i(5, 5), Vector2i(6, 5), 1)
	_check(not L.options_for(_id(0, K.KNIGHT), K.KNIGHT, ST.MOVE).has(Vector2i(7, 5)), "walls block the knight")

	# 셋 중 하나: 움직인 방향의 다음 칸 공격, 상하좌우 아군 넘기기, 이동 전 자리 바로 뒤(내 성 쪽) 아군과 함께 이동
	var set_up := [[0, K.KNIGHT, Vector2i(5, 5)], [0, K.PRIEST, Vector2i(5, 6)], [0, K.ANGEL, Vector2i(6, 6)],
		[0, K.ROBOT, Vector2i(6, 5)], [0, K.MAGICIAN, Vector2i(4, 5)], [1, K.SOLDIER, Vector2i(5, 2)], [1, K.MAGICIAN, Vector2i(6, 3)]]
	L = _board(set_up)
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 3)])
	t = L.step_options()
	_check(L.act_step == ST.CARRY and L.act_optional and t == {Vector2i(5, 2): "attack", Vector2i(5, 6): "carry"},
		"the enemy ahead, or the ally right behind the start; nobody beside it, no enemy beside the knight")
	L.choose(Vector2i(5, 6))
	_check(L.pos[_id(0, K.PRIEST)] == Vector2i(5, 4) and L.at(Vector2i(5, 6)) == -1, "the ally moves just like the knight")
	_check(L.act_hero < 0 and L.alive(_id(1, K.SOLDIER)), "only one ally, and no attack after that")
	L = _board(set_up)
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 3), Vector2i(5, 2)])
	_check(not L.alive(_id(1, K.SOLDIER)) and L.ghost_pos[_id(1, K.SOLDIER)] == Vector2i(5, 2) and L.act_hero < 0 and L.pos[_id(0, K.PRIEST)] == Vector2i(5, 6),
		"attacking instead: no carry")
	_check(L.pos[_id(0, K.KNIGHT)] == Vector2i(5, 3), "attacking doesn't move the knight")
	# 이동 전 자리 바로 뒤(내 성 쪽 칸)의 아군: 방향 · 칸 수가 기사와 같음 (로봇도). 위쪽 편은 위가 뒤
	for me in 2:
		var back: Vector2i = Vector2i.DOWN if me == 0 else Vector2i.UP
		for dv: Vector2i in HeroLogic.DIRS4:
			for n in [1, 2]:
				if dv == back:
					continue   # 그쪽 아군에 막혀 기사가 못 감
				L = _board([[me, K.KNIGHT, Vector2i(5, 5)], [me, K.ROBOT, Vector2i(5, 5) + back], [me, K.PRIEST, Vector2i(9, 9)], [1 - me, K.SOLDIER, Vector2i(0, 0)]], me)
				_act(L, _id(me, K.KNIGHT), [Vector2i(5, 5) + dv * int(n)])
				_check(L.step_options() == {Vector2i(5, 5) + back: "carry"}, "the ally behind the start (%d %s x%d)" % [me, dv, n])
				L.choose(Vector2i(5, 5) + back)
				_check(L.pos[_id(me, K.ROBOT)] == Vector2i(5, 5) + back + dv * int(n) and L.act_hero < 0, "moves the same way (%d %s x%d)" % [me, dv, n])
	# 옆이나 앞에 있던 아군과 뒤의 적은 함께 못 감, 길에 벽 · 영웅 · 유령이 있을 때
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.PRIEST, Vector2i(4, 5)], [0, K.SOLDIER, Vector2i(6, 5)], [1, K.SOLDIER, Vector2i(5, 6)]])
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 3)])
	_check(L.act_hero < 0, "allies beside the start and an enemy behind it don't come along")
	for what in ["wall1", "wall2", "hero1", "hero2", "ghost1", "ghost2", "turret"]:
		L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.REAPER, Vector2i(5, 6)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)], [1, K.ROBOT, Vector2i(10, 0)]])
		match what:
			"wall1":
				L._set_wall(Vector2i(5, 6), Vector2i(6, 6), 0)
			"wall2":
				L._set_wall(Vector2i(6, 6), Vector2i(7, 6), 1)
			"hero1":
				L._relocate(_id(0, K.PRIEST), Vector2i(6, 6))
			"hero2":
				L._relocate(_id(1, K.ROBOT), Vector2i(7, 6))
			"ghost1", "ghost2":
				L._relocate(_id(0, K.PRIEST), Vector2i(6, 6) if what == "ghost1" else Vector2i(7, 6))
				L._kill(_id(0, K.PRIEST), "attack")
			"turret":
				L.turret[L._i(Vector2i(6, 6))] = 1
		_act(L, _id(0, K.KNIGHT), [Vector2i(7, 5)])
		_check(L.step_options().has(Vector2i(5, 6)) == (what == "ghost1"), "the way of the ally: %s" % what)
	# 이동 후 상하좌우의 아군: 기사를 넘어 반대편 칸으로 (제자리도 됨)
	for d: Vector2i in HeroLogic.DIRS4:
		for from: Vector2i in [Vector2i(5, 5), Vector2i(3, 5), Vector2i(7, 5), Vector2i(5, 3)]:
			if from != Vector2i(5, 5) and (from - Vector2i(5, 5)).sign() == d:
				continue   # 아군에 막혀 기사가 못 옴
			L = _board([[0, K.KNIGHT, from], [0, K.ROBOT, Vector2i(5, 5) + d], [1, K.SOLDIER, Vector2i(0, 0)]])
			_act(L, _id(0, K.KNIGHT), [Vector2i(5, 5)])
			_check(L.step_options() == {Vector2i(5, 5) + d: "carry"}, "an ally next to the new cell")
			L.choose(Vector2i(5, 5) + d)
			_check(L.pos[_id(0, K.ROBOT)] == Vector2i(5, 5) - d and L.act_hero < 0, "goes over the knight to the other side")
	for what in ["ally", "enemy", "ghost", "wall1", "wall2", "diag"]:
		L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.REAPER, Vector2i(5, 4)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)], [1, K.ROBOT, Vector2i(10, 0)]])
		match what:
			"ally":
				L._relocate(_id(0, K.PRIEST), Vector2i(5, 6))
			"enemy":
				L._relocate(_id(1, K.ROBOT), Vector2i(5, 6))
			"ghost":
				L._relocate(_id(0, K.PRIEST), Vector2i(5, 6))
				L._kill(_id(0, K.PRIEST), "attack")
			"wall1":
				L._set_wall(Vector2i(5, 5), Vector2i(5, 4), 1)
			"wall2":
				L._set_wall(Vector2i(5, 5), Vector2i(5, 6), 0)
			"diag":
				L._relocate(_id(0, K.REAPER), Vector2i(4, 4))
		_act(L, _id(0, K.KNIGHT), [Vector2i(5, 5)])
		_check(L.act_hero < 0, "can't be moved over the knight: %s" % what)
	# 옮긴 칸의 적 지뢰에 맞음, 성 칸 · 판 밖으로는 못 옮김
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.PRIEST, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.mines[L._i(Vector2i(5, 6))] = 2
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 5), Vector2i(5, 4)])
	_check(not L.alive(_id(0, K.PRIEST)) and L.mine_at(Vector2i(5, 6)) < 0, "moved onto an enemy mine")
	L = _board([[0, K.KNIGHT, Vector2i(5, 1)], [0, K.PRIEST, Vector2i(5, 2)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 1)])
	_check(not L.step_options().values().has("carry") and L.step_options().get(Vector2i(5, 0)) == "castle", "not onto a castle")
	L = _board([[0, K.KNIGHT, Vector2i(0, 10)], [0, K.PRIEST, Vector2i(0, 9)], [0, K.ROBOT, Vector2i(1, 10)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.KNIGHT), [Vector2i(0, 10)])
	_check(L.act_hero < 0, "nor off the board")
	# 흑기사도 아군을 옮길 수 있음
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.PRIEST, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(6, 6)], [1, K.PRIEST, Vector2i(0, 0)]])
	L.dark[_id(0, K.KNIGHT)] = 1
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 5)])
	_check(L.step_options() == {Vector2i(6, 6): "sweep", Vector2i(5, 4): "carry"}, "a black knight: sweep or an ally")
	# 제자리: 이동 방향이 없으므로 공격도 함께 이동도 없음
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.PRIEST, Vector2i(4, 4)], [1, K.SOLDIER, Vector2i(5, 4)]])
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 5)])
	_check(L.act_hero < 0 and L.pos[_id(0, K.PRIEST)] == Vector2i(4, 4), "staying: no carry, no attack")
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(5, 4)], [1, K.MAGICIAN, Vector2i(5, 6)], [0, K.PRIEST, Vector2i(9, 9)]])
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 5)])
	_check(L.act_hero < 0, "staying with no ally around: nothing to do")
	# 도착 칸에 유령이 있으면 함께 못 감
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.PRIEST, Vector2i(5, 6)], [0, K.SOLDIER, Vector2i(7, 6)], [1, K.SOLDIER, Vector2i(8, 5)]])
	L._kill(_id(0, K.SOLDIER), "attack")
	_act(L, _id(0, K.KNIGHT), [Vector2i(7, 5)])
	_check(L.act_step == ST.STRIKE and L.step_options() == {Vector2i(8, 5): "attack"}, "a ghost on the ally's cell → straight to the attack")
	# 공격은 움직인 방향의 다음 칸
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.ROBOT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(7, 4)], [1, K.MAGICIAN, Vector2i(8, 5)],
		[1, K.PRIEST, Vector2i(4, 5)]])
	_act(L, _id(0, K.KNIGHT), [Vector2i(7, 5)])
	_check(L.step_options() == {Vector2i(8, 5): "attack"},
		"sideways move: attacks the next cell in that direction, not the cell toward the enemy side")
	L.choose(Vector2i(8, 5))
	_check(not L.alive(_id(1, K.MAGICIAN)) and L.alive(_id(1, K.SOLDIER)), "knight hits the enemy in the move direction")
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(5, 8)], [1, K.MAGICIAN, Vector2i(6, 7)], [0, K.PRIEST, Vector2i(9, 9)]])
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 7)])
	_check(L.step_options().get(Vector2i(5, 8)) == "attack" and not L.step_options().has(Vector2i(6, 7)), "moving back attacks behind")

	# 성 공격, 벽 너머는 공격 대신 벽 허물기
	L = _board([[0, K.KNIGHT, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(9, 9)]])
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 1)])
	_check(L.step_options().get(Vector2i(5, 0)) == "castle", "knight with the castle right in front can hit it")
	# 벽은 누구의 것이든 이동을 막고, 공격(성 공격도)은 적군의 벽에만 막힘. 벽은 못 부숨
	for owner in 2:
		L = _board([[0, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(5, 1)], [1, K.PRIEST, Vector2i(9, 9)]])
		L._set_wall(Vector2i(5, 2), Vector2i(5, 1), owner)
		L._set_wall(Vector2i(5, 2), Vector2i(4, 2), owner)
		_act(L, _id(0, K.KNIGHT), [Vector2i(5, 2)])
		t = L.step_options()
		_check(t == ({Vector2i(5, 1): "attack"} if owner == 0 else {}), "attack over my wall, not over an enemy's (wall owner %d)" % owner)
		L.choose(Vector2i(5, 1))
		_check(L.alive(_id(1, K.SOLDIER)) == (owner == 1) and L.wall_count() == 2, "the wall stays")
		_check(not L.options_for(_id(0, K.KNIGHT), K.KNIGHT, ST.MOVE).has(Vector2i(4, 2)), "a wall still blocks moving")
		L = _board([[0, K.KNIGHT, Vector2i(5, 1)], [1, K.PRIEST, Vector2i(9, 9)]])
		L._set_wall(Vector2i(5, 1), Vector2i(5, 0), owner)
		_act(L, _id(0, K.KNIGHT), [Vector2i(5, 1)])
		_check(L.step_options() == ({Vector2i(5, 0): "castle"} if owner == 0 else {}), "the castle can be hit over my wall only")
	_test_horse()


## 말: 공격받으면 말이 대신 죽고 1칸만 움직임, 내 성 주위 5칸에 가면 다시 생김
func _test_horse() -> void:
	var kn := _id(1, K.KNIGHT)
	var L := _board([[0, K.SOLDIER, Vector2i(5, 5)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(0, 0)]])
	_check(L.horse[kn] == 1 and L.horse[_id(0, K.SOLDIER)] == 0, "a knight starts on its horse")
	var ev := _act(L, _id(0, K.SOLDIER), [Vector2i(5, 5), Vector2i(5, 4)])
	var told := false
	for e in ev:
		told = told or e["t"] == "horse_off"
	_check(told and L.alive(kn) and L.horse[kn] == 0 and L.pos[kn] == Vector2i(5, 4) and not L.has_ghost(kn), "the horse dies instead of the knight")
	var h := L.state_hash()
	var C := L.clone()
	_check(C.horse[kn] == 0 and C.state_hash() == h, "kept in copies and the state hash")
	C.horse[kn] = 1
	_check(C.state_hash() != h, "part of the state")
	var t := L.options_for(kn, K.KNIGHT, ST.MOVE)
	_check(t.size() == 4 and t.has(Vector2i(5, 3)) and t.has(Vector2i(4, 4)) and not t.has(Vector2i(5, 2)), "on foot: one cell, or stays")
	L.end_turn()
	# 말 없이도 공격 · 데려오기는 됨
	_act(L, kn, [Vector2i(5, 4)])
	_check(not L.step_options().values().has("attack"), "staying: no attack, as before")
	if L.act_hero >= 0:
		L.stop_action()
	L.end_turn()
	_act(L, _id(0, K.SOLDIER), [Vector2i(5, 5), Vector2i(5, 4)])
	_check(not L.alive(kn) and L.has_ghost(kn), "on foot it falls")
	# 배리어가 먼저, 그다음 말
	L = _board([[0, K.SOLDIER, Vector2i(5, 5)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(0, 0)]])
	L.barrier[kn] = 1
	_act(L, _id(0, K.SOLDIER), [Vector2i(5, 5), Vector2i(5, 4)])
	_check(L.alive(kn) and L.horse[kn] == 1 and L.barrier[kn] == 0, "a barrier goes first")
	# 지뢰는 말이 대신 맞음. 사신의 자동 공격에는 흑기사로 변신 (_test_dark)
	L = _board([[0, K.PRIEST, Vector2i(9, 9)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(0, 0)]], 1)
	L.mines[L._i(Vector2i(5, 5))] = 1
	_act(L, kn, [Vector2i(5, 5)])
	_check(L.alive(kn) and L.horse[kn] == 0 and L.mine_at(Vector2i(5, 5)) < 0, "a mine takes the horse")
	L = _board([[0, K.REAPER, Vector2i(4, 5)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.KNIGHT, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(0, 0)]], 1)
	_act(L, kn, [Vector2i(5, 4)])
	_check(L.alive(kn) and L.horse[kn] == 1 and L.dark[kn] == 1, "a reaper's automatic attack turns a mounted knight dark, the horse stays")
	# 저주 이동은 공격이 아님: 말이 있어도 쓰러짐
	L = _board([[0, K.REAPER, Vector2i(1, 9)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.KNIGHT, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(0, 0)]])
	L.cursed_by[kn] = _id(0, K.REAPER)
	_act(L, _id(0, K.REAPER), [Vector2i(1, 9), Vector2i(5, 3)])
	_check(not L.alive(kn) and not L.has_ghost(kn), "a curse takes the knight, horse or not")
	# 내 성 주위 5칸에 가서 멈추면 말이 생김 (제자리 · 상대 성 주위는 X)
	for how in ["move", "summon", "swap", "stay", "enemy"]:
		L = _board([[0, K.KNIGHT, Vector2i(3, 10)], [0, K.MAGICIAN, Vector2i(6, 9)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.PRIEST, Vector2i(0, 0)]])
		var me := _id(0, K.KNIGHT)
		L.horse[me] = 0
		match how:
			"move":
				_act(L, me, [Vector2i(4, 10)])
			"summon":
				L.do_summon(me, Vector2i(5, 9))
			"swap":
				_act(L, _id(0, K.MAGICIAN), [Vector2i(3, 10)])
			"stay":
				L._relocate(me, Vector2i(4, 9))
				_act(L, me, [Vector2i(4, 9)])
			"enemy":
				L._relocate(me, Vector2i(3, 0))
				_act(L, me, [Vector2i(4, 0)])
		_check((L.horse[me] == 1) == (how != "stay" and how != "enemy"), "horse back by %s" % how)
	# 부활한 기사는 성 주위에 나타나므로 말을 탐
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.KNIGHT, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(_id(0, K.KNIGHT), "attack")
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5), Vector2i(4, 9)])
	_check(L.alive(_id(0, K.KNIGHT)) and L.horse[_id(0, K.KNIGHT)] == 1, "revived on a horse")
	# 닌자가 기사를 따라 하면 그 기사의 말: 말이 있으면 2칸 · 대신 죽고, 없으면 1칸. 닌자로 돌아오면 말도 없음
	for mounted in 2:
		L = _board([[0, K.NINJA, Vector2i(3, 8)], [0, K.KNIGHT, Vector2i(3, 3)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(5, 8)], [1, K.PRIEST, Vector2i(9, 0)]])
		L.horse[_id(0, K.KNIGHT)] = mounted
		_act(L, _id(0, K.NINJA), [Vector2i(3, 3)])
		t = L.step_options()
		_check(t.has(Vector2i(4, 8)) and t.has(Vector2i(3, 6)) == (mounted == 1), "copied knight's move (mounted %d)" % mounted)
		L.choose(Vector2i(4, 8))
		if L.act_hero >= 0:
			L.stop_action()
		L.end_turn()
		_act(L, _id(1, K.SOLDIER), [Vector2i(5, 8), Vector2i(4, 8)])
		_check(L.alive(_id(0, K.NINJA)) == (mounted == 1) and L.horse[_id(0, K.NINJA)] == 0, "the copied horse dies instead (mounted %d)" % mounted)
	_test_dark()


## 사신은 적 유령에게도 저주를 걸고, 저주 걸린 유령에게 가서 없앰
func _test_ghost_curse() -> void:
	var rp := _id(0, K.REAPER)
	var so := _id(1, K.SOLDIER)
	var L := _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(5, 8)], [0, K.ANGEL, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(5, 6)], [1, K.KNIGHT, Vector2i(5, 5)],
		[1, K.ARCHITECT, Vector2i(7, 7)], [1, K.PRIEST, Vector2i(9, 1)], [1, K.MAGICIAN, Vector2i(3, 7)]])
	L.horse[_id(1, K.KNIGHT)] = 0
	L._kill(so, "attack")
	L._kill(_id(1, K.ARCHITECT), "attack")
	L._set_wall(Vector2i(6, 7), Vector2i(7, 7), 1)
	L._set_wall(Vector2i(4, 7), Vector2i(3, 7), 0)
	_act(L, rp, [Vector2i(5, 7)])
	var t := L.step_options()
	_check(t.get(Vector2i(5, 6)) == "curse" and not t.has(Vector2i(5, 5)) and not t.has(Vector2i(7, 7)) and t.get(Vector2i(3, 7)) == "curse",
		"an enemy ghost can be cursed and stops the curse; an enemy wall stops it too")
	var h := L.state_hash()
	L.choose(Vector2i(5, 6))
	_check(L.cursed_by[so] == rp and L.has_ghost(so) and L.state_hash() != h and L.clone().cursed_by[so] == rp, "the ghost is cursed")
	_check(not L.options_for(rp, K.REAPER, ST.REAP).get(Vector2i(5, 6), "") == "curse" and L.options_for(rp, K.REAPER, ST.REAP).get(Vector2i(5, 6)) == "doom" and not L.options_for(rp, K.REAPER, ST.REAP).has(Vector2i(5, 5)),
		"a cursed ghost can be taken, and it still stops the curse")
	# 유령이 움직여도 저주는 따라감, 거리와 상관없이 가서 없앰
	L.end_turn()
	_act(L, so, [Vector2i(6, 6)])
	_check(L.cursed_by[so] == rp, "the curse moves with the ghost")
	L.end_turn()
	_act(L, rp, [Vector2i(5, 7)])
	L.choose(Vector2i(6, 6))
	_check(not L.has_ghost(so) and not L.alive(so) and L.cursed_by[so] < 0 and L.pos[rp] == Vector2i(6, 6) and L.ghost_at(Vector2i(6, 6)) < 0 and L.act_hero < 0, "the reaper goes there, the ghost is gone without a trace")
	# 내 유령은 저주를 안 막음
	L = _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.SOLDIER, Vector2i(5, 6)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.MAGICIAN, Vector2i(5, 5)], [1, K.PRIEST, Vector2i(9, 1)]])
	L._kill(_id(0, K.SOLDIER), "attack")
	t = L.options_for(rp, K.REAPER, ST.REAP)
	_check(t.get(Vector2i(5, 5)) == "curse" and not t.has(Vector2i(5, 6)), "my own ghost doesn't stop it and can't be cursed")
	# 사신이 쓰러지면 유령에게 걸린 저주도, 천사가 부활시키거나 성직자가 없애도 사라짐
	for how in ["reaper", "revive", "cross"]:
		L = _board([[0, K.REAPER, Vector2i(2, 7)], [0, K.PRIEST, Vector2i(5, 5)], [0, K.ROBOT, Vector2i(10, 10)], [1, K.SOLDIER, Vector2i(5, 4)], [1, K.ANGEL, Vector2i(5, 2)], [1, K.PRIEST, Vector2i(9, 1)]], 0 if how == "cross" else 1)
		L._kill(so, "attack")
		L.cursed_by[so] = rp
		match how:
			"reaper":
				L._kill(rp, "attack")
				_check(L.has_ghost(so), "the ghost stays")
			"revive":
				_act(L, _id(1, K.ANGEL), [Vector2i(5, 4), Vector2i(4, 1)])
				_check(L.alive(so), "revived")
			"cross":
				_act(L, _id(0, K.PRIEST), [Vector2i(5, 5), Vector2i(5, 4)])
				_check(not L.has_ghost(so), "removed")
		_check(L.cursed_by[so] < 0, "no curse left (%s)" % how)
	# 사신의 유령에게도 걸 수 있음(살아 있는 사신만 면역), 닌자가 사신을 따라 해도 됨
	L = _board([[0, K.NINJA, Vector2i(3, 9)], [0, K.REAPER, Vector2i(3, 2)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.REAPER, Vector2i(3, 7)], [1, K.PRIEST, Vector2i(9, 1)]])
	L._kill(_id(1, K.REAPER), "attack")
	_act(L, _id(0, K.NINJA), [Vector2i(3, 2), Vector2i(3, 9), Vector2i(3, 7)])
	_check(L.cursed_by[_id(1, K.REAPER)] == _id(0, K.NINJA), "a reaper's ghost can be cursed, by a ninja in reaper form too")
	# 저주를 걸 때 이미 걸려 있던 저주는 풀림 (영웅 · 유령 · 닌자가 건 것 모두). 말 탄 기사에게 걸어도
	for target in ["hero", "ghost", "knight"]:
		L = _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.MAGICIAN, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(7, 7)], [1, K.KNIGHT, Vector2i(3, 7)],
			[1, K.PRIEST, Vector2i(9, 1)], [1, K.ARCHITECT, Vector2i(0, 0)]])
		L._kill(so, "attack")
		L._kill(_id(1, K.ARCHITECT), "attack")
		L.cursed_by[_id(1, K.PRIEST)] = rp
		L.cursed_by[_id(1, K.ARCHITECT)] = _id(0, K.NINJA)
		var tap: Vector2i = {"hero": Vector2i(5, 5), "ghost": Vector2i(7, 7), "knight": Vector2i(3, 7)}[target]
		_act(L, rp, [Vector2i(5, 7), tap])
		var n := 0
		for k in 10:
			n += int(L.cursed_by[10 + k] >= 0)
		_check(L.cursed_by[_id(1, K.PRIEST)] < 0 and L.cursed_by[_id(1, K.ARCHITECT)] < 0 and n == (0 if target == "knight" else 1), "a new curse lifts the old ones (%s)" % target)
		_check(L.dark[_id(1, K.KNIGHT)] == int(target == "knight") and L.has_ghost(_id(1, K.ARCHITECT)), "only the curse changes")
	# 풀린 적에게는 다시 걸 수 있고, 상대 편이 내 편에게 건 저주는 그대로
	L = _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.MAGICIAN, Vector2i(5, 5)], [1, K.REAPER, Vector2i(0, 0)], [1, K.PRIEST, Vector2i(9, 1)]])
	L.cursed_by[_id(0, K.PRIEST)] = _id(1, K.REAPER)
	_act(L, rp, [Vector2i(5, 7), Vector2i(5, 5)])
	_check(L.cursed_by[_id(0, K.PRIEST)] == _id(1, K.REAPER) and L.cursed_by[_id(1, K.MAGICIAN)] == rp, "the enemy's curse on my side stays")
	# 저주로 없앤 칸의 적 지뢰는 사신이 밟음
	L = _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(8, 3)], [1, K.PRIEST, Vector2i(9, 1)]])
	L._kill(so, "attack")
	L.cursed_by[so] = rp
	L.mines[L._i(Vector2i(8, 3))] = 2
	_act(L, rp, [Vector2i(5, 7), Vector2i(8, 3)])
	_check(not L.has_ghost(so) and not L.alive(rp) and L.mine_at(Vector2i(8, 3)) < 0, "an enemy mine there hits the reaper")


## 흑기사: 말을 타고 있을 때 사신의 자동 공격 · 저주가 닿으면 그 편의 차례가 한 번 끝날 때까지 변신, 주위 8칸의 적 모두 공격, 저주 풀림
func _test_dark() -> void:
	var kn := _id(0, K.KNIGHT)
	var around := [[1, K.REAPER, Vector2i(4, 4)], [1, K.SOLDIER, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(6, 6)], [1, K.ROBOT, Vector2i(6, 5)], [1, K.ARCHITECT, Vector2i(7, 5)]]
	# 내 차례에 사신의 대각선으로 가서 변신 → 그 자리에서 8칸 공격 (로봇 · 아군 · 2칸은 X)
	var L := _board([[0, K.KNIGHT, Vector2i(5, 7)], [0, K.MAGICIAN, Vector2i(4, 5)]] + around)
	var ev := _act(L, kn, [Vector2i(5, 5)])
	var told := false
	for e in ev:
		told = told or (e["t"] == "dark" and int(e["id"]) == kn)
	_check(told and L.alive(kn) and L.dark[kn] == 1 and L.horse[kn] == 1, "stopping on a reaper's diagonal turns it dark")
	var C := L.clone()
	_check(C.dark[kn] == 1 and C.state_hash() == L.state_hash(), "kept in copies and the state hash")
	C.dark[kn] = 0
	_check(C.state_hash() != L.state_hash(), "part of the state")
	var t := L.step_options()
	_check(t.get(Vector2i(4, 4)) == "sweep" and t.get(Vector2i(5, 4)) == "sweep" and t.get(Vector2i(6, 6)) == "sweep" and not t.has(Vector2i(6, 5)) and not t.has(Vector2i(7, 5))
		and not t.has(Vector2i(4, 5)), "every enemy in the 8 cells, not the robot, not 2 cells away, not an ally (the robot is in its way over)")
	L.choose(Vector2i(6, 6))
	_check(not L.alive(_id(1, K.REAPER)) and not L.alive(_id(1, K.SOLDIER)) and not L.alive(_id(1, K.PRIEST)) and L.alive(_id(1, K.ROBOT)) and L.alive(_id(1, K.ARCHITECT))
		and L.alive(_id(0, K.MAGICIAN)) and L.act_hero < 0, "all of them at once, allies aren't hurt")
	# 제자리여도 됨, 배리어는 막고 말은 대신 죽음
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(4, 5)], [1, K.PRIEST, Vector2i(0, 0)]])
	L.dark[kn] = 1
	L.barrier[_id(1, K.SOLDIER)] = 1
	_act(L, kn, [Vector2i(5, 5)])
	_check(L.act_step == ST.STRIKE and L.step_options().size() == 2, "staying works for a dark knight")
	L.choose(Vector2i(4, 5))
	_check(L.alive(_id(1, K.SOLDIER)) and L.barrier[_id(1, K.SOLDIER)] == 0 and L.alive(_id(1, K.KNIGHT)) and L.horse[_id(1, K.KNIGHT)] == 0, "barriers and horses take it")
	# 성은 휩쓸기에 안 들어가고, 맞닿아 있으면 따로 칠 수 있음
	L = _board([[0, K.KNIGHT, Vector2i(4, 0)], [1, K.SOLDIER, Vector2i(4, 1)], [1, K.PRIEST, Vector2i(0, 0)]])
	L.dark[kn] = 1
	_act(L, kn, [Vector2i(4, 0)])
	_check(L.step_options().get(Vector2i(4, 1)) == "sweep" and L.step_options().get(Vector2i(5, 0)) == "castle", "sweep, or the castle next to it")
	L.choose(Vector2i(4, 1))
	_check(L.lives[1] == 3 and not L.alive(_id(1, K.SOLDIER)), "a sweep doesn't hit the castle")
	# 상대 차례에 변신하면 내 다음 차례가 끝날 때까지
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.REAPER, Vector2i(4, 3)], [1, K.SOLDIER, Vector2i(0, 0)], [1, K.PRIEST, Vector2i(0, 5)]], 1)
	_act(L, _id(1, K.REAPER), [Vector2i(4, 4)])
	_check(L.alive(kn) and L.dark[kn] == 1, "a reaper walking up turns it dark")
	if L.act_hero >= 0:
		L.stop_action()
	L.end_turn()
	_check(L.current == 0 and L.dark[kn] == 1, "still dark on its own turn")
	_act(L, kn, [Vector2i(5, 5)])
	_check(L.step_options().get(Vector2i(4, 4)) == "sweep", "it can strike the reaper")
	L.stop_action()
	L._relocate(_id(1, K.REAPER), Vector2i(0, 8))
	L.end_turn()
	_check(L.dark[kn] == 0, "over when its turn ends")
	# 내 차례에 변신하고 사신의 대각선을 떠나지 않으면 차례가 바뀔 때 다시 변신
	L = _board([[0, K.KNIGHT, Vector2i(5, 6)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.REAPER, Vector2i(4, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, kn, [Vector2i(5, 5), STOP])
	L.end_turn()
	_check(L.alive(kn) and L.dark[kn] == 1, "still on the diagonal at the turn change → dark again")
	# 말이 없으면 그냥 맞음, 배리어가 있으면 변신도 안 함
	L = _board([[0, K.KNIGHT, Vector2i(5, 6)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.REAPER, Vector2i(4, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.horse[kn] = 0
	_act(L, kn, [Vector2i(5, 5)])
	_check(not L.alive(kn) and L.has_ghost(kn), "on foot it falls")
	L = _board([[0, K.KNIGHT, Vector2i(5, 6)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.REAPER, Vector2i(4, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.barrier[kn] = 1
	_act(L, kn, [Vector2i(5, 5)])
	_check(L.alive(kn) and L.dark[kn] == 0 and L.barrier[kn] == 1, "a barrier keeps the reaper off, no change")
	# 저주: 말 탄 기사는 저주에 안 걸리고 변신, 흑기사에게는 저주를 못 걺, 걸려 있던 저주는 풀림
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(3, 5)], [1, K.REAPER, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(0, 0)]], 1)
	_act(L, _id(1, K.REAPER), [Vector2i(5, 3), Vector2i(5, 5)])
	_check(L.dark[kn] == 1 and L.cursed_by[kn] < 0 and L.act_hero < 0, "a curse turns a mounted knight dark instead")
	_check(not L.options_for(_id(1, K.REAPER), K.REAPER, ST.REAP).has(Vector2i(5, 5)), "a dark knight can't be cursed")
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.REAPER, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(0, 0)]], 1)
	L.horse[kn] = 0
	_act(L, _id(1, K.REAPER), [Vector2i(5, 3), Vector2i(5, 5)])
	_check(L.dark[kn] == 0 and L.cursed_by[kn] == _id(1, K.REAPER), "on foot it is cursed")
	L.horse[kn] = 1
	L.end_turn()
	ev = _act(L, kn, [Vector2i(5, 3) if false else Vector2i(6, 5)])
	if L.act_hero >= 0:
		L.stop_action()
	L._relocate(_id(1, K.REAPER), Vector2i(7, 4))
	L._arrive(_id(1, K.REAPER))
	_check(L.dark[kn] == 1 and L.cursed_by[kn] < 0, "turning dark lifts a curse")
	# 포탑에는 말을 타고 있어도 바로
	L = _board([[0, K.KNIGHT, Vector2i(5, 8)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.dark[kn] = 1
	L.turret[L._i(Vector2i(5, 5))] = 2
	for d in HeroLogic.DIRS4:
		L._set_wall(Vector2i(5, 5), Vector2i(5, 5) + d, 1)
	_act(L, kn, [Vector2i(5, 6)])
	_check(not L.alive(kn) and L.dark[kn] == 0, "a turret fells a dark knight")
	# 닌자: 흑기사를 따라 하면 흑기사, 말 탄 기사 모습이면 변신함. 닌자로 돌아오면 끝
	L = _board([[0, K.NINJA, Vector2i(5, 8)], [0, K.KNIGHT, Vector2i(5, 2)], [1, K.SOLDIER, Vector2i(4, 7)], [1, K.PRIEST, Vector2i(0, 0)]])
	L.dark[kn] = 1
	_act(L, _id(0, K.NINJA), [Vector2i(5, 2), Vector2i(5, 8)])
	_check(L.dark[_id(0, K.NINJA)] == 1 and L.step_options().get(Vector2i(4, 7)) == "sweep", "a ninja copying a dark knight is dark")
	L.choose(Vector2i(4, 7))
	L.end_turn()
	L.pass_turn()
	_check(L.dark[_id(0, K.NINJA)] == 0 and L.ninja_form[0] == -1, "gone with the copied form")
	L = _board([[0, K.NINJA, Vector2i(5, 8)], [0, K.KNIGHT, Vector2i(5, 2)], [1, K.REAPER, Vector2i(4, 6)], [1, K.PRIEST, Vector2i(0, 0)]])
	_act(L, _id(0, K.NINJA), [Vector2i(5, 2), Vector2i(5, 7)])
	_check(L.alive(_id(0, K.NINJA)) and L.dark[_id(0, K.NINJA)] == 1 and L.step_options().get(Vector2i(4, 6)) == "sweep", "a ninja in mounted knight form turns dark too")


func _test_soldier_mine() -> void:
	var L := _board([[0, K.SOLDIER, Vector2i(5, 5)], [0, K.PRIEST, Vector2i(4, 3)], [1, K.SOLDIER, Vector2i(3, 2)],
		[1, K.ANGEL, Vector2i(9, 0)]])
	_act(L, _id(0, K.SOLDIER), [Vector2i(5, 3)])
	var t := L.step_options()
	_check(t.has(Vector2i(5, 2)) and t.has(Vector2i(6, 3)) and t.has(Vector2i(5, 4)) and not t.has(Vector2i(4, 3)),
		"mine goes on an empty cell next to the new position")
	L.choose(Vector2i(5, 2))
	_check(L.mine_at(Vector2i(5, 2)) == 0 and L.mine_at(Vector2i(6, 3)) == 0 and L.mine_at(Vector2i(5, 4)) == 0 and L.mine_at(Vector2i(4, 3)) < 0 and L.mine_at(Vector2i(5, 3)) < 0,
		"mines on every empty cell of the 4, not under a hero")
	_check(L.current == 0, "turn continues")
	L.end_turn()
	# 적이 지나가는 건 괜찮고 멈추면 쾅
	_act(L, _id(1, K.SOLDIER), [Vector2i(5, 2)])
	_check(not L.alive(_id(1, K.SOLDIER)) and L.mine_at(Vector2i(5, 2)) == -1, "enemy stopping on the mine is hurt, mine gone")
	# 둘 중 하나: 상하좌우의 적 한 명 공격, 또는 지뢰
	var set_up := [[0, K.SOLDIER, Vector2i(5, 5)], [1, K.ARCHITECT, Vector2i(6, 3)], [1, K.PRIEST, Vector2i(5, 2)], [1, K.ANGEL, Vector2i(9, 0)]]
	L = _board(set_up)
	_act(L, _id(0, K.SOLDIER), [Vector2i(5, 3)])
	t = L.step_options()
	_check(t.get(Vector2i(5, 2)) == "attack" and t.get(Vector2i(6, 3)) == "attack" and t.get(Vector2i(4, 3)) == "mine" and t.get(Vector2i(5, 4)) == "mine",
		"mine spots plus any enemy in the 4 cells")
	L.choose(Vector2i(4, 3))
	_check(L.act_hero < 0 and L.alive(_id(1, K.PRIEST)) and L.mine_at(Vector2i(4, 3)) == 0 and L.mine_at(Vector2i(5, 4)) == 0 and L.mine_at(Vector2i(6, 3)) < 0,
		"placing mines ends the ability (no attack too)")
	# 이미 적군 지뢰가 있는 칸은 지뢰끼리 터져서 지뢰 없는 칸이 되고(옆의 영웅은 안 다침), 내 지뢰가 있는 칸은 그대로
	for press: Vector2i in [Vector2i(4, 3), Vector2i(6, 3)]:
		L = _board([[0, K.SOLDIER, Vector2i(5, 3)], [0, K.PRIEST, Vector2i(5, 1)], [0, K.KNIGHT, Vector2i(5, 4)], [1, K.ARCHITECT, Vector2i(3, 3)], [1, K.ANGEL, Vector2i(9, 0)]])
		L.mines[L._i(Vector2i(4, 3))] = 2
		L.mines[L._i(Vector2i(5, 2))] = 1
		L.mines[L._i(Vector2i(5, 4))] = 1
		_act(L, _id(0, K.SOLDIER), [Vector2i(5, 3)])
		t = L.step_options()
		_check(t.get(Vector2i(4, 3)) == "mine_off" and not t.has(Vector2i(5, 2)) and t.get(Vector2i(6, 3)) == "mine" and not t.has(Vector2i(5, 4)), "marks")
		L.choose(press)
		_check(L.mine_at(Vector2i(4, 3)) < 0 and L.mine_at(Vector2i(5, 2)) == 0 and L.mine_at(Vector2i(6, 3)) == 0 and L.mine_at(Vector2i(5, 4)) == 0,
			"enemy mines already there blow up, mine stay, the rest are laid, whichever is pressed")
		_check(L.heroes_of(0).size() == 3 and L.heroes_of(1).size() == 2, "no one is hurt")
	# 지뢰끼리 터지기만 할 수도 있음 (네 칸 모두 지뢰)
	L = _board([[0, K.SOLDIER, Vector2i(5, 5)], [1, K.ANGEL, Vector2i(9, 0)]])
	for d in HeroLogic.DIRS4:
		L.mines[L._i(Vector2i(5, 5) + d)] = 2
	_act(L, _id(0, K.SOLDIER), [Vector2i(5, 5), Vector2i(5, 4)])
	for d in HeroLogic.DIRS4:
		_check(L.mine_at(Vector2i(5, 5) + d) < 0, "all four blow up")
	# 네 칸 모두 내 지뢰면 놓을 것이 없음
	L = _board([[0, K.SOLDIER, Vector2i(5, 5)], [1, K.ANGEL, Vector2i(9, 0)]])
	for d in HeroLogic.DIRS4:
		L.mines[L._i(Vector2i(5, 5) + d)] = 1
	_act(L, _id(0, K.SOLDIER), [Vector2i(5, 5)])
	_check(L.act_hero < 0, "nothing to lay next to my own mines")
	# 유령 · 성 · 포탑 칸에는 안 놓음, 닌자가 병사를 따라 해도 같음
	L = _board([[0, K.SOLDIER, Vector2i(5, 2)], [0, K.NINJA, Vector2i(5, 7)], [1, K.ANGEL, Vector2i(9, 0)]])
	_act(L, _id(0, K.NINJA), [Vector2i(5, 2), Vector2i(5, 7), Vector2i(5, 8)])
	var nm := 0
	for i in HeroLogic.W * HeroLogic.H:
		nm += int(L.mines[i] == 1)
	_check(nm == 4 and L.mine_at(Vector2i(5, 8)) == 0, "a ninja in soldier form lays them all")
	L = _board(set_up)
	_act(L, _id(0, K.SOLDIER), [Vector2i(5, 3), Vector2i(5, 2)])
	var any_mine := false
	for i in HeroLogic.W * HeroLogic.H:
		any_mine = any_mine or L.mines[i] != 0
	_check(not L.alive(_id(1, K.PRIEST)) and not any_mine and L.act_hero < 0, "front attack without a mine")
	L = _board(set_up)
	_act(L, _id(0, K.SOLDIER), [Vector2i(5, 3), Vector2i(6, 3)])
	_check(not L.alive(_id(1, K.ARCHITECT)) and L.alive(_id(1, K.PRIEST)), "only one of them")
	L = _board([[0, K.SOLDIER, Vector2i(5, 5)], [0, K.PRIEST, Vector2i(5, 6)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.ROBOT, Vector2i(4, 5)], [1, K.PRIEST, Vector2i(6, 6)]])
	_act(L, _id(0, K.SOLDIER), [Vector2i(5, 5)])
	t = L.step_options()
	_check(t.get(Vector2i(5, 4)) == "attack" and not t.has(Vector2i(5, 6)) and not t.has(Vector2i(4, 5)) and not t.has(Vector2i(6, 6)), "not allies, not the robot, not diagonals")


func _test_angel() -> void:
	# 2칸 이하 (영웅을 뛰어넘음) → 아군 유령 칸에 들어간 그 차례에 바로 내 성 주위 5칸에 부활
	var L := _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.SOLDIER, Vector2i(5, 6)], [0, K.KNIGHT, Vector2i(2, 2)],
		[1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(_id(0, K.KNIGHT), "attack")
	L._set_ghost(_id(0, K.KNIGHT), Vector2i(5, 5))
	var t := L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE)
	_check(t.get(Vector2i(5, 5)) == "revive", "angel jumps over a hero")
	_check(t.has(Vector2i(3, 7)) and t.has(Vector2i(7, 7)) and t.has(Vector2i(5, 9)) and t.get(Vector2i(5, 6)) == "land" and t.get(Vector2i(5, 7)) == "stay",
		"up to 2 cells in one direction, can land on a hero, can stay")
	_check(not t.has(Vector2i(5, 4)) and not t.has(Vector2i(4, 6)) and not t.has(Vector2i(4, 5)) and not t.has(Vector2i(2, 7)) and not t.has(Vector2i(5, 10)), "never 3 cells, no turns, no diagonals")
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5)])
	t = L.step_options()
	_check(L.act_step == ST.REVIVE and t.size() == 5 and t.get(Vector2i(5, 9)) == "rise" and t.has(Vector2i(4, 9)) and t.has(Vector2i(6, 10)),
		"revive onto one of the 5 cells around MY castle, right away")
	L.choose(Vector2i(4, 9))
	_check(L.pos[_id(0, K.KNIGHT)] == Vector2i(4, 9) and not L.has_ghost(_id(0, K.KNIGHT)), "revived around the castle")
	# 유령 칸에 들어가면 꼭 부활 (벽 치기로 대신 못 함). 성 주위 빈칸이 없으면 아군 유령 칸에 못 감
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.KNIGHT, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(_id(0, K.KNIGHT), "attack")
	L._set_wall(Vector2i(5, 5), Vector2i(4, 5), 1)
	_check(L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE).get(Vector2i(5, 5)) == "revive", "marked as a revival")
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5), STOP])
	_check(L.act_step == ST.REVIVE and not L.act_optional and L.step_options().size() == 5 and not L.step_options().values().has("break"), "reviving can't be skipped or swapped for a wall")
	L.choose(Vector2i(6, 9))
	_check(L.alive(_id(0, K.KNIGHT)) and L.act_hero < 0, "revived")
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.REAPER, Vector2i(5, 6)], [0, K.SOLDIER, Vector2i(5, 9)], [0, K.KNIGHT, Vector2i(4, 10)],
		[0, K.PRIEST, Vector2i(4, 9)], [0, K.MAGICIAN, Vector2i(6, 9)], [0, K.ROBOT, Vector2i(6, 10)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(_id(0, K.REAPER), "attack")
	t = L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE)
	_check(not t.has(Vector2i(5, 6)) and t.has(Vector2i(5, 5)), "no free cell around the castle → can't enter my ghost's cell (flying over is fine)")
	L._relocate(_id(0, K.ROBOT), Vector2i(0, 5))
	_check(L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE).get(Vector2i(5, 6)) == "revive", "one free cell is enough")
	# 적 유령 칸에 가면 그 유령을 없앰 (다른 유령은 그대로). 봉인이면 유령 칸에 못 감, 적 전사 옆에는 갈 수 있음
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [1, K.KNIGHT, Vector2i(5, 5)], [1, K.ARCHITECT, Vector2i(7, 5)], [1, K.SOLDIER, Vector2i(0, 0)]])
	for id in [_id(1, K.KNIGHT), _id(1, K.ARCHITECT)]:
		L._kill(id, "attack")
	var both := L.clone()
	_check(L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE).get(Vector2i(5, 5)) == "exorcise", "marked as a removal")
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5)])
	_check(not L.has_ghost(_id(1, K.KNIGHT)) and L.has_ghost(_id(1, K.ARCHITECT)) and L.ghost_at(Vector2i(5, 5)) < 0 and L.pos[_id(0, K.ANGEL)] == Vector2i(5, 5),
		"the angel removes the enemy ghost on its cell")
	both.sealed[_id(0, K.ANGEL)] = 1
	_check(not both.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE).has(Vector2i(5, 5)) and both.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE).has(Vector2i(5, 6)), "a sealed angel can't enter a ghost's cell")
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [1, K.KNIGHT, Vector2i(5, 5)], [1, K.WARRIOR, Vector2i(4, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(_id(1, K.KNIGHT), "attack")
	_check(L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE).get(Vector2i(5, 5)) == "exorcise", "beside an enemy warrior it can")
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5)])
	_check(not L.has_ghost(_id(1, K.KNIGHT)) and L.disabled_by[_id(0, K.ANGEL)] < 0, "an angel isn't disabled")
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.KNIGHT, Vector2i(5, 5)], [1, K.WARRIOR, Vector2i(4, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(_id(0, K.KNIGHT), "attack")
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5), Vector2i(4, 9)])
	_check(L.alive(_id(0, K.KNIGHT)) and L.pos[_id(0, K.KNIGHT)] == Vector2i(4, 9), "and it revives there too")
	L = _board([[0, K.NINJA, Vector2i(3, 8)], [0, K.ANGEL, Vector2i(3, 2)], [1, K.KNIGHT, Vector2i(5, 8)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(_id(1, K.KNIGHT), "attack")
	_act(L, _id(0, K.NINJA), [Vector2i(3, 2), Vector2i(5, 8)])
	_check(not L.has_ghost(_id(1, K.KNIGHT)), "a ninja in angel form removes it too")
	# 유령 칸에 서는 순간 사신에게 맞으면: 유령은 그대로, 천사는 유령 없이 쓰러짐
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.KNIGHT, Vector2i(5, 5)], [1, K.REAPER, Vector2i(6, 4)]])
	L._kill(_id(1, K.KNIGHT), "attack")
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5)])
	_check(not L.alive(_id(0, K.ANGEL)) and L.ghost_at(Vector2i(5, 5)) == _id(1, K.KNIGHT) and not L.has_ghost(_id(0, K.ANGEL)),
		"cut down on arrival: the ghost stays, the angel leaves none")
	# 적 칸에 내려앉으면 그 적이 아니라 그 적의 상하좌우 적 한 명을 공격하고, 천사는 이동 전 자리로 돌아감 (로봇 칸은 X)
	var set_up := [[0, K.ANGEL, Vector2i(5, 7)], [1, K.KNIGHT, Vector2i(5, 5)], [1, K.ROBOT, Vector2i(6, 6)], [1, K.PRIEST, Vector2i(5, 4)],
		[1, K.MAGICIAN, Vector2i(6, 4)], [1, K.SOLDIER, Vector2i(0, 0)]]
	L = _board(set_up)
	t = L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE)
	_check(t.get(Vector2i(5, 5)) == "land" and not t.has(Vector2i(6, 6)), "angel can land on an enemy, not on the robot")
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5)])
	t = L.step_options()
	_check(L.act_step == ST.LAND and not L.act_optional and t.get(Vector2i(5, 4)) == "attack" and not t.has(Vector2i(5, 5))
		and not t.has(Vector2i(6, 4)) and t.get(Vector2i(5, 7)) == "return" and not t.has(Vector2i(4, 10)) and t.size() == 2, "attack an enemy next to it, or just go back")
	_check(L.at(Vector2i(5, 5)) == _id(1, K.KNIGHT) and L.alive(_id(1, K.KNIGHT)), "the hero it lands on isn't hurt")
	L.choose(Vector2i(5, 4))
	_check(not L.alive(_id(1, K.PRIEST)) and L.pos[_id(0, K.ANGEL)] == Vector2i(5, 7) and L.at(Vector2i(5, 7)) == _id(0, K.ANGEL) and L.at(Vector2i(5, 5)) == _id(1, K.KNIGHT)
		and L.act_hero < 0, "enemy falls, the angel is back where it started")
	L = _board(set_up)
	L.barrier[_id(1, K.PRIEST)] = 1
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5), Vector2i(5, 4)])
	_check(L.act_hero < 0 and L.alive(_id(1, K.PRIEST)) and L.barrier[_id(1, K.PRIEST)] == 0, "a barrier blocks the angel's attack")
	# 아군 칸에 내려앉아도 똑같음 (아군은 그대로). 공격할 적이 없으면 그냥 돌아감
	L = _board([[0, K.ANGEL, Vector2i(5, 5)], [0, K.WARRIOR, Vector2i(5, 3)], [1, K.SOLDIER, Vector2i(6, 3)], [1, K.PRIEST, Vector2i(9, 0)]])
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 3), Vector2i(6, 3)])
	_check(not L.alive(_id(1, K.SOLDIER)) and L.pos[_id(0, K.WARRIOR)] == Vector2i(5, 3) and L.at(Vector2i(5, 3)) == _id(0, K.WARRIOR) and L.pos[_id(0, K.ANGEL)] == Vector2i(5, 5),
		"landing on an ally: attack next to it, the ally stays")
	L = _board([[0, K.ANGEL, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(9, 0)]])
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 3)])
	_check(L.act_step == ST.LAND and L.step_options() == {Vector2i(5, 5): "return"}, "nothing to attack → still can land, and goes back")
	L.choose(Vector2i(5, 5))
	_check(L.pos[_id(0, K.ANGEL)] == Vector2i(5, 5) and L.act_hero < 0, "went back")
	# 성 주위에 빈칸이 없어도 내려앉을 수 있음
	var full := [[0, K.ANGEL, Vector2i(5, 3)], [0, K.WARRIOR, Vector2i(5, 1)], [0, K.SOLDIER, Vector2i(5, 9)], [0, K.KNIGHT, Vector2i(4, 10)],
		[0, K.PRIEST, Vector2i(4, 9)], [0, K.MAGICIAN, Vector2i(6, 9)], [0, K.ROBOT, Vector2i(6, 10)], [1, K.SOLDIER, Vector2i(0, 0)]]
	L = _board(full)
	_check(L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE).get(Vector2i(5, 1)) == "land", "no free cell around the castle is needed")
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 1), Vector2i(5, 0)])
	_check(L.lives[1] == 2 and L.pos[_id(0, K.ANGEL)] == Vector2i(5, 3) and L.act_hero < 0, "hits the castle and goes back")
	# 돌아온 자리가 적 사신의 대각선이면 맞음(배리어가 내려앉은 칸의 지뢰에 깨진 뒤). 자리에 있던 배리어가 막아 주던 것
	L = _board([[0, K.ANGEL, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.REAPER, Vector2i(6, 6)], [1, K.KNIGHT, Vector2i(5, 3)]])
	L.barrier[_id(0, K.ANGEL)] = 1
	L.mines[L._i(Vector2i(5, 3))] = 2
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 3), Vector2i(5, 5)])
	_check(not L.alive(_id(0, K.ANGEL)) and L.cross_cell(0) == Vector2i(5, 5), "going back is a stop too: the reaper cuts it")
	# 벽과 포탑에 막힘 (공격은 내 벽만 넘음)
	L = _board([[0, K.ANGEL, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(5, 2)], [1, K.KNIGHT, Vector2i(9, 0)]])
	L._set_wall(Vector2i(5, 5), Vector2i(5, 4), 1)
	L._set_wall(Vector2i(5, 3), Vector2i(5, 2), 1)
	t = L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE)
	_check(not t.has(Vector2i(5, 4)) and not t.has(Vector2i(5, 3)) and t.has(Vector2i(5, 6)) and t.has(Vector2i(3, 5)), "walls stop the angel")
	L._set_wall(Vector2i(5, 5), Vector2i(5, 4), -1)
	L._set_wall(Vector2i(5, 4), Vector2i(5, 3), 0)
	t = L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE)
	_check(t.has(Vector2i(5, 4)) and not t.has(Vector2i(5, 3)), "anyone's wall, on the second step too")
	L._set_wall(Vector2i(5, 4), Vector2i(5, 3), -1)
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 3)])
	_check(not L.step_options().has(Vector2i(5, 2)), "no attack over an enemy wall")
	L._set_wall(Vector2i(5, 3), Vector2i(5, 2), 0)
	_check(L.step_options().get(Vector2i(5, 2)) == "attack", "over mine it can")
	L = _board([[0, K.ANGEL, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.turret[L._i(Vector2i(5, 4))] = 2
	for d in HeroLogic.DIRS4:
		L._set_wall(Vector2i(5, 4), Vector2i(5, 4) + d, 1)
	t = L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE)
	_check(not t.has(Vector2i(5, 4)) and not t.has(Vector2i(5, 3)), "a turret stops it")
	# 붙은 상대 성은 다른 영웅처럼 칠 수 있음
	L = _board([[0, K.ANGEL, Vector2i(5, 3)], [1, K.SOLDIER, Vector2i(5, 1)]])
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 1), Vector2i(5, 0)])
	_check(L.lives[1] == 2 and L.pos[_id(0, K.ANGEL)] == Vector2i(5, 3), "landing next to the castle it can hit it, then goes back")
	# 영웅 칸에 내려앉는 것도 멈춘 것: 적 사신의 대각선이면 공격받음, 적 전사 주위 8칸 영웅 칸엔 못 내려앉음(전사 자신의 칸은 됨)
	L = _board([[0, K.ANGEL, Vector2i(5, 6)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.REAPER, Vector2i(6, 3)]])
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 4)])
	_check(not L.alive(_id(0, K.ANGEL)) and L.act_hero < 0 and L.at(Vector2i(5, 4)) == _id(1, K.KNIGHT) and not L.has_ghost(_id(0, K.ANGEL)), "the enemy reaper cuts an angel landing on its diagonal")
	L = _board([[0, K.ANGEL, Vector2i(5, 6)], [1, K.KNIGHT, Vector2i(5, 5)], [1, K.WARRIOR, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(5, 3)]])
	t = L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE)
	_check(t.get(Vector2i(5, 5)) == "land" and t.get(Vector2i(5, 4)) == "land", "it may land on heroes beside an enemy warrior too")
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5)])
	_check(L.act_step == ST.LAND and L.disabled_by[_id(0, K.ANGEL)] < 0 and L.step_options().get(Vector2i(5, 4)) == "attack", "not disabled: it can attack the warrior")
	L.choose(Vector2i(5, 4))
	_check(not L.alive(_id(1, K.WARRIOR)) and L.pos[_id(0, K.ANGEL)] == Vector2i(5, 6) and L.act_hero < 0, "then it goes back")
	# 무력해진 아군 칸에 내려앉아 공격하고 복귀. 빈칸에 멈춰도 무력해지지 않음 (천사 모습 닌자도)
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.KNIGHT, Vector2i(5, 5)], [1, K.WARRIOR, Vector2i(4, 4)], [1, K.PRIEST, Vector2i(6, 5)]])
	_check(L.disabled_by[_id(0, K.KNIGHT)] == _id(1, K.WARRIOR) and L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE).get(Vector2i(5, 5)) == "land", "on a disabled ally")
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5), Vector2i(6, 5)])
	_check(not L.alive(_id(1, K.PRIEST)) and L.pos[_id(0, K.ANGEL)] == Vector2i(5, 7) and L.disabled_by[_id(0, K.ANGEL)] < 0 and L.disabled_by[_id(0, K.KNIGHT)] >= 0,
		"attack from a disabled ally's cell, the ally stays disabled")
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.KNIGHT, Vector2i(9, 9)], [1, K.WARRIOR, Vector2i(4, 4)], [1, K.PRIEST, Vector2i(6, 5)]])
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5)])
	_check(L.act_hero < 0 and L.disabled_by[_id(0, K.ANGEL)] < 0, "stopping on a free cell beside it doesn't disable")
	L.end_turn()
	L.pass_turn()
	_check(L.selectable().has(_id(0, K.ANGEL)), "it can act on its next turn")
	L = _board([[0, K.NINJA, Vector2i(5, 7)], [0, K.ANGEL, Vector2i(5, 9)], [0, K.KNIGHT, Vector2i(9, 9)], [1, K.WARRIOR, Vector2i(4, 4)], [1, K.PRIEST, Vector2i(9, 0)]])
	_act(L, _id(0, K.NINJA), [Vector2i(5, 9), Vector2i(5, 5)])
	_check(L.disabled_by[_id(0, K.NINJA)] < 0, "a ninja in angel form neither")
	L.ninja_form[0] = -1
	L._update_disabled()
	_check(L.disabled_by[_id(0, K.NINJA)] == _id(1, K.WARRIOR), "a plain ninja is")
	_test_sacrifice()


## 천사는 쓰러지면 유령 대신 십자가가 생기고, 성직자가 내 성 주위 5칸에서 희생해 십자가 자리에서 부활시킴
func _test_sacrifice() -> void:
	var an := _id(0, K.ANGEL)
	var pr := _id(0, K.PRIEST)
	for cause in ["attack", "curse", "house"]:
		var D := _board([[0, K.ANGEL, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
		D._kill(an, cause, cause == "attack")
		_check(not D.alive(an) and not D.has_ghost(an) and D.ghost_at(Vector2i(5, 5)) < 0 and D.cross_cell(0) == (Vector2i(5, 5) if cause == "attack" else HeroLogic.NONE),
			"a fallen angel leaves a cross, no ghost, and nothing when no trace is left (%s)" % cause)
	var L := _board([[0, K.ANGEL, Vector2i(2, 2)], [0, K.PRIEST, Vector2i(3, 9)], [0, K.SOLDIER, Vector2i(9, 9)], [0, K.KNIGHT, Vector2i(5, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(an, "attack")
	var h0 := L.state_hash()
	L.cross[0] = -1
	_check(L.state_hash() != h0, "the cross is part of the state")
	L.cross[0] = L._i(Vector2i(2, 2))
	_check(L.clone().cross_cell(0) == Vector2i(2, 2), "and is cloned")
	_act(L, pr, [Vector2i(3, 9)])
	_check(not L.step_options().values().has("rise"), "not away from the castle")
	L.stop_action()
	L.end_turn()
	L.pass_turn()
	_act(L, pr, [Vector2i(4, 9)])
	var t := L.step_options()
	_check(L.act_optional and t.get(Vector2i(2, 2)) == "rise" and not t.has(Vector2i(4, 10)) and not t.has(Vector2i(6, 9)) and t.get(Vector2i(5, 9)) == "barrier" and t.get(Vector2i(4, 9)) == "barrier",
		"next to the castle: a barrier, or the cross")
	var ev := L.choose(Vector2i(2, 2))
	var told := false
	for e in ev:
		told = told or e["t"] == "sacrifice"
	_check(told and L.pos[an] == Vector2i(2, 2) and L.at(Vector2i(2, 2)) == an and not L.alive(pr) and L.ghost_pos[pr] == Vector2i(4, 9) and L.act_hero < 0 and L.used == 1 and L.cross[0] < 0,
		"the priest falls (its ghost stays), the angel is back where its cross was, the cross is gone")
	_check(L.selectable().has(an), "the angel can act this turn")
	# 살아 있으면 안 됨, 무력 · 봉인이면 안 됨
	L = _board([[0, K.ANGEL, Vector2i(2, 2)], [0, K.PRIEST, Vector2i(4, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, pr, [Vector2i(4, 9)])
	_check(not L.step_options().values().has("rise"), "not while the angel is alive")
	L = _board([[0, K.ANGEL, Vector2i(2, 2)], [0, K.PRIEST, Vector2i(4, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(an, "attack")
	L.sealed[pr] = 1
	_act(L, pr, [Vector2i(4, 9)])
	_check(L.act_hero < 0 and not L.alive(an), "not while sealed")
	# 성 주위가 꽉 차 있어도 됨
	L = _board([[0, K.ANGEL, Vector2i(2, 2)], [0, K.PRIEST, Vector2i(4, 9)], [0, K.SOLDIER, Vector2i(4, 10)], [0, K.KNIGHT, Vector2i(5, 9)], [0, K.WARRIOR, Vector2i(6, 9)], [0, K.ROBOT, Vector2i(6, 10)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(an, "attack")
	_act(L, pr, [Vector2i(4, 9)])
	_check(L.step_options().get(Vector2i(2, 2)) == "rise", "no free castle cell is needed")
	# 상대 성 주위는 X, 성직자를 따라 한 닌자도 됨 (닌자의 유령이 남음)
	L = _board([[0, K.ANGEL, Vector2i(2, 2)], [0, K.PRIEST, Vector2i(4, 1)], [1, K.SOLDIER, Vector2i(0, 10)]])
	L._kill(an, "attack")
	_act(L, pr, [Vector2i(4, 1)])
	_check(not L.step_options().values().has("rise"), "not next to the enemy castle")
	L = _board([[0, K.ANGEL, Vector2i(2, 2)], [0, K.NINJA, Vector2i(4, 9)], [0, K.PRIEST, Vector2i(4, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(an, "attack")
	_act(L, _id(0, K.NINJA), [Vector2i(4, 4), Vector2i(4, 9), Vector2i(2, 2)])
	_check(L.alive(an) and L.pos[an] == Vector2i(2, 2) and not L.alive(_id(0, K.NINJA)) and L.has_ghost(_id(0, K.NINJA)) and L.alive(pr), "a ninja in priest form sacrifices itself")
	# 내 십자가만 (상대 천사의 십자가로는 X)
	L = _board([[1, K.ANGEL, Vector2i(2, 2)], [0, K.PRIEST, Vector2i(4, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(_id(1, K.ANGEL), "attack")
	_act(L, pr, [Vector2i(4, 9)])
	_check(L.cross_at(Vector2i(2, 2)) == 1 and not L.step_options().values().has("rise"), "only my own angel's cross")
	_test_angel_cross()
	# 천사 모습 닌자가 쓰러지면 유령이 남음
	L = _board([[0, K.NINJA, Vector2i(3, 8)], [0, K.ANGEL, Vector2i(3, 3)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(5, 8)], [1, K.PRIEST, Vector2i(9, 0)]])
	_act(L, _id(0, K.NINJA), [Vector2i(3, 3), Vector2i(4, 8)])
	if L.act_hero >= 0:
		L.stop_action()
	L.end_turn()
	_act(L, _id(1, K.SOLDIER), [Vector2i(5, 8), Vector2i(4, 8)])
	_check(not L.alive(_id(0, K.NINJA)) and L.has_ghost(_id(0, K.NINJA)), "a ninja in angel form leaves a ghost")


## 십자가 칸: 아무도 못 멈추고 지나가기는 됨
func _test_angel_cross() -> void:
	var an := _id(0, K.ANGEL)
	var pr := _id(0, K.PRIEST)
	var x := Vector2i(5, 5)
	for k in [K.KNIGHT, K.SOLDIER, K.ARCHITECT, K.NINJA, K.ROBOT, K.ANGEL, K.WARRIOR, K.PRIEST, K.REAPER]:
		for side in 2:
			# 천사 편도 상대 편도 못 멈춤. 2칸 이상 가는 영웅은 지나감
			var B := _board([[1 - side if k == K.ANGEL else 0, K.ANGEL, x], [side, k, Vector2i(5, 6)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.MAGICIAN, Vector2i(0, 0)]], side)
			var who: int = (1 - side if k == K.ANGEL else 0) * 10 + K.ANGEL
			B._kill(who, "attack")
			var paths := B.move_paths(_id(side, k))
			_check(not paths.has(x), "%s can't stop on a cross (side %d)" % [HeroLogic.NAMES[k], side])
			if not k in [K.WARRIOR, K.PRIEST, K.REAPER]:
				_check(paths.has(Vector2i(5, 4)), "%s passes over it (side %d)" % [HeroLogic.NAMES[k], side])
	# 유령도 못 멈춤, 밀 자리도 아님(스턴), 지뢰도 못 놓음, 전진도 못 함
	var L := _board([[0, K.ANGEL, x], [0, K.SOLDIER, Vector2i(5, 6)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(4, 5)], [1, K.ROBOT, Vector2i(0, 0)]])
	L._kill(an, "attack")
	L._kill(_id(0, K.SOLDIER), "attack")
	_check(not L.spirit_paths(_id(0, K.SOLDIER)).has(x), "a ghost can't stop on a cross")
	L = _board([[1, K.ANGEL, x], [0, K.ROBOT, Vector2i(2, 5)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(4, 5)], [1, K.ROBOT, Vector2i(0, 0)]])
	L._kill(_id(1, K.ANGEL), "attack")
	_act(L, _id(0, K.ROBOT), [Vector2i(3, 5), Vector2i(4, 5)])
	_check(L.pos[_id(1, K.SOLDIER)] == Vector2i(4, 5) and L.stunned[_id(1, K.SOLDIER)] == 1, "no room on a cross: a stun")
	L = _board([[1, K.ANGEL, x], [0, K.SOLDIER, Vector2i(5, 6)], [0, K.PRIEST, Vector2i(9, 9)], [0, K.WARRIOR, Vector2i(5, 7)], [1, K.ROBOT, Vector2i(0, 0)]])
	L._kill(_id(1, K.ANGEL), "attack")
	_act(L, _id(0, K.SOLDIER), [Vector2i(5, 6)])
	_check(not L.step_options().has(x) and L.step_options().get(Vector2i(4, 6)) == "mine", "no mine on a cross")
	L.choose(Vector2i(4, 6))
	_check(L.mine_at(x) < 0, "none laid there")
	# 성 주위 십자가 칸에는 소환도 부활도 안 됨
	L = _board([[0, K.ANGEL, Vector2i(5, 9)], [0, K.SOLDIER, Vector2i(9, 4)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.ROBOT, Vector2i(0, 0)]])
	L._kill(an, "attack")
	_check(not L.summon_cells().has(Vector2i(5, 9)) and L.summon_cells().size() == 4, "no summoning onto a cross")
	# 십자가 칸이 포탑이 되면 십자가가 사라짐 (내 포탑이든 적 포탑이든). 그 천사는 부활 못 함
	for side in 2:
		L = _board([[1, K.ANGEL, x], [side, K.ARCHITECT, Vector2i(5, 6)], [1, K.PRIEST, Vector2i(4, 1)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.ROBOT, Vector2i(0, 0)]], side)
		L._kill(_id(1, K.ANGEL), "attack")
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			L._set_wall(x, x + d, side)
		var ev := _act(L, _id(side, K.ARCHITECT), [Vector2i(5, 6), x])
		var gone := 0
		for e in ev:
			gone += int(e["t"] == "cross_gone")
		_check(L.turret_at(x) == side and L.cross[1] < 0 and gone == 1, "a turret on a cross takes the cross away (side %d)" % side)
		if L.act_hero >= 0:
			L.stop_action()
		if side == 0:
			L.end_turn()
		_act(L, _id(1, K.PRIEST), [Vector2i(4, 1)])
		_check(not L.step_options().values().has("rise") and not L.step_options().has(x), "that angel can't come back (side %d)" % side)
	# 천사가 포탑에 갇혀 쓰러지면 십자가가 안 생김. 로봇이 그 포탑을 부숴도 없음
	for side in 2:
		L = _board([[0, K.ANGEL, x], [0, K.PRIEST, Vector2i(4, 9)], [0, K.ARCHITECT, Vector2i(9, 9)], [side, K.ARCHITECT, Vector2i(5, 6)], [0, K.ROBOT, Vector2i(0, 5)], [1, K.ROBOT, Vector2i(0, 0)]], side)
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			L._set_wall(x, x + d, side)
		_act(L, _id(side, K.ARCHITECT), [Vector2i(5, 6), x])
		_check(not L.alive(an) and L.turret_at(x) == side and L.cross[0] < 0 and not L.has_ghost(an), "trapped in a turret it leaves no cross (side %d)" % side)
		if L.act_hero >= 0:
			L.stop_action()
		if side == 1:
			L.end_turn()
		_act(L, _id(0, K.ROBOT), [Vector2i(4, 5), x])
		_check(L.turret_at(x) < 0 and L.cross[0] < 0 and L.is_free(x), "broken by a robot: still no cross (side %d)" % side)
	# 유령 칸은 여전히 포탑이 안 됨
	L = _board([[1, K.SOLDIER, x], [0, K.ARCHITECT, Vector2i(5, 6)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.ROBOT, Vector2i(0, 0)]])
	L._kill(_id(1, K.SOLDIER), "attack")
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		L._set_wall(x, x + d, 0)
	_act(L, _id(0, K.ARCHITECT), [Vector2i(5, 6), x])
	_check(L.turret_at(x) < 0 and L.has_ghost(_id(1, K.SOLDIER)), "a ghost cell still can't become a turret")
	# 내려앉다 쓰러지면(적 지뢰) 가장 가까운 빈칸에 십자가 (적 지뢰 칸은 빼고)
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, x], [1, K.PRIEST, Vector2i(0, 0)]])
	L.mines[L._i(x)] = 2
	L.mines[L._i(Vector2i(5, 6))] = 2
	_act(L, an, [x])
	_check(not L.alive(an) and L.at(x) == _id(1, K.SOLDIER) and L.cross_cell(0) == Vector2i(4, 5), "falling on another hero's cell: the nearest free cell without an enemy mine")
	# 부활한 자리에서는 멈춘 것처럼 사신에게 맞음 (십자가는 다시 생김)
	L = _board([[0, K.ANGEL, x], [0, K.PRIEST, Vector2i(4, 9)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.REAPER, Vector2i(6, 6)], [1, K.PRIEST, Vector2i(0, 0)]])
	L._kill(an, "attack")
	_act(L, pr, [Vector2i(4, 9), x])
	_check(not L.alive(an) and L.cross_cell(0) == x and L.ghost_pos[pr] == Vector2i(4, 9), "next to a reaper's diagonal it falls again")
	# 저주는 천사에게 안 통함: 못 걸고, 그 너머로도 못 걺. 자동 공격은 맞음
	L = _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.ANGEL, Vector2i(5, 6)], [1, K.SOLDIER, x], [1, K.PRIEST, Vector2i(0, 0)]])
	_act(L, _id(0, K.REAPER), [Vector2i(5, 7)])
	_check(not L.step_options().has(Vector2i(5, 6)) and not L.step_options().has(x), "no curse on an angel, nor past it")
	L = _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.NINJA, Vector2i(5, 5)], [1, K.PRIEST, Vector2i(0, 0)]])
	L.ninja_form[1] = K.ANGEL
	_act(L, _id(0, K.REAPER), [Vector2i(5, 7)])
	_check(L.act_hero < 0 or not L.step_options().has(Vector2i(5, 5)), "nor on a ninja in angel form")
	L = _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.NINJA, Vector2i(0, 5)], [1, K.PRIEST, Vector2i(0, 0)]])
	L.cursed_by[_id(1, K.NINJA)] = _id(0, K.REAPER)
	_act(L, _id(0, K.REAPER), [Vector2i(5, 7)])
	_check(L.step_options().get(Vector2i(0, 5)) == "doom", "a cursed ninja can be taken")
	L.ninja_form[1] = K.ANGEL
	_check(not L.step_options().has(Vector2i(0, 5)), "not while it is in angel form")
	L = _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.ANGEL, Vector2i(7, 5)], [1, K.PRIEST, Vector2i(0, 0)]])
	_act(L, _id(0, K.REAPER), [Vector2i(6, 7)])
	if L.act_hero >= 0:
		L.stop_action()
	_act(L, _id(0, K.PRIEST), [Vector2i(9, 9), STOP])
	_check(L.alive(_id(1, K.ANGEL)), "(not on its diagonal yet)")
	L._relocate(_id(0, K.REAPER), Vector2i(6, 6))
	L._reap_around()
	_check(not L.alive(_id(1, K.ANGEL)) and L.cross_cell(1) == Vector2i(7, 5), "but the reaper's own strike still hits it")


func _test_flying_and_walls() -> void:
	# 천사도 지뢰에 맞음 (유령은 안 생김). 천사 모습을 따라 한 닌자도. 배리어가 막아 줌
	var L := _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.mines[L._i(Vector2i(5, 5))] = 2
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5)])
	_check(not L.alive(_id(0, K.ANGEL)) and L.mine_at(Vector2i(5, 5)) < 0 and not L.has_ghost(_id(0, K.ANGEL)), "the angel is hurt by a mine")
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.mines[L._i(Vector2i(5, 5))] = 2
	L.barrier[_id(0, K.ANGEL)] = 1
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5)])
	_check(L.alive(_id(0, K.ANGEL)) and L.mine_at(Vector2i(5, 5)) < 0 and L.barrier[_id(0, K.ANGEL)] == 0, "a barrier takes it")
	# 지뢰를 넘어가는 것은 괜찮음
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.mines[L._i(Vector2i(5, 6))] = 2
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5)])
	_check(L.alive(_id(0, K.ANGEL)) and L.mine_at(Vector2i(5, 6)) == 1, "passing over a mine is fine")
	# 자기 지뢰 위의 적에게 내려앉으면 그 지뢰에 맞음. 유령 칸의 적 지뢰도
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(5, 5)], [1, K.PRIEST, Vector2i(6, 5)]])
	L.mines[L._i(Vector2i(5, 5))] = 2
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5)])
	_check(not L.alive(_id(0, K.ANGEL)) and L.alive(_id(1, K.SOLDIER)) and L.at(Vector2i(5, 5)) == _id(1, K.SOLDIER) and L.mine_at(Vector2i(5, 5)) < 0 and L.act_hero < 0,
		"landing on an enemy standing on its own mine")
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(_id(0, K.PRIEST), "attack")
	L.mines[L._i(Vector2i(5, 5))] = 2
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 5)])
	_check(not L.alive(_id(0, K.ANGEL)) and L.has_ghost(_id(0, K.PRIEST)) and L.act_hero < 0, "a mine on the ghost's cell stops the revival")
	L = _board([[0, K.NINJA, Vector2i(5, 7)], [0, K.ANGEL, Vector2i(5, 2)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.mines[L._i(Vector2i(7, 7))] = 2
	_act(L, _id(0, K.NINJA), [Vector2i(5, 2), Vector2i(7, 7)])
	_check(not L.alive(_id(0, K.NINJA)), "a ninja in angel form is too")
	# 파이어볼은 적군의 벽(내 벽은 지나감)과 모든 포탑에 막힘
	L = _board([[0, K.MAGICIAN, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(7, 5)], [1, K.PRIEST, Vector2i(3, 5)]])
	L._set_wall(Vector2i(6, 5), Vector2i(7, 5), 0)
	L._set_wall(Vector2i(4, 5), Vector2i(3, 5), 1)
	var mg := _id(0, K.MAGICIAN)
	_check(L.options_for(mg, K.MAGICIAN, ST.SWAP_FIRE) == {Vector2i(7, 5): "fire"}, "an enemy wall stops the fireball, mine doesn't")
	for who in 2:
		L.turret[L._i(Vector2i(6, 5))] = who + 1
		for d in HeroLogic.DIRS4:
			L._set_wall(Vector2i(6, 5), Vector2i(6, 5) + d, who)
		_check(L.options_for(mg, K.MAGICIAN, ST.SWAP_FIRE).is_empty(), "any turret stops it, mine too")
	L.turret[L._i(Vector2i(6, 5))] = 2
	for d in HeroLogic.DIRS4:
		L._set_wall(Vector2i(6, 5), Vector2i(6, 5) + d, -1)
	_check(L.options_for(mg, K.MAGICIAN, ST.SWAP_FIRE).is_empty(), "the turret cell itself stops it too")
	for far in [1, 2, 3]:
		for owner in 2:
			L = _board([[0, K.MAGICIAN, Vector2i(5, far)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 9)]])
			L._set_wall(Vector2i(5, 1), Vector2i(5, 0), owner)
			_check(L.options_for(mg, K.MAGICIAN, ST.SWAP_FIRE).get(Vector2i(5, 0), "") == ("castle" if owner == 0 else ""), "a wall before the castle (%d away)" % far)
	# 로봇은 움직인 방향의 적만 밂. 밀려나는 길의 벽에 막히면 스턴, 로봇과 영웅 사이의 벽은 상관없음 (그 벽을 부술 수도 있음: 칸 + SIDE)
	L = _board([[0, K.ROBOT, Vector2i(3, 5)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.PRIEST, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(6, 5)], [1, K.KNIGHT, Vector2i(9, 0)]])
	L._set_wall(Vector2i(5, 5), Vector2i(6, 5), 0)
	L._set_wall(Vector2i(5, 5), Vector2i(5, 6), 1)
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5)])
	var pt := L.step_options()
	_check(pt == {Vector2i(6, 5): "push", Vector2i(6, 5) + HeroLogic.SIDE: "break", Vector2i(5, 6): "break"},
		"push the enemy ahead over a wall or break it; walls of either side can be broken on every side; not an enemy to the side")
	var br := L.clone()
	var pu := L.clone()
	br.choose(Vector2i(6, 5) + HeroLogic.SIDE)
	_check(br.wall_count() == 1 and br.pos[_id(1, K.SOLDIER)] == Vector2i(6, 5) and br.act_hero < 0, "the wall broken, nobody pushed")
	pu.choose(Vector2i(6, 5))
	_check(pu.wall_count() == 2 and pu.pos[_id(1, K.SOLDIER)] == Vector2i(7, 5) and pu.stunned[_id(1, K.SOLDIER)] == 1, "or the hero pushed and stunned, the wall stays")
	L = _board([[0, K.ROBOT, Vector2i(7, 5)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.KNIGHT, Vector2i(4, 5)], [1, K.PRIEST, Vector2i(9, 0)]])
	L._set_wall(Vector2i(4, 5), Vector2i(3, 5), 1)
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5), Vector2i(4, 5)])
	_check(L.pos[_id(1, K.KNIGHT)] == Vector2i(4, 5) and L.stunned[_id(1, K.KNIGHT)] == 1, "a wall behind: stunned where it stands")
	L = _board([[0, K.ROBOT, Vector2i(5, 7)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.PRIEST, Vector2i(5, 4)], [1, K.KNIGHT, Vector2i(9, 0)]])
	L.mines[L._i(Vector2i(5, 3))] = 1
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5), Vector2i(5, 4)])
	_check(not L.alive(_id(1, K.PRIEST)), "an enemy pushed onto my mine is hurt")
	# 네 변이 모두 아군 벽이어야 포탑, 적군 벽이 하나라도 섞이면 벽으로만 남음 (안의 영웅도 그대로)
	for mixed in [1, 2, 3]:
		for inside in 2:
			L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [1, K.PRIEST, Vector2i(9, 0)], [1, K.SOLDIER, Vector2i(5, 4) if inside == 1 else Vector2i(0, 0)]])
			var ns := [Vector2i(4, 4), Vector2i(6, 4), Vector2i(5, 3)]
			for i in 3:
				L._set_wall(Vector2i(5, 4), ns[i], 1 if i < mixed else 0)
			_act(L, _id(0, K.ARCHITECT), [Vector2i(5, 5), Vector2i(5, 4)])
			_check(L.turret_at(Vector2i(5, 4)) < 0 and L.wall_count() == 4 and L.alive(_id(1, K.SOLDIER)), "no turret with %d enemy walls" % mixed)
	# 건축가 자기 칸도 마찬가지
	L = _board([[0, K.ARCHITECT, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(9, 0)]])
	L._set_wall(Vector2i(5, 4), Vector2i(4, 4), 0)
	L._set_wall(Vector2i(5, 4), Vector2i(6, 4), 1)
	L._set_wall(Vector2i(5, 4), Vector2i(5, 3), 0)
	_act(L, _id(0, K.ARCHITECT), [Vector2i(5, 4), Vector2i(5, 5)])
	_check(L.turret_at(Vector2i(5, 4)) < 0 and L.act_hero < 0 and L.pos[_id(0, K.ARCHITECT)] == Vector2i(5, 4), "its own cell neither")
	# 건축가가 세운 벽의 주인, 포탑이 되면 네 벽 모두 포탑 주인의 벽
	L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [1, K.PRIEST, Vector2i(9, 0)]])
	var house := Vector2i(5, 4)
	for n in [Vector2i(4, 4), Vector2i(6, 4), Vector2i(5, 3)]:
		L._set_wall(house, n, 0)
	_act(L, _id(0, K.ARCHITECT), [Vector2i(5, 5), house])
	_check(L.turret_at(house) == 0 and L.wall_owner(house, Vector2i(5, 5)) == 0 and L.wall_owner(house, Vector2i(4, 4)) == 0,
		"walls belong to their builder; a turret's four walls belong to its owner")


func _test_magician() -> void:
	var L := _board([[0, K.MAGICIAN, Vector2i(5, 8)], [0, K.SOLDIER, Vector2i(2, 4)], [0, K.ROBOT, Vector2i(0, 5)],
		[1, K.SOLDIER, Vector2i(8, 8)], [1, K.PRIEST, Vector2i(5, 7)], [1, K.ANGEL, Vector2i(5, 6)], [1, K.KNIGHT, Vector2i(1, 8)]])
	_check(L.options_for(_id(0, K.MAGICIAN), K.MAGICIAN, ST.MOVE).is_empty(), "magician never moves")
	_check(L.can_act(_id(0, K.MAGICIAN)), "magician acts by its ability")
	L.begin_action(_id(0, K.MAGICIAN))
	var t := L.step_options()
	_check(t.get(Vector2i(2, 4)) == "swap" and t.get(Vector2i(0, 5)) == "swap", "swap with an ally anywhere, the robot too")
	_check(t.get(Vector2i(8, 8)) == "fire" and not t.has(Vector2i(1, 8)), "fireball reaches 3 cells, not 4")
	_check(t.get(Vector2i(5, 7)) == "fire" and not t.has(Vector2i(5, 6)), "no piercing: only the first enemy in a line")
	L.choose(Vector2i(5, 7))
	_check(not L.alive(_id(1, K.PRIEST)) and L.alive(_id(1, K.ANGEL)) and L.alive(_id(1, K.SOLDIER)) and L.act_hero < 0,
		"one enemy is hit")
	# 아군 · 로봇에 막힘, 유령은 안 막고 안 맞음
	L = _board([[0, K.MAGICIAN, Vector2i(5, 8)], [0, K.SOLDIER, Vector2i(6, 8)], [1, K.KNIGHT, Vector2i(7, 8)], [1, K.ROBOT, Vector2i(4, 8)], [1, K.ANGEL, Vector2i(3, 8)],
		[1, K.PRIEST, Vector2i(5, 7)], [1, K.SOLDIER, Vector2i(5, 6)]])
	L._kill(_id(1, K.PRIEST), "attack")
	t = L.options_for(_id(0, K.MAGICIAN), K.MAGICIAN, ST.SWAP_FIRE)
	_check(not t.has(Vector2i(7, 8)) and t.get(Vector2i(6, 8)) == "swap" and not t.has(Vector2i(3, 8)) and not t.has(Vector2i(4, 8)), "blocked by an ally or the robot")
	_check(t.get(Vector2i(5, 6)) == "fire" and not t.has(Vector2i(5, 7)), "a ghost neither blocks a fireball nor is hit by it")
	# 바꾸거나 쏘거나 하나만
	L = _board([[0, K.MAGICIAN, Vector2i(5, 8)], [0, K.SOLDIER, Vector2i(2, 4)], [1, K.KNIGHT, Vector2i(3, 4)]])
	_act(L, _id(0, K.MAGICIAN), [Vector2i(2, 4)])
	_check(L.pos[_id(0, K.MAGICIAN)] == Vector2i(2, 4) and L.pos[_id(0, K.SOLDIER)] == Vector2i(5, 8) and L.act_step == ST.SEAL and L.act_optional
		and L.step_options() == {Vector2i(3, 4): "seal"} and L.alive(_id(1, K.KNIGHT)), "swap OR fireball: after a swap it may only seal")
	_test_seal()
	# 성: 3칸까지, 사이에 영웅이 있으면 막힘
	L = _board([[0, K.MAGICIAN, Vector2i(2, 0)], [1, K.SOLDIER, Vector2i(9, 9)]])
	_act(L, _id(0, K.MAGICIAN), [Vector2i(5, 0)])
	_check(L.lives[1] == 2, "fireball hits the castle 3 cells away")
	L = _board([[0, K.MAGICIAN, Vector2i(3, 0)], [1, K.PRIEST, Vector2i(4, 0)], [1, K.SOLDIER, Vector2i(9, 9)]])
	_check(not L.options_for(_id(0, K.MAGICIAN), K.MAGICIAN, ST.SWAP_FIRE).has(Vector2i(5, 0)), "not the castle behind an enemy")
	_act(L, _id(0, K.MAGICIAN), [Vector2i(4, 0)])
	_check(L.lives[1] == 3 and not L.alive(_id(1, K.PRIEST)), "only the enemy in front is hit")
	# 바로 옆 적도 적군의 벽이 있으면 못 맞힘
	L = _board([[0, K.MAGICIAN, Vector2i(5, 8)], [1, K.SOLDIER, Vector2i(6, 8)], [1, K.PRIEST, Vector2i(9, 0)]])
	L._set_wall(Vector2i(5, 8), Vector2i(6, 8), 1)
	_check(L.options_for(_id(0, K.MAGICIAN), K.MAGICIAN, ST.SWAP_FIRE).is_empty() and not L.can_act(_id(0, K.MAGICIAN)), "an enemy right behind a wall isn't hit")
	# 아군 유령과 자리 바꾸기 (상대 유령은 X). 부활은 안 됨
	L = _board([[0, K.MAGICIAN, Vector2i(5, 8)], [0, K.KNIGHT, Vector2i(3, 4)], [0, K.SOLDIER, Vector2i(8, 4)], [0, K.ROBOT, Vector2i(9, 9)], [1, K.PRIEST, Vector2i(9, 5)], [1, K.ANGEL, Vector2i(0, 0)]])
	for id in [_id(0, K.KNIGHT), _id(0, K.SOLDIER), _id(1, K.PRIEST)]:
		L._kill(id, "attack")
	L.begin_action(_id(0, K.MAGICIAN))
	t = L.step_options()
	_check(t.get(Vector2i(3, 4)) == "warp" and t.get(Vector2i(8, 4)) == "warp" and not t.has(Vector2i(9, 5)), "my ghosts anywhere, not enemy ghosts")
	L.choose(Vector2i(3, 4))
	_check(L.pos[_id(0, K.MAGICIAN)] == Vector2i(3, 4) and L.ghost_pos[_id(0, K.KNIGHT)] == Vector2i(5, 8) and L.ghost_at(Vector2i(5, 8)) == _id(0, K.KNIGHT) and L.ghost_at(Vector2i(3, 4)) < 0
		and L.act_hero < 0, "magician and ghost swap places")


func _test_priest_barrier() -> void:
	# 가로 · 세로 1칸 (제자리도 됨)
	var M := _board([[0, K.PRIEST, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(6, 5)], [1, K.SOLDIER, Vector2i(0, 0)]])
	var mt := M.options_for(_id(0, K.PRIEST), K.PRIEST, ST.MOVE)
	_check(mt.size() == 4 and mt.has(Vector2i(5, 4)) and mt.has(Vector2i(4, 5)) and mt.has(Vector2i(5, 6)) and mt.get(Vector2i(5, 5)) == "stay",
		"priest moves 1 cell orthogonally (or stays), only onto free cells")
	var L := _board([[0, K.PRIEST, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(6, 4)], [0, K.ROBOT, Vector2i(4, 4)],
		[0, K.REAPER, Vector2i(5, 3)], [0, K.ANGEL, Vector2i(4, 3)], [1, K.KNIGHT, Vector2i(6, 1)],
		[1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 4)])
	var t := L.step_options()
	_check(t.get(Vector2i(6, 4)) == "barrier" and t.get(Vector2i(5, 3)) == "barrier" and t.get(Vector2i(5, 4)) == "barrier"
		and not t.has(Vector2i(4, 3)) and t.get(Vector2i(4, 4)) == "barrier", "barrier: an ally in the 4 cells (the reaper and the robot too) or itself; not diagonal")
	L.choose(Vector2i(6, 4))
	_check(L.barrier[_id(0, K.SOLDIER)] == 1, "barrier given")
	L.end_turn()
	# 공격받으면 배리어만 깨지고 제자리 (밀리지 않음)
	_act(L, _id(1, K.KNIGHT), [Vector2i(6, 3), Vector2i(6, 4)])
	_check(L.alive(_id(0, K.SOLDIER)) and L.pos[_id(0, K.SOLDIER)] == Vector2i(6, 4) and L.barrier[_id(0, K.SOLDIER)] == 0,
		"barrier breaks, hero stays put")
	# 대각선 · 두 칸 떨어진 아군 · 적에게는 안 됨. 로봇은 됨. 벽은 상관없음
	L = _board([[0, K.PRIEST, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(6, 5)], [0, K.ANGEL, Vector2i(7, 5)], [0, K.ROBOT, Vector2i(5, 6)], [0, K.NINJA, Vector2i(4, 6)], [1, K.SOLDIER, Vector2i(4, 5)], [1, K.KNIGHT, Vector2i(0, 0)]])
	for d in HeroLogic.DIRS4:
		L._set_wall(Vector2i(5, 5), Vector2i(5, 5) + d, 1)
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 5)])
	t = L.step_options()
	_check(t.get(Vector2i(6, 5)) == "barrier" and not t.has(Vector2i(7, 5)) and t.get(Vector2i(5, 6)) == "barrier" and not t.has(Vector2i(4, 6)) and t.get(Vector2i(4, 5)) != "barrier", "4 cells only, walls don't matter")
	# 깨질 때까지 유지 (차례가 지나도)
	L = _board([[0, K.PRIEST, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(6, 5)], [0, K.ANGEL, Vector2i(5, 6)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 5), Vector2i(6, 5)])
	L.end_turn()
	for n in 6:
		L.pass_turn()
	_check(L.barrier[_id(0, K.SOLDIER)] == 1, "it stays until it breaks")
	if L.current == 1:
		L.pass_turn()
	# 다른 영웅에게 주면 있던 배리어는 사라짐 (한 편에 하나), 이미 있는 영웅에겐 또 못 줌, 상대 배리어는 그대로
	L.barrier[_id(1, K.SOLDIER)] = 1
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 5)])
	_check(not L.step_options().has(Vector2i(6, 5)) and L.step_options().get(Vector2i(5, 6)) == "barrier", "no second barrier on the same hero")
	L.choose(Vector2i(5, 6))
	_check(L.barrier[_id(0, K.ANGEL)] == 1 and L.barrier[_id(0, K.SOLDIER)] == 0 and L.barrier[_id(1, K.SOLDIER)] == 1, "giving it to another hero destroys the old one, not the enemy's")
	L.end_turn()
	L.pass_turn()
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 5), Vector2i(5, 5)])
	_check(L.barrier[_id(0, K.PRIEST)] == 1 and L.barrier[_id(0, K.ANGEL)] == 0, "itself too")
	# 성직자를 따라 한 닌자도 같은 배리어를 옮김
	L = _board([[0, K.NINJA, Vector2i(3, 8)], [0, K.PRIEST, Vector2i(3, 5)], [0, K.SOLDIER, Vector2i(4, 8)], [0, K.ANGEL, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.barrier[_id(0, K.ANGEL)] = 1
	_act(L, _id(0, K.NINJA), [Vector2i(3, 5), Vector2i(3, 8), Vector2i(4, 8)])
	_check(L.barrier[_id(0, K.SOLDIER)] == 1 and L.barrier[_id(0, K.ANGEL)] == 0, "one barrier per side, a ninja in priest form moves it")
	# 배리어는 저주를 풀어 줌
	L = _board([[0, K.PRIEST, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(6, 5)], [1, K.REAPER, Vector2i(0, 0)]])
	L.cursed_by[_id(0, K.SOLDIER)] = _id(1, K.REAPER)
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 5), Vector2i(6, 5)])
	_check(L.cursed_by[_id(0, K.SOLDIER)] < 0 and L.barrier[_id(0, K.SOLDIER)] != 0, "a barrier lifts the curse")
	_test_cross()


func _test_cross() -> void:
	# 십자가: 상하좌우 바로 옆 칸의 적 하나 (대각선 · 2칸 X)
	var set_up := [[0, K.PRIEST, Vector2i(5, 6)], [0, K.SOLDIER, Vector2i(5, 8)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(5, 3)], [1, K.ANGEL, Vector2i(7, 5)],
		[1, K.MAGICIAN, Vector2i(4, 5)], [1, K.WARRIOR, Vector2i(8, 8)], [1, K.ARCHITECT, Vector2i(6, 6)]]
	var L := _board(set_up)
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 5)])
	var t := L.step_options()
	_check(t.get(Vector2i(5, 4)) == "attack" and t.get(Vector2i(4, 5)) == "attack" and not t.has(Vector2i(5, 3)) and not t.has(Vector2i(7, 5)) and not t.has(Vector2i(6, 6)),
		"cross: the enemies right next to it only")
	_check(t.get(Vector2i(5, 5)) == "barrier", "or a barrier")
	L.choose(Vector2i(4, 5))
	_check(not L.alive(_id(1, K.MAGICIAN)) and L.alive(_id(1, K.KNIGHT)) and L.act_hero < 0 and L.pos[_id(0, K.PRIEST)] == Vector2i(5, 5), "one enemy falls, the priest stays")
	# 사신도 맞음(공격이라), 배리어가 막음
	L = _board([[0, K.PRIEST, Vector2i(5, 5)], [1, K.REAPER, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.barrier[_id(1, K.REAPER)] = 1
	var bare := L.clone()
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 5), Vector2i(5, 4)])
	_check(L.alive(_id(1, K.REAPER)) and L.barrier[_id(1, K.REAPER)] == 0, "a barrier blocks the cross")
	bare.barrier[_id(1, K.REAPER)] = 0
	_act(bare, _id(0, K.PRIEST), [Vector2i(5, 5), Vector2i(5, 4)])
	_check(not bare.alive(_id(1, K.REAPER)), "the reaper isn't safe from it (it's an attack)")
	# 로봇은 안 맞고, 내 벽은 넘고 적군의 벽에는 막힘
	L = _board([[0, K.PRIEST, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(5, 4)], [1, K.ROBOT, Vector2i(4, 5)], [1, K.SOLDIER, Vector2i(6, 5)], [1, K.MAGICIAN, Vector2i(5, 6)]])
	L._set_wall(Vector2i(5, 5), Vector2i(6, 5), 1)
	L._set_wall(Vector2i(5, 5), Vector2i(5, 6), 0)
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 5)])
	t = L.step_options()
	_check(t.get(Vector2i(5, 4)) == "barrier" and not t.has(Vector2i(4, 5)), "an ally gets the barrier, the robot can't be hit")
	_check(not t.has(Vector2i(6, 5)) and t.get(Vector2i(5, 6)) == "attack" and not t.values().has("break"), "over my wall, not an enemy's")
	# 유령: 적 유령은 맞아 사라짐(적군의 벽 너머는 X). 아군 유령 · 대각선 · 2칸의 유령은 X
	L = _board([[0, K.PRIEST, Vector2i(5, 5)], [0, K.KNIGHT, Vector2i(6, 5)], [0, K.ANGEL, Vector2i(0, 10)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(5, 3)],
		[1, K.PRIEST, Vector2i(4, 4)], [1, K.MAGICIAN, Vector2i(4, 5)], [1, K.NINJA, Vector2i(5, 6)], [1, K.ARCHITECT, Vector2i(9, 0)]])
	for id in [_id(1, K.KNIGHT), _id(1, K.SOLDIER), _id(0, K.KNIGHT), _id(1, K.PRIEST), _id(1, K.MAGICIAN), _id(1, K.NINJA)]:
		L._kill(id, "attack")
	L._set_wall(Vector2i(5, 5), Vector2i(5, 6), 1)
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 5)])
	t = L.step_options()
	_check(t.get(Vector2i(5, 4)) == "exorcise" and t.get(Vector2i(4, 5)) == "exorcise" and not t.has(Vector2i(5, 3)) and not t.has(Vector2i(6, 5)) and not t.has(Vector2i(4, 4))
		and not t.has(Vector2i(5, 6)), "enemy ghosts right next to it (not over an enemy wall), not mine, not diagonal")
	L.choose(Vector2i(4, 5))
	_check(not L.has_ghost(_id(1, K.MAGICIAN)) and L.has_ghost(_id(1, K.KNIGHT)) and L.act_hero < 0, "the ghost is gone for good")
	# 유령 칸으로는 이동 못 함
	L = _board([[0, K.PRIEST, Vector2i(5, 5)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(_id(1, K.KNIGHT), "attack")
	_check(not L.options_for(_id(0, K.PRIEST), K.PRIEST, ST.MOVE).has(Vector2i(5, 4)), "the priest can't step onto a ghost")
	L._set_wall(Vector2i(5, 5), Vector2i(5, 4), 0)
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 5)])
	t = L.step_options()
	_check(t.get(Vector2i(5, 4)) == "exorcise" and not t.has(Vector2i(5, 4) + HeroLogic.SIDE), "a ghost over my wall")
	L.choose(Vector2i(5, 4))
	_check(not L.has_ghost(_id(1, K.KNIGHT)) and L.wall_count() == 1, "the ghost is hit over the wall")
	# 성: 바로 옆만, 닌자가 따라 해도 같음
	L = _board([[0, K.PRIEST, Vector2i(5, 3)], [1, K.SOLDIER, Vector2i(9, 9)]])
	var far := L.options_for(_id(0, K.PRIEST), K.PRIEST, ST.BARRIER)
	_check(not far.has(Vector2i(5, 0)), "the castle 2 or 3 cells away isn't reached")
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 2)])
	_check(not L.step_options().has(Vector2i(5, 0)), "2 cells away neither")
	L = _board([[0, K.PRIEST, Vector2i(5, 2)], [1, K.SOLDIER, Vector2i(9, 9)]])
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 1), Vector2i(5, 0)])
	_check(L.lives[1] == 2 and L.act_hero < 0, "right next to it, it is")
	L = _board([[0, K.NINJA, Vector2i(5, 5)], [0, K.PRIEST, Vector2i(5, 9)], [1, K.SOLDIER, Vector2i(6, 4)]])
	_act(L, _id(0, K.NINJA), [Vector2i(5, 9), Vector2i(6, 5), Vector2i(6, 4)])
	_check(not L.alive(_id(1, K.SOLDIER)) and L.pos[_id(0, K.NINJA)] == Vector2i(6, 5), "a ninja in priest form: 1 step and a cross")


func _test_robot() -> void:
	var L := _board([[0, K.ROBOT, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(9, 7)], [1, K.KNIGHT, Vector2i(4, 3)],
		[1, K.SOLDIER, Vector2i(5, 1)], [1, K.WARRIOR, Vector2i(7, 7)], [1, K.MAGICIAN, Vector2i(9, 8)]])
	var t := L.options_for(_id(0, K.ROBOT), K.ROBOT, ST.MOVE)
	_check(t.has(Vector2i(5, 2)) and t.has(Vector2i(5, 9)) and t.has(Vector2i(0, 5)) and not t.has(Vector2i(5, 1)), "robot slides along lines")
	# 누구의 공격 대상도 아님
	L.current = 1
	_act(L, _id(1, K.KNIGHT), [Vector2i(5, 3)])
	_check(not L.step_options().has(Vector2i(6, 3)) and L.act_hero < 0, "nothing to hit")
	# 밀기: 움직인 방향의 다음 칸에 있는 적을 한 칸 뒤로
	L = _board([[0, K.ROBOT, Vector2i(5, 6)], [1, K.SOLDIER, Vector2i(5, 4)], [1, K.WARRIOR, Vector2i(7, 5)],
		[1, K.PRIEST, Vector2i(8, 5)], [1, K.ANGEL, Vector2i(4, 4)]])
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5)])
	t = L.step_options()
	_check(L.act_step == ST.PUSH and t.has(Vector2i(5, 4)) and not t.has(Vector2i(4, 4)), "push step: pick a hero next to the robot")
	L.mines[L._i(Vector2i(5, 3))] = 1
	L.choose(Vector2i(5, 4))
	_check(not L.alive(_id(1, K.SOLDIER)) and L.ghost_pos[_id(1, K.SOLDIER)] == Vector2i(5, 3), "pushed onto my mine → hurt")
	# 옆에 있는 적은 못 밂 (움직인 방향만). 전사의 무력은 로봇에게 안 통함
	for from in [[Vector2i(5, 8), Vector2i(5, 4)], [Vector2i(5, 2), Vector2i(5, 6)], [Vector2i(2, 5), Vector2i(6, 5)], [Vector2i(8, 5), Vector2i(4, 5)]]:
		L = _board([[0, K.ROBOT, from[0]], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.SOLDIER, Vector2i(5, 4)], [1, K.WARRIOR, Vector2i(6, 5)], [1, K.PRIEST, Vector2i(5, 6)], [1, K.ANGEL, Vector2i(4, 5)]])
		for id in L.heroes_of(1):
			if HeroLogic.manh(L.pos[id], from[0]) == 1 or L.pos[id] == Vector2i(5, 5) * 2 - from[1]:
				L._relocate(id, Vector2i(10, 0))   # 로봇이 지나올 쪽은 비움
		L._update_disabled()
		_act(L, _id(0, K.ROBOT), [Vector2i(5, 5)])
		t = L.step_options()
		_check(t == {from[1]: "push"}, "only the enemy ahead can be pushed (%s)" % str(from[1]))
		L.choose(from[1])
		var d: Vector2i = from[1] - Vector2i(5, 5)
		_check(L.at(from[1]) < 0 and L.at(from[1] + d) >= 0 and L.act_hero < 0, "pushed one cell on (%s)" % str(from[1]))
	# 제자리에 있으면 못 밂 (벽 부수기는 됨)
	L = _board([[0, K.ROBOT, Vector2i(5, 5)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.SOLDIER, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(6, 5)]])
	L._set_wall(Vector2i(5, 5), Vector2i(4, 5), 1)
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5)])
	_check(L.step_options() == {Vector2i(4, 5): "break"}, "staying in place it can't push, but can break a wall")
	L = _board([[0, K.ROBOT, Vector2i(5, 5)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.SOLDIER, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(6, 5)]])
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5)])
	_check(L.act_hero < 0, "nothing to do in place")
	# 바로 옆 칸이 아니면 못 밂
	L = _board([[0, K.ROBOT, Vector2i(5, 8)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.SOLDIER, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(9, 0)]])
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 6)])
	_check(L.step_options() == {Vector2i(5, 4): "pull"}, "only the very next cell can be pushed (one cell apart it can be pulled)")
	_test_pull()
	# 자기 칸의 지뢰는 누구 것이든 없앰
	for owner in 2:
		L = _board([[0, K.ROBOT, Vector2i(5, 6)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
		L.mines[L._i(Vector2i(5, 3))] = owner + 1
		_act(L, _id(0, K.ROBOT), [Vector2i(5, 3)])
		_check(L.alive(_id(0, K.ROBOT)) and L.mine_at(Vector2i(5, 3)) < 0, "the robot clears a mine on its cell (owner %d)" % owner)
	_test_stun()


## 끌어당기기: 상하좌우로 한 칸 띄워진 적 · 아군을 자기 쪽으로 한 칸 (제자리도 됨, 스턴 X)
func _test_pull() -> void:
	var rb := _id(0, K.ROBOT)
	for side in 2:
		for d: Vector2i in HeroLogic.DIRS4:
			for moved in [false, true]:
				var c := Vector2i(5, 5)
				var B := _board([[0, K.ROBOT, c], [0, K.MAGICIAN, Vector2i(0, 9)], [side, K.KNIGHT, c + d * 2], [1, K.PRIEST, Vector2i(0, 0)]])
				if moved:   # 옆에서 미끄러져 와도 됨
					B._relocate(rb, c + Vector2i(d.y, d.x) * 2)
				_act(B, rb, [c])
				var t := B.step_options()
				_check(t == {c + d * 2: "pull"}, "a hero one cell apart can be pulled (side %d, %s, moved %s)" % [side, d, moved])
				var ev := B.choose(c + d * 2)
				_check(B.pos[_id(side, K.KNIGHT)] == c + d and B.at(c + d * 2) < 0 and B.stunned[_id(side, K.KNIGHT)] == 0 and B.act_hero < 0 and ev[0]["t"] == "pull",
					"it comes one cell closer, not stunned")
	# 붙어 있거나 두 칸 띄워지면 안 됨, 대각선도 안 됨
	var L := _board([[0, K.ROBOT, Vector2i(5, 5)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(8, 5)], [1, K.PRIEST, Vector2i(6, 6)], [1, K.WARRIOR, Vector2i(3, 3)]])
	_act(L, rb, [Vector2i(5, 5)])
	_check(L.act_hero < 0, "not next to it, not two cells apart, not diagonally")
	# 사이 칸이 빈칸이 아니면(영웅 · 유령 · 십자가 · 포탑) 안 됨
	for what in ["hero", "ghost", "cross", "turret"]:
		L = _board([[0, K.ROBOT, Vector2i(5, 5)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.KNIGHT, Vector2i(5, 3)], [1, K.SOLDIER, Vector2i(5, 4)], [1, K.ANGEL, Vector2i(9, 0)]])
		match what:
			"ghost":
				L._kill(_id(1, K.SOLDIER), "attack")
			"cross":
				L._relocate(_id(1, K.SOLDIER), Vector2i(0, 0))
				L._relocate(_id(1, K.ANGEL), Vector2i(5, 4))
				L._kill(_id(1, K.ANGEL), "attack")
			"turret":
				L._relocate(_id(1, K.SOLDIER), Vector2i(0, 0))
				L.turret[L._i(Vector2i(5, 4))] = 1
		_check(L.pull_moves(rb).is_empty(), "the cell between must be free (%s)" % what)
	# 끌려오는 길의 벽은 막고, 사이 칸과 로봇 사이의 벽은 상관없음 (그 벽은 부술 수도 있음)
	for owner in 2:
		L = _board([[0, K.ROBOT, Vector2i(5, 5)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.KNIGHT, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(0, 0)]])
		L._set_wall(Vector2i(5, 3), Vector2i(5, 4), owner)
		_check(L.pull_moves(rb).is_empty(), "a wall in its way stops it (owner %d)" % owner)
		L = _board([[0, K.ROBOT, Vector2i(5, 5)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.KNIGHT, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(0, 0)]])
		L._set_wall(Vector2i(5, 5), Vector2i(5, 4), owner)
		_act(L, rb, [Vector2i(5, 5)])
		_check(L.step_options() == {Vector2i(5, 3): "pull", Vector2i(5, 4): "break"}, "a wall by the robot doesn't (owner %d), and can be broken instead" % owner)
	# 지뢰 · 사신 · 포탑 · 무력은 밀기와 같음. 배리어는 상관없음. 적 로봇도 끌림
	L = _board([[0, K.ROBOT, Vector2i(5, 5)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.SOLDIER, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(0, 0)]])
	L.mines[L._i(Vector2i(5, 4))] = 1
	_act(L, rb, [Vector2i(5, 5), Vector2i(5, 3)])
	_check(not L.alive(_id(1, K.SOLDIER)) and L.ghost_pos[_id(1, K.SOLDIER)] == Vector2i(5, 4), "pulled onto my mine")
	L = _board([[0, K.ROBOT, Vector2i(5, 5)], [0, K.REAPER, Vector2i(6, 5)], [1, K.SOLDIER, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(0, 0)]])
	_act(L, rb, [Vector2i(5, 5), Vector2i(5, 3)])
	_check(not L.alive(_id(1, K.SOLDIER)), "pulled onto my reaper's diagonal")
	L = _board([[0, K.ROBOT, Vector2i(5, 5)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.SOLDIER, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(0, 0)]])
	L.barrier[_id(1, K.SOLDIER)] = 1
	L.turret[L._i(Vector2i(6, 5))] = 1
	_act(L, rb, [Vector2i(5, 5), Vector2i(5, 3)])
	_check(not L.alive(_id(1, K.SOLDIER)), "pulled next to my turret, barrier or not")
	L = _board([[0, K.ROBOT, Vector2i(5, 5)], [0, K.KNIGHT, Vector2i(5, 3)], [1, K.WARRIOR, Vector2i(5, 2)], [1, K.PRIEST, Vector2i(0, 0)]])
	_check(L.disabled_by[_id(0, K.KNIGHT)] == _id(1, K.WARRIOR), "disabled first")
	_act(L, rb, [Vector2i(5, 5), Vector2i(5, 3)])
	_check(L.pos[_id(0, K.KNIGHT)] == Vector2i(5, 4) and L.disabled_by[_id(0, K.KNIGHT)] < 0 and L.selectable().has(_id(0, K.KNIGHT)), "an ally pulled out of the warrior's 8 cells is free and can act")
	L = _board([[0, K.ROBOT, Vector2i(5, 5)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.ROBOT, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(0, 0)]])
	_act(L, rb, [Vector2i(5, 5), Vector2i(5, 3)])
	_check(L.pos[_id(1, K.ROBOT)] == Vector2i(5, 4), "an enemy robot can be pulled")
	# 밀기와 끌기 중 하나만. 로봇을 따라 한 닌자도 됨
	L = _board([[0, K.ROBOT, Vector2i(5, 8)], [0, K.MAGICIAN, Vector2i(0, 9)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(7, 5)], [0, K.PRIEST, Vector2i(3, 5)]])
	_act(L, rb, [Vector2i(5, 5)])
	_check(L.step_options() == {Vector2i(5, 4): "push", Vector2i(7, 5): "pull", Vector2i(3, 5): "pull"}, "push, or pull an enemy or an ally")
	L.choose(Vector2i(3, 5))
	_check(L.pos[_id(0, K.PRIEST)] == Vector2i(4, 5) and L.pos[_id(1, K.KNIGHT)] == Vector2i(5, 4) and L.act_hero < 0, "only one of them")
	L = _board([[0, K.NINJA, Vector2i(5, 8)], [0, K.ROBOT, Vector2i(5, 10)], [1, K.SOLDIER, Vector2i(7, 5)], [1, K.PRIEST, Vector2i(0, 0)]])
	_act(L, _id(0, K.NINJA), [Vector2i(5, 10), Vector2i(5, 5), Vector2i(7, 5)])
	_check(L.pos[_id(1, K.SOLDIER)] == Vector2i(6, 5), "a ninja in robot form pulls too")


## 스턴: 로봇이 민 적(자리가 없어 안 밀려도)은 그 편의 다음 차례에 이동도 능력도 못 씀 (아군은 못 밂, 패시브는 그대로)
func _test_stun() -> void:
	var L := _board([[0, K.ROBOT, Vector2i(5, 6)], [0, K.PRIEST, Vector2i(4, 5)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(5, 3)]])
	var kn := _id(1, K.KNIGHT)
	var ev := _act(L, _id(0, K.ROBOT), [Vector2i(5, 5), Vector2i(5, 4)])
	var told := false
	for e in ev:
		told = told or (e["t"] == "stun" and int(e["id"]) == kn)
	_check(told and L.pos[kn] == Vector2i(5, 4) and L.stunned[kn] == 1, "an enemy with no room is stunned")
	var C := L.clone()
	_check(C.stunned[kn] == 1 and C.state_hash() == L.state_hash(), "kept in copies and the state hash")
	C.stunned[kn] = 0
	_check(C.state_hash() != L.state_hash(), "part of the state")
	L.end_turn()
	_check(not L.selectable().has(kn) and not L.can_act(kn) and L.selectable().has(_id(1, K.SOLDIER)), "it can't act on its next turn, others can")
	_check(L.summon_ids().has(kn), "the castle can still call it")
	L.pass_turn()
	_check(L.stunned[kn] == 0, "gone when that turn is over")
	L.pass_turn()
	_check(L.selectable().has(kn), "then it acts again")
	# 아군은 못 밂, 자리가 있는 적은 밀리면서 스턴
	L = _board([[0, K.ROBOT, Vector2i(8, 5)], [0, K.PRIEST, Vector2i(4, 5)], [0, K.SOLDIER, Vector2i(5, 6)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5)])
	_check(L.act_hero < 0 and L.pos[_id(0, K.PRIEST)] == Vector2i(4, 5), "an ally can't be pushed")
	L = _board([[0, K.ROBOT, Vector2i(5, 8)], [0, K.PRIEST, Vector2i(4, 5)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5)])
	_check(L.step_options() == {Vector2i(5, 4): "push"}, "only the enemy")
	L.choose(Vector2i(5, 4))
	_check(L.pos[kn] == Vector2i(5, 3) and L.stunned[kn] == 1 and L.act_hero < 0, "pushed and stunned")
	L.end_turn()
	_check(not L.selectable().has(kn), "it can't act on its next turn")
	L.pass_turn()
	_check(L.stunned[kn] == 0, "gone when that turn is over")
	# 이미 스턴된 적도 자리가 있으면 또 밀 수 있음
	L = _board([[0, K.ROBOT, Vector2i(5, 8)], [0, K.PRIEST, Vector2i(4, 5)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.stunned[kn] = 1
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5), Vector2i(5, 4)])
	_check(L.pos[kn] == Vector2i(5, 3) and L.stunned[kn] == 1, "a stunned enemy with room can be pushed again")
	# 자리가 없으면(영웅 · 벽 · 판 끝 · 성 · 유령 · 포탑) 밀리지 않지만 스턴은 걸림. 아군은 못 고름
	for what in ["hero", "wall", "edge", "castle", "ghost", "turret"]:
		L = _board([[0, K.ROBOT, Vector2i(5, 6)], [0, K.ANGEL, Vector2i(9, 9)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(10, 3)], [1, K.PRIEST, Vector2i(0, 0)]])
		var at_k := Vector2i(5, 4)
		match what:
			"hero":
				L._relocate(_id(1, K.SOLDIER), Vector2i(5, 3))
			"wall":
				L._set_wall(Vector2i(5, 4), Vector2i(5, 3), 0)
			"edge":
				at_k = Vector2i(3, 0)
			"castle":
				at_k = Vector2i(5, 1)
			"ghost":
				L._relocate(_id(1, K.SOLDIER), Vector2i(5, 3))
				L._kill(_id(1, K.SOLDIER), "attack")
			"turret":
				L.turret[L._i(Vector2i(5, 3))] = 2
		L._relocate(kn, at_k)
		L._relocate(_id(0, K.ROBOT), at_k + Vector2i(0, 3))
		_act(L, _id(0, K.ROBOT), [at_k + Vector2i(0, 1)])
		_check(L.step_options().get(at_k) == "push", "an enemy with no room can be picked (%s)" % what)
		L.choose(at_k)
		_check(L.pos[kn] == at_k and L.stunned[kn] == 1 and L.act_hero < 0, "it stays and is stunned (%s)" % what)
	L = _board([[0, K.ROBOT, Vector2i(5, 7)], [0, K.KNIGHT, Vector2i(5, 4)], [0, K.SOLDIER, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(0, 0)]])
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5)])
	_check(L.act_hero < 0, "an ally with no room can't either")
	L = _board([[0, K.ROBOT, Vector2i(5, 7)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(0, 0)]])
	L.stunned[kn] = 1
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5)])
	_check(L.act_hero < 0, "nothing to do to a stunned enemy with no room")
	# 밀려서 쓰러지면 스턴도 없음, 적 로봇도 밀리거나 스턴됨, 로봇 모습 닌자도 같음
	L = _board([[0, K.ROBOT, Vector2i(5, 7)], [1, K.SOLDIER, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(0, 0)]])
	L.mines[L._i(Vector2i(5, 3))] = 1
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5), Vector2i(5, 4)])
	_check(not L.alive(_id(1, K.SOLDIER)) and L.stunned[_id(1, K.SOLDIER)] == 0, "pushed onto a mine: it falls, no stun")
	L = _board([[0, K.ROBOT, Vector2i(5, 7)], [1, K.ROBOT, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(0, 0)]])
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5), Vector2i(5, 4)])
	_check(L.pos[_id(1, K.ROBOT)] == Vector2i(5, 3) and L.stunned[_id(1, K.ROBOT)] == 1, "a robot can be pushed and stunned")
	L = _board([[0, K.ROBOT, Vector2i(5, 7)], [1, K.ROBOT, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(5, 3)]])
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5), Vector2i(5, 4)])
	_check(L.pos[_id(1, K.ROBOT)] == Vector2i(5, 4) and L.stunned[_id(1, K.ROBOT)] == 1, "or stunned")
	L = _board([[0, K.NINJA, Vector2i(5, 8)], [0, K.ROBOT, Vector2i(5, 9)], [1, K.SOLDIER, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(5, 3)]])
	_act(L, _id(0, K.NINJA), [Vector2i(5, 9), Vector2i(5, 5), Vector2i(5, 4)])
	_check(L.stunned[_id(1, K.SOLDIER)] == 1, "a ninja in robot form stuns too")
	# 무력 · 스턴된 사신도 자동 공격은 함
	for how in ["stun", "disable"]:
		L = _board([[1, K.REAPER, Vector2i(5, 5)], [1, K.PRIEST, Vector2i(0, 0)], [0, K.WARRIOR, Vector2i(5, 6) if how == "disable" else Vector2i(9, 9)], [0, K.SOLDIER, Vector2i(6, 8)]])
		if how == "stun":
			L.stunned[_id(1, K.REAPER)] = 1
		_check(L.disabled_by[_id(1, K.REAPER)] >= 0 or how == "stun", "the reaper is disabled")
		_act(L, _id(0, K.SOLDIER), [Vector2i(6, 6)])
		_check(not L.alive(_id(0, K.SOLDIER)), "a reaper under %s still cuts its diagonals" % how)
	# AI 는 스턴된 영웅을 쓰지 않고도 계획을 세움
	L = _board([[0, K.ROBOT, Vector2i(5, 7)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(2, 0)]])
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5), Vector2i(5, 4)])
	L.end_turn()
	for lv in 3:
		for st in HeroAI.new(lv).plan(L):
			_check(not (st as Dictionary).has("taps") or (st as Dictionary)["taps"][0] != kn, "AI level %d doesn't use a stunned hero" % lv)


func _test_warrior() -> void:
	var L := _board([[0, K.WARRIOR, Vector2i(5, 8)], [1, K.SOLDIER, Vector2i(5, 6)], [1, K.KNIGHT, Vector2i(4, 6)],
		[1, K.PRIEST, Vector2i(9, 0)]])
	var t := L.options_for(_id(0, K.WARRIOR), K.WARRIOR, ST.MOVE)
	_check(t.size() == 5 and t.has(Vector2i(5, 7)) and t.has(Vector2i(4, 8)) and t.has(Vector2i(5, 9))
		and t.get(Vector2i(5, 8)) == "stay", "warrior moves 1 orthogonally, or stays")
	_act(L, _id(0, K.WARRIOR), [Vector2i(5, 7)])
	_check(L.disabled_by[_id(1, K.SOLDIER)] == _id(0, K.WARRIOR) and L.disabled_by[_id(1, K.KNIGHT)] == _id(0, K.WARRIOR) and L.disabled_by[_id(1, K.PRIEST)] < 0,
		"passive: enemies in the 8 cells are disabled as soon as it stops there")
	t = L.step_options()
	_check(L.act_optional and t.get(Vector2i(5, 6)) == "attack" and t.size() == 1, "then attack one orthogonal enemy (the front is blocked, no advance)")
	L.choose(Vector2i(5, 6))
	_check(not L.alive(_id(1, K.SOLDIER)) and L.pos[_id(0, K.WARRIOR)] == Vector2i(5, 7) and L.act_hero < 0, "attack one")
	L.end_turn()
	_check(not L.can_act(_id(1, K.KNIGHT)), "a disabled hero can't act")
	L.pass_turn()
	L.pass_turn()
	_check(L.current == 1 and not L.can_act(_id(1, K.KNIGHT)), "as long as it stays in the 8 cells")
	# 1칸 전진은 앞(적진 쪽)으로만
	L = _board([[0, K.WARRIOR, Vector2i(5, 8)], [1, K.SOLDIER, Vector2i(4, 8)], [1, K.KNIGHT, Vector2i(6, 5)], [1, K.PRIEST, Vector2i(9, 0)]])
	_act(L, _id(0, K.WARRIOR), [Vector2i(5, 7)])
	t = L.step_options()
	_check(t.get(Vector2i(5, 6)) == "advance" and t.size() == 1, "advance one cell forward only")
	_check(L.disabled_by[_id(1, K.SOLDIER)] == _id(0, K.WARRIOR), "diagonal enemies are disabled too")
	L.choose(Vector2i(5, 6))
	_check(L.pos[_id(0, K.WARRIOR)] == Vector2i(5, 6) and L.disabled_by[_id(1, K.KNIGHT)] == _id(0, K.WARRIOR) and L.disabled_by[_id(1, K.SOLDIER)] < 0,
		"advanced; the passive follows it")
	L = _board([[0, K.WARRIOR, Vector2i(5, 8)], [1, K.SOLDIER, Vector2i(4, 5)], [1, K.PRIEST, Vector2i(9, 0)]])
	L._set_wall(Vector2i(5, 7), Vector2i(5, 6), 0)
	_act(L, _id(0, K.WARRIOR), [Vector2i(5, 7)])
	_check(L.act_hero < 0, "a wall blocks the advance, and it can't be broken")
	# 이동해서 8칸에 멈추면 바로 무력 → 그 이동의 능력도 못 씀. 벗어나면 다시 쓸 수 있음
	L = _board([[0, K.SOLDIER, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.WARRIOR, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(9, 0)]])
	_act(L, _id(0, K.SOLDIER), [Vector2i(5, 5)])
	_check(L.act_hero < 0 and L.used == 1 and L.alive(_id(1, K.WARRIOR)) and L.disabled_by[_id(0, K.SOLDIER)] == _id(1, K.WARRIOR),
		"stopping beside an enemy warrior ends the action at once (no attack)")
	L.end_turn()
	L.pass_turn()
	_check(not L.can_act(_id(0, K.SOLDIER)), "and it stays stuck")
	L = _board([[0, K.KNIGHT, Vector2i(5, 8)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.WARRIOR, Vector2i(5, 5)], [1, K.PRIEST, Vector2i(9, 0)]])
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 6)])
	_check(L.act_hero < 0 and L.alive(_id(1, K.WARRIOR)), "the knight can't strike it either after stopping there")
	# 떨어져서 치는 능력은 됨: 파이어볼(3칸). 십자가는 옆에 서야 해서 무력해짐
	L = _board([[0, K.MAGICIAN, Vector2i(5, 7)], [0, K.SOLDIER, Vector2i(6, 6)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.WARRIOR, Vector2i(5, 5)], [1, K.PRIEST, Vector2i(9, 0)]])
	_check(not L.can_act(_id(0, K.SOLDIER)), "the soldier next to it is disabled")
	_act(L, _id(0, K.MAGICIAN), [Vector2i(5, 5)])
	_check(not L.alive(_id(1, K.WARRIOR)) and L.disabled_by[_id(0, K.SOLDIER)] < 0 and L.can_act(_id(0, K.SOLDIER)), "the warrior falls → free at once")
	L = _board([[0, K.PRIEST, Vector2i(5, 8)], [0, K.SOLDIER, Vector2i(6, 6)], [1, K.WARRIOR, Vector2i(5, 5)], [1, K.PRIEST, Vector2i(9, 0)]])
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 7), STOP])
	_check(L.alive(_id(1, K.WARRIOR)) and L.act_hero < 0, "the priest's cross doesn't reach 2 cells")
	# 자리 바꾸기로 들어가도 · 빠져나와도 바로
	L = _board([[0, K.MAGICIAN, Vector2i(2, 8)], [0, K.SOLDIER, Vector2i(5, 5)], [1, K.WARRIOR, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(9, 0)]])
	_act(L, _id(0, K.MAGICIAN), [Vector2i(5, 5)])
	_check(L.disabled_by[_id(0, K.MAGICIAN)] == _id(1, K.WARRIOR) and L.disabled_by[_id(0, K.SOLDIER)] < 0 and L.can_act(_id(0, K.SOLDIER)),
		"swapping moves one in (disabled) and one out (free)")
	# 로봇이 적 전사를 밀어내면 풀림
	L = _board([[0, K.SOLDIER, Vector2i(5, 4)], [0, K.ROBOT, Vector2i(8, 5)], [1, K.WARRIOR, Vector2i(4, 5)], [1, K.PRIEST, Vector2i(9, 0)]])
	_check(L.disabled_by[_id(0, K.SOLDIER)] == _id(1, K.WARRIOR), "disabled first")
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 5), Vector2i(4, 5)])
	_check(L.pos[_id(1, K.WARRIOR)] == Vector2i(3, 5) and L.disabled_by[_id(0, K.SOLDIER)] < 0, "pushing the warrior away frees it")
	# 로봇 · 전사끼리는 안 통함 (전사 모습 닌자도 전사). 사신에게는 통함
	L = _board([[0, K.WARRIOR, Vector2i(5, 5)], [1, K.WARRIOR, Vector2i(5, 4)], [1, K.ROBOT, Vector2i(4, 4)], [1, K.REAPER, Vector2i(4, 5)], [1, K.NINJA, Vector2i(6, 5)], [1, K.PRIEST, Vector2i(9, 0)]])
	_check(L.disabled_by[_id(0, K.WARRIOR)] < 0 and L.disabled_by[_id(1, K.WARRIOR)] < 0, "warriors don't disable each other")
	_check(L.disabled_by[_id(1, K.ROBOT)] < 0 and L.disabled_by[_id(1, K.REAPER)] == _id(0, K.WARRIOR) and L.disabled_by[_id(1, K.NINJA)] == _id(0, K.WARRIOR), "nor the robot; a reaper and a plain ninja yes")
	L.ninja_form[1] = K.WARRIOR
	L._update_disabled()
	_check(L.disabled_by[_id(1, K.NINJA)] < 0, "a ninja in warrior form counts as a warrior")
	# 두 번째 전사 곁: 전사가 움직여 떠나면 풀림
	L = _board([[0, K.WARRIOR, Vector2i(5, 8)], [1, K.SOLDIER, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.PRIEST, Vector2i(9, 0)]])
	_act(L, _id(0, K.WARRIOR), [Vector2i(5, 9)])
	_check(L.disabled_by[_id(1, K.SOLDIER)] < 0, "the warrior walks away → free")


func _test_ghost() -> void:
	var g := _id(0, K.KNIGHT)
	# 쓰러지면 그 자리에 유령이 나타남, 행동 1번을 써서 상하좌우 한 칸 (제자리도 됨)
	var L := _board([[0, K.KNIGHT, Vector2i(3, 5)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.KNIGHT, Vector2i(3, 4)],
		[1, K.ROBOT, Vector2i(0, 0)]])
	L._kill(g, "attack")
	_check(L.has_ghost(g) and L.ghost_pos[g] == Vector2i(3, 5) and not L.is_free(Vector2i(3, 5)) and L.is_open(Vector2i(3, 5)), "a fallen hero stays as a ghost on its cell")
	_check(L.selectable().has(g), "the ghost can be picked as an action")
	_check(L.begin_action(g) and L.act_ghost and L.act_step == ST.SPIRIT, "picking it starts a ghost move")
	var t := L.step_options()
	_check(t.size() == 4 and t.get(Vector2i(3, 5)) == "stay" and t.get(Vector2i(2, 5)) == "move" and t.get(Vector2i(4, 5)) == "move" and t.get(Vector2i(3, 6)) == "move",
		"one orthogonal cell, or stays; not onto a hero, no diagonals, not 2 cells")
	L.cancel_action()
	L._set_wall(Vector2i(3, 5), Vector2i(3, 6), 0)
	L.begin_action(g)
	_check(not L.step_options().has(Vector2i(3, 6)), "walls block the ghost, my own too")
	L.cancel_action()
	# 유령은 공격 · 능력의 대상이 아님, 지뢰도 안 터짐. 끝 줄을 다녀와도 부활은 없음
	L.current = 1
	_check(not L.options_for(_id(1, K.KNIGHT), K.KNIGHT, ST.STRIKE).has(Vector2i(3, 5)), "an enemy can't attack the ghost")
	L.current = 0
	L.mines[L._i(Vector2i(4, 5))] = 2
	_act(L, g, [Vector2i(4, 5)])
	_check(L.ghost_pos[g] == Vector2i(4, 5) and L.mine_at(Vector2i(4, 5)) == 1, "a ghost stops on an enemy mine without setting it off")
	_check(L.used == 1 and L.act_hero < 0, "a ghost move uses one action")
	for row in [1, 9]:
		L = _board([[0, K.KNIGHT, Vector2i(3, 5)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.ROBOT, Vector2i(0, 0)]])
		L._kill(g, "attack")
		L._set_ghost(g, Vector2i(3, row))
		_act(L, g, [Vector2i(3, 0 if row == 1 else 10)])
		_check(not L.alive(g) and L.has_ghost(g) and L.act_hero < 0, "end rows do nothing")
	# 영웅 · 다른 유령이 있는 칸으로는 못 감
	L = _board([[0, K.KNIGHT, Vector2i(3, 5)], [0, K.SOLDIER, Vector2i(3, 6)], [0, K.PRIEST, Vector2i(2, 5)], [1, K.SOLDIER, Vector2i(4, 5)], [1, K.ROBOT, Vector2i(0, 0)]])
	for id in [g, _id(0, K.SOLDIER), _id(1, K.SOLDIER)]:
		L._kill(id, "attack")
	var sp := L.spirit_paths(g)
	_check(sp.size() == 2 and sp.has(Vector2i(3, 5)) and sp.has(Vector2i(3, 4)), "not onto a hero nor another ghost, mine or not")
	# 영웅은 유령 칸(누구 것이든)에 멈출 수 없고, 지나갈 수는 있음 (천사만 들어감)
	for owner in 2:
		L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(3, 7)], [0, K.ROBOT, Vector2i(5, 8)], [0, K.NINJA, Vector2i(9, 3)], [0, K.ARCHITECT, Vector2i(1, 8)],
			[owner, K.WARRIOR, Vector2i(5, 4)], [owner, K.MAGICIAN, Vector2i(3, 6)], [owner, K.PRIEST, Vector2i(5, 7)], [owner, K.REAPER, Vector2i(7, 3)], [1, K.SOLDIER, Vector2i(10, 0)]])
		for id in [_id(owner, K.WARRIOR), _id(owner, K.MAGICIAN), _id(owner, K.PRIEST), _id(owner, K.REAPER)]:
			L._kill(id, "attack")
		L._update_disabled()
		t = L.options_for(_id(0, K.KNIGHT), K.KNIGHT, ST.MOVE)
		_check(not t.has(Vector2i(5, 4)) and t.get(Vector2i(5, 3)) == "move" and t.get(Vector2i(5, 6)) == "move" and not t.has(Vector2i(5, 7)), "the knight passes over a ghost but can't stop there")
		t = L.options_for(_id(0, K.SOLDIER), K.SOLDIER, ST.MOVE)
		_check(not t.has(Vector2i(3, 6)) and t.has(Vector2i(3, 5)), "the soldier too")
		t = L.options_for(_id(0, K.ROBOT), K.ROBOT, ST.MOVE)
		_check(not t.has(Vector2i(5, 7)) and t.has(Vector2i(5, 6)) and not t.has(Vector2i(5, 5)), "the robot too")
		t = L.options_for(_id(0, K.NINJA), K.NINJA, ST.MOVE)
		_check(not t.has(Vector2i(7, 3)) and t.has(Vector2i(6, 3)) and t.has(Vector2i(0, 3)), "the ninja too")
		t = L.options_for(_id(0, K.ARCHITECT), K.ARCHITECT, ST.MOVE)
		_check(not t.has(Vector2i(3, 6)) and t.has(Vector2i(4, 5)), "the architect too")
		L.begin_action(_id(0, K.KNIGHT))
		L.choose(Vector2i(5, 3))
		_check(L.pos[_id(0, K.KNIGHT)] == Vector2i(5, 3) and L.has_ghost(_id(owner, K.WARRIOR)), "passing over it doesn't remove it")
	for k in 10:
		if k == K.ANGEL or k == K.MAGICIAN:
			continue
		L = _board([[0, k, Vector2i(5, 6)], [0, K.KNIGHT if k != K.KNIGHT else K.SOLDIER, Vector2i(0, 10)], [1, K.KNIGHT, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(10, 5)]])
		L._kill(_id(1, K.KNIGHT), "attack")
		_check(not L.options_for(k, k, ST.MOVE).has(Vector2i(5, 5)), "%s can't stop on a ghost" % HeroLogic.NAMES[k])
	# 능력으로도 못 옮겨짐: 밀기 · 데려오기 · 전진 · 지뢰 · 소환 · 부활 자리
	L = _board([[0, K.ROBOT, Vector2i(5, 6)], [0, K.SOLDIER, Vector2i(5, 5)], [0, K.WARRIOR, Vector2i(8, 5)], [0, K.PRIEST, Vector2i(5, 4)], [0, K.NINJA, Vector2i(8, 4)], [0, K.KNIGHT, Vector2i(4, 10)], [1, K.SOLDIER, Vector2i(0, 0)]])
	for id in [_id(0, K.PRIEST), _id(0, K.NINJA), _id(0, K.KNIGHT)]:
		L._kill(id, "attack")
	_check(L.push_moves(_id(0, K.ROBOT)).is_empty(), "nothing to push")
	_check(not L.options_for(_id(0, K.WARRIOR), K.WARRIOR, ST.WARRIOR).has(Vector2i(8, 4)), "a warrior can't advance onto a ghost")
	_check(not L.options_for(_id(0, K.SOLDIER), K.SOLDIER, ST.MINE).has(Vector2i(5, 4)), "no mine on a ghost")
	_check(L.summon_cells().size() == 4 and not L.summon_cells().has(Vector2i(4, 10)), "a ghost next to the castle takes that cell")
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(5, 6)], [0, K.PRIEST, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(_id(0, K.PRIEST), "attack")
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 3)])
	_check(not L.step_options().values().has("carry"), "the knight can't move an ally onto a ghost")
	# 겹치면 가장 가까운 빈칸: 자기 성에 가까운 쪽, 그다음 왼쪽
	L = _board([[0, K.KNIGHT, Vector2i(3, 5)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(5, 8)], [1, K.ROBOT, Vector2i(0, 0)]])
	_check(L._ghost_cell(Vector2i(3, 3), 0) == Vector2i(3, 3), "the cell itself when it's free")
	L._place(_id(0, K.PRIEST), Vector2i(5, 5))
	_check(L._ghost_cell(Vector2i(5, 5), 0) == Vector2i(5, 6) and L._ghost_cell(Vector2i(5, 5), 1) == Vector2i(5, 4), "nearest free cell, its own castle's side first")
	L._place(_id(0, K.ANGEL), Vector2i(5, 6))
	_check(L._ghost_cell(Vector2i(5, 5), 0) == Vector2i(4, 5), "then the left one")
	# 유령이 있던 칸이 비면 다시 들어갈 수 있음
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(5, 4)], [1, K.ROBOT, Vector2i(0, 0)]], 1)
	L._kill(_id(1, K.SOLDIER), "attack")
	_act(L, _id(1, K.SOLDIER), [Vector2i(4, 4)])
	L.end_turn()
	t = L.options_for(_id(0, K.KNIGHT), K.KNIGHT, ST.MOVE)
	_check(t.has(Vector2i(5, 4)) and L.ghost_at(Vector2i(4, 4)) == _id(1, K.SOLDIER) and L.ghost_at(Vector2i(5, 4)) < 0, "the cell a ghost left is free again")
	# AI: 천사로 유령을 부활시킴
	L = _board([[0, K.ANGEL, Vector2i(3, 8)], [0, K.REAPER, Vector2i(3, 6)], [0, K.ROBOT, Vector2i(9, 9)], [1, K.ROBOT, Vector2i(9, 1)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(_id(0, K.REAPER), "attack")
	var plan: Array = HeroAI.new(HeroAI.Level.NORMAL).plan(L)
	var revives := false
	for s in plan:
		var taps: Array = (s as Dictionary).get("taps", [])
		if taps.size() >= 3 and taps[0] == _id(0, K.ANGEL) and taps[1] == Vector2i(3, 6) and taps[2] != STOP:
			revives = true
	_check(revives, "AI revives its reaper with the angel")


func _test_ninja() -> void:
	# 가로 · 세로 이동(능력 없음), 또는 앞 세로줄에서 처음 만나는 영웅(거리 상관없음, 적도 됨 – 적 사신 · 적 닌자 X)을 눌러 이동과 능력 따라 하기
	var L := _board([[0, K.NINJA, Vector2i(3, 7)], [0, K.REAPER, Vector2i(3, 3)], [1, K.SOLDIER, Vector2i(5, 5)],
		[1, K.PRIEST, Vector2i(4, 7)], [1, K.ANGEL, Vector2i(5, 7)]])
	var t := L.options_for(_id(0, K.NINJA), K.NINJA, ST.MOVE)
	_check(t.get(Vector2i(3, 7)) == "stay" and t.has(Vector2i(2, 7)) and t.has(Vector2i(0, 7)) and not t.has(Vector2i(2, 6))
		and t.has(Vector2i(3, 4)) and t.has(Vector2i(3, 10)) and not t.has(Vector2i(4, 7)), "ninja slides along lines until something blocks it, or stays")
	_check(t.get(Vector2i(3, 3)) == "copy", "the first hero up its column can be copied")
	_act(L, _id(0, K.NINJA), [Vector2i(3, 3)])
	t = L.step_options()
	_check(L.act_copy == _id(0, K.REAPER) and L.act_kind == K.REAPER and L.act_step == ST.MOVE and not L.act_optional,
		"copying starts with the copied hero's move")
	_check(t.has(Vector2i(3, 6)) and t.has(Vector2i(2, 7)) and not t.has(Vector2i(2, 6)) and not t.has(Vector2i(4, 6)), "copied reaper move: 1 orthogonal cell")
	L.choose(Vector2i(3, 6))
	if L.act_hero >= 0:
		L.stop_action()
	_check(not L.alive(_id(1, K.PRIEST)) and L.alive(_id(1, K.SOLDIER)) and L.alive(_id(1, K.ANGEL)), "copied reaper hits its diagonals")
	_check(L.alive(_id(0, K.REAPER)), "the source isn't touched")
	# 따라 한 모습은 다음 내 차례까지. 그 차례에 다시 따라 하지 않으면 끝날 때 닌자로 돌아옴
	_check(L.ninja_form[0] == K.REAPER, "the ninja keeps the copied form")
	L.end_turn()
	_check(L.current == 1 and L.ninja_form[0] == K.REAPER, "still copied during the opponent's turn")
	L.pass_turn()
	_check(L.current == 0 and L.ninja_form[0] == -1, "back to the ninja when my next turn starts")
	# 전사를 따라 하면 그 모습인 동안 주위 8칸의 적이 무력 (닌자로 돌아오면 풀림)
	L = _board([[0, K.NINJA, Vector2i(3, 7)], [0, K.WARRIOR, Vector2i(3, 2)], [1, K.SOLDIER, Vector2i(2, 5)],
		[1, K.PRIEST, Vector2i(9, 0)]])
	_act(L, _id(0, K.NINJA), [Vector2i(3, 2), Vector2i(3, 6)])
	_check(L.disabled_by[_id(1, K.SOLDIER)] == _id(0, K.NINJA) and L.step_options().get(Vector2i(3, 5)) == "advance", "ninja as a warrior disables, then may advance")
	L.stop_action()
	L.end_turn()
	_check(L.disabled_by[_id(1, K.SOLDIER)] == _id(0, K.NINJA), "the disable lasts through the opponent's turn")
	L.pass_turn()
	_check(L.ninja_form[0] == -1 and L.disabled_by[_id(1, K.SOLDIER)] < 0, "my turn starts → back to a ninja, the disable ends")
	# 1칸 이동에는 능력이 없음
	L = _board([[0, K.NINJA, Vector2i(3, 7)], [1, K.REAPER, Vector2i(3, 3)], [1, K.SOLDIER, Vector2i(2, 5)]])
	_act(L, _id(0, K.NINJA), [Vector2i(3, 5)])
	_check(L.act_hero < 0 and L.pos[_id(0, K.NINJA)] == Vector2i(3, 5) and L.alive(_id(1, K.SOLDIER)), "a plain move has no ability")
	# 기사를 따라 하면 기사 이동(한 방향 2칸 이하) → 데려오기 또는 공격
	L = _board([[0, K.NINJA, Vector2i(3, 8)], [0, K.SOLDIER, Vector2i(3, 9)], [1, K.KNIGHT, Vector2i(3, 3)],
		[1, K.PRIEST, Vector2i(6, 8)]])
	_act(L, _id(0, K.NINJA), [Vector2i(3, 3)])
	t = L.step_options()
	_check(t.has(Vector2i(5, 8)) and t.has(Vector2i(3, 6)) and not t.has(Vector2i(4, 7)), "copied knight move: straight up to 2")
	L.choose(Vector2i(5, 8))
	t = L.step_options()
	_check(L.act_step == ST.CARRY and t.get(Vector2i(3, 9)) == "carry" and t.get(Vector2i(6, 8)) == "attack",
		"copied knight can take an ally that was behind the start along, or attack")
	L.choose(Vector2i(3, 9))
	_check(L.pos[_id(0, K.SOLDIER)] == Vector2i(5, 9) and L.act_hero < 0 and L.alive(_id(1, K.PRIEST)), "the ally moves just like the ninja, no attack too")
	# 마법사를 따라 하면 이동 없이 바로 자리 바꾸기 · 파이어볼, 아군도 따라 할 수 있음
	L = _board([[0, K.NINJA, Vector2i(3, 8)], [0, K.MAGICIAN, Vector2i(3, 5)], [1, K.SOLDIER, Vector2i(5, 8)],
		[1, K.PRIEST, Vector2i(9, 0)]])
	_act(L, _id(0, K.NINJA), [Vector2i(3, 5)])
	_check(L.act_step == ST.SWAP_FIRE and L.step_options().get(Vector2i(5, 8)) == "fire", "copied magician: no move, fireball right away")
	L.choose(Vector2i(5, 8))
	_check(not L.alive(_id(1, K.SOLDIER)) and L.pos[_id(0, K.NINJA)] == Vector2i(3, 8), "fireball from where the ninja stands")
	# 앞 또는 뒤 세로줄의 첫 영웅 중에서 고름
	L = _board([[0, K.NINJA, Vector2i(3, 5)], [1, K.KNIGHT, Vector2i(3, 2)], [0, K.SOLDIER, Vector2i(3, 9)], [1, K.ANGEL, Vector2i(3, 1)], [1, K.PRIEST, Vector2i(9, 0)]])
	t = L.options_for(_id(0, K.NINJA), K.NINJA, ST.MOVE)
	_check(t.get(Vector2i(3, 2)) == "copy" and t.get(Vector2i(3, 9)) == "copy" and not t.has(Vector2i(3, 1)), "the first hero in front OR behind can be copied")
	_act(L, _id(0, K.NINJA), [Vector2i(3, 9)])
	_check(L.act_kind == K.SOLDIER, "copied the hero behind")
	# 모든 영웅을 따라 함: 로봇이면 쭉 이동 → 밀기, 그 모습인 동안 공격 · 능력 대상이 아님
	L = _board([[0, K.NINJA, Vector2i(3, 8)], [1, K.ROBOT, Vector2i(3, 3)], [1, K.SOLDIER, Vector2i(3, 4)], [1, K.PRIEST, Vector2i(9, 0)]])
	L._relocate(_id(1, K.ROBOT), Vector2i(3, 10))
	_check(L.options_for(_id(0, K.NINJA), K.NINJA, ST.MOVE).get(Vector2i(3, 10)) == "copy", "the robot can be copied")
	_act(L, _id(0, K.NINJA), [Vector2i(3, 10), Vector2i(3, 5)])
	t = L.step_options()
	_check(L.pos[_id(0, K.NINJA)] == Vector2i(3, 5) and L.act_step == ST.PUSH and t == {Vector2i(3, 4): "push"}, "copied robot: slides, then pushes ahead")
	if L.act_hero >= 0:
		L.stop_action()
	_check(L.ninja_form[0] == K.ROBOT and L._immune(_id(0, K.NINJA)), "robot form: immune")
	L.end_turn()
	L.current = 1
	_act(L, _id(1, K.SOLDIER), [Vector2i(4, 5)])
	_check(not L.step_options().has(Vector2i(3, 5)), "can't be attacked in robot form")
	if L.act_hero >= 0:
		L.stop_action()
	# 상대 닌자는 따라 할 수 없음 (어떤 모습이든), 그 너머도 못 봄
	for form in [-1, K.KNIGHT, K.REAPER]:
		L = _board([[0, K.NINJA, Vector2i(3, 8)], [1, K.NINJA, Vector2i(3, 4)], [1, K.KNIGHT, Vector2i(3, 2)], [0, K.SOLDIER, Vector2i(3, 10)], [1, K.PRIEST, Vector2i(9, 0)]])
		L.ninja_form[1] = form
		_check(L.ninja_sources(_id(0, K.NINJA)) == [_id(0, K.SOLDIER)], "an enemy ninja can't be copied nor seen past (form %d)" % form)
	# 벽에 막힘
	L = _board([[0, K.NINJA, Vector2i(3, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._set_wall(Vector2i(6, 7), Vector2i(7, 7), 0)
	t = L.options_for(_id(0, K.NINJA), K.NINJA, ST.MOVE)
	_check(t.has(Vector2i(6, 7)) and not t.has(Vector2i(7, 7)), "walls stop the ninja")


func _test_reaper() -> void:
	# 가로 · 세로 1칸
	var L := _board([[0, K.REAPER, Vector2i(5, 8)], [1, K.SOLDIER, Vector2i(4, 5)], [1, K.ROBOT, Vector2i(6, 7)],
		[1, K.KNIGHT, Vector2i(3, 7)], [1, K.PRIEST, Vector2i(9, 1)]], 1)
	var t := L.options_for(_id(0, K.REAPER), K.REAPER, ST.MOVE)
	_check(t.size() == 5 and t.has(Vector2i(5, 7)) and t.has(Vector2i(4, 8)) and not t.has(Vector2i(4, 7)) and t.get(Vector2i(5, 8)) == "stay",
		"reaper moves 1 orthogonally or stays")
	# 지나가기만 하면 괜찮고, 대각선에 멈추면 공격받음
	_act(L, _id(1, K.KNIGHT), [Vector2i(5, 7), STOP])
	_check(L.alive(_id(1, K.KNIGHT)), "passing through a diagonal cell (and stopping orthogonally) is safe")
	_act(L, _id(1, K.SOLDIER), [Vector2i(4, 7)])
	_check(not L.alive(_id(1, K.SOLDIER)) and L.act_hero < 0, "an enemy stopping on a diagonal cell is attacked")
	# 사신이 다가가도 (내 차례) 대각선의 적을 모두 자동 공격. 로봇과 상하좌우는 X
	L = _board([[0, K.REAPER, Vector2i(5, 8)], [1, K.PRIEST, Vector2i(4, 6)], [1, K.SOLDIER, Vector2i(6, 6)],
		[1, K.ROBOT, Vector2i(4, 8)], [1, K.ANGEL, Vector2i(5, 6)], [1, K.KNIGHT, Vector2i(9, 1)]])
	_act(L, _id(0, K.REAPER), [Vector2i(5, 7)])
	_check(not L.alive(_id(1, K.PRIEST)) and not L.alive(_id(1, K.SOLDIER)) and L.alive(_id(1, K.ROBOT)) and L.alive(_id(1, K.ANGEL)),
		"the reaper stopping auto-attacks every diagonal enemy, not the robot, not the orthogonals")
	# 저주: 상하좌우 2칸 안에서 처음 만나는 적
	L = _board([[0, K.REAPER, Vector2i(5, 8)], [0, K.PRIEST, Vector2i(4, 7)], [1, K.SOLDIER, Vector2i(5, 5)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.ANGEL, Vector2i(8, 7)],
		[1, K.MAGICIAN, Vector2i(3, 7)], [1, K.PRIEST, Vector2i(9, 1)]])
	_act(L, _id(0, K.REAPER), [Vector2i(5, 7)])
	t = L.step_options()
	_check(L.act_step == ST.REAP and L.act_optional and t.get(Vector2i(5, 5)) == "curse" and not t.has(Vector2i(5, 4)) and not t.has(Vector2i(8, 7)) and not t.has(Vector2i(3, 7)),
		"curse: the first enemy within 2 cells; not behind it, not 3 cells away, allies block")
	L.choose(Vector2i(5, 5))
	_check(L.cursed_by[_id(1, K.SOLDIER)] == _id(0, K.REAPER) and L.alive(_id(1, K.SOLDIER)) and L.act_hero < 0, "cursed, not hurt")
	var h := L.state_hash()
	L.cursed_by[_id(1, K.SOLDIER)] = -1
	_check(h != L.state_hash(), "the curse is part of the state")
	L.cursed_by[_id(1, K.SOLDIER)] = _id(0, K.REAPER)
	_check(L.clone().cursed_by[_id(1, K.SOLDIER)] == _id(0, K.REAPER), "and of a copy")
	# 저주 걸린 적의 자리로 거리와 상관없이 → 그 적은 쓰러지고 사신이 그 칸에. 비석 · 유령은 그 칸에 남음
	L.end_turn()
	_act(L, _id(1, K.SOLDIER), [Vector2i(6, 4)])
	if L.act_hero >= 0:
		L.stop_action()
	L.end_turn()
	var sc: Vector2i = L.pos[_id(1, K.SOLDIER)]
	_act(L, _id(0, K.REAPER), [Vector2i(5, 8)])
	_check(L.step_options().get(sc) == "doom", "a cursed enemy can be taken from anywhere")
	L.choose(sc)
	_check(not L.alive(_id(1, K.SOLDIER)) and L.pos[_id(0, K.REAPER)] == sc and L.at(sc) == _id(0, K.REAPER)
		and not L.has_ghost(_id(1, K.SOLDIER)) and L.ghost_at(sc) < 0 and L.act_hero < 0, "the enemy falls, the reaper stands there, no ghost")
	# 옮긴 자리의 대각선도 자동 공격
	L = _board([[0, K.REAPER, Vector2i(1, 9)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(8, 2)], [1, K.ARCHITECT, Vector2i(7, 1)], [1, K.PRIEST, Vector2i(5, 3)]])
	L.cursed_by[_id(1, K.SOLDIER)] = _id(0, K.REAPER)
	_act(L, _id(0, K.REAPER), [Vector2i(1, 9), Vector2i(8, 2)])
	_check(not L.alive(_id(1, K.SOLDIER)) and not L.alive(_id(1, K.ARCHITECT)) and L.alive(_id(1, K.PRIEST)), "then it cuts the diagonals of the new cell")
	# 배리어가 있는 적은 저주의 대상이 안 되고(배리어도 그대로) 그 너머로도 못 걺, 이미 저주 걸린 적 · 적 사신 · 로봇은 못 고름, 상대 벽에 막힘
	L = _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(5, 5)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.MAGICIAN, Vector2i(7, 7)],
		[1, K.PRIEST, Vector2i(9, 1)]])
	L.barrier[_id(1, K.SOLDIER)] = 1
	_act(L, _id(0, K.REAPER), [Vector2i(5, 7)])
	t = L.step_options()
	_check(not t.has(Vector2i(5, 5)) and not t.has(Vector2i(5, 4)) and t.get(Vector2i(7, 7)) == "curse", "an enemy with a barrier can't be cursed, nor one behind it")
	L.choose(Vector2i(5, 5))
	_check(L.cursed_by[_id(1, K.SOLDIER)] < 0 and L.barrier[_id(1, K.SOLDIER)] == 1 and L.act_hero >= 0, "tapping it does nothing")
	L = _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.REAPER, Vector2i(5, 5)], [1, K.ROBOT, Vector2i(7, 7)], [1, K.SOLDIER, Vector2i(3, 7)], [1, K.KNIGHT, Vector2i(5, 9)],
		[1, K.PRIEST, Vector2i(9, 1)]])
	L._set_wall(Vector2i(4, 7), Vector2i(3, 7), 1)
	L._set_wall(Vector2i(5, 8), Vector2i(5, 9), 0)
	_act(L, _id(0, K.REAPER), [Vector2i(5, 7)])
	t = L.step_options()
	_check(not t.has(Vector2i(5, 5)) and not t.has(Vector2i(7, 7)) and not t.has(Vector2i(3, 7)) and t.get(Vector2i(5, 9)) == "curse",
		"not the enemy reaper nor the robot, not over an enemy wall; over mine it can")
	L._set_wall(Vector2i(4, 7), Vector2i(3, 7), -1)
	_check(L.options_for(_id(0, K.REAPER), K.REAPER, ST.REAP).get(Vector2i(3, 7)) == "curse", "no wall: it can be cursed")
	for who in 2:
		L.turret[L._i(Vector2i(4, 7))] = who + 1
		_check(L.options_for(_id(0, K.REAPER), K.REAPER, ST.REAP).has(Vector2i(3, 7)) == false, "any turret stops the curse, mine too")
	# 적 사신(사신 모습 닌자도)은 저주에 안 걸리고 저주를 막음, 닌자로 돌아오면 걸림
	for who in [K.REAPER, K.NINJA]:
		L = _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, who, Vector2i(5, 6)], [1, K.SOLDIER, Vector2i(5, 5)], [1, K.PRIEST, Vector2i(9, 1)]])
		if who == K.NINJA:
			L.ninja_form[1] = K.REAPER
		t = L.options_for(_id(0, K.REAPER), K.REAPER, ST.REAP)
		_check(not t.has(Vector2i(5, 6)) and not t.has(Vector2i(5, 5)), "a reaper can't be cursed and stops the curse")
		L.ninja_form[1] = -1
		t = L.options_for(_id(0, K.REAPER), K.REAPER, ST.REAP)
		_check(t.has(Vector2i(5, 6)) == (who == K.NINJA), "a plain ninja can")
	# 사신이 쓰러지면 적에게 걸린 모든 저주가 사라짐. 닌자가 사신을 따라 하면 내 편 저주를 쓸 수 있음
	L = _board([[0, K.REAPER, Vector2i(3, 2)], [0, K.NINJA, Vector2i(3, 9)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(8, 5)], [1, K.PRIEST, Vector2i(9, 1)]])
	L.cursed_by[_id(1, K.SOLDIER)] = _id(0, K.REAPER)
	_act(L, _id(0, K.NINJA), [Vector2i(3, 2), Vector2i(3, 9)])
	_check(L.act_step == ST.REAP and L.step_options().get(Vector2i(8, 5)) == "doom", "a ninja in reaper form can take the cursed enemy")
	L.stop_action()
	L.cursed_by[_id(1, K.PRIEST)] = _id(0, K.NINJA)
	L._kill(_id(0, K.REAPER), "attack")
	_check(L.cursed_by[_id(1, K.SOLDIER)] < 0 and L.cursed_by[_id(1, K.PRIEST)] < 0, "the reaper falls → every curse on the enemy is gone, whoever cast it")
	L.cursed_by[_id(1, K.PRIEST)] = _id(0, K.NINJA)
	L.ninja_form[0] = -1
	L._kill(_id(0, K.NINJA), "attack")
	_check(L.cursed_by[_id(1, K.PRIEST)] >= 0, "a plain ninja falling doesn't lift it")
	L = _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.NINJA, Vector2i(3, 9)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(8, 5)], [1, K.PRIEST, Vector2i(9, 1)]])
	L.cursed_by[_id(1, K.SOLDIER)] = _id(0, K.REAPER)
	L.ninja_form[0] = K.REAPER
	L._kill(_id(0, K.NINJA), "attack")
	_check(L.cursed_by[_id(1, K.SOLDIER)] < 0, "a ninja in reaper form falling does")
	# 저주 걸린 영웅이 쓰러지면 저주가 유령에게 남고, 부활하면 저주는 없음
	L = _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(8, 5)], [1, K.PRIEST, Vector2i(9, 1)]])
	L.cursed_by[_id(1, K.SOLDIER)] = _id(0, K.REAPER)
	L._kill(_id(1, K.SOLDIER), "attack")
	_check(L.has_ghost(_id(1, K.SOLDIER)) and L.cursed_by[_id(1, K.SOLDIER)] == _id(0, K.REAPER), "the curse stays on the ghost")
	_test_ghost_curse()
	L._revive(_id(1, K.SOLDIER), Vector2i(8, 5), -1)
	_check(L.cursed_by[_id(1, K.SOLDIER)] < 0, "a revived hero isn't cursed")
	# 무력 · 밀기도 다른 영웅처럼 통함. 아군의 능력도 통함 (배리어도)
	L = _board([[0, K.ROBOT, Vector2i(5, 8)], [0, K.REAPER, Vector2i(5, 5)], [0, K.KNIGHT, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.ROBOT), [Vector2i(5, 6)])
	_check(L.act_hero < 0, "my robot can't push my reaper")
	L = _board([[0, K.REAPER, Vector2i(5, 5)], [1, K.ROBOT, Vector2i(5, 8)], [1, K.SOLDIER, Vector2i(0, 0)]], 1)
	_act(L, _id(1, K.ROBOT), [Vector2i(5, 6)])
	_check(L.step_options().get(Vector2i(5, 5)) == "push", "the enemy robot can push my reaper")
	L.choose(Vector2i(5, 5))
	_check(L.pos[_id(0, K.REAPER)] == Vector2i(5, 4) and L.stunned[_id(0, K.REAPER)] == 1, "pushed and stunned")
	L = _board([[0, K.MAGICIAN, Vector2i(5, 8)], [0, K.REAPER, Vector2i(5, 5)], [0, K.KNIGHT, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.begin_action(_id(0, K.MAGICIAN))
	_check(L.step_options().get(Vector2i(5, 5)) == "swap", "my magician can swap with my reaper")
	L = _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.REAPER, Vector2i(5, 6)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 3)])
	_check(L.step_options().get(Vector2i(5, 6)) == "carry", "my knight can carry my reaper")
	L = _board([[0, K.ANGEL, Vector2i(5, 5)], [0, K.REAPER, Vector2i(5, 3)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_check(L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE).get(Vector2i(5, 3)) == "land", "my angel can land on my reaper")
	L = _board([[0, K.REAPER, Vector2i(5, 3)], [1, K.WARRIOR, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(9, 0)]], 1)
	_check(L.disabled_by[_id(0, K.REAPER)] == _id(1, K.WARRIOR), "an enemy warrior disables the reaper")
	_act(L, _id(1, K.WARRIOR), [Vector2i(5, 4)])
	_check(L.step_options().get(Vector2i(5, 3)) == "attack", "but can attack it")
	L = _board([[0, K.KNIGHT, Vector2i(5, 3)], [1, K.REAPER, Vector2i(5, 1)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 2), Vector2i(5, 1)])
	_check(not L.alive(_id(1, K.REAPER)), "attacks do work on the reaper")
	# 내 차례에 내 로봇이 밀어 넣어도
	L = _board([[0, K.REAPER, Vector2i(5, 5)], [0, K.ROBOT, Vector2i(4, 1)], [1, K.SOLDIER, Vector2i(4, 3)],
		[1, K.PRIEST, Vector2i(9, 1)]])
	_act(L, _id(0, K.ROBOT), [Vector2i(4, 2), Vector2i(4, 3)])
	_check(not L.alive(_id(1, K.SOLDIER)), "pushed onto a diagonal cell on my turn → attacked too")
	# 배리어가 있는 동안 자동 공격이 안 통하고 배리어도 안 깨짐 (사라지는 순간의 자동 공격까지). 대각선은 벽과 상관없음
	L = _board([[0, K.REAPER, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(4, 2)], [1, K.PRIEST, Vector2i(9, 1)]], 1)
	L.barrier[_id(1, K.SOLDIER)] = 1
	L._set_wall(Vector2i(5, 5), Vector2i(4, 5), 1)
	L._set_wall(Vector2i(5, 5), Vector2i(5, 4), 1)
	_act(L, _id(1, K.SOLDIER), [Vector2i(4, 4), STOP])
	_check(L.alive(_id(1, K.SOLDIER)) and L.barrier[_id(1, K.SOLDIER)] == 1, "a barrier keeps the automatic attack away and isn't used up")
	var gone := L.clone()
	for n in 4:
		L.pass_turn()
	_check(L.alive(_id(1, K.SOLDIER)) and L.barrier[_id(1, K.SOLDIER)] == 1, "at every turn change, as long as it lasts")
	# 배리어가 다른 공격으로 깨지면 다음 차례가 바뀔 때 맞음
	L = gone
	L.barrier[_id(1, K.SOLDIER)] = 0
	L.pass_turn()
	_check(not L.alive(_id(1, K.SOLDIER)), "a broken barrier doesn't help")
	# 대각선으로 다가온 사신도, 내려앉은 천사도 마찬가지 · 배리어가 없으면 벽이 있어도 맞음
	L = _board([[0, K.REAPER, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(4, 3)], [1, K.ARCHITECT, Vector2i(6, 3)], [1, K.PRIEST, Vector2i(9, 1)]])
	L.barrier[_id(1, K.SOLDIER)] = 1
	L._set_wall(Vector2i(6, 3), Vector2i(6, 4), 1)
	_act(L, _id(0, K.REAPER), [Vector2i(5, 4), STOP])
	_check(L.alive(_id(1, K.SOLDIER)) and not L.alive(_id(1, K.ARCHITECT)), "the reaper walking up: only the one without a barrier falls")
	L = _board([[0, K.REAPER, Vector2i(5, 5)], [0, K.KNIGHT, Vector2i(4, 4)], [1, K.ANGEL, Vector2i(4, 2)], [1, K.PRIEST, Vector2i(9, 1)]], 1)
	L.barrier[_id(1, K.ANGEL)] = 1
	_act(L, _id(1, K.ANGEL), [Vector2i(4, 4)])
	_check(L.alive(_id(1, K.ANGEL)) and L.barrier[_id(1, K.ANGEL)] == 1 and L.act_step == ST.LAND, "a landed angel with a barrier isn't cut")
	# 사신은 누구의 벽이든 통과함 (영웅 · 포탑 칸에는 못 섬). 저주는 적군의 벽에 막힘, 저주 걸린 적에게 가는 것은 벽과 상관없음
	L = _board([[0, K.REAPER, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(5, 6)], [1, K.KNIGHT, Vector2i(7, 5)], [1, K.PRIEST, Vector2i(9, 1)]])
	L._set_wall(Vector2i(5, 5), Vector2i(6, 5), 1)
	L._set_wall(Vector2i(5, 5), Vector2i(4, 5), 0)
	for d in HeroLogic.DIRS4:
		L._set_wall(Vector2i(5, 4), Vector2i(5, 4) + d, 1)
	L.turret[L._i(Vector2i(5, 4))] = 2
	L.barrier[_id(0, K.REAPER)] = 1
	t = L.options_for(_id(0, K.REAPER), K.REAPER, ST.MOVE)
	_check(t.has(Vector2i(6, 5)) and t.has(Vector2i(4, 5)) and not t.has(Vector2i(5, 6)) and not t.has(Vector2i(5, 4)) and t.size() == 3,
		"the reaper walks through anyone's wall, not onto a hero or a turret")
	_check(not L.options_for(_id(0, K.REAPER), K.REAPER, ST.REAP).has(Vector2i(7, 5)), "its curse doesn't go over an enemy wall")
	L.cursed_by[_id(1, K.KNIGHT)] = _id(0, K.REAPER)
	_check(L.options_for(_id(0, K.REAPER), K.REAPER, ST.REAP).get(Vector2i(7, 5)) == "doom", "but it can go to a cursed enemy behind one")
	L.cursed_by[_id(1, K.KNIGHT)] = -1
	L.turret[L._i(Vector2i(5, 4))] = 0   # 포탑은 배리어를 뚫으므로 치움
	_act(L, _id(0, K.REAPER), [Vector2i(6, 5), STOP])
	_check(L.pos[_id(0, K.REAPER)] == Vector2i(6, 5) and L.has_wall(Vector2i(5, 5), Vector2i(6, 5)), "the wall stays")
	L = _board([[0, K.WARRIOR, Vector2i(5, 5)], [0, K.NINJA, Vector2i(3, 8)], [0, K.REAPER, Vector2i(3, 2)], [1, K.PRIEST, Vector2i(9, 1)]])
	L._set_wall(Vector2i(5, 5), Vector2i(6, 5), 1)
	L._set_wall(Vector2i(3, 8), Vector2i(4, 8), 1)
	_check(not L.options_for(_id(0, K.WARRIOR), K.WARRIOR, ST.MOVE).has(Vector2i(6, 5)), "others are still blocked")
	_act(L, _id(0, K.NINJA), [Vector2i(3, 2)])
	_check(L.act_kind == K.REAPER and L.step_options().has(Vector2i(4, 8)), "a ninja in reaper form walks through too (copying my own reaper)")
	# 닌자는 상대 사신(사신 모습의 닌자도)을 따라 할 수 없고 그 너머도 못 봄
	L = _board([[0, K.NINJA, Vector2i(3, 8)], [1, K.REAPER, Vector2i(3, 5)], [1, K.SOLDIER, Vector2i(3, 3)], [0, K.SOLDIER, Vector2i(3, 10)], [1, K.PRIEST, Vector2i(9, 1)]])
	_check(L.ninja_sources(_id(0, K.NINJA)) == [_id(0, K.SOLDIER)], "a ninja can't copy the enemy reaper nor see past it")
	L = _board([[0, K.NINJA, Vector2i(3, 8)], [1, K.NINJA, Vector2i(3, 4)], [1, K.PRIEST, Vector2i(9, 1)], [0, K.SOLDIER, Vector2i(0, 10)]])
	L.ninja_form[1] = K.REAPER
	_check(L.ninja_sources(_id(0, K.NINJA)).is_empty(), "nor an enemy ninja in reaper form")
	# 천사는 적 사신 칸에도 내려앉음
	L = _board([[0, K.ANGEL, Vector2i(5, 8)], [1, K.REAPER, Vector2i(5, 7)], [0, K.REAPER, Vector2i(7, 8)], [1, K.SOLDIER, Vector2i(0, 0)]])
	t = L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE)
	_check(t.get(Vector2i(5, 7)) == "land" and t.has(Vector2i(5, 6)) and t.get(Vector2i(7, 8)) == "land", "an angel can land on the enemy reaper, and on mine")
	_act(L, _id(0, K.ANGEL), [Vector2i(5, 7), Vector2i(5, 8)])
	_check(L.alive(_id(0, K.ANGEL)) and L.pos[_id(0, K.ANGEL)] == Vector2i(5, 8) and L.alive(_id(1, K.REAPER)), "the reaper under it doesn't cut it")
	# 로봇 · 건축가 · 닌자(무엇을 따라 하든, 아군도 적도) 칸에는 못 내려앉음, 넘어가기는 됨
	for side in 2:
		for k in [K.ROBOT, K.ARCHITECT, K.NINJA]:
			for form in [-1, K.KNIGHT, K.REAPER] if k == K.NINJA else [-1]:
				L = _board([[0, K.ANGEL, Vector2i(5, 8)], [side, k, Vector2i(5, 7)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
				if k == K.NINJA:
					L.ninja_form[side] = form
				t = L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE)
				_check(not t.has(Vector2i(5, 7)) and t.has(Vector2i(5, 6)), "no landing on %s (side %d form %d)" % [HeroLogic.NAMES[k], side, form])
	# 나머지 영웅은 아군이든 적이든 됨
	for side in 2:
		for k in [K.KNIGHT, K.SOLDIER, K.MAGICIAN, K.PRIEST, K.WARRIOR, K.REAPER]:
			L = _board([[0, K.ANGEL, Vector2i(5, 8)], [side, k, Vector2i(5, 7)], [0, K.SOLDIER if k != K.SOLDIER else K.KNIGHT, Vector2i(9, 9)], [1, K.SOLDIER if k != K.SOLDIER else K.KNIGHT, Vector2i(0, 0)]])
			_check(L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE).get(Vector2i(5, 7)) == "land", "landing on %s (side %d)" % [HeroLogic.NAMES[k], side])
	# 두 사신이 마주치면 동시에
	L = _board([[0, K.REAPER, Vector2i(4, 6)], [1, K.REAPER, Vector2i(3, 4)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.PRIEST, Vector2i(9, 1)]])
	_act(L, _id(0, K.REAPER), [Vector2i(4, 5)])
	_check(not L.alive(_id(0, K.REAPER)) and not L.alive(_id(1, K.REAPER)) and L.act_hero < 0, "two reapers meeting attack each other at once")
	# 사신 모습을 따라 한 닌자도 똑같음 (모습이 바뀌는 순간에도)
	L = _board([[0, K.NINJA, Vector2i(3, 7)], [0, K.REAPER, Vector2i(3, 2)], [1, K.SOLDIER, Vector2i(5, 4)],
		[1, K.ARCHITECT, Vector2i(2, 6)], [1, K.PRIEST, Vector2i(9, 1)]])
	_act(L, _id(0, K.NINJA), [Vector2i(3, 2)])
	_check(not L.alive(_id(1, K.ARCHITECT)) and L.act_step == ST.MOVE, "becoming a reaper attacks the diagonals at once, then moves")
	L.choose(Vector2i(4, 7))
	if L.act_hero >= 0:
		L.stop_action()
	L.end_turn()
	_act(L, _id(1, K.SOLDIER), [Vector2i(5, 6)])
	_check(not L.alive(_id(1, K.SOLDIER)), "a ninja in reaper form attacks an enemy stopping on its diagonal")
	# 성은 자동으로 공격하지 않음. 상하좌우에 붙은 성은 다른 영웅처럼 칠 수 있음
	L = _board([[0, K.REAPER, Vector2i(4, 2)], [1, K.SOLDIER, Vector2i(9, 9)]])
	_act(L, _id(0, K.REAPER), [Vector2i(4, 1)])
	_check(L.lives[1] == 3 and L.act_hero < 0, "the castle on a diagonal isn't attacked")
	L = _board([[0, K.REAPER, Vector2i(5, 2)], [1, K.SOLDIER, Vector2i(9, 9)]])
	_act(L, _id(0, K.REAPER), [Vector2i(5, 1), Vector2i(5, 0)])
	_check(L.lives[1] == 2, "next to the castle it can strike it like anyone")


func _test_architect() -> void:
	var L := _board([[0, K.ARCHITECT, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(5, 3)], [1, K.SOLDIER, Vector2i(8, 8)], [1, K.PRIEST, Vector2i(0, 1)]])
	var t := L.options_for(_id(0, K.ARCHITECT), K.ARCHITECT, ST.MOVE)
	_check(t.has(Vector2i(5, 9)) and t.has(Vector2i(1, 5)) and t.has(Vector2i(9, 5)) and t.has(Vector2i(1, 1)) and t.has(Vector2i(9, 1))
		and t.has(Vector2i(1, 9)) and t.has(Vector2i(7, 7)) and t.get(Vector2i(5, 5)) == "stay" and t.has(Vector2i(0, 5)) and t.has(Vector2i(0, 10)) and t.has(Vector2i(10, 5)), "architect goes any distance in 8 directions, or stays")
	_check(t.has(Vector2i(5, 4)) and not t.has(Vector2i(5, 3)) and not t.has(Vector2i(5, 2)) and not t.has(Vector2i(8, 8)) and not t.has(Vector2i(9, 9))
		and not t.has(Vector2i(6, 7)) and not t.has(Vector2i(5, 10)), "blocked by heroes and castles, only straight lines")
	# 대각선: 모서리를 돌아가는 두 길이 모두 벽이면 막힘
	L._set_wall(Vector2i(5, 5), Vector2i(6, 5), 1)
	_check(L.options_for(_id(0, K.ARCHITECT), K.ARCHITECT, ST.MOVE).has(Vector2i(6, 4)), "one wall at the corner doesn't stop a diagonal step")
	L._set_wall(Vector2i(5, 5), Vector2i(5, 4), 1)
	t = L.options_for(_id(0, K.ARCHITECT), K.ARCHITECT, ST.MOVE)
	_check(not t.has(Vector2i(6, 4)) and not t.has(Vector2i(7, 3)) and not t.has(Vector2i(5, 4)), "both ways walled → blocked")
	L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._set_wall(Vector2i(5, 5), Vector2i(6, 5), 1)
	L._set_wall(Vector2i(5, 4), Vector2i(6, 4), 1)
	_check(not L.options_for(_id(0, K.ARCHITECT), K.ARCHITECT, ST.MOVE).has(Vector2i(6, 4)), "a straight 2-cell wall blocks the diagonal")
	L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.ARCHITECT), [Vector2i(6, 5)])
	t = L.step_options()
	_check(t.size() == 4 and t.get(Vector2i(6, 4)) == "wall", "wall on any of the 4 edges")
	L.choose(Vector2i(6, 4))
	_check(L.has_wall(Vector2i(6, 5), Vector2i(6, 4)), "wall built")
	L.end_turn()
	L.current = 0
	L.used = 0
	L.acted = 0
	_act(L, _id(0, K.ARCHITECT), [Vector2i(6, 6)])
	_check(not L.step_options().values().has("unwall"), "architect can't remove walls")


func _test_turret() -> void:
	# 빈 칸의 네 변을 모두 아군 벽으로 막으면 그 편의 포탑
	var L := _board([[0, K.ARCHITECT, Vector2i(5, 5)], [1, K.WARRIOR, Vector2i(7, 1)], [1, K.SOLDIER, Vector2i(4, 1)],
		[1, K.ROBOT, Vector2i(3, 4)], [1, K.PRIEST, Vector2i(9, 0)]])
	var house := Vector2i(5, 4)
	L._set_wall(house, Vector2i(4, 4), 0)
	L._set_wall(house, Vector2i(6, 4), 0)
	L._set_wall(house, Vector2i(5, 3), 0)
	var ev := _act(L, _id(0, K.ARCHITECT), [Vector2i(5, 5), house])
	var told := false
	for e in ev:
		told = told or e["t"] == "turret"
	_check(L.turret_at(house) == 0 and told, "4th wall around an empty cell → my turret")
	_check(not L.is_free(house), "nobody can stand on a turret")
	L.end_turn()
	# 포탑은 사신처럼 자동 공격: 주위 8칸에 멈추는 순간 (대각선도), 지나가기만 하면 괜찮음
	_act(L, _id(1, K.SOLDIER), [Vector2i(4, 3)])
	_check(not L.alive(_id(1, K.SOLDIER)) and L.act_hero < 0, "stopping next to it is shot right away (diagonal too)")
	_act(L, _id(1, K.ROBOT), [Vector2i(4, 4)])
	if L.act_hero >= 0:
		L.stop_action()
	_check(L.alive(_id(1, K.ROBOT)) and L.alive(_id(1, K.WARRIOR)), "the robot is immune, a far enemy isn't hit")
	# 배리어를 뚫고 공격. 주인 편은 안 맞음
	L = _board([[0, K.SOLDIER, Vector2i(4, 4)], [1, K.SOLDIER, Vector2i(6, 1)], [1, K.PRIEST, Vector2i(9, 0)]], 1)
	for d in HeroLogic.DIRS4:
		L._set_wall(house, house + d, 0)
	L.turret[L._i(house)] = 1
	L.barrier[_id(1, K.SOLDIER)] = 1
	_act(L, _id(1, K.SOLDIER), [Vector2i(6, 3)])
	_check(not L.alive(_id(1, K.SOLDIER)) and L.act_hero < 0 and L.alive(_id(0, K.SOLDIER)), "a turret shoots through a barrier; the owner's heroes aren't hit")
	# 차례가 바뀔 때는 공격하지 않음
	L = _board([[0, K.SOLDIER, Vector2i(0, 10)], [1, K.SOLDIER, Vector2i(6, 3)], [1, K.PRIEST, Vector2i(9, 0)]])
	for d in HeroLogic.DIRS4:
		L._set_wall(house, house + d, 0)
	L.turret[L._i(house)] = 1
	L.pass_turn()
	L.pass_turn()
	_check(L.alive(_id(1, K.SOLDIER)), "no attack at the turn change")
	# 말 탄 기사도 바로 쓰러짐
	L = _board([[0, K.SOLDIER, Vector2i(0, 10)], [1, K.KNIGHT, Vector2i(6, 1)], [1, K.ANGEL, Vector2i(4, 2)], [1, K.PRIEST, Vector2i(9, 0)]], 1)
	for d in HeroLogic.DIRS4:
		L._set_wall(house, house + d, 0)
	L.turret[L._i(house)] = 1
	L.barrier[_id(1, K.KNIGHT)] = 1
	_act(L, _id(1, K.KNIGHT), [Vector2i(6, 3)])
	_check(not L.alive(_id(1, K.KNIGHT)) and L.has_ghost(_id(1, K.KNIGHT)), "a mounted knight falls at once, barrier or not")
	_act(L, _id(1, K.ANGEL), [Vector2i(4, 3)])
	_check(not L.alive(_id(1, K.ANGEL)) and not L.has_ghost(_id(1, K.ANGEL)), "an angel too, leaving no ghost")
	# 밀려 들어가도, 내려앉은 천사도, 사신도 맞음. 유령은 안 맞음
	L = _board([[0, K.ROBOT, Vector2i(10, 4)], [1, K.SOLDIER, Vector2i(7, 4)], [1, K.PRIEST, Vector2i(9, 0)]])
	for d in HeroLogic.DIRS4:
		L._set_wall(house, house + d, 0)
	L.turret[L._i(house)] = 1
	_act(L, _id(0, K.ROBOT), [Vector2i(8, 4), Vector2i(7, 4)])
	_check(not L.alive(_id(1, K.SOLDIER)) and L.ghost_pos[_id(1, K.SOLDIER)] == Vector2i(6, 4), "pushed next to a turret → shot")
	L = _board([[0, K.KNIGHT, Vector2i(6, 3)], [1, K.ANGEL, Vector2i(6, 1)], [1, K.REAPER, Vector2i(4, 2)], [1, K.PRIEST, Vector2i(9, 0)]], 1)
	for d in HeroLogic.DIRS4:
		L._set_wall(house, house + d, 0)
	L.turret[L._i(house)] = 1
	_act(L, _id(1, K.ANGEL), [Vector2i(6, 3)])
	_check(not L.alive(_id(1, K.ANGEL)) and L.alive(_id(0, K.KNIGHT)) and L.at(Vector2i(6, 3)) == _id(0, K.KNIGHT), "an angel landing there is shot")
	_act(L, _id(1, K.REAPER), [Vector2i(4, 3)])
	_check(not L.alive(_id(1, K.REAPER)), "the reaper too")
	# 포탑이 생길 때 상하좌우에 있던 적도 바로 공격
	L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [1, K.MAGICIAN, Vector2i(4, 4)], [1, K.SOLDIER, Vector2i(6, 4)],
		[1, K.ANGEL, Vector2i(6, 3)], [1, K.PRIEST, Vector2i(9, 0)]])
	L.barrier[_id(1, K.SOLDIER)] = 1
	L._set_wall(house, Vector2i(4, 4), 0)
	L._set_wall(house, Vector2i(6, 4), 0)
	L._set_wall(house, Vector2i(5, 3), 0)
	_act(L, _id(0, K.ARCHITECT), [Vector2i(5, 5), house])
	_check(not L.alive(_id(1, K.MAGICIAN)) and not L.alive(_id(1, K.ANGEL)) and not L.alive(_id(1, K.SOLDIER)), "a new turret shoots the enemies in the 8 cells around, barrier or not")
	# 건축가가 자기 칸을 막으면 그 칸이 포탑이 되고 옆 빈칸을 골라 나옴
	L = _board([[0, K.ARCHITECT, house], [1, K.PRIEST, Vector2i(9, 0)]])
	L._set_wall(house, Vector2i(4, 4), 0)
	L._set_wall(house, Vector2i(6, 4), 0)
	L._set_wall(house, Vector2i(5, 3), 0)
	_act(L, _id(0, K.ARCHITECT), [house, Vector2i(5, 5)])
	var t0 := L.step_options()
	_check(L.turret_at(house) == 0 and L.act_step == ST.EXIT and not L.act_optional, "the architect's own cell becomes a turret")
	_check(t0.size() == 4 and t0.has(Vector2i(5, 3)) and t0.has(Vector2i(4, 4)), "it picks any free cell around the turret")
	L.choose(Vector2i(5, 3))
	_check(L.pos[_id(0, K.ARCHITECT)] == Vector2i(5, 3) and L.at(house) == -1 and L.act_hero < 0, "architect stepped out")
	# 포탑은 로봇만 부술 수 있음 (상대 것도 자기 것도), 네 벽이 한꺼번에 깨짐. 밀기 대신 하나만
	for owner in [0, 1]:
		L = _board([[0, K.ROBOT, Vector2i(6, 8)], [1, K.SOLDIER, Vector2i(7, 4)], [1, K.PRIEST, Vector2i(9, 0)]])
		for d in HeroLogic.DIRS4:
			L._set_wall(house, house + d, owner)
		L.turret[L._i(house)] = owner + 1
		L._set_wall(Vector2i(6, 4), Vector2i(6, 3), 1)
		_act(L, _id(0, K.ROBOT), [Vector2i(6, 5)])
		_check(not L.step_options().values().has("turret"), "only orthogonally next to it")
		L = _board([[0, K.ROBOT, Vector2i(6, 8)], [1, K.SOLDIER, Vector2i(7, 4)], [1, K.PRIEST, Vector2i(9, 0)]])
		for d in HeroLogic.DIRS4:
			L._set_wall(house, house + d, owner)
		L.turret[L._i(house)] = owner + 1
		L._set_wall(Vector2i(6, 4), Vector2i(6, 3), 1)
		_act(L, _id(0, K.ROBOT), [Vector2i(6, 4)])
		var t := L.step_options()
		_check(t.get(house) == "turret" and not t.has(Vector2i(7, 4)) and t.get(Vector2i(6, 3)) == "break", "the robot can break the turret or a wall on any side; the enemy to the side can't be pushed")
		L.choose(house)
		_check(L.turret_at(house) < 0 and L.wall_count() == 1 and L.act_hero < 0, "turret destroyed, all four walls gone at once")
	# 다른 영웅은 포탑을 못 침 (적도 주인도)
	for k in 10:
		for owner in [0, 1]:
			L = _board([[0, k, Vector2i(6, 4)], [0, K.SOLDIER if k != K.SOLDIER else K.KNIGHT, Vector2i(0, 10)], [1, K.SOLDIER, Vector2i(10, 10)]])
			for d in HeroLogic.DIRS4:
				L._set_wall(house, house + d, owner)
			L.turret[L._i(house)] = owner + 1
			L.begin_action(k)
			if L.act_step == ST.MOVE:
				# 멈추면(제자리여도) 상대 포탑에 맞으니, 능력 칸만 봄
				pass
			var o := L.options_for(k, k, HeroLogic.ability_step(k))
			_check((o.get(house) == "turret") == (k == K.ROBOT) and o.get(house) != "break" and not o.has(house + HeroLogic.SIDE),
				"%s and a turret next to it" % HeroLogic.NAMES[k])
	# 로봇 모습 닌자도 부술 수 있음. 옆 포탑과 함께 쓰던 벽은 남음
	L = _board([[0, K.NINJA, Vector2i(6, 4)], [0, K.ROBOT, Vector2i(6, 9)], [1, K.SOLDIER, Vector2i(10, 10)]])
	for h in [house, Vector2i(4, 4)]:
		for d in HeroLogic.DIRS4:
			L._set_wall(h, h + d, 1)
		L.turret[L._i(h)] = 2
	_act(L, _id(0, K.NINJA), [Vector2i(6, 9), Vector2i(6, 4), house])
	_check(L.turret_at(house) < 0 and L.turret_at(Vector2i(4, 4)) == 1 and L.wall_count() == 4, "a ninja in robot form breaks it; a wall shared with another turret stays")
	# 건축가는 8방향으로 막힐 때까지
	L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(10, 10)]])
	var am := L.options_for(_id(0, K.ARCHITECT), K.ARCHITECT, ST.MOVE)
	_check(am.has(Vector2i(5, 1)) and not am.has(Vector2i(5, 0)) and am.has(Vector2i(9, 9)) and am.has(Vector2i(10, 5)) and am.has(Vector2i(1, 5)) and am.has(Vector2i(0, 5)) and not am.has(Vector2i(6, 7)),
		"the architect moves any distance in 8 directions")
	# 안에 있던 다른 영웅은 편과 상관없이 배리어를 무시하고 쓰러짐 (로봇 · 사신도). 유령은 안 생김
	for who in [[0, K.SOLDIER], [1, K.KNIGHT], [1, K.ROBOT], [1, K.REAPER], [0, K.ROBOT]]:
		L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [who[0], who[1], house], [1, K.PRIEST, Vector2i(9, 0)], [1, K.SOLDIER, Vector2i(0, 0)], [0, K.ANGEL, Vector2i(0, 10)]])
		var vic := _id(who[0], who[1])
		L.barrier[vic] = 1
		L._set_wall(house, Vector2i(4, 4), 0)
		L._set_wall(house, Vector2i(6, 4), 0)
		L._set_wall(house, Vector2i(5, 3), 0)
		_act(L, _id(0, K.ARCHITECT), [Vector2i(5, 5), house])
		_check(L.turret_at(house) == 0 and not L.alive(vic) and not L.has_ghost(vic) and L.at(house) < 0 and L.act_hero < 0,
			"a hero inside falls (barrier or not) and the turret is built, no ghost: %s" % HeroLogic.NAMES[who[1]])
	# 포탑이 무너져도 부활할 수 없음
	L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [1, K.KNIGHT, house], [1, K.ANGEL, Vector2i(5, 1)], [1, K.SOLDIER, Vector2i(3, 4)]])
	L._set_wall(house, Vector2i(4, 4), 0)
	L._set_wall(house, Vector2i(6, 4), 0)
	L._set_wall(house, Vector2i(5, 3), 0)
	_act(L, _id(0, K.ARCHITECT), [Vector2i(5, 5), house])
	L.end_turn()
	_check(L.current == 1 and not L.selectable().has(_id(1, K.KNIGHT)), "no ghost to move")
	L._strike(_id(1, K.ANGEL), house, "turret")
	_act(L, _id(1, K.ANGEL), [house])
	_check(L.turret_at(house) < 0 and L.act_step != ST.REVIVE and not L.alive(_id(1, K.KNIGHT)), "gone for good even when the turret falls")
	# 저주 걸어 둔 사신이 갇히면 저주도 사라지고, 전사가 갇히면 무력도 풀림
	L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [1, K.REAPER, house], [0, K.KNIGHT, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.cursed_by[_id(0, K.KNIGHT)] = _id(1, K.REAPER)
	L._set_wall(house, Vector2i(4, 4), 0)
	L._set_wall(house, Vector2i(6, 4), 0)
	L._set_wall(house, Vector2i(5, 3), 0)
	_act(L, _id(0, K.ARCHITECT), [Vector2i(5, 5), house])
	_check(L.cursed_by[_id(0, K.KNIGHT)] < 0, "its curses go with it")
	# 건축가는 성을 칠 수 없음. 성 쪽 변에도 벽을 세울 수 있음
	for wall in [-1, 0, 1]:
		L = _board([[0, K.ARCHITECT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
		if wall >= 0:
			L._set_wall(Vector2i(5, 1), Vector2i(5, 0), wall)
		_act(L, _id(0, K.ARCHITECT), [Vector2i(5, 1)])
		_check(L.step_options().get(Vector2i(5, 0), "") == ("" if wall >= 0 else "wall") and L.step_options().get(Vector2i(4, 1)) == "wall" and not L.step_options().values().has("castle"),
			"an architect can't hit the castle (wall owner %d)" % wall)
		L.choose(Vector2i(5, 0) if wall < 0 else Vector2i(4, 1))
		_check(L.lives[1] == 3 and L.act_hero < 0 and L.wall_count() == (2 if wall >= 0 else 1), "it builds a wall there instead (wall owner %d)" % wall)
	L = _board([[0, K.ARCHITECT, Vector2i(5, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_check(L.options_for(_id(0, K.ARCHITECT), K.ARCHITECT, ST.WALL).get(Vector2i(5, 10)) == "wall", "a wall on my own castle's side is fine")
	L = _board([[0, K.NINJA, Vector2i(5, 1)], [0, K.ARCHITECT, Vector2i(5, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.NINJA), [Vector2i(5, 9), Vector2i(5, 1)])
	_check(L.act_step == ST.WALL and not L.step_options().values().has("castle"), "a ninja in architect form can't either")
	# 유령이 있는 칸은 그대로 벽만
	L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [1, K.KNIGHT, house], [1, K.PRIEST, Vector2i(9, 0)]])
	L._kill(_id(1, K.KNIGHT), "attack")
	L._set_wall(house, Vector2i(4, 4), 0)
	L._set_wall(house, Vector2i(6, 4), 0)
	L._set_wall(house, Vector2i(5, 3), 0)
	_act(L, _id(0, K.ARCHITECT), [Vector2i(5, 5), house])
	_check(L.turret_at(house) < 0 and L.wall_count() == 4 and L.has_ghost(_id(1, K.KNIGHT)), "a ghost inside → just walls, no turret")


## 건축가는 행동 2개를 모두 쓸 수 있음 (다른 영웅은 한 번, 닌자가 따라 해도 한 번)
func _test_architect_twice() -> void:
	var ar := _id(0, K.ARCHITECT)
	var L := _board([[0, K.ARCHITECT, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, ar, [Vector2i(5, 5), Vector2i(5, 4)])
	_check(L.current == 0 and L.used == 1 and L.selectable().has(ar) and not L.has_acted(ar), "the architect can act again")
	_act(L, ar, [Vector2i(4, 4), Vector2i(4, 3)])
	_check(L.current == 1 and L.wall_count() == 2, "both actions are its own, then the turn ends")
	L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, ar, [Vector2i(5, 5), Vector2i(5, 4)])
	_act(L, _id(0, K.SOLDIER), [Vector2i(9, 9), STOP])
	_check(L.current == 1, "or one by another hero")
	L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.SOLDIER), [Vector2i(9, 9), STOP])
	_check(not L.selectable().has(_id(0, K.SOLDIER)) and L.selectable().has(ar), "others act once")
	_act(L, ar, [Vector2i(5, 5), Vector2i(5, 4)])
	_check(L.current == 1, "two actions a turn in all")
	# 한 차례에 벽 두 개로 포탑 완성 (적을 가둠)
	L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._set_wall(Vector2i(5, 4), Vector2i(5, 3), 0)
	L._set_wall(Vector2i(5, 4), Vector2i(4, 4), 0)
	_act(L, ar, [Vector2i(5, 5), Vector2i(5, 4)])
	_act(L, ar, [Vector2i(6, 4), Vector2i(5, 4)])
	_check(L.turret_at(Vector2i(5, 4)) == 0 and not L.alive(_id(1, K.KNIGHT)), "two walls in one turn")
	# 첫 행동에 쓰러지면 유령으로 또 행동하지는 못함, 봉인돼도 두 번 움직일 수는 있음
	L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.mines[L._i(Vector2i(7, 5))] = 2
	_act(L, ar, [Vector2i(7, 5)])
	_check(L.has_ghost(ar) and not L.selectable().has(ar) and L.current == 0, "a fallen one can't act again as a ghost")
	L = _board([[0, K.ARCHITECT, Vector2i(5, 5)], [0, K.PRIEST, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L.sealed[ar] = 1
	_act(L, ar, [Vector2i(6, 5)])
	_check(L.selectable().has(ar), "sealed: it may still move twice")
	# 닌자가 따라 해도 한 번
	L = _board([[0, K.NINJA, Vector2i(3, 8)], [0, K.ARCHITECT, Vector2i(3, 3)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.NINJA), [Vector2i(3, 3), Vector2i(3, 8), Vector2i(3, 7)])
	_check(L.used == 1 and not L.selectable().has(_id(0, K.NINJA)), "a ninja in architect form acts once")


## 로봇 · 건축가 · 닌자가 아닌 영웅은 옆의 상대 성을 늘 칠 수 있고(적군의 벽이 없으면), 벽은 로봇만 부술 수 있음
func _test_siege_all() -> void:
	for k in 10:
		for wall in [-1, 0, 1]:
			for d in HeroLogic.DIRS4:
				var n: Vector2i = HeroLogic.CASTLE[1]
				var at_c: Vector2i = n - d
				if at_c.y < 0:
					continue
				var L := _board([[0, k, at_c], [0, K.SOLDIER if k != K.SOLDIER else K.KNIGHT, Vector2i(0, 10)], [1, K.SOLDIER, Vector2i(10, 10)]])
				if wall >= 0:
					L._set_wall(at_c, n, wall)
				L.begin_action(k)
				if L.act_step == ST.MOVE:
					L.choose(at_c)
				var t := L.step_options()
				if k == K.ROBOT:
					_check(not t.values().has("castle") and t.get(n, "") == ("break" if wall >= 0 else ""), "the robot can't hit the castle, only break a wall")
					continue
				if k == K.NINJA:
					_check(L.act_hero < 0, "a ninja has nothing to do next to the castle")
					continue
				if k == K.ARCHITECT:
					_check(not t.values().has("castle") and t.get(n, "") == ("" if wall >= 0 else "wall"), "the architect can't hit the castle")
					continue
				if wall == 1:
					_check(not t.values().has("castle"), "%s can't hit the castle over an enemy wall" % HeroLogic.NAMES[k])
					continue
				_check(t.get(n) == "castle" and not t.has(n + HeroLogic.SIDE), "%s can hit the castle next to it (wall %d)" % [HeroLogic.NAMES[k], wall])
				L.choose(n)
				_check(L.lives[1] == 2 and L.wall_count() == (1 if wall >= 0 else 0), "castle hit by %s, the wall stays" % HeroLogic.NAMES[k])
	_test_wall_attacks()
	# 로봇만 벽을 부숨 (누구 것이든). 다른 영웅은 벽 쪽에 아무 표시도 없음(병사의 지뢰 · 전사의 전진 · 건축가의 벽 세우기는 따로)
	for k in 10:
		for owner in 2:
			var M := _board([[0, k, Vector2i(5, 5)], [0, K.SOLDIER if k != K.SOLDIER else K.KNIGHT, Vector2i(0, 10)], [1, K.SOLDIER, Vector2i(10, 10)]])
			M._set_wall(Vector2i(5, 5), Vector2i(4, 5), owner)
			M._set_wall(Vector2i(5, 5), Vector2i(5, 4), owner)
			M.begin_action(k)
			if M.act_step == ST.MOVE:
				M.choose(Vector2i(5, 5))
			var o := M.step_options()
			if k != K.ROBOT:
				_check(not o.values().has("break"), "%s can't break a wall" % HeroLogic.NAMES[k])
				if k == K.ARCHITECT:
					_check(not o.has(Vector2i(4, 5)) and o.get(Vector2i(6, 5)) == "wall", "the architect builds on open edges only")
				continue
			_check(o.get(Vector2i(4, 5)) == "break" and o.get(Vector2i(5, 4)) == "break" and o.size() == 2, "the robot can break walls next to it")
			M.choose(Vector2i(4, 5))
			_check(not M.has_wall(Vector2i(5, 5), Vector2i(4, 5)) and M.has_wall(Vector2i(5, 5), Vector2i(5, 4)) and M.act_hero < 0, "only that wall")
	# 병사: 벽 너머 빈칸에는 지뢰도 놓을 수 있음
	var N := _board([[0, K.SOLDIER, Vector2i(5, 5)], [1, K.KNIGHT, Vector2i(0, 0)]])
	N._set_wall(Vector2i(5, 5), Vector2i(5, 4), 1)
	_act(N, _id(0, K.SOLDIER), [Vector2i(5, 5), Vector2i(5, 4)])
	_check(N.mine_at(Vector2i(5, 4)) == 0 and N.wall_count() == 1, "a mine over a wall")
	# 로봇 모습 닌자도 벽을 부숨
	N = _board([[0, K.NINJA, Vector2i(5, 8)], [0, K.ROBOT, Vector2i(5, 3)], [1, K.SOLDIER, Vector2i(0, 0)]])
	N._set_wall(Vector2i(5, 8), Vector2i(6, 8), 1)
	_act(N, _id(0, K.NINJA), [Vector2i(5, 3), Vector2i(5, 8), Vector2i(6, 8)])
	_check(N.wall_count() == 0, "a ninja in robot form breaks a wall")


## 적군의 벽은 상하좌우 공격을 막고, 대각선 공격(사신 · 흑기사의 대각선 · 포탑)은 못 막음. 내 벽은 내 공격을 안 막음
func _test_wall_attacks() -> void:
	var kn := _id(0, K.KNIGHT)
	for owner in 2:
		# 병사 · 전사 · 성직자
		for k in [K.SOLDIER, K.WARRIOR, K.PRIEST]:
			var A := _board([[0, k, Vector2i(5, 5)], [0, K.ROBOT, Vector2i(0, 9)], [1, K.MAGICIAN, Vector2i(5, 4)], [1, K.ANGEL, Vector2i(9, 0)]])
			A._set_wall(Vector2i(5, 5), Vector2i(5, 4), owner)
			_act(A, _id(0, k), [Vector2i(5, 5)])
			_check((A.step_options().get(Vector2i(5, 4), "") == "attack") == (owner == 0), "%s attacks over my wall only" % HeroLogic.NAMES[k])
		# 흑기사: 상하좌우는 적군의 벽에 막히고 대각선은 됨
		var L := _board([[0, K.KNIGHT, Vector2i(5, 5)], [0, K.ROBOT, Vector2i(0, 9)], [1, K.SOLDIER, Vector2i(5, 4)], [1, K.PRIEST, Vector2i(6, 4)], [1, K.ANGEL, Vector2i(9, 0)]])
		L.dark[kn] = 1
		for d in HeroLogic.DIRS4:
			L._set_wall(Vector2i(5, 5), Vector2i(5, 5) + d, owner)
		_act(L, kn, [Vector2i(5, 5)])
		var t := L.step_options()
		_check(t.get(Vector2i(6, 4)) == "sweep" and t.has(Vector2i(5, 4)) == (owner == 0), "a sweep: the diagonal always, the side over my wall only")
		L.choose(Vector2i(6, 4))
		_check(not L.alive(_id(1, K.PRIEST)) and L.alive(_id(1, K.SOLDIER)) == (owner == 1), "and it hits just those")
		# 사신의 자동 공격은 안 막힘
		L = _board([[0, K.REAPER, Vector2i(5, 7)], [0, K.ROBOT, Vector2i(0, 9)], [1, K.SOLDIER, Vector2i(6, 5)], [1, K.ANGEL, Vector2i(9, 0)]])
		for d in HeroLogic.DIRS4:
			L._set_wall(Vector2i(5, 6), Vector2i(5, 6) + d, owner)
			L._set_wall(Vector2i(6, 5), Vector2i(6, 5) + d, owner)
		L._set_wall(Vector2i(5, 7), Vector2i(5, 6), owner)
		_act(L, _id(0, K.REAPER), [Vector2i(5, 6)])
		_check(not L.alive(_id(1, K.SOLDIER)), "walls don't stop the reaper's own attack")
		# 포탑도 대각선 · 상하좌우 모두 공격함 (네 벽은 포탑 주인의 것)
		for spot: Vector2i in [Vector2i(5, 4), Vector2i(6, 4)]:
			L = _board([[1, K.SOLDIER, Vector2i(5, 7)], [1, K.PRIEST, Vector2i(9, 1)], [0, K.ROBOT, Vector2i(0, 9)]], 1)
			L.turret[L._i(Vector2i(5, 5))] = 1
			for d in HeroLogic.DIRS4:
				L._set_wall(Vector2i(5, 5), Vector2i(5, 5) + d, 0)
			L._set_wall(spot, spot + Vector2i(1, 0), owner)
			L._relocate(_id(1, K.SOLDIER), spot)
			L._arrive(_id(1, K.SOLDIER))
			_check(not L.alive(_id(1, K.SOLDIER)), "a turret's attack isn't stopped")


func _test_siege() -> void:
	_test_siege_all()
	_test_architect_twice()
	var L := _board([[0, K.PRIEST, Vector2i(5, 2)], [0, K.KNIGHT, Vector2i(3, 0)], [0, K.ANGEL, Vector2i(3, 5)],
		[0, K.ROBOT, Vector2i(8, 5)], [1, K.SOLDIER, Vector2i(9, 9)]])
	_act(L, _id(0, K.PRIEST), [Vector2i(5, 1)])
	_check(L.step_options().get(Vector2i(5, 0)) == "castle", "a priest right below the castle can hit it")
	L.choose(Vector2i(5, 0))
	_check(L.lives[1] == 2, "castle hit by the priest")
	_act(L, _id(0, K.KNIGHT), [Vector2i(4, 0)])
	_check(L.step_options().get(Vector2i(5, 0)) == "castle", "knight can hit the castle at its side too")
	# 닌자는 성을 못 침: 그냥 움직인 뒤에도, 무엇을 따라 해도 (파이어볼 · 내려앉은 천사 모습도)
	L = _board([[0, K.NINJA, Vector2i(5, 2)], [1, K.SOLDIER, Vector2i(9, 9)]])
	_act(L, _id(0, K.NINJA), [Vector2i(5, 1)])
	_check(L.act_hero < 0 and L.lives[1] == 3, "ninja's plain move ends right away")
	for k in 10:
		if k == K.NINJA:
			continue
		L = _board([[0, K.NINJA, Vector2i(4, 3)], [0, k, Vector2i(4, 9)], [0, K.PRIEST if k != K.PRIEST else K.SOLDIER, Vector2i(9, 9)], [1, K.SOLDIER, Vector2i(9, 4)]])
		_act(L, _id(0, K.NINJA), [Vector2i(4, 9)])
		for st in [ST.CARRY, ST.STRIKE, ST.MINE, ST.SWAP_FIRE, ST.BARRIER, ST.PUSH, ST.WARRIOR, ST.REAP, ST.WALL, ST.LAND]:
			for spot: Vector2i in [Vector2i(4, 0), Vector2i(5, 1), Vector2i(5, 3)]:
				L._relocate(_id(0, K.NINJA), spot)
				L.act_dir = Vector2i(0, -1)
				_check(not L.options_for(_id(0, K.NINJA), k, st).values().has("castle"), "a ninja as %s can't hit the castle (step %d)" % [HeroLogic.NAMES[k], st])


func _test_summon() -> void:
	var L := _board([[0, K.KNIGHT, Vector2i(3, 1)], [0, K.REAPER, Vector2i(4, 1)], [0, K.ROBOT, Vector2i(6, 2)],
		[0, K.SOLDIER, Vector2i(2, 5)], [0, K.ANGEL, Vector2i(7, 9)], [1, K.SOLDIER, Vector2i(9, 4)]])
	var ids := L.summon_ids()
	_check(ids.has(_id(0, K.KNIGHT)) and ids.has(_id(0, K.SOLDIER)), "my heroes can be summoned")
	_check(ids.has(_id(0, K.ANGEL)), "wherever they are")
	_check(ids.has(_id(0, K.REAPER)) and not ids.has(_id(0, K.ROBOT)), "the reaper can be summoned, the robot can't")
	_check(not ids.has(_id(1, K.SOLDIER)), "not enemy heroes")
	var cells := L.summon_cells()
	_check(cells.size() == 5 and cells.has(Vector2i(5, 9)) and cells.has(Vector2i(4, 10)) and cells.has(Vector2i(6, 10))
		and cells.has(Vector2i(4, 9)) and cells.has(Vector2i(6, 9)), "summon onto the 5 cells around my castle")
	_check(not cells.has(Vector2i(0, 8)) and not cells.has(Vector2i(3, 9)), "not other cells")
	L.do_summon(_id(0, K.KNIGHT), Vector2i(3, 8))
	_check(L.pos[_id(0, K.KNIGHT)] == Vector2i(3, 1), "a cell away from the castle is refused")
	L.do_summon(_id(0, K.KNIGHT), Vector2i(5, 9))
	_check(L.pos[_id(0, K.KNIGHT)] == Vector2i(5, 9) and L.at(Vector2i(3, 1)) == -1, "knight pulled back next to my castle")
	_check(L.current == 0 and L.used == 1 and L.lives[0] == 2 and L.lives[1] == 3, "a summon takes one action and one heart of my castle")
	# 불러온 영웅도 남은 행동으로 움직임
	_check(L.selectable().has(_id(0, K.KNIGHT)), "the summoned hero can still act")
	_act(L, _id(0, K.KNIGHT), [Vector2i(5, 8)])
	if L.act_hero >= 0:
		L.stop_action()
	_check(L.current == 1 and L.pos[_id(0, K.KNIGHT)] == Vector2i(5, 8), "then the turn is over")
	# 한 차례에 두 번도 됨, 이미 움직인 영웅도 부름. 하트가 1개면 못 부름
	L = _board([[0, K.KNIGHT, Vector2i(3, 1)], [0, K.SOLDIER, Vector2i(2, 5)], [1, K.SOLDIER, Vector2i(9, 4)]])
	var evs := L.do_summon(_id(0, K.KNIGHT), Vector2i(5, 9))
	_check(evs[0]["t"] == "summon" and int(evs[0]["left"]) == 2 and L.summon_ids().has(_id(0, K.SOLDIER)), "a second summon is possible")
	L.do_summon(_id(0, K.SOLDIER), Vector2i(4, 9))
	_check(L.lives[0] == 1 and L.current == 1 and L.pos[_id(0, K.SOLDIER)] == Vector2i(4, 9), "two summons: two hearts, the turn is over")
	L.pass_turn()
	_check(L.summon_ids().is_empty() and L.current == 0, "not with one heart left")
	L.do_summon(_id(0, K.KNIGHT), Vector2i(6, 9))
	_check(L.lives[0] == 1 and L.pos[_id(0, K.KNIGHT)] == Vector2i(5, 9), "refused")
	L = _board([[0, K.KNIGHT, Vector2i(3, 4)], [0, K.SOLDIER, Vector2i(2, 5)], [1, K.SOLDIER, Vector2i(9, 4)]])
	_act(L, _id(0, K.KNIGHT), [Vector2i(3, 3), STOP])
	_check(L.used == 1 and L.current == 0 and L.summon_ids().has(_id(0, K.KNIGHT)) and L.summon_ids().has(_id(0, K.SOLDIER)), "a hero that has acted can be called too")
	L.do_summon(_id(0, K.KNIGHT), Vector2i(5, 9))
	_check(L.pos[_id(0, K.KNIGHT)] == Vector2i(5, 9) and L.lives[0] == 2 and L.current == 1, "as the second action")
	# 움직일 영웅이 없어도 부를 수 있으면 차례가 저절로 끝나지 않음 (무력에 걸린 아군을 부름). 하트가 1개면 끝남
	for hearts in [2, 1]:
		L = _board([[0, K.SOLDIER, Vector2i(2, 5)], [0, K.KNIGHT, Vector2i(5, 4)], [1, K.WARRIOR, Vector2i(5, 3)], [1, K.PRIEST, Vector2i(9, 0)]])
		L.lives[0] = hearts
		_act(L, _id(0, K.SOLDIER), [Vector2i(2, 4)])
		if L.act_hero >= 0:
			L.stop_action()
		_check(L.current == (0 if hearts == 2 else 1), "the turn waits for a summon only when one is possible (hearts %d)" % hearts)
		if hearts == 2:
			L.do_summon(_id(0, K.KNIGHT), Vector2i(5, 9))
			_check(L.disabled_by[_id(0, K.KNIGHT)] < 0 and L.current == 1, "the disabled ally is called back")
	# 부를 때 쓰인 하트로는 지지 않음 (하트 2개 → 1개)
	L = _board([[0, K.KNIGHT, Vector2i(3, 1)], [0, K.SOLDIER, Vector2i(2, 5)], [1, K.SOLDIER, Vector2i(9, 4)]])
	L.lives[0] = 2
	L.do_summon(_id(0, K.KNIGHT), Vector2i(5, 9))
	_check(not L.over and L.lives[0] == 1 and L.used == 1, "down to one heart, the game goes on")
	L.do_summon(_id(0, K.SOLDIER), Vector2i(4, 9))
	_check(L.pos[_id(0, K.SOLDIER)] == Vector2i(2, 5) and L.lives[0] == 1, "no more")
	# 성 옆이 막혀 있으면 (아군 · 적 지뢰) 소환 못 함
	L = _board([[0, K.KNIGHT, Vector2i(3, 1)], [0, K.SOLDIER, Vector2i(5, 9)], [0, K.ANGEL, Vector2i(4, 10)],
		[0, K.PRIEST, Vector2i(4, 9)], [0, K.MAGICIAN, Vector2i(6, 9)], [1, K.SOLDIER, Vector2i(9, 4)]])
	L.mines[L._i(Vector2i(6, 10))] = 2
	_check(L.summon_cells().is_empty(), "no free cell next to the castle → no summon cell")
	L = _board([[0, K.SOLDIER, Vector2i(2, 5)], [0, K.KNIGHT, Vector2i(4, 1)], [0, K.ANGEL, Vector2i(7, 5)],
		[1, K.SOLDIER, Vector2i(9, 4)]])
	_act(L, _id(0, K.SOLDIER), [Vector2i(2, 3), STOP])
	_check(not L.summon_ids().is_empty(), "a summon after a hero acted is fine")
	# 유령(쓰러진 영웅)은 소환 못 함
	L = _board([[0, K.SOLDIER, Vector2i(2, 5)], [0, K.KNIGHT, Vector2i(4, 1)], [1, K.SOLDIER, Vector2i(9, 4)]])
	L._kill(_id(0, K.KNIGHT), "attack")
	_check(not L.summon_ids().has(_id(0, K.KNIGHT)) and L.summon_ids().has(_id(0, K.SOLDIER)), "ghosts can't be summoned")


func _test_castle() -> void:
	var L := _board([[0, K.KNIGHT, Vector2i(3, 1)], [0, K.WARRIOR, Vector2i(5, 2)], [0, K.SOLDIER, Vector2i(6, 2)],
		[1, K.ROBOT, Vector2i(0, 10)]])
	L.begin_action(_id(0, K.KNIGHT))
	L.choose(Vector2i(4, 1))
	_check(not L.step_options().has(Vector2i(5, 0)), "diagonal neighbour isn't in the knight's attack range")
	L.stop_action()
	_act(L, _id(0, K.WARRIOR), [Vector2i(5, 1), Vector2i(5, 0)])
	_check(L.lives[1] == 2, "warrior hits the castle right in front")
	_check(L.pos[_id(0, K.WARRIOR)] == Vector2i(5, 1), "attacker stays")
	L = _board([[0, K.WARRIOR, Vector2i(6, 2)], [1, K.ROBOT, Vector2i(0, 10)]])
	L.begin_action(_id(0, K.WARRIOR))
	L.choose(Vector2i(6, 1))
	_check(L.act_hero < 0 or not L.step_options().has(Vector2i(5, 0)), "warrior can't hit a diagonal castle")


func _test_collapse() -> void:
	var L := _board([[0, K.ROBOT, Vector2i(0, 10)], [1, K.ROBOT, Vector2i(10, 0)]])
	var guard := 0
	while not L.over and guard < 400:
		guard += 1
		var id := L.selectable()[0]
		L.begin_action(id)
		var opts := L.step_options()
		L.choose(opts.keys()[0])
		if not L.over and L.act_hero >= 0:
			L.stop_action()
		if not L.over and L.used > 0 and L.act_hero < 0 and L.current == HeroLogic.owner_of(id):
			L.end_turn()
	_check(L.over and L.end_reason == "collapse", "collapse ends a stalled game (%s at turn %d)" % [L.end_reason, L.turn])
	_check(L.turn <= HeroLogic.COLLAPSE_START + HeroLogic.COLLAPSE_EVERY * (HeroLogic.START_LIVES - 1), "collapse timing")
	# 한쪽이 3명 이하이고 3명 이상 차이 나면 결전을 건너뜀
	L = _board([[0, K.ROBOT, Vector2i(0, 10)], [0, K.SOLDIER, Vector2i(1, 10)], [0, K.KNIGHT, Vector2i(2, 10)],
		[0, K.PRIEST, Vector2i(3, 10)], [1, K.ROBOT, Vector2i(10, 0)]])
	_check(L.collapse_paused(), "4 vs 1 → collapse paused")
	L.turn = HeroLogic.COLLAPSE_START - 1
	L.pass_turn()
	_check(L.lives[0] == 3 and L.lives[1] == 3 and L.collapse_skipped and not L.collapsed_now, "the collapse is skipped")
	L = _board([[0, K.ROBOT, Vector2i(0, 10)], [0, K.SOLDIER, Vector2i(1, 10)], [0, K.KNIGHT, Vector2i(2, 10)],
		[1, K.ROBOT, Vector2i(10, 0)]])
	_check(not L.collapse_paused(), "3 vs 1 (gap 2) → collapse goes on")


## AI 끼리 대결 (a = 첫 판 선공, 번갈아 가며)
func _match(a: int, b: int, games: int) -> void:
	var wins := [0, 0, 0]
	var total_turns := 0
	var slow := 0
	var reasons := {}
	for g in games:
		var L := HeroLogic.new()
		L.setup(g % 2)
		var ais := [HeroAI.new(a), HeroAI.new(b)]
		var side_a := g % 2   # a 가 맡는 플레이어
		if side_a == 1:
			ais = [HeroAI.new(b), HeroAI.new(a)]
		for p in 2:
			(ais[p] as HeroAI).choose_formation(L, p)
		L.start_play()
		var guard := 0
		while not L.over and guard < 400:
			guard += 1
			var p := L.current
			var t0 := Time.get_ticks_msec()
			var plan: Array = (ais[p] as HeroAI).plan(L)
			slow = maxi(slow, Time.get_ticks_msec() - t0)
			if plan.is_empty():
				_check(false, "AI found nothing to do")
				break
			for step in plan:
				var s: Dictionary = step
				if s.has("summon"):
					L.do_summon(s["summon"], s["cell"])
					continue
				var taps: Array = s["taps"]
				if not L.begin_action(taps[0]):
					_check(false, "AI plan invalid (begin)")
					break
				for i in range(1, taps.size()):
					if taps[i] == HeroLogic.STOP:
						L.stop_action()
					else:
						L.choose(taps[i])
				if L.act_hero >= 0:
					_check(false, "AI plan left an action unfinished")
					L.stop_action()
					L.cancel_action()
			if not L.over and L.current == p and L.used > 0:
				L.end_turn()
			if not L.over and L.current == p and L.used == 0 and L.turn == 0:
				_check(false, "turn didn't advance")
				break
		total_turns += L.turn
		reasons[L.end_reason] = int(reasons.get(L.end_reason, 0)) + 1
		if L.winner < 0:
			wins[2] += 1
		elif L.winner == side_a:
			wins[0] += 1
		else:
			wins[1] += 1
	print("  AI Lv%d vs Lv%d: %d-%d (draw %d), avg %d turns, slowest plan %d ms, %s" % [
		a, b, wins[0], wins[1], wins[2], total_turns / games, slow, reasons])


## 마법사의 봉인: 자리를 바꾼 뒤 옮긴 자리 주위 8칸의 적 한 명, 그 편의 다음 차례가 끝날 때까지 이동만
func _test_seal() -> void:
	var set_up := [[0, K.MAGICIAN, Vector2i(9, 9)], [0, K.SOLDIER, Vector2i(5, 5)], [1, K.KNIGHT, Vector2i(4, 4)], [1, K.REAPER, Vector2i(6, 5)],
		[1, K.ROBOT, Vector2i(5, 4)], [1, K.WARRIOR, Vector2i(5, 7)], [1, K.ANGEL, Vector2i(6, 4)]]
	var L := _board(set_up)
	_act(L, _id(0, K.MAGICIAN), [Vector2i(5, 5)])
	var t := L.step_options()
	_check(t.get(Vector2i(4, 4)) == "seal" and t.get(Vector2i(6, 4)) == "seal" and t.get(Vector2i(6, 5)) == "seal" and t.get(Vector2i(5, 4)) == "seal" and not t.has(Vector2i(5, 7)),
		"seal: an enemy in the 8 cells around its new cell (the robot and the reaper too), not 2 cells away")
	L.choose(Vector2i(4, 4))
	_check(L.sealed[_id(1, K.KNIGHT)] == 1 and L.act_hero < 0, "sealed, the action is over")
	var h := L.state_hash()
	var C := L.clone()
	_check(C.sealed[_id(1, K.KNIGHT)] == 1 and C.state_hash() == h, "kept in copies and the state hash")
	C.sealed[_id(1, K.KNIGHT)] = 0
	_check(C.state_hash() != h, "part of the state")
	L.end_turn()
	# 이동은 되고 능력은 안 됨
	_act(L, _id(1, K.KNIGHT), [Vector2i(3, 4)])
	_check(L.pos[_id(1, K.KNIGHT)] == Vector2i(3, 4) and L.act_hero < 0 and L.used == 1, "a sealed hero moves but has no ability step")
	L.end_turn()
	_check(L.sealed[_id(1, K.KNIGHT)] == 0, "gone when its side's turn is over")
	# 봉인은 안 해도 됨, 배리어와 상관없음, 아군 유령과 바꾼 뒤에도
	L = _board([[0, K.MAGICIAN, Vector2i(9, 9)], [0, K.SOLDIER, Vector2i(5, 5)], [0, K.KNIGHT, Vector2i(0, 10)], [1, K.KNIGHT, Vector2i(4, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(_id(0, K.SOLDIER), "attack")
	L.barrier[_id(1, K.KNIGHT)] = 1
	_act(L, _id(0, K.MAGICIAN), [Vector2i(5, 5)])
	_check(L.act_step == ST.SEAL and L.act_optional and L.step_options().get(Vector2i(4, 4)) == "seal", "also after swapping with a ghost, a barrier doesn't stop it")
	var N := L.clone()
	N.stop_action()
	_check(N.act_hero < 0 and N.sealed[_id(1, K.KNIGHT)] == 0, "it may skip sealing")
	L.choose(Vector2i(4, 4))
	_check(L.sealed[_id(1, K.KNIGHT)] == 1 and L.barrier[_id(1, K.KNIGHT)] == 1, "sealed, the barrier stays")
	# 파이어볼을 쏘면 봉인 없음, 주위에 적이 없으면 바로 끝
	L = _board([[0, K.MAGICIAN, Vector2i(5, 5)], [0, K.SOLDIER, Vector2i(9, 9)], [1, K.KNIGHT, Vector2i(5, 3)], [1, K.SOLDIER, Vector2i(4, 4)]])
	var M := L.clone()
	_act(L, _id(0, K.MAGICIAN), [Vector2i(5, 3)])
	_check(L.act_hero < 0, "no seal with a fireball")
	_act(M, _id(0, K.MAGICIAN), [Vector2i(9, 9)])
	_check(M.act_hero < 0 and M.pos[_id(0, K.MAGICIAN)] == Vector2i(9, 9), "nobody around → the action just ends")
	# 옮긴 자리가 적 전사 주위 8칸이면 무력해져 봉인을 못 함
	L = _board([[0, K.MAGICIAN, Vector2i(9, 9)], [0, K.SOLDIER, Vector2i(5, 5)], [1, K.WARRIOR, Vector2i(4, 4)], [1, K.KNIGHT, Vector2i(6, 5)]])
	_act(L, _id(0, K.MAGICIAN), [Vector2i(5, 5)])
	_check(L.act_hero < 0 and L.disabled_by[_id(0, K.MAGICIAN)] >= 0, "disabled beside an enemy warrior → no seal")
	# 봉인된 영웅마다: 이동 뒤 능력 · 벽 치기 X, 마법사는 아무것도 못 함, 닌자는 따라 하기 X, 천사는 내려앉기 · 부활 X, 전사의 무력은 그대로
	for k in 10:
		if k == K.ROBOT:
			continue
		L = _board([[0, k, Vector2i(5, 5)], [0, K.SOLDIER if k != K.SOLDIER else K.KNIGHT, Vector2i(5, 8)], [1, K.KNIGHT, Vector2i(5, 4)], [1, K.SOLDIER, Vector2i(10, 10)]])
		L._set_wall(Vector2i(5, 5), Vector2i(4, 5), 1)
		L.sealed[k] = 1
		L._update_disabled()
		if k == K.MAGICIAN:
			_check(not L.can_act(k), "a sealed magician can't act (it has no move)")
			continue
		L.begin_action(k)
		var marks := L.step_options().values()
		_check(not marks.has("copy") and not marks.has("land"), "%s: no copying, no landing while sealed" % HeroLogic.NAMES[k])
		L.choose(Vector2i(5, 5))
		_check(L.act_hero < 0 and L.alive(_id(1, K.KNIGHT)) and L.wall_count() == 1, "%s: no ability, no wall breaking while sealed" % HeroLogic.NAMES[k])
		if k == K.WARRIOR:
			_check(L.disabled_by[_id(1, K.KNIGHT)] == k, "a sealed warrior still disables")
	L = _board([[0, K.ANGEL, Vector2i(5, 7)], [0, K.KNIGHT, Vector2i(5, 5)], [1, K.SOLDIER, Vector2i(0, 0)]])
	L._kill(_id(0, K.KNIGHT), "attack")
	L.sealed[_id(0, K.ANGEL)] = 1
	_check(not L.options_for(_id(0, K.ANGEL), K.ANGEL, ST.MOVE).has(Vector2i(5, 5)), "a sealed angel can't revive")
	# 쓰러지면 봉인도 사라짐
	L.sealed[_id(0, K.ANGEL)] = 1
	L._kill(_id(0, K.ANGEL), "attack")
	_check(L.sealed[_id(0, K.ANGEL)] == 0, "gone when the hero falls")
	# 마법사를 따라 한 닌자도
	L = _board([[0, K.NINJA, Vector2i(3, 8)], [0, K.MAGICIAN, Vector2i(3, 5)], [0, K.SOLDIER, Vector2i(7, 5)], [1, K.KNIGHT, Vector2i(6, 4)], [1, K.SOLDIER, Vector2i(0, 0)]])
	_act(L, _id(0, K.NINJA), [Vector2i(3, 5), Vector2i(7, 5), Vector2i(6, 4)])
	_check(L.sealed[_id(1, K.KNIGHT)] == 1 and L.act_hero < 0, "a ninja in magician form seals too")
