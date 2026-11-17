extends Node2D

const GameData = preload("res://game_data.gd")

# Objet à ramasser : "piece", "coeur", "eclat" ou "receptacle" (+1 coeur max pour toujours).

var level = null
var target = null           # le joueur
var kind := "piece"
var vel := Vector2.ZERO
var falling := false        # true : saute puis retombe (pièces lâchées par un ennemi)
var t := 0.0
var base_y := 0.0
var magnet := false
var shard_id := -1
var pickup_delay := 0.0


func _ready() -> void:
	base_y = position.y
	t = randf() * TAU
	magnet = kind == "piece" and GameData.get_level("aimant") > 0
	if falling:
		pickup_delay = 0.25
	if level and (kind == "eclat" or kind == "receptacle"):
		level.add_light(self, 0.7, 0.8)


func _physics_process(delta: float) -> void:
	t += delta
	pickup_delay -= delta
	if falling:
		vel.y += 800.0 * delta
		if level.is_solid(position + Vector2(signf(vel.x) * 6.0, 0)):
			vel.x = -vel.x * 0.5
		position += vel * delta
		if vel.y > 0.0 and level.is_solid(position + Vector2(0, 8), true):
			position.y = floor((position.y + 8.0) / 32.0) * 32.0 - 8.0
			vel = Vector2.ZERO
			falling = false
			base_y = position.y
		if position.y > level.world_bottom() + 60.0:
			queue_free()
	else:
		position.y = base_y + sin(t * 3.0) * 2.0

	if target == null or target.dead:
		queue_redraw()
		return
	var d: float = target.global_position.distance_to(global_position)
	if magnet and d < 110.0:
		position = position.move_toward(target.global_position, 280.0 * delta)
		base_y = position.y
		falling = false
	if d < 22.0 and pickup_delay <= 0.0:
		level.collect(self)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	match kind:
		"piece":
			# pièce qui tourne sur elle-même
			var w := absf(cos(t * 4.0))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(maxf(0.15, w), 1.0))
			draw_circle(Vector2.ZERO, 7.0, Color.BLACK)
			draw_circle(Vector2.ZERO, 6.0, Color.WHITE)
			draw_arc(Vector2.ZERO, 3.5, 0.0, TAU, 12, Color(0.35, 0.35, 0.35), 1.5)
			draw_set_transform(Vector2.ZERO)
			if fmod(t, 2.0) < 0.15:
				draw_line(Vector2(-4, -9), Vector2(4, -9), Color.WHITE, 1.0)
				draw_line(Vector2(0, -13), Vector2(0, -5), Color.WHITE, 1.0)
		"coeur":
			var s := 1.0 + 0.12 * sin(t * 6.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
			draw_circle(Vector2.ZERO, 12.0, Color(1, 1, 1, 0.1))
			var heart := PackedVector2Array([Vector2(0, 8), Vector2(-8, 0), Vector2(-8, -4), Vector2(-5, -7), Vector2(-2, -7), Vector2(0, -4), Vector2(2, -7), Vector2(5, -7), Vector2(8, -4), Vector2(8, 0)])
			draw_colored_polygon(heart, Color.WHITE)
			heart.append(heart[0])
			draw_polyline(heart, Color.BLACK, 1.5)
			draw_set_transform(Vector2.ZERO)
		"receptacle":
			# gros coeur avec un « + »
			var s2 := 1.4 + 0.15 * sin(t * 5.0)
			for k in 3:
				draw_circle(Vector2.ZERO, 16.0 + k * 6.0, Color(1, 1, 1, 0.08))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(s2, s2))
			var big := PackedVector2Array([Vector2(0, 8), Vector2(-8, 0), Vector2(-8, -4), Vector2(-5, -7), Vector2(-2, -7), Vector2(0, -4), Vector2(2, -7), Vector2(5, -7), Vector2(8, -4), Vector2(8, 0)])
			draw_colored_polygon(big, Color.WHITE)
			big.append(big[0])
			draw_polyline(big, Color.BLACK, 1.2)
			draw_line(Vector2(-3, -1), Vector2(3, -1), Color.BLACK, 1.5)
			draw_line(Vector2(0, -4), Vector2(0, 2), Color.BLACK, 1.5)
			draw_set_transform(Vector2.ZERO)
		"eclat":
			# croissant de lune qui brille
			for k in 3:
				draw_circle(Vector2.ZERO, 10.0 + k * 5.0 + sin(t * 3.0) * 2.0, Color(1, 1, 1, 0.07))
			draw_circle(Vector2.ZERO, 8.0, Color.WHITE)
			draw_circle(Vector2(4, -3), 7.0, Color.BLACK)
			for k in 4:
				var a := t * 1.5 + k * TAU / 4.0
				var p := Vector2(cos(a), sin(a)) * 15.0
				draw_line(p - Vector2(2, 0), p + Vector2(2, 0), Color.WHITE, 1.0)
				draw_line(p - Vector2(0, 2), p + Vector2(0, 2), Color.WHITE, 1.0)
