class_name FruitAI
extends RefCounted
## 과일 종치기 AI – 반응 속도와 실수로 난이도를 나눠요
##  쉬움  : 느리고(1.25~1.9초) 30%는 놓치고, 5개 근처(4·6개)에서 가끔 헛치기
##  보통  : 0.8~1.25초, 10% 놓침
##  어려움: 0.5~0.8초, 거의 안 놓침

enum Level { EASY, NORMAL, HARD }

const REACT := [[1.25, 1.9], [0.8, 1.25], [0.5, 0.8]]
const MISS := [0.3, 0.1, 0.03]
const FALSE_RING := [0.07, 0.03, 0.01]
const FLIP := [[0.95, 1.35], [0.85, 1.2], [0.75, 1.05]]

var level: int
var rng := RandomNumberGenerator.new()


func _init(p_level: int = Level.NORMAL) -> void:
	level = p_level
	rng.randomize()


## 지금 판을 보고 몇 초 뒤에 종을 칠지 (안 치면 -1). real = 진짜 5개를 보고 치는지
func ring_delay(L: FruitLogic) -> Array:
	var r: Array = REACT[level]
	if L.has_five():
		if rng.randf() < MISS[level]:
			return [-1.0, true]
		return [rng.randf_range(r[0], r[1]), true]
	var t := L.totals()
	if (t.has(FruitLogic.TARGET - 1) or t.has(FruitLogic.TARGET + 1)) and rng.randf() < FALSE_RING[level]:
		return [rng.randf_range(r[0], r[1]) * 1.1, false]
	return [-1.0, false]


func flip_delay() -> float:
	var f: Array = FLIP[level]
	return rng.randf_range(f[0], f[1])
