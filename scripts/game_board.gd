extends Node3D

const LETTERS: Array[String] = [
	"A","B","C","D","E","F","G","H","I","J","K","L",
	"M","N","O","P","Q","R","S","T","U","V","Y","?"
]

const BOARD_R := 6.5
const RING_R  := 5.0
const BTN_R   := 0.50
const CENT_R  := 1.90
const TURN_T := 15.0

const C_BOARD   := Color(0.72, 0.08, 0.08)
const C_CENTER  := Color(0.48, 0.04, 0.04)
const C_RIM     := Color(0.96, 0.96, 0.96)
const C_BTN     := Color(0.96, 0.96, 0.96)
const C_WILD    := Color(0.92, 0.82, 0.12)
const C_HOVER   := Color(1.00, 0.82, 0.82)
const C_BLOCKED := Color(0.30, 0.30, 0.32)
const C_TXT_ON  := Color(0.05, 0.05, 0.05)
const C_TXT_OFF := Color(0.55, 0.55, 0.55)
const C_CTR_TXT := Color.WHITE

enum State { PLAYING, ROUND_END, GAME_OVER }

var _state      : State = State.PLAYING
var _num_players: int   = 2
var _cur_player : int   = 0
var _topic      : String = ""
var _blocked    : Array[String] = []
var _time_left  : float = TURN_T
var _timing     : bool  = false

var _board_pivot: Node3D
var _mats       : Dictionary = {}

var _layer      : CanvasLayer
var _status     : Label
var _tbar       : ProgressBar
var _wrong_btn  : Button
var _new_btn    : Button
var _word_input : LineEdit
var _submit_btn : Button
var _tv_panel   : Panel
var _tv_next_lbl: Label
var _stop_empty : Label
var _stop_fill  : Label
var _stop_clip  : Control
var _stop_holder : Control
var _word_display: Label

var _score_panel    : Panel
var _score_name_lbls: Array[Label] = []
var _score_pen_lbls : Array[Label] = []

var _max_penalties    : int           = 3
var _game_over_overlay: Control
var _go_name_lbls     : Array[Label] = []
var _go_ticket_lbls   : Array[Label] = []

var _env : Environment
var _turn_sfx    : AudioStreamPlayer
var _success_sfx : AudioStreamPlayer
var _wrong_sfx   : AudioStreamPlayer


func _ready() -> void:
	_num_players    = GameState.num_players
	_cur_player     = GameState.cur_player
	_topic          = GameState.topic
	_max_penalties  = GameState.max_penalties
	_turn_sfx = AudioStreamPlayer.new()
	add_child(_turn_sfx)
	_turn_sfx.stream = load("res://assets/freesound_community-pedestrian-crossing-77181.mp3")
	_success_sfx = AudioStreamPlayer.new()
	add_child(_success_sfx)
	_success_sfx.stream = load("res://assets/sounds-fx/meldix-success-340660.mp3")
	_wrong_sfx = AudioStreamPlayer.new()
	add_child(_wrong_sfx)
	_wrong_sfx.stream = load("res://assets/sounds-fx/error.mp3")
	_build_3d()
	_build_ui()
	_begin_round()

func _process(delta: float) -> void:
	if _timing and _state == State.PLAYING:
		_time_left -= delta
		var elapsed := 1.0 - (_time_left / TURN_T)   # 0 -> 1 as time runs out
		elapsed = clampf(elapsed, 0.0, 1.0)
		_env.background_color = _timer_color(elapsed)
		var h := _stop_holder.size.y           # full height of the word area
		_stop_clip.offset_top = -h * elapsed   # grow clip upward from the bottom
		if _time_left <= 0.0:
			_timing = false
			_end_turn_wrong()

# ═══════════════════════════════ 3D Scene ════════════════════════════════════
func _build_stop_timer() -> void:
	var holder := Control.new()
	_layer.add_child(holder)
	holder.anchor_left = 0.5; holder.anchor_right = 0.5
	holder.anchor_top  = 0.5; holder.anchor_bottom = 0.5
	holder.offset_left = -120; holder.offset_right = 120
	holder.offset_top  = -45;  holder.offset_bottom = 45
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Bottom layer: invisible until fill begins
	_stop_empty = Label.new()
	holder.add_child(_stop_empty)
	_stop_empty.text = "STOP"
	_stop_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stop_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stop_empty.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_stop_empty.add_theme_font_size_override("font_size", 72)
	_stop_empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.0))  # invisible

	# Clip container anchored to BOTTOM, grows upward
	_stop_clip = Control.new()
	holder.add_child(_stop_clip)
	_stop_clip.clip_contents = true
	# pin left/right to holder, bottom to holder bottom; height starts at 0
	_stop_clip.anchor_left = 0.0; _stop_clip.anchor_right = 1.0
	_stop_clip.anchor_top  = 1.0; _stop_clip.anchor_bottom = 1.0
	_stop_clip.offset_left = 0;   _stop_clip.offset_right = 0
	_stop_clip.offset_top  = 0;   _stop_clip.offset_bottom = 0   # zero height = nothing shown

	# Top layer: solid white STOP. Pinned so it stays full-size while the clip reveals it.
	_stop_fill = Label.new()
	_stop_clip.add_child(_stop_fill)
	_stop_fill.text = "STOP"
	_stop_fill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stop_fill.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_stop_fill.add_theme_font_size_override("font_size", 72)
	_stop_fill.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))

	_stop_holder = holder
	_stop_fill.anchor_left = 0.0; _stop_fill.anchor_right = 1.0
	_stop_fill.anchor_top  = 1.0; _stop_fill.anchor_bottom = 1.0
	_stop_fill.offset_left = 0;   _stop_fill.offset_right = 0
	_stop_fill.offset_top  = -90; _stop_fill.offset_bottom = 0 

func _build_3d() -> void:
	_add_camera()
	_add_env()
	_board_pivot = Node3D.new()
	add_child(_board_pivot)
	_add_board()

func _add_camera() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 3.0, 0.0)
	cam.look_at(Vector3.ZERO, Vector3(0, 0, -1))  # up-vector can't be Y when looking along Y
	cam.current = true

func _add_env() -> void:
	var we  := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = Color(0.20, 0.80, 0.20) 
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.60, 0.38, 0.38)
	env.ambient_light_energy = 0.75
	we.environment = env
	add_child(we)
	_env = env

	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.position = Vector3(5.0, 10.0, 5.0)
	sun.look_at(Vector3.ZERO)
	sun.light_energy   = 1.2
	sun.shadow_enabled = true

	var fill := DirectionalLight3D.new()
	add_child(fill)
	fill.position = Vector3(-4.0, 4.0, -3.0)
	fill.look_at(Vector3.ZERO)
	fill.light_energy = 0.3

func _mat(color: Color, rough := 0.55, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = rough
	m.metallic     = metal
	return m
	
func _timer_color(t: float) -> Color:
	var green  := Color(0.20, 0.80, 0.20)
	var yellow := Color(0.95, 0.85, 0.15)
	var red    := Color(0.85, 0.10, 0.10)
	if t < 0.5:
		return green.lerp(yellow, t / 0.5)
	else:
		return yellow.lerp(red, (t - 0.5) / 0.5)
		
func _add_board() -> void:
	var scene := load("res://assets/stopboard/Stop.glb1.1.glb") as PackedScene
	if scene == null:
		push_error("game_board: failed to load board GLB")
		return
	var board := scene.instantiate()
	board.position = Vector3(-0.09, -0.25, -3.6)
	_board_pivot.add_child(board)
	_wire_glb_letters(board)

func _wire_glb_letters(board: Node) -> void:
	for letter in LETTERS:
		var mi := _find_letter_mesh(board, letter)
		if mi == null:
			push_warning("NO MESH for '%s'" % letter)
			continue
		var wild := letter == "?"

		# Duplicate the GLB's own material so we keep the baked-in letter texture
		var src := mi.get_active_material(0)
		var mat: StandardMaterial3D
		if src is StandardMaterial3D:
			mat = (src as StandardMaterial3D).duplicate()
		else:
			mat = StandardMaterial3D.new()   # fallback if it's not a StandardMaterial3D

		# Tint instead of overwrite: multiplies the texture, so the glyph stays
		mat.albedo_color = C_WILD if wild else C_BTN

		mi.set_surface_override_material(0, mat)
		_mats[letter] = mat
		var body := StaticBody3D.new()
		_board_pivot.add_child(body)
		var aabb := mi.get_aabb()
		body.global_position = mi.to_global(aabb.get_center())
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = min(aabb.size.x, aabb.size.y) * 0.45
		cs.shape  = sh
		body.add_child(cs)
		#body.input_event.connect(_on_btn_input.bind(letter))
		body.mouse_entered.connect(_on_hover.bind(letter, true))
		body.mouse_exited.connect(_on_hover.bind(letter, false))

# "S" was never modelled in the GLB; "Z" is the only unused button node,
# so we redirect the search for "S" to "Z" as a visual stand-in.
const _GLB_REMAP: Dictionary = { "S": "Z" }

func _find_letter_mesh(root: Node, letter: String) -> MeshInstance3D:
	var target := (_GLB_REMAP.get(letter, letter) as String).to_upper()
	for child in root.get_children():
		if child.name.to_upper() == target:
			if child is MeshInstance3D:
				return child as MeshInstance3D
			for sub in child.get_children():
				if sub is MeshInstance3D:
					return sub as MeshInstance3D
	return null

# ═══════════════════════════════ 2D UI ═══════════════════════════════════════

func _build_ui() -> void:
	_layer = CanvasLayer.new(); add_child(_layer)

	_status = Label.new(); _layer.add_child(_status)
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_status.offset_top    = 8
	_status.offset_bottom = 44
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_color_override("font_color", Color.WHITE)

	_tbar = ProgressBar.new(); _layer.add_child(_tbar)
	_tbar.anchor_left  = 0.5; _tbar.anchor_right  = 0.5
	_tbar.offset_left  = -220; _tbar.offset_right  = 220
	_tbar.offset_top   = 48;   _tbar.offset_bottom = 66
	_tbar.max_value = 1.0; _tbar.value = 1.0
	_tbar.visible = false

	_word_input = LineEdit.new(); _layer.add_child(_word_input)
	_word_input.anchor_left  = 0.5;  _word_input.anchor_right  = 0.5
	_word_input.anchor_top   = 1.0;  _word_input.anchor_bottom = 1.0
	_word_input.offset_left  = -260; _word_input.offset_right  = 100
	_word_input.offset_top   = -130; _word_input.offset_bottom = -100
	_word_input.visible = false
	_word_input.text_submitted.connect(_on_word_submitted)

	_submit_btn = Button.new(); _layer.add_child(_submit_btn)
	_submit_btn.text         = "Submit"
	_submit_btn.anchor_left  = 0.5;  _submit_btn.anchor_right  = 0.5
	_submit_btn.anchor_top   = 1.0;  _submit_btn.anchor_bottom = 1.0
	_submit_btn.offset_left  = 110;  _submit_btn.offset_right  = 260
	_submit_btn.offset_top   = -130; _submit_btn.offset_bottom = -100
	_submit_btn.visible = false
	_submit_btn.pressed.connect(func(): _on_word_submitted(_word_input.text))

	_wrong_btn = Button.new(); _layer.add_child(_wrong_btn)
	_wrong_btn.text          = "⚠  Wrong Word / Time's Up"
	_wrong_btn.anchor_left   = 0.5; _wrong_btn.anchor_right  = 0.5
	_wrong_btn.anchor_top    = 1.0; _wrong_btn.anchor_bottom = 1.0
	_wrong_btn.offset_left   = -175; _wrong_btn.offset_right  = 175
	_wrong_btn.offset_top    = -60;  _wrong_btn.offset_bottom = -12
	_wrong_btn.visible = false
	_wrong_btn.add_theme_font_size_override("font_size", 15)
	_wrong_btn.pressed.connect(_end_turn_wrong)

	_new_btn = Button.new(); _layer.add_child(_new_btn)
	_new_btn.text          = "↩  New Game"
	_new_btn.anchor_left   = 0.5; _new_btn.anchor_right  = 0.5
	_new_btn.anchor_top    = 1.0; _new_btn.anchor_bottom = 1.0
	_new_btn.offset_left   = -110; _new_btn.offset_right  = 110
	_new_btn.offset_top    = -60;  _new_btn.offset_bottom = -12
	_new_btn.visible = false
	_new_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_build_stop_timer()

	_word_display = Label.new()
	_layer.add_child(_word_display)
	_word_display.anchor_left   = 0.5; _word_display.anchor_right  = 0.5
	_word_display.anchor_top    = 0.5; _word_display.anchor_bottom = 0.5
	_word_display.offset_left   = -260; _word_display.offset_right  = 260
	_word_display.offset_top    = -50;  _word_display.offset_bottom = 50
	_word_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word_display.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_word_display.add_theme_font_size_override("font_size", 56)
	_word_display.add_theme_color_override("font_color", Color.WHITE)
	_word_display.visible = false

	_build_tv_panel()
	_build_scoreboard()
	_build_game_over_panel()

# ═══════════════════════════════ State Machine ═══════════════════════════════

func _begin_round() -> void:
	_turn_sfx.play()
	_state              = State.PLAYING
	_time_left          = TURN_T
	_timing             = true
	_stop_clip.offset_top = 0.0
	_env.background_color = _timer_color(0.0)
	#_tbar.value         = 1.0
	#_tbar.visible       = true
	_wrong_btn.visible  = true
	_word_input.visible = true
	_submit_btn.visible = true
	_new_btn.visible    = false
	_word_input.text    = ""
	_word_input.placeholder_text = "Player %d — type your word..." % (_cur_player + 1)
	_word_input.grab_focus()
	_refresh_status()
	_update_tv()
	_refresh_scoreboard()
	_show("P %d\n▶ GO!" % (_cur_player + 1))

func _end_turn_wrong(word: String = "") -> void:
	if _state != State.PLAYING:
		return
	_wrong_sfx.play()
	_timing             = false
	_tbar.visible       = false
	_wrong_btn.visible  = false
	_word_input.visible = false
	_submit_btn.visible = false
	_state              = State.ROUND_END

	if word != "":
		_word_display.add_theme_color_override("font_color", Color.BLACK)
		_word_display.text    = word.to_upper()
		_word_display.visible = true
		_env.background_color = Color(0.85, 0.10, 0.10)
		_stop_clip.offset_top = 0.0

	if _cur_player < GameState.penalties.size():
		GameState.penalties[_cur_player] += 1
	_refresh_scoreboard()

	var loser := _cur_player
	_show("P %d\nOut!" % (loser + 1))
	_update_tv()

	GameState.blocked.clear()
	GameState.cur_player = (loser + 1) % _num_players

	if GameState.penalties[loser] >= _max_penalties:
		_status.text = "Player %d is eliminated! Game over!" % (loser + 1)
		await get_tree().create_timer(2.0).timeout
		_show_game_over()
		return

	_status.text = "Player %d is out!  Next round in 3 seconds..." % (loser + 1)
	await get_tree().create_timer(3.0).timeout
	if _state == State.ROUND_END:
		get_tree().change_scene_to_file("res://scenes/card_selection.tscn")

# ═══════════════════════════════ Button & Word Input ═════════════════════════

func _on_btn_input(_cam: Node, ev: InputEvent, _p: Vector3, _n: Vector3, _si: int, letter: String) -> void:
	if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed):
		return
	if _state != State.PLAYING:
		return
	_use_letter(letter)

func _on_word_submitted(word: String) -> void:
	if _state != State.PLAYING:
		return
	word = word.strip_edges()
	if word.is_empty():
		return
	var l := WordLists.normalize_word(word).unicode_at(0)
	var letter := String.chr(l).to_upper()
	_word_input.text = ""
	_word_input.grab_focus()
	if not LETTERS.has(letter) or letter == "?":
		_end_turn_wrong(word)
		return
	if not WordLists.has_word(_topic, word):
		_end_turn_wrong(word)
		return
	_success_sfx.play()
	_use_letter(letter, word)

func _use_letter(letter: String, word: String = "") -> void:
	if letter == "?":
		var free: Array[String] = []
		for l in LETTERS:
			if l != "?" and not _blocked.has(l) and _mats.has(l):
				free.append(l)
		if free.is_empty():
			_show("Board\nFull!")
			_blocked.clear()
			_reset_all_buttons()
			return
		var picked := free[randi() % free.size()]
		_block_letter(picked)
		_show("★→%s" % picked)
	elif _blocked.has(letter):
		if not _blocked.has("?"):
			_block_letter("?")
			_show("?")
		else:
			_end_turn_wrong(word)
			return
	else:
		_block_letter(letter)
		_show(letter)

	_timing = false
	_word_input.visible = false
	_submit_btn.visible = false
	_wrong_btn.visible  = false
	_cur_player = (_cur_player + 1) % _num_players

	if word != "":
		_word_display.add_theme_color_override("font_color", Color.WHITE)
		_word_display.text    = word.to_upper()
		_word_display.visible = true
		_stop_clip.offset_top = 0.0
		_env.background_color = Color(0.20, 0.80, 0.20)
		await get_tree().create_timer(1.0).timeout
		_word_display.visible = false

	_begin_round()

func _block_letter(l: String) -> void:
	if _blocked.has(l):
		return
	_blocked.append(l)
	if _mats.has(l):
		(_mats[l] as StandardMaterial3D).albedo_color = C_BLOCKED

func _on_hover(letter: String, entered: bool) -> void:
	if _blocked.has(letter):
		return
	var base := C_WILD if letter == "?" else C_BTN
	(_mats[letter] as StandardMaterial3D).albedo_color = C_HOVER if entered else base

func _reset_all_buttons() -> void:
	for l in LETTERS:
		(_mats[l] as StandardMaterial3D).albedo_color = C_WILD if l == "?" else C_BTN

# ═══════════════════════════════ Helpers ════════════════════════════════════

func _show(_text: String) -> void:
	pass

func _refresh_status() -> void:
	var free := 0
	for l in LETTERS:
		if l != "?" and not _blocked.has(l):
			free += 1
	_status.text = "Player %d's turn  ·  Topic: %s  ·  %d letters left" % [
		_cur_player + 1, _topic, free
	]

func _build_tv_panel() -> void:
	_tv_panel = Panel.new()
	_layer.add_child(_tv_panel)
	_tv_panel.anchor_left   = 1.0; _tv_panel.anchor_right  = 1.0
	_tv_panel.anchor_top    = 0.0; _tv_panel.anchor_bottom = 0.0
	_tv_panel.offset_left   = -245; _tv_panel.offset_right  = -12
	_tv_panel.offset_top    = 12;   _tv_panel.offset_bottom = 158
	_tv_panel.visible = false

	var body_style := StyleBoxFlat.new()
	body_style.bg_color                   = Color(0.13, 0.13, 0.16)
	body_style.corner_radius_top_left     = 10
	body_style.corner_radius_top_right    = 10
	body_style.corner_radius_bottom_left  = 10
	body_style.corner_radius_bottom_right = 10
	body_style.border_width_left   = 2; body_style.border_width_right  = 2
	body_style.border_width_top    = 2; body_style.border_width_bottom  = 2
	body_style.border_color = Color(0.22, 0.22, 0.26)
	_tv_panel.add_theme_stylebox_override("panel", body_style)

	var screen := Panel.new()
	_tv_panel.add_child(screen)
	screen.anchor_left = 0; screen.anchor_right  = 1
	screen.anchor_top  = 0; screen.anchor_bottom = 1
	screen.offset_left = 9; screen.offset_right  = -9
	screen.offset_top  = 9; screen.offset_bottom = -26

	var scr_style := StyleBoxFlat.new()
	scr_style.bg_color                    = Color(0.04, 0.04, 0.04)
	scr_style.corner_radius_top_left      = 5
	scr_style.corner_radius_top_right     = 5
	scr_style.corner_radius_bottom_left   = 5
	scr_style.corner_radius_bottom_right  = 5
	scr_style.border_width_left = 3
	scr_style.border_color = Color(0.90, 0.03, 0.08)
	screen.add_theme_stylebox_override("panel", scr_style)

	var margin := MarginContainer.new()
	screen.add_child(margin)
	margin.anchor_left = 0; margin.anchor_right  = 1
	margin.anchor_top  = 0; margin.anchor_bottom = 1
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom",  8)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	vb.add_child(hb)

	var n_lbl := Label.new()
	n_lbl.text = "N"
	n_lbl.add_theme_font_size_override("font_size", 30)
	n_lbl.add_theme_color_override("font_color", Color(0.90, 0.03, 0.08))
	n_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(n_lbl)

	var info_vb := VBoxContainer.new()
	info_vb.add_theme_constant_override("separation", 1)
	hb.add_child(info_vb)

	var a_cont := Label.new()
	a_cont.text = "A continuación"
	a_cont.add_theme_font_size_override("font_size", 10)
	a_cont.add_theme_color_override("font_color", Color(0.60, 0.60, 0.60))
	info_vb.add_child(a_cont)

	var sig_lbl := Label.new()
	sig_lbl.text = "SIGUIENTE"
	sig_lbl.add_theme_font_size_override("font_size", 13)
	sig_lbl.add_theme_color_override("font_color", Color(0.90, 0.03, 0.08))
	info_vb.add_child(sig_lbl)

	var div := Label.new()
	div.text = "────────────────────"
	div.add_theme_font_size_override("font_size", 9)
	div.add_theme_color_override("font_color", Color(0.90, 0.03, 0.08, 0.45))
	vb.add_child(div)

	_tv_next_lbl = Label.new()
	_tv_next_lbl.add_theme_font_size_override("font_size", 28)
	_tv_next_lbl.add_theme_color_override("font_color", Color.WHITE)
	_tv_next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_tv_next_lbl)

	var legs := HBoxContainer.new()
	legs.alignment = BoxContainer.ALIGNMENT_CENTER
	legs.add_theme_constant_override("separation", 40)
	_tv_panel.add_child(legs)
	legs.anchor_left = 0; legs.anchor_right  = 1
	legs.anchor_top  = 1; legs.anchor_bottom = 1
	legs.offset_top  = -22; legs.offset_bottom = 0

	for _i in 2:
		var leg := Label.new()
		leg.text = "▌"
		leg.add_theme_font_size_override("font_size", 14)
		leg.add_theme_color_override("font_color", Color(0.22, 0.22, 0.26))
		legs.add_child(leg)

func _build_scoreboard() -> void:
	# Ensure penalties array is sized for current players
	if GameState.penalties.size() != _num_players:
		GameState.penalties.resize(_num_players)
		GameState.penalties.fill(0)

	var row_h   := 22
	var panel_h := 16 + 30 + 12 + _num_players * row_h

	_score_panel = Panel.new()
	_layer.add_child(_score_panel)
	_score_panel.anchor_left   = 1.0; _score_panel.anchor_right  = 1.0
	_score_panel.anchor_top    = 1.0; _score_panel.anchor_bottom = 1.0
	_score_panel.offset_left   = -232; _score_panel.offset_right  = -12
	_score_panel.offset_top    = -(panel_h + 12); _score_panel.offset_bottom = -12

	var style := StyleBoxFlat.new()
	style.bg_color                    = Color(0.10, 0.10, 0.13, 0.90)
	style.corner_radius_top_left      = 8
	style.corner_radius_top_right     = 8
	style.corner_radius_bottom_left   = 8
	style.corner_radius_bottom_right  = 8
	style.border_width_left = 1; style.border_width_right  = 1
	style.border_width_top  = 1; style.border_width_bottom = 1
	style.border_color = Color(0.25, 0.25, 0.30)
	_score_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	_score_panel.add_child(margin)
	margin.anchor_left = 0; margin.anchor_right  = 1
	margin.anchor_top  = 0; margin.anchor_bottom = 1
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_bottom",  8)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	margin.add_child(vb)

	# Header
	var hdr := HBoxContainer.new()
	vb.add_child(hdr)

	var hdr_name := Label.new()
	hdr_name.text = "Players"
	hdr_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_name.add_theme_font_size_override("font_size", 11)
	hdr_name.add_theme_color_override("font_color", Color(0.60, 0.60, 0.65))
	hdr.add_child(hdr_name)

	var hdr_pen := Label.new()
	hdr_pen.text = "Penalties"
	hdr_pen.custom_minimum_size = Vector2(68, 0)
	hdr_pen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr_pen.add_theme_font_size_override("font_size", 11)
	hdr_pen.add_theme_color_override("font_color", Color(0.60, 0.60, 0.65))
	hdr.add_child(hdr_pen)

	var div := Label.new()
	div.text = "─────────────────────"
	div.add_theme_font_size_override("font_size", 8)
	div.add_theme_color_override("font_color", Color(0.30, 0.30, 0.35))
	vb.add_child(div)

	# One row per player
	_score_name_lbls.clear()
	_score_pen_lbls.clear()
	for i in _num_players:
		var row := HBoxContainer.new()
		vb.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = "Player %d" % (i + 1)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(name_lbl)
		_score_name_lbls.append(name_lbl)

		var pen_lbl := Label.new()
		pen_lbl.text = ""
		pen_lbl.custom_minimum_size = Vector2(68, 0)
		pen_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pen_lbl.add_theme_font_size_override("font_size", 14)
		pen_lbl.add_theme_color_override("font_color", Color(0.92, 0.40, 0.40))
		row.add_child(pen_lbl)
		_score_pen_lbls.append(pen_lbl)

func _refresh_scoreboard() -> void:
	for i in _num_players:
		var is_cur  := (i == _cur_player and _state == State.PLAYING)
		var c_name  := Color(0.98, 0.78, 0.20) if is_cur else Color.WHITE
		_score_name_lbls[i].add_theme_color_override("font_color", c_name)
		var pen := GameState.penalties[i] if i < GameState.penalties.size() else 0
		_score_pen_lbls[i].text = "" if pen == 0 else str(pen)

func _update_tv() -> void:
	if _state == State.PLAYING and _num_players > 1:
		var next := (_cur_player + 1) % _num_players
		_tv_next_lbl.text = "Jugador %d" % (next + 1)
		_tv_panel.visible = true
	else:
		_tv_panel.visible = false

func _build_game_over_panel() -> void:
	_game_over_overlay = Control.new()
	_layer.add_child(_game_over_overlay)
	_game_over_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over_overlay.visible = false

	var bg := ColorRect.new()
	_game_over_overlay.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.82)

	var panel_w := 440.0
	var panel_h := 190.0 + _num_players * 40.0 + 60.0

	var panel := Panel.new()
	_game_over_overlay.add_child(panel)
	panel.anchor_left   = 0.5; panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left   = -panel_w * 0.5; panel.offset_right  = panel_w * 0.5
	panel.offset_top    = -panel_h * 0.5; panel.offset_bottom = panel_h * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color                    = Color(0.10, 0.10, 0.13, 1.0)
	style.corner_radius_top_left      = 12
	style.corner_radius_top_right     = 12
	style.corner_radius_bottom_left   = 12
	style.corner_radius_bottom_right  = 12
	style.border_width_left = 2; style.border_width_right  = 2
	style.border_width_top  = 2; style.border_width_bottom = 2
	style.border_color = Color(0.90, 0.03, 0.08)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	panel.add_child(margin)
	margin.anchor_left = 0; margin.anchor_right  = 1
	margin.anchor_top  = 0; margin.anchor_bottom = 1
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_top",    22)
	margin.add_theme_constant_override("margin_bottom", 22)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.90, 0.03, 0.08))
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Final Scoreboard"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.60, 0.60, 0.65))
	vb.add_child(subtitle)

	var div := Label.new()
	div.text = "─────────────────────────────────────"
	div.add_theme_font_size_override("font_size", 9)
	div.add_theme_color_override("font_color", Color(0.30, 0.30, 0.35))
	vb.add_child(div)

	var hdr := HBoxContainer.new()
	vb.add_child(hdr)

	var hdr_name := Label.new()
	hdr_name.text = "Player"
	hdr_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_name.add_theme_font_size_override("font_size", 11)
	hdr_name.add_theme_color_override("font_color", Color(0.60, 0.60, 0.65))
	hdr.add_child(hdr_name)

	var hdr_tick := Label.new()
	hdr_tick.text = "Tickets"
	hdr_tick.custom_minimum_size = Vector2(110, 0)
	hdr_tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr_tick.add_theme_font_size_override("font_size", 11)
	hdr_tick.add_theme_color_override("font_color", Color(0.60, 0.60, 0.65))
	hdr.add_child(hdr_tick)

	_go_name_lbls.clear()
	_go_ticket_lbls.clear()

	for i in _num_players:
		var row := HBoxContainer.new()
		vb.add_child(row)

		var n_lbl := Label.new()
		n_lbl.text = "Player %d" % (i + 1)
		n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n_lbl.add_theme_font_size_override("font_size", 19)
		n_lbl.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(n_lbl)
		_go_name_lbls.append(n_lbl)

		var t_lbl := Label.new()
		var empty_dots := ""
		for _d in _max_penalties:
			empty_dots += "○ "
		t_lbl.text = empty_dots.strip_edges()
		t_lbl.custom_minimum_size = Vector2(110, 0)
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t_lbl.add_theme_font_size_override("font_size", 17)
		t_lbl.add_theme_color_override("font_color", Color(0.92, 0.82, 0.12))
		row.add_child(t_lbl)
		_go_ticket_lbls.append(t_lbl)

	var div2 := Label.new()
	div2.text = "─────────────────────────────────────"
	div2.add_theme_font_size_override("font_size", 9)
	div2.add_theme_color_override("font_color", Color(0.30, 0.30, 0.35))
	vb.add_child(div2)

	var new_game_btn := Button.new()
	new_game_btn.text = "↩  New Game"
	new_game_btn.add_theme_font_size_override("font_size", 18)
	new_game_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_game_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	vb.add_child(new_game_btn)

func _show_game_over() -> void:
	_state = State.GAME_OVER
	_wrong_btn.visible    = false
	_word_input.visible   = false
	_submit_btn.visible   = false
	_new_btn.visible      = false
	_tv_panel.visible     = false
	_word_display.visible = false
	_stop_holder.visible  = false

	for i in _num_players:
		var pen := GameState.penalties[i] if i < GameState.penalties.size() else 0
		var dots := ""
		for d in _max_penalties:
			dots += ("● " if d < pen else "○ ")
		_go_ticket_lbls[i].text = dots.strip_edges()
		if pen >= _max_penalties:
			_go_name_lbls[i].add_theme_color_override("font_color", Color(0.90, 0.03, 0.08))
			_go_ticket_lbls[i].add_theme_color_override("font_color", Color(0.90, 0.03, 0.08))

	_game_over_overlay.visible = true
