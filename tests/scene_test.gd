extends SceneTree

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", description)
	else:
		failures += 1
		push_error(description)

func _run() -> void:
	var scene: PackedScene = load("res://scenes/piste.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	_check(game.camera.current and game.rider.is_inside_tree(), "Piste, rider, HUD and active camera start successfully")
	_check(game.model.regular, "Regular is the default stance")
	_check(InputMap.action_has_event("heel", _joy_button(JOY_BUTTON_LEFT_SHOULDER)), "LB is mapped to heel edge")
	_check(InputMap.action_has_event("toe", _joy_button(JOY_BUTTON_RIGHT_SHOULDER)), "RB is mapped to toe edge")
	_check(InputMap.action_has_event("front", _joy_axis(JOY_AXIS_RIGHT_Y, -1.0)), "Right stick up maps to front pressure")
	var shoulder: InputEventJoypadButton = _joy_button(JOY_BUTTON_LEFT_SHOULDER)
	shoulder.device = 3
	shoulder.pressed = true
	Input.parse_input_event(shoulder)
	Input.flush_buffered_events()
	_check(Input.is_action_pressed("heel"), "Shoulder button events work on a nonzero controller device")
	shoulder = shoulder.duplicate()
	shoulder.pressed = false
	Input.parse_input_event(shoulder)
	Input.flush_buffered_events()
	var stick: InputEventJoypadMotion = _joy_axis(JOY_AXIS_RIGHT_Y, -0.75)
	stick.device = 3
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	_check(Input.get_action_strength("front") > 0.5, "Analog controller events preserve front pressure strength")
	stick = stick.duplicate()
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	game.paused = true
	var old_position: Vector2 = game.model.position
	for _frame in range(10):
		await physics_frame
	_check(game.model.position == old_position, "Pause freezes the physics state")
	game.paused = false
	Input.action_press("toe")
	Input.action_press("twist_right", 0.5)
	Input.action_press("front", 0.75)
	game.model.velocity = Vector2(0.0, 6.0)
	for _frame in range(90):
		await physics_frame
	Input.action_release("toe")
	Input.action_release("twist_right")
	Input.action_release("front")
	_check(game.model.edge > 0.8 and game.model.heading > 0.1 and game.model.weight > 0.5,
		"Input actions drive edge, body rotation and pressure through the live scene")
	_check(game.trails.size() > 0, "Moving board leaves snow tracks")
	_check(game.speed_label.text != "0.0 km/u", "Telemetry reflects the moving simulation")
	game._reset_run("Test reset")
	_check(game.model.velocity == Vector2.ZERO and game.model.position == Vector2(0, 8), "Reset returns to the start with no momentum")
	game.model.position.x = 50.0
	game._physics_process(1.0 / 120.0)
	_check(game.model.position == Vector2(0, 8), "Leaving the practice area returns safely to the start")
	# Optional rendered capture, kept outside the project. Headless remains valid.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			game.set_physics_process(false)
			game._reset_run("Oefen: rol rustig aan, kies een kant en draai je bovenlichaam. Rem door je board dwars te zetten.")
			game._update_interface()
			await process_frame
			await RenderingServer.frame_post_draw
			var error: Error = root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))
			_check(error == OK, "Rendered screenshot saved")
	root.remove_child(game)
	game.free()
	await process_frame
	print("Scene checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)

func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	return event

func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = value
	return event
