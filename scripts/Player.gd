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
##   - Kick (발차기)
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
@export var attack_duration := 0.22
@export var attack_lunge := 130.0
@export var attack_combo_window := 0.5
@export var kick_duration := 0.26
@export var kick_lunge := 190.0
@export var attack_damage := 10.0
@export var kick_damage := 14.0

# --- State ---
var facing := 1                  # 1 = right, -1 = left.
var invulnerable := false        # True while any i-frame timer is active.
var stealthed := false           # Stealth toggle state.
var flipping := false
var attacking := false
var current_action := ""         # "attack" or "kick" for the active swing.
var combo_step := 0              # 0..2 sword combo index.
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
	_wall_jump_lock = max(_wall_jump_lock - delta, 0.0)
	invulnerable = _invuln_timer > 0.0
	if attacking:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			attacking = false
			current_action = ""


func _handle_horizontal(delta, on_floor):
	var direction := Input.get_axis("move_left", "move_right")

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

	# During an attack/kick we let the lunge play out (just apply friction).
	if attacking:
		velocity.x = move_toward(velocity.x, 0.0, ground_accel * delta)
		return

	var accel := ground_accel if on_floor else air_accel
	velocity.x = move_toward(velocity.x, direction * _move_speed(), accel * delta)
	if direction != 0:
		facing = int(sign(direction))


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
	if attacking or flipping:
		return
	if Input.is_action_just_pressed("attack"):
		start_attack()
	elif Input.is_action_just_pressed("kick"):
		start_kick()


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
	_attack_timer = attack_duration
	# Advance the 3-hit combo if we are still inside the window.
	combo_step = (combo_step + 1) % 3 if _combo_timer > 0.0 else 0
	_combo_timer = attack_combo_window
	velocity.x = facing * attack_lunge
	stealthed = false
	_spawn_hitbox(Vector2(facing * 26, -4), Vector2(40, 28), attack_damage)
	_spawn_slash(false)


func start_kick():
	attacking = true
	current_action = "kick"
	_attack_timer = kick_duration
	velocity.x = facing * kick_lunge
	stealthed = false
	_spawn_hitbox(Vector2(facing * 24, 14), Vector2(34, 22), kick_damage)
	_spawn_slash(true)


# --- Helpers -----------------------------------------------------------

func _move_speed() -> float:
	return speed * (stealth_speed_mult if stealthed else 1.0)


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
	# 현재 authored 애니는 idle뿐. run/jump/attack 등은 트랙이 채워지면 여기 분기 추가.
	var next := "idle"
	if anim.current_animation != next:
		anim.play(next)


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


func _spawn_slash(low: bool):
	# Lightweight white arc that fades out — visual feedback for the swing.
	var fx := Line2D.new()
	fx.width = 4.0
	fx.default_color = Color(0.95, 0.96, 1.0, 0.9)
	fx.z_index = 5
	var pts: PackedVector2Array
	if low:
		pts = PackedVector2Array([
			Vector2(8, 12), Vector2(22, 16), Vector2(32, 22), Vector2(38, 30)
		])
	else:
		pts = PackedVector2Array([
			Vector2(8, -20), Vector2(24, -12), Vector2(34, 0),
			Vector2(30, 14), Vector2(18, 24)
		])
	for i in pts.size():
		pts[i] = Vector2(pts[i].x * facing, pts[i].y)
	fx.points = pts
	add_child(fx)
	var tw := create_tween()
	tw.tween_property(fx, "modulate:a", 0.0, attack_duration)
	tw.tween_callback(fx.queue_free)


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
