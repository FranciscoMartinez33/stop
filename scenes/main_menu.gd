extends Node

const CLASSIC_DECK_SIZE := 20
const WC_DECK_SIZE      := 10

var _num_players  : int = 2
var _max_penalties: int = 3
var _ply_lbl      : Label
var _pen_lbl      : Label
var _mode_panel   : Control
var _settings_panel: Control
var _mode_lbl     : Label  # subtitle inside settings panel

func _ready() -> void:
	_build_ui()
	var sfx := AudioStreamPlayer.new()
	add_child(sfx)
	sfx.stream = load("res://assets/sounds-fx/freesound_community-1stop-it-audio-clip-100732.mp3")
	sfx.play()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var bg := TextureRect.new()
	layer.add_child(bg)
	bg.texture      = load("res://assets/stop_menu.png")
	bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_mode_panel(layer)
	_build_settings_panel(layer)
	_settings_panel.visible = false

# ── Mode selection ────────────────────────────────────────────────────────────
func _build_mode_panel(layer: CanvasLayer) -> void:
	_mode_panel = PanelContainer.new()
	layer.add_child(_mode_panel)
	_mode_panel.anchor_left   = 0.5; _mode_panel.anchor_right  = 0.5
	_mode_panel.anchor_top    = 0.5; _mode_panel.anchor_bottom = 0.5
	_mode_panel.offset_left   = -230; _mode_panel.offset_right  = 230
	_mode_panel.offset_top    = -195; _mode_panel.offset_bottom = 195

	var style := StyleBoxFlat.new()
	style.bg_color                    = Color(0.0, 0.0, 0.0, 0.78)
	style.corner_radius_top_left      = 12; style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left   = 12; style.corner_radius_bottom_right = 12
	style.border_width_left = 2; style.border_width_right  = 2
	style.border_width_top  = 2; style.border_width_bottom = 2
	style.border_color = Color(0.90, 0.03, 0.08)
	_mode_panel.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	_mode_panel.add_child(vb)
	vb.add_theme_constant_override("separation", 18)

	var title := Label.new()
	title.text = "STOP!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(0.90, 0.03, 0.08))
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose your game mode"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
	vb.add_child(subtitle)

	var classic_btn := Button.new()
	classic_btn.text = "CLASSIC"
	classic_btn.add_theme_font_size_override("font_size", 22)
	classic_btn.pressed.connect(func(): _select_mode("CLASSIC"))
	vb.add_child(classic_btn)

	var wc_btn := Button.new()
	wc_btn.text = "WORLD CUP 2026"
	wc_btn.add_theme_font_size_override("font_size", 22)
	wc_btn.add_theme_color_override("font_color", Color(0.15, 0.88, 0.15))
	wc_btn.pressed.connect(func(): _select_mode("WORLD_CUP"))
	vb.add_child(wc_btn)

func _select_mode(mode: String) -> void:
	GameState.game_mode = mode
	_mode_panel.visible = false
	_mode_lbl.text = "World Cup 2026" if mode == "WORLD_CUP" else "Classic"
	_mode_lbl.add_theme_color_override("font_color",
		Color(0.15, 0.88, 0.15) if mode == "WORLD_CUP" else Color(0.70, 0.70, 0.75))
	_settings_panel.visible = true

# ── Game settings ─────────────────────────────────────────────────────────────
func _build_settings_panel(layer: CanvasLayer) -> void:
	_settings_panel = PanelContainer.new()
	layer.add_child(_settings_panel)
	_settings_panel.anchor_left   = 0.5; _settings_panel.anchor_right  = 0.5
	_settings_panel.anchor_top    = 0.5; _settings_panel.anchor_bottom = 0.5
	_settings_panel.offset_left   = -200; _settings_panel.offset_right  = 200
	_settings_panel.offset_top    = -210; _settings_panel.offset_bottom = 210

	var style := StyleBoxFlat.new()
	style.bg_color                    = Color(0.0, 0.0, 0.0, 0.72)
	style.corner_radius_top_left      = 12; style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left   = 12; style.corner_radius_bottom_right = 12
	style.border_width_left = 2; style.border_width_right  = 2
	style.border_width_top  = 2; style.border_width_bottom = 2
	style.border_color = Color(0.90, 0.03, 0.08)
	_settings_panel.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	_settings_panel.add_child(vb)
	vb.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "STOP!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.90, 0.03, 0.08))
	vb.add_child(title)

	_mode_lbl = Label.new()
	_mode_lbl.text = "Classic"
	_mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_lbl.add_theme_font_size_override("font_size", 13)
	_mode_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.75))
	vb.add_child(_mode_lbl)

	# Players
	var ply_sub := Label.new()
	ply_sub.text = "Number of players:"
	ply_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ply_sub.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(ply_sub)

	var ply_row := HBoxContainer.new()
	ply_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ply_row.add_theme_constant_override("separation", 18)
	vb.add_child(ply_row)

	var ply_minus := Button.new()
	ply_minus.text = "  −  "
	ply_minus.pressed.connect(func(): _change_players(-1))
	ply_row.add_child(ply_minus)

	_ply_lbl = Label.new()
	_ply_lbl.text = str(_num_players)
	_ply_lbl.custom_minimum_size = Vector2(44, 0)
	_ply_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ply_lbl.add_theme_font_size_override("font_size", 30)
	_ply_lbl.add_theme_color_override("font_color", Color.WHITE)
	ply_row.add_child(_ply_lbl)

	var ply_plus := Button.new()
	ply_plus.text = "  +  "
	ply_plus.pressed.connect(func(): _change_players(1))
	ply_row.add_child(ply_plus)

	# Penalties
	var pen_sub := Label.new()
	pen_sub.text = "Penalties to lose:"
	pen_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pen_sub.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(pen_sub)

	var pen_row := HBoxContainer.new()
	pen_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pen_row.add_theme_constant_override("separation", 18)
	vb.add_child(pen_row)

	var pen_minus := Button.new()
	pen_minus.text = "  −  "
	pen_minus.pressed.connect(func(): _change_penalties(-1))
	pen_row.add_child(pen_minus)

	_pen_lbl = Label.new()
	_pen_lbl.text = str(_max_penalties)
	_pen_lbl.custom_minimum_size = Vector2(44, 0)
	_pen_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pen_lbl.add_theme_font_size_override("font_size", 30)
	_pen_lbl.add_theme_color_override("font_color", Color(0.92, 0.40, 0.40))
	pen_row.add_child(_pen_lbl)

	var pen_plus := Button.new()
	pen_plus.text = "  +  "
	pen_plus.pressed.connect(func(): _change_penalties(1))
	pen_row.add_child(pen_plus)

	# Back
	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.add_theme_font_size_override("font_size", 13)
	back_btn.pressed.connect(func():
		_settings_panel.visible = false
		_mode_panel.visible = true
	)
	vb.add_child(back_btn)

	# Start
	var start := Button.new()
	start.text = "▶  Start Game"
	start.add_theme_font_size_override("font_size", 18)
	start.pressed.connect(_on_start)
	vb.add_child(start)

func _change_players(delta: int) -> void:
	_num_players  = clampi(_num_players + delta, 2, 8)
	_ply_lbl.text = str(_num_players)

func _change_penalties(delta: int) -> void:
	_max_penalties = clampi(_max_penalties + delta, 1, 10)
	_pen_lbl.text  = str(_max_penalties)

func _on_start() -> void:
	GameState.num_players   = _num_players
	GameState.max_penalties = _max_penalties
	GameState.cur_player    = 0
	GameState.blocked.clear()
	var deck_size := WC_DECK_SIZE if GameState.game_mode == "WORLD_CUP" else CLASSIC_DECK_SIZE
	GameState.deck_seq = range(deck_size)
	GameState.deck_seq.shuffle()
	GameState.deck_pos = 0
	GameState.penalties.resize(_num_players)
	GameState.penalties.fill(0)
	get_tree().change_scene_to_file("res://scenes/card_selection.tscn")
