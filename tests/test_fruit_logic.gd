extends SceneTree
## 과일 종치기 로직 헤드리스 테스트
## 실행: Godot_console.exe --headless --path . -s res://tests/test_fruit_logic.gd

const F := FruitLogic.Fruit
var _fail := 0


func _init() -> void:
	_test_deck()
	_test_deal()
	_test_flip_and_five()
	_test_ring_ok()
	_test_ring_wrong()
	_test_out_and_win()
	_test_ai()
	_test_random_games()
	print("RESULT: ", "ALL PASSED" if _fail == 0 else "%d FAILED" % _fail)
	quit(1 if _fail > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fail += 1
		print("  FAIL: ", msg)


func _c(f: int, k: int) -> int:
	return FruitLogic.card(f, k)


## 카드 순서를 정해서 나눔 (i 번째 카드 → (first + i) % n)
func _game(n: int, cards: Array, first: int = 0) -> FruitLogic:
	var L := FruitLogic.new()
	L.setup(n, first, RandomNumberGenerator.new(), cards)
	return L


func _test_deck() -> void:
	var d := FruitLogic.full_deck()
	_check(d.size() == 56, "56 cards")
	var per := [0, 0, 0, 0]
	var fives := 0
	for c in d:
		per[FruitLogic.fruit_of(c)] += FruitLogic.count_of(c)
		if FruitLogic.count_of(c) == 5:
			fives += 1
	_check(per == [33, 33, 33, 33], "33 fruits of each kind, got %s" % [per])
	_check(fives == 4, "one 5-card per fruit")


func _test_deal() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for n in [2, 3, 4]:
		var L := FruitLogic.new()
		L.setup(n, 0, rng)
		var total := 0
		for p in n:
			total += L.card_count(p)
		_check(total == 56, "%d players: all 56 dealt" % n)
		_check(absi(L.card_count(0) - L.card_count(n - 1)) <= 1, "%d players: even deal" % n)


func _test_flip_and_five() -> void:
	var L := _game(2, [_c(F.STRAWBERRY, 2), _c(F.BANANA, 3), _c(F.STRAWBERRY, 3), _c(F.LIME, 1), _c(F.GRAPE, 5), _c(F.GRAPE, 1)])
	_check(L.current == 0 and L.flip(1) == -1, "only current player flips")
	_check(L.flip(0) == _c(F.STRAWBERRY, 2) and L.current == 1, "flip and pass turn")
	L.flip(1)
	_check(not L.has_five(), "2 strawberries + 3 bananas is not five")
	L.flip(0)
	_check(L.top(0) == _c(F.STRAWBERRY, 3), "new card covers the old one")
	_check(L.totals()[F.STRAWBERRY] == 3 and L.totals()[F.BANANA] == 3, "only top cards count")
	L.flip(1)
	_check(not L.has_five(), "no five")
	L.flip(0)
	_check(L.has_five(), "grape 5 alone is five")


func _test_ring_ok() -> void:
	var L := _game(2, [_c(F.STRAWBERRY, 2), _c(F.STRAWBERRY, 3), _c(F.LIME, 1), _c(F.LIME, 2)])
	L.flip(0)
	L.flip(1)
	_check(L.has_five(), "2 + 3 strawberries")
	var res := L.ring(1)
	_check(res["ok"] and L.card_count(1) == 3 and L.card_count(0) == 1, "ringer takes both piles (%d, %d)" % [L.card_count(1), L.card_count(0)])
	_check((L.piles[0] as Array).is_empty() and (L.piles[1] as Array).is_empty(), "piles cleared")
	_check(L.current == 1, "ringer flips next")


func _test_ring_wrong() -> void:
	var L := _game(3, [_c(F.STRAWBERRY, 1), _c(F.BANANA, 1), _c(F.LIME, 1), _c(F.GRAPE, 1), _c(F.GRAPE, 2), _c(F.GRAPE, 3)])
	L.flip(0)
	var res := L.ring(2)
	_check(not res["ok"] and (res["gave"] as Array).size() == 2, "wrong ring gives to the two others")
	_check(L.card_count(2) == 0 and L.card_count(0) == 3 and L.card_count(1) == 3, "cards moved (%d %d %d)" % [L.card_count(0), L.card_count(1), L.card_count(2)])
	_check(not L.out[2], "not out until their turn")


func _test_out_and_win() -> void:
	var L := _game(2, [_c(F.STRAWBERRY, 1), _c(F.BANANA, 1), _c(F.LIME, 1)])
	L.flip(0)
	L.flip(1)
	_check(not L.over, "still playing")
	L.flip(0)
	_check(L.out[1] and L.over and L.winner == 0, "player with no cards to flip is out → last one wins")
	_check(L.newly_out == [1], "newly_out reported")


func _test_ai() -> void:
	var L := _game(2, [_c(F.STRAWBERRY, 5), _c(F.BANANA, 1)])
	L.flip(0)
	var hard := FruitAI.new(FruitAI.Level.HARD)
	var rung := 0
	for i in 100:
		var d: Array = hard.ring_delay(L)
		if float(d[0]) >= 0.0:
			rung += 1
			_check(float(d[0]) >= 0.5 and float(d[0]) <= 0.8 and d[1], "hard reacts in 0.5~0.8s")
	_check(rung > 85, "hard rarely misses (%d/100)" % rung)
	var easy := FruitAI.new(FruitAI.Level.EASY)
	rung = 0
	for i in 200:
		if float(easy.ring_delay(L)[0]) >= 0.0:
			rung += 1
	_check(rung > 100 and rung < 175, "easy misses sometimes (%d/200)" % rung)


## 무작위로 펼치고 치는 판이 항상 끝나고 카드 수가 보존되는지
func _test_random_games() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var total_flips := 0
	for g in 60:
		var n := 2 + g % 3
		var L := FruitLogic.new()
		L.setup(n, g % n, rng)
		var guard := 0
		while not L.over and guard < 2000:
			guard += 1
			if L.has_five() or rng.randf() < 0.03:
				var a := L.active()
				L.ring(int(a[rng.randi() % a.size()]))
			else:
				L.flip(L.current)
			var sum := 0
			for p in n:
				sum += L.card_count(p)
			if sum != 56:
				_check(false, "cards conserved (%d)" % sum)
				return
		_check(L.over, "game ends (guard %d)" % guard)
		total_flips += L.flips
	print("  random games: avg %d flips" % (total_flips / 60))
