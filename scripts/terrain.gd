extends Node3D

@export var distance = 256
@export var chunk_size = 16
@export var steps = 1
@export var lod_levels = 4
@export var density = Vector2(64, 256)

var chunk_mins: Vector3i
var chunk_maxs: Vector3i
var chunk_active: Vector3
var chunk_nodes: Dictionary
var chunk_nodes_body: Dictionary
var chunk_nodes_body_collisions: Dictionary
var chunks: Array
var mc: MarchingCubes
var view_sphere: Array
var viewer: CharacterBody3D
var update_lod: Dictionary
var update_reset: bool
var noise: OpenSimplexNoise
var update_semaphore: Semaphore
var update_thread: Thread

func _enter_tree():
	var size = int(round(chunk_size / 2))
	chunk_mins = Vector3i(0 - size, 0 - size, 0 - size)
	chunk_maxs = Vector3i(0 + size, 0 + size, 0 + size)
	chunk_active = Vector3(0, 0, 0)
	chunk_nodes = {}
	chunk_nodes_body = {}
	chunk_nodes_body_collisions = {}
	chunks = []
	mc = MarchingCubes.new(chunk_mins, chunk_maxs, steps)
	view_sphere = []
	viewer = get_parent().get_node("Player")
	update_lod = {}
	update_reset = false

	# Configure the virtual sphere of possible chunk positions
	for x in range(-distance, distance + 1, chunk_size):
		for y in range(-distance, distance + 1, chunk_size):
			for z in range(-distance, distance + 1, chunk_size):
				var pos = Vector3(x, y, z)
				if pos.distance_to(Vector3i(0, 0, 0)) <= distance:
					view_sphere.append(pos)
	view_sphere.sort_custom(_sort_closest)
	chunk_active = Vector3(INF, INF, INF)

	noise = OpenSimplexNoise.new()
	noise.seed = randi()
	noise.octaves = 16
	noise.lacunarity = 4
	noise.period = 256
	noise.persistence = 0.5

	update_semaphore = Semaphore.new()
	update_thread = Thread.new()
	update_thread.start(Callable(self, "_threads_update"))

func _exit_tree():
	update_thread.wait_to_finish()

func _process(delta):
	# Updates are only preformed when the player moves into a new chunk
	# Other chunks are evaluated based on the distance between them and the active chunk
	# This improves performance while providing a good level of accuracy
	var pos = viewer.position
	var pos_chunk = pos.snapped(Vector3i(chunk_size, chunk_size, chunk_size))
	if chunk_active != pos_chunk:
		chunk_active = pos_chunk
		update_reset = true
		update_semaphore.post()

# Sort chunk positions so entries closest to the active chunk come first
func _sort_closest(a: Vector3, b: Vector3):
	return a.distance_squared_to(chunk_active) < b.distance_squared_to(chunk_active) 

# Thread that scans for changes and updates chunk objects
func _threads_update():
	while true:
		update_semaphore.wait()
		update_reset = false

		# Remove nodes for chunks that are out of range
		for pos in chunks.duplicate():
			if update_reset:
				break
			if pos.distance_to(chunk_active) >= distance:
				_chunk_destroy(pos)
				update_lod.erase(pos)

		# Create nodes for chunks that are within range or change the LOD of existing chunks
		# LOD level 0 marks empty chunks that don't need to be spawned
		for pos_point in view_sphere:
			if update_reset:
				break
			var pos = pos_point + chunk_active
			var dist = pos.distance_to(chunk_active)
			var lod = 1 + floor(dist / (distance / lod_levels))
			if not update_lod.has(pos) or (update_lod[pos] > 0 and update_lod[pos] != lod):
				var points = _get_points(pos)
				if points:
					if not chunks.has(pos):
						_chunk_create(pos)
					var mesh = mc.get_mesh(points, lod)
					var mesh_collision = mesh.create_trimesh_shape()
					chunk_nodes[pos].set_mesh(mesh)
					chunk_nodes_body_collisions[pos].set_shape(mesh_collision)
				update_lod[pos] = lod if points else 0

# Create a new chunk and set properties that don't need to be updated
func _chunk_create(pos: Vector3):
	chunks.append(pos)

	chunk_nodes[pos] = MeshInstance3D.new()
	chunk_nodes[pos].position = pos
	chunk_nodes_body[pos] = StaticBody3D.new()
	chunk_nodes_body_collisions[pos] = CollisionShape3D.new()

	chunk_nodes_body[pos].call_deferred("add_child", chunk_nodes_body_collisions[pos])
	chunk_nodes[pos].call_deferred("add_child", chunk_nodes_body[pos])
	call_deferred("add_child", chunk_nodes[pos])

# Destroy a chunk and remove its data from memory
func _chunk_destroy(pos: Vector3):
	chunks.erase(pos)

	chunk_nodes_body_collisions[pos].queue_free()
	chunk_nodes_body[pos].queue_free()
	chunk_nodes[pos].queue_free()

	chunk_nodes.erase(pos)
	chunk_nodes_body.erase(pos)
	chunk_nodes_body_collisions.erase(pos)

# Noise for the point density
func _get_points_noise(pos: Vector3):
	var ofs = density[0] if pos.y >= 0 else density[1]
	var n = noise.get_noise_3dv(pos) + (pos.y / ofs)
	return min(max(n, -1), 1)

# Get the point density of each unit within this cubic area
func _get_points(pos: Vector3):
	var p = {}
	var p_valid = false
	for x in range(chunk_mins.x, chunk_maxs.x + 3):
		for y in range(chunk_mins.y, chunk_maxs.y + 3):
			for z in range(chunk_mins.z, chunk_maxs.z + 3):
				var vec = Vector3(x, y, z)
				var vec_noise = Vector3(pos.x + x, pos.y + y, pos.z + z)
				p[vec] = _get_points_noise(vec_noise)
				if p[vec] > 0 and p[vec] < 1:
					p_valid = true
	return p if p_valid else null
