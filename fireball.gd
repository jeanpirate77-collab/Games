extends Area2D

# Boule tirée par un ennemi « tireur ». Créée par main.gd.

var velocity := Vector2(-150, 0)
var life := 4.0
var spin := 0.0


func _ready() -> void:
	add_to_group("boules")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	spin += delta * 12.0
	life -= delta
	if life <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	# halo, boule blanche, petit cœur noir qui tourne
	draw_circle(Vector2.ZERO, 10.0, Color(1, 1, 1, 0.15))
	draw_circle(Vector2.ZERO, 7.0, Color.WHITE)
	draw_circle(Vector2(cos(spin), sin(spin)) * 2.5, 2.5, Color.BLACK)
	# traînée
	var back := -signf(velocity.x)
	for i in 3:
		draw_circle(Vector2(back * (10.0 + i * 6.0), 0), 3.0 - i, Color(1, 1, 1, 0.5 - i * 0.15))
