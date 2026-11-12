extends Area2D

var is_open = false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Player":
		if body.keys > 0:
			if not is_open:
				print("Dörren öppnas!")
				is_open = true
				body.keys -= 1 # Förbrukar en nyckel
				
				# Byt bilder
				$ClosedDoor.visible = false
				$OpenDoor.visible = true
				
				# Stäng av väggen
				$Doorbody/WallCollision.set_deferred("disabled", true)
				
				# Uppdatera kamerans gränser för Rum 2
				var camera = body.get_node_or_null("Camera2D")
				if camera:
					camera.limit_left = 20
					camera.limit_right = 1165
					camera.limit_top = -290
					camera.limit_bottom = -250
					
		else:
			if not is_open:
				print("Du behöver en nyckel!")
