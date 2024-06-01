extends TextureRect

var _tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready():
	_tween = Tween.new()
	_rotate()

func _rotate():
	_tween.interpolate_property(
		self,
		"rotation",
		self.rotation,
		self.rotation + 45,
		3,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)
	_tween.start()
	await(_tween)
	_rotate()
