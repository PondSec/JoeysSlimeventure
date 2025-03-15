extends ColorRect

func flash() -> void:
	visible = true
	modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)  # Blitzeffekt über 0.1 Sekunden ausblenden
	tween.tween_callback(set.bind("visible", false))
