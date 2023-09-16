@tool
extends EditorPlugin

var inspector_plugin_scene = preload("res://addons/levelProgressionEditor/levelProgression_inspector.gd")
var dock_scene = preload("res://addons/levelProgressionEditor/levelProgressionEditor_dock.tscn")

var inspector_plugin
var dock
var toolBtn

var icons

func _enter_tree():
	icons = {}
	var gui = get_editor_interface().get_base_control()
	icons["Add"] = gui.get_theme_icon("Add", "EditorIcons")
	icons["ArrowUp"] = gui.get_theme_icon("ArrowUp", "EditorIcons")
	icons["ArrowDown"] = gui.get_theme_icon("ArrowDown", "EditorIcons")
	icons["Remove"] = gui.get_theme_icon("Remove", "EditorIcons")
	
	inspector_plugin = inspector_plugin_scene.new()
	add_inspector_plugin(inspector_plugin)
	dock = dock_scene.instantiate()
	dock.set_icons(icons)
	inspector_plugin.connect("edit_pressed", dock.select_resource)
	toolBtn = add_control_to_bottom_panel(dock, "Level Progression")


func _exit_tree():
	if inspector_plugin:
		remove_inspector_plugin(inspector_plugin)
	if dock:
		remove_control_from_bottom_panel(dock)
		dock.free()
