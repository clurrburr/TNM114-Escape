extends CharacterBody2D

# --- GRUNDLÄGGANDE RÖRELSE OCH GRÄNSER ---
const SPEED = 100.0
@export var LEFT_LIMIT = 300.0
@export var RIGHT_LIMIT = 500.0

# Waypoint-variabler (för förbestämda patrullrutter där vakten vänder automatiskt)
@export var patrol_points: Array[Vector2] = []
var current_point_index = 0
var patrol_direction_forward = true

# AI-parametrar
const FOV = 60.0
const WAIT_TIME = 3.0

# --- NODER OCH GRAFIKLAGER ---
@onready var body = $Body
@onready var pants = $Pants
@onready var shirt = $Shirt
@onready var shoes = $Shoes
@onready var hair = $Hair
@onready var eyes = $Eyes

@onready var ray_cast = $RayCast2D # Används för siktlinje och väggkollisioner

# --- TILLSTÅNDS- OCH RÖRELSEVARIABLER ---
var facing_direction = Vector2.RIGHT

var investigating_sound = false
var sound_position = Vector2.ZERO
var is_chasing_player = false # Styr om vakten jagar aktivt eller bara undersöker

var returning_to_patrol = false
var patrol_return_position = Vector2.ZERO
var patrol_facing_direction = Vector2.RIGHT

var waiting_at_sound = false
var wait_timer = 0.0

var is_guarding_exit = false
var has_reached_door = false 
var exit_target_position = Vector2.ZERO
var exit_march_direction = Vector2.RIGHT
var exit_march_start_x = 0.0

var player_in_proximity = false
var target_player: Node2D = null

var has_alerted = false
var is_caught = false
var home_room = 0


func _ready():
	set_vision_color("normal")
	add_to_group("guards")
	if ray_cast:
		ray_cast.enabled = true
	
	# Spara vilket rum vakten startar i så den inte lämnar det
	home_room = get_room_number(global_position)

# Kontrollerar om vakten har fri sikt till spelaren (stoppas av väggar via Raycast)
func has_line_of_sight_to(player_node: Node2D) -> bool:
	if not ray_cast:
		return true
		
	ray_cast.target_position = ray_cast.to_local(player_node.global_position)
	ray_cast.force_raycast_update()
	
	if not ray_cast.is_colliding():
		return true
		
	var collider = ray_cast.get_collider()
	if collider == player_node:
		return true
		
	return false
	
# Hjälpfunktion för mjuk rörelse
func move_guard(dir: Vector2, speed_val: float):
	velocity = dir * speed_val
	move_and_slide()

# --- HUVUDLOOP: FINITE STATE MACHINE (FSM) ---
func _physics_process(_delta):

# Tillstånd 1: Spelet är över (vakten har fångat spelaren)
	if is_caught:
		velocity = Vector2.ZERO
		move_and_slide()
		return

# Kolla synfält och närhet till spelaren i varje bildruta
	var overlapping_bodies = $VisionArea.get_overlapping_bodies()
	for body_node in overlapping_bodies:
		if body_node.name == "Player":
			var distance_to_player = global_position.distance_to(body_node.global_position)
			var direction_to_player = global_position.direction_to(body_node.global_position)
			var dot_product = facing_direction.dot(direction_to_player)
			var fov_limit = cos(deg_to_rad(FOV / 2.0))

			var is_in_fov = (dot_product >= fov_limit)
			var is_touching = (distance_to_player < 65.0)
			
			if (is_touching or is_in_fov) and has_line_of_sight_to(body_node):
				if not is_caught:
					is_caught = true
					velocity = Vector2.ZERO # Stanna vakten direkt
					set_vision_color("chase") # Sätt synfältet till rött omedelbart!
					print("SPELET ÄR ÖVER! Vakten tog dig!")
					
					if not has_alerted:
						alert_nearby_guards(body_node.global_position)
						has_alerted = true
					
					# Vänta 1 sekund så spelaren hinner se det röda synfältet innan skärmbytet:
					await get_tree().create_timer(1.0).timeout
					
					# BYT TILL GAME OVER-SKÄRMEN HÄR:
					get_tree().change_scene_to_file("res://GameOver.tscn")
				
				return

	# Tillstånd 2: Vakten vaktar utgångsdörren (Rum 3 - Hög säkerhet)
	if is_guarding_exit:
		var target_pos = exit_target_position + Vector2(0, 75.0)
		
		if not has_reached_door:
			if global_position.distance_to(target_pos) > 30.0:
				var dir = global_position.direction_to(target_pos)
				move_guard(dir, SPEED)
				
				if is_on_wall() and velocity.length() < SPEED * 0.7:
					velocity = dir * SPEED
					move_and_slide()
			else:
				has_reached_door = true
				exit_march_start_x = global_position.x
		else:
			# Marscherar fram och tillbaka vid dörren
			velocity = Vector2(exit_march_direction.x * (SPEED * 0.7), 0)
			move_and_slide()
			
			if position.x >= exit_march_start_x + 50.0:
				exit_march_direction = Vector2.LEFT
			elif position.x <= exit_march_start_x - 50.0:
				exit_march_direction = Vector2.RIGHT

		update_animations(velocity)
		update_vision_direction(velocity)
		return
		
	# Tillstånd 3: Vakten står stilla och scannar av ett ljud med timer (WAIT_TIME)
	if waiting_at_sound:
		if player_in_proximity and has_line_of_sight_to(target_player):
			waiting_at_sound = false
			investigating_sound = true
			return

		velocity = Vector2.ZERO
		move_and_slide()
		update_animations(velocity)

		wait_timer -= _delta
		if wait_timer <= 0:
			waiting_at_sound = false
			returning_to_patrol = true

		return

# Tillstånd 4: Vakten återvänder till sin ursprungliga patrullposition
	if returning_to_patrol:
		var direction_to_patrol = global_position.direction_to(patrol_return_position)
		move_guard(direction_to_patrol, SPEED)
		
		update_animations(velocity)
		update_vision_direction(velocity)

		if global_position.distance_to(patrol_return_position) < 10.0:
			returning_to_patrol = false
			facing_direction = patrol_facing_direction
			apply_vision_rotation(facing_direction)
			set_vision_color("normal")
			
			# VIKTIGT: Nollställ dessa så vakten kan larma igen senare!
			has_alerted = false
			investigating_sound = false

		return

	# Tillstånd 5: Vakten springer för att undersöka en ljudkälla (t.ex. kastad kruka)
	if investigating_sound:
		if is_chasing_player and player_in_proximity and target_player and has_line_of_sight_to(target_player):
			sound_position = target_player.global_position
			waiting_at_sound = false

		var direction_to_sound = global_position.direction_to(sound_position)
		move_guard(direction_to_sound, SPEED)
		
		if is_on_wall() and velocity.length() < SPEED * 0.7:
			velocity = direction_to_sound * SPEED
			move_and_slide()

		update_animations(velocity)
		update_vision_direction(velocity)

		if global_position.distance_to(sound_position) < 30.0:
			if not player_in_proximity or not is_chasing_player:
				investigating_sound = false
				waiting_at_sound = true
				wait_timer = WAIT_TIME

		return

	# Tillstånd 6: Waypoint-patrullering (Följer utsatta punkter och vänder)
	# Waypoint-patrullering (Vänder automatiskt vid sista punkten och går tillbaka)
	if patrol_points.size() > 0:
		var target_point = patrol_points[current_point_index]
		
		if global_position.distance_to(target_point) < 10.0:
			if current_point_index >= patrol_points.size() - 1:
				patrol_direction_forward = false
			elif current_point_index <= 0:
				patrol_direction_forward = true
			
			if patrol_direction_forward:
				current_point_index += 1
			else:
				current_point_index -= 1
				
			target_point = patrol_points[current_point_index]
		
		var dir = global_position.direction_to(target_point)
		move_guard(dir, SPEED)
		
		update_animations(velocity)
		update_vision_direction(velocity)
		return


	# Tillstånd 7: Standardpatrullering fram och tillbaka mellan fasta gränser
	velocity.x = facing_direction.x * SPEED
	velocity.y = 0
	move_and_slide()

	update_animations(velocity)

	if is_on_wall() or (position.x >= RIGHT_LIMIT and facing_direction.x == 1) or (position.x <= LEFT_LIMIT and facing_direction.x == -1):
		if facing_direction == Vector2.RIGHT:
			facing_direction = Vector2.LEFT
		else:
			facing_direction = Vector2.RIGHT
		
		apply_vision_rotation(facing_direction)

# --- VISUELL FEEDBACK (Synfältets färg) ---
func set_vision_color(state: String):
	if state == "normal":
		$VisionCone.modulate = Color(0.7, 0.8, 1.0, 0.25)
	elif state == "suspicious":
		$VisionCone.modulate = Color(1.0, 1.0, 0.0, 0.4)
	elif state == "chase":
		$VisionCone.modulate = Color(1.0, 0.0, 0.0, 0.5)

# Uppdaterar vart synfältet pekar baserat på rörelseriktning
func update_vision_direction(vel: Vector2):
	if vel.length() > 0:
		if abs(vel.x) > abs(vel.y):
			if vel.x > 0:
				facing_direction = Vector2.RIGHT
			else:
				facing_direction = Vector2.LEFT
		else:
			if vel.y > 0:
				facing_direction = Vector2.DOWN
			else:
				facing_direction = Vector2.UP
		
		apply_vision_rotation(facing_direction)


func apply_vision_rotation(dir: Vector2):
	if dir == Vector2.RIGHT:
		$VisionCone.rotation_degrees = 0
		$VisionCone.scale.x = abs($VisionCone.scale.x)
		$VisionCone.position = Vector2.ZERO
		$VisionCone.z_index = 0
	elif dir == Vector2.LEFT:
		$VisionCone.rotation_degrees = 180
		$VisionCone.position = Vector2.ZERO
		$VisionCone.z_index = 0
	elif dir == Vector2.DOWN:
		$VisionCone.rotation_degrees = 90
		$VisionCone.position = Vector2(0, 8)
		$VisionCone.z_index = 1
	elif dir == Vector2.UP:
		$VisionCone.rotation_degrees = 270
		$VisionCone.position = Vector2.ZERO
		$VisionCone.z_index = 0
		
# --- ANIMERINGSHANTERING ---	
func update_animations(vel: Vector2):
	if vel.length() > 0:
		var anim_name = ""
		if abs(vel.x) > abs(vel.y):
			if vel.x > 0:
				anim_name = "walk_right"
			else:
				anim_name = "walk_left"
		else:
			if vel.y > 0:
				anim_name = "walk_down"
			else:
				anim_name = "walk_up"
		play_all_layers(anim_name)
	else:
		stop_all_layers()


func play_all_layers(anim_name: String):
	body.play(anim_name)
	pants.play(anim_name)
	shirt.play(anim_name)
	shoes.play(anim_name)
	hair.play(anim_name)
	eyes.play(anim_name)


func stop_all_layers():
	body.stop()
	pants.stop()
	shirt.stop()
	shoes.stop()
	hair.stop()
	eyes.stop()

# --- KOPPLINGAR OCH INTERAKTIONER ---
func _on_proximity_area_body_entered(body_node):
	if is_caught:
		return
		
	if body_node.name == "Player":
		target_player = body_node
		player_in_proximity = true
		
		if not has_line_of_sight_to(body_node):
			return
		
		if not investigating_sound and not returning_to_patrol:
			patrol_return_position = global_position
			patrol_facing_direction = facing_direction

		set_vision_color("suspicious")
		sound_position = body_node.global_position
		investigating_sound = true
		is_chasing_player = true 
		returning_to_patrol = false
		waiting_at_sound = false
		
		var my_room = get_room_number(global_position)
		if not has_alerted:
			if my_room != 1:
				print("Vakten ropar på nära håll!")
				alert_nearby_guards(body_node.global_position)
			has_alerted = true


func _on_proximity_area_body_exited(body_node):
	if body_node == target_player or body_node.name == "Player":
		player_in_proximity = false
		target_player = null

# Trigger när spelaren kastar ett föremål (t.ex. en kruka)
func hear_sound(position_of_sound):
	if is_caught:
		return
		
	if not investigating_sound and not returning_to_patrol:
		patrol_return_position = global_position
		patrol_facing_direction = facing_direction

	sound_position = position_of_sound
	investigating_sound = true
	is_chasing_player = false 
	returning_to_patrol = false
	waiting_at_sound = false
	
	set_vision_color("suspicious")
	print("Vakten hörde ett ljud och går för att undersöka!")

# Särskild funktion för att beordra vakt till utgångsdörren
func guard_the_exit(pos: Vector2):
	if is_caught:
		return
		
	is_guarding_exit = true
	has_reached_door = false 
	exit_target_position = pos
	investigating_sound = false
	waiting_at_sound = false
	returning_to_patrol = false
	is_chasing_player = false
	
	set_vision_color("suspicious")
	print("VAKT: Larmet går i sista rummet! Jag springer till dörren och marscherar!")

# --- RUMSUPPDELNING OCH SVÄRM-INTELLIGENCE ---
func get_room_number(pos: Vector2) -> int:
	if pos.y < -520:
		return 3 
	elif pos.y < -150:
		return 2 
	else:
		return 1 

# Samordnar hur vakterna reagerar i grupp beroende på vilket rum larmet utlöses i
func alert_nearby_guards(alert_pos: Vector2):
	var my_room = get_room_number(global_position)
	var all_guards = get_tree().get_nodes_in_group("guards")
	var exit_doors = get_tree().get_nodes_in_group("exit_door")
	var exit_door_node = exit_doors[0] if exit_doors.size() > 0 else null
	
	var guard_sent_to_door = false
	var an_alert_was_triggered = false # Håller koll på om vi faktiskt nådde en annan vakt
	
	for g in all_guards:
		if g != self:
			var other_guard_room = get_room_number(g.global_position)
			var dist = global_position.distance_to(g.global_position)
			
			if my_room == 1:
				return
			elif my_room == 2:
				if other_guard_room == 2 and dist < 900.0:
					if not g.investigating_sound:
						g.hear_sound(alert_pos)
						an_alert_was_triggered = true # En kollega larmades!
			elif my_room == 3:
				if other_guard_room == 3 and dist < 400.0:
					if exit_door_node and not guard_sent_to_door:
						g.guard_the_exit(exit_door_node.global_position)
						guard_sent_to_door = true
						an_alert_was_triggered = true # En kollega larmades!
					else:
						if not g.investigating_sound:
							g.hear_sound(alert_pos)
							an_alert_was_triggered = true # En kollega larmades!

	# Spela bara upp ropat BARA OM vi faktiskt lyckades varna en kollega i rummet
	if an_alert_was_triggered:
		if has_node("ShoutSound") and not $ShoutSound.playing:
			$ShoutSound.play()
