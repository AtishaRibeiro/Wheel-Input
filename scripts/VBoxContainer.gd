extends VBoxContainer

var ghost_file = "no file loaded"
var total_frames = 0
var current_frame = 0
var recording = false

func _ready():
	get_tree().get_root().set_transparent_background(true)
	get_node("FileDialog").current_path = OS.get_executable_path()
	get_node("FileDialog2").current_path = OS.get_executable_path()

func end_record():
	get_node("ghost_button").visible = true
	get_node("play_button").visible = true
	get_node("record_button").visible = true
	get_node("transp_button").visible = true
	recording = false
	OS.set_window_resizable(true)

func update_frames(current, total):
	current_frame = current
	total_frames = total

func _process(delta):
	var recording_string = " RECORDING " if recording else ""
	OS.set_window_title("%s | %s[%s/%s]" % [ghost_file, recording_string, current_frame, total_frames])

func _on_ghost_button_pressed():
	get_node("FileDialog").popup()

func _on_FileDialog_file_selected(path):
	get_node("WiiWheel").load_ghost_file(path)
	ghost_file = path.split("/")[-1]

func _on_record_button_pressed():
	get_node("FileDialog2").popup()


func _on_play_button_pressed():
	get_node("WiiWheel").start_play()


func _on_transp_button_toggled(button_pressed):
	get_node("bg_plane").visible = !button_pressed


func _on_FileDialog2_dir_selected(dir):
	get_node("WiiWheel").image_dir = dir
	get_node("ghost_button").visible = false
	get_node("play_button").visible = false
	get_node("record_button").visible = false
	get_node("transp_button").visible = false
	recording = true
	get_node("WiiWheel").start_record()
	OS.set_window_resizable(false)
	
