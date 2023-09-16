@tool
extends Control

var data : LevelProgressionSpawnEntry

signal EntrySelected(entry)
signal EntryRangeChanged(entry)

func _enter_tree():
	connect("gui_input", _on_gui_input)
	$bar.connect("Selected", _on_selected)
	$bar.connect("bar_moved", _on_moved)
	$bar.connect("left_moved", _on_moved_left)
	$bar.connect("right_moved", _on_moved_right)

func _on_gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			$bar.set_selected()

func _on_selected():
	$Background.modulate = Color.WHITE
	emit_signal("EntrySelected", data)

func _on_moved(pos_x):
	var length = data.Start - data.End
	data.Start = clamp(1800 - pos_x, length + 1, 1800)
	data.End = clamp(data.Start - length, 1, 1800)
	emit_signal("EntryRangeChanged", data)

func _on_moved_left(pos_x):
	data.Start = clamp(1800 - pos_x, data.End + 1, 1800)
	emit_signal("EntryRangeChanged", data)

func _on_moved_right(pos_x):
	var length = data.Start - data.End
	data.End = clamp(1800 - pos_x, 1, data.Start - 1)
	emit_signal("EntryRangeChanged", data)

func deselect():
	$Background.modulate = Color(0.5, 0.5, 0.5, 1.0)
	$bar.set_deselected()

func select():
	$Background.modulate = Color.WHITE
	$bar.set_selected(false)

func set_data(resource:LevelProgressionSpawnEntry):
	if not (resource is Resource):
		printerr("Selected resource is not a LevelProgressionSpawnEntry!")
		return
	if data:
		data.disconnect("changed", update_display)
	data = resource
	data.connect("changed", update_display)
	update_display()


func set_laneName(name:String):
	for l in $NameOverlay.get_children():
		l.text = name


func get_laneName()->String:
	return $NameOverlay.get_child(0).text


func update_display():
	update_display_start()
	update_display_end()
	update_display_name()
	update_entry_color()


func update_display_start():
	$bar.position.x = 1800 - data.Start
	
func update_display_end():
	$bar.size.x = data.Start - data.End

func update_display_name():
	if !data:
		set_laneName("#ERROR#")
		return
	set_laneName(data.Name)

func update_entry_color():
	if !data:
		$bar.set_color(Color("#db8b00"))
		return
	$bar.set_color(data.EntryColor)
