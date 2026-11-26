extends SceneTree
## 그림 퀴즈 단어 · 낙서 헤드리스 테스트
## 실행: Godot_console.exe --headless --path . -s res://tests/test_drawquiz.gd

var _fail := 0


func _init() -> void:
	# 낙서 그림: 모두 있고, 선이 있고, 판 안에 있음
	var seen := {}
	for w in DrawDoodles.WORDS:
		_check(not seen.has(w), "duplicate doodle %s" % w)
		seen[w] = true
		var st := DrawDoodles.strokes(w)
		_check(st.size() >= 1 and DrawDoodles.total_length(st) > 40.0, "%s has strokes" % w)
		var fallback: bool = st.size() == 1 and st[0]["c"] == DrawDoodles.K and (st[0]["p"] as PackedVector2Array)[0].distance_to(Vector2(80, 50)) < 0.5
		_check(not fallback, "%s is not the fallback circle" % w)
		for s in st:
			for p in (s["p"] as PackedVector2Array):
				if p.x < -2 or p.x > 102 or p.y < -2 or p.y > 102:
					_check(false, "%s point out of box %s" % [w, p])
					break
	_check(DrawDoodles.WORDS.size() >= 40, "at least 40 doodles (%d)" % DrawDoodles.WORDS.size())
	# 친구들과 단어
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for cat in QuizWords.CATEGORIES:
		var words: Array = QuizWords.WORDS[cat]
		_check(words.size() >= 20, "%s has 20+ words" % cat)
		var uniq := {}
		for w in words:
			_check(not uniq.has(w), "%s duplicate %s" % [cat, w])
			uniq[w] = true
	var used: Array = []
	for i in 25:
		var r := QuizWords.pick("동물", rng, used)
		_check(not used.has(r[0]), "no repeats while words remain")
		used.append(r[0])
	_check(QuizWords.pick("", rng, []).size() == 2, "random category pick")
	_check(QuizWords.hint("아이스크림") == "5글자" and QuizWords.hint("산타클로스") == "5글자", "hint counts letters")
	print("RESULT: ", "ALL PASSED" if _fail == 0 else "%d FAILED" % _fail)
	quit(1 if _fail > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fail += 1
		print("  FAIL: ", msg)
