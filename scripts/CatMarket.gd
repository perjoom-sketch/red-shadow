extends Node2D
## CatMarket.gd — 야옹시장 씬 컨트롤러.

@export var bgm_track := "bladethunder"

@onready var exit_portal: Area2D = $ExitPortal
@onready var player = $Player
@onready var ladder_l: Area2D = $Ladders/LadderL
@onready var ladder_r: Area2D = $Ladders/LadderR
@onready var portal_modal = $PortalModal

## 포털에서 선택 가능한 목적지 목록
var portal_destinations: Array[Dictionary] = [
	{"name": "루프탑", "scene": "res://scenes/Main.tscn"},
]


func _ready() -> void:
	# 배경음악 (트랙이 없으면 Music.play 내부에서 경고만 출력)
	Music.play(bgm_track)
	# 포탈 진입 연결
	exit_portal.body_entered.connect(_on_exit_portal_entered)
	# 사다리 시그널 연결
	_connect_ladder(ladder_l)
	_connect_ladder(ladder_r)


func _connect_ladder(ladder: Area2D) -> void:
	ladder.body_entered.connect(func(body):
		if body == player:
			player._on_ladder_entered(ladder)
	)
	ladder.body_exited.connect(func(body):
		if body == player:
			player._on_ladder_exited(ladder)
	)


func _on_exit_portal_entered(body: Node2D) -> void:
	if body.name == "Player":
		portal_modal.show_modal(portal_destinations)
