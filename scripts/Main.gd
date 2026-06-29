extends Node2D
## Main.gd — 메인 씬 진입 시 배경음악 시작.

## 이 씬에서 재생할 트랙 이름 (MusicManager.TRACKS 의 키).
@export var bgm_track := "bladethunder"

@onready var portal_trigger: Area2D = $BGWorld/PortalTrigger
@onready var portal_modal = $PortalModal

## 포털에서 선택 가능한 목적지 목록
var portal_destinations: Array[Dictionary] = [
	{"name": "야옹시장", "scene": "res://scenes/CatMarket.tscn"},
]


func _ready() -> void:
	Music.play(bgm_track)
	portal_trigger.body_entered.connect(_on_portal_entered)


func _on_portal_entered(body: Node2D) -> void:
	if body.name == "Player":
		portal_modal.show_modal(portal_destinations)
