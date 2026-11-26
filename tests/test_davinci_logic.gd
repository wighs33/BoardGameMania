extends SceneTree
## 비밀 숫자 · 라이어 찾기 로직/AI 헤드리스 테스트
## 실행: Godot_console.exe --headless --path . -s res://tests/test_davinci_logic.gd

var _fail := 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 12345
	_test_setup()
	_test_guess_flow()
	_test_empty_pool()
	_test_probs()
	for n in [2, 3, 4]:
		for lv in [0, 1, 2]:
			_selfplay(n, lv, 6)
	_test_liar()
	print("RESULT: ", "ALL PASSED" if _fail == 0 else "%d FAILED" % _fail)
	quit(1 if _fail > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fail += 1
		print("  FAIL: ", msg)


func _sorted_ok(L: DavinciLogic) -> bool:
	for p in L.n:
		var h: Array = L.hands[p]
		for i in range(1, h.size()):
			if int(h[i - 1]) >= int(h[i]):
				return false
		if (L.revealed[p] as Array).size() != h.size():
			return false
	return true


func _total(L: DavinciLogic) -> int:
	var t := L.pool.size() + (1 if L.drawn >= 0 else 0)
	for p in L.n:
		t += (L.hands[p] as Array).size()
	return t


func _test_setup() -> void:
	for n in [2, 3, 4]:
		var L := DavinciLogic.new()
		L.setup(n, _rng, 0)
		var per := 4 if n <= 3 else 3
		for p in n:
			_check((L.hands[p] as Array).size() == per, "n=%d hand size %d" % [n, per])
		_check(_sorted_ok(L), "hands sorted n=%d" % n)
		_check(_total(L) == 24, "24 tiles n=%d" % n)
		_check(L.phase == DavinciLogic.Phase.DRAW, "starts in DRAW")
	_check(DavinciLogic.key_of(5, 0) < DavinciLogic.key_of(5, 1), "black 5 left of white 5")
	_check(DavinciLogic.key_of(5, 1) < DavinciLogic.key_of(6, 0), "white 5 left of black 6")


## 손패를 직접 정해서 흐름 확인
func _fixed(hands: Array, pool: Array) -> DavinciLogic:
	var L := DavinciLogic.new()
	L.setup(2, _rng, 0)
	L.hands = []
	L.revealed = []
	for h in hands:
		var hh: Array = (h as Array).duplicate()
		hh.sort()
		L.hands.append(hh)
		var rv: Array = []
		rv.resize(hh.size())
		rv.fill(false)
		L.revealed.append(rv)
	L.pool = pool.duplicate()
	L.current = 0
	L.phase = DavinciLogic.Phase.DRAW if not pool.is_empty() else DavinciLogic.Phase.GUESS
	return L


func _test_guess_flow() -> void:
	var k := DavinciLogic.key_of
	var L := _fixed([[k.call(1, 0), k.call(4, 1)], [k.call(2, 0), k.call(7, 1)]], [k.call(9, 0), k.call(3, 1)])
	_check(not L.can_target(1, 0), "cannot guess before drawing")
	var d := L.draw(0, _rng)
	_check(d == k.call(9, 0), "drew the only black tile")
	_check(L.phase == DavinciLogic.Phase.GUESS, "GUESS after draw")
	_check(not L.can_target(0, 0), "cannot target own tile")
	_check(L.guess(1, 0, 2), "correct guess black 2")
	_check(L.revealed[1][0] == true, "tile revealed")
	_check(L.phase == DavinciLogic.Phase.DECIDE, "DECIDE after hit")
	_check(not L.can_target(1, 0), "revealed tile not targetable")
	_check(not L.guess(1, 1, 6), "wrong guess white 6")
	_check(L.wrong.get(k.call(7, 1), []).has(6), "wrong guess remembered")
	_check(L.current == 1, "turn passed after miss")
	var i9 := L.index_of_key(0, k.call(9, 0))
	_check(i9 == 2 and L.revealed[0][i9] == true, "drawn tile placed revealed at right spot")
	_check(_sorted_ok(L), "sorted after insert")
	_check(L.excluded_for(1, 1, 1).has(6), "excluded includes wrong guess")
	# 상대가 맞히고 멈추기 → 뽑은 타일 숨긴 채
	var d2 := L.draw(1, _rng)
	_check(d2 == k.call(3, 1), "p1 drew white 3")
	_check(L.guess(0, 0, 1), "p1 hits black 1")
	_check(L.stop(), "p1 stops")
	var i3 := L.index_of_key(1, k.call(3, 1))
	_check(i3 == 1 and L.revealed[1][i3] == false, "stopped tile inserted hidden (black2 < white3 < white7)")
	_check(L.current == 0, "turn back to p0")
	# 탈락과 끝
	_check(L.phase == DavinciLogic.Phase.GUESS, "pool empty → straight to GUESS")
	_check(L.guess(1, 1, 3), "hit white 3")
	_check(L.guess(1, 2, 7), "hit white 7 → p1 out")
	_check(L.is_over() and L.winner == 0, "p0 wins")
	_check(L.ranking() == [0, 1], "ranking")


func _test_empty_pool() -> void:
	var k := DavinciLogic.key_of
	var L := _fixed([[k.call(1, 0), k.call(4, 1)], [k.call(2, 0), k.call(7, 1)]], [])
	_check(L.phase == DavinciLogic.Phase.GUESS, "empty pool GUESS")
	_check(not L.guess(1, 0, 5), "miss")
	_check(L.phase == DavinciLogic.Phase.REVEAL_OWN, "must reveal own")
	_check(not L.reveal_own(5), "bad index rejected")
	_check(L.reveal_own(1), "reveal own white 4")
	_check(L.current == 1 and L.revealed[0][1], "turn passes after reveal")


func _test_probs() -> void:
	var k := DavinciLogic.key_of
	# 상대 줄: 검정3(공개) [하양?] 검정5(공개) → 사이에 올 수 있는 하양은 3 · 4 뿐
	var L := _fixed([[k.call(0, 0), k.call(10, 1)], [k.call(3, 0), k.call(4, 1), k.call(5, 0)]], [k.call(9, 0)])
	L.revealed[1][0] = true
	L.revealed[1][2] = true
	var ai := DavinciAI.new(DavinciAI.Level.HARD)
	var rows := ai._row_probs(L, 0, 1, true)
	var d: Dictionary = rows[1]
	_check(d.size() == 2 and d.has(3) and d.has(4), "only white 3/4 fit between black3 and black5: %s" % [d])
	_check(absf(float(d[3]) - 0.5) < 0.001, "50/50")
	L.wrong[k.call(4, 1)] = [3]
	rows = ai._row_probs(L, 0, 1, true)
	d = rows[1]
	_check(d.size() == 1 and d.has(4), "wrong guess removes 3")
	L.draw(0, _rng)
	var g := ai.choose_guess(L, 0)
	_check(g.size() == 4 and int(g[2]) == 4 and float(g[3]) > 0.99, "hard AI guesses the sure 4: %s" % [g])
	# 확률 합 = 1, 진짜 숫자는 항상 가능
	for trial in 30:
		var M := DavinciLogic.new()
		M.setup(3, _rng, 0)
		var a := DavinciAI.new(DavinciAI.Level.HARD)
		for o in [1, 2]:
			var rr := a._row_probs(M, 0, o, true)
			for i in rr.size():
				var dd: Dictionary = rr[i]
				var s := 0.0
				for v in dd:
					s += float(dd[v])
				_check(absf(s - 1.0) < 0.001, "probabilities sum to 1")
				_check(dd.has(DavinciLogic.num_of(int(M.hands[o][i]))), "true number possible")


func _selfplay(n: int, lv: int, games: int) -> void:
	var wins := []
	wins.resize(n)
	wins.fill(0)
	for gi in games:
		var L := DavinciLogic.new()
		L.setup(n, _rng, gi % n)
		var ais: Array = []
		for p in n:
			ais.append(DavinciAI.new(lv if p == 0 else (gi + p) % 3))
		var guard := 0
		while not L.is_over() and guard < 2000:
			guard += 1
			var me := L.current
			var a: DavinciAI = ais[me]
			if L.phase == DavinciLogic.Phase.DRAW:
				L.draw(a.choose_draw(L, me), _rng)
			var turn_guard := 0
			while L.current == me and not L.is_over() and turn_guard < 40:
				turn_guard += 1
				if L.phase == DavinciLogic.Phase.REVEAL_OWN:
					L.reveal_own(a.choose_reveal(L, me))
					break
				var g := a.choose_guess(L, me)
				if g.is_empty():
					_check(false, "no guess available")
					break
				_check(L.can_target(g[0], g[1]), "AI target valid")
				var ok := L.guess(g[0], g[1], g[2])
				if ok and not L.is_over() and L.current == me and L.phase == DavinciLogic.Phase.DECIDE:
					if not a.should_continue(L, me):
						L.stop()
			_check(_sorted_ok(L), "sorted during play")
			_check(_total(L) == 24, "tile count conserved")
		_check(L.is_over(), "game n=%d lv=%d finished (guard %d)" % [n, lv, guard])
		if L.winner >= 0:
			wins[L.winner] += 1
	print("  selfplay n=%d p0 level %d: wins %s" % [n, lv, wins])


func _test_liar() -> void:
	for cat in LiarWords.CATEGORIES:
		_check(LiarWords.words(cat).size() >= LiarLogic.CHOICE_COUNT + 2, "category %s has enough words for 20 candidates" % cat)
		var seen := {}
		for w in LiarWords.words(cat):
			_check(not seen.has(w), "duplicate word %s" % w)
			seen[w] = true
	var L := LiarLogic.new()
	var used: Array = []
	for r in 20:
		L.setup(5, "동물", r % 2 == 1, _rng, used)
		_check(not used.has(L.word), "word not repeated (round %d)" % r)
		used.append(L.word)
		var liar_cards := 0
		for p in 5:
			var w := L.card_word(p)
			if p == L.liar:
				liar_cards += 1
				if L.fool_mode:
					_check(not w.is_empty() and w != L.word, "fool liar gets a different word")
				else:
					_check(w.is_empty(), "liar sees no word")
			else:
				_check(w == L.word, "citizen sees the word")
		_check(liar_cards == 1, "exactly one liar")
		# 라이어가 처음부터 받는 후보 20개: 제시어 포함, 중복 없음, 바보 라이어 단어는 빠짐
		_check(L.choices.size() == LiarLogic.CHOICE_COUNT and L.choices.has(L.word), "20 candidates incl. answer (round %d)" % r)
		var uniq := {}
		for w in L.choices:
			uniq[w] = true
			_check(LiarWords.words("동물").has(w), "candidate from the category")
		_check(uniq.size() == L.choices.size(), "no duplicate candidates")
		if L.fool_mode:
			_check(not L.choices.has(L.fool_word), "fool word not among candidates")
	for cat in LiarWords.CATEGORIES:
		L.setup(8, cat, true, _rng)
		_check(L.choices.size() == LiarLogic.CHOICE_COUNT, "category %s fills 20 candidates in fool mode" % cat)
	L.setup(4, "", false, _rng)
	_check(LiarWords.CATEGORIES.has(L.category), "random category")
	_check(L.speak_order().size() == 4 and int(L.speak_order()[0]) == L.first, "speak order")
	# 설명 두 바퀴: 순서대로 → 거꾸로
	var one := L.speak_order()
	var two := L.talk_order()
	_check(two.size() == 8 and two.slice(0, 4) == one, "first round in order")
	_check(two[4] == one[3] and two[5] == one[2] and two[6] == one[1] and two[7] == one[0], "second round reversed: %s" % [two])
	var not_liar := (L.liar + 1) % 4
	_check(not L.accuse(not_liar) and L.liar_won(), "wrong accusation → liar wins")
	_check(L.points()[L.liar] == 3, "escaped liar +3")
	L.setup(4, "과일", false, _rng)
	_check(L.accuse(L.liar), "caught liar")
	var ch := L.choices
	_check(ch.size() == LiarLogic.CHOICE_COUNT and ch.has(L.word), "20 choices incl. answer")
	var wrong_w := ""
	for w in ch:
		if w != L.word:
			wrong_w = w
			break
	_check(not L.guess(wrong_w) and not L.liar_won(), "wrong guess → citizens win")
	var pts := L.points()
	_check(pts[L.liar] == 0 and pts[(L.liar + 1) % 4] == 1, "citizens +1")
	L.result = LiarLogic.Result.NONE
	_check(L.guess(L.word) and L.liar_won() and L.points()[L.liar] == 2, "liar guessed → +2")
