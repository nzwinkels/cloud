extends RefCounted
## A force-based, ground-constrained prototype on a uniform planar slope.
## Coordinates are metres: x across the piste, y along the fall line.
## This deliberately does not simulate jumps, contact collisions or board flex.

const GRAVITY: float = 9.81
var slope_degrees: float = 12.0
var sidecut_radius: float = 9.0
var edge_friction: float = 0.95
var flat_friction: float = 0.035
var base_friction: float = 0.018
var air_drag: float = 0.003
var torso_response: float = 0.75

var position := Vector2(0.0, 8.0)
var velocity := Vector2.ZERO
var heading: float = 0.0
var yaw_rate: float = 0.0
var edge: float = 0.0
var twist: float = 0.0
var weight: float = 0.0 # +1 front / -1 rear
var slip_speed: float = 0.0
var grip_usage: float = 0.0
var regular: bool = true

func reset() -> void:
	position = Vector2(0.0, 8.0)
	velocity = Vector2.ZERO
	heading = 0.0
	yaw_rate = 0.0
	edge = 0.0
	twist = 0.0
	weight = 0.0
	slip_speed = 0.0
	grip_usage = 0.0

func forward_axis() -> Vector2:
	return Vector2(sin(heading), cos(heading))

func side_axis() -> Vector2:
	return Vector2(cos(heading), -sin(heading))

func step(dt: float, heel: float, toe: float, rotation_input: float, pressure: float) -> void:
	if dt <= 0.0:
		return
	# Exponential smoothing has the same response at different physics rates.
	var response: float = 1.0 - exp(-dt * 8.0)
	var stance_sign: float = 1.0 if regular else -1.0
	edge = lerpf(edge, clampf(toe - heel, -1.0, 1.0) * stance_sign, response)
	twist = lerpf(twist, clampf(rotation_input, -1.0, 1.0), response)
	weight = lerpf(weight, clampf(pressure, -1.0, 1.0), response)
	var load_factor: float = 1.0 + weight * 0.35
	var forward_speed: float = velocity.dot(forward_axis())
	# Empirical steering torque + sidecut yaw response, not a direct heading snap.
	# Travelling switch reverses sidecut response; stick direction stays consistent.
	var carve_rate: float = edge * forward_speed / maxf(sidecut_radius, 0.1)
	var desired_rate: float = carve_rate + twist * torso_response * load_factor
	yaw_rate = lerpf(yaw_rate, desired_rate, 1.0 - exp(-dt * 3.0 * load_factor))
	heading = wrapf(heading + yaw_rate * dt, -PI, PI)
	var forward: Vector2 = forward_axis()
	var side: Vector2 = side_axis()
	var slope: float = deg_to_rad(slope_degrees)
	var normal_acceleration: float = GRAVITY * cos(slope)
	# Gravity and quadratic air resistance change momentum; there is no speed cap.
	velocity += Vector2(0.0, GRAVITY * sin(slope)) * dt
	velocity /= 1.0 + air_drag * velocity.length() * dt
	# Longitudinal base friction cannot reverse velocity or create energy.
	var longitudinal: float = velocity.dot(forward)
	velocity -= forward * clampf(longitudinal, -base_friction * normal_acceleration * dt, base_friction * normal_acceleration * dt)
	# A loaded edge resists lateral sliding, up to its friction budget. Above that
	# budget the board skids. Across the hill this also provides static holding.
	var lateral: float = velocity.dot(side)
	var friction: float = lerpf(flat_friction, edge_friction, absf(edge))
	friction *= 1.0 + weight * 0.12
	var budget: float = maxf(friction * normal_acceleration * dt, 0.000001)
	var correction: float = clampf(lateral, -budget, budget)
	velocity -= side * correction
	grip_usage = absf(correction) / budget
	slip_speed = absf(velocity.dot(side))
	position += velocity * dt

func surface_normal() -> Vector3:
	var angle: float = deg_to_rad(slope_degrees)
	return Vector3(0.0, cos(angle), -sin(angle))

func world_position(point: Vector2) -> Vector3:
	var angle: float = deg_to_rad(slope_degrees)
	return Vector3(point.x, 35.0 - point.y * sin(angle), -point.y * cos(angle))

func world_direction(direction: Vector2) -> Vector3:
	var angle: float = deg_to_rad(slope_degrees)
	return Vector3(direction.x, -direction.y * sin(angle), -direction.y * cos(angle))
