extends Node3D

const SnowModel = preload("res://scripts/snow_model.gd")
const PISTE_WIDTH: float = 84.0
const PISTE_LENGTH: float = 360.0
const INK := Color("172e3c")
const MUTED := Color("557081")
const ACCENT := Color("d95028")

@export_group("Oefenpiste")
@export_range(0.0, 25.0, 0.5) var slope_degrees: float = 12.0
@export_group("Board en sneeuw")
@export_range(5.0, 18.0, 0.5) var sidecut_radius: float = 9.0
@export_range(0.1, 1.5, 0.05) var edge_friction: float = 0.95
@export_range(0.01, 0.15, 0.005) var flat_friction: float = 0.035
@export_range(0.1, 1.5, 0.05) var torso_response: float = 0.75

var model = SnowModel.new()
var rider: Node3D
var bank: Node3D
var body: Node3D
var upper_body: Node3D
var camera: Camera3D
var speed_label: Label
var mode_label: Label
var edge_label: Label
var weight_label: Label
var hint_label: Label
var input_label: Label
var stance_label: Label
var pause_label: Label
var edge_bar: ProgressBar
var weight_bar: ProgressBar
var slip_bar: ProgressBar
var paused: bool = false
var hint_timer: float = 0.0
var trail_timer: float = 0.0
var trails: Array[MeshInstance3D] = []
var snow_material: StandardMaterial3D

func _ready() -> void:
	model.slope_degrees = slope_degrees
	model.sidecut_radius = sidecut_radius
	model.edge_friction = edge_friction
	model.flat_friction = flat_friction
	model.torso_response = torso_response
	_register_controls()
	_build_piste()
	_build_rider()
	_build_interface()
	_sync_rider()
	camera.global_position = rider.global_position + Vector3(4.0, 3.7, 7.0)
	camera.look_at(rider.global_position + Vector3(0.0, 1.0, -3.0))
	_update_interface()
	Input.joy_connection_changed.connect(_controller_changed)
	_controller_changed(0, false)

func _register_controls() -> void:
	_key("twist_left", KEY_A)
	_key("twist_right", KEY_D)
	_key("heel", KEY_Q)
	_key("toe", KEY_E)
	_key("front", KEY_W)
	_key("rear", KEY_S)
	_key("reset_run", KEY_R)
	_key("switch_stance", KEY_G)
	_key("pause_run", KEY_ESCAPE)
	_axis("twist_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("twist_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("front", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("rear", JOY_AXIS_RIGHT_Y, 1.0)
	_button("heel", JOY_BUTTON_LEFT_SHOULDER)
	_button("toe", JOY_BUTTON_RIGHT_SHOULDER)
	_button("reset_run", JOY_BUTTON_A)
	_button("switch_stance", JOY_BUTTON_Y)
	_button("pause_run", JOY_BUTTON_START)

func _key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.15)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

func _axis(action: String, axis: JoyAxis, direction: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)

func _button(action: String, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	InputMap.action_add_event(action, event)

func _controller_changed(_id: int, _connected: bool) -> void:
	if Input.get_connected_joypads().is_empty():
		input_label.text = "TOETSENBORD  ·  Sluit een controller aan voor sticks"
	else:
		input_label.text = "CONTROLLER  ·  " + Input.get_joy_name(Input.get_connected_joypads()[0])

func _physics_process(dt: float) -> void:
	if Input.is_action_just_pressed("pause_run"):
		paused = not paused
	if Input.is_action_just_pressed("switch_stance"):
		model.regular = not model.regular
	if Input.is_action_just_pressed("reset_run"):
		_reset_run("Nieuwe afdaling. Laat je eerst rustig rollen.")
	if not paused:
		model.step(dt, Input.get_action_strength("heel"), Input.get_action_strength("toe"),
			Input.get_axis("twist_left", "twist_right"), Input.get_axis("rear", "front"))
		if absf(model.position.x) > PISTE_WIDTH * 0.5 or model.position.y > PISTE_LENGTH - 12.0 or model.position.y < -8.0:
			_reset_run("Einde van de oefenpiste — je staat weer bovenaan.")
		_sync_rider()
		_leave_track(dt)
	hint_timer = maxf(0.0, hint_timer - dt)
	_update_interface()

func _process(dt: float) -> void:
	var desired: Vector3 = rider.global_position + Vector3(4.0, 3.7, 7.0)
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-dt * 5.0))
	camera.look_at(rider.global_position + Vector3(0.0, 0.8, -3.0))

func _sync_rider() -> void:
	var roll_angle: float = model.edge * deg_to_rad(48.0)
	# Keep the lower board edge on the snow while banking.
	var contact_height: float = 0.029 * cos(roll_angle) + 0.145 * absf(sin(roll_angle))
	rider.position = model.world_position(model.position) + model.surface_normal() * (contact_height + 0.008)
	var forward: Vector3 = model.world_direction(model.forward_axis())
	var up: Vector3 = model.surface_normal()
	rider.basis = Basis(forward.cross(up).normalized(), up, -forward)
	bank.rotation.z = -roll_angle
	body.position = Vector3(model.edge * 0.10, -absf(model.edge) * 0.09, -model.weight * 0.16)
	body.rotation.x = -model.weight * 0.15
	upper_body.rotation.y = -model.twist * 0.5 + (0.0 if model.regular else PI)

func _reset_run(message: String) -> void:
	model.reset()
	paused = false
	for trail in trails:
		trail.queue_free()
	trails.clear()
	trail_timer = 0.0
	hint_timer = 4.0
	hint_label.text = message
	_sync_rider()
	camera.global_position = rider.global_position + Vector3(4.0, 3.7, 7.0)

func _material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _mesh(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _box(parent: Node3D, size: Vector3, material: Material, at: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, material, at)

func _sphere(parent: Node3D, radius: float, material: Material, at: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _mesh(parent, mesh, material, at)

func _limb(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	var part: MeshInstance3D = _mesh(parent, mesh, material, (from + to) * 0.5)
	var direction: Vector3 = (to - from).normalized()
	var right: Vector3 = direction.cross(Vector3.FORWARD).normalized()
	part.basis = Basis(right, direction, right.cross(direction))

func _build_piste() -> void:
	snow_material = _material(Color("f5f8fa"))
	var ground := PlaneMesh.new()
	ground.size = Vector2(PISTE_WIDTH, PISTE_LENGTH + 40.0)
	var piste: MeshInstance3D = _mesh(self, ground, snow_material, model.world_position(Vector2(0.0, PISTE_LENGTH * 0.5 - 10.0)))
	piste.rotation.x = -deg_to_rad(model.slope_degrees)
	# The analytical surface is shared by snow rendering and the force model.
	var blue: StandardMaterial3D = _material(Color("335d74"))
	var orange: StandardMaterial3D = _material(ACCENT)
	for distance in range(0, int(PISTE_LENGTH), 20):
		for side in [-1.0, 1.0]:
			var marker := Node3D.new()
			add_child(marker)
			marker.position = model.world_position(Vector2(side * (PISTE_WIDTH / 2.0 - 1.0), distance))
			marker.basis = Basis(Vector3.RIGHT, model.surface_normal(), -model.world_direction(Vector2(0, 1)))
			_box(marker, Vector3(0.07, 1.7, 0.07), blue, Vector3(0, 0.85, 0))
			_box(marker, Vector3(0.5, 0.32, 0.025), orange if side < 0 else blue, Vector3(side * 0.23, 1.43, 0))
	# Quiet, white surroundings; no jumps, obstacles or trick ramps.
	for side in [-1.0, 1.0]:
		for i in range(9):
			var mountain := CylinderMesh.new()
			mountain.top_radius = 0.0
			mountain.bottom_radius = 25.0 + i % 3 * 8.0
			mountain.height = 25.0 + i % 4 * 12.0
			mountain.radial_segments = 5
			var location: Vector3 = model.world_position(Vector2(side * (75.0 + i % 2 * 20.0), i * 52.0 - 40.0))
			location.y += mountain.height * 0.2
			_mesh(self, mountain, snow_material, location)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("c4dce6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d5e4ee")
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("dce9ee")
	environment.fog_density = 0.002
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 67.0
	camera.far = 900.0
	camera.current = true
	add_child(camera)

func _build_rider() -> void:
	rider = Node3D.new()
	rider.name = "Snowboarder"
	add_child(rider)
	bank = Node3D.new()
	rider.add_child(bank)
	var board_mat: StandardMaterial3D = _material(Color("1a3b4c"), 0.4)
	var boot_mat: StandardMaterial3D = _material(Color("223340"))
	var pants_mat: StandardMaterial3D = _material(Color("3a5868"))
	var jacket_mat: StandardMaterial3D = _material(ACCENT)
	_box(bank, Vector3(0.29, 0.055, 1.43), board_mat, Vector3.ZERO)
	for z in [-0.715, 0.715]:
		var tip := CylinderMesh.new()
		tip.top_radius = 0.145
		tip.bottom_radius = 0.145
		tip.height = 0.055
		_mesh(bank, tip, board_mat, Vector3(0.0, 0.015, z))
	for z in [-0.33, 0.33]:
		var boot: MeshInstance3D = _box(bank, Vector3(0.29, 0.13, 0.12), boot_mat, Vector3(0.03, 0.10, z))
		boot.rotation.y = 0.25 * signf(z)
	body = Node3D.new()
	bank.add_child(body)
	for z in [-1.0, 1.0]:
		_limb(body, Vector3(0.0, 0.14, z * 0.33), Vector3(0.13, 0.40, z * 0.23), 0.075, pants_mat)
		_limb(body, Vector3(0.13, 0.40, z * 0.23), Vector3(0.0, 0.69, z * 0.12), 0.085, pants_mat)
	upper_body = Node3D.new()
	upper_body.position.y = 0.65
	body.add_child(upper_body)
	var torso := CapsuleMesh.new()
	torso.radius = 0.18
	torso.height = 0.57
	_mesh(upper_body, torso, jacket_mat, Vector3(0.0, 0.26, 0.0))
	_box(upper_body, Vector3(0.16, 0.37, 0.28), boot_mat, Vector3(-0.18, 0.27, 0.0))
	_sphere(upper_body, 0.19, boot_mat, Vector3(0.0, 0.68, 0.0))
	_box(upper_body, Vector3(0.045, 0.08, 0.28), _material(Color("f4c882"), 0.2), Vector3(0.175, 0.69, 0.0))
	for z in [-1.0, 1.0]:
		_limb(upper_body, Vector3(0.0, 0.45, z * 0.19), Vector3(0.12, 0.26, z * 0.35), 0.06, jacket_mat)
		_limb(upper_body, Vector3(0.12, 0.26, z * 0.35), Vector3(0.32, 0.25, z * 0.43), 0.055, jacket_mat)
		_sphere(upper_body, 0.065, boot_mat, Vector3(0.32, 0.25, z * 0.43))

func _leave_track(dt: float) -> void:
	trail_timer += dt
	if trail_timer < 0.09 or model.velocity.length() < 0.8:
		return
	trail_timer = 0.0
	var length: float = clampf(model.velocity.length() * 0.10, 0.15, 2.5)
	var width: float = 0.025 if model.slip_speed < 0.35 and absf(model.edge) > 0.3 else 0.22
	var trace: MeshInstance3D = _box(self, Vector3(width, 0.003, length), _material(Color("d5e2e9")), model.world_position(model.position) + model.surface_normal() * 0.007)
	var forward: Vector3 = model.world_direction(model.velocity.normalized())
	trace.basis = Basis(forward.cross(model.surface_normal()).normalized(), model.surface_normal(), -forward)
	trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trails.append(trace)
	if trails.size() > 420:
		trails.pop_front().queue_free()

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.99, 1.0, 0.92)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	return style

func _label(parent: Node, text: String, size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("dce6ec")
	bar.add_theme_stylebox_override("background", background)
	parent.add_child(bar)
	return bar

func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 34)
	top.add_theme_constant_override("margin_top", 28)
	top.add_theme_constant_override("margin_right", 34)
	root.add_child(top)
	var header := HBoxContainer.new()
	top.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_label(titles, "S N O W B O A R D   L A B", 26)
	_label(titles, "01  /  KANTENGRIP & BOCHTEN", 14, MUTED)
	var right := VBoxContainer.new()
	header.add_child(right)
	stance_label = _label(right, "REGULAR  ·  LINKERVOET VOOR", 15)
	_label(right, "OEFENPISTE  /  %.0f°  /  HARDE SNEEUW" % model.slope_degrees, 13, MUTED)
	var telemetry := PanelContainer.new()
	telemetry.position = Vector2(34, 128)
	telemetry.custom_minimum_size = Vector2(265, 0)
	telemetry.add_theme_stylebox_override("panel", _panel())
	root.add_child(telemetry)
	var readings := VBoxContainer.new()
	readings.add_theme_constant_override("separation", 9)
	telemetry.add_child(readings)
	_label(readings, "SNELHEID", 12, MUTED)
	speed_label = _label(readings, "0.0 km/u", 36)
	mode_label = _label(readings, "STILSTAAN", 15, ACCENT)
	_label(readings, "", 4)
	edge_label = _label(readings, "Vlak board", 14)
	edge_bar = _bar(readings, ACCENT)
	weight_label = _label(readings, "Gewicht  ·  gecentreerd", 14)
	weight_bar = _bar(readings, Color("48728a"))
	_label(readings, "ZIJWAARTSE SLIP", 12, MUTED)
	slip_bar = _bar(readings, Color("bb8555"))
	var bottom := MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -210
	bottom.add_theme_constant_override("margin_left", 34)
	bottom.add_theme_constant_override("margin_right", 34)
	bottom.add_theme_constant_override("margin_bottom", 28)
	root.add_child(bottom)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel())
	bottom.add_child(panel)
	var guide := VBoxContainer.new()
	guide.add_theme_constant_override("separation", 8)
	panel.add_child(guide)
	hint_label = _label(guide, "", 17)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(guide, "LB / Q  hielkant     RB / E  teenkant     L-stick / A D  lichaamsrotatie     R-stick / W S  voor–achter", 15)
	_label(guide, "A / R  opnieuw     Y / G  wissel regular / goofy     Start / Esc  pauze", 14, MUTED)
	input_label = _label(guide, "", 12, MUTED)
	var pause_center := CenterContainer.new()
	pause_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pause_center)
	pause_label = _label(pause_center, "GEPAUZEERD  ·  Start / Esc om verder te rijden", 24)

func _update_interface() -> void:
	var speed: float = model.velocity.length()
	speed_label.text = "%.1f km/u" % (speed * 3.6)
	if speed < 0.12:
		mode_label.text = "STILSTAAN"
	elif model.slip_speed > 0.5:
		mode_label.text = "SLIPPEN  ·  %.1f m/s" % model.slip_speed
	elif absf(model.edge) > 0.3:
		mode_label.text = "OP DE KANT"
	else:
		mode_label.text = "VLAK GLIJDEN"
	var physical_edge: float = model.edge * (1.0 if model.regular else -1.0)
	var edge_name: String = "Hielkant" if physical_edge < -0.05 else ("Teenkant" if physical_edge > 0.05 else "Vlak board")
	edge_label.text = "%s  ·  %.0f°" % [edge_name, absf(model.edge) * 48.0]
	edge_bar.value = absf(model.edge) * 100.0
	var weight_name: String = "voor" if model.weight > 0.15 else ("achter" if model.weight < -0.15 else "gecentreerd")
	weight_label.text = "Gewicht  ·  " + weight_name
	weight_bar.value = (model.weight + 1.0) * 50.0
	slip_bar.value = clampf(model.slip_speed / 5.0, 0.0, 1.0) * 100.0
	stance_label.text = "REGULAR  ·  LINKERVOET VOOR" if model.regular else "GOOFY  ·  RECHTERVOET VOOR"
	pause_label.visible = paused
	if hint_timer <= 0.0:
		hint_label.text = "Oefen: rol rustig aan, kies een kant en draai je bovenlichaam. Rem door het board dwars te zetten en je kant vast te houden."
