extends PointLight2D

@export var Speed : float = 200
@export var Amplitude : float = 0.8
# when seed is 0, it will be seeded randomly on start!
@export var Seed : int = 0

var _noise : FastNoiseLite

var _currentFlickerProgress : float = 0
var _maxEnergy : float = 1
var _minEnergy : float = 0.5
var _maxHeight : float = 50
var _minHeight : float = 25

func _ready():
	_maxEnergy = energy
	_minEnergy = energy - energy * Amplitude
	_maxHeight = height
	_minHeight = height - height * Amplitude 
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_VALUE
	if Seed == 0:
		_noise.seed = randi_range(0, 999999)
	else:
		_noise.seed = Seed


func _process(delta):
#ifdef PROFILING
#	updateFlickeringLight(delta)
#
#func updateFlickeringLight(delta):
#endif
	_currentFlickerProgress += delta * Speed
	var currentFactor : float = 0.5 + 0.5 * _noise.get_noise_1d(_currentFlickerProgress)

	energy = lerpf(_minEnergy, _maxEnergy, currentFactor)
	height = lerpf(_minHeight, _maxHeight, currentFactor)
