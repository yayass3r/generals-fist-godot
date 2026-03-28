extends Control
## Main Menu Scene Controller

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var version_label: Label = $VersionLabel

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	start_button.grab_focus()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_root.tscn")
