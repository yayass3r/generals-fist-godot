extends Control
## ═══════════════════════════════════════════════════════════════
## شاشة الإنجازات — قبضة الجنرال
## ═══════════════════════════════════════════════════════════════

const COLOR_BG := Color(0.02, 0.03, 0.06, 1.0)
const COLOR_GOLD := Color(0.788, 0.635, 0.153, 1.0)
const COLOR_DARK_PANEL := Color(0.05, 0.08, 0.16, 0.9)
const COLOR_RED := Color(0.937, 0.267, 0.267, 1.0)
const COLOR_GREEN := Color(0.2, 0.7, 0.3, 1.0)

var category_names: Dictionary = {
	"combat": "⚔️ قتال",
	"economy": "💰 اقتصاد",
	"campaign": "📖 حملات",
	"military": "🎖️ عسكري",
	"social": "🤝 اجتماعي",
}

var current_category: String = "combat"

func _ready() -> void:
	_build_ui()
	game_manager.achievements_changed.connect(_refresh)
	_refresh()

func _build_ui() -> void:
	# خلفية
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# حاوية رئيسية
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	main_vbox.offset_top = 10
	main_vbox.offset_bottom = -10
	main_vbox.offset_left = 10
	main_vbox.offset_right = -10
	add_child(main_vbox)

	# عنوان
	var title := Label.new()
	title.text = "🏆 الإنجازات"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	# عدد الإنجازات
	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	main_vbox.add_child(count_label)

	# TabBar
	var tab_bar := TabBar.new()
	tab_bar.name = "CategoryTabs"
	tab_bar.tab_count = 5
	tab_bar.set_tab_title(0, "⚔️ قتال")
	tab_bar.set_tab_title(1, "💰 اقتصاد")
	tab_bar.set_tab_title(2, "📖 حملات")
	tab_bar.set_tab_title(3, "🎖️ عسكري")
	tab_bar.set_tab_title(4, "🤝 اجتماعي")
	tab_bar.add_theme_font_size_override("font_size", 13)
	tab_bar.tab_changed.connect(_on_category_changed)
	main_vbox.add_child(tab_bar)

	# ScrollContainer
	var scroll := ScrollContainer.new()
	scroll.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	scroll.name = "ScrollContainer"
	main_vbox.add_child(scroll)

	# حاوية الإنجازات
	var ach_container := VBoxContainer.new()
	ach_container.name = "AchievementList"
	ach_container.add_theme_constant_override("separation", 6)
	scroll.add_child(ach_container)

func _on_category_changed(tab: int) -> void:
	var categories := ["combat", "economy", "campaign", "military", "social"]
	if tab >= 0 and tab < categories.size():
		current_category = categories[tab]
		_refresh()

func _refresh() -> void:
	# تحديث العداد
	var count_label := get_node_or_null("CountLabel")
	if count_label:
		var unlocked := 0
		var total := 0
		for a in game_manager.achievements:
			total += 1
			if a["completed"]:
				unlocked += 1
		count_label.text = "✅ %d / %d إنجاز مُفتح" % [unlocked, total]

	# تحديث قائمة الإنجازات
	var list := get_node_or_null("ScrollContainer/AchievementList")
	if not list:
		return
	for child in list.get_children():
		child.queue_free()

	for a in game_manager.achievements:
		if a["category"] != current_category:
			continue
		var card := _create_achievement_card(a)
		list.add_child(card)

func _create_achievement_card(a: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	if a["completed"] and a["claimed"]:
		style.bg_color = Color(0.05, 0.12, 0.05, 0.9)
		style.border_color = Color(0.2, 0.7, 0.3, 0.4)
	elif a["completed"]:
		style.bg_color = Color(0.1, 0.08, 0.03, 0.9)
		style.border_color = Color(0.788, 0.635, 0.153, 0.6)
	else:
		style.bg_color = Color(0.04, 0.05, 0.08, 0.9)
		style.border_color = Color(0.2, 0.2, 0.25, 0.4)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# أيقونة
	var icon_label := Label.new()
	icon_label.text = a["icon"]
	icon_label.add_theme_font_size_override("font_size", 28)
	icon_label.custom_minimum_size = Vector2(40, 40)
	hbox.add_child(icon_label)

	# معلومات
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_label := Label.new()
	name_label.text = a["name"]
	name_label.add_theme_font_size_override("font_size", 14)
	if a["completed"]:
		name_label.add_theme_color_override("font_color", COLOR_GREEN)
	else:
		name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = a["desc"]
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1))
	vbox.add_child(desc_label)

	# مكافأة
	var reward_text := "⚙️%d  ⛽%d  ⭐%d" % [a["reward"].get("scrap", 0), a["reward"].get("fuel", 0), a["reward"].get("xp", 0)]
	var reward_label := Label.new()
	reward_label.text = reward_text
	reward_label.add_theme_font_size_override("font_size", 10)
	reward_label.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(reward_label)

	# حالة / زر استلام
	var status_vbox := VBoxContainer.new()
	status_vbox.add_theme_constant_override("separation", 4)
	status_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(status_vbox)

	if a["claimed"]:
		var done := Label.new()
		done.text = "✅ تم الاستلام"
		done.add_theme_font_size_override("font_size", 12)
		done.add_theme_color_override("font_color", COLOR_GREEN)
		status_vbox.add_child(done)
	elif a["completed"]:
		var btn := Button.new()
		btn.text = "🎁 استلام"
		btn.custom_minimum_size = Vector2(90, 32)
		btn.add_theme_font_size_override("font_size", 12)
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = COLOR_GOLD
		btn_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_color_override("font_color", Color(0.05, 0.03, 0.06, 1))
		var ach_id: String = a["id"]
		btn.pressed.connect(func(): _claim(ach_id))
		status_vbox.add_child(btn)
	else:
		var lock := Label.new()
		lock.text = "🔒"
		lock.add_theme_font_size_override("font_size", 20)
		status_vbox.add_child(lock)

	return panel

func _claim(achievement_id: String) -> void:
	game_manager.claim_achievement(achievement_id)
