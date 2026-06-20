extends Sprite2D

@export var amplitude: float = 0.08     # 최대 흔들림 각도 (라디안)
@export var speed: float = 2.0          # 사인파 주파수
@export var damping: float = 0.15       # 속도 lag 반영 강도

var _base_rotation: float = 0.0
var _parent_prev_pos: Vector2 = Vector2.ZERO
var _velocity_lag: float = 0.0

func _ready() -> void:
	_base_rotation = rotation
	if get_parent():
		_parent_prev_pos = get_parent().global_position

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0

	# 부모 이동 속도 기반 lag
	var parent_vel_x := 0.0
	if get_parent():
		var cur_pos: Vector2 = get_parent().global_position
		parent_vel_x = (cur_pos.x - _parent_prev_pos.x) / max(delta, 0.001)
		_parent_prev_pos = cur_pos

	_velocity_lag = lerp(_velocity_lag, -parent_vel_x * damping, 10.0 * delta)

	rotation = _base_rotation + sin(t * speed) * amplitude + deg_to_rad(_velocity_lag)
