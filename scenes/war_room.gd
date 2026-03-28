extends Control
## ═══════════════════════════════════════════════════════════════
## غرفة العمليات — نشر القوات وإعداد المعركة
## ═══════════════════════════════════════════════════════════════

@onready var power_label: Label = $TopPanel/PowerBox/PowerVal
@onready var terrain_label: Label = $TopPanel/TerrainBox/TerrainVal
@onready var weather_label: Label = $TopPanel/WeatherBox/WeatherVal
@onready var morale_label: Label = $TopPanel/MoraleBox/MoraleVal
@onready var troop_panel: PanelContainer = $TroopSelector
@onready var waves_container: VBoxContainer = $ScrollContainer/WavesContainer
@onready var attack_btn: Button = $AttackBtn

func _ready() -> void:
	_refresh_ui()
	game_manager.resources_changed.connect(_refresh_ui)
	game_manager.troops_changed.connect(_refresh_ui)
	attack_btn.pressed.connect(_on_attack)

func _refresh_ui() -> void:
	power_label.text = str(game_manager.get_deployed_power())
	terrain_label.text = game_manager.terrain_names[game_manager.selected_terrain]
	weather_label.text = game_manager.weather_names[game_manager.current_weather]
	morale_label.text = "%d%%" % int(game_manager.player_morale)
	# تحديث الأزرار
	for btn in troop_panel.get_children():
		if btn is Button:
			var ttype: int = btn.get_meta("troop_type", -1)
			if ttype >= 0:
				var count: int = game_manager.get_total_troops_by_type(ttype)
				btn.text = "%s %s (%d)" % [game_manager.troop_icons[ttype], game_manager.troop_names[ttype], count]
	# تحديث الموجات
	_refresh_waves()

func _refresh_waves() -> void:
	for child in waves_container.get_children():
		child.queue_free()
	for wave_idx in range(3):
		var wave_box = _create_wave_box(wave_idx)
		waves_container.add_child(wave_box)

func _create_wave_box(wave_idx: int) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.16, 0.8)
	style.border_color = Color(0.2, 0.2, 0.3, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	# عنوان الموجة
	var title = Label.new()
	title.text = "الموجة %d" % (wave_idx + 1)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.788, 0.635, 0.153, 1))
	vbox.add_child(title)
	# خانتان
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	for slot_idx in range(2):
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(170, 50)
		var slot_data: Dictionary = game_manager.deployment[wave_idx][slot_idx]
		if slot_data["type"] >= 0:
			slot_btn.text = "%s %s x%d" % [game_manager.troop_icons[slot_data["type"]], game_manager.troop_names[slot_data["type"]], slot_data["count"]]
		else:
			slot_btn.text = "— فارغ —"
			slot_btn.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.08, 0.12, 0.22, 0.8)
		btn_style.border_color = Color(0.3, 0.3, 0.4, 0.5)
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(6)
		slot_btn.add_theme_stylebox_override("normal", btn_style)
		slot_btn.add_theme_font_size_override("font_size", 12)
		hbox.add_child(slot_btn)
	vbox.add_child(hbox)
	panel.add_child(vbox)
	return panel

func _on_troop_selected(troop_type: int) -> void:
	# تعبئة أول خانة فارغة
	for w in range(3):
		for s in range(2):
			var slot: Dictionary = game_manager.deployment[w][s]
			if slot["type"] == -1 or slot["type"] == troop_type:
				game_manager.assign_to_slot(w, s, troop_type)
				_refresh_ui()
				return

func _on_terrain_next() -> void:
	game_manager.selected_terrain = (game_manager.selected_terrain + 1) % 5
	_refresh_ui()

func _on_weather_next() -> void:
	game_manager.current_weather = (game_manager.current_weather + 1) % 6
	_refresh_ui()

func _on_clear_deployment() -> void:
	game_manager.clear_deployment()
	_refresh_ui()

func _on_attack() -> void:
	if game_manager.get_deployed_count() == 0:
		attack_btn.text = "❌ نشر القوات أولاً!"
		await get_tree().create_timer(1.5).timeout
		attack_btn.text = "⚔️ هجوم!"
		return
	attack_btn.text = "⚔️ جاري الهجوم..."
	# تبدأ المعركة من الخريطة (سنستخدم بيانات افتراضية)
	var enemy_power = 200 + randi() % 300
	game_manager.start_battle(enemy_power, "قطاع أمامي")
