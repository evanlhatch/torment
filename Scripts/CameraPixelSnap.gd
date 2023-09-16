extends Camera2D

var snap_to_pixels : bool

func _ready():
	snap_to_pixels = Global.CurrentSettings["low_res"]
	Global.SettingsApplied.connect(_on_settings_applied)

func _on_settings_applied(setting_key:String):
	if setting_key.is_empty() or setting_key == "low_res":
		snap_to_pixels = Global.CurrentSettings["low_res"]

# as a test the snapping is now handled via get_viewport().snap_2d_transforms_to_pixel.
# when that feels good, we can remove this component.
#func _process(_delta):
#	if snap_to_pixels:
#		position = Vector2.ZERO
#		global_position = Vector2(
#			floori(global_position.x),
#			floori(global_position.y))
