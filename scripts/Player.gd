extends CharacterBody2D
## Player.gd — "붉은 그림자 / Red Shadow"
## A black cat swordsman with a growing kit of skills.
##
## Skills implemented:
##   - Run + variable jump (coyote time, jump buffer)
##   - Double jump (extra air jumps)
##   - Aerial flip (signature move, with i-frames)
##   - Blink / teleport (short dash with i-frames)
##   - Stealth (toggle: fade + speed boost, broken by attacking)
##   - Sword attack (3-hit combo, 검술)
##
## IMPORTANT design rule:
##   Only the "Visual" node rotates during the flip.
##   The CollisionShape2D stays upright so collisions remain stable.

# --- Cached child node that we rotate during the flip ---
@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/AdamSprite

# --- Movement tuning (live-editable in the Inspector) ---
@export_group("Movement")
@export var speed := 220.0
@export var walk_speed := 140.0       # 단일 입력(걷기) 속도. 방향키 연타 시 speed(달리기)로
@export var double_tap_window := 0.25  # 더블탭 달리기 인식 시간(초)
@export var ground_accel := 2000.0
@export var air_accel := 1200.0
@export var jump_velocity := -860.0   # Cat-like: jumps high by default.
@export var gravity := 1300.0
@export var fall_gravity_mult := 1.7
@export var jump_cut_mult := 0.45

@export_group("Feel")
@export var coyote_time := 0.10
@export var jump_buffer := 0.10

@export_group("Jump")
@export var max_air_jumps := 1        # 1 extra jump = double jump.

@export_group("Wall")
@export var wall_slide_speed := 90.0   # Max fall speed while clinging to a wall.
@export var wall_jump_velocity := -520.0
@export var wall_jump_push := 300.0
@export var wall_enabled := false  # 벽 슬라이드/벽차기 on/off. 좁은 샤프트 레벨만 true. 계단형 맵은 false(경계벽 타기 버그 차단).

@export_group("Flip")
@export var flip_duration := 0.35
@export var flip_invuln := 0.15
@export var flip_cooldown := 0.45
@export var ground_flip_boost := 240.0

@export_group("Blink")
@export var blink_distance := 150.0
@export var blink_cooldown := 0.7
@export var blink_invuln := 0.12

@export_group("Stealth")
@export var stealth_alpha := 0.35
@export var stealth_speed_mult := 1.2

@export_group("Dash")              # 경공술 (light-step dash)
@export var dash_speed := 620.0
@export var dash_duration := 0.16
@export var dash_cooldown := 0.45
@export var max_air_dashes := 1
@export var dash_invuln := 0.12

@export_group("Climb")             # 사다리 등반
@export var climb_speed := 180.0   # 등반 속도

@export_group("Combat")
@export var attack_duration := 0.30
@export var attack_lunge := 130.0
@export var attack_combo_window := 0.8
@export var attack_damage := 10.0
@export var attack_reach := 54.0                 # 히트박스 중심 오프셋(사거리). 할나급 길게
@export var attack_hit_size := Vector2(44, 30)   # 히트박스 크기(폭, 높이) → 도달 ~76px
@export var attack_windup := 0.0                 # 발도~타격 지연(초). 0 = 즉발
@export var combat_linger := 1.5
@export var sheathe_time := 0.28    # 자동 납도 애니 길이 = anim_sheathe length

@export_group("Audio")
@export var sfx_draw: AudioStream   # 발도음(스릉/챙). 비우면 무음
@export var sfx_hit: AudioStream    # 타격음(챙!). 비우면 무음

# --- State ---
var facing := 1                  # 1 = right, -1 = left.
var _running := false            # 더블탭 달리기 상태
var _tap_dir := 0                # 직전 탭 방향 (더블탭 감지용)
var _tap_timer := 0.0            # 더블탭 유효시간 남음
var invulnerable := false        # True while any i-frame timer is active.
var stealthed := false           # Stealth toggle state.
var flipping := false
var attacking := false
var current_action := ""         # "attack" for the active swing.
var combo_step := 0              # 0..4 sword combo index.
var _spin_t := 0.0               # 회전베기 진행 타이머(>0이면 몸이 회전 중)
var _spin_dir := 1               # 회전 방향(facing 기준)
var _auto_combo := false         # true면 연타로 발동된 5타 자동 콤보가 진행 중
var _combat_timer := 0.0
var _was_drawn := false       # 직전 프레임에 발도(전투) 상태였는지
var _sheathe_timer := 0.0     # >0 이면 납도 애니 재생 중
var on_wall_slide := false       # True while clinging/sliding on a wall.
var dashing := false             # True during a 경공 dash burst.
var climbing := false            # True while on a ladder.
var _ladder_area: Area2D = null  # 현재 겹친 사다리 영역

# --- Flip internals ---
var flip_time := 0.0
var flip_spin_dir := 1
var flip_turn_committed := false

# --- Timers ---
var _coyote := 0.0
var _buffer := 0.0
var _flip_cd := 0.0
var _blink_cd := 0.0
var _invuln_timer := 0.0
var _attack_timer := 0.0
var _combo_timer := 0.0
var _air_jumps_left := 0
var _wall_jump_lock := 0.0       # Brief no-steer window after a wall jump.
var _dash_cd := 0.0
var _dash_timer := 0.0
var _air_dashes_left := 0
var _dash_dir := Vector2.RIGHT


func _physics_process(delta):
	var on_floor := is_on_floor()
	_tick_timers(delta)

	# 경공술 dash: a committed burst that overrides all other motion.
	if dashing:
		_dash_timer -= delta
		velocity = _dash_dir * dash_speed
		_spawn_trail()
		if _dash_timer <= 0.0:
			dashing = false
			velocity = _dash_dir * dash_speed * 0.35
		move_and_slide()
		_update_visual()
		_update_animation()
		return

	# 사다리 등반 처리
	if climbing:
		_handle_climb(delta)
		move_and_slide()
		_update_visual()
		_update_animation()
		return

	if on_floor:
		_coyote = coyote_time
		_air_jumps_left = max_air_jumps
		_air_dashes_left = max_air_dashes
	else:
		_coyote = max(_coyote - delta, 0.0)

	# Gravity (heavier while falling for a snappy arc).
	# 사다리 영역에서는 중력 무시
	if not on_floor and _ladder_area == null:
		var g := gravity
		if velocity.y > 0.0:
			g *= fall_gravity_mult
		velocity.y += g * delta

	# Wall cling: detect a wall and slow the fall while pressing into it.
	var on_wall := wall_enabled and is_on_wall_only() and not on_floor
	on_wall_slide = false
	if on_wall and velocity.y > 0.0 and _pressing_into_wall():
		on_wall_slide = true
		velocity.y = min(velocity.y, wall_slide_speed)
		_air_jumps_left = max_air_jumps
		_air_dashes_left = max_air_dashes

	_handle_horizontal(delta, on_floor)
	_handle_jump(delta, on_floor, on_wall)
	_handle_flip(delta)
	_handle_dash()
	_handle_blink()
	_handle_stealth()
	_handle_combat()
	_handle_ladder_entry()

	update_flip(delta)
	move_and_slide()
	_update_visual()
	_update_animation()


func _tick_timers(delta):
	_flip_cd = max(_flip_cd - delta, 0.0)
	_blink_cd = max(_blink_cd - delta, 0.0)
	_dash_cd = max(_dash_cd - delta, 0.0)
	_invuln_timer = max(_invuln_timer - delta, 0.0)
	_combo_timer = max(_combo_timer - delta, 0.0)
	_tap_timer = max(_tap_timer - delta, 0.0)
	_combat_timer = max(_combat_timer - delta, 0.0)
	# 전투 종료(_combat_timer 가 0 도달) 순간 자동 납도 트리거
	_sheathe_timer = max(_sheathe_timer - delta, 0.0)
	if _combat_timer > 0.0:
		_was_drawn = true
	elif _was_drawn and not attacking:
		_was_drawn = false
		_sheathe_timer = sheathe_time
	_wall_jump_lock = max(_wall_jump_lock - delta, 0.0)
	_spin_t = max(_spin_t - delta, 0.0)
	invulnerable = _invuln_timer > 0.0
	if attacking:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			attacking = false
			current_action = ""


func _handle_horizontal(delta, on_floor):
	var direction := Input.get_axis("move_left", "move_right")
	_update_run_state(direction)

	# During a flip we keep momentum but allow one decisive aerial turn.
	if flipping:
		if direction != 0 and not flip_turn_committed:
			facing = int(sign(direction))
			velocity.x = facing * _move_speed()
			flip_turn_committed = true
		return

	# A fresh wall jump keeps its push for a moment (no instant re-steer).
	if _wall_jump_lock > 0.0:
		return

	# During an attack: hold a direction to keep advancing; otherwise the lunge decays.
	if attacking:
		var adir := Input.get_axis("move_left", "move_right")
		if adir != 0.0:
			velocity.x = move_toward(velocity.x, adir * _move_speed(), ground_accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, ground_accel * delta)
		return

	var accel := ground_accel if on_floor else air_accel
	velocity.x = move_toward(velocity.x, direction * _move_speed(), accel * delta)
	if direction != 0:
		facing = int(sign(direction))


func _update_run_state(direction: float) -> void:
	# 달리던 방향에서 멈추거나 반대로 틀면 먼저 해제 (탭 갱신 전, 옛 방향 기준)
	if _running and (direction == 0.0 or int(sign(direction)) != _tap_dir):
		_running = false
	# 같은 방향키를 double_tap_window 안에 두 번 누르면 달리기 진입
	if Input.is_action_just_pressed("move_left"):
		if _tap_dir == -1 and _tap_timer > 0.0:
			_running = true
		_tap_dir = -1
		_tap_timer = double_tap_window
	elif Input.is_action_just_pressed("move_right"):
		if _tap_dir == 1 and _tap_timer > 0.0:
			_running = true
		_tap_dir = 1
		_tap_timer = double_tap_window


func _handle_jump(delta, on_floor, on_wall):
	var pressed := Input.is_action_just_pressed("jump")
	if pressed:
		_buffer = jump_buffer
	else:
		_buffer = max(_buffer - delta, 0.0)

	# Buffered ground/coyote jump.
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0
	# Wall jump: launch up and away from the wall.
	elif pressed and on_wall:
		var nx := signf(get_wall_normal().x)
		if nx == 0.0:
			nx = float(-facing)
		velocity.x = nx * wall_jump_push
		velocity.y = wall_jump_velocity
		facing = int(nx)
		_wall_jump_lock = 0.18
		_buffer = 0.0
	# Double jump: fresh press while airborne with air jumps remaining.
	elif pressed and not on_floor and _coyote <= 0.0 and _air_jumps_left > 0:
		velocity.y = jump_velocity
		_air_jumps_left -= 1

	# Variable jump height: release early to cut the rise short.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_mult


func _handle_flip(_delta):
	if Input.is_action_just_pressed("flip") and not flipping and not attacking and _flip_cd <= 0.0:
		start_flip()


func _handle_dash():
	if not Input.is_action_just_pressed("dash"):
		return
	if dashing or attacking or _dash_cd > 0.0:
		return
	if not is_on_floor() and _air_dashes_left <= 0:
		return
	var s := Input.get_axis("move_left", "move_right")
	var d := int(sign(s)) if s != 0 else facing
	facing = d
	_dash_dir = Vector2(d, 0)
	dashing = true
	_dash_timer = dash_duration
	_dash_cd = dash_cooldown
	if not is_on_floor():
		_air_dashes_left -= 1
	_invuln_timer = max(_invuln_timer, dash_invuln)
	velocity = _dash_dir * dash_speed


func _handle_blink():
	if Input.is_action_just_pressed("blink") and _blink_cd <= 0.0 and not attacking:
		do_blink()


func _handle_stealth():
	if Input.is_action_just_pressed("stealth"):
		stealthed = not stealthed


func _handle_combat():
	if flipping:
		return
	# 자동 콤보 진행 중: 입력과 무관하게 스윙이 끝날 때마다 다음 타 (2→3→4→5), 끝나면 기본으로.
	if _auto_combo:
		if not attacking:
			combo_step += 1
			if combo_step >= 5:
				_auto_combo = false
				combo_step = 0
			else:
				start_attack()
		return
	if attacking:
		# 첫 타(내려베기) 스윙 중에 다시 누름 = 연타 → 자동 5타 콤보 발동
		if Input.is_action_just_pressed("attack"):
			_auto_combo = true
		return
	# 단발: 누를 때마다 항상 기본 베기(내려베기) 1타
	if Input.is_action_just_pressed("attack"):
		combo_step = 0
		start_attack()


# --- Skills ------------------------------------------------------------

func start_flip():
	flipping = true
	flip_time = 0.0
	_flip_cd = flip_cooldown
	_invuln_timer = max(_invuln_timer, flip_invuln)
	flip_spin_dir = facing
	flip_turn_committed = false
	if is_on_floor():
		velocity.x = facing * ground_flip_boost


func update_flip(delta):
	if not flipping:
		return
	flip_time += delta
	if flip_time < flip_invuln:
		_invuln_timer = max(_invuln_timer, flip_invuln - flip_time)
	var t = clamp(flip_time / flip_duration, 0.0, 1.0)
	visual.rotation = TAU * t * flip_spin_dir
	if t >= 1.0:
		flipping = false
		visual.rotation = 0.0


func do_blink():
	# Blink in the held direction, or facing if no input.
	var dir := Input.get_axis("move_left", "move_right")
	var d := int(sign(dir)) if dir != 0 else facing
	facing = d
	global_position.x += d * blink_distance
	velocity.x = d * speed
	_blink_cd = blink_cooldown
	_invuln_timer = max(_invuln_timer, blink_invuln)
	_spawn_ghost()


func start_attack():
	attacking = true
	current_action = "attack"
	# combo_step 은 호출자(_handle_combat)가 결정한다: 단발=0(내려베기), 자동 콤보=1~4.
	# 5타 마무리(찌르기)는 살짝 길게 머문다 (묵직한 피니시).
	_attack_timer = attack_duration + 0.04 if combo_step == 4 else attack_duration
	# 3·4타는 회전베기: 몸을 한 바퀴 돌린다 (flip 과 같은 visual.rotation 방식).
	if combo_step == 2 or combo_step == 3:
		_spin_t = attack_duration
		_spin_dir = facing
	_combo_timer = attack_combo_window
	velocity.x = facing * attack_lunge
	stealthed = false
	_spawn_attack_hitbox()
	_spawn_slash(combo_step)
	_combat_timer = combat_linger
	_sheathe_timer = 0.0    # 재발도 시 진행 중이던 납도 취소
	_play_sfx(sfx_draw)     # 발도음


# --- Helpers -----------------------------------------------------------

func _move_speed() -> float:
	var base := speed if _running else walk_speed
	return base * (stealth_speed_mult if stealthed else 1.0)


func _play_sfx(stream: AudioStream) -> void:
	# 일회성 재생기. stream 이 비어있으면(파일 미할당) 그냥 무음.
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "SFX"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _pressing_into_wall() -> bool:
	var dir := Input.get_axis("move_left", "move_right")
	if dir == 0.0:
		return false
	# Pressing toward the wall = input opposite to the wall normal.
	return signf(dir) == -signf(get_wall_normal().x)


func _update_visual():
	visual.scale.x = facing
	visual.modulate.a = stealth_alpha if stealthed else 1.0
	# 회전베기: _spin_t 동안 몸을 0→360° 돌린다. (flip 중에는 flip 이 rotation 을 관리)
	if _spin_t > 0.0:
		var st := 1.0 - _spin_t / attack_duration   # 0→1
		visual.rotation = TAU * st * float(_spin_dir)
	elif not flipping:
		visual.rotation = 0.0


func _update_animation() -> void:
	var next := "idle"
	if climbing:
		next = "climb"
		sprite.flip_h = false
		sprite.scale = Vector2(0.105, 0.105)
	elif attacking:
		if current_action == "attack":
			next = ["slash_h", "attack_up", "attack2", "attack2", "attack2"][combo_step]
	elif _sheathe_timer > 0.0:
		if sprite.animation != &"sheath":
			sprite.play(&"sheath")
		return
	elif not is_on_floor() and _ladder_area == null:
		next = "fall" if velocity.y > 0 else "jump_up"
		# 상승 중일 때 이미지 좌우반전
		sprite.flip_h = (velocity.y < 0)
		# 점프 중 스케일 10% 축소
		sprite.scale = Vector2(0.0945, 0.0945)
	elif is_on_floor() and not dashing:
		if absf(velocity.x) >= 30.0:
			next = "run" if _running else "walk"
			if _running:
				sprite.scale = Vector2(0.11025, 0.11025)  # run 1.05배
			else:
				sprite.scale = Vector2(0.105, 0.105)  # walk
		else:
			sprite.scale = Vector2(0.105, 0.105)  # idle
		sprite.flip_h = false
	if sprite.animation != StringName(next):
		sprite.play(StringName(next))


func _spawn_attack_hitbox() -> void:
	# 사거리/크기는 export 로 튜닝. windup 0 이면 즉발(누르면 바로 타격).
	var off := Vector2(facing * attack_reach, -4.0)
	if attack_windup <= 0.0:
		_spawn_hitbox(off, attack_hit_size, attack_damage)
		return
	get_tree().create_timer(attack_windup).timeout.connect(
		_spawn_hitbox.bind(off, attack_hit_size, attack_damage))


func _spawn_hitbox(offset: Vector2, size: Vector2, dmg: float):
	# A short-lived Area2D that damages enemy bodies on layer bit 4.
	var hb := Area2D.new()
	hb.collision_layer = 0
	hb.collision_mask = 0b1000   # Bit 4 = "enemy" bodies.
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	hb.add_child(shape)
	hb.position = offset
	hb.set_meta("dmg", dmg)
	hb.body_entered.connect(_on_hitbox_body_entered.bind(hb))
	add_child(hb)
	get_tree().create_timer(0.08).timeout.connect(hb.queue_free)


func _on_hitbox_body_entered(body, hb):
	# Deal damage + knockback away from the player.
	if body.has_method("take_hit"):
		var dir := signf(body.global_position.x - global_position.x)
		if dir == 0.0:
			dir = float(facing)
		body.take_hit(hb.get_meta("dmg", 0.0), dir)
		_play_sfx(sfx_hit)    # 타격음 (적에 실제로 맞을 때만)


func _spawn_slash(step: int):
	# 거합 섬광: 칼날 대신. 콤보 단계별로 다른 궤적(내려/올려/찌르기). 길이는 사거리에 연동.
	var r := (attack_reach + attack_hit_size.x * 0.5) * 1.35
	var pts: PackedVector2Array
	match step:
		1:  # 2타 올려베기: 아래→앞→위
			pts = PackedVector2Array([
				Vector2(0.08 * r, 0.52 * r), Vector2(0.46 * r, 0.40 * r),
				Vector2(0.82 * r, 0.14 * r), Vector2(1.0 * r, -0.10 * r),
				Vector2(0.84 * r, -0.36 * r), Vector2(0.55 * r, -0.56 * r)
			])
		2, 3:  # 3·4타 회전베기: 몸 주위를 한 바퀴 도는 원형 섬광
			pts = PackedVector2Array()
			var seg := 18
			for s in seg + 1:
				var a := TAU * float(s) / float(seg) - PI / 2.0
				pts.append(Vector2(cos(a), sin(a)) * (r * 0.72))
		4:  # 5타 찌르기(피니시): 앞으로 더 길게 뻗는 직선 렌즈
			pts = PackedVector2Array([
				Vector2(0.10 * r, 0.0), Vector2(0.58 * r, 0.0), Vector2(1.25 * r, 0.0)
			])
		_:  # 1타 내려베기: 위→앞→아래
			pts = PackedVector2Array([
				Vector2(0.08 * r, -0.52 * r), Vector2(0.46 * r, -0.40 * r),
				Vector2(0.82 * r, -0.14 * r), Vector2(1.0 * r, 0.10 * r),
				Vector2(0.84 * r, 0.36 * r), Vector2(0.55 * r, 0.56 * r)
			])
	for i in pts.size():
		pts[i] = Vector2(pts[i].x * facing, pts[i].y)
	var fx := Node2D.new()
	fx.z_index = 10
	fx.add_child(_make_slash_arc(pts, 60.0, Color(0.65, 0.82, 1.0), 0.32))  # 글로우
	fx.add_child(_make_slash_arc(pts, 36.0, Color(1.0, 1.0, 1.0), 1.0))     # 코어
	add_child(fx)
	# 처음부터 풀 길이로 번쩍 → 살짝 더 커지며 사라짐
	fx.scale = Vector2(1.0, 1.0)
	var tw := create_tween()
	tw.parallel().tween_property(fx, "scale", Vector2(1.18, 1.18), 0.18).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_callback(fx.queue_free)


func _make_slash_arc(pts: PackedVector2Array, width: float, col: Color, alpha: float) -> Line2D:
	var l := Line2D.new()
	l.width = width
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	var wc := Curve.new()                       # 가운데 두껍고 양끝 얇게 → 초승달
	wc.add_point(Vector2(0.0, 0.08))
	wc.add_point(Vector2(0.5, 1.0))
	wc.add_point(Vector2(1.0, 0.08))
	l.width_curve = wc
	var g := Gradient.new()                     # 끝으로 갈수록 옅게
	g.set_color(0, Color(col.r, col.g, col.b, alpha))
	g.set_color(1, Color(col.r, col.g, col.b, alpha * 0.4))
	l.gradient = g
	l.points = pts
	return l


func _spawn_trail():
	# Fading after-image streak while dashing (경공 trail).
	var g := Line2D.new()
	g.width = 16.0
	g.default_color = Color(0.8, 0.86, 1.0, 0.3)
	g.points = PackedVector2Array([Vector2(0, -28), Vector2(0, 26)])
	g.global_position = global_position
	get_parent().add_child(g)
	var tw := create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.18)
	tw.tween_callback(g.queue_free)


func _spawn_ghost():
	# Fading after-image of the body to sell the blink.
	var ghost := Line2D.new()
	ghost.width = 18.0
	ghost.default_color = Color(0.6, 0.1, 0.12, 0.5)
	ghost.points = PackedVector2Array([Vector2(0, -30), Vector2(0, 28)])
	ghost.global_position = global_position - Vector2(facing * blink_distance, 0)
	get_parent().add_child(ghost)
	var tw := create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)


# --- Ladder / Climb ----------------------------------------------------------

func _handle_climb(_delta: float) -> void:
	# 등반 중 상하 이동
	var vert := Input.get_axis("move_up", "move_down")

	# 바닥에 발이 닿고 위로 올릴 입력이 없으면 등반 종료
	if is_on_floor() and vert <= 0.0:
		climbing = false
		_ladder_area = null
		set_floor_snap_length(4.0)
		return

	velocity.y = vert * climb_speed
	velocity.x = 0.0

	# 좌우 입력으로 사다리에서 내리기
	var horiz := Input.get_axis("move_left", "move_right")
	if absf(horiz) > 0.5:
		climbing = false
		_ladder_area = null
		velocity.x = horiz * speed * 0.5
		return

	# 점프로 사다리에서 뛰어내리기
	if Input.is_action_just_pressed("jump"):
		climbing = false
		_ladder_area = null
		velocity.y = jump_velocity * 0.6
		_air_jumps_left = max_air_jumps
		return

	# 등반 중에는 one-way 플랫폼 통과 허용
	set_floor_snap_length(0.0 if vert > 0.0 else 4.0)

	# 바닥(Ground)에 닿고 아래로 내려가는 중이면 자연스럽게 착지
	# one-way 플랫폼은 통과하므로 Ground에서만 멈춤
	if is_on_floor() and vert > 0.0:
		climbing = false
		_ladder_area = null
		velocity.y = 0.0
		set_floor_snap_length(4.0)
		return

	# 사다리 영역 상단을 벗어나면 (위로 올라가는 중) 플랫폼 위로 올라서기
	if _ladder_area and not _is_overlapping_ladder():
		climbing = false
		_ladder_area = null
		if vert < 0.0:
			# 위로 올라가는 중이면 살짝 위로 밀어서 플랫폼에 착지
			velocity.y = -50.0
		return


func _is_overlapping_ladder() -> bool:
	# 현재 사다리 영역과 겹치는지 확인
	if _ladder_area == null:
		return false
	return _ladder_area.overlaps_body(self)


func enter_ladder(ladder: Area2D) -> void:
	# 외부에서 사다리 진입 시 호출
	_ladder_area = ladder
	climbing = true
	velocity = Vector2.ZERO
	_air_jumps_left = max_air_jumps
	_air_dashes_left = max_air_dashes


func try_enter_ladder() -> void:
	# move_up/down 입력 시 근처 사다리 탐색
	if climbing or _ladder_area == null:
		return
	enter_ladder(_ladder_area)


func _on_ladder_entered(ladder: Area2D) -> void:
	_ladder_area = ladder


func _on_ladder_exited(_ladder: Area2D) -> void:
	if not climbing:
		_ladder_area = null


func _handle_ladder_entry() -> void:
	# 사다리 영역 안에서 상하 입력 시 등반 시작
	if _ladder_area == null or climbing:
		return
	var vert := Input.get_axis("move_up", "move_down")
	# 바닥에 서 있으면 아래(vert > 0)만 진입, 공중이면 위아래 둘 다 진입
	if is_on_floor():
		if vert > 0.1:
			enter_ladder(_ladder_area)
	else:
		if absf(vert) > 0.1:
			enter_ladder(_ladder_area)
