extends PanelContainer
## ═══════════════════════════════════════════════════════════════
## شاشة الإعدادات — قبضة الجنرال
## ═══════════════════════════════════════════════════════════════

const COLOR_GOLD := Color(0.788, 0.635, 0.153, 1.0)
const COLOR_DARK_PANEL := Color(0.05, 0.08, 0.16, 0.9)
const COLOR_RED := Color(0.937, 0.267, 0.267, 1.0)

func _ready() -> void:
	_build_ui()
	game_manager.settings_changed.connect(_refresh)
	_refresh()

func _build_ui() -> void:
	# نمط اللوحة
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.12, 0.97)
	style.border_color = COLOR_GOLD
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	# تحديد الأنكور
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -160
	offset_top = -200
	offset_right = 160
	offset_bottom = 200
	z_index = 200

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# عنوان + زر إغلاق
	var title_hbox := HBoxContainer.new()
	main_vbox.add_child(title_hbox)

	var title := Label.new()
	title.text = "⚙️ الإعدادات"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.15, 0.15, 0.2, 0.5)
	close_style.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.pressed.connect(func(): visible = false)
	title_hbox.add_child(close_btn)

	# فاصل
	var sep1 := HSeparator.new()
	main_vbox.add_child(sep1)

	# ─── الإعدادات ───
	var settings_label := Label.new()
	settings_label.text = "── تفضيلات ──"
	settings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_label.add_theme_font_size_override("font_size", 13)
	settings_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	main_vbox.add_child(settings_label)

	# زر المؤثرات الصوتية
	var sound_btn := Button.new()
	sound_btn.name = "SoundBtn"
	sound_btn.text = "🔊 المؤثرات الصوتية: مفعّل"
	sound_btn.custom_minimum_size = Vector2(0, 36)
	sound_btn.add_theme_font_size_override("font_size", 12)
	sound_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	var sound_style := StyleBoxFlat.new()
	sound_style.bg_color = Color(0.08, 0.1, 0.18, 0.9)
	sound_style.set_corner_radius_all(6)
	sound_btn.add_theme_stylebox_override("normal", sound_style)
	sound_btn.pressed.connect(_toggle_sound)
	main_vbox.add_child(sound_btn)

	# زر الإشعارات
	var notif_btn := Button.new()
	notif_btn.name = "NotifBtn"
	notif_btn.text = "📢 الإشعارات: مفعّل"
	notif_btn.custom_minimum_size = Vector2(0, 36)
	notif_btn.add_theme_font_size_override("font_size", 12)
	notif_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	notif_btn.add_theme_stylebox_override("normal", sound_style.duplicate())
	notif_btn.pressed.connect(_toggle_notifications)
	main_vbox.add_child(notif_btn)

	# زر الحفظ التلقائي
	var autosave_btn := Button.new()
	autosave_btn.name = "AutoSaveBtn"
	autosave_btn.text = "💾 الحفظ التلقائي: مفعّل"
	autosave_btn.custom_minimum_size = Vector2(0, 36)
	autosave_btn.add_theme_font_size_override("font_size", 12)
	autosave_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	autosave_btn.add_theme_stylebox_override("normal", sound_style.duplicate())
	autosave_btn.pressed.connect(_toggle_autosave)
	main_vbox.add_child(autosave_btn)

	# فاصل
	var sep2 := HSeparator.new()
	main_vbox.add_child(sep2)

	# ─── الإحصائيات ───
	var stats_label := Label.new()
	stats_label.text = "── الإحصائيات ──"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	main_vbox.add_child(stats_label)

	var stats_text := RichTextLabel.new()
	stats_text.name = "StatsText"
	stats_text.add_theme_font_size_override("normal_font_size", 11)
	stats_text.add_theme_color_override("default_color", Color(0.7, 0.75, 0.8, 1))
	stats_text.fit_content = true
	stats_text.custom_minimum_size = Vector2(0, 100)
	main_vbox.add_child(stats_text)

	# فاصل
	var sep3 := HSeparator.new()
	main_vbox.add_child(sep3)

	# زر إعادة تعيين
	var reset_btn := Button.new()
	reset_btn.text = "🗑️ إعادة تعيين اللعبة"
	reset_btn.custom_minimum_size = Vector2(0, 36)
	reset_btn.add_theme_font_size_override("font_size", 12)
	reset_btn.add_theme_color_override("font_color", COLOR_RED)
	var reset_style := StyleBoxFlat.new()
	reset_style.bg_color = Color(0.15, 0.05, 0.05, 0.9)
	reset_style.set_corner_radius_all(6)
	reset_btn.add_theme_stylebox_override("normal", reset_style)
	reset_btn.pressed.connect(_on_reset_pressed)
	main_vbox.add_child(reset_btn)

func _refresh() -> void:
	var sound_btn := get_node_or_null("SoundBtn")
	if sound_btn:
		var enabled: bool = game_manager.settings.get("sound_enabled", true)
		sound_btn.text = "🔊 المؤثرات الصوتية: %s" % ("مفعّل" if enabled else "معطّل")

	var notif_btn := get_node_or_null("NotifBtn")
	if notif_btn:
		var enabled: bool = game_manager.settings.get("notifications_enabled", true)
		notif_btn.text = "📢 الإشعارات: %s" % ("مفعّل" if enabled else "معطّل")

	var autosave_btn := get_node_or_null("AutoSaveBtn")
	if autosave_btn:
		var enabled: bool = game_manager.settings.get("auto_save_enabled", true)
		autosave_btn.text = "💾 الحفظ التلقائي: %s" % ("مفعّل" if enabled else "معطّل")

	# تحديث الإحصائيات
	var stats := get_node_or_null("StatsText")
	if stats:
		var mins: int = int(game_manager.total_play_time) / 60
		var hours: int = mins / 60
		mins = mins % 60
		stats.text = "[center]⚔️ معارك فائزة: %d  |  💔 معارك خاسرة: %d[/center]\n"
		stats.text += "[center]🔥 سلسلة انتصارات: %d  |  🚛 قوافل: %d[/center]\n"
		stats.text += "[center]⭐ مستوى: %d  |  ⏱️ وقت اللعب: %d:%02d[/center]\n"
		stats.text += "[center]⚙️ إجمالي خردة: %d  |  ⛽ إجمالي وقود: %d[/center]"
		stats.text = stats.text % [
			game_manager.total_battles_won,
			game_manager.total_battles_lost,
			game_manager.consecutive_wins,
			game_manager.completed_convoys_count,
			game_manager.player_level,
			hours, mins,
			game_manager.total_scrap_earned,
			game_manager.total_fuel_earned,
		]
		stats.fit_content = true

func _toggle_sound() -> void:
	game_manager.settings["sound_enabled"] = not game_manager.settings.get("sound_enabled", true)
	game_manager.settings_changed.emit()
	game_manager.save_game()
	_refresh()

func _toggle_notifications() -> void:
	game_manager.settings["notifications_enabled"] = not game_manager.settings.get("notifications_enabled", true)
	game_manager.settings_changed.emit()
	game_manager.save_game()
	_refresh()

func _toggle_autosave() -> void:
	game_manager.settings["auto_save_enabled"] = not game_manager.settings.get("auto_save_enabled", true)
	game_manager.settings_changed.emit()
	game_manager.save_game()
	_refresh()

func _on_reset_pressed() -> void:
	_show_confirmation()

func _show_confirmation() -> void:
	# حوار تأكيد
	var dialog := AcceptDialog.new()
	dialog.title = "⚠️ تحذير"
	dialog.dialog_text = "هل أنت متأكد من إعادة تعيين اللعبة؟ سيتم حذف كل التقدم!"
	dialog.dialog_hide_on_ok = true
	dialog.get_label().add_theme_font_size_override("font_size", 14)
	dialog.get_label().add_theme_color_override("font_color", COLOR_RED)
	dialog.confirmed.connect(_do_reset)
	add_child(dialog)
	dialog.popup_centered()

func _do_reset() -> void:
	game_manager.reset_game()
	visible = false
