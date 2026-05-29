extends Node3D

# ── Letters (A-Y minus W, X, Z) + wildcard ────────────────────────────────────
const LETTERS: Array[String] = [
	"A","B","C","D","E","F","G","H","I","J","K","L",
	"M","N","O","P","Q","R","S","T","U","V","Y","?"
]

# ── Card deck (pairs of topics) ───────────────────────────────────────────────
const DECK: Array = [
	["RED THINGS",       "SUPERPOWERS"],
	["ANIMALS",          "SPORTS"],
	["COUNTRIES",        "FOODS"],
	["MOVIES",           "JOBS"],
	["FRUITS",           "COLORS"],
	["FAMOUS PEOPLE",    "VEHICLES"],
	["KITCHEN ITEMS",    "MUSIC GENRES"],
	["BEACH THINGS",     "TV SHOWS"],
	["SCHOOL SUBJECTS",  "CLOTHING"],
	["CAPITAL CITIES",   "DRINKS"],
	["THINGS THAT FLY",  "BOARD GAMES"],
	["FAMOUS BRANDS",    "FAIRY TALE CHARS"],
	["PARK THINGS",      "WATER SPORTS"],
	["HOLIDAYS",         "BODY PARTS"],
	["PLANTS",           "DANCE STYLES"],
	["GLOWING THINGS",   "MYTHICAL CREATURES"],
	["COLD THINGS",      "CARTOON CHARACTERS"],
	["MAP THINGS",       "INSTRUMENTS"],
	["SWEET FOODS",      "OLYMPIC SPORTS"],
	["SPACE THINGS",     "PROFESSIONS"],
]

# ── Dimensions ────────────────────────────────────────────────────────────────
const BOARD_R := 5.2
const RING_R  := 4.0
const BTN_R   := 0.40
const TURN_T  := 8.0     # seconds each player has to say a word

# ── Colors ────────────────────────────────────────────────────────────────────
const C_BOARD    := Color(0.72, 0.08, 0.08)   # red board
const C_CENTER   := Color(0.48, 0.04, 0.04)   # dark-red center disc
const C_RIM      := Color(0.96, 0.96, 0.96)   # white

const C_BTN      := Color(0.96, 0.96, 0.96)   # white button
const C_WILD     := Color(0.92, 0.82, 0.12)   # gold wildcard
const C_HOVER    := Color(1.00, 0.82, 0.82)   # light-red hover
const C_BLOCKED  := Color(0.30, 0.30, 0.32)   # dark-gray blocked

const C_TXT_ON   := Color(0.05, 0.05, 0.05)   # black text (active)
const C_TXT_OFF  := Color(0.55, 0.55, 0.55)   # gray text (blocked)
const C_CTR_TXT  := Color.WHITE                # white center label

# ── Game state ────────────────────────────────────────────────────────────────
enum State { SETUP, CARD_DRAWN, PLAYING, ROUND_END }

var _state        : State  = State.SETUP
var _num_players  : int    = 2
var _cur_player   : int    = 0
var _topic        : String = ""
var _blocked      : Array[String] = []
var _cur_card     : Array  = []
var _deck_seq     : Array  = []
var _deck_pos     : int    = 0
var _time_left    : float  = TURN_T
var _timing       : bool   = false

# ── 3D node refs ──────────────────────────────────────────────────────────────
var _ctr_lbl  : Label3D
var _mats     : Dictionary = {}   # letter -> StandardMaterial3D
var _lbls     : Dictionary = {}   # letter -> Label3D

var _card_nd  : Node3D
var _card_lbl : Label3D

# ── UI node refs ──────────────────────────────────────────────────────────────
var _layer       : CanvasLayer
var _status      : Label
var _tbar        : ProgressBar

var _setup_pnl   : PanelContainer
var _ply_lbl     : Label

var _card_panel  : PanelContainer
var _card_title  : Label
var _t1_btn      : Button
var _t2_btn      : Button

var _wrong_btn   : Button
var _new_btn     : Button

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_3d()
	_build_ui()
	_enter_setup()

func _process(delta: float) -> void:
	if _timing and _state == State.PLAYING:
		_time_left -= delta
		_tbar.value = _time_left / TURN_T
		if _time_left <= 0.0:
			_timing = false
			_end_turn_wrong()

# ═══════════════════════════════ 3D Scene ════════════════════════════════════

func _build_3d() -> void:
	_add_camera()
	_add_env()
	_add_board()
	_add_center()
	_add_buttons()
	_add_card_node()

func _add_camera() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 13.0, 7.5)
	cam.look_at(Vector3.ZERO)
	cam.current = true

func _add_env() -> void:
	var we  := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = Color(0.06, 0.01, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.60, 0.38, 0.38)
	env.ambient_light_energy = 0.75
	we.environment = env
	add_child(we)

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

func _add_board() -> void:
	# CylinderMesh with 8 radial segments = octagonal prism
	var mi := MeshInstance3D.new(); add_child(mi)
	var cm := CylinderMesh.new()
	cm.top_radius      = BOARD_R
	cm.bottom_radius   = BOARD_R
	cm.height          = 0.14
	cm.radial_segments = 8
	mi.mesh = cm; mi.material_override = _mat(C_BOARD, 0.65)

	# Gold rim: one box per edge, centred on each face of the octagon.
	# apothem = perpendicular distance from centre to edge midpoint.
	# edge_len = length of one edge.
	# Rotation: local +X must align with the edge tangent direction,
	#   which requires rotation.y = -(mid_angle + π/2).
	var sides    := 8
	var apothem  := BOARD_R * cos(PI / float(sides))
	var edge_len := 2.0 * BOARD_R * sin(PI / float(sides))

	for i in sides:
		var mid_angle := (TAU * float(i) / float(sides)) + PI / float(sides)
		var seg := MeshInstance3D.new(); add_child(seg)
		var bm  := BoxMesh.new()
		bm.size        = Vector3(edge_len, 0.14, 0.18)
		seg.mesh       = bm
		seg.position   = Vector3(cos(mid_angle) * apothem, 0.07, sin(mid_angle) * apothem)
		seg.rotation.y = -(mid_angle + PI * 0.5)
		seg.material_override = _mat(C_RIM, 0.20, 0.85)

func _add_center() -> void:
	var mi := MeshInstance3D.new(); add_child(mi)
	var cm := CylinderMesh.new()
	cm.top_radius = 1.55; cm.bottom_radius = 1.55; cm.height = 0.22
	mi.mesh = cm; mi.position.y = 0.01
	mi.material_override = _mat(C_CENTER, 0.65)

	var ring := MeshInstance3D.new(); add_child(ring)
	var rm   := TorusMesh.new()
	rm.inner_radius = 1.48; rm.outer_radius = 1.62
	ring.mesh = rm; ring.position.y = 0.12
	ring.material_override = _mat(C_RIM, 0.20, 0.85)

	_ctr_lbl = Label3D.new(); add_child(_ctr_lbl)
	_ctr_lbl.position             = Vector3(0, 0.26, 0)
	_ctr_lbl.billboard            = BaseMaterial3D.BILLBOARD_ENABLED
	_ctr_lbl.font_size            = 52
	_ctr_lbl.modulate             = C_CTR_TXT
	_ctr_lbl.outline_size         = 6
	_ctr_lbl.outline_modulate     = Color(0, 0, 0, 0.9)
	_ctr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _add_buttons() -> void:
	var n := LETTERS.size()
	for i in n:
		var a := (TAU * float(i) / float(n)) - PI * 0.5
		_spawn_btn(LETTERS[i], Vector3(cos(a) * RING_R, 0.14, sin(a) * RING_R))

func _spawn_btn(letter: String, pos: Vector3) -> void:
	var wild := letter == "?"

	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)

	var mi  := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = BTN_R; cyl.bottom_radius = BTN_R; cyl.height = 0.18
	mi.mesh = cyl
	var mat := _mat(C_WILD if wild else C_BTN, 0.35)
	mi.material_override = mat
	body.add_child(mi)
	_mats[letter] = mat

	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new(); sh.radius = BTN_R; sh.height = 0.18
	cs.shape = sh; body.add_child(cs)

	var lbl := Label3D.new()
	lbl.text     = letter
	lbl.position = Vector3(0, 0.12, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 36
	# White text with black outline on white button → use black text, white outline
	lbl.modulate         = C_TXT_ON
	lbl.outline_size     = 4
	lbl.outline_modulate = Color(1, 1, 1, 0.8)
	body.add_child(lbl)
	_lbls[letter] = lbl

	body.input_event.connect(_on_btn_input.bind(letter))
	body.mouse_entered.connect(_on_hover.bind(letter, true))
	body.mouse_exited.connect(_on_hover.bind(letter, false))

# ── Floating card in 3D ──────────────────────────────────────────────────────
func _add_card_node() -> void:
	_card_nd = Node3D.new()
	_card_nd.position         = Vector3(0, 2.8, 0)
	_card_nd.rotation_degrees = Vector3(-28, 0, 0)   # tilt toward camera
	_card_nd.visible          = false
	add_child(_card_nd)

	# Card background
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(3.6, 2.4, 0.06)
	mi.mesh = bm; mi.material_override = _mat(Color(0.98, 0.96, 0.86), 0.8)
	_card_nd.add_child(mi)

	# Card border (slightly larger, behind)
	var fr := MeshInstance3D.new()
	var fm := BoxMesh.new(); fm.size = Vector3(3.75, 2.55, 0.04)
	fr.mesh = fm; fr.position.z = -0.03
	fr.material_override = _mat(Color(0.25, 0.10, 0.02), 0.6, 0.3)
	_card_nd.add_child(fr)

	_card_lbl = Label3D.new()
	_card_lbl.position             = Vector3(0, 0, 0.05)
	_card_lbl.billboard            = BaseMaterial3D.BILLBOARD_DISABLED
	_card_lbl.font_size            = 26
	_card_lbl.modulate             = Color(0.08, 0.03, 0.0)
	_card_lbl.outline_size         = 2
	_card_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_nd.add_child(_card_lbl)

# ═══════════════════════════════ 2D UI ═══════════════════════════════════════

func _build_ui() -> void:
	_layer = CanvasLayer.new(); add_child(_layer)

	# ── Top status bar ────────────────────────────────────────────────────
	_status = Label.new(); _layer.add_child(_status)
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_status.offset_top    = 8
	_status.offset_bottom = 44
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_color_override("font_color", Color.WHITE)

	# ── Timer bar (below status) ──────────────────────────────────────────
	_tbar = ProgressBar.new(); _layer.add_child(_tbar)
	_tbar.anchor_left = 0.5; _tbar.anchor_right = 0.5
	_tbar.offset_left = -220; _tbar.offset_right = 220
	_tbar.offset_top  = 48;   _tbar.offset_bottom = 66
	_tbar.max_value = 1.0; _tbar.value = 1.0
	_tbar.visible = false

	# ── Setup panel ───────────────────────────────────────────────────────
	_setup_pnl = PanelContainer.new(); _layer.add_child(_setup_pnl)
	_setup_pnl.anchor_left   = 0.5; _setup_pnl.anchor_right  = 0.5
	_setup_pnl.anchor_top    = 0.5; _setup_pnl.anchor_bottom = 0.5
	_setup_pnl.offset_left   = -180; _setup_pnl.offset_right  = 180
	_setup_pnl.offset_top    = -110; _setup_pnl.offset_bottom = 110

	var sv := VBoxContainer.new(); _setup_pnl.add_child(sv)
	sv.add_theme_constant_override("separation", 14)

	var ttl := Label.new(); ttl.text = "STOP!"; sv.add_child(ttl)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.add_theme_font_size_override("font_size", 42)

	var sub := Label.new(); sub.text = "Number of players:"; sv.add_child(sub)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var row := HBoxContainer.new(); sv.add_child(row)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)

	var minus := Button.new(); minus.text = "  −  "; row.add_child(minus)
	minus.pressed.connect(func(): _change_players(-1))

	_ply_lbl = Label.new(); _ply_lbl.text = "2"; row.add_child(_ply_lbl)
	_ply_lbl.custom_minimum_size = Vector2(44, 0)
	_ply_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ply_lbl.add_theme_font_size_override("font_size", 30)

	var plus := Button.new(); plus.text = "  +  "; row.add_child(plus)
	plus.pressed.connect(func(): _change_players(1))

	var start := Button.new(); start.text = "▶  Start Game"; sv.add_child(start)
	start.pressed.connect(_on_start)
	start.add_theme_font_size_override("font_size", 18)

	# ── Card topic selection panel ────────────────────────────────────────
	_card_panel = PanelContainer.new(); _layer.add_child(_card_panel)
	_card_panel.anchor_left   = 0.5; _card_panel.anchor_right  = 0.5
	_card_panel.anchor_top    = 0.5; _card_panel.anchor_bottom = 0.5
	_card_panel.offset_left   = -260; _card_panel.offset_right  = 260
	_card_panel.offset_top    = -85;  _card_panel.offset_bottom = 85
	_card_panel.visible = false

	var cv := VBoxContainer.new(); _card_panel.add_child(cv)
	cv.add_theme_constant_override("separation", 12)

	_card_title = Label.new(); cv.add_child(_card_title)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.add_theme_font_size_override("font_size", 17)

	var ch := HBoxContainer.new(); cv.add_child(ch)
	ch.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.add_theme_constant_override("separation", 20)

	_t1_btn = Button.new(); ch.add_child(_t1_btn)
	_t1_btn.custom_minimum_size = Vector2(200, 52)
	_t1_btn.pressed.connect(func(): _pick_topic(0))

	_t2_btn = Button.new(); ch.add_child(_t2_btn)
	_t2_btn.custom_minimum_size = Vector2(200, 52)
	_t2_btn.pressed.connect(func(): _pick_topic(1))

	# ── "Wrong Word" button (bottom center, shown while playing) ──────────
	_wrong_btn = Button.new(); _layer.add_child(_wrong_btn)
	_wrong_btn.text          = "⚠  Wrong Word / Time's Up"
	_wrong_btn.anchor_left   = 0.5; _wrong_btn.anchor_right  = 0.5
	_wrong_btn.anchor_top    = 1.0; _wrong_btn.anchor_bottom = 1.0
	_wrong_btn.offset_left   = -175; _wrong_btn.offset_right  = 175
	_wrong_btn.offset_top    = -60;  _wrong_btn.offset_bottom = -12
	_wrong_btn.visible = false
	_wrong_btn.add_theme_font_size_override("font_size", 15)
	_wrong_btn.pressed.connect(_end_turn_wrong)

	# ── "New Game" button (shown after game ends) ─────────────────────────
	_new_btn = Button.new(); _layer.add_child(_new_btn)
	_new_btn.text          = "↩  New Game"
	_new_btn.anchor_left   = 0.5; _new_btn.anchor_right  = 0.5
	_new_btn.anchor_top    = 1.0; _new_btn.anchor_bottom = 1.0
	_new_btn.offset_left   = -110; _new_btn.offset_right  = 110
	_new_btn.offset_top    = -60;  _new_btn.offset_bottom = -12
	_new_btn.visible = false
	_new_btn.pressed.connect(_enter_setup)

# ═══════════════════════════════ State Machine ═══════════════════════════════

func _enter_setup() -> void:
	_state        = State.SETUP
	_blocked.clear()
	_cur_player   = 0
	_timing       = false
	_reset_all_buttons()
	_setup_pnl.visible   = true
	_card_panel.visible  = false
	_card_nd.visible     = false
	_wrong_btn.visible   = false
	_new_btn.visible     = false
	_tbar.visible        = false
	_status.text         = ""
	_show("STOP!")

func _draw_card() -> void:
	if _state == State.SETUP:
		return
	_state = State.CARD_DRAWN
	_wrong_btn.visible  = false
	_tbar.visible       = false
	_timing             = false

	if _deck_pos >= _deck_seq.size():
		_shuffle_deck()
	_cur_card = DECK[_deck_seq[_deck_pos]]
	_deck_pos += 1

	# 3D card
	_card_lbl.text   = "① %s\n\n② %s" % [_cur_card[0], _cur_card[1]]
	_card_nd.visible = true

	# 2D panel
	_card_title.text = "Player %d — choose a topic:" % (_cur_player + 1)
	_t1_btn.text     = "① " + _cur_card[0]
	_t2_btn.text     = "② " + _cur_card[1]
	_card_panel.visible = true

	_status.text = "Player %d: pick a topic from the card" % (_cur_player + 1)
	_show("P %d\nPick!" % (_cur_player + 1))

func _pick_topic(idx: int) -> void:
	_topic              = _cur_card[idx]
	_card_panel.visible = false
	_card_nd.visible    = false
	_begin_round()

func _begin_round() -> void:
	_state     = State.PLAYING
	_time_left = TURN_T
	_timing    = true
	_tbar.value   = 1.0
	_tbar.visible = true
	_wrong_btn.visible = true
	_refresh_status()
	_show("P %d\n▶ GO!" % (_cur_player + 1))

# ── Called when current player says a wrong word or timer expires ─────────────
func _end_turn_wrong() -> void:
	if _state != State.PLAYING:
		return
	_timing            = false
	_tbar.visible      = false
	_wrong_btn.visible = false
	_state             = State.ROUND_END

	_show("P %d\nOut!" % (_cur_player + 1))
	_status.text = "Player %d is out!  Next round in 3 seconds..." % (_cur_player + 1)

	_blocked.clear()
	_reset_all_buttons()
	_cur_player = (_cur_player + 1) % _num_players

	_wait_then_draw()

func _wait_then_draw() -> void:
	await get_tree().create_timer(3.0).timeout
	if _state == State.ROUND_END:
		_draw_card()

# ═══════════════════════════════ Button Interaction ══════════════════════════

func _on_btn_input(_cam: Node, ev: InputEvent, _p: Vector3, _n: Vector3, _si: int, letter: String) -> void:
	if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed):
		return
	if _state != State.PLAYING:
		return
	_use_letter(letter)

# Player says a word starting with this letter
func _use_letter(letter: String) -> void:
	if letter == "?":
		# Wildcard → randomly picks and blocks one free letter
		var free: Array[String] = []
		for l in LETTERS:
			if l != "?" and not _blocked.has(l):
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
		# Saying a word that starts with a blocked letter = wrong
		_end_turn_wrong()
		return
	else:
		_block_letter(letter)
		_show(letter)

	# Pass turn to next player
	_cur_player = (_cur_player + 1) % _num_players
	_time_left  = TURN_T
	_tbar.value = 1.0
	_refresh_status()

func _block_letter(l: String) -> void:
	if _blocked.has(l):
		return
	_blocked.append(l)
	(_mats[l] as StandardMaterial3D).albedo_color = C_BLOCKED
	(_lbls[l] as Label3D).modulate = C_TXT_OFF

func _on_hover(letter: String, entered: bool) -> void:
	if _blocked.has(letter):
		return   # blocked buttons don't respond to hover
	var base := C_WILD if letter == "?" else C_BTN
	(_mats[letter] as StandardMaterial3D).albedo_color = C_HOVER if entered else base

func _reset_all_buttons() -> void:
	for l in LETTERS:
		(_mats[l] as StandardMaterial3D).albedo_color = C_WILD if l == "?" else C_BTN
		(_lbls[l] as Label3D).modulate = C_TXT_ON

# ═══════════════════════════════ Helpers ════════════════════════════════════

func _show(text: String) -> void:
	_ctr_lbl.text = text

func _refresh_status() -> void:
	var free := 0
	for l in LETTERS:
		if l != "?" and not _blocked.has(l):
			free += 1
	_status.text = "Player %d's turn  ·  Topic: %s  ·  %d letters left" % [
		_cur_player + 1, _topic, free
	]

func _change_players(delta: int) -> void:
	_num_players  = clampi(_num_players + delta, 2, 8)
	_ply_lbl.text = str(_num_players)

func _on_start() -> void:
	_setup_pnl.visible = false
	_shuffle_deck()
	_draw_card()

func _shuffle_deck() -> void:
	_deck_seq = range(DECK.size())
	_deck_seq.shuffle()
	_deck_pos = 0
