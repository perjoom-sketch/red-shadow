@tool
extends EditorScript
## 아담 SpriteFrames 자동 생성 스크립트
## 에디터에서 실행: Script > Run (Ctrl+Shift+X)
##
## 사전조건: assets/characters/adam/normalized/ 폴더에 정규화된 PNG 파일 필요
## (tools/normalize_adam_frames.py 실행 후)

const NORMALIZED_DIR = "res://assets/characters/adam/normalized/"
const OUTPUT_PATH = "res://assets/characters/adam/adam_sprites.tres"

# animation_map.json 기반 애니메이션 정의
var animations_config = [
	{"name": "idle", "frames": ["idle", "idle_breath"], "fps": 2.0, "loop": true},
	{"name": "walk", "frames": ["walk_frame2", "walk_frame3", "walk_frame6", "walk_frame7"], "fps": 8.0, "loop": true},
	{"name": "run", "frames": ["run_frame1", "run_frame2", "run_frame3", "run_frame4", "run_frame5", "run_frame6", "run_frame7", "run_frame8"], "fps": 12.0, "loop": true},
	{"name": "dash", "frames": ["dash"], "fps": 1.0, "loop": false},
	{"name": "crouch", "frames": ["crouch"], "fps": 1.0, "loop": false},
	{"name": "step_back", "frames": ["backstep_frame1", "backstep_frame2", "backstep_frame3", "backstep_frame4", "backstep_frame5", "backstep_frame6", "backstep_frame7", "backstep_frame8"], "fps": 10.0, "loop": true},
	{"name": "turn", "frames": ["turn_frame1", "turn_frame2", "turn_frame3"], "fps": 10.0, "loop": false},
	{"name": "jump_up", "frames": ["jump_takeoff", "air_up", "air_apex"], "fps": 10.0, "loop": false},
	{"name": "fall", "frames": ["air_down"], "fps": 1.0, "loop": false},
	{"name": "land", "frames": ["land"], "fps": 1.0, "loop": false},
	{"name": "draw_charge", "frames": ["draw_charge"], "fps": 1.0, "loop": false},
	{"name": "slash_h", "frames": ["slash_h"], "fps": 1.0, "loop": false},
	{"name": "sheath", "frames": ["sheath"], "fps": 1.0, "loop": false},
	{"name": "attack_up", "frames": ["attack_up"], "fps": 1.0, "loop": false},
	{"name": "attack2", "frames": ["attack2"], "fps": 1.0, "loop": false},
	{"name": "guard", "frames": ["guard"], "fps": 1.0, "loop": false},
	{"name": "parry", "frames": ["parry"], "fps": 1.0, "loop": false},
	{"name": "hurt", "frames": ["hurt"], "fps": 1.0, "loop": false},
	{"name": "dizzy", "frames": ["dizzy"], "fps": 1.0, "loop": true},
	{"name": "die", "frames": ["die"], "fps": 1.0, "loop": false},
	{"name": "victory", "frames": ["victory"], "fps": 1.0, "loop": false},
]


func _run() -> void:
	print("=".repeat(60))
	print("아담 SpriteFrames 생성 시작")
	print("=".repeat(60))

	var sprite_frames = SpriteFrames.new()

	# 기본 "default" 애니메이션 삭제
	if sprite_frames.has_animation(&"default"):
		sprite_frames.remove_animation(&"default")

	var success_count = 0
	var error_count = 0

	for anim_config in animations_config:
		var anim_name: StringName = anim_config["name"]
		var frame_names: Array = anim_config["frames"]
		var fps: float = anim_config["fps"]
		var loop: bool = anim_config["loop"]

		# 애니메이션 추가
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_speed(anim_name, fps)
		sprite_frames.set_animation_loop(anim_name, loop)

		# 프레임 추가
		var all_frames_ok = true
		for frame_name in frame_names:
			var texture_path = NORMALIZED_DIR + frame_name + ".png"
			var texture = load(texture_path)

			if texture == null:
				push_error("텍스처 로드 실패: " + texture_path)
				all_frames_ok = false
				continue

			sprite_frames.add_frame(anim_name, texture)

		if all_frames_ok:
			print("✅ ", anim_name, " (", frame_names.size(), " frames, ", fps, " fps)")
			success_count += 1
		else:
			print("⚠️ ", anim_name, " - 일부 프레임 누락")
			error_count += 1

	# 저장
	var err = ResourceSaver.save(sprite_frames, OUTPUT_PATH)
	if err == OK:
		print("")
		print("=".repeat(60))
		print("✅ SpriteFrames 저장 완료: ", OUTPUT_PATH)
		print("애니메이션: ", success_count, "개 성공, ", error_count, "개 오류")
		print("=".repeat(60))
	else:
		push_error("저장 실패: " + str(err))
