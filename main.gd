extends Node2D

const GameData = preload("res://game_data.gd")
const Levels = preload("res://levels.gd")
const EnemyScript = preload("res://enemy.gd")
const BossScript = preload("res://boss.gd")
const ProjectileScript = preload("res://fireball.gd")
const PickupScript = preload("res://pickup.gd")
const FxScript = preload("res://fx.gd")
const MenuScript = preload("res://menu.gd")

const TILE := 32
const INVINCIBLE_TIME := 1.2
const PARALLAX_W := 1200.0
const ENEMY_CHARS := {"w": "marcheur", "s": "tireur", "f": "chauve-souris", "j": "sauteur", "g": "spectre"}
const HEART := [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
const POST_FX := true            # grain + lueur « film noir » (mettre false si l'écran devient noir)
const DARKNESS := [0.62, 0.42, 0.55]   # luminosité ambiante par monde (forêt, grotte, château)

var grid: Array = []
var cols := 0
var rows := 0
var world := 0
var level_data: Dictionary = {}
var in_level := false

var hearts := 3
var max_hearts := 3
var level_coins := 0
var shards_found: Array = [false, false, false]
var shard_count := 0
var invincible := 0.0
var finished := false
var respawn_point := Vector2.ZERO
var checkpoints: Array = []
var exit_pos := Vector2(-1000, -1000)
var exit_open := true
var exit_alpha := 1.0
var boss = null
var movers: Array = []
var crates := {}
var time := 0.0
var look := 0.0
var shake_amount := 0.0
var flash_alpha := 0.0
var next_lightning := 5.0
var ambient_timer := 0.0
var rain: Array = []

var camera: Camera2D
var fx
var sky: Node2D
var deco: Node2D
var weather: Node2D
var hud_layer: CanvasLayer
var hud_draw: Node2D
var coin_label: Label
var banner: Label
var boss_label: Label
var pause_button: Button
var panel: Control = null
var touch = null
var light_tex: GradientTexture2D
var door_light: PointLight2D
var fog_art: Node2D
var tile_chunks: Array = []
var canvas: CanvasItem = null   # tranche de décor en cours de dessin

@onready var player = $Player


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameData.load_game()
	GameData.setup_inputs()
	GameData.taps.clear()
	# Taille de référence 640x360 étirée sur tout l'écran (sinon tout est minuscule sur iPad)
	var win := get_window()
	win.content_scale_size = Vector2i(640, 360)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	light_tex = make_light_texture()
	# Les scripts se détachent parfois après un rechargement : on les remet si besoin
	ensure_script(player, "res://player.gd")
	ensure_script($CanvasLayer, "res://canvas_layer.gd")
	touch = $CanvasLayer
	# Le sol vient maintenant des cartes de levels.gd
	if has_node("StaticBody2D"):
		$StaticBody2D.queue_free()
	fx = FxScript.new()
	add_child(fx)
	get_viewport().size_changed.connect(on_resize)
	if GameData.screen == "niveau":
		start_level()
	else:
		start_menu()


func ensure_script(node: Node, path: String) -> void:
	if node.get_script() != null:
		return
	push_warning("Script manquant sur %s : rattaché automatiquement." % node.name)
	node.set_script(load(path))
	node.call("_ready")  # _ready() n'est pas rappelé tout seul après set_script
	node.set_physics_process(true)
	node.set_process(true)
	node.set_process_input(true)
	node.set_process_unhandled_input(true)


# =====================================================================
#  MENU
# =====================================================================

func start_menu() -> void:
	in_level = false
	world = 0
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	touch.visible = false
	touch.process_mode = Node.PROCESS_MODE_DISABLED
	setup_background()
	camera = Camera2D.new()
	camera.position = Vector2(0, 192)
	add_child(camera)
	camera.make_current()
	update_zoom()
	setup_foreground()
	setup_vignette()
	add_child(MenuScript.new())


# =====================================================================
#  CONSTRUCTION DU NIVEAU
# =====================================================================

func start_level() -> void:
	in_level = true
	var all: Array = Levels.LEVELS
	GameData.current_level = clampi(GameData.current_level, 0, all.size() - 1)
	level_data = all[GameData.current_level]
	world = int(level_data["monde"])
	grid = (level_data["carte"] as Array).duplicate()
	rows = grid.size()
	cols = String(grid[0]).length()
	max_hearts = GameData.max_hearts()
	hearts = max_hearts

	player.level = self
	player.apply_stats()
	player.melee.connect(_on_player_melee)
	player.fire.connect(_on_player_fire)
	touch.player = player
	touch.layout()

	setup_background()
	build_level()
	deco = Node2D.new()
	add_child(deco)
	move_child(deco, 0)  # dessiné avant le joueur
	deco.draw.connect(draw_deco)
	build_tile_chunks()
	setup_camera()
	setup_hud()
	setup_foreground()
	setup_lighting()
	setup_vignette()
	if world == 2:
		setup_rain()
	show_banner(level_data["nom"])


func build_level() -> void:
	var solid_body := StaticBody2D.new()
	add_child(solid_body)
	var mover_index := 0
	for r in rows:
		var line: String = grid[r]
		var c := 0
		while c < cols:
			var ch := line[c]
			if ch == "#" or ch == "=":
				# une seule forme de collision par suite de cases identiques
				var start := c
				while c < cols and line[c] == ch:
					c += 1
				add_run(solid_body, start, c, r, ch == "=")
				continue
			var center := Vector2(c * TILE + 16, r * TILE + 16)
			match ch:
				"P":
					player.global_position = center
					respawn_point = center
					set_cell(c, r, ".")
				"E":
					exit_pos = center
					set_cell(c, r, ".")
				"C":
					checkpoints.append({"pos": center, "on": false})
					set_cell(c, r, ".")
				"o":
					spawn_pickup("piece", center)
					set_cell(c, r, ".")
				"h":
					spawn_pickup("coeur", center)
					set_cell(c, r, ".")
				"*":
					var p = spawn_pickup("eclat", center)
					p.shard_id = shard_count
					shard_count += 1
					set_cell(c, r, ".")
				"B":
					add_crate(c, r)
				"m":
					add_mover(center, mover_index)
					mover_index += 1
					set_cell(c, r, ".")
				"Z":
					spawn_boss(center)
					set_cell(c, r, ".")
				_:
					if ENEMY_CHARS.has(ch):
						spawn_enemy(ENEMY_CHARS[ch], center)
						set_cell(c, r, ".")
			c += 1


func add_run(body: StaticBody2D, c0: int, c1: int, r: int, one_way: bool) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var h := 12.0 if one_way else float(TILE)
	rect.size = Vector2((c1 - c0) * TILE, h)
	shape.shape = rect
	shape.position = Vector2(c0 * TILE + rect.size.x * 0.5, r * TILE + h * 0.5)
	shape.one_way_collision = one_way
	body.add_child(shape)


func add_crate(c: int, r: int) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	shape.shape = rect
	body.position = Vector2(c * TILE + 16, r * TILE + 16)
	body.add_child(shape)
	add_child(body)
	crates[Vector2i(c, r)] = body


func add_mover(center: Vector2, index: int) -> void:
	var body := AnimatableBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(96, 12)
	shape.shape = rect
	shape.one_way_collision = true
	body.add_child(shape)
	body.position = Vector2(center.x, center.y - 10.0)
	add_child(body)
	body.draw.connect(draw_mover.bind(body))
	movers.append({"body": body, "base": body.position, "phase": PI * (index % 2)})


func spawn_boss(center: Vector2) -> void:
	var gy := center.y
	while not is_solid(Vector2(center.x, gy)) and gy < rows * TILE:
		gy += TILE
	boss = BossScript.new()
	boss.kind = level_data["boss"]
	boss.level = self
	boss.target = player
	boss.arena_left = TILE
	boss.arena_right = (cols - 1) * TILE
	boss.ground_y = floor(gy / TILE) * TILE
	boss.position = center
	add_child(boss)
	add_light(boss, 1.6, 0.7)
	exit_open = false
	exit_alpha = 0.0


# ---------- Accès à la grille ----------

func cell(c: int, r: int) -> String:
	if c < 0 or c >= cols or rows == 0:
		return "#"
	var line: String = grid[clampi(r, 0, rows - 1)]
	return line[c]


func set_cell(c: int, r: int, ch: String) -> void:
	var line: String = grid[r]
	grid[r] = line.substr(0, c) + ch + line.substr(c + 1)


func is_solid(p: Vector2, platforms := false) -> bool:
	var c := int(floor(p.x / TILE))
	var r := int(floor(p.y / TILE))
	if c < 0 or c >= cols:
		return true
	if r < 0 or r >= rows:
		return false
	var line: String = grid[r]
	var ch := line[c]
	return ch == "#" or ch == "B" or (platforms and ch == "=")


func world_bottom() -> float:
	return float(rows * TILE)


# ---------- Création d'objets ----------

func spawn_enemy(kind: String, pos: Vector2):
	var e = EnemyScript.new()
	e.kind = kind
	e.level = self
	e.target = player
	e.position = pos
	add_child(e)
	return e


func spawn_projectile(pos: Vector2, vel: Vector2, team: String, kind: String, damage := 1):
	var p = ProjectileScript.new()
	p.level = self
	p.team = team
	p.kind = kind
	p.velocity = vel
	p.damage = damage
	p.position = pos
	add_child(p)
	return p


func spawn_pickup(kind: String, pos: Vector2, pop := false):
	var p = PickupScript.new()
	p.kind = kind
	p.level = self
	p.target = player
	p.position = pos
	if pop:
		p.falling = true
		p.vel = Vector2(randf_range(-90, 90), randf_range(-280, -180))
	add_child(p)
	return p


func count_enemies(kind: String) -> int:
	var n := 0
	for e in group("ennemis"):
		if not e.dead and e.kind == kind:
			n += 1
	return n


# Liste non typée : on peut lire .dead, .kind... sans avertissement
func group(group_name: String) -> Array:
	return get_tree().get_nodes_in_group(group_name)


func boss_alive() -> bool:
	return boss != null and is_instance_valid(boss) and not boss.dead


# =====================================================================
#  CAMÉRA, HUD, EFFETS D'ÉCRAN
# =====================================================================

func setup_camera() -> void:
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = cols * TILE
	camera.limit_bottom = rows * TILE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)
	camera.make_current()
	update_zoom()


func update_zoom() -> void:
	# la hauteur du niveau (12 cases) remplit exactement la hauteur de l'écran
	var h := get_viewport().get_visible_rect().size.y
	var view_h := float(rows * TILE) if in_level else 384.0
	var z := h / view_h
	camera.zoom = Vector2(z, z)


func on_resize() -> void:
	if sky:
		sky.queue_redraw()
	if camera:
		update_zoom()
	if hud_layer:
		layout_hud()


func shake(amount: float) -> void:
	shake_amount = maxf(shake_amount, amount)


func freeze(duration: float) -> void:
	# « arrêt sur image » très court qui rend les coups plus percutants
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func setup_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.7))
	grad.add_point(0.55, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 1.25)
	tex.width = 256
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if POST_FX:
		setup_post_fx()


# Filtre plein écran : lueur autour des zones claires + grain de pellicule
const POST_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float grain_amount = 0.05;
uniform float bloom_amount = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;
	vec3 blur = textureLod(screen_tex, SCREEN_UV, 3.0).rgb * 0.6 + textureLod(screen_tex, SCREEN_UV, 5.0).rgb * 0.4;
	vec3 glow = max(blur - vec3(0.45), vec3(0.0)) * 1.8;
	vec3 col = base + glow * bloom_amount;
	float n = hash(floor(FRAGCOORD.xy / 2.0) + vec2(fract(TIME * 7.0) * 113.0));
	col += (n - 0.5) * grain_amount;
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(g), 1.0);
}
"""


func setup_post_fx() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	var shader := Shader.new()
	shader.code = POST_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var rect := ColorRect.new()
	rect.material = mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# ---------- Lumières 2D ----------

func make_light_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.35, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


# Ajoute une lumière ronde à un objet (taille 1.0 = 256 px de diamètre)
func add_light(node: Node, size: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.texture_scale = size
	l.energy = energy
	l.color = Color.WHITE
	node.add_child(l)
	return l


func setup_lighting() -> void:
	# assombrit le monde : seules les zones éclairées restent bien blanches
	var cm := CanvasModulate.new()
	var v: float = DARKNESS[world]
	cm.color = Color(v, v, v)
	add_child(cm)
	add_light(player, 2.4, 0.85)
	for cp in checkpoints:
		var holder := Node2D.new()
		holder.position = cp["pos"] + Vector2(0, -18)
		add_child(holder)
		cp["light"] = add_light(holder, 1.2, 0.25)
	var door := Node2D.new()
	door.position = exit_pos + Vector2(0, -12)
	add_child(door)
	door_light = add_light(door, 1.8, 0.0)


# ---------- Premier plan, brume ----------

func setup_foreground() -> void:
	# silhouettes noires devant le joueur, qui défilent plus vite (profondeur)
	var px := Parallax2D.new()
	px.scroll_scale = Vector2(1.3, 1.0)
	px.repeat_size = Vector2(900, 0)
	px.repeat_times = 3
	px.z_index = 15
	var art := Node2D.new()
	px.add_child(art)
	art.draw.connect(draw_foreground.bind(art))
	add_child(px)
	# brume qui avance doucement
	var fog := Parallax2D.new()
	fog.scroll_scale = Vector2(0.8, 1.0)
	fog.repeat_size = Vector2(PARALLAX_W, 0)
	fog.repeat_times = 3
	fog.z_index = 14
	fog_art = Node2D.new()
	fog.add_child(fog_art)
	fog_art.draw.connect(draw_fog)
	add_child(fog)


func draw_foreground(art: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + world
	var ink := Color(0, 0, 0, 0.92)
	# bas de l'écran : herbes / rochers / tombes
	var x := 0.0
	while x < 900.0:
		match world:
			1:
				var w := rng.randf_range(30, 70)
				art.draw_colored_polygon(PackedVector2Array([Vector2(x, 400), Vector2(x + w * 0.3, 372 - rng.randf_range(0, 20)), Vector2(x + w * 0.7, 368 - rng.randf_range(0, 24)), Vector2(x + w, 400)]), ink)
				x += w + rng.randf_range(60, 160)
			2:
				var h := rng.randf_range(16, 30)
				art.draw_rect(Rect2(x, 384 - h, 4, h + 20), ink)
				art.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 386 - h), Vector2(x + 2, 376 - h), Vector2(x + 7, 386 - h)]), ink)
				x += 14.0
			_:
				for i in 5:
					var bx := x + i * 5.0
					var h := rng.randf_range(10, 34)
					art.draw_colored_polygon(PackedVector2Array([Vector2(bx, 400), Vector2(bx + 5, 400), Vector2(bx + 2.5 + rng.randf_range(-6, 6), 384 - h)]), ink)
				x += rng.randf_range(40, 140)
	# haut de l'écran : lianes / stalactites / chaînes
	x = rng.randf_range(0, 60)
	while x < 900.0:
		match world:
			1:
				var w := rng.randf_range(16, 40)
				art.draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.5, -10), Vector2(x + w * 0.5, -10), Vector2(x, rng.randf_range(30, 70))]), ink)
				x += rng.randf_range(50, 140)
			2:
				var len_c := rng.randf_range(30, 80)
				var y := 0.0
				while y < len_c:
					art.draw_arc(Vector2(x, y), 3.5, 0.0, TAU, 8, ink, 2.0)
					y += 7.0
				x += rng.randf_range(120, 260)
			_:
				var len_v := rng.randf_range(20, 70)
				var pts := PackedVector2Array()
				for i in 8:
					var k := i / 7.0
					pts.append(Vector2(x + sin(k * 5.0 + x) * 4.0, -4.0 + k * len_v))
				art.draw_polyline(pts, ink, 2.0)
				for i in 3:
					var leaf := pts[2 + i * 2]
					art.draw_colored_polygon(PackedVector2Array([leaf, leaf + Vector2(5, 2), leaf + Vector2(1, 6)]), ink)
				x += rng.randf_range(40, 120)


func draw_fog() -> void:
	var tt := Time.get_ticks_msec() * 0.001
	var strength := 0.05 if world != 1 else 0.035
	for i in 14:
		var fx0 := fmod(i * 97.0 + tt * (6.0 + (i % 3) * 3.0), PARALLAX_W)
		var fy := 300.0 + (i % 4) * 14.0 + sin(tt * 0.5 + i) * 5.0
		fog_art.draw_set_transform(Vector2(fx0, fy), 0.0, Vector2(3.0, 0.6))
		fog_art.draw_circle(Vector2.ZERO, 40.0 + (i % 3) * 12.0, Color(1, 1, 1, strength))
	fog_art.draw_set_transform(Vector2.ZERO)


func setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS  # les boutons marchent pendant la pause
	add_child(hud_layer)
	hud_draw = Node2D.new()
	hud_layer.add_child(hud_draw)
	hud_draw.draw.connect(draw_hud)

	coin_label = MenuScript.make_label("0", 18)
	hud_layer.add_child(coin_label)
	banner = MenuScript.make_label("", 26)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_layer.add_child(banner)
	boss_label = MenuScript.make_label("", 14)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.visible = false
	hud_layer.add_child(boss_label)
	pause_button = MenuScript.make_button("II", 18)
	pause_button.custom_minimum_size = Vector2(46, 38)
	pause_button.pressed.connect(toggle_pause)
	hud_layer.add_child(pause_button)
	layout_hud()
	update_hud()


func layout_hud() -> void:
	var s := get_viewport().get_visible_rect().size
	coin_label.position = Vector2(36, 33 + heart_rows_offset())
	pause_button.position = Vector2(s.x - 58, 8)
	banner.position = Vector2(0, s.y * 0.2)
	banner.size = Vector2(s.x, 40)
	boss_label.position = Vector2(0, 8)
	boss_label.size = Vector2(s.x, 20)


func update_hud() -> void:
	if hud_draw == null:
		return
	coin_label.text = str(level_coins)
	coin_label.position = Vector2(36, 33 + heart_rows_offset())
	hud_draw.queue_redraw()


func show_banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 0.0
	var tw := banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.8)
	tw.tween_property(banner, "modulate:a", 0.0, 0.8)


func popup(text: String, pos: Vector2) -> void:
	var l := MenuScript.make_label(text, 14)
	l.position = pos + Vector2(-40, -40)
	l.size = Vector2(80, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 30
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 30.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


# =====================================================================
#  BOUCLE DE JEU
# =====================================================================

func _physics_process(delta: float) -> void:
	if not in_level:
		return
	time += delta
	for m in movers:
		var body: AnimatableBody2D = m["body"]
		var base: Vector2 = m["base"]
		body.position.x = base.x + sin(time * 1.1 + float(m["phase"])) * 64.0
		body.queue_redraw()
	if finished:
		return

	if invincible > 0.0:
		invincible -= delta
		player.modulate.a = 0.35 if fmod(invincible, 0.16) < 0.08 else 1.0
		if invincible <= 0.0:
			player.modulate.a = 1.0

	check_checkpoints()
	check_enemies()
	check_projectiles()
	check_spikes()
	if exit_open and player.global_position.distance_to(exit_pos) < 22.0:
		level_complete()
	elif player.global_position.y > world_bottom() + 48.0:
		fell_in_pit()


func check_checkpoints() -> void:
	for cp in checkpoints:
		if not cp["on"] and player.global_position.distance_to(cp["pos"]) < 30.0:
			cp["on"] = true
			respawn_point = cp["pos"]
			popup("POINT DE PASSAGE", cp["pos"])
			fx.ring(cp["pos"] + Vector2(0, -14), 10.0, Color.WHITE, 0.5)
			fx.burst(cp["pos"] + Vector2(0, -14), 12, 80.0, Color.WHITE, 0.6, 2.0, 0.0, 30.0)


func stomp_damage() -> int:
	return 3 if GameData.character == "roc" else 2


func check_enemies() -> void:
	var pr: Rect2 = player.get_hit_rect()
	for e in group("ennemis"):
		if e.dead:
			continue
		var er: Rect2 = e.get_hit_rect()
		if not pr.intersects(er):
			continue
		# on tombe dessus par le dessus : écrasé !
		if player.velocity.y > 30.0 and pr.end.y < er.position.y + 14.0 and e.stompable:
			player.bounce()
			e.take_damage(stomp_damage(), player.global_position.x)
			fx.ring(Vector2(player.global_position.x, pr.end.y), 12.0, Color.WHITE, 0.3)
		elif not player.is_invulnerable():
			hurt_player(1, er.get_center().x)

	if boss_alive() and boss.is_harmful():
		var br: Rect2 = boss.get_hit_rect()
		if pr.intersects(br):
			if player.velocity.y > 30.0 and pr.end.y < br.position.y + 16.0:
				player.bounce()
				boss.take_damage(1, player.global_position.x)
			elif not player.is_invulnerable():
				hurt_player(1, br.get_center().x)


func check_projectiles() -> void:
	var pr: Rect2 = player.get_hit_rect()
	for p in group("proj_ennemi"):
		if p.is_queued_for_deletion():
			continue
		if pr.intersects(p.get_hit_rect()) and not player.is_invulnerable():
			if hurt_player(p.damage, p.position.x):
				p.explode()

	var foes := group("ennemis")
	for p in group("proj_joueur"):
		if p.is_queued_for_deletion():
			continue
		var hr: Rect2 = p.get_hit_rect()
		var hit := false
		for e in foes:
			if not e.dead and hr.intersects(e.get_hit_rect()):
				e.take_damage(p.damage, p.position.x)
				hit = true
				break
		if not hit and boss_alive() and boss.can_be_hit() and hr.intersects(boss.get_hit_rect()):
			boss.take_damage(p.damage, p.position.x)
			hit = true
		if hit:
			p.explode()


func check_spikes() -> void:
	if player.is_invulnerable() or invincible > 0.0:
		return
	var pr: Rect2 = player.get_hit_rect()
	var c0 := int(floor(pr.position.x / TILE))
	var c1 := int(floor(pr.end.x / TILE))
	var r0 := int(floor(pr.position.y / TILE))
	var r1 := int(floor(pr.end.y / TILE))
	for r in range(r0, r1 + 1):
		if r < 0 or r >= rows:
			continue
		for c in range(c0, c1 + 1):
			var ch := cell(c, r)
			var danger := Rect2()
			if ch == "^":
				danger = Rect2(c * TILE + 4, r * TILE + 18, 24, 14)
			elif ch == "v":
				danger = Rect2(c * TILE + 4, r * TILE, 24, 14)
			else:
				continue
			if pr.intersects(danger):
				hurt_player(1, c * TILE + 16.0)
				return


# Retourne true si le joueur a vraiment été touché
func hurt_player(amount: int, from_x: float) -> bool:
	if invincible > 0.0 or finished or player.dead:
		return false
	hearts -= amount
	shake(7.0)
	fx.burst(player.global_position, 14, 150.0, Color.WHITE, 0.4, 2.5)
	freeze(0.07)
	update_hud()
	if hearts <= 0:
		hearts = 0
		update_hud()
		player_died()
		return true
	player.take_hit(from_x)
	invincible = INVINCIBLE_TIME
	return true


func fell_in_pit() -> void:
	if player.dead:
		return
	hearts -= 1
	update_hud()
	if hearts <= 0:
		hearts = 0
		player_died()
		return
	for p in group("proj_ennemi"):
		p.queue_free()
	player.global_position = respawn_point
	player.velocity = Vector2.ZERO
	camera.reset_smoothing()
	invincible = INVINCIBLE_TIME
	shake(4.0)


# ---------- Attaques du joueur ----------

func _on_player_melee(hit_rect: Rect2, damage: int) -> void:
	var hit_any := false
	for e in group("ennemis"):
		if not e.dead and hit_rect.intersects(e.get_hit_rect()):
			e.take_damage(damage, player.global_position.x)
			hit_any = true
	if boss_alive() and hit_rect.intersects(boss.get_hit_rect()):
		if boss.take_damage(damage, player.global_position.x) or boss.can_be_hit():
			hit_any = true
	# l'arme détruit aussi les projectiles ennemis
	for p in group("proj_ennemi"):
		if hit_rect.intersects(p.get_hit_rect()):
			p.explode()
			hit_any = true
	# et casse les caisses
	var c0 := int(floor(hit_rect.position.x / TILE))
	var c1 := int(floor(hit_rect.end.x / TILE))
	var r0 := int(floor(hit_rect.position.y / TILE))
	var r1 := int(floor(hit_rect.end.y / TILE))
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if crates.has(Vector2i(c, r)):
				break_crate(c, r)
				hit_any = true
	if hit_any:
		shake(3.0)
		freeze(0.04)


func _on_player_fire(from_pos: Vector2, dir_x: float) -> void:
	var angles := [0.0]
	if GameData.get_level("feu") >= 3:
		angles = [-0.22, 0.0, 0.22]
	for a in angles:
		spawn_projectile(from_pos, Vector2(dir_x * 300.0, 0).rotated(a * dir_x), "joueur", "feu", 1)
	fx.burst(from_pos, 6, 70.0, Color.WHITE, 0.25, 2.0)


func on_projectile_wall(p) -> void:
	if p.team != "joueur":
		return
	var c := int(floor(p.position.x / TILE))
	var r := int(floor(p.position.y / TILE))
	if crates.has(Vector2i(c, r)):
		break_crate(c, r)


func break_crate(c: int, r: int) -> void:
	var key := Vector2i(c, r)
	if not crates.has(key):
		return
	crates[key].queue_free()
	crates.erase(key)
	set_cell(c, r, ".")
	var center := Vector2(c * TILE + 16, r * TILE + 16)
	fx.burst(center, 16, 160.0, Color.WHITE, 0.7, 3.5, 600.0, 120.0)
	for i in 3:
		spawn_pickup("piece", center, true)
	redraw_tiles()


func on_enemy_killed(e) -> void:
	fx.burst(e.position, 18, 160.0, Color.WHITE, 0.5, 3.0)
	fx.ring(e.position, 10.0, Color.WHITE, 0.35)
	for i in e.coins:
		spawn_pickup("piece", e.position, true)
	shake(3.0)
	freeze(0.05)


func on_boss_defeated(b) -> void:
	exit_open = true
	boss_label.visible = false
	popup("VICTOIRE !", b.position)
	for i in 15:
		spawn_pickup("piece", b.position, true)
	spawn_pickup("coeur", b.position, true)
	# réceptacle de coeur : +1 coeur maximum pour toujours (une fois par boss)
	if not GameData.containers.has(GameData.current_level):
		spawn_pickup("receptacle", b.position + Vector2(0, -10), true)
	shake(12.0)
	var tw := create_tween()
	tw.tween_property(self, "exit_alpha", 1.0, 1.0)


func collect(p) -> void:
	match p.kind:
		"piece":
			level_coins += 1
			fx.burst(p.position, 5, 60.0, Color.WHITE, 0.3, 2.0)
		"coeur":
			hearts = mini(max_hearts, hearts + 1)
			popup("+1 COEUR", p.position)
			fx.ring(p.position, 10.0, Color.WHITE, 0.4)
		"eclat":
			if p.shard_id >= 0 and p.shard_id < 3:
				shards_found[p.shard_id] = true
			popup("ÉCLAT DE LUNE !", p.position)
			fx.ring(p.position, 14.0, Color.WHITE, 0.6)
			fx.burst(p.position, 20, 120.0, Color.WHITE, 0.8, 2.5)
			freeze(0.06)
		"receptacle":
			GameData.containers[GameData.current_level] = true
			GameData.save_game()
			max_hearts += 1
			hearts = max_hearts
			popup("+1 COEUR MAXIMUM !", p.position)
			fx.ring(p.position, 20.0, Color.WHITE, 0.8)
			fx.burst(p.position, 30, 160.0, Color.WHITE, 0.9, 3.0)
			freeze(0.1)
	update_hud()


# =====================================================================
#  FIN DE NIVEAU, MORT, PAUSE
# =====================================================================

func level_complete() -> void:
	finished = true
	player.can_control = false
	player.velocity = Vector2.ZERO
	touch.release_all()
	touch.visible = false
	var idx := GameData.current_level
	var bonus := hearts * 5
	var found: int = shards_found.count(true)
	var is_boss: bool = level_data["boss"] != ""
	if is_boss:
		found = 1
	GameData.coins += level_coins + bonus
	GameData.shards[idx] = maxi(int(GameData.shards.get(idx, 0)), found)
	GameData.unlocked = maxi(GameData.unlocked, mini(idx + 1, Levels.LEVELS.size() - 1))
	GameData.save_game()

	fx.burst(exit_pos, 30, 150.0, Color.WHITE, 0.8, 3.0, 0.0, 40.0)
	var tw: Tween = player.create_tween()
	tw.tween_property(player, "modulate:a", 0.0, 0.5)

	var text := "Pièces : %d  (+%d bonus de coeurs)" % [level_coins, bonus]
	if not is_boss:
		text += "\nÉclats de lune : %d / 3" % found
	var buttons := []
	var title := "NIVEAU TERMINÉ !"
	if idx + 1 < Levels.LEVELS.size():
		buttons.append(["SUIVANT", next_level])
	else:
		title = "LE ROI OMBRE EST VAINCU !"
		text += "\nMerci d'avoir joué !"
	buttons.append(["MAGASIN", go_shop])
	buttons.append(["CARTE", go_map])
	await get_tree().create_timer(0.9).timeout
	show_panel(title, text, buttons)


func player_died() -> void:
	finished = true
	player.die()
	touch.release_all()
	touch.visible = false
	var kept := int(level_coins * 0.5)
	GameData.coins += kept
	GameData.save_game()
	shake(10.0)
	await get_tree().create_timer(1.3).timeout
	show_panel("VAINCU...", "Tu gardes la moitié des pièces : %d" % kept,
		[["RÉESSAYER", restart], ["MAGASIN", go_shop], ["CARTE", go_map]])


func toggle_pause() -> void:
	if finished:
		return
	if get_tree().paused:
		resume()
		return
	get_tree().paused = true
	touch.release_all()
	show_panel("PAUSE", level_data["nom"], [["REPRENDRE", resume], ["RECOMMENCER", restart], ["CARTE", go_map]])


func resume() -> void:
	get_tree().paused = false
	touch.release_all()
	if panel:
		panel.queue_free()
		panel = null


func restart() -> void:
	get_tree().paused = false
	GameData.screen = "niveau"
	get_tree().reload_current_scene()


func next_level() -> void:
	GameData.current_level += 1
	restart()


func go_map() -> void:
	get_tree().paused = false
	GameData.screen = "carte"
	get_tree().reload_current_scene()


func go_shop() -> void:
	get_tree().paused = false
	GameData.screen = "magasin"
	get_tree().reload_current_scene()


func show_panel(title: String, text: String, buttons: Array) -> void:
	if panel:
		panel.queue_free()
	var cc := CenterContainer.new()
	hud_layer.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := MenuScript.make_panel()
	cc.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	p.add_child(box)
	var t := MenuScript.make_label(title, 28)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var l := MenuScript.make_label(text, 16, Color(0.85, 0.85, 0.85))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for b in buttons:
		var btn := MenuScript.make_button(b[0], 18)
		btn.custom_minimum_size = Vector2(120, 44)
		btn.pressed.connect(b[1])
		row.add_child(btn)
	cc.modulate.a = 0.0
	var tw := cc.create_tween()
	tw.tween_property(cc, "modulate:a", 1.0, 0.25)
	panel = cc


# =====================================================================
#  EFFETS CONTINUS
# =====================================================================

func _process(delta: float) -> void:
	if camera:
		if in_level:
			var target_look := 0.0
			if not player.dead and not finished:
				target_look = player.facing * 36.0
			look = lerpf(look, target_look, minf(1.0, 3.0 * delta))
		else:
			camera.position.x += 25.0 * delta  # défilement lent derrière le menu
		camera.offset = Vector2(look, 0) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
		shake_amount = move_toward(shake_amount, 0.0, 30.0 * delta)
		ambient(delta)

	if deco:
		deco.queue_redraw()
	if fog_art:
		fog_art.queue_redraw()
	var tt := Time.get_ticks_msec() * 0.001
	for cp in checkpoints:
		if cp.has("light"):
			var l: PointLight2D = cp["light"]
			l.enabled = cp["on"]
			l.energy = 1.0 + 0.15 * sin(tt * 13.0 + l.global_position.x)
	if door_light:
		door_light.enabled = exit_alpha > 0.0
		door_light.energy = exit_alpha * (1.1 + 0.2 * sin(tt * 3.0))
	if world == 2:
		update_weather(delta)
	if boss != null:
		if not is_instance_valid(boss):
			boss = null
			boss_label.visible = false
		else:
			boss_label.visible = not boss.dead
			boss_label.text = boss.display_name
		if hud_draw:
			hud_draw.queue_redraw()


func ambient(delta: float) -> void:
	ambient_timer -= delta
	if ambient_timer > 0.0:
		return
	ambient_timer = 0.12
	var center := camera.get_screen_center_position()
	var half := get_viewport().get_visible_rect().size / camera.zoom * 0.5
	var p := center + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
	match world:
		0:
			# lucioles
			fx.spawn(p, Vector2(randf_range(-12, 12), randf_range(-14, -4)), Color(1, 1, 1, 0.9), 2.5, 2.0)
		1:
			# gouttes qui tombent du plafond
			fx.spawn(Vector2(p.x, 66.0), Vector2(0, 20), Color(0.85, 0.85, 0.85, 0.8), 1.2, 2.0, 450.0)
		2:
			# cendres
			fx.spawn(Vector2(p.x, center.y - half.y), Vector2(randf_range(-25, -5), 35), Color(0.7, 0.7, 0.7, 0.6), 5.0, 2.0)


func setup_rain() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	weather = Node2D.new()
	layer.add_child(weather)
	weather.draw.connect(draw_weather)
	var s := get_viewport().get_visible_rect().size
	for i in 70:
		rain.append(Vector2(randf() * s.x, randf() * s.y))


func update_weather(delta: float) -> void:
	next_lightning -= delta
	if next_lightning <= 0.0:
		next_lightning = randf_range(6.0, 12.0)
		flash_alpha = 0.7
		shake(2.0)
	flash_alpha = move_toward(flash_alpha, 0.0, delta * 2.5)
	if weather:
		var s := get_viewport().get_visible_rect().size
		for i in rain.size():
			var d: Vector2 = rain[i]
			d += Vector2(-120.0, 520.0) * delta
			if d.y > s.y:
				d = Vector2(randf() * (s.x + 100.0), -10.0)
			rain[i] = d
		weather.queue_redraw()
	if sky:
		sky.queue_redraw()


func draw_weather() -> void:
	for d in rain:
		weather.draw_line(d, d + Vector2(-3, 11), Color(0.85, 0.85, 0.85, 0.35), 1.0)
	if flash_alpha > 0.0:
		var s := get_viewport().get_visible_rect().size
		weather.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, flash_alpha * 0.25))


# =====================================================================
#  DESSIN : HUD
# =====================================================================

func draw_hud() -> void:
	var s := get_viewport().get_visible_rect().size
	# coeurs : 8 par ligne
	for i in max_hearts:
		draw_heart(Vector2(14 + (i % 8) * 24, 10 + floori(i / 8.0) * 22), i < hearts)
	# pièce
	var coin_y := 46.0 + heart_rows_offset()
	hud_draw.draw_circle(Vector2(22, coin_y), 8.0, Color.BLACK)
	hud_draw.draw_circle(Vector2(22, coin_y), 6.5, Color.WHITE)
	hud_draw.draw_arc(Vector2(22, coin_y), 3.5, 0.0, TAU, 12, Color(0.35, 0.35, 0.35), 1.5)
	# éclats de lune
	if level_data.get("boss", "") == "":
		for i in 3:
			var c := Vector2(s.x - 80 - i * 22, 27)
			if shards_found[2 - i]:
				hud_draw.draw_circle(c, 7.0, Color.WHITE)
				hud_draw.draw_circle(c + Vector2(3.5, -2.5), 6.0, Color.BLACK)
			else:
				hud_draw.draw_arc(c, 7.0, 0.0, TAU, 16, Color(0.45, 0.45, 0.45), 1.5)
	# barre de vie du boss
	if boss != null and is_instance_valid(boss) and not boss.dead:
		var w := s.x * 0.42
		var x := (s.x - w) * 0.5
		var y := 30.0
		hud_draw.draw_rect(Rect2(x - 2, y - 2, w + 4, 14), Color.BLACK)
		hud_draw.draw_rect(Rect2(x, y, w * float(boss.hp) / float(boss.max_hp), 10), Color.WHITE)
		hud_draw.draw_rect(Rect2(x - 2, y - 2, w + 4, 14), Color.WHITE, false, 1.5)


func heart_rows_offset() -> float:
	return (ceili(max_hearts / 8.0) - 1) * 22.0


func draw_heart(pos: Vector2, full: bool) -> void:
	for y in 6:
		var line: String = HEART[y]
		for x in 7:
			if line[x] == "#":
				hud_draw.draw_rect(Rect2(pos + Vector2(x, y) * 3.0 - Vector2(1, 1), Vector2(5, 5)), Color.BLACK)
	for y in 6:
		var line: String = HEART[y]
		for x in 7:
			if line[x] == "#":
				var col := Color.WHITE if full else Color(0.28, 0.28, 0.28)
				hud_draw.draw_rect(Rect2(pos + Vector2(x, y) * 3.0, Vector2(3, 3)), col)


# =====================================================================
#  DESSIN : DÉCOR DE FOND (ciel + 2 couches en parallaxe par monde)
# =====================================================================

func setup_background() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	sky = Node2D.new()
	sky_layer.add_child(sky)
	sky.draw.connect(draw_sky)
	match world:
		1:
			add_parallax(0.2, draw_cave_far)
			add_parallax(0.45, draw_cave_near)
		2:
			add_parallax(0.12, draw_castle_far)
			add_parallax(0.4, draw_graveyard)
		_:
			add_parallax(0.15, draw_far_hills)
			add_parallax(0.4, draw_near_forest)


func add_parallax(scroll: float, fn: Callable) -> void:
	var px := Parallax2D.new()
	px.scroll_scale = Vector2(scroll, 1.0)
	px.repeat_size = Vector2(PARALLAX_W, 0)
	px.repeat_times = 3
	px.z_index = -5
	var art := Node2D.new()
	px.add_child(art)
	art.draw.connect(fn.bind(art))
	add_child(px)


func draw_sky() -> void:
	var s := get_viewport().get_visible_rect().size
	var top := 0.02
	var bottom := 0.3
	if world == 1:
		top = 0.0
		bottom = 0.08
	elif world == 2:
		top = 0.03
		bottom = 0.22
	var bands := 32
	for i in bands:
		var k := float(i) / (bands - 1)
		var g := lerpf(top, bottom, k * k)
		sky.draw_rect(Rect2(0, s.y * i / bands, s.x, s.y / bands + 1.0), Color(g, g, g))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	if world == 1:
		# grotte : quelques cristaux qui scintillent au loin
		for i in 25:
			var p := Vector2(rng.randf() * s.x, rng.randf() * s.y)
			var a := 0.15 + 0.15 * sin(Time.get_ticks_msec() * 0.002 + i)
			sky.draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 1, 1, a))
		return
	for i in 70:
		var p := Vector2(rng.randf() * s.x, rng.randf() * s.y * 0.6)
		sky.draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(1, 1, 1, rng.randf_range(0.2, 0.8)))
	var m := Vector2(s.x * (0.78 if world == 0 else 0.25), s.y * 0.2)
	var r := s.y * (0.08 if world == 0 else 0.13)
	# rayons de lune
	var sway := sin(Time.get_ticks_msec() * 0.0003) * 0.05
	for k in 6:
		var a := 1.75 + (k - 2.5) * 0.22 + sway
		var d1 := Vector2(cos(a - 0.04), sin(a - 0.04)) * s.y * 1.6
		var d2 := Vector2(cos(a + 0.04), sin(a + 0.04)) * s.y * 1.6
		sky.draw_colored_polygon(PackedVector2Array([m, m + d1, m + d2]), Color(1, 1, 1, 0.025))
	for k in 5:
		sky.draw_circle(m, r * (1.3 + k * 0.45), Color(1, 1, 1, 0.035))
	sky.draw_circle(m, r, Color(0.95, 0.95, 0.95))
	sky.draw_circle(m + Vector2(-r * 0.3, -r * 0.2), r * 0.22, Color(0.8, 0.8, 0.8))
	sky.draw_circle(m + Vector2(r * 0.35, r * 0.25), r * 0.15, Color(0.82, 0.82, 0.82))
	sky.draw_circle(m + Vector2(-r * 0.1, r * 0.5), r * 0.1, Color(0.84, 0.84, 0.84))
	if world == 2:
		# nuages d'orage qui passent devant la lune
		var tt := Time.get_ticks_msec() * 0.001
		for i in 6:
			var cx := fmod(i * 170.0 + tt * (8.0 + i * 2.0), s.x + 300.0) - 150.0
			var cy := s.y * (0.12 + 0.07 * (i % 3))
			for k in 4:
				sky.draw_circle(Vector2(cx + k * 26.0, cy + sin(k * 1.7) * 6.0), 22.0 + (k % 2) * 8.0, Color(0.08, 0.08, 0.08, 0.85))
		if flash_alpha > 0.0:
			sky.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, flash_alpha * 0.5))


func hill_y(x: float, base_y: float, amp: float, seed_value: float) -> float:
	var t := x / PARALLAX_W * TAU
	return base_y - amp * (0.6 * sin(t * 2.0 + seed_value) + 0.4 * sin(t * 5.0 + seed_value * 2.0))


func draw_hill_band(art: Node2D, base_y: float, amp: float, seed_value: float, color: Color, rim: Color) -> void:
	var pts := PackedVector2Array()
	var top := PackedVector2Array()
	for i in 81:
		var x := PARALLAX_W * i / 80.0
		var p := Vector2(x, hill_y(x, base_y, amp, seed_value))
		pts.append(p)
		top.append(p)
	pts.append(Vector2(PARALLAX_W, 520))
	pts.append(Vector2(0, 520))
	art.draw_colored_polygon(pts, color)
	art.draw_polyline(top, rim, 1.5)


func draw_far_hills(art: Node2D) -> void:
	draw_hill_band(art, 270.0, 50.0, 1.0, Color(0.15, 0.15, 0.15), Color(0.3, 0.3, 0.3))


func draw_near_forest(art: Node2D) -> void:
	draw_hill_band(art, 315.0, 26.0, 4.0, Color(0.08, 0.08, 0.08), Color(0.2, 0.2, 0.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 8:
		var tx := 70.0 + k * 150.0
		draw_dead_tree(art, Vector2(tx, hill_y(tx, 315.0, 26.0, 4.0) + 4.0), rng.randf_range(60, 110), Color(0.03, 0.03, 0.03), rng)
	# brume
	art.draw_rect(Rect2(0, 300, PARALLAX_W, 30), Color(1, 1, 1, 0.03))
	art.draw_rect(Rect2(0, 312, PARALLAX_W, 30), Color(1, 1, 1, 0.03))


func draw_cave_far(art: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var col := Color(0.09, 0.09, 0.09)
	for k in 12:
		var x := k * 100.0 + rng.randf_range(-20, 20)
		var w := rng.randf_range(30, 70)
		var h := rng.randf_range(60, 150)
		art.draw_colored_polygon(PackedVector2Array([Vector2(x - w, 0), Vector2(x + w, 0), Vector2(x + rng.randf_range(-8, 8), h)]), col)
		var h2 := rng.randf_range(60, 160)
		art.draw_colored_polygon(PackedVector2Array([Vector2(x + 40 - w, 400), Vector2(x + 40 + w, 400), Vector2(x + 40, 400 - h2)]), col)
	for i in 20:
		var p := Vector2(rng.randf() * PARALLAX_W, rng.randf_range(120, 300))
		art.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(3, 0), p + Vector2(0, 5), p + Vector2(-3, 0)]), Color(1, 1, 1, 0.25))


func draw_cave_near(art: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var col := Color(0.045, 0.045, 0.045)
	for k in 5:
		var x := k * 240.0 + 60.0
		var w := rng.randf_range(26, 44)
		# colonne de roche
		var pts := PackedVector2Array()
		for i in 9:
			var y := i * 50.0
			pts.append(Vector2(x - w + sin(i * 1.3 + k) * 8.0, y))
		for i in range(8, -1, -1):
			var y := i * 50.0
			pts.append(Vector2(x + w + cos(i * 1.1 + k) * 8.0, y))
		art.draw_colored_polygon(pts, col)


func draw_castle_far(art: Node2D) -> void:
	var col := Color(0.13, 0.13, 0.13)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	art.draw_rect(Rect2(0, 260, PARALLAX_W, 260), col)
	for k in 7:
		var x := 40.0 + k * 170.0
		var w := rng.randf_range(40, 70)
		var h := rng.randf_range(90, 170)
		var top := 260.0 - h
		art.draw_rect(Rect2(x, top, w, h + 10), col)
		# créneaux ou toit pointu
		if k % 2 == 0:
			for i in int(w / 12.0):
				art.draw_rect(Rect2(x + i * 12.0, top - 8, 7, 8), col)
		else:
			art.draw_colored_polygon(PackedVector2Array([Vector2(x - 6, top), Vector2(x + w * 0.5, top - 50), Vector2(x + w + 6, top)]), col)
		# fenêtres allumées
		for i in 3:
			if rng.randf() < 0.6:
				art.draw_rect(Rect2(x + w * 0.5 - 3, top + 20 + i * 30, 6, 10), Color(0.75, 0.75, 0.75))
	for i in 12:
		var x := rng.randf() * PARALLAX_W
		art.draw_rect(Rect2(x, 240, 6, 20), col)


func draw_graveyard(art: Node2D) -> void:
	draw_hill_band(art, 330.0, 14.0, 2.0, Color(0.06, 0.06, 0.06), Color(0.18, 0.18, 0.18))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var col := Color(0.06, 0.06, 0.06)
	for k in 16:
		var x := 30.0 + k * 75.0 + rng.randf_range(-10, 10)
		var y := hill_y(x, 330.0, 14.0, 2.0)
		if k % 3 == 0:
			art.draw_rect(Rect2(x - 2, y - 30, 4, 30), col)
			art.draw_rect(Rect2(x - 10, y - 22, 20, 4), col)
		else:
			art.draw_rect(Rect2(x - 8, y - 18, 16, 18), col)
			art.draw_circle(Vector2(x, y - 18), 8.0, col)
	# grille en fer
	for i in 60:
		var x := i * 20.0
		art.draw_line(Vector2(x, 300), Vector2(x, 345), Color(0.1, 0.1, 0.1), 2.0)
		art.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 302), Vector2(x, 294), Vector2(x + 3, 302)]), Color(0.1, 0.1, 0.1))
	art.draw_line(Vector2(0, 308), Vector2(PARALLAX_W, 308), Color(0.1, 0.1, 0.1), 2.0)


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


# =====================================================================
#  DESSIN : CASES DU NIVEAU (dessinées une fois, redessinées si une caisse casse)
# =====================================================================

func build_tile_chunks() -> void:
	# le décor est découpé en tranches de 16 colonnes (plus rapide, et chaque tranche
	# ne reçoit que les lumières proches)
	var c0 := 0
	while c0 < cols:
		var chunk := Node2D.new()
		add_child(chunk)
		move_child(chunk, 0)
		chunk.draw.connect(draw_chunk.bind(chunk, c0, mini(c0 + 16, cols)))
		tile_chunks.append(chunk)
		c0 += 16


func redraw_tiles() -> void:
	for chunk in tile_chunks:
		chunk.queue_redraw()


func draw_chunk(chunk: Node2D, c0: int, c1: int) -> void:
	canvas = chunk
	var rng := RandomNumberGenerator.new()
	for r in rows:
		var line: String = grid[r]
		for c in range(c0, c1):
			var ch := line[c]
			rng.seed = tile_hash(c, r)
			match ch:
				"#":
					draw_tile(c, r, rng)
				"=":
					draw_platform(c, r, rng)
				"B":
					draw_crate(c, r)
				"^":
					draw_spikes(c, r, false)
				"v":
					draw_spikes(c, r, true)


func tile_hash(c: int, r: int) -> int:
	return absi((c * 73856093) ^ (r * 19349663)) % 100000


func depth_of(c: int, r: int) -> int:
	# distance au bord le plus proche (pour assombrir l'intérieur des blocs)
	for d in range(1, 4):
		if cell(c, r - d) != "#" or cell(c, r + d) != "#" or cell(c - d, r) != "#" or cell(c + d, r) != "#":
			return d
	return 4


func draw_tile(c: int, r: int, rng: RandomNumberGenerator) -> void:
	var x := float(c * TILE)
	var y := float(r * TILE)
	var rect := Rect2(x, y, TILE, TILE)
	var shade: float = [1.0, 1.0, 0.8, 0.62, 0.5][depth_of(c, r)]
	var base := Color(shade, shade, shade)
	canvas.draw_rect(rect, base)
	var ink := Color(0, 0, 0, 0.55 * shade)
	var up := cell(c, r - 1) != "#"
	var down := cell(c, r + 1) != "#"
	# léger dégradé vertical dans chaque case (volume)
	canvas.draw_rect(Rect2(x, y + 22, TILE, 10), Color(0, 0, 0, 0.08))
	if cell(c - 1, r) != "#":
		canvas.draw_line(Vector2(x + 1, y), Vector2(x + 1, y + TILE), Color.BLACK, 2.0)
		canvas.draw_line(Vector2(x + 3, y + 2), Vector2(x + 3, y + TILE), Color(1, 1, 1, 0.5), 1.0)
	if cell(c + 1, r) != "#":
		canvas.draw_line(Vector2(x + TILE - 1, y), Vector2(x + TILE - 1, y + TILE), Color.BLACK, 2.0)
		canvas.draw_line(Vector2(x + TILE - 4, y + 2), Vector2(x + TILE - 4, y + TILE), Color(0, 0, 0, 0.15), 2.0)
	if down and r < rows - 1:
		canvas.draw_line(Vector2(x, y + TILE - 1), Vector2(x + TILE, y + TILE - 1), Color.BLACK, 2.0)

	match world:
		1:
			# roche : fissures
			for i in 2:
				var p := Vector2(x + rng.randf_range(4, 28), y + rng.randf_range(4, 28))
				canvas.draw_line(p, p + Vector2(rng.randf_range(-7, 7), rng.randf_range(3, 8)), ink, 1.0)
			if down and r > 0:
				# petites stalactites sous le plafond
				var sx := x + rng.randf_range(6, 26)
				var tri := PackedVector2Array([Vector2(sx - 4, y + TILE), Vector2(sx + 4, y + TILE), Vector2(sx, y + TILE + rng.randf_range(6, 14))])
				canvas.draw_colored_polygon(tri, base)
				canvas.draw_polyline(PackedVector2Array([tri[0], tri[2], tri[1]]), Color.BLACK, 1.0)
		2:
			# briques
			var mortar := Color(0, 0, 0, 0.4 * shade)
			canvas.draw_line(Vector2(x, y + 16), Vector2(x + TILE, y + 16), mortar, 1.0)
			canvas.draw_line(Vector2(x, y), Vector2(x + TILE, y), mortar, 1.0)
			var off := 0.0 if r % 2 == 0 else 16.0
			canvas.draw_line(Vector2(x + off, y), Vector2(x + off, y + 16), mortar, 1.0)
			canvas.draw_line(Vector2(x + 16 - off + 8, y + 16), Vector2(x + 16 - off + 8, y + 32), mortar, 1.0)
			if rng.randi() % 7 == 0:
				# lierre noir
				var p := Vector2(x + rng.randf_range(4, 28), y)
				for i in 4:
					var q := p + Vector2(sin(i * 1.7) * 4.0, 7.0)
					canvas.draw_line(p, q, Color.BLACK, 1.5)
					canvas.draw_circle(q, 2.0, Color.BLACK)
					p = q
		_:
			# terre : cailloux et racines
			if rng.randi() % 3 == 0:
				canvas.draw_circle(Vector2(x + rng.randf_range(5, 27), y + rng.randf_range(8, 28)), rng.randf_range(1.0, 2.5), ink)
			if rng.randi() % 5 == 0:
				var p := Vector2(x + rng.randf_range(4, 28), y + rng.randf_range(6, 20))
				canvas.draw_line(p, p + Vector2(rng.randf_range(-6, 6), 8), ink, 1.0)

	if up:
		if world == 0:
			# herbe noire sur le dessus
			var gx := x
			while gx < x + TILE - 2.0:
				var h := rng.randf_range(4.0, 9.0)
				var lean := rng.randf_range(-2.0, 2.0)
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(gx, y + 5), Vector2(gx + 3, y + 5), Vector2(gx + 1.5 + lean, y + 5 - h)]), Color.BLACK)
				gx += rng.randf_range(3.0, 5.0)
			if rng.randi() % 6 == 0:
				# petite fleur blanche
				var fx0 := x + rng.randf_range(6, 26)
				canvas.draw_line(Vector2(fx0, y + 2), Vector2(fx0, y - 6), Color.BLACK, 1.0)
				canvas.draw_circle(Vector2(fx0, y - 7), 2.0, Color.WHITE)
				canvas.draw_circle(Vector2(fx0, y - 7), 0.8, Color.BLACK)
		elif world == 1:
			canvas.draw_line(Vector2(x, y + 1), Vector2(x + TILE, y + 1), Color(0.6, 0.6, 0.6), 2.0)
			if rng.randi() % 5 == 0 and r > 2:
				# cristaux lumineux
				var cx := x + rng.randf_range(8, 24)
				canvas.draw_circle(Vector2(cx, y - 6), 12.0, Color(1, 1, 1, 0.08))
				for i in 3:
					var h := rng.randf_range(8, 16)
					var ox := (i - 1) * 5.0
					var tilt := (i - 1) * 3.0
					var cr := PackedVector2Array([Vector2(cx + ox - 2.5, y + 1), Vector2(cx + ox + tilt, y - h), Vector2(cx + ox + 2.5, y + 1)])
					canvas.draw_colored_polygon(cr, Color.WHITE)
					canvas.draw_polyline(cr, Color.BLACK, 1.0)
		else:
			canvas.draw_rect(Rect2(x, y, TILE, 4), Color(0.85, 0.85, 0.85))
			canvas.draw_line(Vector2(x, y + 4), Vector2(x + TILE, y + 4), Color(0, 0, 0, 0.5), 1.0)


func draw_platform(c: int, r: int, rng: RandomNumberGenerator) -> void:
	var x := float(c * TILE)
	var y := float(r * TILE)
	var rect := Rect2(x, y, TILE, 12)
	match world:
		1:
			canvas.draw_rect(rect, Color(0.85, 0.85, 0.85))
			canvas.draw_rect(rect, Color.BLACK, false, 1.0)
			canvas.draw_line(Vector2(x + rng.randf_range(6, 26), y + 2), Vector2(x + rng.randf_range(6, 26), y + 10), Color(0, 0, 0, 0.5), 1.0)
			var tri := PackedVector2Array([Vector2(x + 10, y + 12), Vector2(x + 22, y + 12), Vector2(x + 16, y + 22)])
			canvas.draw_colored_polygon(tri, Color(0.85, 0.85, 0.85))
			canvas.draw_polyline(PackedVector2Array([tri[0], tri[2], tri[1]]), Color.BLACK, 1.0)
		2:
			canvas.draw_rect(rect, Color.WHITE)
			canvas.draw_rect(rect, Color.BLACK, false, 1.0)
			canvas.draw_line(Vector2(x + 16, y), Vector2(x + 16, y + 12), Color(0, 0, 0, 0.5), 1.0)
			# chaînes
			if cell(c - 1, r) != "=" or cell(c + 1, r) != "=":
				var cx := x + 6.0 if cell(c - 1, r) != "=" else x + 26.0
				for i in 6:
					canvas.draw_arc(Vector2(cx, y - 6 - i * 8), 3.0, 0.0, TAU, 8, Color(0.4, 0.4, 0.4), 1.5)
		_:
			# planches de bois
			canvas.draw_rect(rect, Color.WHITE)
			canvas.draw_rect(rect, Color.BLACK, false, 1.0)
			canvas.draw_line(Vector2(x, y + 6), Vector2(x + TILE, y + 6), Color(0, 0, 0, 0.4), 1.0)
			canvas.draw_circle(Vector2(x + 4, y + 3), 1.0, Color.BLACK)
			canvas.draw_circle(Vector2(x + 28, y + 9), 1.0, Color.BLACK)
			canvas.draw_line(Vector2(x + 8, y + 12), Vector2(x + 6, y + 18), Color(0.7, 0.7, 0.7), 1.0)


func draw_crate(c: int, r: int) -> void:
	var rect := Rect2(c * TILE + 1, r * TILE + 1, TILE - 2, TILE - 2)
	canvas.draw_rect(rect, Color.WHITE)
	canvas.draw_rect(rect, Color.BLACK, false, 2.0)
	var inner := rect.grow(-5)
	canvas.draw_rect(inner, Color.BLACK, false, 1.0)
	canvas.draw_line(inner.position, inner.end, Color.BLACK, 1.5)
	canvas.draw_line(Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), Color.BLACK, 1.5)


func draw_spikes(c: int, r: int, ceiling: bool) -> void:
	var x := float(c * TILE)
	var y := float(r * TILE)
	for k in 2:
		var x0 := x + k * 16.0
		var tri := PackedVector2Array()
		if ceiling:
			tri = PackedVector2Array([Vector2(x0, y), Vector2(x0 + 8, y + 16), Vector2(x0 + 16, y)])
		else:
			tri = PackedVector2Array([Vector2(x0, y + TILE), Vector2(x0 + 8, y + TILE - 16), Vector2(x0 + 16, y + TILE)])
		canvas.draw_colored_polygon(tri, Color.WHITE)
		canvas.draw_polyline(tri, Color.BLACK, 1.5)


# =====================================================================
#  DESSIN : ÉLÉMENTS ANIMÉS (redessinés à chaque image)
# =====================================================================

func draw_deco() -> void:
	var tt := time
	# halo autour du joueur
	if not player.dead:
		for k in 3:
			deco.draw_circle(player.global_position, 40.0 + k * 22.0, Color(1, 1, 1, 0.025))

	# points de passage
	for cp in checkpoints:
		var p: Vector2 = cp["pos"]
		deco.draw_line(p + Vector2(0, 16), p + Vector2(0, -10), Color(0.55, 0.55, 0.55), 3.0)
		var lamp := p + Vector2(0, -18)
		deco.draw_rect(Rect2(lamp - Vector2(6, 8), Vector2(12, 16)), Color.BLACK)
		deco.draw_rect(Rect2(lamp - Vector2(6, 8), Vector2(12, 16)), Color(0.7, 0.7, 0.7), false, 1.5)
		if cp["on"]:
			var f := 1.0 + 0.2 * sin(tt * 14.0 + p.x)
			for k in 3:
				deco.draw_circle(lamp, (12.0 + k * 9.0) * f, Color(1, 1, 1, 0.07))
			deco.draw_circle(lamp + Vector2(0, 2), 3.5 * f, Color.WHITE)
		else:
			deco.draw_circle(lamp + Vector2(0, 2), 2.0, Color(0.35, 0.35, 0.35))

	# porte de sortie
	if exit_alpha > 0.0:
		var a := exit_alpha
		var base := exit_pos + Vector2(0, 16)
		var pulse := 0.5 + 0.5 * sin(tt * 3.0)
		for k in 4:
			deco.draw_circle(base + Vector2(0, -28), 30.0 + k * 12.0 + pulse * 4.0, Color(1, 1, 1, 0.04 * a))
		var frame := PackedVector2Array([base + Vector2(-20, 0), base + Vector2(-20, -40), base + Vector2(-12, -54), base + Vector2(0, -58), base + Vector2(12, -54), base + Vector2(20, -40), base + Vector2(20, 0)])
		deco.draw_colored_polygon(frame, Color(1, 1, 1, a))
		var inner := PackedVector2Array([base + Vector2(-13, 0), base + Vector2(-13, -38), base + Vector2(-7, -48), base + Vector2(0, -51), base + Vector2(7, -48), base + Vector2(13, -38), base + Vector2(13, 0)])
		deco.draw_colored_polygon(inner, Color(0, 0, 0, a))
		deco.draw_circle(base + Vector2(0, -24), 6.0 + pulse * 3.0, Color(1, 1, 1, 0.5 * a))
		deco.draw_circle(base + Vector2(0, -24), 3.0, Color(1, 1, 1, a))
		if int(tt * 10.0) % 4 == 0:
			fx.spawn(base + Vector2(randf_range(-10, 10), -4), Vector2(0, -30), Color(1, 1, 1, 0.7 * a), 1.0, 2.0)


func draw_mover(body: AnimatableBody2D) -> void:
	var rect := Rect2(-48, -6, 96, 12)
	body.draw_rect(rect, Color.WHITE)
	body.draw_rect(rect, Color.BLACK, false, 1.5)
	for i in 3:
		body.draw_line(Vector2(-16 + i * 16 - 16, -6), Vector2(-16 + i * 16 - 16, 6), Color(0, 0, 0, 0.4), 1.0)
	# rune qui brille dessous
	var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
	body.draw_circle(Vector2(0, 12), 5.0, Color(1, 1, 1, 0.15 + 0.2 * glow))
	body.draw_colored_polygon(PackedVector2Array([Vector2(0, 8), Vector2(4, 12), Vector2(0, 16), Vector2(-4, 12)]), Color.WHITE)
