extends Node2D

# Projectile (joueur ou ennemi). Créé par main.gd avec spawn_projectile().
#   kind : "feu" et "croissant" (joueur), "boule", "plume", "rocher", "onde", "ombre"

var level = null
var team := "ennemi"      # "joueur" ou "ennemi"
var kind := "boule"
var velocity := Vector2.ZERO
var gravity := 0.0
var life := 4.0
var damage := 1
var radius := 6.0
var t := 0.0
var trail_timer := 0.0


func _ready() -> void:
	add_to_group("proj_" + team)
	match kind:
		"feu":
			radius = 7.0
			life = 1.6
		"rocher":
			radius = 8.0
			gravity = 600.0
		"plume":
			radius = 5.0
		"onde":
			radius = 10.0
			life = 2.5
		"ombre":
			radius = 7.0
			life = 5.0
		"croissant":
			radius = 10.0
			life = 0.9
	if level and team == "joueur":
		level.add_light(self, 0.9, 0.9)


func get_hit_rect() -> Rect2:
	return Rect2(position - Vector2(radius, radius), Vector2(radius, radius) * 2.0)


func _physics_process(delta: float) -> void:
	t += delta
	velocity.y += gravity * delta
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if level:
		if level.is_solid(position):
			level.on_projectile_wall(self)
			explode()
			return
		trail_timer -= delta
		if trail_timer <= 0.0 and (kind == "feu" or kind == "ombre" or kind == "croissant"):
			trail_timer = 0.03
			level.fx.spawn(position + Vector2(randf_range(-3, 3), randf_range(-3, 3)), -velocity * 0.1, Color(1, 1, 1, 0.7), 0.3, 3.0)
	queue_redraw()


func explode() -> void:
	if is_queued_for_deletion():
		return
	if level:
		level.fx.burst(position, 8, 90.0, Color.WHITE, 0.3, 2.5)
	queue_free()


func _draw() -> void:
	match kind:
		"feu":
			var flick := 1.0 + 0.15 * sin(t * 40.0)
			draw_circle(Vector2.ZERO, 12.0 * flick, Color(1, 1, 1, 0.15))
			draw_circle(Vector2.ZERO, 7.0 * flick, Color.WHITE)
			# flamme qui part vers l'arrière
			var back := -signf(velocity.x)
			var tail := PackedVector2Array([Vector2(0, -6), Vector2(back * 16.0, sin(t * 30.0) * 3.0), Vector2(0, 6)])
			draw_colored_polygon(tail, Color(1, 1, 1, 0.8))
			draw_circle(Vector2(signf(velocity.x) * 2.0, 0), 3.0, Color(0.15, 0.15, 0.15))
		"plume":
			var ang := atan2(velocity.y, velocity.x) + sin(t * 10.0) * 0.4
			var d := Vector2(cos(ang), sin(ang))
			var n := Vector2(-d.y, d.x)
			var pts := PackedVector2Array([d * 9.0, n * 3.0, -d * 9.0, -n * 3.0])
			draw_colored_polygon(pts, Color.BLACK)
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color.WHITE, 1.0)
		"rocher":
			draw_set_transform(Vector2.ZERO, t * 6.0)
			var rock := PackedVector2Array([Vector2(-8, -4), Vector2(-3, -8), Vector2(6, -6), Vector2(8, 2), Vector2(2, 8), Vector2(-7, 5)])
			draw_colored_polygon(rock, Color.WHITE)
			draw_polyline(PackedVector2Array([rock[0], rock[1], rock[2], rock[3], rock[4], rock[5], rock[0]]), Color.BLACK, 1.5)
			draw_line(Vector2(-3, -2), Vector2(3, 3), Color.BLACK, 1.0)
			draw_set_transform(Vector2.ZERO)
		"onde":
			var h := 14.0 + sin(t * 20.0) * 3.0
			var wave := PackedVector2Array([Vector2(-10, 10), Vector2(-4, -h * 0.5), Vector2(0, -h), Vector2(4, -h * 0.5), Vector2(10, 10)])
			draw_colored_polygon(wave, Color(1, 1, 1, 0.85))
			draw_polyline(wave, Color.BLACK, 1.5)
		"croissant":
			var d := signf(velocity.x)
			draw_circle(Vector2.ZERO, 14.0, Color(1, 1, 1, 0.12))
			var moon := PackedVector2Array()
			for i in 9:
				var a := -PI * 0.5 + PI * i / 8.0
				moon.append(Vector2(cos(a) * 6.0 * d, sin(a) * 13.0))
			for i in range(8, -1, -1):
				var a := -PI * 0.5 + PI * i / 8.0
				moon.append(Vector2(cos(a) * 1.0 * d, sin(a) * 9.0))
			draw_colored_polygon(moon, Color.WHITE)
		"ombre":
			draw_circle(Vector2.ZERO, 11.0, Color(1, 1, 1, 0.12))
			draw_circle(Vector2.ZERO, 7.0, Color.WHITE)
			draw_circle(Vector2.ZERO, 4.5, Color.BLACK)
			draw_arc(Vector2.ZERO, 9.0, t * 8.0, t * 8.0 + 2.0, 8, Color.WHITE, 1.5)
		_:
			# boule ennemie : blanche, coeur noir qui tourne, traînée
			draw_circle(Vector2.ZERO, 10.0, Color(1, 1, 1, 0.15))
			draw_circle(Vector2.ZERO, 7.0, Color.WHITE)
			draw_circle(Vector2(cos(t * 12.0), sin(t * 12.0)) * 2.5, 2.5, Color.BLACK)
			var b := -signf(velocity.x)
			for i in 3:
				draw_circle(Vector2(b * (10.0 + i * 6.0), 0), 3.0 - i, Color(1, 1, 1, 0.5 - i * 0.15))
