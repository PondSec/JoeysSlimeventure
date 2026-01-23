extends Control

const LORE_LINES = [
	"Die Luft hier ist warm und leuchtet wie flüssiges Sternenlicht.",
	"Ich höre das Echo meines alten Namens... und den Ruf der Lumora.",
	"Sie waren nie nur Lichtwesen. Sie sind Erinnerungen der Welt.",
	"Der Schatten, der mich verschlang, wollte diese Erinnerungen brechen.",
	"Doch in mir ist jetzt ein Kern aus reinem Glanz.",
	"Ich war ein Mensch... und ich bin jetzt mehr als das.",
	"Wenn ich dieses Herz berühre, kehrt der Fluss zurück.",
	"Die Höhlen werden wieder atmen. Die Wälder werden wieder singen.",
	"Und ich... werde Joey bleiben, egal welche Form ich trage."
]

var current_line := 0
var ending_unlocked := false

@onready var story_text: Label = $CanvasLayer/TextPanel/MarginContainer/StoryText
@onready var continue_hint: Label = $CanvasLayer/TextPanel/ContinueHint
@onready var credits_button: Button = $CanvasLayer/EndButtons/ToCreditsButton
@onready var menu_button: Button = $CanvasLayer/EndButtons/ToMenuButton

func _ready() -> void:
	update_line()
	credits_button.hide()
	menu_button.hide()

func _unhandled_input(event: InputEvent) -> void:
	if ending_unlocked:
		return
	if event.is_action_pressed("Interact") or event.is_action_pressed("ui_accept"):
		advance_story()

func advance_story() -> void:
	if current_line < LORE_LINES.size() - 1:
		current_line += 1
		update_line()
	else:
		unlock_ending()

func update_line() -> void:
	story_text.text = LORE_LINES[current_line]
	continue_hint.text = "[E] Weiter"

func unlock_ending() -> void:
	ending_unlocked = true
	continue_hint.text = "Danke fürs Spielen!"
	credits_button.show()
	menu_button.show()

func _on_to_credits_button_pressed() -> void:
	change_scene("res://Scenes/credits.tscn")

func _on_to_menu_button_pressed() -> void:
	change_scene("res://Scenes/main_menu.tscn")

func change_scene(scene_path: String) -> void:
	var target_scene = load(scene_path)
	if target_scene == null:
		push_error("Szene konnte nicht geladen werden: %s" % scene_path)
		return
	var scene_instance = target_scene.instantiate()
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.queue_free()
	get_tree().root.add_child(scene_instance)
	get_tree().current_scene = scene_instance
