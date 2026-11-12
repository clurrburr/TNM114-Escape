extends Area2D

var thrown = false
var throw_speed = 400.0
var throw_direction = Vector2.ZERO

var throw_distance = 0.0
const MAX_THROW_DISTANCE = 300.0

@onready var prompt_label = $PromptLabel # Hämta labeln som ligger i krukans scen

func _ready():
	prompt_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta):
	if thrown:
		var movement = throw_direction * throw_speed * delta
		
		# Kolla om det finns en vägg i vägen INNAN vi flyttar krukan
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, global_position + movement)
		query.exclude = [self] # Ignorera krukan själv
		var result = space_state.intersect_ray(query)
		
		if result:
			# Om strålen träffar något som INTE är spelaren -> Stoppa kastet direkt!
			if result.collider.name != "Player":
				global_position = result.position # Sätt krukan exakt på träffpunkten
				stop_throw()
				return

		# Om vägen är fri, flytta krukan som vanligt
		position += movement
		throw_distance += movement.length()
		
		if throw_distance >= MAX_THROW_DISTANCE:
			stop_throw()


func stop_throw():
	thrown = false
	throw_distance = 0.0
	prompt_label.visible = false # Dölj texten om den kastas iväg
	
	# Spela upp landningsljudet när krukan stannar/landar
	if has_node("LandSound"):
		$LandSound.play()
	
	var guards = get_tree().get_nodes_in_group("guards")
	var closest_guard = null
	var min_distance = 300.0 
	
	for g in guards:
		var dist = global_position.distance_to(g.global_position)
		if dist < min_distance:
			min_distance = dist
			closest_guard = g
			
	if closest_guard:
		closest_guard.hear_sound(global_position)
		print("Bara den närmaste vakten hörde krukan!")


func _on_body_entered(body):
	if thrown:
		# Om krukan kastas och träffar något som INTE är spelaren (t.ex. en vägg) -> Stoppa kastet!
		if body.name != "Player":
			stop_throw()
	else:
		# Det här körs när spelaren står nära krukan (inte när den kastas)
		if body.name == "Player":
			body.current_throwable = self 
			prompt_label.visible = true # Visa texten ovanför krukan!


func _on_body_exited(body):
	if body.name == "Player":
		if body.current_throwable == self:
			body.current_throwable = null 
		prompt_label.visible = false # Dölj texten när spelaren går därifrån
