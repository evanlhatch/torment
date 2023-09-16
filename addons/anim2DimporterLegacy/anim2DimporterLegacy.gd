@tool
extends EditorPlugin

var dock
var file_dialog
var sheet_path = ""
var data_path = ""

var out_path : String

func _enter_tree():
	dock = preload("res://addons/anim2DimporterLegacy/anim2DimporterLegacy.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)

	file_dialog = FileDialog.new()
	var editor_interface = get_editor_interface()
	var base_control = editor_interface.get_base_control()
	base_control.add_child(file_dialog)
	
	dock.get_select_sheet_btn().connect("pressed", select_sheet_file)
	dock.get_select_data_btn().connect("pressed", select_data_file)
	dock.get_select_out_btn().connect("pressed", select_out_file)
	dock.get_import_btn().connect("pressed", import_animations)

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()
	file_dialog.queue_free()

func select_sheet_file():
	file_dialog.title = "Select PNG animation spritesheet"
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.set_filters(PackedStringArray(["*.png ; PNG Images", "*.jpg ; JPEG Images", "*.bmp ; BMP Images"]))
	file_dialog.connect("file_selected", _on_sheet_selected)
	file_dialog.popup_centered_ratio()

func select_data_file():
	file_dialog.title = "Select JSON animation data"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.set_filters(PackedStringArray(["*.JSON ; JSON Files"]))
	file_dialog.connect("file_selected", _on_data_selected)
	file_dialog.popup_centered_ratio()

func select_out_file():
	file_dialog.title = "Select SpriteFrames output file"
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.set_filters(PackedStringArray(["*.tres ; Resource Files"]))
	file_dialog.connect("file_selected", _on_out_selected)
	file_dialog.popup_centered_ratio()

func _on_sheet_selected(path):
	file_dialog.disconnect("file_selected", _on_sheet_selected)
	sheet_path = path
	dock.set_sheet_name(sheet_path)
	dock.set_import_button_enabled(FileAccess.file_exists(data_path) and FileAccess.file_exists(sheet_path))

func _on_data_selected(path):
	file_dialog.disconnect("file_selected", _on_data_selected)
	data_path = path
	dock.set_data_name(data_path)
	dock.set_import_button_enabled(FileAccess.file_exists(data_path) and FileAccess.file_exists(sheet_path))

func _on_out_selected(path):
	file_dialog.disconnect("file_selected", _on_out_selected)
	out_path = path
	dock.set_out_name(out_path)

func import_animations():
	if out_path == null or len(out_path) == 0 or not out_path.begins_with("res://"):
		printerr("Animation import failed: invalid output path: '" + out_path + "'")
		return
	
	var data = {}
	if FileAccess.file_exists(data_path):
		var data_file = FileAccess.open(data_path, FileAccess.READ)
		var json_obj = JSON.new()
		json_obj.parse(data_file.get_as_text())
		data = json_obj.get_data()
	else:
		printerr("Animation import failed: JSON file not found: '" + data_path + "'")
		return
	
	var texture : Texture2D
	if FileAccess.file_exists(sheet_path):
		texture = load(sheet_path)
	else:
		printerr("Animation import failed: sheet image file not found: '" + sheet_path + "'")
		return
	
	var frame_width = data["frame_width"]
	var frame_height = data["frame_height"]
	var spriteFrames = SpriteFrames.new()
	
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
	ResourceSaver.save(spriteFrames, out_path)
