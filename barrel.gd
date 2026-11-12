extends Area2D

var player_in_range = false
var player_ref = null

@onready var prompt_label = $PromptLabel # Hämta labeln i tunnans scen

func _ready():
	prompt_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		player_in_range = true
		player_ref = body
		body.current_barrel = self 
		
		if not player_ref.is_hiding:
			prompt_label.text = "[Space] Göm dig"
			prompt_label.visible = true

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false
		if player_ref:
			player_ref.current_barrel = null 
		player_ref = null
		prompt_label.visible = false

func _unhandled_input(event):
	if player_in_range and event.is_action_pressed("ui_accept"):
		if player_ref and not player_ref.is_hiding:
			player_ref.hide_player(global_position)
			prompt_label.text = "[Space] Hoppa ur" # Byt text när man är i tunnan
