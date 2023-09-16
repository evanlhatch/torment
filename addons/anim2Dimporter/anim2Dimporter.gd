@tool
extends EditorPlugin

var dock
var file_dialog
var sheet_path = ""
var sheet_normal_path = ""
var sheet_shadow_path = ""
var data_path = ""

func _enter_tree():
	dock = preload("res://addons/anim2Dimporter/anim2Dimporter.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)

	file_dialog = FileDialog.new()
	var editor_interface = get_editor_interface()
	var base_control = editor_interface.get_base_control()
	base_control.add_child(file_dialog)

	dock.get_select_data_btn().connect("pressed", select_data_file)
	dock.get_clear_data_btn().connect("pressed", clear_data_file)
	dock.get_import_btn().connect("pressed", import_animations)

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()
	file_dialog.queue_free()


func select_data_file():
	file_dialog.title = "Select JSON animation data"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.set_filters(PackedStringArray(["*.JSON ; JSON Files"]))
	file_dialog.connect("file_selected", _on_data_selected)
	file_dialog.popup_centered_ratio()


func clear_data_file():
	dock.set_data_name("[MANUAL: select data (JSON)]")	
	data_path = ""
	dock.set_import_button_enabled(false) 

func _on_data_selected(path):
	file_dialog.disconnect("file_selected", _on_data_selected)
	data_path = path
	dock.set_data_name("Set .json: \n" + data_path)
	dock.set_import_button_enabled(true)

func import_animations():
	var data = {}
	var spriteFrames = SpriteFrames.new()
	var sheet_split = []
	
	if FileAccess.file_exists(data_path):
		var data_file = FileAccess.open(data_path, FileAccess.READ)
		var json_obj = JSON.new()
		json_obj.parse(data_file.get_as_text())
		data = json_obj.get_data()
	else:
		printerr("Animation import failed: JSON file not found: '" + data_path + "'")
		return
	
	var sheet_directory = data_path.get_base_dir()

	print(data.keys())
	for sheet in data['output_files']:
		if sheet.get_basename().ends_with("_normal"):
			continue
		sheet = "%s/%s" % [sheet_directory, sheet]
		print(sheet)
		
		var sheet_tres_path = sheet.replace(".png", ".tres")
		var texture : Texture2D
		if FileAccess.file_exists(sheet):
			texture = load(sheet)
		else:
			printerr("Animation import failed: sheet image file not found: '" + sheet + "'")
			return

		var frame_width = data["frame_width"]
		var frame_height = data["frame_height"]
		
		spriteFrames.clear_all()

		for anim_name in data['animations']:
			spriteFrames.add_animation(anim_name)
			spriteFrames.set_animation_speed(anim_name, 15)
			for frame_pos in data['animations'][anim_name]:
				var atlasTex = AtlasTexture.new()
				atlasTex.atlas = texture
				atlasTex.region = Rect2(frame_pos["x"], frame_pos["y"], frame_width, frame_height)
				spriteFrames.add_frame(anim_name, atlasTex)


		if spriteFrames.has_animation("default"):
			spriteFrames.remove_animation("default")
			ResourceSaver.save(spriteFrames, sheet_tres_path)
