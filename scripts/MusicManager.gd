extends Node
## MusicManager.gd — 전역 음악 매니저 (Autoload: "Music")
##
## 사용법:
##   Music.play("title")          # 등록된 트랙을 크로스페이드로 재생
##   Music.play("title", 0.0)     # 즉시 전환(페이드 없음)
##   Music.stop()                 # 페이드 아웃 후 정지
##   Music.set_volume_db(-6.0)    # 음악 버스 볼륨
##
## 새 곡 추가: assets/audio/ 에 .ogg/.mp3 넣고 아래 TRACKS 에 경로만 등록.
## 파일이 없어도 경고만 출력하고 게임은 멈추지 않는다.

# 트랙 이름 → 파일 경로. (파일은 나중에 채워도 됨)
const TRACKS := {
	"bladethunder": "res://assets/audio/blade_thunder.mp3",
	"title":   "res://assets/audio/01_main_title.ogg",
	"theme":   "res://assets/audio/02_red_shadow_theme.ogg",
	"city":    "res://assets/audio/03_tower_city.ogg",
	"ascent":  "res://assets/audio/04_vertical_ascent.ogg",
	"abyss":   "res://assets/audio/05_abyss_descent.ogg",
	"battle":  "res://assets/audio/06_ai_battle.ogg",
	"boss":    "res://assets/audio/07_boss.ogg",
	"redmoon": "res://assets/audio/08_red_moon.ogg",
	"ending":  "res://assets/audio/09_ending.ogg",
}

@export var default_fade := 1.5     # 크로스페이드 길이(초)
@export var music_volume_db := -6.0 # 기본 음량

var _players: Array[AudioStreamPlayer] = []
var _active := 0                    # 현재 들리는 플레이어 인덱스(0/1)
var _current := ""                  # 현재 재생 중인 트랙 이름
var _tween: Tween


func _ready() -> void:
	# 크로스페이드용 플레이어 2개 (A/B 핑퐁).
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)


## 트랙 재생. 같은 트랙이면 무시. fade < 0 이면 default_fade 사용.
func play(track: String, fade := -1.0) -> void:
	if track == _current and _players[_active].playing:
		return
	if not TRACKS.has(track):
		push_warning("[Music] 알 수 없는 트랙: %s" % track)
		return
	var path: String = TRACKS[track]
	if not ResourceLoader.exists(path):
		push_warning("[Music] 파일 없음: %s (아직 곡이 준비 안 됨)" % path)
		return

	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("[Music] 로드 실패: %s" % path)
		return

	var f := default_fade if fade < 0.0 else fade
	var next := 1 - _active
	var np := _players[next]
	var cp := _players[_active]

	np.stream = stream
	np.volume_db = -80.0
	np.play()

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if f <= 0.0:
		np.volume_db = music_volume_db
		cp.stop()
	else:
		_tween.tween_property(np, "volume_db", music_volume_db, f)
		_tween.tween_property(cp, "volume_db", -80.0, f)
		_tween.chain().tween_callback(cp.stop)

	_active = next
	_current = track


## 페이드 아웃 후 정지.
func stop(fade := -1.0) -> void:
	var f := default_fade if fade < 0.0 else fade
	var cp := _players[_active]
	if _tween and _tween.is_valid():
		_tween.kill()
	if f <= 0.0:
		cp.stop()
	else:
		_tween = create_tween()
		_tween.tween_property(cp, "volume_db", -80.0, f)
		_tween.tween_callback(cp.stop)
	_current = ""


## 음악 버스(또는 마스터) 볼륨 조절.
func set_volume_db(db: float) -> void:
	music_volume_db = db
	if _players[_active].playing:
		_players[_active].volume_db = db
