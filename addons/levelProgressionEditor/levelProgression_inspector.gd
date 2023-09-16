@tool
extends EditorInspectorPlugin

var selectedObj = null
signal edit_pressed(object)


func _can_handle(object):
	return object is LevelProgression


func _parse_begin(object):
	var edit_btn = Button.new()
	edit_btn.text = "EDIT"
	add_custom_control(edit_btn)
	edit_btn.connect("pressed", _on_edit_pressed)
	selectedObj = object


func _on_edit_pressed():
	if selectedObj:
		emit_signal("edit_pressed", selectedObj)
