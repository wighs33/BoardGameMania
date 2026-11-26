class_name HeroNet
extends RefCounted
## 히어로 체스 온라인 대전 메시지 (중계 서버로 상대에게 보내는 내용)
##  {"k": "place", "f": {종류: [x, y]}}                       배치
##  {"k": "act", "taps": [영웅, [x, y] 또는 "stop", …], "h": 지문}  영웅 행동 하나 (AI 계획과 같은 탭 목록)
##  {"k": "summon", "id": 영웅, "c": [x, y], "h": 지문}          성 소환
##  {"k": "end", "h": 지문}                                     한 명만 쓰고 차례 끝
## 지문(h)은 보낸 쪽이 그 일을 한 뒤의 HeroLogic.state_hash() – 받은 쪽도 같아야 함

## 규칙이 바뀌면 올림: 같은 버전끼리만 매칭됨
const VER := 44
const GAME := "herochess"


static func cell(c: Vector2i) -> Array:
	return [c.x, c.y]


static func to_cell(a: Variant) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func encode_taps(taps: Array) -> Array:
	var out: Array = [int(taps[0])]
	for i in range(1, taps.size()):
		var t: Vector2i = taps[i]
		out.append("stop" if t == HeroLogic.STOP else cell(t))
	return out


static func decode_taps(a: Array) -> Array:
	var out: Array = [int(a[0])]
	for i in range(1, a.size()):
		out.append(HeroLogic.STOP if typeof(a[i]) == TYPE_STRING else to_cell(a[i]))
	return out


static func formation_msg(L: HeroLogic, p: int) -> Dictionary:
	var f := {}
	for k in HeroLogic.KINDS:
		f[str(k)] = cell(L.pos[p * HeroLogic.KINDS + k])
	return {"k": "place", "f": f}


static func formation_cells(d: Dictionary) -> Dictionary:
	var out := {}
	var f: Variant = d.get("f", {})
	if typeof(f) != TYPE_DICTIONARY:
		return out
	for k in f:
		out[int(k)] = to_cell(f[k])
	return out


## 받은 행동 하나를 애니메이션 없이 그대로 적용 (테스트 · 확인용). 지문이 맞으면 true
static func apply(L: HeroLogic, d: Dictionary) -> bool:
	match str(d.get("k", "")):
		"act":
			var taps := decode_taps(d.get("taps", []))
			if not L.begin_action(taps[0]):
				return false
			for i in range(1, taps.size()):
				if taps[i] == HeroLogic.STOP:
					L.stop_action()
				else:
					L.choose(taps[i])
		"summon":
			L.do_summon(int(d["id"]), to_cell(d["c"]))
		"end":
			L.end_turn()
		_:
			return false
	return L.state_hash() == int(d.get("h", 0))
