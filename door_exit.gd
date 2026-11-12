extends Area2D

var is_open = false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Player":
		if body.keys > 0:
			if not is_open:
				print("Grattis! Du klarade spelet!")
				is_open = true
				body.keys -= 1
				
				$ClosedDoor.visible = false
				$OpenDoor.visible = true
				$Doorbody/WallCollision.set_deferred("disabled", true)
				
				# Gör spelaren helt odödlig genom att stänga av dess kollision med vakter direkt!
				if body.has_node("CollisionShape2D"):
					body.get_node("CollisionShape2D").set_deferred("disabled", true)
				
				# Vänta 1 sekund och byt till vinstskärmen (eftersom spelarens kollision är av kan vakterna inte röra dig)
				await get_tree().create_timer(1.0).timeout
				get_tree().change_scene_to_file("res://win_screen.tscn")
				
		else:
			if not is_open:
				print("Du behöver sista nyckeln för att klara spelet!")
