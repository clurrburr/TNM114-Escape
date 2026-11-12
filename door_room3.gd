extends Area2D

var is_open = false
@export var required_keys: int = 2 # Ändra till 3 om du vill kräva 3 nycklar!

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Player":
		# Kolla om spelaren har tillräckligt med nycklar (t.ex. minst 2)
		if body.keys >= required_keys:
			if not is_open:
				print("Dörren till Rum 3 öppnas!")
				is_open = true
				body.keys -= required_keys # Dra av rätt antal nycklar
				
				# Byt bilder
				$ClosedDoor.visible = false
				$OpenDoor.visible = true
				
				# Stäng av väggen
				$Doorbody/WallCollision.set_deferred("disabled", true)
				
				# Uppdatera kamerans gränser för Rum 3
				var camera = body.get_node_or_null("Camera2D")
				if camera:
					camera.limit_left = 20
					camera.limit_right = 1165
					camera.limit_top = -1040
					camera.limit_bottom = -730
		else:
			if not is_open:
				print("Du behöver ", required_keys, " nycklar för att öppna denna dörr! (Du har: ", body.keys, ")")
