extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$Torch/TorchAnimation.play("torch")
	$Torch2/TorchAnimation.play("torch")
	$Torch3/TorchAnimation.play("torch")
