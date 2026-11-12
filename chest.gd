extends Area2D

# Du kan fylla i BÅDE nyckeln och dödskallen i Inspector!
@export var key_scene: PackedScene
@export var skull_scene: PackedScene

# Kryssa i denna i Inspector om kistan ska vara en överraskning!
@export var is_trap: bool = false 

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Player":
		if is_trap and skull_scene:
			print("ÖVERRASKNING! Spelaren öppnade en fälld-kista och väckte dödskallen!")
			spawn_item(skull_scene)
		elif key_scene:
			print("Spelaren öppnade kistan och hittade nyckeln!")
			spawn_item(key_scene)
		
		# Stäng av kistan säkert HÄR (inte i spawn_item)
		set_deferred("monitoring", false)
		call_deferred("queue_free")

func spawn_item(scene_to_spawn: PackedScene):
	var item_instance = scene_to_spawn.instantiate()
	
	# Starta i kistan
	item_instance.global_position = global_position
	item_instance.scale = Vector2(1.2, 1.2)
	item_instance.z_index = 2
	
	# Lägg till i spelet säkert med call_deferred
	get_parent().call_deferred("add_child", item_instance)
	
	# Slumpa landningsplats en bit bort
	var offset = Vector2(randf_range(-40, 40), randf_range(20, 40))
	var target_position = global_position + offset
	
	# Hopps-rörelse (tween)
	var tween = create_tween()
	tween.tween_property(item_instance, "global_position", target_position, 0.3)
