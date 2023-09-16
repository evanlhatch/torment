@tool
extends ColorRect

var drag_mouse_pos = null
var drag_rect_pos = null

var selected : bool
var bar_color : Color
var bar_color_selected : Color

signal bar_moved(pos_x)
signal left_moved(pos_x)
signal right_moved(pos_x)
signal Selected

func _enter_tree():
	connect("gui_input", _on_gui_input)
	$left.connect("gui_input", _on_gui_input_left)
	$right.connect("gui_input", _on_gui_input_right)

func _on_gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# start dragging
			drag_mouse_pos = get_global_mouse_position()
			drag_rect_pos = position
			set_selected()
		else:
			# stop dragging
			drag_mouse_pos = null
	if event is InputEventMouseMotion and drag_mouse_pos:
		var delta_x = (get_global_mouse_position() - drag_mouse_pos).x
		emit_signal("bar_moved", drag_rect_pos.x + delta_x)

func _on_gui_input_left(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# start dragging
			drag_mouse_pos = get_global_mouse_position()
			drag_rect_pos = position
			set_selected()
		else:
			# stop dragging
			drag_mouse_pos = null
	if event is InputEventMouseMotion and drag_mouse_pos:
		var delta_x = (get_global_mouse_position() - drag_mouse_pos).x
		emit_signal("left_moved", drag_rect_pos.x + delta_x)

func _on_gui_input_right(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# start dragging
			drag_mouse_pos = get_global_mouse_position()
			drag_rect_pos = position + size
			set_selected()
		else:
			# stop dragging
			drag_mouse_pos = null
	if event is InputEventMouseMotion and drag_mouse_pos:
		var delta_x = (get_global_mouse_position() - drag_mouse_pos).x
		emit_signal("right_moved", drag_rect_pos.x + delta_x)

func set_selected(do_emit_signal:bool = true):
	color = bar_color_selected
	selected = true
	if do_emit_signal:
		emit_signal("Selected")

func set_deselected():
	color = bar_color
	selected = false

func set_color(color : Color):
	bar_color = color
	bar_color_selected = bar_color
	bar_color_selected.v += 0.3
