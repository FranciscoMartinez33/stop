extends Node3D

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

const WC_DECK: Array = [
	["WC26 TEAMS",       "PLAYERS AWARDED IN WC"],
	["CHAMPIONS COUNTRIES",      "COUNTRIES NEVER WON WC"],
	["WC26 CITIES", "COUNTRIES NEVER PLAYED WC"],
	["PLAYERS CHAMPIONS",      "WC26 COUNTRIES NOT QUALIFIED"],
	["WC MASCOTS",       "WC BALLS"],
	["WC TOP SCORERS",     "WC26 MANAGERS"],
	["WC HOSTS",      "PLAYERS IN WC26"],
	["WC26 TEAMS",      "WC26 STADIUMS"],
	["COUNTRIES NEVER WON WC",       "PLAYERS CHAMPIONS"],
	["PLAYERS IN WC26",       "WC MASCOTS"],
]

var _cur_card   : Array  = []
var _topic_lbls : Array  = []   # [Label3D, Label3D]

func _ready() -> void:
	_build_scene()
	_draw_card()

func _build_scene() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 1.0, 5.0)
	cam.look_at(Vector3(0.0, 0.5, 0.0))
	cam.current = true

	var we  := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = Color(0.12, 0.12, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color.WHITE
	env.ambient_light_energy = 0.9
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.position = Vector3(4.0, 8.0, 6.0)
	sun.look_at(Vector3.ZERO)
	sun.light_energy = 1.2

	var layer := CanvasLayer.new()
	add_child(layer)
	var status := Label.new()
	layer.add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status.offset_top    = 8
	status.offset_bottom = 44
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 17)
	status.add_theme_color_override("font_color", Color.WHITE)
	status.text = "Player %d — choose a topic" % (GameState.cur_player + 1)

	_add_sign(-1, 0)
	_add_sign( 1, 1)

func _add_sign(side: int, idx: int) -> void:
	var scene := load("res://assets/topic/CartelTopic1.glb") as PackedScene
	if scene == null:
		push_error("card_selection: failed to load CartelTopic1.glb")
		return

	var sign := scene.instantiate() as Node3D
	sign.position = Vector3(side * -10.5, 4.0, -6.0)
	sign.rotation_degrees = Vector3(90, 0, 0) 
	sign.scale  = Vector3(1.0, 1.0, 1.0) 
	if side < 0:
		sign.scale.x = -1.0   # mirror so the arrow points left
	add_child(sign)

	# Label added to root (not sign) so it is never affected by the sign's negative scale
	var lbl := Label3D.new()
	lbl.text          = ""
	lbl.font_size     = 52
	lbl.pixel_size    = 0.005
	lbl.billboard     = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.modulate      = Color.WHITE
	lbl.outline_size  = 6
	lbl.position      = Vector3(side * 3.2, 0.6, 0.15)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)
	_topic_lbls.append(lbl)

	# Collision for click detection – also on root so transform is independent of sign scale
	var body := StaticBody3D.new()
	body.position = Vector3(side * 3.2, 0.5, 0.0)
	add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(3.2, 2.4, 0.6)
	cs.shape = sh
	body.add_child(cs)
	body.input_event.connect(_on_sign_input.bind(idx))

func _draw_card() -> void:
	var active_deck := WC_DECK if GameState.game_mode == "WORLD_CUP" else DECK
	if GameState.deck_pos >= GameState.deck_seq.size():
		GameState.deck_seq.shuffle()
		GameState.deck_pos = 0
	_cur_card = active_deck[GameState.deck_seq[GameState.deck_pos]]
	GameState.deck_pos += 1
	_topic_lbls[0].text = _cur_card[0]
	_topic_lbls[1].text = _cur_card[1]

func _on_sign_input(_cam: Node, ev: InputEvent, _p: Vector3, _n: Vector3, _si: int, idx: int) -> void:
	if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed):
		return
	GameState.topic = _cur_card[idx]
	get_tree().change_scene_to_file("res://scenes/main.tscn")
