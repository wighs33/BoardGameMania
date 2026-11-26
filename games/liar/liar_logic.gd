class_name LiarLogic
extends RefCounted
## 라이어 찾기 – 한 판의 규칙
##  역할 나누기(라이어 1명, 라이어는 정답 후보 20개를 미리 봄)
##  → 설명 두 바퀴 (순서대로 한 바퀴, 거꾸로 한 바퀴) → 지목
##  → 라이어를 잡으면 마지막 기회(후보 20개 중 제시어 맞히기) → 점수

enum Result { NONE, LIAR_ESCAPED, LIAR_GUESSED, CITIZENS }

const CHOICE_COUNT := 20   # 라이어가 받는 정답 후보 수 (제시어 포함)

var players: int = 4
var fool_mode: bool = false     # 바보 라이어: 라이어도 다른 단어를 받아서 자기가 라이어인 줄 모름
var category: String = ""
var word: String = ""
var fool_word: String = ""
var liar: int = 0
var first: int = 0
var accused: int = -1
var guessed: String = ""
var choices: Array = []
var result: int = Result.NONE


## cat 이 비어 있거나 없는 주제면 랜덤. used: 이번 모임에서 이미 나온 단어 (되도록 피함)
func setup(n: int, cat: String, fool: bool, rng: RandomNumberGenerator, used: Array = []) -> void:
	players = n
	fool_mode = fool
	if LiarWords.WORDS.has(cat):
		category = cat
	else:
		category = LiarWords.CATEGORIES[rng.randi() % LiarWords.CATEGORIES.size()]
	var pool: Array = LiarWords.words(category)
	var fresh: Array = pool.filter(func(w: String) -> bool: return not used.has(w))
	if fresh.size() < 2:
		fresh = pool
	word = fresh[rng.randi() % fresh.size()]
	fool_word = ""
	if fool:
		var others: Array = pool.filter(func(w: String) -> bool: return w != word)
		fool_word = others[rng.randi() % others.size()]
	liar = rng.randi() % n
	first = rng.randi() % n
	accused = -1
	guessed = ""
	result = Result.NONE
	make_choices(rng)


## p 가 카드에서 보게 될 단어. 빈 문자열이면 "당신은 라이어!" 카드
func card_word(p: int) -> String:
	if p != liar:
		return word
	return fool_word


func speak_order() -> Array:
	var out: Array = []
	for i in players:
		out.append((first + i) % players)
	return out


## 설명 두 바퀴: 순서대로 한 바퀴 → 거꾸로 한 바퀴 (마지막 사람이 연달아 두 번 말함)
func talk_order() -> Array:
	var one := speak_order()
	var back := one.duplicate()
	back.reverse()
	return one + back


## 지목. 라이어를 맞히면 true (그 뒤 라이어의 마지막 기회), 아니면 라이어 승리로 끝
func accuse(p: int) -> bool:
	accused = p
	if p != liar:
		result = Result.LIAR_ESCAPED
		return false
	return true


## 라이어가 받는 정답 후보 (제시어 포함 CHOICE_COUNT 개, 섞어서). 바보 라이어가 받은 단어는 빼요
func make_choices(rng: RandomNumberGenerator) -> Array:
	var pool: Array = LiarWords.words(category).duplicate()
	pool.erase(word)
	pool.erase(fool_word)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	choices = pool.slice(0, CHOICE_COUNT - 1)
	choices.insert(rng.randi() % (choices.size() + 1), word)
	return choices


func guess(w: String) -> bool:
	guessed = w
	if w == word:
		result = Result.LIAR_GUESSED
		return true
	result = Result.CITIZENS
	return false


func liar_won() -> bool:
	return result == Result.LIAR_ESCAPED or result == Result.LIAR_GUESSED


## 이번 판 점수: 안 잡힌 라이어 +3, 잡혔지만 제시어를 맞힌 라이어 +2, 시민 승리면 시민 모두 +1
func points() -> Array:
	var out: Array = []
	for p in players:
		var pts := 0
		match result:
			Result.LIAR_ESCAPED:
				pts = 3 if p == liar else 0
			Result.LIAR_GUESSED:
				pts = 2 if p == liar else 0
			Result.CITIZENS:
				pts = 0 if p == liar else 1
		out.append(pts)
	return out
