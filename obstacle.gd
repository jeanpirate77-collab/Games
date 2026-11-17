extends Node2D

# Obstacles créés par main.gd à partir des cartes (levels.gd) :
#   a  "acide"      : liquide mortel (fait perdre un coeur et ramène au point de passage)
#   x  "fragile"    : plateforme qui s'effondre quand on reste dessus, puis revient
#   k  "ressort"    : propulse très haut
#   r  "scie"       : scie circulaire qui monte et descend
#   l  "flammes"    : jet de flammes qui s'allume et s'éteint
#   u  "stalactite" : tombe quand le joueur passe dessous
#   q  "pendule"    : lame qui se balance
#   T  "torche"     : décor lumineux

var kind := "acide"
var level = null
var player = null
var t := 0.0
var phase := 0.0
var state := ""
var timer := 0.0
var home := Vector2.ZERO
var vel := Vector2.ZERO
var body: StaticBody2D = null
var shape: CollisionShape2D = null
var light: PointLight2D = null
var squash := 0.0


func _ready() -> void:
	add_to_group("obstacles")
	home = position
	phase = fmod(position.x * 0.013, TAU)
	match kind:
		"fragile":
			body = StaticBody2D.new()
			shape = CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(32, 12)
			shape.shape = rect
			shape.one_way_collision = true
			shape.position = Vector2(0, -10)
			body.add_child(shape)
			add_child(body)
		"flammes":
			light = level.add_light(self, 1.4, 0.0)
		"torche":
			light = level.add_light(self, 1.6, 0.9)
		"scie":
			z_index = 1


func _physics_process(delta: float) -> void:
	t += delta
	match kind:
		"fragile":
			update_fragile(delta)
		"stalactite":
			update_stalactite(delta)
		"flammes":
			var on := flame_on()
			light.energy = (1.1 + 0.2 * sin(t * 30.0)) if on else (0.25 if flame_warning() else 0.0)
			if on and int(t * 30.0) % 2 == 0:
				level.fx.spawn(position + Vector2(randf_range(-6, 6), 12.0 - randf_range(0, 90)), Vector2(randf_range(-20, 20), -120), Color(1, 1, 1, 0.8), 0.4, 3.0)
		"torche":
			light.energy = 0.85 + 0.15 * sin(t * 11.0) + randf_range(-0.05, 0.05)
			if randf() < 0.1:
				level.fx.spawn(position + Vector2(randf_range(-3, 3), -14), Vector2(randf_range(-10, 10), -50), Color(1, 1, 1, 0.9), 0.6, 2.0)
	squash = move_toward(squash, 0.0, delta * 4.0)
	queue_redraw()


# ---------- Logique ----------

func flame_cycle() -> float:
	return fmod(t + phase, 3.0)


func flame_warning() -> bool:
	var k := flame_cycle()
	return k >= 1.2 and k < 1.8


func flame_on() -> bool:
	return flame_cycle() >= 1.8


func update_fragile(delta: float) -> void:
	match state:
		"craque":
			timer -= delta
			if timer <= 0.0:
				state = "tombe"
				timer = 3.0
				shape.set_deferred("disabled", true)
				level.fx.burst(position + Vector2(0, -10), 10, 80.0, Color(0.85, 0.85, 0.85), 0.5, 3.0, 400.0)
		"tombe":
			timer -= delta
			vel.y += 600.0 * delta
			if timer <= 0.0:
				state = ""
				vel = Vector2.ZERO
				shape.set_deferred("disabled", false)
				level.fx.burst(position + Vector2(0, -10), 8, 50.0, Color.WHITE, 0.4, 2.0)
		_:
			if player.is_on_floor() and absf(player.global_position.x - position.x) < 28.0 and absf(player.global_position.y + 16.0 - (position.y - 16.0)) < 6.0:
				state = "craque"
				timer = 0.45


func update_stalactite(delta: float) -> void:
	match state:
		"tremble":
			timer -= delta
			if timer <= 0.0:
				state = "chute"
		"chute":
			vel.y += 900.0 * delta
			position += vel * delta
			if level.is_solid(position + Vector2(0, 14), true) or position.y > level.world_bottom():
				level.fx.burst(position + Vector2(0, 10), 14, 140.0, Color(0.85, 0.85, 0.85), 0.6, 3.0, 500.0, 80.0)
				level.shake(3.0)
				state = "cassee"
				timer = 4.0
		"cassee":
			timer -= delta
			if timer <= 0.0:
				state = ""
				position = home
				vel = Vector2.ZERO
		_:
			var dx: float = absf(player.global_position.x - position.x)
			if dx < 40.0 and player.global_position.y > position.y:
				state = "tremble"
				timer = 0.4


# Ressorts : appelé par main.gd à chaque image
func interact(p) -> void:
	if kind != "ressort":
		return
	var pr: Rect2 = p.get_hit_rect()
	var top := Rect2(position.x - 12, position.y + 2, 24, 14)
	if p.velocity.y >= 0.0 and pr.intersects(top):
		p.spring(-720.0)
		squash = 1.0
		level.fx.burst(position + Vector2(0, 8), 10, 90.0, Color.WHITE, 0.4, 2.5)


# Retourne true si l'obstacle touche le joueur (rectangle pr)
func hits_player(pr: Rect2) -> bool:
	match kind:
		"acide":
			return pr.intersects(Rect2(position.x - 16, position.y - 6, 32, 22))
		"scie":
			return circle_hits(pr, saw_pos(), 13.0)
		"pendule":
			return circle_hits(pr, pendulum_tip(), 13.0)
		"flammes":
			return flame_on() and pr.intersects(Rect2(position.x - 9, position.y + 16 - 92, 18, 92))
		"stalactite":
			return state == "chute" and pr.intersects(Rect2(position.x - 7, position.y - 16, 14, 32))
	return false


func circle_hits(pr: Rect2, c: Vector2, r: float) -> bool:
	var closest := Vector2(clampf(c.x, pr.position.x, pr.end.x), clampf(c.y, pr.position.y, pr.end.y))
	return closest.distance_to(c) < r


func saw_pos() -> Vector2:
	return position + Vector2(0, sin(t * 1.6 + phase) * 48.0)


func pendulum_angle() -> float:
	return sin(t * 1.7 + phase) * 1.15


func pendulum_tip() -> Vector2:
	var a := pendulum_angle()
	return position + Vector2(sin(a), cos(a)) * 84.0


# ---------- Dessin ----------

func _draw() -> void:
	match kind:
		"acide":
			draw_acid()
		"fragile":
			draw_fragile()
		"ressort":
			draw_spring()
		"scie":
			draw_saw()
		"flammes":
			draw_flames()
		"stalactite":
			draw_stalactite()
		"pendule":
			draw_pendulum()
		"torche":
			draw_torch()


func draw_acid() -> void:
	var top := PackedVector2Array()
	for i in 9:
		var x := -16.0 + i * 4.0
		top.append(Vector2(x, -6.0 + sin(t * 3.0 + (position.x + x) * 0.15) * 2.0))
	var pts := top.duplicate()
	pts.append(Vector2(16, 16))
	pts.append(Vector2(-16, 16))
	draw_colored_polygon(pts, Color(0.08, 0.08, 0.08))
	draw_polyline(top, Color.WHITE, 2.0)
	# reflets et bulles
	draw_line(Vector2(-10, 2), Vector2(-4, 2), Color(1, 1, 1, 0.25), 1.0)
	for k in 2:
		var bt := fmod(t * 0.8 + k * 0.5 + phase, 1.0)
		var bx := -8.0 + k * 14.0 + sin(phase + k) * 3.0
		draw_arc(Vector2(bx, 12.0 - bt * 16.0), 1.5 + bt * 1.5, 0.0, TAU, 8, Color(1, 1, 1, 0.6 * (1.0 - bt)), 1.0)


func draw_fragile() -> void:
	var off := Vector2.ZERO
	var a := 1.0
	if state == "craque":
		off = Vector2(randf_range(-1.5, 1.5), 0)
	elif state == "tombe":
		off = Vector2(0, (3.0 - timer) * (3.0 - timer) * 300.0 * 0.5)
		a = clampf(timer - 2.0, 0.0, 1.0)
	var rect := Rect2(Vector2(-16, -16) + off, Vector2(32, 12))
	draw_rect(rect, Color(0.85, 0.85, 0.85, a))
	draw_rect(rect, Color(0, 0, 0, a), false, 1.5)
	# fissures
	draw_line(rect.position + Vector2(8, 0), rect.position + Vector2(12, 7), Color(0, 0, 0, a), 1.0)
	draw_line(rect.position + Vector2(12, 7), rect.position + Vector2(10, 12), Color(0, 0, 0, a), 1.0)
	draw_line(rect.position + Vector2(22, 0), rect.position + Vector2(20, 6), Color(0, 0, 0, a), 1.0)
	if state == "craque":
		draw_line(rect.position + Vector2(16, 0), rect.position + Vector2(17, 12), Color(0, 0, 0, a), 1.5)


func draw_spring() -> void:
	var h := 10.0 - squash * 6.0
	var base_y := 16.0
	# ressort en zigzag
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(Vector2(-7.0 if i % 2 == 0 else 7.0, base_y - 2.0 - i * h / 5.0))
	draw_polyline(pts, Color.BLACK, 4.0)
	draw_polyline(pts, Color(0.75, 0.75, 0.75), 2.0)
	draw_rect(Rect2(-12, base_y - 3, 24, 3), Color(0.3, 0.3, 0.3))
	var top := Rect2(-12, base_y - 6 - h, 24, 5)
	draw_rect(top, Color.WHITE)
	draw_rect(top, Color.BLACK, false, 1.5)
	draw_line(Vector2(-6, top.position.y + 2), Vector2(6, top.position.y + 2), Color(0, 0, 0, 0.4), 1.0)


func draw_saw() -> void:
	var p := saw_pos() - position
	# rail
	draw_line(Vector2(0, -52), Vector2(0, 52), Color(0.2, 0.2, 0.2), 3.0)
	draw_circle(Vector2(0, -52), 3.0, Color(0.3, 0.3, 0.3))
	draw_circle(Vector2(0, 52), 3.0, Color(0.3, 0.3, 0.3))
	# lame dentelée qui tourne
	var teeth := PackedVector2Array()
	for i in 24:
		var a := t * 12.0 + i * TAU / 24.0
		var r := 15.0 if i % 2 == 0 else 11.0
		teeth.append(p + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(teeth, Color.WHITE)
	teeth.append(teeth[0])
	draw_polyline(teeth, Color.BLACK, 1.5)
	draw_circle(p, 5.0, Color(0.2, 0.2, 0.2))
	draw_circle(p, 2.0, Color.WHITE)
	draw_arc(p, 8.0, t * 12.0, t * 12.0 + 1.5, 8, Color(0, 0, 0, 0.5), 1.5)


func draw_flames() -> void:
	# buse au sol
	draw_rect(Rect2(-10, 8, 20, 8), Color(0.25, 0.25, 0.25))
	draw_rect(Rect2(-10, 8, 20, 8), Color.BLACK, false, 1.5)
	draw_rect(Rect2(-6, 6, 12, 3), Color(0.5, 0.5, 0.5))
	if flame_warning():
		for k in 3:
			draw_circle(Vector2(randf_range(-4, 4), 4.0 - k * 4.0), 2.0, Color(1, 1, 1, 0.6))
	elif flame_on():
		var pts := PackedVector2Array()
		var steps := 8
		for i in steps + 1:
			var k := float(i) / steps
			pts.append(Vector2(-8.0 * (1.0 - k * 0.6) + sin(t * 25.0 + i) * 2.0, 6.0 - k * 92.0))
		for i in range(steps, -1, -1):
			var k := float(i) / steps
			pts.append(Vector2(8.0 * (1.0 - k * 0.6) + sin(t * 23.0 + i * 1.3) * 2.0, 6.0 - k * 92.0))
		draw_colored_polygon(pts, Color(1, 1, 1, 0.9))
		draw_polyline(pts, Color(0.4, 0.4, 0.4), 1.0)
		var core := PackedVector2Array([Vector2(-3, 6), Vector2(sin(t * 30.0) * 2.0, -60), Vector2(3, 6)])
		draw_colored_polygon(core, Color(0.6, 0.6, 0.6))


func draw_stalactite() -> void:
	if state == "cassee":
		return
	var off := Vector2(randf_range(-1.5, 1.5), 0) if state == "tremble" else Vector2.ZERO
	var tri := PackedVector2Array([Vector2(-8, -16) + off, Vector2(8, -16) + off, Vector2(1, 16) + off])
	draw_colored_polygon(tri, Color(0.9, 0.9, 0.9))
	draw_polyline(PackedVector2Array([tri[0], tri[2], tri[1]]), Color.BLACK, 1.5)
	draw_line(Vector2(-2, -12) + off, Vector2(0, 6) + off, Color(0, 0, 0, 0.3), 1.0)


func draw_pendulum() -> void:
	var tip := pendulum_tip() - position
	# chaîne qui monte jusqu'en haut
	draw_line(Vector2(0, -position.y), Vector2.ZERO, Color(0.25, 0.25, 0.25), 2.0)
	draw_circle(Vector2.ZERO, 5.0, Color(0.3, 0.3, 0.3))
	draw_line(Vector2.ZERO, tip, Color.BLACK, 4.0)
	draw_line(Vector2.ZERO, tip, Color(0.6, 0.6, 0.6), 2.0)
	# lame en croissant
	var a := pendulum_angle()
	var d := Vector2(sin(a), cos(a))
	var n := Vector2(-d.y, d.x)
	var blade := PackedVector2Array()
	for i in 9:
		var k := -1.0 + i / 4.0
		blade.append(tip + n * k * 16.0 + d * (6.0 - k * k * 6.0))
	for i in range(8, -1, -1):
		var k := -1.0 + i / 4.0
		blade.append(tip + n * k * 12.0 - d * (2.0 + k * k * 2.0))
	draw_colored_polygon(blade, Color.WHITE)
	blade.append(blade[0])
	draw_polyline(blade, Color.BLACK, 1.5)
	# traînée de mouvement
	var a2 := sin((t - 0.08) * 1.7 + phase) * 1.15
	var tip2 := Vector2(sin(a2), cos(a2)) * 84.0
	draw_line(tip2, tip, Color(1, 1, 1, 0.25), 6.0)


func draw_torch() -> void:
	draw_line(Vector2(0, 16), Vector2(0, -6), Color(0.35, 0.35, 0.35), 3.0)
	draw_rect(Rect2(-4, -9, 8, 4), Color(0.5, 0.5, 0.5))
	var flick := 1.0 + 0.2 * sin(t * 17.0)
	for k in 3:
		draw_circle(Vector2(0, -16), (7.0 + k * 5.0) * flick, Color(1, 1, 1, 0.06))
	var flame := PackedVector2Array([Vector2(-4, -10), Vector2(sin(t * 13.0) * 2.0, -24.0 * flick), Vector2(4, -10)])
	draw_colored_polygon(flame, Color.WHITE)
	draw_circle(Vector2(0, -12), 3.0, Color(0.7, 0.7, 0.7))
