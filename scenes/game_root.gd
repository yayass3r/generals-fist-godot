extends Control
## ═══════════════════════════════════════════════════════════════
## جذر اللعبة — التنقل بين الشاشات + شريط الموارد + المستوى
## ═══════════════════════════════════════════════════════════════

@onready var content_container: Control = $ContentContainer
@onready var scrap_label: Label = $TopBar/ResourceBar/HBox/ScrapLabel
@onready var fuel_label: Label = $TopBar/ResourceBar/HBox/FuelLabel
@onready var intel_label: Label = $TopBar/ResourceBar/HBox/IntelLabel
@onready var scrap_rate: Label = $TopBar/ResourceBar/HBox/ScrapRate
@onready var fuel_rate: Label = $TopBar/ResourceBar/HBox/FuelRate
@onready var intel_rate: Label = $TopBar/ResourceBar/HBox/IntelRate
@onready var level_badge: Label = $TopBar/ResourceBar/HBox/LevelBadge
@onready var nav_war: Button = $BottomNav/HBox/NavWar
@onready var nav_map: Button = $BottomNav/HBox/NavMap
@onready var nav_barracks: Button = $BottomNav/HBox/NavBarracks
@onready var nav_campaign: Button = $BottomNav/HBox/NavCampaign
@onready var nav_missions: Button = $BottomNav/HBox/NavMissions
@onready var battle_overlay: Control = $BattleOverlay
@onready var event_popup: PanelContainer = $EventPopup
@onready var event_icon: Label = $EventPopup/VBox/EventIcon
@onready var event_title: Label = $EventPopup/VBox/EventTitle
@onready var event_desc: Label = $EventPopup/VBox/EventDesc
@onready var event_close: Button = $EventPopup/VBox/EventClose
@onready var settings_btn: Button = $TopBar/ResourceBar/SettingsBtn
@onready var achievements_btn: Button = $TopBar/ResourceBar/AchievementsBtn
@onready var tutorial_popup: PanelContainer = $TutorialPopup
@onready var tutorial_icon: Label = $TutorialPopup/VBox/TutorialIcon
@onready var tutorial_text: Label = $TutorialPopup/VBox/TutorialText
@onready var tutorial_step_label: Label = $TutorialPopup/VBox/TutorialStepLabel
@onready var tutorial_next: Button = $TutorialPopup/VBox/TutorialNext
@onready var tutorial_close_btn: Button = $TutorialPopup/VBox/TutorialCloseBtn

var current_scene: Control = null
var settings_panel: Control = null
var achievements_panel: Control = null

func _ready() -> void:
        game_manager.resources_changed.connect(_update_resources)
        game_manager.screen_changed.connect(_update_nav_highlight)
        game_manager.level_up.connect(_update_resources)
        game_manager.battle_started.connect(_on_battle_started)
        game_manager.battle_ended.connect(_on_battle_ended)
        game_manager.random_event_occurred.connect(_on_random_event)
        game_manager.tutorial_step_changed.connect(_on_tutorial_step_changed)
        game_manager.achievement_unlocked.connect(_on_achievement_unlocked)
        nav_war.pressed.connect(func(): _switch_screen("war_room"))
        nav_map.pressed.connect(func(): _switch_screen("world_map"))
        nav_barracks.pressed.connect(func(): _switch_screen("barracks"))
        nav_campaign.pressed.connect(func(): _switch_screen("campaign"))
        nav_missions.pressed.connect(func(): _switch_screen("missions"))
        event_close.pressed.connect(func(): event_popup.visible = false)
        settings_btn.pressed.connect(_open_settings)
        achievements_btn.pressed.connect(_open_achievements)
        tutorial_next.pressed.connect(_on_tutorial_next)
        tutorial_close_btn.pressed.connect(func(): tutorial_popup.visible = false)
        _switch_screen("war_room")
        _update_resources()
        # عرض التعليمات عند بداية اللعبة الأولى
        if game_manager.show_tutorial and game_manager.tutorial_step == 0:
                game_manager.tutorial_step = 1
                game_manager.tutorial_step_changed.emit(game_manager.tutorial_step)
                tutorial_popup.visible = true

func _open_settings() -> void:
        if settings_panel == null:
                var scene = load("res://scenes/settings.tscn")
                settings_panel = scene.instantiate()
                add_child(settings_panel)
                settings_panel.visible = false
        settings_panel.visible = not settings_panel.visible

func _open_achievements() -> void:
        if achievements_panel == null:
                var scene = load("res://scenes/achievements.tscn")
                achievements_panel = scene.instantiate()
                content_container.add_child(achievements_panel)
                achievements_panel.visible = false
        # إخفاء الشاشة الحالية وإظهار الإنجازات
        if achievements_panel.visible:
                _switch_screen(game_manager.current_screen)
                achievements_panel.visible = false
        else:
                if current_scene:
                        current_scene.visible = false
                achievements_panel.visible = true

func _switch_screen(screen_name: String) -> void:
        game_manager.current_screen = screen_name
        if current_scene:
                current_scene.queue_free()
                current_scene = null
        if achievements_panel:
                achievements_panel.visible = false
        var scene_path := ""
        match screen_name:
                "war_room":
                        scene_path = "res://scenes/war_room.tscn"
                "world_map":
                        scene_path = "res://scenes/world_map.tscn"
                "barracks":
                        scene_path = "res://scenes/barracks.tscn"
                "campaign":
                        scene_path = "res://scenes/campaign.tscn"
                "missions":
                        scene_path = "res://scenes/missions.tscn"
        if scene_path != "":
                var scene = load(scene_path)
                current_scene = scene.instantiate()
                content_container.add_child(current_scene)

func _update_resources() -> void:
        scrap_label.text = str(game_manager.scrap)
        fuel_label.text = str(game_manager.fuel)
        intel_label.text = str(game_manager.intel)
        var prod = game_manager.get_total_production_per_second()
        scrap_rate.text = "+%d/ث" % int(prod["scrap"]) if prod["scrap"] > 0 else ""
        fuel_rate.text = "+%d/ث" % int(prod["fuel"]) if prod["fuel"] > 0 else ""
        intel_rate.text = "+%.1f/ث" % prod["intel"] if prod["intel"] > 0 else ""
        level_badge.text = "⭐%d" % game_manager.player_level

func _update_nav_highlight(screen: String) -> void:
        nav_war.modulate = Color(1, 0.85, 0.2) if screen == "war_room" else Color(0.5, 0.5, 0.5)
        nav_map.modulate = Color(0.3, 0.7, 0.95) if screen == "world_map" else Color(0.5, 0.5, 0.5)
        nav_barracks.modulate = Color(0.3, 0.9, 0.4) if screen == "barracks" else Color(0.5, 0.5, 0.5)
        nav_campaign.modulate = Color(0.9, 0.7, 0.2) if screen == "campaign" else Color(0.5, 0.5, 0.5)
        nav_missions.modulate = Color(0.251, 0.627, 0.878) if screen == "missions" else Color(0.5, 0.5, 0.5)

func _on_battle_started() -> void:
        battle_overlay.visible = true
        var scene = load("res://scenes/battle.tscn")
        var battle_ui = scene.instantiate()
        battle_overlay.add_child(battle_ui)
        _switch_screen("")

func _on_battle_ended(_won: bool, _loot: Dictionary) -> void:
        await get_tree().create_timer(1.0).timeout
        for child in battle_overlay.get_children():
                child.queue_free()
        battle_overlay.visible = false
        if game_manager.battle_is_campaign:
                _switch_screen("campaign")
        else:
                _switch_screen("war_room")

func _on_random_event(event: Dictionary) -> void:
        # تحقق من إعدادات الإشعارات
        if not game_manager.settings.get("notifications_enabled", true):
                return
        event_popup.visible = true
        event_icon.text = str(event.get("icon", "📢"))
        event_title.text = str(event.get("name", "حدث!"))
        event_desc.text = str(event.get("desc", ""))
        var is_positive: bool = event.get("scrap", 0) > 0 or event.get("amount", 0) > 0 or event.get("fuel", 0) > 0
        if is_positive:
                event_title.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3, 1))
        else:
                event_title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))

# ─── نظام التعليمات ───
func _on_tutorial_step_changed(step: int) -> void:
        if step <= 0 or step >= game_manager.tutorial_texts.size():
                tutorial_popup.visible = false
                return
        tutorial_popup.visible = true
        tutorial_text.text = game_manager.tutorial_texts[step]
        tutorial_step_label.text = "%d / %d" % [step, game_manager.tutorial_texts.size() - 1]
        if step >= game_manager.tutorial_texts.size() - 1:
                tutorial_next.text = "🏁 إنهاء"
        else:
                tutorial_next.text = "التالي ▶"

func _on_tutorial_next() -> void:
        game_manager.advance_tutorial()

# ─── إشعار إنجاز جديد ───
func _on_achievement_unlocked(achievement_id: String) -> void:
        for a in game_manager.achievements:
                if a["id"] == achievement_id:
                        event_popup.visible = true
                        event_icon.text = str(a["icon"])
                        event_title.text = "🏆 إنجاز جديد!"
                        event_title.add_theme_color_override("font_color", Color(0.788, 0.635, 0.153, 1))
                        event_desc.text = "%s: %s" % [a["name"], a["desc"]]
                        break
