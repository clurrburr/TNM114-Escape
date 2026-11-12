extends Control

func _ready():
	# Koppla knapparna (se till att sökvägarna stämmer med dina nodnamn)
	$CenterContainer/VBoxContainer/Button.pressed.connect(_on_restart_pressed)
	$CenterContainer/VBoxContainer/Button2.pressed.connect(_on_menu_pressed)

func _on_restart_pressed():
	# Starta om banan
	get_tree().change_scene_to_file("res://Level1.tscn")

func _on_menu_pressed():
	# Gå tillbaka till huvudmenyn
	get_tree().change_scene_to_file("res://MainMenu.tscn")
