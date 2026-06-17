extends Node2D
## Main.gd — 메인 씬 진입 시 배경음악 시작.

## 이 씬에서 재생할 트랙 이름 (MusicManager.TRACKS 의 키).
@export var bgm_track := "bladethunder"


func _ready() -> void:
	Music.play(bgm_track)
