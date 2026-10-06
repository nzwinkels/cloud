extends SceneTree

const SnowModel = preload("res://scripts/snow_model.gd")
const DT: float = 1.0 / 120.0
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", description)
	else:
		failed += 1
		push_error("FAIL  " + description)

func _advance(model, seconds: float, heel: float = 0.0, toe: float = 0.0, twist: float = 0.0, weight: float = 0.0, dt: float = DT) -> void:
	for _frame in range(roundi(seconds / dt)):
		model.step(dt, heel, toe, twist, weight)

func _run() -> void:
	var straight = SnowModel.new()
	_advance(straight, 3.0)
	_check(straight.velocity.y > 5.0 and absf(straight.velocity.x) < 0.0001, "Gravity accelerates downhill without sideways drift")
	_check(straight.position.y > 15.0, "Momentum moves the board along the slope")
	var flat = SnowModel.new()
	flat.slope_degrees = 0.0
	_advance(flat, 3.0)
	_check(flat.velocity.is_zero_approx(), "A flat surface does not invent acceleration")
	flat.velocity = Vector2(2.0, 5.0)
	var energy_before: float = flat.velocity.length_squared()
	_advance(flat, 3.0, 1.0, 0.0, -0.5)
	_check(flat.velocity.length_squared() < energy_before, "Turning and friction do not add kinetic energy on flat snow")
	var left = SnowModel.new()
	var right = SnowModel.new()
	left.velocity = Vector2(0.0, 7.0)
	right.velocity = left.velocity
	_advance(left, 1.5, 1.0, 0.0, -0.35)
	_advance(right, 1.5, 0.0, 1.0, 0.35)
	_check(left.heading < -0.3 and left.velocity.x < -0.5, "Heel edge and left torso rotation produce a left turn")
	_check(right.heading > 0.3 and right.velocity.x > 0.5, "Toe edge and right torso rotation produce a right turn")
	_check(absf(left.velocity.x + right.velocity.x) < 0.0001 and absf(left.velocity.y - right.velocity.y) < 0.0001,
		"Left and right turns are physically symmetric")
	var stopping = SnowModel.new()
	stopping.heading = PI / 2.0
	stopping.velocity = Vector2(0.0, 8.0)
	_advance(stopping, 5.0, 0.0, 1.0)
	_check(stopping.velocity.length() < 0.1, "Board across the slope with a loaded edge stops completely")
	_advance(stopping, 5.0, 0.0, 1.0)
	_check(stopping.velocity.length() < 0.1, "Static edge friction holds the rider stationary on the slope")
	var drifting = SnowModel.new()
	drifting.heading = PI / 2.0
	_advance(drifting, 3.0)
	_check(drifting.velocity.y > 4.0 and drifting.slip_speed > 3.0, "A flat board across the slope slips downhill")
	var front = SnowModel.new()
	var rear = SnowModel.new()
	_advance(front, 1.0, 0.0, 0.0, 0.6, 1.0)
	_advance(rear, 1.0, 0.0, 0.0, 0.6, -1.0)
	_check(front.heading > rear.heading * 1.2, "Front pressure makes the steering response stronger than rear pressure")
	var fast_step = SnowModel.new()
	var slow_step = SnowModel.new()
	_advance(fast_step, 3.0, 0.0, 0.6, 0.2, 0.3, 1.0 / 120.0)
	_advance(slow_step, 3.0, 0.0, 0.6, 0.2, 0.3, 1.0 / 60.0)
	_check(fast_step.position.distance_to(slow_step.position) < 0.2 and fast_step.velocity.distance_to(slow_step.velocity) < 0.15,
		"60 and 120 Hz produce comparable trajectories")
	var goofy = SnowModel.new()
	goofy.regular = false
	goofy.velocity = Vector2(0.0, 7.0)
	_advance(goofy, 1.5, 1.0)
	_check(goofy.heading > 0.3, "Goofy reverses the physical heel side, preserving heel/toe semantics")
	# A long run with alternating load and edge input catches numerical instability.
	var endurance = SnowModel.new()
	for frame in range(120 * 90):
		var input: float = sin(frame * DT * 0.7)
		endurance.step(DT, maxf(0.0, -input), maxf(0.0, input), input * 0.4, cos(frame * DT))
	_check(endurance.position.is_finite() and endurance.velocity.is_finite() and is_finite(endurance.heading),
		"90-second alternating turn sequence stays numerically stable")
	print("Physics checks: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
