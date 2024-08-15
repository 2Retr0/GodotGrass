@tool
extends Node

const PREFIXES := ['skirt0', 'skirt1', 'skirt2']
const SUFFIXES := ['_S_L', '_F_L', '_F_M', '_F_R', '_S_R', '_B_R', '_B_M', '_B_L']
const NUM_SUBDIVISIONS := 1

class Particle:
	var position : Vector3
	var previous_position : Vector3
	var rest_position : Vector3
	var normal : Vector3
	var gravity : Vector3
	var is_pinned := false
	
	func _init(position_ : Vector3, normal_ : Vector3, gravity_direction:=Vector3.UP) -> void:
		position = position_
		previous_position = position_
		rest_position = position_
		normal = normal_.normalized()
		gravity = gravity_direction.normalized() * ProjectSettings.get_setting('physics/3d/default_gravity')
	
	func integrate(delta : float, previous_delta : float) -> void:
		if is_pinned: return
		var velocity := position - previous_position
		var acceleration := -gravity - velocity*300.0 # Damping
		var displacement := velocity*(delta/previous_delta) + acceleration*lerpf(delta, previous_delta, 0.5)*delta
		
		previous_position = position
		position += displacement

class Spring:
	var p0 : Particle
	var p1 : Particle
	var stiffness : float
	var length : float
	
	func _init(p0_ : Particle, p1_ : Particle, stiffness_:=1.0) -> void:
		p0 = p0_
		p1 = p1_
		stiffness = stiffness_
		length = p0.position.distance_to(p1.position)
		
	func calculate_forces() -> void:
		var displacement := p1.position - p0.position
		var offset := displacement.normalized() * (length - displacement.length()) * 0.5 * stiffness
		if not p0.is_pinned: p0.position -= offset
		if not p1.is_pinned: p1.position += offset

class CapsuleCollider:
	var shape : CollisionShape3D
	var transform : Transform3D
	var endpoints : Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var radius : float
	
	func _init(shape_ : CollisionShape3D) -> void:
		assert(shape_.shape is CapsuleShape3D)
		shape = shape_
	
	func calculate_properties(delta : float) -> void:
		var new_transform = (shape.get_parent_node_3d().transform * shape.transform)
		radius = lerpf(radius, shape.shape.radius * (0.5 if transform.is_equal_approx(new_transform) else 1.0), delta * 3.0)
		transform = new_transform
		
		var capsule_axis : Vector3 = transform.basis.y.normalized() * (shape.shape.height - radius*2.0)*0.5
		endpoints[0] = transform.origin - capsule_axis
		endpoints[1] = transform.origin + capsule_axis

@export var skeleton : Skeleton3D :
	set(value):
		skeleton = value
		if value: generate_fabric()
@export var colliders : Array[CollisionShape3D] :
	set(value):
		var temp : Array[CapsuleCollider] = []
		for collider in value:
			if not collider: continue
			if not collider.shape is CapsuleShape3D:
				printerr('Collider shape must be CapsuleShape3D!')
				return
			temp.push_back(CapsuleCollider.new(collider))
		colliders = value
		colliders_ = temp
@export_category('Editor Only')
@export var toggle_debug := false :
	set(value):
		if not Engine.is_editor_hint(): return
		$ParticleDebugMultiMesh.visible = not $ParticleDebugMultiMesh.visible 
		$SpringDebugMultiMesh.visible = not $SpringDebugMultiMesh.visible
		
var colliders_ : Array[CapsuleCollider]
var bone_cache : Array[Array]
var bone_map : Array[Array]
var particle_map : Array[Array]
var particles : Array[Particle]
var springs : Array[Spring]

var previous_global_position := Vector3.ZERO
var previous_delta := 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if skeleton: 
		generate_fabric()
	else:
		self.set_physics_process(false)
	if not Engine.is_editor_hint():
		$ParticleDebugMultiMesh.queue_free()
		$SpringDebugMultiMesh.queue_free()

func generate_fabric() -> void:
	var sub_factor := NUM_SUBDIVISIONS + 1
	# Resize particle map
	particle_map.clear(); particle_map.resize(len(PREFIXES) + 1)
	for i in range(len(PREFIXES) + 1): particle_map[i].resize(len(SUFFIXES) * sub_factor)
		
	# Fill bone map (cache)
	bone_cache.clear(); bone_cache.resize(len(PREFIXES))
	for i in range(len(PREFIXES)):
		for j in range(len(SUFFIXES)):
			bone_cache[i].push_back(skeleton.find_bone(PREFIXES[i] + SUFFIXES[j]))
	
	particles.clear(); springs.clear(); bone_map.clear()
	skeleton.clear_bones_global_pose_override()
	for i in range(len(PREFIXES) + 1):
		for j in range(len(particle_map[i])):
			var particle : Particle
			if i != len(PREFIXES):
				# Note: this also covers the case for a particle that is part of a subdivision!
				var divisor := snappedf(j / float(sub_factor), 1e-2)
				var t0 := skeleton.get_bone_global_rest(bone_cache[i][floori(divisor)])
				var t1 := skeleton.get_bone_global_rest(bone_cache[i][ceili(divisor) % len(SUFFIXES)])
				var t := divisor - floorf(divisor)
				var basis_lerped := t0.basis.slerp(t1.basis, t)
				particle = Particle.new(t0.origin.lerp(t1.origin, t), basis_lerped.z * Vector3(-1,1,1), -basis_lerped.y)
			else:
				var p0 : Particle = particle_map[i-2][j]
				var p1 : Particle = particle_map[i-1][j]
				particle = Particle.new(p1.position + (p1.position - p0.position), p1.normal, p1.gravity)
			
			if i != 0:
				# Connect with previous particle above
				springs.push_back(Spring.new(particle, particle_map[i-1][j], 1.0))
				if j != 0: # Connect with previous particle horizontally
					springs.push_back(Spring.new(particle, particle_map[i][j-1], 1.0))
				if j == len(particle_map[i]) - 1: # Connect with first particle horizontally
					springs.push_back(Spring.new(particle, particle_map[i][0], 1.0))
				if i == len(PREFIXES):
					# We add these connections as a hack to reduce shearing across the fabric
					springs.push_back(Spring.new(particle, particle_map[0][j-1], 1.0))
					springs.push_back(Spring.new(particle, particle_map[0][(j+1) % len(particle_map[i])], 1.0))
					
				if j % sub_factor == 0: # Couple previous bone above with particle's rotation
					bone_map.push_back([bone_cache[i-1][j / sub_factor], particle])
			else:
				particle.is_pinned = true
			
			particles.push_back(particle)
			particle_map[i][j] = particle
	self.set_physics_process(true)

func _physics_process(delta: float) -> void:
	### Update pinned bone positions (relative to skeleton pose) ###
	var sub_factor := NUM_SUBDIVISIONS + 1
	var pinned_particles := particle_map[0]
	var pinned_bones := bone_cache[0]
	for j in range(len(pinned_particles)):
		if j % sub_factor == 0:
			pinned_particles[j].position = skeleton.get_bone_global_pose_no_override(pinned_bones[j / sub_factor]).origin
		else: # If particle is part of a subdivision (i.e., between bones)
			var divisor := j / float(sub_factor)
			var p0 := skeleton.get_bone_global_pose_no_override(pinned_bones[floori(divisor)]).origin
			var p1 := skeleton.get_bone_global_pose_no_override(pinned_bones[ceili(divisor) % len(SUFFIXES)]).origin
			pinned_particles[j].position = p0.lerp(p1, divisor - floorf(divisor))
	
	### Update collider properties ###
	for collider in colliders_: collider.calculate_properties(delta)
	
	### Solve collisions ###
	for particle in particles:
		if particle.is_pinned: continue
		for collider in colliders_:
			# my 'novel' approach to collision correction... :3
			if sdf_capsule(particle.position, collider.endpoints[0], collider.endpoints[1], collider.radius) <= 0.0:
				# We project the normal to collider's local space so that it faces the direction of
				# the fabric were it deformed over the collider.
				var normal := collider.transform.basis * particle.normal
				# We displace the particle on the surface of the collider in the direction of the
				# calculated normal.
				var t := ray_capsule_intersection(particle.position, normal, collider.endpoints[0], collider.endpoints[1], collider.radius)
				particle.position += t*normal
				break
		particle.position += (previous_global_position - skeleton.global_position) * delta * 10.0
	previous_global_position = skeleton.global_position
	
	### Solve distance constraints ###
	for spring in springs: spring.calculate_forces()
	
	### Apply forces on particles ###
	for particle in particles: particle.integrate(delta, previous_delta)
	previous_delta = delta
	
	### Update bone rotations ###
	for mapping in bone_map: calculate_bone_rotation(mapping[0], mapping[1].position)
	
	if Engine.is_editor_hint():
		draw_debug()

func draw_debug() -> void:
	$ParticleDebugMultiMesh.multimesh.instance_count = particles.size()
	$SpringDebugMultiMesh.multimesh.instance_count = springs.size()
	for i in range(particles.size()):
		$ParticleDebugMultiMesh.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(skeleton.global_basis.get_scale()), skeleton.global_transform * particles[i].position))
	for i in range(springs.size()):
		var displacement = springs[i].p1.position - springs[i].p0.position
		var direction = displacement.normalized()
		var spring_basis := skeleton.global_basis * Basis.from_scale(Vector3(1.0, displacement.length(), 1.0)).rotated(Vector3.UP.cross(direction).normalized(), acos(Vector3.UP.dot(direction)))
		$SpringDebugMultiMesh.multimesh.set_instance_transform(i, Transform3D(spring_basis, skeleton.global_transform * (springs[i].p0.position + displacement*0.5)))

## Source: https://iquilezles.org/articles/distfunctions/
func sdf_capsule(p : Vector3, p0 : Vector3, p1 : Vector3, radius : float) -> float:
	var pa := p - p0
	var ba := p1 - p0
	var h := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba*h).length() - radius

## Source: https://iquilezles.org/articles/intersectors/
func ray_capsule_intersection(ro : Vector3, rd : Vector3, p0 : Vector3, p1 : Vector3, radius : float) -> float:
	var ba := p1 - p0
	var oa := ro - p0
	var baba := ba.dot(ba)
	var bard := ba.dot(rd)
	var baoa := ba.dot(oa)
	var rdoa := rd.dot(oa)
	var oaoa := oa.dot(oa)
	var a := baba      - bard*bard
	var b := baba*rdoa - baoa*bard
	var c := baba*oaoa - baoa*baoa - radius*radius*baba
	var h := b*b - a*c
	if h >= 0.0:
		var t := (-b + sqrt(h)) / a
		var y := baoa + t*bard
		# Test body intersection
		if y > 0.0 and y < baba: return t
		# Test caps intersection
		var oc := oa if y <= 0.0 else ro - p1
		b = rd.dot(oc)
		c = oc.dot(oc) - radius*radius
		h = b*b - c
		if h > 0.0: return -b + sqrt(h)
	return -1.0

func calculate_bone_rotation(bone_idx : int, look_at : Vector3) -> void:
	var bone_transform := skeleton.get_bone_global_pose(bone_idx)
	var displacement := (bone_transform.affine_inverse() * look_at).normalized()

	var rotation_axis := Vector3.UP.cross(displacement)
	var rotation_angle := acos(Vector3.UP.dot(displacement))

	if rotation_axis.length_squared() >= 1e-6:
		skeleton.set_bone_global_pose_override(bone_idx, bone_transform.rotated_local(rotation_axis.normalized(), rotation_angle), 0.8, true)
