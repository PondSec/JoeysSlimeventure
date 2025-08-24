extends Control

func _ready() -> void:
	$AnimationPlayer.play("ScrollAnimation")
	$AnimationPlayer.animation_finished.connect(_on_animation_finished)

func _on_texture_button_pressed() -> void:
	var main_scene = load("res://Scenes/main_menu.tscn")
	
	if main_scene == null:
		print("Fehler: Die Hauptmenü-Szene konnte nicht geladen werden.")
		return  

	var current_scene = get_tree().current_scene  
	if current_scene != null:
		current_scene.queue_free()  

	var scene_instance = main_scene.instantiate()  

	get_tree().root.add_child(scene_instance)  
	get_tree().current_scene = scene_instance  

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "ScrollAnimation":
		_on_texture_button_pressed()
