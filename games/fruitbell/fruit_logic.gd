class_name FruitLogic
extends RefCounted
## 과일 종치기 규칙 엔진 – 화면과 분리된 순수 로직
## 카드 56장: 과일 4종(딸기 · 바나나 · 라임 · 포도) × [1개 5장, 2개 3장, 3개 3장, 4개 2장, 5개 1장]
## 모두에게 나눠 엎어 두고, 차례대로 맨 위 카드를 내 앞에 펼쳐요 (펼친 카드 위에 겹쳐 놓음)
## 펼쳐진 맨 위 카드들에서 한 과일이 정확히 5개가 되면 종을 쳐요
##  - 맞으면: 펼쳐진 카드를 모두 가져가 내 카드 맨 아래에 넣고, 내가 다음에 펼침
##  - 틀리면: 탈락하지 않은 다른 사람 모두에게 내 카드를 한 장씩 줌
## 펼칠 차례인데 엎어 둔 카드가 없으면 탈락 (펼친 카드는 그대로 남아 다음에 종 친 사람이 가져감)
## 한 명만 남으면 그 사람 승리. MAX_FLIPS 번 펼쳐도 안 끝나면 카드가 가장 많은 사람 승리

enum Fruit { STRAWBERRY, BANANA, LIME, GRAPE }

const NAMES := ["딸기", "바나나", "라임", "포도"]
const COUNTS := [1, 1, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 5]
const TARGET := 5
const MAX_FLIPS := 360

var n: int = 2
var decks: Array = []        # 플레이어별 엎은 카드 (앞 = 맨 위)
var piles: Array = []        # 플레이어별 펼친 카드 (뒤 = 맨 위)
var out: Array = []
var current: int = 0         # 다음에 펼칠 사람
var flips: int = 0
var over: bool = false
var winner: int = -1
var end_reason: String = ""  # "last" / "flips"
var newly_out: Array = []    # 방금 탈락한 사람들


static func card(fruit: int, count: int) -> int:
	return fruit * 10 + count


static func fruit_of(c: int) -> int:
	return c / 10


static func count_of(c: int) -> int:
	return c % 10


static func full_deck() -> Array:
	var out_cards: Array = []
	for f in 4:
		for k in COUNTS:
			out_cards.append(card(f, k))
	return out_cards


func setup(players: int, first: int, rng: RandomNumberGenerator, cards: Array = []) -> void:
	n = players
	var all := cards.duplicate() if not cards.is_empty() else full_deck()
	if cards.is_empty():
		for i in range(all.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t: int = all[i]
			all[i] = all[j]
			all[j] = t
	decks = []
	piles = []
	out = []
	for p in n:
		decks.append([])
		piles.append([])
		out.append(false)
	for i in all.size():
		(decks[(first + i) % n] as Array).append(all[i])
	current = first
	flips = 0
	over = false
	winner = -1
	end_reason = ""
	newly_out = []


# ── 정보 ───────────────────────────────────────────────
func top(p: int) -> int:
	var pile: Array = piles[p]
	return -1 if pile.is_empty() else int(pile[-1])


## 과일별로 보이는 개수 (펼친 카드 맨 위만)
func totals() -> Array:
	var t := [0, 0, 0, 0]
	for p in n:
		var c := top(p)
		if c >= 0:
			t[fruit_of(c)] += count_of(c)
	return t


func has_five() -> bool:
	return totals().has(TARGET)


func card_count(p: int) -> int:
	return (decks[p] as Array).size() + (piles[p] as Array).size()


func active() -> Array:
	var a: Array = []
	for p in n:
		if not out[p]:
			a.append(p)
	return a


func can_flip(p: int) -> bool:
	return not over and p == current and not out[p] and not (decks[p] as Array).is_empty()


# ── 펼치기 ─────────────────────────────────────────────
## 펼친 카드 (못 하면 -1)
func flip(p: int) -> int:
	newly_out = []
	if not can_flip(p):
		return -1
	var c: int = (decks[p] as Array).pop_front()
	(piles[p] as Array).append(c)
	flips += 1
	_advance(p)
	if not over and flips >= MAX_FLIPS:
		_finish_by_cards()
	return c


## p 다음 사람에게 차례 넘기기 (엎은 카드가 없으면 탈락)
func _advance(from: int) -> void:
	current = from   # 다른 사람이 모두 탈락하면 그대로 (곧 승리)
	for i in range(1, n):
		var q := (from + i) % n
		if out[q]:
			continue
		if (decks[q] as Array).is_empty():
			out[q] = true
			newly_out.append(q)
			continue
		current = q
		break
	_check_last()


func _check_last() -> void:
	var a := active()
	if a.size() <= 1:
		over = true
		winner = int(a[0]) if a.size() == 1 else _most_cards()
		end_reason = "last"


# ── 종 치기 ────────────────────────────────────────────
## 결과 {ok, p, taken: [[주인, 카드 수, 맨 위 카드]…], gave: [받은 사람…]}
func ring(p: int) -> Dictionary:
	newly_out = []
	var res := {"ok": false, "p": p, "taken": [], "gave": []}
	if over or out[p]:
		return {}
	if has_five():
		res["ok"] = true
		var got: Array = []
		for q in n:
			var pile: Array = piles[q]
			if pile.is_empty():
				continue
			(res["taken"] as Array).append([q, pile.size(), pile[-1]])
			got.append_array(pile)
			piles[q] = []
		(decks[p] as Array).append_array(got)
		current = p
	else:
		for q in n:
			if q == p or out[q] or (decks[p] as Array).is_empty():
				continue
			(decks[q] as Array).append((decks[p] as Array).pop_front())
			(res["gave"] as Array).append(q)
		# 펼칠 차례인 사람이 카드가 없으면 넘김
		if (decks[current] as Array).is_empty() and not out[current]:
			out[current] = true
			newly_out.append(current)
			_advance(current)
	_check_last()
	return res


func _most_cards() -> int:
	var best := -1
	for p in n:
		if best < 0 or card_count(p) > card_count(best):
			best = p
	return best


func _finish_by_cards() -> void:
	over = true
	winner = _most_cards()
	end_reason = "flips"


## 순위용: 카드 많은 순 (탈락은 맨 뒤)
func ranking() -> Array:
	var order: Array = range(n)
	order.sort_custom(func(a: int, b: int) -> bool:
		if out[a] != out[b]:
			return not out[a]
		return card_count(a) > card_count(b))
	return order
