extends SceneTree
## 벽 땅따먹기 로직/AI 헤드리스 테스트 (룰 1 · 룰 2)
## 실행: Godot_console.exe --headless --path . -s res://tests/test_wall_logic.gd

var _fail := 0


func _init() -> void:
	_test_rule1_moves()
	_test_rule2_moves()
	_test_stuck_pair()
	_test_wall_break()
	_test_trio_setup()
	_test_duel_setup()
	_test_enclosure()
	for rule in [1, 2]:
		for lv in [[0, 1, 2], [2, 2, 2]]:
			_selfplay_trio(rule, lv)
		for pair in [[1, 2], [2, 1]]:
			_selfplay_duel(rule, pair)
	print("RESULT: ", "ALL PASSED" if _fail == 0 else "%d FAILED" % _fail)
	quit(1 if _fail > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fail += 1
		print("  FAIL: ", msg)


## 말 하나만 있는 판 (2인, 배치 끝난 상태)
func _single(rule: int, kind: int, at: Vector2i) -> WallLogic:
	var L := WallLogic.new()
	L.setup(rule, 2, [[], []], [[0, at, kind], [1, Vector2i(6, 6), kind]], false)
	return L


func _test_rule1_moves() -> void:
	var L := _single(1, WallLogic.Kind.ROUND, Vector2i(3, 3))
	_check(L.phase == WallLogic.Phase.MOVE and L.current == 0, "no placement -> MOVE, first player")
	var d := L.destinations(0)
	# 1칸 4곳 + 2칸 8곳 + 되돌아오기(제자리) = 13
	_check(d.size() == 13, "rule1 center reach 13, got %d" % d.size())
	_check(d.has(Vector2i(3, 3)), "rule1 can come back to start")
	_check(d.has(Vector2i(4, 4)), "rule1 can turn")
	_check((d[Vector2i(3, 3)]["path"] as Array).is_empty(), "staying is a 0-step move")
	# 네 변이 모두 벽이면 벽 세울 곳이 없어 제자리도 불가
	var M := _single(1, WallLogic.Kind.ROUND, Vector2i(0, 0))
	M.set_wall(Vector2i(0, 0), 1, 2)
	M.set_wall(Vector2i(0, 0), 2, 2)
	_check(M.destinations(0).is_empty(), "fully walled piece cannot act")
	_check(not M.player_can_act(0) or M.pieces_of(0).size() > 1, "player with only boxed piece cannot act")


func _test_rule2_moves() -> void:
	var S := _single(2, WallLogic.Kind.SQUARE, Vector2i(3, 3))
	var ds := S.destinations(0)
	_check(ds.size() == 9, "square reach 8 (straight 1~2) + stay, got %d" % ds.size())
	_check(ds.has(Vector2i(3, 3)), "square can stay")
	_check(not ds.has(Vector2i(4, 4)), "square cannot turn")
	var R := _single(2, WallLogic.Kind.ROUND, Vector2i(3, 3))
	var dr := R.destinations(0)
	_check(dr.size() == 9, "round reach 8 (1 step + diagonals) + stay, got %d" % dr.size())
	_check(dr.has(Vector2i(4, 4)) and not dr.has(Vector2i(3, 1)), "round turns, no straight 2")
	_check(dr.has(Vector2i(3, 3)), "round can stay")


## 아래쪽 두 칸짜리 구역에 서로 다른 편 말 둘이 갇힌 상황 (실제 플레이에서 나온 막힘)
## 옆칸이 상대 말뿐이라 둘 다 움직일 수 없지만, 제자리에서 사이에 벽을 세워 끝낼 수 있어야 한다
func _test_stuck_pair() -> void:
	for rule in [1, 2]:
		var L := WallLogic.new()
		L.setup(rule, 2, [[], []], [[0, Vector2i(2, 6), WallLogic.Kind.ROUND], [1, Vector2i(3, 6), WallLogic.Kind.ROUND]], false)
		L.set_wall(Vector2i(2, 6), 3, 1)
		L.set_wall(Vector2i(2, 6), 0, 2)
		L.set_wall(Vector2i(3, 6), 0, 1)
		L.set_wall(Vector2i(3, 6), 1, 2)
		_check(not L.is_finished(), "rule%d stuck pair shares a region" % rule)
		_check(L.player_can_act(0) and L.player_can_act(1), "rule%d both stuck pieces can still act" % rule)
		var d := L.destinations(0)
		_check(d.size() == 1 and d.has(Vector2i(2, 6)), "rule%d only option is staying" % rule)
		var mv := WallAI.new(WallAI.Level.HARD).choose_move(L.clone(), 0)
		_check(not mv.is_empty() and mv[1] == Vector2i(2, 6) and int(mv[2]) == 1, "rule%d AI walls off the pair: %s" % [rule, mv])
		_check(L.move_piece(0, Vector2i(2, 6)) and L.place_wall(1), "rule%d stay + wall" % rule)
		_check(L.phase == WallLogic.Phase.OVER and L.is_finished(), "rule%d game ends after splitting the pair" % rule)


func _test_wall_break() -> void:
	var L := WallLogic.new()
	L.setup(1, 2, [[], []], [[0, Vector2i(0, 0), 0], [1, Vector2i(6, 6), 0]], true)
	L.set_wall(Vector2i(0, 0), 1, 2)   # 오른쪽 벽
	_check(not L.destinations(0, false).has(Vector2i(1, 0)), "wall blocks normally")
	var db := L.destinations(0, true)
	_check(db.has(Vector2i(1, 0)) and (db[Vector2i(1, 0)]["broken"] as Vector2i).x >= 0, "break lets you pass")
	_check(L.move_piece(0, Vector2i(1, 0), true), "move with break")
	_check(not L.is_wall(Vector2i(0, 0), 1) and L.breaks_left[0] == 0, "wall removed, break used")
	L.cancel_move()
	_check(L.is_wall(Vector2i(0, 0), 1) and L.breaks_left[0] == 1 and L.piece_pos[0] == Vector2i(0, 0), "cancel restores wall and break")
	L.move_piece(0, Vector2i(1, 0), true)
	L.place_wall(2)
	_check(L.breaks_left[0] == 0, "break consumed after turn")
	_check(L.destinations(L.pieces_of(1)[0], true).size() > 0, "other player still has a break")


func _test_trio_setup() -> void:
	var L := WallLogic.new()
	L.setup_trio(1)
	var order := []
	var cells := [Vector2i(0, 0), Vector2i(6, 0), Vector2i(0, 6), Vector2i(6, 6), Vector2i(3, 3), Vector2i(3, 0)]
	for c in cells:
		order.append(L.current)
		_check(L.place_piece(c), "trio place %s" % c)
	_check(order == [0, 1, 2, 2, 1, 0], "trio snake order 1-2-3-3-2-1, got %s" % [order])
	_check(L.phase == WallLogic.Phase.MOVE and L.current == 0, "first player moves first")
	_check(L.breaks_left == PackedInt32Array([1, 1, 1]), "trio has wall breaks")
	# 룰 2: 종류 고르기
	var M := WallLogic.new()
	M.setup_trio(2)
	_check(M.place_piece(Vector2i(0, 0), WallLogic.Kind.ROUND), "rule2 place round first")
	_check(M.remaining_kinds(0) == [WallLogic.Kind.SQUARE], "square left for player 0")


func _test_duel_setup() -> void:
	for rule in [1, 2]:
		var L := WallLogic.new()
		L.setup_duel(rule)
		_check(L.piece_pos.size() == 4, "duel starts with 4 fixed pieces")
		_check(L.piece_owner[0] == 0 and L.piece_pos[0] == Vector2i(1, 1), "first player fixed at B6")
		var order := []
		for c in [Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 3), Vector2i(2, 2)]:
			order.append(L.current)
			L.place_piece(c)
		_check(order == [0, 1, 1, 0], "duel order 1-2-2-1")
		_check(L.pieces_of(0).size() == 4 and L.pieces_of(1).size() == 4, "4 pieces each")
		_check(L.breaks_left == PackedInt32Array([0, 0]), "no wall break in duel")
		if rule == 2:
			_check(L.piece_kind[4] == WallLogic.Kind.SQUARE, "rule2 duel places square pieces")


func _test_enclosure() -> void:
	var L := WallLogic.new()
	L.setup(1, 2, [[], []], [[0, Vector2i(0, 0), 0], [1, Vector2i(6, 6), 0]], false)
	L.set_wall(Vector2i(1, 0), 1, 1)
	L.set_wall(Vector2i(1, 1), 1, 1)
	L.set_wall(Vector2i(0, 1), 2, 1)
	L.set_wall(Vector2i(1, 1), 2, 1)
	_check(L.is_finished(), "enclosed -> finished")
	var sc := L.scores()
	_check(int(sc[0]["area"]) == 4 and int(sc[1]["area"]) == 45, "areas 4/45, got %s" % [sc])
	_check(L.winner() == 1 and L.ranking() == [1, 0], "blue wins")


func _run(L: WallLogic, ais: Array) -> Dictionary:
	var max_ms := 0
	var moves := 0
	var guard := 0
	var breaks := 0
	while L.phase != WallLogic.Phase.OVER and guard < 500:
		guard += 1
		var ai: WallAI = ais[L.current]
		var t0 := Time.get_ticks_msec()
		if L.phase == WallLogic.Phase.PLACE:
			var pl: Array = ai.choose_placement(L.clone(), L.current)
			_check(L.place_piece(pl[0], pl[1]), "AI placement legal")
		else:
			var mv: Array = ai.choose_move(L.clone(), L.current)
			if mv.is_empty():
				_check(false, "AI found no move")
				break
			var brk := (mv[3] as Vector2i).x >= 0
			_check(L.move_piece(mv[0], mv[1], brk), "AI move legal")
			_check(L.place_wall(mv[2]), "AI wall legal")
			if brk:
				breaks += 1
			moves += 1
		max_ms = maxi(max_ms, Time.get_ticks_msec() - t0)
	_check(L.phase == WallLogic.Phase.OVER, "game finished")
	return {"moves": moves, "max_ms": max_ms, "breaks": breaks}


func _selfplay_trio(rule: int, lv: Array) -> void:
	var L := WallLogic.new()
	L.setup_trio(rule)
	var r := _run(L, [WallAI.new(lv[0]), WallAI.new(lv[1]), WallAI.new(lv[2])])
	var sc := L.scores()
	var areas := []
	for p in 3:
		areas.append(int(sc[p]["area"]))
	print("rule%d 3인 AI%s: %d턴, 땅 %s, 순위 %s, 벽부수기 %d회, 최대 생각 %dms" % [rule, lv, r["moves"], areas, L.ranking(), r["breaks"], r["max_ms"]])


func _selfplay_duel(rule: int, pair: Array) -> void:
	var L := WallLogic.new()
	L.setup_duel(rule)
	var r := _run(L, [WallAI.new(pair[0]), WallAI.new(pair[1])])
	var sc := L.scores()
	print("rule%d 1:1 AI%d vs AI%d: %d턴, 땅 %d:%d, 승자 %d, 최대 생각 %dms" % [rule, pair[0], pair[1], r["moves"], int(sc[0]["area"]), int(sc[1]["area"]), L.winner(), r["max_ms"]])
