extends PointLight2D

@export var IsPlayerLight : bool = false

var colorTween
var scaleTween

var defaultScale : float

var defaultColor : Color
var colorFade : float


func _ready():
	var gameObject = Global.get_gameObject_in_parents(self)
	gameObject.connectToSignal("ReceivedDamage", _on_damage_received)
	defaultScale = texture_scale
	defaultColor = color

	if IsPlayerLight:
		if not Global.is_world_ready(): await Global.WorldReady
		energy = Global.World.PlayerLightEnergy


func _on_damage_received(_damageAmount:int, _soruce:Node, _weapon_index:int):
	texture_scale = clamp(texture_scale - 0.3, 0.5, defaultScale)
	colorFade = clamp(colorFade + 0.3, 0.0, 1.0)
	color = defaultColor.lerp(Color.RED, colorFade)

func _process(delta):
	if texture_scale < defaultScale:
		texture_scale = clamp(texture_scale + delta, 0.5, defaultScale)
	if colorFade > 0:
		colorFade = clamp(colorFade - delta, 0.0, 1.0)
		color = defaultColor.lerp(Color.RED, colorFade)
