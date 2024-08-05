@tool
extends Node3D

const GRASS_MESH_HIGH := preload('res://assets/grass/grass_high.obj')
const GRASS_MESH_LOW := preload('res://assets/grass/grass_low.obj')
const GRASS_MAT := preload('res://assets/grass/mat_grass.tres')
const HEIGHTMAP := preload('res://assets/heightmap.tres')

const TILE_SIZE := 5.0
const MAP_RADIUS := 200.0

var grass_multimeshes : Array[Array] = []
var previous_tile_id := Vector3.ZERO
var should_render_imgui := true

@onready var camera := get_viewport().get_camera_3d()
@onready var camera_fov := [camera.fov]
@onready var should_render_fog := [$Environment.environment.volumetric_fog_enabled]
@onready var should_render_shadows := [true]
@onready var density_modifier := [1.0]
@onready var clumping_factor := [GRASS_MAT.get_shader_parameter('clumping_factor')]
@onready var wind_speed := [GRASS_MAT.get_shader_parameter('wind_speed')]

func _init() -> void:
	DisplayServer.window_set_size(DisplayServer.screen_get_size() * 0.75)
	DisplayServer.window_set_position(DisplayServer.screen_get_size() * 0.25 / 2.0)
	RenderingServer.global_shader_parameter_set('heightmap', HEIGHTMAP) # idk this needs to be set manually??
	
func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_tree().root.get_viewport_rid(), true) 
	_setup_heightmap_collision()
	_setup_grass_instances()
	_generate_grass_multimeshes()

func _render_imgui() -> void:
	if not should_render_imgui or Engine.is_editor_hint(): return
	
	var viewport_rid := get_tree().root.get_viewport_rid()
	var frame_time = RenderingServer.get_frame_setup_time_cpu() + RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
	
	ImGui.Begin(' ', [], ImGui.WindowFlags_AlwaysAutoResize | ImGui.WindowFlags_NoMove)
	ImGui.SetWindowPos(Vector2(20, 20))
	
	ImGui.PushStyleColor(ImGui.Col_Text, Color.WEB_GRAY); ImGui.Text('Press %s-H to toggle visibility!' % ['Cmd' if OS.get_name() == 'macOS' else 'Ctrl']); ImGui.PopStyleColor()
	ImGui.SeparatorText('Grass')
	ImGui.Text('FPS:              %d (%s)' % [Engine.get_frames_per_second(), '%.2fms' % frame_time])
	ImGui.Text('Render Fog:      '); ImGui.SameLine(); if ImGui.Checkbox('##fog_bool', should_render_fog): $Environment.environment.volumetric_fog_enabled = should_render_fog[0]
	ImGui.Text('Render Shadows:  '); ImGui.SameLine(); if ImGui.Checkbox('##shadows_bool', should_render_shadows):
		for data in grass_multimeshes:
			data[0].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if should_render_shadows[0] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ImGui.Text('Grass Density:   '); ImGui.SameLine(); if ImGui.SliderFloat('##density_float', density_modifier, 0.0, 1.0): _generate_grass_multimeshes()
	ImGui.Text('Clumping Factor: '); ImGui.SameLine(); if ImGui.SliderFloat('##clump_float', clumping_factor, 0.0, 1.0): GRASS_MAT.set_shader_parameter('clumping_factor', clumping_factor[0])
	ImGui.Text('Wind Speed:      '); ImGui.SameLine(); if ImGui.SliderFloat('##speed_float', wind_speed, 0.0, 5.0): 
		GRASS_MAT.set_shader_parameter('wind_speed', (wind_speed[0] + 0.1)*0.91)
		$WindAudioPlayer.pitch_scale = lerpf(0.8, 2.0, wind_speed[0] / 5.0)
		$WindAudioPlayer.volume_db = lerpf(-10.0, 5.0, min(wind_speed[0], 1.0))
		$GrassAudioPlayer.volume_db = lerpf(-30.0, -18.5, wind_speed[0] / 5.0)
		$InsectAudioPlayer.volume_db = lerpf(-30.0, -80.0, wind_speed[0] / 5.0)
	ImGui.SeparatorText('Camera')
	ImGui.Text('Camera Position:  %+.2v' % [$Player/CameraMount/Camera3D.global_position])
	ImGui.Text('Camera FOV:      '); ImGui.SameLine(); if ImGui.SliderFloat('##fov_float', camera_fov, 20, 170): camera.fov = camera_fov[0]
	ImGui.End()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed('toggle_imgui'):
		should_render_imgui = not should_render_imgui

func _process(delta: float) -> void:
	_render_imgui()

func _physics_process(delta: float) -> void:
	RenderingServer.global_shader_parameter_set('player_position', $Player.global_position)

	# Correct LOD by repositioning tiles when the player moves into a new tile
	var lod_target : Node3D = EditorInterface.get_editor_viewport_3d(0).get_camera_3d() if Engine.is_editor_hint() else $Player
	var tile_id : Vector3 = ((lod_target.global_position + Vector3.ONE*TILE_SIZE*0.5) / TILE_SIZE * Vector3(1,0,1)).floor()
	if tile_id != previous_tile_id:
		for data in grass_multimeshes:
			data[0].global_position = data[1] + Vector3(1,0,1)*TILE_SIZE*tile_id
	previous_tile_id = tile_id

## Creates a HeightMapShape3D from the provided NoiseTexture2D
func _setup_heightmap_collision() -> void:
	var heightmap := HEIGHTMAP.noise.get_image(512, 512)
	var map_data : PackedFloat32Array
	for j in heightmap.get_height():
		for i in heightmap.get_width():
			map_data.push_back((heightmap.get_pixel(i, j).r - 0.5)*5.0)
	
	var heightmap_shape := HeightMapShape3D.new()
	heightmap_shape.map_width = heightmap.get_height()
	heightmap_shape.map_depth = heightmap.get_width()
	heightmap_shape.map_data = map_data
	$StaticBody3D/CollisionShape3D.shape = heightmap_shape

## Creates initial tiled multimesh instances.
func _setup_grass_instances() -> void:
	for i in range(-MAP_RADIUS, MAP_RADIUS, TILE_SIZE):
		for j in range(-MAP_RADIUS, MAP_RADIUS, TILE_SIZE):
			var instance := MultiMeshInstance3D.new()
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if should_render_shadows[0] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.material_override = GRASS_MAT
			instance.position = Vector3(i, 0.0, j)
			instance.extra_cull_margin = 1.0
			add_child(instance)
			grass_multimeshes.append([instance, instance.position])

## Generates multimeshes for previously created multimesh instances with LOD based
## on distance to origin.
func _generate_grass_multimeshes() -> void:
	var multimesh_lods : Array[MultiMesh] = [
		create_grass_multimesh(1.0*density_modifier[0], TILE_SIZE, GRASS_MESH_HIGH),
		create_grass_multimesh(0.5*density_modifier[0], TILE_SIZE, GRASS_MESH_HIGH),
		create_grass_multimesh(0.25*density_modifier[0], TILE_SIZE, GRASS_MESH_LOW),
		create_grass_multimesh(0.1*density_modifier[0], TILE_SIZE, GRASS_MESH_LOW),
		create_grass_multimesh(0.02*(1.0 if density_modifier[0] != 0.0 else 0.0), TILE_SIZE, GRASS_MESH_LOW),
	]
	for data in grass_multimeshes:
		var distance = data[1].length() # Distance from center tile
		if distance > MAP_RADIUS: continue
		if distance < 12.0:    data[0].multimesh = multimesh_lods[0]
		elif distance < 40.0:  data[0].multimesh = multimesh_lods[1]
		elif distance < 70.0:  data[0].multimesh = multimesh_lods[2]
		elif distance < 100.0: data[0].multimesh = multimesh_lods[3]
		else:                  data[0].multimesh = multimesh_lods[4]

func create_grass_multimesh(density : float, tile_size : float, mesh : Mesh) -> MultiMesh:
	var row_size = ceil(tile_size*lerpf(0.0, 10.0, density));
	var multimesh := MultiMesh.new()
	multimesh.mesh = mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = row_size*row_size

	var jitter_offset := tile_size/float(row_size) * 0.5 * 0.9
	for i in row_size:
		for j in row_size:
			var grass_position := Vector3(i/float(row_size) - 0.5, 0, j/float(row_size) - 0.5) * tile_size
			var grass_offset := Vector3(randf_range(-jitter_offset, jitter_offset), 0, randf_range(-jitter_offset, jitter_offset))
			multimesh.set_instance_transform(i + j*row_size, Transform3D(Basis(), grass_position + grass_offset))
	return multimesh
