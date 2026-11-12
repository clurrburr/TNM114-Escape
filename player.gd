extends CharacterBody2D

const SPEED = 200.0

var last_direction = Vector2.RIGHT
var is_hiding = false
var current_throwable = null # Håller koll på krukan man står vid
var current_barrel = null
var keys = 0  # Håller koll på hur många nycklar du bär på

@onready var throwable = get_parent().get_node("Throwable")

# Hämta alla sex lager
@onready var body = $Body
@onready var eyes = $Eyes
@onready var shoes = $Shoes
@onready var pants = $Pants
@onready var shirt = $Shirt
@onready var hair = $Hair


func _physics_process(_delta):
	# Stoppa rörelse och animationer helt om spelaren gömmer sig
	if is_hiding:
		velocity = Vector2.ZERO
		stop_animation()
		return

	var direction = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	if direction.length() > 0:
		direction = direction.normalized()
		last_direction = direction
		
		# Välj rätt animation baserat på riktning
		var anim_name = ""
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				anim_name = "walk_right"
			else:
				anim_name = "walk_left"
		else:
			if direction.y > 0:
				anim_name = "walk_down"
			else:
				anim_name = "walk_up"
		
		# Spela upp animationen på ALLA lager samtidigt
		play_animation(anim_name)
	else:
		# Stanna alla lager när spelaren står still
		stop_animation()

	velocity = direction * SPEED
	move_and_slide()


# Hjälpfunktion för att spela upp animationer på alla lager
func play_animation(anim_name: String):
	body.play(anim_name)
	eyes.play(anim_name)
	shoes.play(anim_name)
	pants.play(anim_name)
	shirt.play(anim_name)
	hair.play(anim_name)


# Hjälpfunktion för att stanna alla lager
func stop_animation():
	body.stop()
	eyes.stop()
	shoes.stop()
	pants.stop()
	shirt.stop()
	hair.stop()


func _input(event):
	# Kasta krukan om man trycker på kast-knappen och står vid en kruka
	if event.is_action_pressed("throw") and current_throwable != null:
		current_throwable.thrown = true
		current_throwable.throw_direction = last_direction
		current_throwable = null # Släpp taget om krukan när den kastas

	# Om spelaren trycker Space/Enter när hen gömmer sig -> Kliv ur!
	if event.is_action_pressed("ui_accept") and is_hiding:
		unhide_player()


# Funktioner för att hantera gömstället
func hide_player(target_position: Vector2):
	is_hiding = true
	global_position = target_position # Flytta spelaren till tunnan
	
	# Gör alla lagren osynliga
	body.visible = false
	eyes.visible = false
	shoes.visible = false
	pants.visible = false
	shirt.visible = false
	hair.visible = false
	
	# Stäng av kollisionen så vakter inte upptäcker spelaren fysiskt
	$CollisionShape2D.set_deferred("disabled", true)


func unhide_player():
	is_hiding = false
	
	# Slå på synligheten igen
	body.visible = true
	eyes.visible = true
	shoes.visible = true
	pants.visible = true
	shirt.visible = true
	hair.visible = true
	
	# Slå på kollisionen igen
	$CollisionShape2D.set_deferred("disabled", false)
	
	# Skuffa ut spelaren lite nedanför så man inte fastnar
	global_position += Vector2(0, 20)
	
