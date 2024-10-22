extends CharacterBody3D

@export var speed := 5.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.4
@export var enable_camera_movement := true

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting('physics/3d/default_gravity')
var blend_factor := 0.0

@onready var model : Node3D = $Reisen
@onready var camera_offset_z : float = $CameraMount/Camera3D.position.z
@onready var camera_rotation := Vector2($CameraMount.rotation_degrees.x, $CameraMount.rotation_degrees.y)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and enable_camera_movement:
		camera_rotation += -event.relative * mouse_sensitivity
		camera_rotation.y = clamp(camera_rotation.y, -80.0, 70.0)
		$CameraMount.rotation_degrees = Vector3(camera_rotation.y, camera_rotation.x, 0.0)
	elif Input.is_action_pressed('ui_focus_next'):
		camera_offset_z = maxf(camera_offset_z, 1.25)
		camera_offset_z -= 0.25
	elif Input.is_action_pressed('ui_focus_prev'):
		camera_offset_z += 0.25
		camera_offset_z = minf(camera_offset_z, 4.0)

func _process(delta: float) -> void:
	if abs(velocity.x) + abs(velocity.z) != 0.0:
		var angle_offset_velocity : float = velocity.signed_angle_to(-$CameraMount.global_basis.z * Vector3(1,0,1), Vector3.UP)
		model.rotation.y = lerp_angle(model.rotation.y, $CameraMount.rotation.y + PI - angle_offset_velocity, minf(delta*5.0, 1.0))
	
	# Add procedural leaning based on velocity
	var angle_offset_z : float = clamp(-model.global_basis.z.cross(velocity).y * 0.02, -0.1, 0.1) * PI
	model.rotation.z = lerp_angle(model.rotation.z, angle_offset_z, minf(delta*3.0, 1.0))
	
	# Smooth camera distance transition
	$CameraMount/Camera3D.position.z = lerpf($CameraMount/Camera3D.position.z, camera_offset_z, minf(delta*5.0, 1.0))

func _physics_process(delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enable_camera_movement else Input.MOUSE_MODE_VISIBLE
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	#if Input.is_action_just_pressed('ui_accept') and is_on_floor():
		#velocity.y = jump_velocity

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector('ui_left', 'ui_right', 'ui_up', 'ui_down')
	var direction : Vector3 = ($CameraMount.global_basis * Vector3(input_dir.x, 0, input_dir.y) * Vector3(1,0,1)).normalized()
	if direction:
		blend_factor += delta*5.0
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		blend_factor -= delta*5.0
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	move_and_slide()
	
	blend_factor = clamp(blend_factor, 0.0, 1.0)
	$AnimationTree.set('parameters/Run/blend_amount', blend_factor)
