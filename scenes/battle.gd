extends Control
## ═══════════════════════════════════════════════════════════════
## مشهد المعركة — قتال实时 مع تكتيكات
## ═══════════════════════════════════════════════════════════════

@onready var enemy_hp_bar: ProgressBar = $TopSection/EnemyBox/HBox/ProgressBar
@onready var enemy_label: Label = $TopSection/EnemyBox/HBox/EnemyLabel
@onready var player_hp_bar: ProgressBar = $PlayerSection/PlayerBox/HBox/ProgressBar
@onready var player_label: Label = $PlayerSection/PlayerBox/HBox/PlayerLabel
@onready var log_text: RichTextLabel = $LogSection/LogText
@onready var smoke_btn: Button = $TacticsSection/HBox/SmokeBtn
@onready var air_btn: Button = $TacticsSection/HBox/AirBtn
@onready var retreat_btn: Button = $TacticsSection/HBox/RetreatBtn
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_title: Label = $ResultPanel/VBox/ResultTitle
@onready var result_loot: Label = $ResultPanel/VBox/ResultLoot
@onready var result_btn: Button = $ResultPanel/VBox/ResultBtn
@onready var vs_label: Label = $VSLabel

func _ready() -> void:
	game_manager.battle_updated.connect(_on_battle_update)
	game_manager.battle_ended.connect(_on_battle_end)
	smoke_btn.pressed.connect(func(): game_manager.activate_tactic("smoke"))
	air_btn.pressed.connect(func(): game_manager.activate_tactic("air_support"))
	retreat_btn.pressed.connect(func(): game_manager.activate_tactic("retreat"))
	result_btn.pressed.connect(_on_result_close)
	result_panel.visible = false
	# تعيين HP القصوى
	if game_manager.battle_data.has("enemy_power"):
		enemy_hp_bar.max_value = game_manager.battle_data["enemy_power"]
		enemy_hp_bar.value = game_manager.battle_data["enemy_current_hp"]
	if game_manager.battle_data.has("player_power"):
		player_hp_bar.max_value = game_manager.battle_data["player_power"]
		player_hp_bar.value = game_manager.battle_data["player_current_hp"]

func _process(_delta: float) -> void:
	if not game_manager.battle_active:
		return
	var data: Dictionary = game_manager.battle_data
	if data.is_empty():
		return
	# تحديث أشرطة HP
	enemy_hp_bar.max_value = data["enemy_power"]
	enemy_hp_bar.value = maxi(0, data["enemy_current_hp"])
	player_hp_bar.max_value = data["player_power"]
	player_hp_bar.value = maxi(0, data["player_current_hp"])
	# تحديث النصوص
	var enemy_pct: float = (data["enemy_current_hp"] / data["enemy_power"]) * 100
	var player_pct: float = (data["player_current_hp"] / data["player_power"]) * 100
	enemy_label.text = "👾 عدو: %d%%" % int(enemy_pct)
	player_label.text = "👤 أنت: %d%%" % int(player_pct)
	# تحديث أزرار التكتيكات
	var cd_smoke: float = data["tactics_cooldowns"]["smoke"]
	var cd_air: float = data["tactics_cooldowns"]["air_support"]
	smoke_btn.disabled = cd_smoke > 0 or game_manager.fuel < 20
	air_btn.disabled = cd_air > 0 or game_manager.fuel < 40
	if cd_smoke > 0:
		smoke_btn.text = "🚬 دخان (%dث)" % int(ceil(cd_smoke))
	else:
		smoke_btn.text = "🚬 ستارة دخان -20⛽"
	if cd_air > 0:
		air_btn.text = "✈️ جوي (%dث)" % int(ceil(cd_air))
	else:
		air_btn.text = "✈️ دعم جوي -40⛽"

func _on_battle_update(data: Dictionary) -> void:
	# إضافة آخر سطر من السجل
	log_text.append_text(data["log"][-1] + "\n")
	# التمرير للأسفل
	log_text.scroll_to_line(log_text.get_line_count() - 1)

func _on_battle_end(won: bool, loot: Dictionary) -> void:
	result_panel.visible = true
	if won:
		result_title.text = "🏆 نصر!"
		result_title.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3, 1))
		result_loot.text = "الغنائم:\n⚙️ %d خردة\n⛽ %d وقود\n📋 %d معلومات" % [loot["scrap"], loot["fuel"], loot["intel"]]
	else:
		result_title.text = "💔 هزيمة"
		result_title.add_theme_color_override("font_color", Color(0.937, 0.267, 0.267, 1))
		result_loot.text = "لا غنائم. حاول مرة أخرى!"

func _on_result_close() -> void:
	result_panel.visible = false
