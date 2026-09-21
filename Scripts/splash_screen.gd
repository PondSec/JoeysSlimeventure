extends Control

const MAIN_MENU_SCENE := "res://Scenes/main_menu.tscn"
const DISPLAY_TIME := 2.4
const FADE_TIME := 0.45

var _can_skip := false

func _ready() -> void:
	if "--dedicated-server" in OS.get_cmdline_args() or "--dedicated-server" in OS.get_cmdline_user_args():
		call_deferred("_launch_dedicated_server")
		return
	modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, FADE_TIME).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.35).timeout
	_can_skip = true
	await get_tree().create_timer(DISPLAY_TIME - 0.35).timeout
	_show_main_menu()


func _launch_dedicated_server() -> void:
	get_tree().change_scene_to_file("res://Server/dedicated_server.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if _can_skip and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event is InputEventMouseButton):
		_show_main_menu()

func _show_main_menu() -> void:
	if is_queued_for_deletion():
		return
	_can_skip = false
	set_process_unhandled_input(false)
	var fade_out := create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, FADE_TIME).set_trans(Tween.TRANS_SINE)
	await fade_out.finished
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
