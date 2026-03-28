extends Control
## ═══════════════════════════════════════════════════════════════
## الثكنات — تجنيد القوات + البحث والتطوير
## ═══════════════════════════════════════════════════════════════

@onready var tab_barracks: Button = $TabBar/HBox/TabBarracks
@onready var tab_research: Button = $TabBar/HBox/TabResearch
@onready var barracks_content: ScrollContainer = $BarracksContent
@onready var research_content: ScrollContainer = $ResearchContent

func _ready() -> void:
	tab_barracks.pressed.connect(func(): _show_tab("barracks"))
	tab_research.pressed.connect(func(): _show_tab("research"))
	game_manager.troops_changed.connect(_build_barracks)
	game_manager.research_completed.connect(_on_research_done)
	_build_barracks()
	_build_research()
	_show_tab("barracks")

func _show_tab(tab: String) -> void:
	barracks_content.visible = tab == "barracks"
	research_content.visible = tab == "research"
	tab_barracks.modulate = Color(0.3, 0.9, 0.4) if tab == "barracks" else Color(0.4, 0.4, 0.4)
	tab_research.modulate = Color(0.251, 0.627, 0.878) if tab == "research" else Color(0.4, 0.4, 0.4)

func _build_barracks() -> void:
	for child in barracks_content.get_children():
		child.queue_free()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	barracks_content.add_child(vbox)
	# عنوان
	var title = Label.new()
	title.text = "🏰 التشكيلات العسكرية"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.788, 0.635, 0.153, 1))
	vbox.add_child(title)
	# بطاقات الشركات
	for company in game_manager.companies:
		var card = _create_company_card(company)
		vbox.add_child(card)

func _create_company_card(company: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.16, 0.9)
	style.border_color = Color(0.2, 0.25, 0.35, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	# عنوان الشركة
	var header = HBoxContainer.new()
	var name_label = Label.new()
	var ttype: int = company["type"]
	name_label.text = "%s %s" % [game_manager.troop_icons[ttype], game_manager.troop_names[ttype]]
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	header.add_child(name_label)
	var count_label = Label.new()
	var total: int = game_manager.get_company_troop_count(company)
	count_label.text = "القوات: %d/100" % total
	count_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(count_label)
	vbox.add_child(header)
	# معلومات الفرق
	var stats: Dictionary = game_manager.troop_stats[ttype]
	var info = Label.new()
	info.text = "هجوم: %d | دفاع: %d | تكلفة: %d⚙️ + %d⛽" % [stats["attack"], stats["defense"], stats["cost_scrap"], stats["cost_fuel"]]
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
	vbox.add_child(info)
	# أزرار
	var btn_box = HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 6)
	# زر إضافة فصيلة
	var add_btn = Button.new()
	add_btn.text = "+ فصيلة"
	add_btn.custom_minimum_size = Vector2(100, 36)
	add_btn.add_theme_font_size_override("font_size", 11)
	var add_style = StyleBoxFlat.new()
	add_style.bg_color = Color(0.2, 0.3, 0.5, 0.8)
	add_style.set_corner_radius_all(6)
	add_btn.add_theme_stylebox_override("normal", add_style)
	add_btn.pressed.connect(func(): game_manager.add_squad(company["id"]))
	btn_box.add_child(add_btn)
	# زر تجنيد
	var recruit_btn = Button.new()
	recruit_btn.text = "+5 تجنيد"
	recruit_btn.custom_minimum_size = Vector2(100, 36)
	recruit_btn.add_theme_font_size_override("font_size", 11)
	var rec_style = StyleBoxFlat.new()
	rec_style.bg_color = Color(0.2, 0.5, 0.3, 0.8)
	rec_style.set_corner_radius_all(6)
	recruit_btn.add_theme_stylebox_override("normal", rec_style)
	recruit_btn.pressed.connect(func():
		var recruited: int = game_manager.recruit_troops(company["id"], 0, 5)
		if recruited > 0:
			_build_barracks()
	)
	btn_box.add_child(recruit_btn)
	vbox.add_child(btn_box)
	# عرض الفصائل
	for i in range(company["squads"].size()):
		var squad: Dictionary = company["squads"][i]
		var sq_label = Label.new()
		sq_label.text = "  📋 فصيلة %d: %d/10 مقاتل" % [i + 1, squad["size"]]
		sq_label.add_theme_font_size_override("font_size", 11)
		sq_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		vbox.add_child(sq_label)
	panel.add_child(vbox)
	return panel

func _build_research() -> void:
	for child in research_content.get_children():
		child.queue_free()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	research_content.add_child(vbox)
	# عنوان
	var title = Label.new()
	title.text = "🔬 البحث والتطوير"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.251, 0.627, 0.878, 1))
	vbox.add_child(title)
	if game_manager.research_in_progress != "":
		var prog_label = Label.new()
		var pct: int = int(game_manager.research_progress)
		prog_label.text = "⏳ جاري البحث... %d%%" % pct
		prog_label.add_theme_font_size_override("font_size", 13)
		prog_label.add_theme_color_override("font_color", Color(0.788, 0.635, 0.153, 1))
		vbox.add_child(prog_label)
	# بطاقات التقنيات
	for tech in game_manager.tech_tree:
		var card = _create_tech_card(tech)
		vbox.add_child(card)

func _create_tech_card(tech: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var completed: bool = tech["id"] in game_manager.completed_techs
	var can_do: bool = game_manager.can_research(tech["id"])
	var style = StyleBoxFlat.new()
	if completed:
		style.bg_color = Color(0.1, 0.2, 0.1, 0.9)
		style.border_color = Color(0.2, 0.7, 0.3, 0.5)
	elif can_do:
		style.bg_color = Color(0.05, 0.08, 0.16, 0.9)
		style.border_color = Color(0.251, 0.627, 0.878, 0.3)
	else:
		style.bg_color = Color(0.04, 0.04, 0.06, 0.9)
		style.border_color = Color(0.15, 0.15, 0.2, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	# العنوان
	var header = Label.new()
	header.text = "%s %s (الطبقة %d)" % [tech["icon"], tech["name"], tech["tier"]]
	header.add_theme_font_size_override("font_size", 14)
	if completed:
		header.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3, 1))
	else:
		header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	vbox.add_child(header)
	# الوصف
	var desc = Label.new()
	desc.text = tech["desc"]
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
	vbox.add_child(desc)
	# التكلفة
	var cost = Label.new()
	cost.text = "التكلفة: %d⚙️ + %d📋 | الوقت: %dث" % [tech["cost_scrap"], tech["cost_intel"], int(tech["time"])]
	cost.add_theme_font_size_override("font_size", 11)
	cost.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	vbox.add_child(cost)
	# زر البحث
	if not completed and can_do:
		var btn = Button.new()
		btn.text = "🔬 بحث"
		btn.custom_minimum_size = Vector2(100, 34)
		btn.add_theme_font_size_override("font_size", 12)
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.251, 0.627, 0.878, 1)
		btn_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.pressed.connect(func():
			game_manager.start_research(tech["id"])
			_build_research()
		)
		vbox.add_child(btn)
	elif completed:
		var done = Label.new()
		done.text = "✅ مكتمل"
		done.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3, 1))
		done.add_theme_font_size_override("font_size", 12)
		vbox.add_child(done)
	panel.add_child(vbox)
	return panel

func _on_research_done(_tech_id: String) -> void:
	_build_research()
