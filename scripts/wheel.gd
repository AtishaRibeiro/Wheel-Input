extends Spatial

var time_elapsed = 0.0
var rkgd
var rot_x = 0.0
var rot_y = 0.0
var rot_x_collection
var rot_y_collection
var recording = false
var playing = false
var current_frame = 0
var transform_basis
var image_dir = "Images"
var previous_frame = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	transform_basis = transform.basis
	rkgd = RKGD.new()
	reset_inputs(rkgd.get_neutral_input())
	
func load_ghost_file(path):
	end_play()
	end_record()
	rkgd.load_file(path)
	get_parent().update_frames(0, rkgd.total_frames)

func reset_inputs(first_input):
	rot_x_collection = []
	rot_y_collection = []
	for _i in range(6):
		rot_x_collection.push_back(first_input["analog"][0] - 0.5)
		rot_y_collection.push_back(0.5 - first_input["analog"][1])

func get_average(arr):
	var total = 0
	for x in arr:
		total += x
	return total / arr.size()

func get_interpolated_rotation(x, y):
	rot_x_collection.pop_front()
	rot_x_collection.push_back(x)
	rot_y_collection.pop_front()
	rot_y_collection.push_back(y)
	return [get_average(rot_x_collection), get_average(rot_y_collection)]

func start_record():
	if !rkgd.file_loaded:
		end_record()
		return
		
	end_play()
	# Creates an empty folder.
	var directory = Directory.new()
	directory.make_dir(image_dir)
	print(directory.get_current_dir())
	
	reset_inputs(rkgd.get_input(0))
	current_frame = 0
	recording = true
	
	
func end_record():
	recording = false
	time_elapsed = 0.0
	current_frame = 0
	get_parent().end_record()
	
func start_play():
	if rkgd.file_loaded:
		playing = true
		reset_inputs(rkgd.get_input(0))
		time_elapsed = 0.0
		
func end_play():
	playing = false
	time_elapsed = 0.0

func animate(new_rot_x, new_rot_y, a_button, b_button):
	transform.basis = transform_basis # reset rotation
	rotate_object_local(Vector3(0, 0, 1), new_rot_x * 1.2)
	rotate_object_local(Vector3(1, 0, 0), new_rot_y)
	transform = transform.orthonormalized()
	rot_x = new_rot_x
	rot_y = new_rot_y
	
	if a_button:
		get_node("a_button").material.albedo_color = Color(0.58, 1, 0.192)
	else:
		get_node("a_button").material.albedo_color = Color(1, 1, 1)
		
	if b_button:
		get_node("b_button").material.albedo_color = Color(1, 0.278, 0.278)
	else:
		get_node("b_button").material.albedo_color = Color(1, 1, 1)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if !recording and playing:
		current_frame = floor(time_elapsed * 59.94)
		time_elapsed += delta

	if (current_frame == previous_frame) and current_frame != 0:
		return
	else:
		previous_frame = current_frame
		get_parent().update_frames(current_frame, rkgd.total_frames)
		
	var input = rkgd.get_input(current_frame)
	var new_rot_x = input["analog"][0] - 0.5
	var new_rot_y = 0.5 - input["analog"][1]
	
	if !input["active"]:
		if playing:
			end_play()
		if recording:
			end_record()
		animate(new_rot_x, new_rot_y, input["a_button"], input["b_button"])
		return
	
	var interpolations = get_interpolated_rotation(new_rot_x, new_rot_y)
	var interpol_x = interpolations[1]
	var interpol_y = interpolations[0] * 1.3
	animate(interpol_x, interpol_y, input["a_button"], input["b_button"])
	
	if recording:
		var image = get_viewport().get_texture().get_data()
		image.convert(Image.FORMAT_RGBA8)
		image.flip_y()
		image.save_png(image_dir + "/%s.png" % current_frame)
		current_frame += 1
