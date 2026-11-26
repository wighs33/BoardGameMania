extends GameScreen
## 히어로 체스 – 게임 화면 (배치 → 차례마다 영웅 두 명 '이동 후 능력' 또는 성 소환, 정보 칸, 무르기, AI 차례 관리)
## 상단 바 / 플레이어 카드 / 팝업 등 공통 UI는 GameScreen 에 있음

const K := HeroLogic.Kind
const ST := HeroLogic.Step
const DESC := [
	"2칸(말 없으면 1칸) 이하 이동 → 다음 칸 공격, 옆의 아군 넘기기, 바로 뒤 아군과 함께 이동. 말이 대신 맞고 사신에 닿으면 흑기사!",
	"2칸 이하 이동(꺾어도 OK) → 상하좌우의 적 한 명 공격, 또는 상하좌우 빈칸 모두에 지뢰(적 지뢰와 겹치면 터져요).",
	"한 방향 2칸 이하(영웅 넘기). 유령 칸 = 부활·제거, 영웅 칸 = 조종해 옆 적 공격 뒤 원래 칸으로. 쓰러지면 십자가가 남아요.",
	"이동 없음 → 아군·아군 유령과 자리를 바꾸고 주위 8칸 적 하나의 능력 봉인, 또는 상하좌우 3칸 파이어볼!",
	"1칸 이동 → 상하좌우 아군이나 자기에게 배리어(하나만), 옆 칸을 십자가로 공격(적·적 유령), 성 옆에서 희생해 십자가의 천사 부활.",
	"가로·세로로 막힐 때까지 이동 → 앞의 적을 밀며 1턴 스턴, 한 칸 띈 영웅 끌기, 벽·포탑 부수기. 공격·무력·저주·조종 안 통함.",
	"주위 8칸 적은 늘 무력(이동·능력 X). 가로·세로 1칸 이동 → 상하좌우 적 한 명 공격, 또는 1칸 전진.",
	"가로·세로로 막힐 때까지 이동(능력 없음), 또는 제자리에서 앞·뒤 줄 영웅의 이동+능력을 따라 하기! 성은 못 쳐요.",
	"대각선 4칸 적을 늘 자동 공격. 1칸 이하 이동 → 상하좌우 2칸 안의 적·적 유령에게 저주, 또는 저주 걸린 적에게 가서 없애기.",
	"한 차례에 두 번 행동. 8방향 이동 → 자기 칸 변에 벽. 아군 벽 4개면 포탑(8칸 자동 공격), 안의 영웅은 쓰러져요. 성은 못 쳐요.",
]
const UNDO_MAX := 200   # 무르기로 되돌릴 수 있는 행동 수
const SERVER_URL := "wss://boardgamemania-relay.onrender.com"   # 온라인 대전 중계 서버 (Render 무료, 화면에는 보이지 않음)
const GHOST_DESC := "쓰러진 영웅의 유령. 상하좌우 빈칸으로 한 칸 이동. 같은 편 천사가 이 칸에 오면 부활하고, 적 성직자·천사·사신이 없앨 수 있어요."

const CASTLE_DESC := "행동 1개와 하트 1개로 내 영웅(로봇 제외) 한 명을 성 주위 5칸의 빈칸으로 불러와요. 하트가 2개 이상일 때만 돼요."

var logic: HeroLogic
var ai: HeroAI = null
var order_choice: int = 0     # AI 대전 순서: 0 = 내가 먼저, 1 = AI 먼저, 2 = 랜덤

var board: HeroBoard
var main_btn: Button
var sub_btn: Button
var undo_btn: Button
var _portrait: HeroPortrait
var _info_name: Label
var _info_desc: Label
var _hearts: Array = []

var _busy: bool = false
var _thread: Thread = null
var _thread_token: int = -1
var _ai_started_ms: int = 0
var _rng := RandomNumberGenerator.new()
# 배치
var _placing: bool = false
var _place_order: Array = []
var _placer: int = 0
var _place_sel := HeroLogic.NONE
var _place_loaded: bool = false         # 이번 판에 직전 배치를 불러왔는지
# 소환
var _summon_id: int = -1
var _summon_mode: bool = false
# 무르기: 사람이 행동하기 직전 상태 (HeroLogic 복사본, 마지막이 가장 최근)
var _undo: Array = []
# 온라인 대전 (중계 서버로 빠른 매칭)
var online: bool = false
var net: OnlineClient = null
var _net_taps: Array = []          # 지금 하는 내 행동의 탭 (끝나면 상대에게 보냄)
var _net_inbox: Array = []         # 상대에게서 받은 일 (차례대로 보여 줌)
var _net_their_place: Dictionary = {}
var _net_my_placed: bool = false
var _net_applying: bool = false
var _net_over: bool = false        # 상대가 나가는 등으로 온라인 판이 끝남


# ══════════════════════════════════════════════════════
#  GameScreen 설정
# ══════════════════════════════════════════════════════
func _game_title() -> String:
	return "히어로 체스"


func _rules_text() -> String:
	var c1 := UIKit.player_dark(0).to_html(false)
	var c2 := UIKit.GREEN.darkened(0.15).to_html(false)
	var c3 := UIKit.player_dark(1).to_html(false)
	var c4 := UIKit.ORANGE.darkened(0.1).to_html(false)
	var heroes := ""
	for k in HeroLogic.KINDS:
		heroes += "  · [b]%s[/b]  %s\n" % [HeroLogic.NAMES[k], DESC[k]]
	return (
		"[color=#%s]1. 목표[/color]  상대 [b]성의 하트 3개[/b]를 모두 없애면 승리!\n" % c1
		+ "[color=#%s]2. 배치[/color]  영웅 10명은 [b]맨 끝줄[/b]에서 시작해요(가운데는 성). 시작 전에 영웅끼리 자리를 마음대로 바꿀 수 있어요. 영웅을 누르고 바꿀 영웅을 누르면 돼요. 새 게임에는 [b]직전 배치[/b]가 그대로 나와요.\n" % c2
		+ "[color=#%s]3. 내 차례[/color]  [b]영웅 두 명[/b]까지 골라 한 명씩 [b]이동한 뒤 능력[/b]을 써요. 제자리에 그대로 있어도 되고(마법사는 이동이 없어요), 능력은 안 써도 돼요. [b]건축가만 한 차례에 두 번[/b] 행동할 수 있어요. 행동 하나 대신 [b]내 성[/b]을 눌러, [b]판 위의 내 영웅[/b] 한 명을 [b]내 성 주위 5칸[/b] 중 빈칸으로 [b]소환[/b]할 수 있어요. 소환에는 [b]내 성의 하트 1개[/b]가 들고, 하트가 2개 이상일 때만 돼요(로봇은 소환 못 해요). 불러온 영웅도 남은 행동으로 움직일 수 있고, 이미 움직인 영웅도 부를 수 있어요.\n" % c3
		+ "[color=#%s]4. 공격[/color]  이동은 빈칸으로만 하고 [b]이동으로는 공격하지 않아요[/b]. 공격은 기사 · 병사 · 천사 · 전사 · 마법사 · 성직자 · 사신의 능력과 사신의 자동 공격, 포탑으로 해요. 쓰러진 영웅은 [b]유령[/b]이 돼요. 공격 범위 안에 상대 성이 있으면 성을 쳐서 [b]하트 -1[/b]. 또 [b]로봇 · 건축가 · 닌자를 뺀 영웅은 누구나[/b] 능력을 쓸 때 [b]상하좌우에 붙은 상대 성[/b]을 공격 범위와 상관없이 칠 수 있어요.\n" % c4
		+ "[color=#%s]5. 영웅[/color]  (이동 → 능력)\n%s" % [c1, heroes]
		+ "[color=#%s]6. 유령[/color]  쓰러진 영웅은 그 자리에 [b]유령[/b](투명한 팀 색)으로 남아요. 유령도 행동 1번을 써서 [b]상하좌우 빈칸으로 한 칸[/b] 움직여요(벽에 막혀요). 부활은 [b]천사의 능력으로만[/b] 해요: 내 천사가 내 유령 칸에 오면 그 영웅을 내 성 주위 5칸 중 빈칸에 부활시켜요. 유령은 [b]성직자의 십자가, 천사, 사신의 저주[/b]로만 없앨 수 있어요. 영웅은 유령 칸을 지나갈 수 있지만 [b]유령과 같은 칸에 멈출 수는 없어요[/b](천사만 부활시키거나 없애러 들어가요). 유령끼리도 같은 칸에 못 있어요. [b]사신의 저주[/b]로 쓰러지거나 [b]포탑에 갇혀[/b] 쓰러진 영웅과 [b]천사[/b]는 유령이 안 생겨요. 천사는 유령 대신 [b]십자가[/b]가 생겨요.\n" % c3
		+ "[color=#%s]7. 그 밖에[/color]\n" % c2
		+ "  · 지뢰는 지나가도 괜찮고 [b]멈추면[/b] 터져요. 밀리거나 옮겨져서 멈춰도, 천사가 영웅 칸에 내려앉아도 터져요. 병사는 상하좌우 [b]빈칸 모두[/b]에 한꺼번에 놓아요. 이미 [b]적 지뢰[/b]가 있는 칸에서는 [b]지뢰끼리 터져[/b] 지뢰 없는 칸이 돼요(아무도 안 다쳐요). 내 지뢰가 있는 칸은 그대로예요.\n"
		+ "  · 배리어는 [b]깨질 때까지[/b] 유지되고 [b]한 편에 하나뿐[/b]이에요: 다른 영웅에게 주면 있던 배리어는 사라져요. 공격 · 지뢰를 한 번 막고 깨져요. 받는 순간 [b]저주를 풀어 주고[/b], 배리어가 있는 동안에는 [b]저주의 대상이 안 돼요[/b]. [b]사신의 자동 공격은 배리어가 있는 동안 안 통하고[/b] 배리어도 안 깨져요. [b]포탑은 배리어를 뚫고[/b] 공격해요.\n"
		+ "  · [b]전사 주위 8칸의 적은 늘 무력[/b]해요. 무력한 영웅은 이동도 능력도 못 해요. 이동해서 그 8칸에 멈추면 바로 무력해져서 능력을 쓸 수 없어요. 8칸을 벗어나거나(자리 바꾸기 · 밀기 등) 그 전사가 쓰러지면 풀려요. 로봇 · 천사와 전사끼리는 안 통해요.\n"
		+ "  · 천사는 상하좌우 한 방향으로 2칸 이하 움직이고 [b]영웅을 뛰어넘어요[/b](성과 벽은 못 넘어요). 로봇 · 건축가 · 닌자를 뺀 영웅 칸에 내려앉으면 그 영웅을 [b]조종해[/b] 그 상하좌우의 적 한 명을 공격한 뒤(안 해도 돼요) [b]이동 전 자리[/b]로 돌아가요. 천사에게는 [b]무력과 저주가 안 통해서[/b] 적 전사 옆에서도 능력을 써요. 아군 유령 칸에 가면 그 영웅을 내 성 주위 5칸 중 한 칸에 부활시키고(빈칸이 있어야 갈 수 있어요), 적 유령 칸에 가면 그 유령을 없애요. 봉인되면 유령 칸에 못 가요. 천사가 쓰러지면 유령 대신 그 자리에 [b]십자가[/b]가 생겨요. 성직자가 내 성 주위 5칸에 있을 때 [b]자신을 희생하면[/b](성직자의 유령은 남아요) 천사가 [b]십자가 자리에서[/b] 부활해요. 십자가 칸은 지나갈 수만 있고 아무도 멈출 수 없어요. [b]십자가가 있는 칸이 포탑이 되면 십자가가 사라지고[/b], 천사가 포탑에 갇혀 쓰러져도 십자가가 안 생겨요. 그러면 천사는 부활할 수 없어요.\n"
		+ "  · 벽은 세운 편의 색이고 누구의 것이든 [b]이동[/b]을 막아요(사신은 지나가요). [b]적군의 벽은 공격도 막아요[/b](성 공격 · 십자가 · 파이어볼 · 저주도. 내 벽은 지나가요). 하지만 [b]대각선 공격[/b](사신의 자동 공격, 포탑, 흑기사의 대각선)은 못 막아요. 파이어볼과 저주는 [b]모든 포탑[/b]에도 막혀요. 벽은 [b]로봇만[/b] 부술 수 있어요(누구의 것이든, 건축가도 못 허물어요). 밀려나는 길에 벽이 있으면 안 밀려요.\n"
		+ "  · 로봇은 [b]움직인 방향의 다음 칸[/b]에 있는 [b]적[/b]을 한 칸 뒤로 밀어요(아군은 못 밀고, 제자리에 있으면 못 밀어요). 밀린 적은 [b]스턴[/b]돼서 다음 차례 한 번 동안 이동도 능력도 못 해요(패시브는 그대로). 뒤 칸이 막혀 자리가 없으면 [b]안 밀리지만 스턴은 걸려요[/b]. 또는 상하좌우로 [b]한 칸 띄워진 영웅[/b](적 · 아군, 제자리에서도 돼요)을 자기 쪽으로 한 칸 [b]끌어당겨요[/b]. 사이 칸이 빈칸이어야 하고 스턴은 안 걸려요. [b]벽과 포탑은 로봇만[/b] 부술 수 있어요(밀기 · 끌기 대신 하나, 누구의 것이든). 밀 적과 벽이 함께 있으면 무엇을 할지 골라요. 로봇은 성을 칠 수 없어요.\n"
		+ "  · [b]포탑[/b]: 건축가가 칸의 네 변을 모두 [b]아군 벽[/b]으로 막으면 그 칸이 그 편의 포탑이 돼요(적군 벽이 섞이면 안 돼요). [b]안에 있던 다른 영웅은 아군이든 적이든 배리어와 상관없이 쓰러져요[/b](로봇 · 사신도). 유령(천사는 십자가)이 안 생겨서 부활할 수 없어요. 유령이 있는 칸은 포탑이 안 되고, 천사의 십자가가 있는 칸은 포탑이 되면서 십자가가 사라져요. 건축가가 자기 칸을 막으면 그 칸도 포탑이 되고 건축가는 옆 빈칸으로 나와요. 포탑은 [b]자동 공격[/b]해요: 생길 때와 적이 주위 8칸에 멈출 때요(배리어도 뚫고 말 탄 기사도 한 번에 쓰러뜨려요). 포탑은 [b]로봇만[/b] 능력으로 부술 수 있고, 부서지면 네 벽이 한꺼번에 깨져요.\n"
		+ "  · 로봇에게는 [b]공격 · 무력 · 저주 · 조종[/b]이 안 통해요(밀기 · 스턴 · 자리 바꾸기 · 데려오기 · 봉인 · 배리어는 통해요). 멈춘 칸에 지뢰가 있으면 누구 것이든 없애요.\n"
		+ "  · 기사는 [b]말[/b]을 타고 시작해요. 공격받으면 [b]말이 대신 죽고[/b] 1칸만 움직일 수 있게 되고, 말이 없을 때 공격받으면 쓰러져요. 말을 타고 있을 때 [b]사신의 자동 공격이나 저주[/b]가 닿으면 다치지 않고 1턴(내 차례가 한 번 끝날 때까지) 동안 [b]흑기사[/b]로 변신해요. 흑기사는 움직인 방향 대신 [b]주위 8칸의 적 모두[/b]를 공격하고(제자리도 돼요), 걸려 있던 저주가 풀리고 흑기사인 동안 저주에 안 걸려요. 포탑에는 말을 타고 있어도 바로 쓰러져요. [b]내 성 주위 5칸[/b]에 가서 멈추면 말이 다시 생겨요. 기사는 셋 중 하나만 해요: 공격, [b]넘기기[/b](이동 후 상하좌우의 아군을 기사 너머 반대편 칸으로, 제자리도 돼요), [b]함께 이동[/b](이동 전 자리 바로 뒤, 곧 내 성 쪽 칸의 아군이 기사와 같은 방향 · 같은 칸 수만큼 이동). 아군이 가는 길에 벽이나 영웅이 있거나 도착 칸이 빈칸이 아니면 못 옮겨요.\n"
		+ "  · 닌자는 가로 · 세로로 막힐 때까지의 아무 칸으로 움직이거나(능력 없음), 움직이지 않고 앞·뒤 줄의 금색 영웅을 눌러 그 영웅의 이동과 능력을 따라 해요(적 사신과 적 닌자만 빼고 모든 영웅 가능). 로봇 모습이면 공격 · 무력 · 저주 · 조종이 안 통하고, 사신 모습이면 자동 공격을 하고, 전사 모습이면 주위 8칸의 적이 무력해지고, 기사 모습이면 말이 대신 죽어요. 따라 한 모습은 내 다음 차례가 시작될 때 닌자로 돌아와요. [b]닌자는 무엇을 따라 하든 성을 칠 수 없어요[/b].\n"
		+ "  · 기사는 [b]움직인 방향의 다음 칸[/b]을 공격해요. 제자리에 있으면 공격은 없어요. 병사는 상하좌우의 적 한 명을 공격하거나 상하좌우 빈칸 모두에 지뢰를 놓아요.\n"
		+ "  · [b]봉인[/b]: 마법사가 자리를 바꾼 뒤 옮긴 자리 주위 8칸의 적 한 명에게 걸어요(안 해도 돼요). 봉인은 [b]1턴[/b](상대의 다음 차례 한 번) 동안이고, 봉인된 영웅은 [b]이동만[/b] 할 수 있어요: 능력, 성 치기, 닌자의 따라 하기, 천사의 내려앉기 · 부활이 안 되고, 패시브는 그대로예요. 이동이 없는 마법사가 봉인되면 아무것도 못 해요. 배리어로 막지 못해요.\n"
		+ "  · 마법사의 파이어볼(3칸)은 한 방향에서 [b]처음 만나는 적[/b] 하나만 맞혀요. 뚫고 지나가지 못해서 아군 · 로봇 · [b]적군의 벽과 모든 포탑[/b]에 막히고, 유령과 내 벽은 지나가요. 범위 안의 상대 성도 칠 수 있어요.\n"
		+ "  · 성직자의 능력은 셋 중 하나예요: 배리어, 십자가, 천사를 위한 희생. [b]십자가[/b]는 상하좌우 바로 옆 칸의 적이나 [b]적 유령[/b]을 때려요. 마법사가 아군 유령과 자리를 바꾸면 유령은 마법사가 있던 칸으로 가요.\n"
		+ "  · [b]사신의 저주[/b]: 상하좌우 한 방향으로 2칸 안에서 처음 만나는 적이나 [b]적 유령[/b]에게 걸어요(아군 · 로봇 · [b]적군의 벽과 모든 포탑[/b]에 막혀요. 배리어가 있는 적과 [b]사신 · 천사[/b]에게는 못 걸어요). 다음부터 사신은 저주 걸린 적이나 적 유령의 자리로 [b]거리와 상관없이[/b] 가서 흔적도 없이 없앨 수 있어요(유령도 안 남아요). 저주 걸린 영웅이 다른 공격에 쓰러지면 [b]저주가 유령에게 남아요[/b]. 저주는 [b]한 번에 하나뿐[/b]이라 새로 걸면 걸려 있던 저주는 풀려요. 배리어를 받거나 부활해도 풀리고, 사신이 쓰러지면 적과 적 유령에게 걸린 모든 저주가 사라져요.\n"
		+ "  · [b]사신의 자동 공격[/b]: 사신이나 적이 멈춰서 사신의 대각선 4칸에 적이 놓이면 누구의 차례든 바로 공격받아요. 차례가 바뀔 때마다 대각선에 남아 있는 적도 공격해요. 지나가기만 하면 괜찮고, [b]배리어가 있으면 안 맞고[/b], 말 탄 기사는 [b]흑기사로 변신[/b]해요. 두 사신이 마주치면 동시에 공격해요. 로봇과 성은 공격하지 않아요. 사신은 [b]벽도 지나가요[/b]. 적 닌자는 사신을 따라 할 수 없어요. 저주에는 안 걸려요. 무력 · 밀기 · 봉인은 다른 영웅처럼 통하지만, 무력이나 스턴이어도 자동 공격은 해요. 사신 모습을 따라 한 닌자도 그 모습인 동안 똑같아요.\n"
		+ "  · 영웅을 고른 뒤 표시가 없는 빈칸을 누르면 고르기가 취소되고, 능력을 고를 때 누르면 능력을 안 쓰고 끝내요.\n"
		+ "  · 할 게 없으면 차례를 건너뛰어요.\n"
		+ "  · [b]무르기[/b]를 누르면 직전 행동 하나를 되돌려요. AI 대전에서는 그 뒤에 둔 AI 차례도 함께 되돌아가요.\n"
		+ "  · [b]온라인 대전[/b]: 게임을 켠 다른 사람과 빠른 매칭으로 붙어요. 내 성이 늘 아래에 보여요. 무르기는 안 되고, 상대가 나가면 내가 이겨요.\n"
		+ ("[color=#%s]8. 결전[/color]  %d차례가 지나면 %d차례마다 [b]두 성의 하트가 함께 1씩[/b] 줄어요. 앞선 쪽은 계속 앞서요! 단, 한쪽의 살아 있는 영웅이 [b]3명 이하[/b]이고 두 편 영웅 수가 [b]3명 이상[/b] 차이 나면 그 결전은 건너뛰어요.\n") % [
			c3, HeroLogic.COLLAPSE_START, HeroLogic.COLLAPSE_EVERY]
	)


func _mode_ids() -> Array:
	return MODE_IDS + ["online"]


func _mode_label(id: String) -> String:
	return "온라인 대전" if id == "online" else super(id)


func _add_setup_options(box: VBoxContainer) -> void:
	add_choice_row(box, "순서 (AI 대전)", ["내가 먼저", "AI 먼저", "랜덤"], order_choice, UIKit.GREEN,
		func(i: int) -> void: order_choice = i)
	box.add_child(UIKit.make_label("시작 전에 끝줄에서 영웅 자리를 정해요", 21, UIKit.INK_SOFT))


func _on_setup_opened() -> void:
	_busy = false
	_net_close()
	if board != null:
		board.input_enabled = false


## 온라인 대전의 상대도 사람이 누를 수 없는 차례로 다룸
func is_ai(p: int) -> bool:
	return (ai_level >= 0 or online) and p != human_player


func player_name(p: int) -> String:
	if online:
		return "나" if p == human_player else "상대"
	return super(p)


func subject(p: int) -> String:
	if online:
		return "내가" if p == human_player else "상대가"
	return super(p)


func who_prefix(p: int) -> String:
	return "" if online else super(p)


func _is_game_over() -> bool:
	return logic != null and logic.over


# ══════════════════════════════════════════════════════
#  화면 구성
# ══════════════════════════════════════════════════════
func _ready() -> void:
	game_id = "herochess"
	mode = str(Global.get_setting(game_id, "mode", "ai_normal"))
	order_choice = int(Global.get_setting(game_id, "order", 0))
	_rng.randomize()
	build_frame()
	content.add_theme_constant_override("separation", 10)
	for p in 2:
		var h := HeroHearts.new()
		h.custom_minimum_size = Vector2(0, 42)
		set_card_widget(p, h)
		_hearts.append(h)

	board = HeroBoard.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(0, 440)
	board.cell_tapped.connect(_on_cell)
	content.add_child(board)
	attach_toast(board)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	content.add_child(bottom)
	# 영웅 정보 칸
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", UIKit.panel_style(Color.WHITE, 28, 8))
	info.custom_minimum_size = Vector2(0, 104)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(info)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	info.add_child(hb)
	_portrait = HeroPortrait.new()
	_portrait.custom_minimum_size = Vector2(66, 70)
	hb.add_child(_portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	hb.add_child(vb)
	_info_name = UIKit.make_label("", 22, UIKit.INK, 800, HORIZONTAL_ALIGNMENT_LEFT)
	_info_name.clip_text = true
	vb.add_child(_info_name)
	_info_desc = UIKit.make_label("", 17, UIKit.INK_SOFT, 700, HORIZONTAL_ALIGNMENT_LEFT)
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.max_lines_visible = 3
	vb.add_child(_info_desc)
	# 버튼
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	bottom.add_child(btns)
	main_btn = UIKit.make_button("차례 끝", UIKit.PURPLE, Vector2(146, 56), 25)
	main_btn.disabled = true
	main_btn.pressed.connect(_on_main)
	btns.add_child(main_btn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	btns.add_child(row)
	undo_btn = UIKit.make_button("무르기", UIKit.ORANGE, Vector2(70, 40), 19)
	undo_btn.disabled = true
	undo_btn.pressed.connect(_on_undo)
	row.add_child(undo_btn)
	sub_btn = UIKit.make_button("새 게임", UIKit.GREEN, Vector2(70, 40), 19)
	sub_btn.pressed.connect(_on_sub)
	row.add_child(sub_btn)

	logic = HeroLogic.new()
	logic.setup(0)
	board.setup(logic)
	_show_info(-1)
	_refresh_ui()
	set_status("어떻게 플레이할지 골라 주세요")
	show_setup()


func _exit_tree() -> void:
	_token += 1
	_net_close()
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


func _process(delta: float) -> void:
	super(delta)
	if _thread != null and not _thread.is_alive():
		var result: Variant = _thread.wait_to_finish()
		_thread = null
		if _thread_token == _token:
			_apply_ai_result(result)


# ══════════════════════════════════════════════════════
#  게임 시작 · 배치
# ══════════════════════════════════════════════════════
func _start_game() -> void:
	_token += 1
	_busy = false
	_net_close()
	Global.set_setting(game_id, "mode", mode)
	Global.set_setting(game_id, "order", order_choice)
	apply_mode()
	close_overlay()
	if mode == "online":
		_start_online()
		return
	online = false
	board.flip = false
	ai = HeroAI.new(ai_level) if ai_level >= 0 else null
	human_player = 0
	var first := 0
	if ai_level >= 0:
		first = order_choice if order_choice < 2 else randi() % 2
	logic = HeroLogic.new()
	logic.setup(first)
	if ai_level >= 0:
		_place_order = [human_player]
	else:
		_place_order = [first, 1 - first]
	_load_places()
	board.setup(logic)
	_undo.clear()
	_summon_mode = false
	_summon_id = -1
	close_overlay()
	_begin_place(0)


## 직전에 시작한 판의 배치를 불러옴 (혼자 · 온라인은 내 배치, 둘이서는 빨강 · 파랑 따로)
func _load_places() -> void:
	_place_loaded = false
	for p: int in _place_order:
		if logic.use_place_list(p, Global.get_setting(game_id, _place_key(p), [])):
			_place_loaded = true


func _save_place(p: int) -> void:
	Global.set_setting(game_id, _place_key(p), logic.place_list(p))


func _place_key(p: int) -> String:
	return "place_blue" if p == 1 and ai_level < 0 and not online else "place"


func _begin_place(i: int) -> void:
	_placing = true
	_placer = int(_place_order[i])
	_place_sel = HeroLogic.NONE
	board.hide_team = 1 - human_player if ai_level >= 0 or online else -1
	board.home_glow = _placer
	board.selected = -1
	board.marks = {}
	board.pickable = []
	board.input_enabled = true
	_refresh_ui()
	set_status_side(_placer)
	set_status("%s영웅을 눌러 자리를 바꿔 보세요" % who_prefix(_placer))
	if _place_loaded and i == 0:
		toast("직전 배치를 불러왔어요 (바꿔도 돼요)")
	elif ai_level >= 0 or online:
		toast("끝줄에서 영웅 자리를 정해요")
	else:
		toast("%s 영웅 자리를 정해요" % _side_name(_placer))
	_update_buttons()


func _place_tap(c: Vector2i) -> void:
	var id := logic.at(c)
	if id >= 0:
		_show_info(id)
	if _place_sel == HeroLogic.NONE:
		if id >= 0 and HeroLogic.owner_of(id) == _placer:
			_place_sel = c
			board.selected = id
			board.hop(id)
			set_status("%s 바꿀 영웅을 누르세요" % josa(HeroLogic.NAMES[HeroLogic.kind_of(id)], "과", "와"))
		return
	if c == _place_sel:
		_place_sel = HeroLogic.NONE
		board.selected = -1
		set_status("%s영웅을 눌러 자리를 바꿔 보세요" % who_prefix(_placer))
		return
	var a := logic.at(_place_sel)
	var b := logic.at(c)
	var from := _place_sel
	if logic.place_swap(_placer, _place_sel, c):
		if a >= 0:
			board.slide(a, from, c, 0.22)
		if b >= 0:
			board.slide(b, c, from, 0.22)
		_place_sel = HeroLogic.NONE
		board.selected = -1
		set_status("%s영웅을 눌러 자리를 바꿔 보세요" % who_prefix(_placer))
	elif id >= 0 and HeroLogic.owner_of(id) == _placer:
		_place_sel = c
		board.selected = id
	else:
		toast("내 영웅끼리만 자리를 바꿀 수 있어요")


func _finish_place() -> void:
	_place_sel = HeroLogic.NONE
	board.selected = -1
	_save_place(_placer)
	var i := _place_order.find(_placer)
	if i + 1 < _place_order.size():
		_begin_place(i + 1)
		return
	if online:
		_net_send_place()
		return
	_placing = false
	board.home_glow = -1
	board.input_enabled = false
	if ai_level >= 0:
		var side := 1 - human_player
		ai.choose_formation(logic, side)
		board.hide_team = -1
		board.sync()
		for id in logic.heroes_of(side):
			board.spawn(id, logic.pos[id], randf() * 0.25)
	logic.start_play()
	board.sync()
	if ai_level >= 0:
		toast("내가 먼저 해요!" if logic.current == human_player else "AI가 먼저 해요")
	else:
		toast("%s 먼저 해요!" % josa(_side_name(logic.current), "이", "가"))
	_next_turn()


# ══════════════════════════════════════════════════════
#  게임 진행
# ══════════════════════════════════════════════════════
func _clear_marks() -> void:
	board.selected = -1
	board.marks = {}
	board.pickable = []
	board.castle_glow = -1


func _next_turn() -> void:
	board.input_enabled = false
	_clear_marks()
	_summon_mode = false
	_summon_id = -1
	_refresh_ui()
	if logic.collapsed_now and logic.used == 0:
		board.castle_hit(0)
		board.castle_hit(1)
		toast("결전! 두 성이 함께 흔들려요 (하트 -1)")
	elif logic.collapse_skipped and logic.used == 0:
		toast("영웅 수 차이가 커서 이번 결전은 건너뛰어요")
	if logic.over:
		_update_buttons()
		_game_over()
		return
	if board.info_id >= 0 and not logic.alive(board.info_id):
		_show_info(-1)
	if logic.passed >= 0 and logic.used == 0:
		toast("%s 할 수 있는 게 없어서 차례를 넘겨요" % subject(logic.passed))
	_update_buttons()
	if is_ai(logic.current):
		if online:
			_wait_remote()
		else:
			_start_ai()
		return
	_idle_prompt()


## 사람 차례에서 영웅을 고르기 전 화면
func _idle_prompt() -> void:
	board.input_enabled = true
	board.selected = -1
	board.marks = {}
	board.pickable = logic.selectable()
	board.castle_glow = logic.current if _can_summon() else -1
	var who := who_prefix(logic.current)
	if logic.used == 0:
		var left := logic.turns_to_collapse()
		if left > 0 and left <= 6:
			if logic.collapse_paused():
				set_status("%s영웅 두 명을 고르세요 · 영웅 수 차이로 결전 멈춤" % who)
			else:
				set_status("%s영웅 두 명을 고르세요 · 결전까지 %d차례" % [who, left])
		elif board.castle_glow >= 0:
			set_status("%s영웅이나 내 성을 고르세요" % who)
		else:
			set_status("%s영웅을 두 명까지 고르세요" % who)
	else:
		set_status(("%s영웅이나 성을 더 고르거나 '차례 끝'" if board.castle_glow >= 0 else "%s한 명 더 고르거나 '차례 끝'") % who)
	_update_buttons()


func _update_buttons() -> void:
	undo_btn.disabled = not _can_undo()
	if logic.over:
		main_btn.text = "결과 보기"
		main_btn.disabled = false
		sub_btn.text = "새 게임"
		return
	if _placing:
		main_btn.text = "배치 완료"
		main_btn.disabled = false
		sub_btn.text = "섞기"
		return
	var human := not is_ai(logic.current) and not _busy and _thread == null
	sub_btn.text = "새 게임"
	if logic.act_hero >= 0 and logic.act_optional:
		main_btn.text = "능력 안 씀"
		main_btn.disabled = not human
	else:
		main_btn.text = "차례 끝"
		main_btn.disabled = not (human and logic.act_hero < 0 and logic.used > 0 and not _summon_mode)
	if human and ((logic.act_hero >= 0 and not logic.act_started) or _summon_mode):
		sub_btn.text = "취소"


## 포탑 주인 ("내" / "AI" / "빨강")
func _side_owner(p: int) -> String:
	if online:
		return "내" if p == human_player else "상대"
	if ai_level >= 0:
		return "내" if p == human_player else "AI"
	return _side_name(p)


## 누구의 무슨 영웅인지 ("내 사신", "AI 기사", "빨강 마법사")
func _hero_name(id: int) -> String:
	var o := HeroLogic.owner_of(id)
	var who := ""
	if online:
		who = "내" if o == human_player else "상대"
	elif ai_level >= 0:
		who = "내" if o == human_player else "AI"
	else:
		who = _side_name(o)
	return "%s %s" % [who, HeroLogic.NAMES[HeroLogic.kind_of(id)]]


func _show_info(id: int, kind_override: int = -1) -> void:
	board.info_id = id
	if id < 0:
		_portrait.kind = -1
		_portrait.team = UIKit.player_color(human_player)
		_info_name.text = "영웅을 눌러 보세요"
		_info_name.add_theme_color_override("font_color", UIKit.INK)
		_info_desc.text = "영웅이나 성을 누르면 누구 것이든 능력을 볼 수 있어요"
		return
	var o := HeroLogic.owner_of(id)
	# 따라 한 모습을 유지하는 닌자
	var form := -1
	if kind_override < 0 and HeroLogic.kind_of(id) == K.NINJA and logic.alive(id) and logic.ninja_form[o] >= 0:
		form = logic.ninja_form[o]
		kind_override = form
	var k := HeroLogic.kind_of(id) if kind_override < 0 else kind_override
	_portrait.kind = k
	_portrait.team = UIKit.player_color(o)
	var tag := ""
	if logic.alive(id):
		if logic.disabled_by[id] >= 0:
			tag = " (무력)"
		elif logic.stunned[id] != 0:
			tag = " (스턴)"
		elif logic.barrier[id] != 0:
			tag = " (배리어)"
		if HeroLogic.kind_of(id) == K.KNIGHT and logic.horse[id] == 0:
			tag += " (말 없음)"
		if logic.dark[id] != 0:
			tag += " (흑기사)"
		if logic.cursed_by[id] >= 0:
			tag += " (저주)"
		if logic.sealed[id] != 0:
			tag += " (봉인)"
	elif logic.has_ghost(id):
		tag = " 유령" + (" (저주)" if logic.cursed_by[id] >= 0 else "")
	var nm := _hero_name(id)
	if kind_override >= 0:
		nm += "→" + HeroLogic.NAMES[k]
	_info_name.text = nm + tag
	_info_name.add_theme_color_override("font_color", UIKit.player_dark(o))
	_info_desc.text = DESC[k] if logic.alive(id) or not logic.has_ghost(id) else GHOST_DESC
	if form >= 0:
		_info_desc.text = "지금 %s 모습이에요. 이 편의 다음 차례가 시작되면 닌자로 돌아와요." % HeroLogic.NAMES[form]


func _show_turret(c: Vector2i) -> void:
	var o := logic.turret_at(c)
	board.info_id = -1
	_portrait.kind = -1
	_portrait.team = UIKit.player_color(o)
	_info_name.text = "%s 포탑" % _side_owner(o)
	_info_name.add_theme_color_override("font_color", UIKit.player_dark(o))
	_info_desc.text = "주위 8칸에 멈춘 적을 자동 공격해요(배리어도 뚫어요). 로봇만 부술 수 있어요."


## 성의 능력 설명 (영웅처럼 누르면 나옴)
func _show_castle(p: int) -> void:
	board.info_id = -1
	_portrait.kind = -1
	_portrait.team = UIKit.player_color(p)
	_info_name.text = "%s 성" % _side_owner(p)
	_info_name.add_theme_color_override("font_color", UIKit.player_dark(p))
	_info_desc.text = CASTLE_DESC


## 쓰러진 천사의 십자가 설명
func _show_cross(c: Vector2i) -> void:
	var o := logic.cross_at(c)
	board.info_id = -1
	_portrait.kind = -1
	_portrait.team = UIKit.player_color(o)
	_info_name.text = "%s 십자가" % _side_owner(o)
	_info_name.add_theme_color_override("font_color", UIKit.player_dark(o))
	_info_desc.text = "쓰러진 천사의 십자가. 성직자가 내 성 옆에서 희생하면 천사가 이 칸에서 부활해요. 지나갈 수만 있고 포탑이 되면 사라져요."


# ── 사람 차례 ─────────────────────────────────────────
func _on_cell(c: Vector2i) -> void:
	if _busy or _thread != null:
		return
	if _placing:
		_place_tap(c)
		return
	if logic.over or is_ai(logic.current):
		return
	var id := logic.at(c)
	if id < 0:
		id = logic.ghost_at(c)   # 영웅이 없으면 그 칸의 유령
	if id < 0 and logic.turret_at(c) >= 0 and logic.act_hero < 0 and not _summon_mode:
		_show_turret(c)
		return
	if id < 0 and logic.cross_at(c) >= 0 and logic.act_hero < 0 and not _summon_mode:
		_show_cross(c)
		return
	if _summon_mode:
		if _summon_id >= 0 and board.marks.has(c):
			_human_summon(c)
		elif id >= 0 and logic.alive(id) and logic.summon_ids().has(id):
			_pick_summon(id)
		elif c == HeroLogic.CASTLE[logic.current]:
			_cancel_summon()
			_show_castle(logic.current)   # 영웅처럼 다시 누르면 풀림
		elif id >= 0:
			_show_info(id)
		return
	if logic.act_hero >= 0:
		if board.marks.has(c):
			if board.marks.has(c + HeroLogic.SIDE):
				_ask_side(c)   # 로봇: 같은 쪽의 영웅을 밀지 벽을 부술지 고르기
			else:
				_human_choose(c)
			return
		# 고르기만 했으면 내 성을 눌러 바로 성 소환 (취소를 따로 안 눌러도 됨)
		if not logic.act_started and c == HeroLogic.CASTLE[logic.current] and _can_summon():
			_open_summon()
			return
		# 표시 없는 빈칸: 고르기만 했으면 취소, 능력을 고르는 중이면 능력 안 쓰고 끝
		var empty := id < 0 and logic.turret_at(c) < 0 and logic.cross_at(c) < 0 and not logic.is_castle(c)
		if not logic.act_started:
			if id >= 0 and id != logic.act_hero and HeroLogic.owner_of(id) == logic.current:
				logic.cancel_action()
				if not _try_begin(id, true):
					_idle_prompt()
				return
			if id == logic.act_hero:
				logic.cancel_action()
				_show_info(id)
				_idle_prompt()
				return
			if empty:
				logic.cancel_action()
				_show_info(-1)
				_idle_prompt()
				return
		elif empty and logic.act_optional:
			_stop_ability()
			return
		if id >= 0:
			_show_info(id)
		elif logic.cross_at(c) >= 0:
			_show_cross(c)
		elif logic.is_castle(c):
			_show_castle(0 if c == HeroLogic.CASTLE[0] else 1)
		return
	# 아무것도 안 고른 상태
	if logic.is_castle(c):
		var cp := 0 if c == HeroLogic.CASTLE[0] else 1
		_show_castle(cp)
		if cp == logic.current:
			if board.castle_glow >= 0:
				_open_summon()
			elif logic.lives[cp] < HeroLogic.SUMMON_LIVES:
				toast("하트가 2개 이상일 때만 불러올 수 있어요")
			elif logic.summon_cells().is_empty():
				toast("성 주위에 빈칸이 없어요")
			else:
				toast("지금은 불러올 영웅이 없어요")
		return
	if id < 0:
		_show_info(-1)
		return
	_show_info(id)
	if HeroLogic.owner_of(id) == logic.current:
		_try_begin(id, true)


func _try_begin(id: int, explain: bool) -> bool:
	if logic.act_hero >= 0:
		logic.cancel_action()
	if logic.begin_action(id):
		_net_taps = [id]
		board.hop(id)
		_show_info(id)
		_show_step()
		return true
	if explain:
		if logic.has_acted(id):
			toast("이번 차례에 이미 움직였어요")
		elif logic.disabled_by[id] >= 0:
			toast("적 전사 주위 8칸이라 무력해요 (이동 · 능력을 못 써요)")
		elif logic.stunned[id] != 0:
			toast("스턴돼서 이번 차례에는 못 움직여요")
		elif HeroLogic.kind_of(id) == K.MAGICIAN and logic.sealed[id] != 0:
			toast("능력이 봉인됐어요 (마법사는 이동이 없어요)")
		elif HeroLogic.kind_of(id) == K.MAGICIAN:
			toast("지금은 쓸 수 있는 능력이 없어요")
		else:
			toast("지금은 갈 수 있는 곳이 없어요")
	return false


## 진행 중인 행동의 지금 단계 표시
func _show_step() -> void:
	var opts := logic.step_options()
	board.selected = logic.act_hero
	board.marks = opts
	board.pickable = []
	board.castle_glow = logic.current if not logic.act_started and _can_summon() else -1
	board.input_enabled = true
	var what := ""
	match logic.act_step:
		ST.SPIRIT:
			what = "유령이 갈 칸을 고르세요 (상하좌우 한 칸)"
		ST.MOVE:
			what = "갈 칸을 고르세요"
			if opts.has(logic.pos[logic.act_hero]):
				what = "갈 칸을 고르세요 (자기를 누르면 제자리)"
			if logic.act_kind == K.KNIGHT:
				what = "갈 칸을 고르세요 (움직인 방향으로 공격, 제자리면 공격 없음)"
			if logic.act_kind == K.ROBOT:
				what = "갈 칸 고르기 (움직인 방향의 적을 밀어요)"
			if logic.act_kind == K.ANGEL and opts.values().has("land"):
				what = "갈 칸 고르기 (영웅 칸 = 조종해 공격)"
			if logic.act_kind == K.ANGEL:
				if opts.values().has("revive"):
					what = "갈 칸 고르기 (아군 유령 칸 = 부활)"
			if logic.act_kind == K.NINJA:
				# 닌자: 가로 · 세로 이동, 또는 금색으로 표시된 앞 줄 영웅을 눌러 따라 하기
				if opts.values().has("copy"):
					what = "가로·세로 이동, 또는 금색 영웅을 눌러 따라 하기"
				else:
					what = "가로·세로 이동 (앞뒤 줄에 따라 할 영웅이 없어요)"
		ST.CARRY:
			what = "주위 8칸 공격 또는 옮길 아군 고르기" if logic.dark[logic.act_hero] != 0 else "공격할 적이나 옮길 아군을 고르세요"
		ST.STRIKE:
			what = "적을 누르면 주위 8칸 모두 공격" if logic.dark[logic.act_hero] != 0 else "공격할 적을 고르세요"
		ST.MINE:
			what = "지뢰 칸을 누르면 모두 놓아요"
			if opts.values().has("attack") or opts.values().has("castle"):
				what = "공격할 적, 또는 지뢰 칸(모두 놓기)"
		ST.REVIVE:
			what = "부활할 칸(내 성 근처)을 고르세요"
		ST.SWAP_FIRE:
			what = "바꿀 아군·유령이나 쏠 적을 고르세요"
		ST.SEAL:
			what = "능력을 봉인할 적을 고르세요"
		ST.BARRIER:
			what = "배리어 줄 아군이나 때릴 적·유령 고르기"
			if opts.values().has("rise"):
				what = "배리어·공격, 또는 십자가(천사 부활)"
		ST.PUSH:
			var can := PackedStringArray()
			if opts.values().has("push"):
				can.append("밀 적")
			if opts.values().has("pull"):
				can.append("끌 영웅")
			if opts.values().has("turret") or opts.values().has("break"):
				can.append("부술 벽·포탑")
			what = "%s 고르기" % " · ".join(can)
		ST.WARRIOR:
			what = "공격할 적이나 앞 칸(전진)을 고르세요"
		ST.REAP:
			what = "저주할 적·유령이나 저주 걸린 적 고르기"
		ST.LAND:
			what = "공격할 적 고르기 (원래 칸 = 돌아가기)"
			if opts.size() == 1:
				what = "공격할 적이 없어요 (원래 칸 = 돌아가기)"
		ST.EXIT:
			what = "포탑에서 나올 칸을 고르세요"
		ST.WALL:
			what = "벽을 세울 쪽 고르기 (내 벽 4개 = 포탑)"
	var nm: String = HeroLogic.NAMES[HeroLogic.kind_of(logic.act_hero)]
	if logic.act_ghost:
		nm += " 유령"
	if logic.act_copy >= 0:
		nm = "닌자→" + HeroLogic.NAMES[logic.act_kind]
		_show_info(logic.act_hero, logic.act_kind)
	set_status("%s: %s" % [nm, what])
	_update_buttons()


## 같은 쪽의 영웅을 밀지, 그 사이 벽을 부술지 고르는 팝업 (로봇)
func _ask_side(c: Vector2i) -> void:
	const NAMES := {"push": "밀기 · 스턴", "break": "벽 부수기", "turret": "포탑 부수기"}
	var tok := _token
	var box := open_overlay("side")
	box.add_child(UIKit.make_label("무엇을 할까요?", 40, UIKit.INK, 800))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for v: Vector2i in [c, c + HeroLogic.SIDE]:
		var mark := str(board.marks[v])
		var b := UIKit.make_button(str(NAMES.get(mark, "능력 쓰기")), UIKit.PURPLE if v == c else UIKit.ORANGE, Vector2(0, 96), 30)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			close_overlay()
			if tok == _token and not _busy and logic.act_hero >= 0 and logic.step_options().has(v):
				_human_choose(v))
		row.add_child(b)
	var no := UIKit.make_button("취소", UIKit.GREEN, Vector2(0, 80), 28)
	no.pressed.connect(close_overlay)
	box.add_child(no)


func _human_choose(c: Vector2i) -> void:
	board.input_enabled = false
	board.marks = {}
	if not logic.act_started:
		_save_undo()
	_busy = true
	_update_buttons()
	var tok := _token
	_net_taps.append(c)
	var ev := logic.choose(c)
	await _play(ev)
	if tok != _token:
		return
	_busy = false
	_after_step()


## 한 단계가 끝난 뒤: 남은 단계 → 같은 사람 차례 → 다음 차례
func _after_step() -> void:
	_net_flush()
	if logic.over:
		_next_turn()
		return
	if logic.act_hero >= 0:
		_show_step()
		return
	if is_ai(logic.current) or logic.used == 0:
		_next_turn()
		return
	_idle_prompt()


func _on_main() -> void:
	if logic.over:
		reopen_result()   # 게임이 끝난 뒤에는 '결과 보기' 버튼
		return
	if _busy or _thread != null:
		return
	if _placing:
		_finish_place()
		return
	if is_ai(logic.current):
		return
	if logic.act_hero >= 0 and logic.act_optional:
		_stop_ability()
	elif logic.act_hero < 0 and logic.used > 0 and not _summon_mode:
		board.input_enabled = false
		_busy = true
		var tok := _token
		logic.end_turn()
		if online and net != null:
			net.send({"k": "end", "h": logic.state_hash()})
		await _play(logic.last_events())   # 다음 차례 시작의 포탑 공격 등
		if tok != _token:
			return
		_busy = false
		_next_turn()


## 능력 안 쓰고 이번 영웅 행동 끝내기
func _stop_ability() -> void:
	if not logic.act_started:
		_save_undo()
	board.input_enabled = false
	_busy = true
	var tok := _token
	_net_taps.append(HeroLogic.STOP)
	var ev := logic.stop_action()
	await _play(ev)
	if tok != _token:
		return
	_busy = false
	_after_step()


func _on_sub() -> void:
	if _busy or _thread != null:
		return
	if _placing:
		logic.random_formation(_placer, _rng)
		board.sync()
		for id in logic.heroes_of(_placer):
			board.hop(id)
		_place_sel = HeroLogic.NONE
		board.selected = -1
		return
	if not logic.over and not is_ai(logic.current):
		if _summon_mode:
			_cancel_summon()
			return
		if logic.act_hero >= 0 and not logic.act_started:
			logic.cancel_action()
			_idle_prompt()
			return
	show_setup()


# ── 무르기 ────────────────────────────────────────────
## 사람이 행동(또는 소환)을 시작하기 직전 상태를 저장. 고르기만 한 영웅은 풀어서 저장
func _save_undo() -> void:
	var snap := logic.clone()
	if snap.act_hero >= 0 and not snap.act_started:
		snap.cancel_action()
	_undo.append(snap)
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()


func _can_undo() -> bool:
	if online:
		return false   # 온라인 대전에서는 무르기 없음
	if _undo.is_empty() or logic == null or logic.over or _placing or _busy or _thread != null:
		return false
	return not is_ai(logic.current)


## 직전 행동 하나를 되돌림. AI 대전이면 그 뒤에 둔 AI 차례도 함께 되돌아감
func _on_undo() -> void:
	if not _can_undo():
		return
	var snap: HeroLogic = _undo.pop_back()
	var crossed := snap.turn != logic.turn
	logic = snap
	logic.log_events = true
	_summon_mode = false
	_summon_id = -1
	board.setup(logic)
	_show_info(-1)
	_refresh_ui()
	if ai_level >= 0 and crossed:
		toast("AI 차례까지 함께 물렀어요")
	else:
		toast("한 행동 물렀어요")
	_idle_prompt()


# ── 성 소환 (판 위의 내 영웅을 성 주위로 불러오기) ──
## 지금 소환할 수 있는지 (행동이 남음 · 하트 2개 이상 · 불러올 수 있는 내 영웅 · 성 주위 빈칸). 고르기만 한 영웅이 있어도 됨
func _can_summon() -> bool:
	if logic.over or logic.phase != HeroLogic.Phase.ACT or logic.used >= HeroLogic.MAX_ACTIONS:
		return false
	if logic.act_hero >= 0 and logic.act_started:
		return false
	return not logic._summonable(logic.current).is_empty() and not logic.summon_cells().is_empty()


func _open_summon() -> void:
	if logic.act_hero >= 0 and not logic.act_started:
		logic.cancel_action()   # 고르기만 한 영웅은 풀고 소환으로
	var ids := logic.summon_ids()
	if ids.is_empty():
		return
	_summon_mode = true
	_summon_id = -1
	_show_castle(logic.current)
	var m := {}
	for id in ids:
		m[logic.pos[id]] = "summon"
	board.marks = m
	board.selected = -1
	board.pickable = []
	board.castle_glow = logic.current
	set_status("성으로 불러올 영웅 고르기 (내 성 하트 -1)")
	_update_buttons()


func _pick_summon(id: int) -> void:
	_summon_mode = true
	_summon_id = id
	var m := {}
	for c in logic.summon_cells():
		m[c] = "summon"
	board.marks = m
	board.selected = id
	board.hop(id)
	board.pickable = []
	board.castle_glow = logic.current
	_show_info(id)
	set_status("%s 불러올 성 주위 칸을 고르세요" % josa(HeroLogic.NAMES[HeroLogic.kind_of(id)], "을", "를"))
	_update_buttons()


func _cancel_summon() -> void:
	_summon_mode = false
	_summon_id = -1
	_idle_prompt()


func _human_summon(c: Vector2i) -> void:
	_save_undo()
	board.input_enabled = false
	_busy = true
	var tok := _token
	var sid := _summon_id
	var ev := logic.do_summon(_summon_id, c)
	if online and net != null:
		net.send({"k": "summon", "id": sid, "c": HeroNet.cell(c), "h": logic.state_hash()})
	_summon_mode = false
	_summon_id = -1
	_clear_marks()
	await _play(ev)
	if tok != _token:
		return
	_busy = false
	if logic.alive(sid):
		_show_info(sid)   # 무력이 풀린 것 등을 새로 보여 줌
	_next_turn()


# ── 효과 ──────────────────────────────────────────────
func _cell_of(id: int) -> Vector2i:
	if logic.alive(id):
		return logic.pos[id]
	return logic.ghost_pos[id]


func _play(evs: Array) -> void:
	var tok := _token
	var i := 0
	while i < evs.size():
		var d := _play_one(evs[i])
		# 기사가 데려가는 아군은 함께 움직임
		while i + 1 < evs.size() and str(evs[i + 1]["t"]) == "move" and (evs[i + 1] as Dictionary).has("ride"):
			i += 1
			var e: Dictionary = evs[i]
			board.slide(e["id"], e["from"], e["to"], 0.36)
		i += 1
		if d > 0.0:
			await wait(d)
			if tok != _token:
				return
	var left := board.busy_time()
	if left > 0.0:
		await wait(left)
		if tok != _token:
			return
	board.sync()
	_refresh_ui()


## 일어난 일 하나 보여 주기. 다음 일까지 기다릴 시간
func _play_one(e: Dictionary) -> float:
	match str(e["t"]):
		"move":
			var id: int = e["id"]
			var from: Vector2i = e["from"]
			var to: Vector2i = e["to"]
			var path: Array = e.get("path", [from, to])
			var steps := path.size() - 1
			match int(e["style"]):
				K.KNIGHT:
					var dur := 0.16 + 0.12 * steps
					board.slide_path(id, path, dur)
					for n in steps:
						board.fx("dust", path[n], path[n], Color.WHITE, n * dur / steps)
					return dur + 0.02
				K.ROBOT:
					board.slide(id, from, to, 0.12 + 0.05 * (absi(to.x - from.x) + absi(to.y - from.y)))
					board.fx("spark", from, from, Color("#7FE3FF"))
					board.fx("spark", to, to, Color("#FFE066"), 0.2)
					return 0.3
				K.NINJA:
					board.fx("smoke", from)
					board.slide(id, from, to, 0.2)
					board.fx("smoke", to, to, Color.WHITE, 0.15)
					return 0.3
				K.ANGEL:
					# 날개로 훌쩍 (영웅을 뛰어넘을 수 있음)
					var dur := 0.2 + 0.12 * steps
					board.slide_path(id, path, dur)
					board.fx("stars", to, to, Color("#FFF3B0"), dur * 0.8, 0.4)
					return dur + 0.02
				_:
					var dur := 0.16 + 0.1 * steps
					board.slide_path(id, path, dur)
					return dur + 0.02
		"attack":
			var by: int = e["by"]
			board.hop(by)
			board.attack_fx(int(e["style"]), e["from"], e["cell"])
			var victim: int = e["victim"]
			var verb: String = {K.MAGICIAN: "파이어볼", K.PRIEST: "십자가 공격"}.get(int(e["style"]), "공격")
			toast("%s %s %s!" % [josa(_hero_name(by), "이", "가"), josa(_hero_name(victim), "에게", "에게"), verb])
			match int(e["style"]):
				K.MAGICIAN:
					return 0.62
				K.PRIEST:
					return 0.42
				K.KNIGHT:
					return 0.3
			return 0.24
		"castle":
			var by: int = e["by"]
			var p: int = e["p"]
			board.hop(by)
			board.attack_fx(int(e["style"]), e["from"], HeroLogic.CASTLE[p])
			board.castle_hit(p, 0.15)
			var left: int = e["left"]
			toast("성 공격! %s" % ("성이 무너졌어요!" if left <= 0 else "하트 %d개 남음" % left))
			_refresh_ui()
			return 0.6
		"shield":
			board.fx("pop", e["cell"])
			toast("배리어가 깨졌어요!")
			return 0.3
		"guard":
			board.fx("ring", e["cell"], e["cell"], Color("#5BC8F5"))
			toast("배리어가 자동 공격을 막았어요!")
			return 0.2
		"dark":
			board.fx("spook", e["cell"], e["cell"], Color("#8A4FC0"))
			board.fx("ring", e["cell"], e["cell"], Color("#5A2D82"), 0.1, 0.5)
			toast("%s 흑기사로 변신했어요! (주위 8칸 공격)" % josa(_hero_name(e["id"]), "이", "가"))
			return 0.45
		"dark_off":
			return 0.0
		"sweep":
			board.hop(e["by"])
			board.fx("ring", e["cell"], e["cell"], Color("#8A4FC0"), 0.0, 0.5)
			board.fx("reap", e["cell"], e["cell"], Color.WHITE, 0.05)
			toast("흑기사가 주위를 휩쓸었어요!")
			return 0.3
		"horse_off":
			board.fx("burst", e["cell"], e["cell"], Color("#A8703F"))
			board.fx("dust", e["cell"])
			board.hop(e["id"])
			toast("%s 말이 대신 쓰러졌어요!" % _hero_name(e["id"]))
			return 0.35
		"horse_on":
			board.fx("stars", e["cell"], e["cell"], Color("#FFE066"), 0.0, 0.5)
			toast("%s 다시 말을 탔어요!" % josa(_hero_name(e["id"]), "이", "가"))
			return 0.3
		"stun":
			board.fx("stun", _cell_of(e["id"]))
			toast("%s 스턴됐어요 (다음 차례에 못 움직여요)" % josa(_hero_name(e["id"]), "이", "가"))
			return 0.35
		"stun_off":
			return 0.0
		"sacrifice":
			board.fx("holy", e["cell"], e["cell"], Color("#FFF3B0"))
			board.hop(e["id"])
			toast("%s 희생해 천사를 부활시켜요" % josa(_hero_name(e["id"]), "이", "가"))
			return 0.5
		"cross":
			# 쓰러진 천사의 자리에 십자가
			board.cross_spawn(int(e["p"]), e["cell"], 0.4)
			board.fx("rise", e["cell"], e["cell"], Color("#FFF3B0"), 0.35)
			return 0.1
		"cross_gone":
			# 십자가가 있던 칸이 포탑이 됨
			board.cross_gone(int(e["p"]))
			board.fx("spook", e["cell"], e["cell"], Color("#FFF3B0"))
			toast("%s 천사의 십자가가 사라졌어요" % _side_owner(int(e["p"])))
			return 0.45
		"pull":
			board.slide(e["id"], e["from"], e["to"], 0.25)
			board.hop(e["by"])
			board.fx("dust", e["to"])
			board.fx("spark", e["to"], e["to"], Color("#7FE3FF"), 0.1)
			toast("로봇이 %s 끌어당겼어요!" % josa(_hero_name(e["id"]), "을", "를"))
			return 0.15
		"push":
			board.slide(e["id"], e["from"], e["to"], 0.22)
			board.fx("dust", e["to"])
			board.fx("spark", e["from"], e["from"], Color("#7FE3FF"))
			toast("로봇이 밀어냈어요!")
			return 0.12
		"die":
			var id: int = e["id"]
			board.poof(id)
			match str(e["cause"]):
				"mine":
					toast("쾅! %s 지뢰를 밟았어요" % josa(_hero_name(id), "이", "가"))
				"aura":
					toast("%s 사신의 낫에 쓰러졌어요" % josa(_hero_name(id), "이", "가"))
				"curse":
					toast("%s 저주로 쓰러졌어요" % josa(_hero_name(id), "이", "가"))
				"house":
					toast("%s 포탑에 갇혀 쓰러졌어요" % josa(_hero_name(id), "이", "가"))
				"turret":
					toast("%s 포탑에 맞아 쓰러졌어요" % josa(_hero_name(id), "이", "가"))
			return 0.32
		"mine":
			var laid: Array = e["cells"]
			var gone: Array = e["off"]
			for mc: Vector2i in laid:
				board.fx("dust", mc)
				board.fx("spark", mc, mc, Color("#FFE066"), 0.05)
			for mc: Vector2i in gone:
				board.fx("boom", mc)
			if gone.is_empty():
				toast("지뢰를 %d개 심었어요" % laid.size())
			elif laid.is_empty():
				toast("지뢰끼리 터졌어요!")
			else:
				toast("지뢰 %d개를 심고 %d칸은 터졌어요!" % [laid.size(), gone.size()])
			return 0.2 if gone.is_empty() else 0.35
		"ghost":
			# 쓰러진 영웅이 그 자리에 유령으로
			board.ghost_spawn(e["id"], e["cell"], 0.45)
			board.fx("rise", e["cell"], e["cell"], Color("#C9D6FF"), 0.35)
			return 0.1
		"ghost_move":
			var gpath: Array = e["path"]
			var gdur := 0.12 * (gpath.size() - 1) + 0.12
			board.ghost_slide(e["id"], gpath, gdur)
			for j in range(1, gpath.size()):
				board.fx("swirl", gpath[j], gpath[j], Color("#C9D6FF"), 0.12 * (j - 1), 0.35)
			return gdur + 0.05
		"ghost_gone":
			board.ghost_poof(e["id"])
			toast("%s 유령이 사라졌어요" % _hero_name(e["id"]))
			return 0.45
		"holy":
			board.hop(e["by"])
			board.attack_fx(K.PRIEST, e["from"], e["cell"])
			return 0.42
		"boom":
			board.fx("boom", e["cell"])
			return 0.3
		"turret":
			var tc: Vector2i = e["cell"]
			board.fx("stars", tc, tc, Color("#FFE066"), 0.0, 0.6)
			for d in HeroLogic.DIRS4:
				board.fx("build", tc, tc + d)
			toast("%s 포탑 완성!" % (_side_owner(int(e["p"]))))
			return 0.5
		"turret_fire":
			var col := UIKit.player_color(int(e["p"]))
			board.fx("fireball", e["cell"], e["target"], col, 0.0, 0.45)
			board.fx("burst", e["target"], e["target"], col, 0.3)
			toast("포탑이 %s 쐈어요!" % josa(_hero_name(e["id"]), "을", "를"))
			return 0.5
		"turret_gone":
			var gc: Vector2i = e["cell"]
			board.attack_fx(int(e["style"]), e["from"], gc)
			for d in HeroLogic.DIRS4:
				board.fx("crumble", gc, gc + d, Color.WHITE, 0.15)
			board.fx("dust", gc, gc, Color.WHITE, 0.2)
			toast("%s 포탑이 무너졌어요!" % _side_owner(int(e["p"])))
			return 0.5
		"defuse":
			board.fx("spark", e["cell"], e["cell"], Color("#FFE066"))
			toast("%s 지뢰를 없앴어요" % josa(_hero_name(e["id"]), "이", "가"))
			return 0.3
		"reap":
			var by: int = e["by"]
			board.hop(by)
			board.fx("ring", e["at"], e["at"], Color("#5A2D82"), 0.0, 0.5)
			for c in e["cells"]:
				board.fx("reap", c, c, Color.WHITE, 0.1)
			toast("%s 낫을 휘둘렀어요! (%d명)" % [josa(_hero_name(by), "이", "가"), (e["cells"] as Array).size()])
			return 0.45
		"disable":
			var ids: Array = e["ids"]
			board.fx("shock", _cell_of(e["by"]), _cell_of(e["by"]), Color("#E0884A"))
			for x in ids:
				board.fx("stun", _cell_of(x))
			toast("%s 무력해졌어요 (전사 주위 8칸)" % josa(_hero_name(ids[0]), "이", "가"))
			return 0.4
		"free":
			return 0.0
		"swap":
			board.slide(e["a"], e["pa"], e["pb"], 0.32)
			board.slide(e["b"], e["pb"], e["pa"], 0.32)
			board.fx("swirl", e["pa"], e["pa"], Color("#B48CFF"))
			board.fx("swirl", e["pb"], e["pb"], Color("#B48CFF"))
			toast("뿅! 자리 바꾸기")
			return 0.36
		"revive":
			board.ghost_poof(e["id"])
			if e.has("cross"):
				board.cross_gone(int(e["cross"]))
			board.spawn(e["id"], e["cell"])
			toast("%s 부활했어요!" % josa(_hero_name(e["id"]), "이", "가"))
			return 0.55
		"summon":
			var p: int = HeroLogic.owner_of(e["id"])
			board.fx("swirl", e["from"], e["from"], Color("#FFC93C"))
			board.fx("smoke", e["from"], e["from"], Color.WHITE, 0.1)
			board.fx("swirl", HeroLogic.CASTLE[p], HeroLogic.CASTLE[p], Color("#FFC93C"))
			board.spawn(e["id"], e["cell"], 0.25)
			board.castle_hit(p, 0.1)
			toast("성으로 %s 불러왔어요! (하트 %d개 남음)" % [josa(HeroLogic.NAMES[HeroLogic.kind_of(e["id"])], "을", "를"), int(e["left"])])
			_refresh_ui()
			return 0.75
		"barrier":
			board.fx("bubble", _cell_of(e["id"]))
			toast("%s 배리어!" % _hero_name(e["id"]))
			return 0.4
		"seal":
			board.hop(e["by"])
			board.fx("fireball", e["from"], e["cell"], Color("#8A4FC0"), 0.0, 0.4)
			board.fx("spook", e["cell"], e["cell"], Color("#B48CFF"), 0.2)
			toast("%s 능력이 1턴 동안 봉인됐어요!" % _hero_name(e["id"]))
			return 0.5
		"seal_off":
			for x in e["ids"]:
				if logic.alive(x):
					board.fx("pop", _cell_of(x))
			return 0.15
		"barrier_off":
			for x in e["ids"]:
				board.fx("pop", _cell_of(x))
			return 0.15
		"curse":
			board.hop(e["by"])
			board.fx("fireball", e["from"], e["cell"], Color("#5A2D82"), 0.0, 0.5)
			return 0.4
		"cursed":
			board.fx("spook", e["cell"], e["cell"], Color("#8A4FC0"))
			toast("%s 저주에 걸렸어요!" % (josa(_hero_name(e["id"]), "이", "가") if logic.alive(e["id"]) else _hero_name(e["id"]) + " 유령이"))
			return 0.5
		"uncurse":
			for x in e["ids"]:
				board.fx("stars", _cell_of(x), _cell_of(x), Color("#FFF3B0"))
			toast("저주가 풀렸어요")
			return 0.3
		"doom":
			# 사신이 저주 걸린 적의 자리로
			var db: int = e["by"]
			board.fx("smoke", e["from"], e["from"], Color("#5A2D82"))
			board.fx("spook", e["to"], e["to"], Color("#8A4FC0"))
			board.fx("reap", e["to"], e["to"], Color.WHITE, 0.15)
			board.spawn(db, e["to"], 0.3)
			toast("%s 저주 걸린 적을 잡으러 갔어요!" % josa(_hero_name(db), "이", "가"))
			return 0.5
		"wall":
			board.fx("build" if bool(e["on"]) else "crumble", e["a"], e["b"])
			toast("벽을 세웠어요!" if bool(e["on"]) else "벽을 허물었어요!")
			return 0.35
		"copy":
			board.fx("copy", _cell_of(e["src"]), _cell_of(e["id"]))
			var src_name: String = HeroLogic.NAMES[HeroLogic.kind_of(e["src"])]
			toast("닌자가 %s 따라 해요! (다음 차례가 시작될 때까지 이 모습)" % josa(src_name, "을", "를"))
			return 0.4
		"warp":
			# 마법사가 아군 유령과 자리를 바꿈
			board.fx("swirl", e["from"], e["from"], Color("#B48CFF"))
			board.fx("swirl", e["to"], e["to"], Color("#B48CFF"))
			board.spawn(e["id"], e["to"], 0.2)
			board.ghost_slide(e["ghost"], [e["to"], e["from"]], 0.4)
			toast("%s 유령과 자리를 바꿨어요" % josa(_hero_name(e["id"]), "이", "가"))
			return 0.5
		"ninja_back":
			board.fx("smoke", e["cell"])
			board.hop(e["id"])
			toast("%s 원래 모습으로 돌아왔어요" % josa(_hero_name(e["id"]), "이", "가"))
			return 0.35
		"home":
			# 천사가 이동 전 자리로 돌아감
			board.fx("stars", e["from"], e["from"], Color("#FFF3B0"), 0.0, 0.4)
			board.fx("swirl", e["from"], e["from"], Color("#FFC93C"))
			board.spawn(e["id"], e["to"], 0.15)
			return 0.45
	return 0.0


# ── AI 차례 (생각은 별도 스레드에서) ───────────────────
func _start_ai() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	board.input_enabled = false
	_update_buttons()
	start_thinking("AI가 작전 짜는 중")
	_ai_started_ms = Time.get_ticks_msec()
	_thread = Thread.new()
	_thread_token = _token
	_thread.start(ai.plan.bind(logic.clone()))


func _apply_ai_result(result: Variant) -> void:
	var tok := _token
	var plan: Array = result
	var wait_s := 0.5 - (Time.get_ticks_msec() - _ai_started_ms) / 1000.0
	if wait_s > 0.0:
		await wait(wait_s)
		if tok != _token:
			return
	_busy = true
	var me := logic.current
	for step in plan:
		var s: Dictionary = step
		if logic.over or logic.current != me:
			break
		if s.has("summon"):
			var id: int = s["summon"]
			set_status("AI가 성으로 %s 불러와요" % josa(HeroLogic.NAMES[HeroLogic.kind_of(id)], "을", "를"))
			board.selected = id
			board.hop(id)
			board.castle_glow = me
			board.marks = {s["cell"]: "summon"}
			await wait(0.6)
			if tok != _token:
				return
			_clear_marks()
			await _play(logic.do_summon(id, s["cell"]))
			if tok != _token:
				return
			continue
		var taps: Array = s["taps"]
		var hero: int = taps[0]
		if not logic.begin_action(hero):
			break
		set_status("AI: %s" % HeroLogic.NAMES[HeroLogic.kind_of(hero)])
		_show_info(hero)
		board.selected = hero
		board.hop(hero)
		for i in range(1, taps.size()):
			if logic.act_hero < 0 or logic.over:
				break
			var c: Vector2i = taps[i]
			if c == HeroLogic.STOP:
				await _play(logic.stop_action())
				if tok != _token:
					return
				continue
			var opts := logic.step_options()
			if logic.act_copy >= 0:
				_show_info(hero, logic.act_kind)
			board.selected = hero
			board.marks = {HeroLogic.real_cell(c): opts.get(c, "move")}
			await wait(0.45)
			if tok != _token:
				return
			board.marks = {}
			await _play(logic.choose(c))
			if tok != _token:
				return
		if logic.act_hero >= 0:   # 계획이 어긋나면 남은 단계는 건너뜀
			logic.stop_action()
			if logic.act_hero >= 0:
				logic.cancel_action()
		_clear_marks()
	if not logic.over and logic.current == me and logic.used > 0 and logic.act_hero < 0:
		logic.end_turn()
		await _play(logic.last_events())   # 다음 차례 시작의 포탑 공격 등
		if tok != _token:
			return
	if not logic.over and logic.current == me and logic.used == 0:
		logic.pass_turn()   # 계획을 못 했으면 차례를 넘김 (멈춤 방지)
		await _play(logic.last_events())
		if tok != _token:
			return
	_busy = false
	_next_turn()


# ══════════════════════════════════════════════════════
#  화면 갱신 / 결과
# ══════════════════════════════════════════════════════
func _refresh_ui() -> void:
	for p in 2:
		var active := not logic.over and logic.current == p and not _placing
		if _placing:
			active = p == _placer
		set_card(p, player_name(p), "", active, false)
		(_hearts[p] as HeroHearts).set_lives(logic.lives[p], HeroLogic.START_LIVES)
	set_status_side(_placer if _placing else logic.current)


func _game_over() -> void:
	if online:
		_net_over = true
		var tk := _token
		await wait(1.3)
		if tk != _token:
			return
		_online_result(logic.winner, "")
		return
	record_result(logic.winner)
	var w := logic.winner
	set_status("게임 끝! " + ("무승부예요" if w < 0 else "%s 이겼어요!" % subject(w)))
	var tok := _token
	await wait(1.3)
	if tok != _token:
		return
	var rows: Array = []
	for p in 2:
		rows.append({"p": p, "big": "하트 %d" % logic.lives[p], "small": "영웅 %d명 남음" % logic.count(p)})
	var note := ""
	match logic.end_reason:
		"castle":
			note = "%s 성을 무너뜨렸어요!" % subject(w)
		"collapse":
			if logic.lives[0] == logic.lives[1]:
				note = "결전에서 두 성이 함께 무너져서 남은 영웅 수로 정했어요"
			else:
				note = "결전! %s 끝까지 버텼어요" % subject(w)
		"stuck":
			note = "둘 다 할 수 있는 게 없어서 하트 · 남은 영웅 수로 정했어요"
		_:
			note = "%d차례가 지나서 하트 · 남은 영웅 수로 정했어요" % HeroLogic.MAX_TURNS
	show_standard_result(w, rows, note)


# ══════════════════════════════════════════════════════
#  온라인 대전 (server/relay_server.gd 중계 서버로 빠른 매칭)
#  두 폰이 같은 규칙 엔진으로 똑같이 계산하고, 내가 한 행동(탭 목록)만 상대에게 보냄
# ══════════════════════════════════════════════════════
func _start_online() -> void:
	online = true
	ai = null
	human_player = 0
	logic = HeroLogic.new()
	logic.setup(0)
	board.flip = false
	board.setup(logic)
	_undo.clear()
	_summon_mode = false
	_summon_id = -1
	_placing = false
	_net_inbox.clear()
	_net_their_place = {}
	_net_my_placed = false
	_net_applying = false
	_net_over = false
	_net_taps = []
	_refresh_ui()
	_update_buttons()
	net = OnlineClient.new()
	add_child(net)
	net.matched.connect(_on_net_matched)
	net.message.connect(_on_net_message)
	net.opponent_left.connect(_on_net_left)
	net.failed.connect(_on_net_failed)
	net.start(SERVER_URL, HeroNet.GAME, HeroNet.VER)
	var box := open_overlay("matching")
	box.add_child(UIKit.make_label("상대를 찾는 중…", 40, UIKit.INK, 800))
	box.add_child(UIKit.make_label("빠른 매칭을 누른 다른 사람과 이어 줘요", 24, UIKit.INK_SOFT))
	box.add_child(UIKit.make_label("서버가 잠들어 있으면 깨어나는 데 1분쯤 걸릴 수 있어요", 20, UIKit.INK_SOFT))
	var cancel := UIKit.make_button("그만 찾기", UIKit.PURPLE, Vector2(0, 96), 32)
	cancel.pressed.connect(show_setup)
	box.add_child(cancel)
	start_thinking("상대를 찾는 중")


func _net_close() -> void:
	if net != null:
		net.close()
		net.queue_free()
		net = null


func _on_net_matched(seat: int, first: int) -> void:
	close_overlay()
	human_player = seat
	logic = HeroLogic.new()
	logic.setup(first)
	board.flip = seat == 1   # 위쪽 자리면 판을 돌려 내 성이 아래로
	_place_order = [human_player]
	_load_places()
	board.setup(logic)
	_refresh_ui()
	toast("상대를 찾았어요!")
	_begin_place(0)


## 내 배치를 보내고, 상대 배치까지 오면 시작
func _net_send_place() -> void:
	_placing = false
	board.home_glow = -1
	board.input_enabled = false
	board.selected = -1
	_net_my_placed = true
	net.send(HeroNet.formation_msg(logic, human_player))
	set_status_side(human_player)
	start_thinking("상대가 배치를 마치길 기다려요")
	_update_buttons()
	_net_try_start()


func _net_try_start() -> void:
	if not _net_my_placed or _net_their_place.is_empty() or logic.phase != HeroLogic.Phase.PLACE:
		return
	if not logic.set_formation(1 - human_player, _net_their_place):
		_net_problem("상대 배치를 읽지 못했어요")
		return
	board.hide_team = -1
	board.sync()
	for id in logic.heroes_of(1 - human_player):
		board.spawn(id, logic.pos[id], randf() * 0.25)
	logic.start_play()
	board.sync()
	toast("내가 먼저 해요!" if logic.current == human_player else "상대가 먼저 해요")
	_next_turn()


## 내 행동 하나가 끝나면 상대에게 보냄
func _net_flush() -> void:
	if not online or net == null or _net_taps.size() < 2 or logic.act_hero >= 0:
		return
	net.send({"k": "act", "taps": HeroNet.encode_taps(_net_taps), "h": logic.state_hash()})
	_net_taps = []


func _on_net_message(d: Dictionary) -> void:
	if str(d.get("k", "")) == "place":
		_net_their_place = HeroNet.formation_cells(d)
		_net_try_start()
		return
	_net_inbox.append(d)
	_net_pump()


## 상대 차례 기다리기
func _wait_remote() -> void:
	board.input_enabled = false
	_update_buttons()
	start_thinking("상대 차례예요")
	_net_pump()


## 받은 일을 차례대로 보여 주며 적용
func _net_pump() -> void:
	if _net_applying or _busy or _net_over or logic == null or logic.phase != HeroLogic.Phase.ACT or logic.over:
		return   # 내 행동을 보여 주는 중이면 끝난 뒤(_wait_remote)에 이어서
	if _net_inbox.is_empty() or logic.current == human_player:
		return
	_net_applying = true
	_busy = true
	var tok := _token
	while not _net_inbox.is_empty() and not logic.over:
		var d: Dictionary = _net_inbox.pop_front()
		await _net_play(d)
		if tok != _token:
			return
		if logic.state_hash() != int(d.get("h", 0)):
			_net_applying = false
			_busy = false
			_net_problem("두 폰의 계산이 달라졌어요 (앱 버전을 맞춰 주세요)")
			return
	_net_applying = false
	_busy = false
	if logic.over or logic.current == human_player:
		_next_turn()
	else:
		start_thinking("상대 차례예요")


func _net_play(d: Dictionary) -> void:
	var tok := _token
	match str(d.get("k", "")):
		"act":
			var taps := HeroNet.decode_taps(d.get("taps", []))
			var hero: int = taps[0]
			if not logic.begin_action(hero):
				return
			set_status("상대: %s" % HeroLogic.NAMES[HeroLogic.kind_of(hero)])
			_show_info(hero)
			board.selected = hero
			board.hop(hero)
			for i in range(1, taps.size()):
				if logic.act_hero < 0 or logic.over:
					break
				var c: Vector2i = taps[i]
				if c == HeroLogic.STOP:
					await _play(logic.stop_action())
					if tok != _token:
						return
					continue
				var opts := logic.step_options()
				if logic.act_copy >= 0:
					_show_info(hero, logic.act_kind)
				board.selected = hero
				board.marks = {HeroLogic.real_cell(c): opts.get(c, "move")}
				await wait(0.4)
				if tok != _token:
					return
				board.marks = {}
				await _play(logic.choose(c))
				if tok != _token:
					return
			_clear_marks()
		"summon":
			var id := int(d["id"])
			var sc := HeroNet.to_cell(d["c"])
			set_status("상대가 성으로 %s 불러와요" % josa(HeroLogic.NAMES[HeroLogic.kind_of(id)], "을", "를"))
			board.selected = id
			board.hop(id)
			board.castle_glow = logic.current
			board.marks = {sc: "summon"}
			await wait(0.5)
			if tok != _token:
				return
			_clear_marks()
			await _play(logic.do_summon(id, sc))
		"end":
			logic.end_turn()
			await _play(logic.last_events())


func _on_net_left() -> void:
	if logic == null or logic.over or _net_over:
		return
	_net_over = true
	_busy = false
	board.input_enabled = false
	_net_close()
	toast("상대가 나갔어요")
	_online_result(human_player, "상대가 게임을 나가서 내가 이겼어요")


func _on_net_failed(reason: String) -> void:
	if _net_over or (logic != null and logic.over):
		return
	_net_problem(reason)


## 온라인 대전을 더 이어 갈 수 없을 때
func _net_problem(reason: String) -> void:
	_net_over = true
	_busy = false
	_thinking = false
	board.input_enabled = false
	_net_close()
	var box := open_overlay("net_error")
	box.add_child(UIKit.make_label("온라인 대전을 할 수 없어요", 38, UIKit.INK, 800))
	box.add_child(UIKit.make_label(reason, 26, UIKit.INK_SOFT))
	var again := UIKit.make_button("다시 찾기", UIKit.GREEN, Vector2(0, 100), 34)
	again.pressed.connect(_start_game)
	box.add_child(again)
	var back := UIKit.make_button("설정으로", UIKit.ORANGE, Vector2(0, 84), 28)
	back.pressed.connect(show_setup)
	box.add_child(back)
	set_status(reason)


func _online_result(w: int, note: String) -> void:
	Global.add_stat(game_id, "online_played")
	if w == human_player:
		Global.add_stat(game_id, "online_wins")
	_net_close()
	var title := "승리!" if w == human_player else ("무승부" if w < 0 else "아쉬운 패배...")
	var color := UIKit.ORANGE if w == human_player else (UIKit.INK if w < 0 else UIKit.PURPLE)
	var rows: Array = []
	for p in 2:
		rows.append({"p": p, "big": "하트 %d" % logic.lives[p], "small": "영웅 %d명 남음" % logic.count(p)})
	show_result(title, color, w == human_player, w, rows, note, "다시 찾기", _start_game)
