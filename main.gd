extends Node2D

const EnemyScript := preload("res://enemy.gd")
const FireballScript := preload("res://fireball.gd")

const GROUND_TOP := 280.0
const GROUND_BOTTOM := 320.0
const LEVEL_END := 5400.0
const VIEW_HEIGHT := 360.0      # hauteur du monde visible à l'écran (règle le zoom)
const INVINCIBLE_TIME := 1.2
const PIT_DEATH_Y := 420.0
const EXIT_X := 5310.0
const CAVE_X1 := 3020.0
const CAVE_X2 := 4200.0
const HILL_PERIOD := 1200.0
const FIREBALL_SPEED := 150.0

# ---------- Description du niveau ----------
# Sol : [x début, x fin]. Les trous entre les morceaux font perdre une vie.
const GROUND := [[0, 1000], [1100, 1900], [2000, 2900], [3020, 4200], [4300, 5400]]
# Plateformes fines (traversables par le dessous) : [x, y du dessus, largeur]
const PLATFORMS := [
	[620, 200, 120],
	[1250, 225, 96], [1400, 175, 96], [1560, 125, 128],
	[2450, 210, 160], [2700, 190, 80],
	[2935, 240, 50],
	[3250, 220, 100], [3500, 200, 120], [3800, 215, 100],
	[4500, 215, 100], [4700, 170, 120], [4950, 220, 100],
]
# Blocs pleins : [x, y du dessus, taille]
const BLOCKS := [[450, 248, 32], [2300, 248, 32], [2332, 248, 32], [2332, 216, 32], [4400, 248, 32]]
# Pics : [x, nombre] (16 px chacun)
const SPIKES := [[820, 2], [1470, 3], [2150, 2], [3400, 3], [3650, 2], [4600, 4], [5050, 2]]
# Ennemis : [type, x, y, min_x, max_x]
const ENEMIES := [
	["tireur", 920, 264, 0, 0],
	["marcheur", 1500, 264, 1300, 1700],
	["marcheur", 2100, 264, 2040, 2280],
	["marcheur", 2550, 194, 2465, 2595],
	["tireur", 2850, 264, 0, 0],
	["marcheur", 3200, 264, 3080, 3380],
	["marcheur", 3850, 264, 3700, 4000],
	["tireur", 4150, 264, 0, 0],
	["marcheur", 4500, 264, 4440, 4590],
	["marcheur", 4760, 154, 4712, 4808],
	["tireur", 5200, 264, 0, 0],
]
const CHECKPOINTS := [1150, 2050, 3070, 4350]
const TREES := [120, 380, 760, 1180, 1750, 2080, 2620, 4380, 4880, 5150]

var lives := 3
var score := 0
var invincible := 0.0
var finished := false
var respawn_point := Vector2(200, 100)
var checkpoint_on: Array[bool] = []
var spike_areas: Array[Area2D] = []

var camera: Camera2D
var sky: Node2D
var hud_label: Label
var message_label: Label

@onready var player = $Player  # non typé : on accède à can_control, bounce()...


func _ready() -> void:
	# Les scripts se détachent parfois après un rechargement : on les remet si besoin
	ensure_script(player, "res://player.gd")
	ensure_script($CanvasLayer, "res://canvas_layer.gd")

	for i in CHECKPOINTS.size():
		checkpoint_on.append(false)

	setup_sky()
	add_parallax_layer(0.2, Color(0.16, 0.16, 0.16), 215.0, 45.0, 1, false)
	add_parallax_layer(0.5, Color(0.08, 0.08, 0.08), 255.0, 28.0, 4, true)
	build_level()
	setup_camera()
	setup_hud()
	queue_redraw()


func ensure_script(node: Node, path: String) -> void:
	if node.get_script() != null:
		return
	push_warning("Script manquant sur %s : rattaché automatiquement." % node.name)
	node.set_script(load(path))
	# _ready() n'est pas rappelé tout seul après set_script
	node.call("_ready")
	node.set_physics_process(true)
	node.set_process_input(true)


# ---------- Construction du niveau ----------

func build_level() -> void:
	for seg in GROUND:
		add_solid(Rect2(seg[0], GROUND_TOP, seg[1] - seg[0], GROUND_BOTTOM - GROUND_TOP), false)
	for p in PLATFORMS:
		add_solid(Rect2(p[0], p[1], p[2], 12), true)
	for b in BLOCKS:
		add_solid(Rect2(b[0], b[1], b[2], b[2]), false)
	# murs invisibles aux deux bouts
	add_solid(Rect2(-20, -400, 20, 800), false)
	add_solid(Rect2(LEVEL_END, -400, 20, 800), false)

	for s in SPIKES:
		var area := Area2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(s[1] * 16 - 4, 10)
		shape.shape = rect
		area.position = Vector2(s[0] + s[1] * 8, GROUND_TOP - 5)
		area.add_child(shape)
		add_child(area)
		spike_areas.append(area)

	for e in ENEMIES:
		add_enemy(e[0], e[1], e[2], e[3], e[4])


func add_solid(rect: Rect2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	shape.shape = r
	shape.one_way_collision = one_way
	body.position = rect.get_center()
	body.add_child(shape)
	add_child(body)


func add_enemy(kind: String, x: float, y: float, min_x: float, max_x: float) -> void:
	var e = EnemyScript.new()
	e.kind = kind
	e.position = Vector2(x, y)
	e.min_x = min_x
	e.max_x = max_x
	e.target = player
	if kind == "tireur":
		e.points = 200
		e.shoot.connect(_on_enemy_shoot)
	add_child(e)


func _on_enemy_shoot(from_pos: Vector2, dir_x: float) -> void:
	if finished:
		return
	var ball = FireballScript.new()
	ball.position = Vector2(from_pos.x, from_pos.y + 6.0)  # à hauteur du sol
	ball.velocity = Vector2(dir_x * FIREBALL_SPEED, 0)
	add_child(ball)


# ---------- Caméra ----------

func setup_camera() -> void:
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = int(LEVEL_END)
	camera.limit_bottom = int(GROUND_BOTTOM)
	camera.limit_top = -400
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.drag_vertical_enabled = true
	camera.drag_top_margin = 0.3
	camera.drag_bottom_margin = 0.1
	player.add_child(camera)
	camera.make_current()
	get_viewport().size_changed.connect(update_zoom)
	update_zoom()


func update_zoom() -> void:
	# Zoom pour que VIEW_HEIGHT pixels du monde remplissent la hauteur de l'écran
	var h := get_viewport().get_visible_rect().size.y
	var z := h / VIEW_HEIGHT
	camera.zoom = Vector2(z, z)


# ---------- HUD ----------

func setup_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)

	hud_label = Label.new()
	hud_label.position = Vector2(16, 10)
	style_label(hud_label, 20)
	hud.add_child(hud_label)

	message_label = Label.new()
	style_label(message_label, 36)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.visible = false
	hud.add_child(message_label)
	message_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	update_hud()


func style_label(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)


func update_hud() -> void:
	hud_label.text = "VIES : %d     SCORE : %d" % [lives, score]


func popup(text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	style_label(l, 14)
	l.position = pos + Vector2(-20, -44)
	l.z_index = 10
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 30.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(l.queue_free)


# ---------- Boucle de jeu ----------

func _physics_process(delta: float) -> void:
	if finished:
		return

	if invincible > 0.0:
		invincible -= delta
		player.modulate.a = 0.3 if fmod(invincible, 0.2) < 0.1 else 1.0
		if invincible <= 0.0:
			player.modulate.a = 1.0

	check_checkpoints()
	check_hazards()

	if player.global_position.y > PIT_DEATH_Y:
		invincible = 0.0  # tomber dans un trou coûte toujours une vie
		hurt()
	elif player.global_position.x > EXIT_X:
		win()


func check_checkpoints() -> void:
	for i in CHECKPOINTS.size():
		if not checkpoint_on[i] and player.global_position.x >= CHECKPOINTS[i] and player.is_on_floor():
			checkpoint_on[i] = true
			respawn_point = Vector2(CHECKPOINTS[i], 200)
			popup("POINT DE PASSAGE", Vector2(CHECKPOINTS[i] - 30, 250))
			queue_redraw()


func check_hazards() -> void:
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e.dead or not e.overlaps_body(player):
			continue
		# on tombe sur l'ennemi par le dessus : écrasé !
		if player.velocity.y > 0.0 and player.global_position.y < e.global_position.y - 4.0:
			stomp(e)
		else:
			hurt()

	for ball in get_tree().get_nodes_in_group("boules"):
		if ball.overlaps_body(player) and hurt():
			ball.queue_free()

	for area in spike_areas:
		if area.overlaps_body(player):
			hurt()


func stomp(e) -> void:
	e.squash()
	player.bounce()
	score += e.points
	update_hud()
	popup("+%d" % e.points, e.global_position)


# Retourne true si le joueur a vraiment perdu une vie
func hurt() -> bool:
	if invincible > 0.0 or finished:
		return false
	lives -= 1
	update_hud()
	if lives <= 0:
		game_over()
	else:
		respawn()
	return true


func respawn() -> void:
	for ball in get_tree().get_nodes_in_group("boules"):
		ball.queue_free()
	player.global_position = respawn_point
	player.velocity = Vector2.ZERO
	camera.reset_smoothing()
	invincible = INVINCIBLE_TIME


func game_over() -> void:
	end_game("GAME OVER\nSCORE : %d" % score, 2.5)


func win() -> void:
	score += lives * 500
	update_hud()
	end_game("BRAVO !\nSCORE : %d" % score, 4.0)


func end_game(text: String, delay: float) -> void:
	finished = true
	player.can_control = false
	player.modulate.a = 1.0
	if player.global_position.y > PIT_DEATH_Y:
		player.set_physics_process(false)
	message_label.text = text
	message_label.visible = true
	get_tree().create_timer(delay).timeout.connect(func(): get_tree().reload_current_scene())


# ---------- Décor (tout dessiné en code) ----------

func setup_sky() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	sky = Node2D.new()
	sky_layer.add_child(sky)
	sky.draw.connect(draw_sky)
	get_viewport().size_changed.connect(sky.queue_redraw)


func draw_sky() -> void:
	var s := get_viewport().get_visible_rect().size
	# dégradé : noir en haut, gris sombre vers l'horizon
	var bands := 32
	for i in bands:
		var t := float(i) / (bands - 1)
		var g := lerpf(0.02, 0.3, t * t)
		sky.draw_rect(Rect2(0, s.y * i / bands, s.x, s.y / bands + 1.0), Color(g, g, g))
	# étoiles
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		var p := Vector2(rng.randf() * s.x, rng.randf() * s.y * 0.55)
		sky.draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(1, 1, 1, rng.randf_range(0.2, 0.8)))
	# lune avec halo et cratères
	var m := Vector2(s.x * 0.78, s.y * 0.2)
	var r := s.y * 0.08
	for k in 4:
		sky.draw_circle(m, r * (1.4 + k * 0.5), Color(1, 1, 1, 0.04))
	sky.draw_circle(m, r, Color(0.95, 0.95, 0.95))
	sky.draw_circle(m + Vector2(-r * 0.3, -r * 0.2), r * 0.22, Color(0.78, 0.78, 0.78))
	sky.draw_circle(m + Vector2(r * 0.35, r * 0.25), r * 0.15, Color(0.8, 0.8, 0.8))
	sky.draw_circle(m + Vector2(-r * 0.1, r * 0.5), r * 0.1, Color(0.82, 0.82, 0.82))


func add_parallax_layer(scroll: float, color: Color, base_y: float, amp: float, seed_value: int, with_trees: bool) -> void:
	var px := Parallax2D.new()
	px.scroll_scale = Vector2(scroll, 1.0)
	px.repeat_size = Vector2(HILL_PERIOD, 0)
	px.repeat_times = 3
	px.z_index = -5
	var art := Node2D.new()
	px.add_child(art)
	art.draw.connect(draw_hills.bind(art, color, base_y, amp, seed_value, with_trees))
	add_child(px)


func draw_hills(art: Node2D, color: Color, base_y: float, amp: float, seed_value: int, with_trees: bool) -> void:
	var pts := PackedVector2Array()
	var steps := 80
	for i in steps + 1:
		var x := HILL_PERIOD * i / steps
		var t := x / HILL_PERIOD * TAU
		# sinus de période entière : le motif se répète sans couture
		var y := base_y - amp * (0.6 * sin(t * 2.0 + seed_value) + 0.4 * sin(t * 5.0 + seed_value * 2.0))
		pts.append(Vector2(x, y))
	pts.append(Vector2(HILL_PERIOD, 460))
	pts.append(Vector2(0, 460))
	art.draw_colored_polygon(pts, color)
	if with_trees:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for k in 6:
			var tx := 100.0 + k * 190.0
			var t2 := tx / HILL_PERIOD * TAU
			var ty := base_y - amp * (0.6 * sin(t2 * 2.0 + seed_value) + 0.4 * sin(t2 * 5.0 + seed_value * 2.0))
			draw_dead_tree(art, Vector2(tx, ty + 4.0), rng.randf_range(40, 70), color.darkened(0.6), rng)


func draw_dead_tree(canvas: CanvasItem, base: Vector2, height: float, color: Color, rng: RandomNumberGenerator) -> void:
	var top := base + Vector2(rng.randf_range(-6, 6), -height)
	var width := maxf(2.0, height * 0.06)
	canvas.draw_line(base, top, color, width)
	draw_branch(canvas, top, -PI / 2.0, height * 0.3, width * 0.7, 2, color, rng)
	for k in 3:
		var p := base.lerp(top, 0.4 + k * 0.18)
		var side := 1.0 if k % 2 == 0 else -1.0
		draw_branch(canvas, p, -PI / 2.0 + side * rng.randf_range(0.6, 1.1), height * 0.35, width * 0.7, 2, color, rng)


func draw_branch(canvas: CanvasItem, start: Vector2, angle: float, length: float, width: float, depth: int, color: Color, rng: RandomNumberGenerator) -> void:
	var to := start + Vector2(cos(angle), sin(angle)) * length
	canvas.draw_line(start, to, color, width)
	if depth <= 0:
		return
	for k in 2:
		var side := 1.0 if k == 0 else -1.0
		draw_branch(canvas, to, angle + side * rng.randf_range(0.3, 0.7), length * 0.6, maxf(1.0, width * 0.6), depth - 1, color, rng)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# fond sombre de la grotte
	draw_rect(Rect2(CAVE_X1, -400, CAVE_X2 - CAVE_X1, GROUND_TOP + 400), Color(0.035, 0.035, 0.035))

	# arbres morts au premier plan
	for x in TREES:
		draw_dead_tree(self, Vector2(x, GROUND_TOP + 2), rng.randf_range(80, 130), Color(0.01, 0.01, 0.01), rng)

	# trous : bien noirs
	for i in range(1, GROUND.size()):
		var gap_x1: float = GROUND[i - 1][1]
		var gap_x2: float = GROUND[i][0]
		draw_rect(Rect2(gap_x1, GROUND_TOP, gap_x2 - gap_x1, 200), Color.BLACK)

	# sol blanc + herbe noire
	for seg in GROUND:
		var r := Rect2(seg[0], GROUND_TOP, seg[1] - seg[0], 200)
		draw_rect(r, Color.WHITE)
		draw_grass(r, rng)
		for k in int(r.size.x / 30.0):
			var p := Vector2(rng.randf_range(r.position.x + 4, r.end.x - 4), rng.randf_range(GROUND_TOP + 12, GROUND_BOTTOM))
			draw_circle(p, rng.randf_range(1.0, 2.5), Color(0.15, 0.15, 0.15))

	# plateformes
	for p in PLATFORMS:
		var r := Rect2(p[0], p[1], p[2], 12)
		draw_rect(r, Color.WHITE)
		draw_grass(r, rng)
		draw_rect(r, Color.BLACK, false, 1.0)
		# petites racines qui pendent
		for k in int(r.size.x / 24.0):
			var rx := r.position.x + 8.0 + k * 24.0
			draw_line(Vector2(rx, r.end.y), Vector2(rx + rng.randf_range(-3, 3), r.end.y + rng.randf_range(4, 10)), Color(0.85, 0.85, 0.85), 1.0)

	# blocs (caisses)
	for b in BLOCKS:
		var r := Rect2(b[0], b[1], b[2], b[2])
		draw_rect(r, Color.WHITE)
		draw_rect(r, Color.BLACK, false, 2.0)
		var inner := r.grow(-5)
		draw_rect(inner, Color.BLACK, false, 1.0)
		draw_line(inner.position, inner.end, Color.BLACK, 1.0)
		draw_line(Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), Color.BLACK, 1.0)

	# pics
	for s in SPIKES:
		for k in s[1]:
			var x0: float = s[0] + k * 16
			var tri := PackedVector2Array([Vector2(x0, GROUND_TOP), Vector2(x0 + 8, GROUND_TOP - 14), Vector2(x0 + 16, GROUND_TOP)])
			draw_colored_polygon(tri, Color.WHITE)
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2]]), Color.BLACK, 1.5)

	draw_cave_ceiling(rng)

	# points de passage (lanternes)
	for i in CHECKPOINTS.size():
		var x: float = CHECKPOINTS[i]
		draw_line(Vector2(x, GROUND_TOP), Vector2(x, GROUND_TOP - 34), Color(0.6, 0.6, 0.6), 2.0)
		var lamp := Vector2(x, GROUND_TOP - 40)
		if checkpoint_on[i]:
			for k in 3:
				draw_circle(lamp, 10.0 + k * 7.0, Color(1, 1, 1, 0.08))
			draw_circle(lamp, 5.0, Color.WHITE)
		else:
			draw_arc(lamp, 5.0, 0.0, TAU, 16, Color(0.5, 0.5, 0.5), 1.5)

	# porte de sortie
	var door := Rect2(EXIT_X - 14, GROUND_TOP - 64, 48, 64)
	for k in 4:
		draw_circle(door.get_center(), 30.0 + k * 12.0, Color(1, 1, 1, 0.05))
	draw_rect(door, Color.WHITE)
	draw_rect(door.grow(-6), Color.BLACK)
	draw_circle(Vector2(door.end.x - 14, door.get_center().y + 4), 2.0, Color.WHITE)


func draw_grass(r: Rect2, rng: RandomNumberGenerator) -> void:
	var x := r.position.x
	while x < r.end.x - 3.0:
		var h := rng.randf_range(4.0, 9.0)
		var lean := rng.randf_range(-2.0, 2.0)
		var base_y := r.position.y + 5.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, base_y), Vector2(x + 3.0, base_y), Vector2(x + 1.5 + lean, base_y - h)
		]), Color.BLACK)
		x += rng.randf_range(3.0, 6.0)


func draw_cave_ceiling(rng: RandomNumberGenerator) -> void:
	var edge := PackedVector2Array()
	var x := CAVE_X1
	while x <= CAVE_X2:
		edge.append(Vector2(x, rng.randf_range(0.0, 18.0)))
		x += 20.0
	var poly := PackedVector2Array([Vector2(CAVE_X1, -400)])
	poly.append_array(edge)
	poly.append(Vector2(CAVE_X2, -400))
	draw_colored_polygon(poly, Color.BLACK)
	draw_polyline(edge, Color(0.75, 0.75, 0.75), 2.0)
	# stalactites
	x = CAVE_X1 + 30.0
	while x < CAVE_X2 - 30.0:
		var w := rng.randf_range(10.0, 22.0)
		var drop := rng.randf_range(25.0, 70.0)
		var tri := PackedVector2Array([Vector2(x - w / 2.0, 8), Vector2(x + w / 2.0, 8), Vector2(x + rng.randf_range(-3, 3), 8 + drop)])
		draw_colored_polygon(tri, Color.BLACK)
		draw_polyline(PackedVector2Array([tri[0], tri[2], tri[1]]), Color(0.75, 0.75, 0.75), 1.5)
		x += rng.randf_range(45.0, 90.0)
