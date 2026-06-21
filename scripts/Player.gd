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
@onready var anim: AnimationPlayer = $Visual/Rig/AnimationPlayer

# --- Movement tuning (live-editable in the Inspector) ---
@export_group("Movement")
@export var speed := 220.0
@export var walk_speed := 140.0       # 단일 입력(걷기) 속도. 방향키 연타 시 speed(달리기)로
@export var double_tap_window := 0.25  # 더블탭 달리기 인식 시간(초)
@export var ground_accel := 2000.0
@export var air_accel := 1200.0
@export var jump_velocity := -560.0   # Cat-like: jumps high by default.
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
var combo_step := 0              # 0..2 sword combo index.
var _attack_buffered := false    # 스윙 중 누른 공격 (콤보 끊김 방지용 버퍼)
var _combat_timer := 0.0
var _was_drawn := false       # 직전 프레임에 발도(전투) 상태였는지
var _sheathe_timer := 0.0     # >0 이면 납도 애니 재생 중
var on_wall_slide := false       # True while clinging/sliding on a wall.
var dashing := false             # True during a 경공 dash burst.

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

	if on_floor:
		_coyote = coyote_time
		_air_jumps_left = max_air_jumps
		_air_dashes_left = max_air_dashes
	else:
		_coyote = max(_coyote - delta, 0.0)

	# Gravity (heavier while falling for a snappy arc).
	if not on_floor:
		var g := gravity
		if velocity.y > 0.0:
			g *= fall_gravity_mult
		velocity.y += g * delta

	# Wall cling: detect a wall and slow the fall while pressing into it.
	var on_wall := is_on_wall_only() and not on_floor
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
	if attacking:
		# 스윙 중 누른 공격은 버퍼에 저장 (콤보 끊김 방지)
		if Input.is_action_just_pressed("attack"):
			_attack_buffered = true
		return
	# 스윙이 끝났고 버퍼가 차 있으면 무조건 다음 타 발동 (콤보 단계는 start_attack 이 판단)
	if _attack_buffered:
		_attack_buffered = false
		start_attack()
		return
	if Input.is_action_just_pressed("attack"):
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
	# Advance the 3-hit combo if we are still inside the window.
	combo_step = (combo_step + 1) % 3 if _combo_timer > 0.0 else 0
	# 3rd hit lingers for a heavier finish (matches anim_attack_dash length 0.26).
	_attack_timer = attack_duration + 0.04 if combo_step == 2 else attack_duration
	_combo_timer = attack_combo_window
	velocity.x = facing * attack_lunge
	stealthed = false
	_spawn_attack_hitbox()
	_spawn_slash(false)
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


func _update_animation() -> void:
	var next := "idle_alert" if (_combat_timer > 0.0 or not is_on_floor() or dashing) else "idle_relaxed"
	if attacking:
		if current_action == "attack":
			# 콤보 3단: 내려 → 올려 → 찌르기
			next = ["slash_down", "slash_up", "thrust"][combo_step]
	elif _sheathe_timer > 0.0:
		# 전투 종료 → 납도 애니를 끝까지 재생 (idle 이 덮어쓰지 않게)
		if anim.current_animation != "sheathe":
			anim.play("sheathe")
		return
	elif is_on_floor() and not dashing:
		if absf(velocity.x) >= 30.0:
			next = "run" if _running else "walk"
	if anim.current_animation != next:
		anim.play(next)


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


func _spawn_slash(low: bool):
	# 거합 섬광: 칼날을 대신하는 크고 굵은 초승달. 글로우(넓고 흐림)+코어(밝고 선명) 2겹.
	# 섬광 길이를 실제 사거리에 묶음 (히트박스 끝보다 살짝 길게 = 연출). 좌표는 reach 비율
	var reach := (attack_reach + attack_hit_size.x * 0.5) * 1.35
	var pts: PackedVector2Array
	if low:
		# 하단베기: 앞→아래로 길게 훑는 호
		pts = PackedVector2Array([
			Vector2(0.12 * reach, -0.10 * reach), Vector2(0.52 * reach, 0.12 * reach),
			Vector2(0.86 * reach, 0.36 * reach), Vector2(1.0 * reach, 0.60 * reach)
		])
	else:
		# 기본(내려베기): 위→앞→아래로 크게 도는 초승달, 사거리만큼 길게
		pts = PackedVector2Array([
			Vector2(0.08 * reach, -0.52 * reach), Vector2(0.46 * reach, -0.40 * reach),
			Vector2(0.82 * reach, -0.14 * reach), Vector2(1.0 * reach, 0.10 * reach),
			Vector2(0.84 * reach, 0.36 * reach), Vector2(0.55 * reach, 0.56 * reach)
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
