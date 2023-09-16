@tool
extends Control

var time_scale_scene = preload("res://addons/levelProgressionEditor/TimeScale.tscn")
var entry_lane_scene = preload("res://addons/levelProgressionEditor/ProgressionLane.tscn")

var selected_resource : LevelProgression
var selected_entry : LevelProgressionSpawnEntry
var scene_picker : EditorResourcePicker

var lanes = []


func _enter_tree():
	lanes = []
	$V/H_Top/AddButton.pressed.connect(_on_add_pressed)
	$V/H_Top/UpButton.pressed.connect(_on_up_pressed)
	$V/H_Top/DownButton.pressed.connect(_on_down_pressed)
	$V/H_Top/DeleteButton.pressed.connect(_on_delete_pressed)
	
	$V/H/Scroll/EntryInspector/ColorPickerButton.color_changed.connect(_on_color_selected)
	
	$V/H/Scroll/EntryInspector/Name.text_submitted.connect(_on_name_submitted)
	$V/H/Scroll/EntryInspector/Name.focus_exited.connect(_on_name_submitted.bind(""))
	$V/H/Scroll/EntryInspector/Start.text_submitted.connect(_on_start_submitted)
	$V/H/Scroll/EntryInspector/Start.focus_exited.connect(_on_start_submitted.bind(""))
	
	$V/H/Scroll/EntryInspector/End.text_submitted.connect(_on_end_submitted)
	$V/H/Scroll/EntryInspector/End.focus_exited.connect(_on_end_submitted.bind(""))
	
	$V/H/Scroll/EntryInspector/CountTarget/Input.text_submitted.connect(_on_count_target_submitted)
	$V/H/Scroll/EntryInspector/CountTarget/Input.focus_exited.connect(_on_count_target_submitted.bind(""))
	
	$V/H/Scroll/EntryInspector/CountTarget/ApplyTormentCheckBox.toggled.connect(_on_count_target_torment_toggled)
	
	$V/H/Scroll/EntryInspector/SpawnInterval/Input.text_submitted.connect(_on_spawn_interval_submitted)
	$V/H/Scroll/EntryInspector/SpawnInterval/Input.focus_exited.connect(_on_spawn_interval_submitted.bind(""))
	
	$V/H/Scroll/EntryInspector/SpawnInterval/ApplyTormentCheckBox.toggled.connect(_on_spawn_interval_torment_toggled)
	
	$V/H/Scroll/EntryInspector/SpawnCount/Input.text_submitted.connect(_on_spawn_count_submitted)
	$V/H/Scroll/EntryInspector/SpawnCount/Input.focus_exited.connect(_on_spawn_count_submitted.bind(""))
	
	$V/H/Scroll/EntryInspector/SpawnCount/ApplyTormentCheckBox.toggled.connect(_on_spawn_count_torment_toggled)
	
	$V/H/Scroll/EntryInspector/DisposableCheckBox.toggled.connect(_on_disposable_toggled)
	$V/H/Scroll/EntryInspector/DestroyOnTargetCheckBox.toggled.connect(_on_destroy_toggled)
	
	$V/H/Scroll/EntryInspector/MinRank.text_submitted.connect(_on_minrank_submitted)
	$V/H/Scroll/EntryInspector/MinRank.focus_exited.connect(_on_minrank_submitted.bind(""))
	$V/H/Scroll/EntryInspector/MaxRank.text_submitted.connect(_on_maxrank_submitted)
	$V/H/Scroll/EntryInspector/MaxRank.focus_exited.connect(_on_maxrank_submitted.bind(""))
	
	$V/H/Scroll/EntryInspector/Flags/flag_N.toggled.connect(_on_flag_toggled)
	$V/H/Scroll/EntryInspector/Flags/flag_S.toggled.connect(_on_flag_toggled)
	$V/H/Scroll/EntryInspector/Flags/flag_E.toggled.connect(_on_flag_toggled)
	$V/H/Scroll/EntryInspector/Flags/flag_W.toggled.connect(_on_flag_toggled)
	
	scene_picker = EditorResourcePicker.new()
	scene_picker.base_type = "PackedScene"
	scene_picker.connect("resource_changed", _on_scene_picked)
	$V/H/Scroll/EntryInspector/SpawnedScene/V.add_child(scene_picker)
	
	for t in 30:
		var s = time_scale_scene.instantiate()
		$V/H/TimelineArea/Timeline/Header.add_child(s)
		s.text = "%d:00" % (30 - t)
	select_resource(null)

func _exit_tree():
	pass

func set_icons(icons):
	$V/H_Top/AddButton.icon = icons["Add"]
	$V/H_Top/UpButton.icon = icons["ArrowUp"]
	$V/H_Top/DownButton.icon = icons["ArrowDown"]
	$V/H_Top/DeleteButton.icon = icons["Remove"]


func select_resource(resource_object : LevelProgression):
	if selected_resource and selected_resource.has_signal("changed"):
		selected_resource.disconnect("changed", _on_selected_resource_changed)
		
	selected_resource = resource_object
	if selected_resource:
		selected_resource.connect("changed", _on_selected_resource_changed)
		$V/H.visible = true
		$V/H_Top/ResourcePath.text = selected_resource.resource_path
		update_displayed_resource_data()
	else:
		$V/H.visible = false
		$V/H_Top/ResourcePath.text = "no resource selected"


func select_entry(resource_object : Resource):
	for l in lanes:
		if l.data != resource_object:
			l.deselect()
		else:
			l.select()
	
	apply_all_string_changes()
	
	selected_entry = resource_object
	if selected_entry:
		if not selected_entry.is_connected("changed", _on_selected_entry_changed):
			selected_entry.connect("changed", _on_selected_entry_changed)
		$V/H/Scroll/EntryInspector.visible = true
		$V/H/no_selection.visible = false
		update_displayed_entry_data()
	else:
		$V/H/Scroll/EntryInspector.visible = false
		$V/H/no_selection.visible = true
		$V/H_Top/ResourcePath.text = "no resource selected"


func update_entry(resource_entry : Resource):
	resource_entry.emit_changed()

func update_displayed_resource_data():
	for l in lanes:
		l.queue_free()
	lanes.clear()
	
	if selected_resource:
		for e in selected_resource.Entries:
			var lane = entry_lane_scene.instantiate()
			lanes.append(lane)
			$V/H/TimelineArea/Timeline.add_child(lane)
			lane.set_data(e)
			lane.connect("EntrySelected", select_entry)
			lane.connect("EntryRangeChanged", update_entry)
	if selected_entry:
		select_entry(selected_entry)


func update_displayed_entry_data():
	if selected_entry:
		$V/H/Scroll/EntryInspector/ColorPickerButton.color = selected_entry.EntryColor
		$V/H/Scroll/EntryInspector/Name.text = selected_entry.Name
		$V/H/Scroll/EntryInspector/Start.text = str(selected_entry.Start)
		$V/H/Scroll/EntryInspector/End.text = str(selected_entry.End)
		$V/H/Scroll/EntryInspector/EndLabel/LengthLabel.text = "(%d)" % (selected_entry.Start - selected_entry.End)
		scene_picker.edited_resource = selected_entry.SpawnedScene
		$V/H/Scroll/EntryInspector/SpawnInterval/Input.text = str(selected_entry.SpawnInterval)		
		$V/H/Scroll/EntryInspector/SpawnInterval/ApplyTormentCheckBox.button_pressed = selected_entry.ApplyTormentToSpawnInterval
		$V/H/Scroll/EntryInspector/SpawnCount/Input.text = str(selected_entry.SpawnsPerInterval)
		$V/H/Scroll/EntryInspector/SpawnCount/ApplyTormentCheckBox.button_pressed = selected_entry.ApplyTormentToSpawnsPerInterval
		$V/H/Scroll/EntryInspector/CountTarget/Input.text = str(selected_entry.CountTarget)
		$V/H/Scroll/EntryInspector/CountTarget/ApplyTormentCheckBox.button_pressed = selected_entry.ApplyTormentToCountTarget
		$V/H/Scroll/EntryInspector/DisposableCheckBox.button_pressed = selected_entry.DisposableOnExit
		$V/H/Scroll/EntryInspector/DestroyOnTargetCheckBox.button_pressed = selected_entry.DestroyOnTargetCount
		$V/H/Scroll/EntryInspector/MinRank.text = str(selected_entry.MinRank)
		$V/H/Scroll/EntryInspector/MaxRank.text = str(selected_entry.MaxRank)
		$V/H/Scroll/EntryInspector/Flags/flag_N.button_pressed = (selected_entry.SpawnFlags & 0b0001) > 0
		$V/H/Scroll/EntryInspector/Flags/flag_S.button_pressed = (selected_entry.SpawnFlags & 0b0010) > 0
		$V/H/Scroll/EntryInspector/Flags/flag_E.button_pressed = (selected_entry.SpawnFlags & 0b0100) > 0
		$V/H/Scroll/EntryInspector/Flags/flag_W.button_pressed = (selected_entry.SpawnFlags & 0b1000) > 0
		for l in lanes:
			if l.data == selected_entry:
				l.update_display()
				break


func _on_add_pressed():
	if selected_resource:
		var entry = LevelProgressionSpawnEntry.new()
		selected_resource.Entries.append(entry)
		selected_resource.emit_changed()


func _on_up_pressed():
	if selected_resource and selected_entry:
		var index = selected_resource.Entries.find(selected_entry)
		if index > 0:
			selected_resource.Entries.remove_at(index)
			selected_resource.Entries.insert(index - 1, selected_entry)
			update_displayed_resource_data()


func _on_down_pressed():
	if selected_resource and selected_entry:
		var index = selected_resource.Entries.find(selected_entry)
		if index >= 0 and index < len(selected_resource.Entries) - 1:
			selected_resource.Entries.remove_at(index)
			selected_resource.Entries.insert(index + 1, selected_entry)
			update_displayed_resource_data()


func _on_delete_pressed():
	if selected_resource and selected_entry:
		selected_resource.Entries.erase(selected_entry)
		selected_resource.emit_changed()


func _on_selected_resource_changed():
	update_displayed_resource_data()

func _on_selected_entry_changed():
	update_displayed_entry_data()


#-------------------------------------------------------------------------------#
#							ENTRY EDITING CALLBACKS								#
#-------------------------------------------------------------------------------#
func _on_name_submitted(_string_param):
	if selected_entry:
		selected_entry.Name = $V/H/Scroll/EntryInspector/Name.text
		selected_entry.emit_changed()
		
func _on_start_submitted(_string_param):
	if selected_entry:
		selected_entry.Start = clamp($V/H/Scroll/EntryInspector/Start.text.to_float(), 1, 1800)
		selected_entry.emit_changed()

func _on_end_submitted(string_param):
	if selected_entry:
		if string_param.is_empty():
			selected_entry.End = clamp($V/H/Scroll/EntryInspector/End.text.to_float(), 1, selected_entry.Start + 1)
		else:
			selected_entry.End = clamp(string_param.to_float(), 1, selected_entry.Start + 1) 
		selected_entry.emit_changed()

func _on_scene_picked(scene : PackedScene):
	if selected_entry:
		selected_entry.SpawnedScene = scene
		selected_entry.emit_changed()

func _on_count_target_submitted(string_param):
	if selected_entry:
		if string_param.is_empty():
			selected_entry.CountTarget = clamp($V/H/Scroll/EntryInspector/CountTarget/Input.text.to_int(), 0, 1024)
		else:
			selected_entry.CountTarget = clamp(string_param.to_int(), 0, 1024)
		selected_entry.emit_changed()

func _on_count_target_torment_toggled(button_pressed : bool):
	if selected_entry:
		selected_entry.ApplyTormentToCountTarget = button_pressed
		selected_entry.emit_changed()

func _on_spawn_interval_submitted(_string_param):
	if selected_entry:
		selected_entry.SpawnInterval = $V/H/Scroll/EntryInspector/SpawnInterval/Input.text.to_float()
		selected_entry.emit_changed()

func _on_spawn_interval_torment_toggled(button_pressed : bool):
	if selected_entry:
		selected_entry.ApplyTormentToSpawnInterval = button_pressed
		selected_entry.emit_changed()

func _on_spawn_count_submitted(_string_param):
	if selected_entry:
		selected_entry.SpawnsPerInterval = clamp($V/H/Scroll/EntryInspector/SpawnCount/Input.text.to_int(), 0, 1024)
		selected_entry.emit_changed()

func _on_spawn_count_torment_toggled(button_pressed : bool):
	if selected_entry:
		selected_entry.ApplyTormentToSpawnsPerInterval = button_pressed
		selected_entry.emit_changed()

func _on_color_selected(color : Color):
	if selected_entry:
		selected_entry.EntryColor = color
		selected_entry.emit_changed()

func _on_disposable_toggled(button_pressed : bool):
	if selected_entry:
		selected_entry.DisposableOnExit = button_pressed
		selected_entry.emit_changed()

func _on_destroy_toggled(button_pressed : bool):
	if selected_entry:
		selected_entry.DestroyOnTargetCount = button_pressed
		selected_entry.emit_changed()
		
func _on_minrank_submitted(_string_param):
	if selected_entry:
		selected_entry.MinRank = clamp($V/H/Scroll/EntryInspector/MinRank.text.to_int(), 0, 5)
		selected_entry.emit_changed()

func _on_maxrank_submitted(_string_param):
	if selected_entry:
		selected_entry.MaxRank = clamp($V/H/Scroll/EntryInspector/MaxRank.text.to_int(), 0, 5) 
		selected_entry.emit_changed()
		
func _on_flag_toggled(_button_pressed : bool):
	if selected_entry:
		var flags : int = 0
		if $V/H/Scroll/EntryInspector/Flags/flag_N.button_pressed: flags |= 0b0001
		if $V/H/Scroll/EntryInspector/Flags/flag_S.button_pressed: flags |= 0b0010
		if $V/H/Scroll/EntryInspector/Flags/flag_E.button_pressed: flags |= 0b0100
		if $V/H/Scroll/EntryInspector/Flags/flag_W.button_pressed: flags |= 0b1000
		selected_entry.SpawnFlags = flags

func apply_all_string_changes():
	_on_name_submitted("")
	_on_start_submitted("")
	_on_end_submitted("")
	_on_count_target_submitted("")
	_on_spawn_interval_submitted("")
	_on_spawn_count_submitted("")
	_on_minrank_submitted("")
	_on_maxrank_submitted("")
