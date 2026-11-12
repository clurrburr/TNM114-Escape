extends Control

func _on_button_pressed():
	# Om du har använt get_tree().paused någonstans ser vi till att spelet inte är pausat längre
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")
