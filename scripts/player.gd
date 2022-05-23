extends CharacterBody3D

@export var Sensitivity_X = 0.01
@export var Sensitivity_Y = 0.01
@export var Invert_Y_Axis = false
@export var Minimum_Y_Look = -90
@export var Maximum_Y_Look = 90
@export var Accelaration = 1
@export var Decelaration = 1
@export var Air_Accelaration = 0.05
@export var Air_Decelaration = 0.05
@export var Cap = 5
@export var Air_Cap = 50
@export var Jump_Speed = 10
@export var Jump_Jetpack = true
@export var Gravity = 0.5

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_process(true)

func _process(delta):
	# if Input.is_key_pressed(KEY_ESCAPE):
		# get_tree().quit()
	pass

func _physics_process(delta):
	# Handle horizontal (X and Z) movement
	if not(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT)):
		var Movement = Decelaration if is_on_floor() else Air_Decelaration
		velocity.x /= 1 + Movement
		velocity.z /= 1 + Movement
	else:
		var Movement = Accelaration if is_on_floor() else Air_Accelaration
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
			velocity.x -= global_transform.basis.z.x * Movement
			velocity.z -= global_transform.basis.z.z * Movement
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			velocity.x += global_transform.basis.z.x * Movement
			velocity.z += global_transform.basis.z.z * Movement
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
			velocity.x -= global_transform.basis.x.x * Movement
			velocity.z -= global_transform.basis.x.z * Movement
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			velocity.x += global_transform.basis.x.x * Movement
			velocity.z += global_transform.basis.x.z * Movement

	# Handle vertical (Y) movement
	if Input.is_action_just_pressed("ui_accept") and (is_on_floor() or Jump_Jetpack):
		velocity.y += Jump_Speed
	velocity.y -= Gravity

	# Apply movement
	var MovementCap = Cap if is_on_floor() else Air_Cap
	velocity.x = min(MovementCap, max(-MovementCap, velocity.x))
	velocity.y = min(MovementCap, max(-MovementCap, velocity.y))
	velocity.z = min(MovementCap, max(-MovementCap, velocity.z))
	move_and_slide()

func _input(event):
	if event is InputEventMouseMotion:
		var camera = get_node("PlayerCamera")
		camera.rotate_x(-Sensitivity_Y * event.relative.y)
		camera.rotation.x = min(deg2rad(Maximum_Y_Look), max(deg2rad(Minimum_Y_Look), camera.rotation.x))

		rotate_y(-Sensitivity_X * event.relative.x)
