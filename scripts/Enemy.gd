extends CharacterBody2D
## Enemy.gd — a simple training dummy / foe.
## Takes hits from the player's sword/kick, flashes, gets knocked back,
## and respawns after a delay so there is always something to hit.

@export var hp_max := 30
@export var knockback := 280.0
@export var knock_up := 160.0
@export var gravity := 1200.0
@export var respawn_delay := 1.5

@onready var body: ColorRect = $Body
@onready var hp_fill: ColorRect = $HPBar/Fill
@onready var col: CollisionShape2D = $CollisionShape2D

var hp := 0
var _flash := 0.0
var _dead := false


func _ready() -> void:
	hp = hp_max
	_update_bar()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	# Friction so knockback decays.
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	move_and_slide()

	# Hit flash: bright (blooms) right after a hit, fading back to normal.
	if _flash > 0.0:
		_flash = max(_flash - delta, 0.0)
		var k := _flash / 0.12
		body.modulate = Color(1, 1, 1).lerp(Color(3, 3, 3), k)


## Called by the player's attack hitbox.
func take_hit(dmg: float, dir: float) -> void:
	if _dead:
		return
	hp -= int(dmg)
	velocity.x = dir * knockback
	velocity.y = -knock_up
	_flash = 0.12
	_update_bar()
	if hp <= 0:
		_die()


func _die() -> void:
	_dead = true
	visible = false
	col.set_deferred("disabled", true)
	await get_tree().create_timer(respawn_delay).timeout
	hp = hp_max
	_update_bar()
	body.modulate = Color(1, 1, 1)
	visible = true
	col.set_deferred("disabled", false)
	_dead = false


func _update_bar() -> void:
	if hp_fill:
		hp_fill.scale.x = clamp(float(hp) / float(hp_max), 0.0, 1.0)
