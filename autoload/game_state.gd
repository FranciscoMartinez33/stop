extends Node

var num_players  : int           = 2
var cur_player   : int           = 0
var topic        : String        = ""
var blocked      : Array[String] = []
var deck_seq     : Array         = []
var deck_pos     : int           = 0
var penalties    : Array[int]    = []
var max_penalties: int           = 3
var game_mode    : String        = "CLASSIC"  # "CLASSIC" or "WORLD_CUP"
