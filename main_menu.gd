extends Control

func _ready():
	# Hitta knappen och koppla ihop den när man klickar på den
	# Byt ut "Button" mot namnet på din knapp om den heter något annat
	$CenterContainer/VBoxContainer/Button.pressed.connect(_on_start_pressed)

func _on_start_pressed():
	# Byt till din riktiga spelbana (ändra sökvägen om din bana heter något annat)
	get_tree().change_scene_to_file("res://Level1.tscn")
