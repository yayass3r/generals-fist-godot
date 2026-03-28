extends Control
## ═══════════════════════════════════════════════════════════════
## مشهد القائمة الرئيسية — قبضة الجنرال
## ═══════════════════════════════════════════════════════════════

@onready var logo: TextureRect = $VBoxContainer/Logo
@onready var start_btn: Button = $VBoxContainer/StartBtn
@onready var title_label: Label = $VBoxContainer/Title
@onready var subtitle_label: Label = $VBoxContainer/Subtitle
@onready var version_label: Label = $VBoxContainer/Version
@onready var bg_anim: AnimationPlayer = $BgAnim

func _ready() -> void:
	# تحريك الظهور
	if bg_anim:
		bg_anim.play("fade_in")
	start_btn.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	# تأثير عند الضغط
	start_btn.modulate.a = 0.5
	await get_tree().create_timer(0.15).timeout
	start_btn.modulate.a = 1.0
	# الانتقال للعبة
	get_tree().change_scene_to_file("res://scenes/game_root.tscn")
