extends CharacterBody2D

const GameData = preload("res://game_data.gd")

signal melee(hit_rect: Rect2, damage: int)
signal fire(from_pos: Vector2, dir_x: float)

const GRAVITY := 1000.0
const MAX_FALL := 700.0
const GLIDE_FALL := 70.0
const COYOTE_TIME := 0.1
const STOMP_BOUNCE := -320.0
const DASH_SPEED := 460.0
const DASH_TIME := 0.18

var level = null            # main.gd (effets visuels), null dans les menus
var can_control := true
var dead := false
var speed := 170.0
var jump_velocity := -440.0
var facing := 1.0
var air_time := 0.0
var jumps_left := 0
var was_on_floor := true
var anim_time := 0.0
var gliding := false

var attack_time := 0.0
var attack_length := 0.28
var attack_hit_done := false
var attack_cd := 0.0
var fire_cd := 0.0
var fire_delay := 1.6
var cast_time := 0.0
var dash_time := 0.0
var dash_cd := 0.0
var hurt_time := 0.0
var ghost_timer := 0.0
var step_timer := 0.0

var sprite: Sprite2D
var weapon_layer: Node2D
var frames := {}

# ---------- Pixel art ----------
# "." transparent, "#" noir, "w" blanc, "g" gris clair, "d" gris foncé
# Tête (9 lignes) propre à chaque personnage, puis torse (4 lignes) et jambes (3 lignes).
const HEADS := {
	"ombre": [
		"................",
		"....########....",
		"...#wwwwwwww#...",
		"..#wwwwwwwwww#..",
		"..#wwww#ww#wg#..",
		"..#wwww#ww#wg#..",
		"..#wwwwwwwwwg#..",
		"...#wwwwwwgg#...",
		"....########....",
	],
	"lune": [
		"..........##....",
		".........#ww#...",
		"....#####wwg#...",
		"...#wwwwwwww#...",
		"..#wwww#ww#wg#..",
		"..#wwww#ww#wg#..",
		"..#wwwwwwwwwg#..",
		"...#wwwwwwgg#...",
		"....########....",
	],
	"roc": [
		".##..........##.",
		".#w#........#w#.",
		"..#w########w#..",
		"..#dddddddddd#..",
		"..#dddd#ww#ww#..",
		"..#dddd#ww#ww#..",
		"..#dddddddddd#..",
		"...#dddddddd#...",
		"....########....",
	],
	"chevalier": [
		"......###.......",
		".....#www#......",
		"....##w#########",
		"...#gggggggggg#.",
		"..#ggggggggggg#.",
		"..#gg##########.",
		"..#gg#wwww#ww#..",
		"..#ggggggggggg#.",
		"...###########..",
	],
	"ninja": [
		"................",
		"....########....",
		"...#dddddddd#...",
		"..#dddddddddd#..",
		"ww#wwwwwwwwww#..",
		".w#dddd#ww#ww#..",
		"..#dddddddddd#..",
		"...#dddddddd#...",
		"....########....",
	],
	"sorciere": [
		"..........##....",
		".........#dd#...",
		"........#ddd#...",
		".......#dddd#...",
		"......#dwwdd#...",
		"..############..",
		"...#wwww#ww#w#..",
		"...#wwwwwwwwg#..",
		"....#########...",
	],
	"spectre": [
		"................",
		"....########....",
		"...#wwwwwwww#...",
		"..#wwwwwwwwww#..",
		"..#www###w###...",
		"..#www###w###...",
		"..#wwwwwwwwww#..",
		"..#www#w##w#w#..",
		"..#wwwwwwwwww#..",
	],
}
const BODY_COLOR := {"ombre": "w", "lune": "g", "roc": "g", "chevalier": "g", "ninja": "d", "sorciere": "d", "spectre": "w"}

const TORSO := [
	"...#wwwwwwww#...",
	"..#ww#wwwwww#...",
	"..#ww#wwwwww#...",
	"...#wwwwwwww#...",
]
const TORSO_ATTACK := [
	"...#wwwwwwww#...",
	"...#wwwwwwww####",
	"...#wwwwwwwwwww#",
	"...#wwwwwwww####",
]
const TORSO_HURT := [
	".#.#wwwwwwww#.#.",
	".#w#wwwwwwww#w#.",
	"..##wwwwwwww##..",
	"...#wwwwwwww#...",
]
const LEGS_IDLE := [
	"....#ww##ww#....",
	"....#ww##ww#....",
	"....###..###....",
]
const LEGS_SPREAD := [
	"...#ww#..#ww#...",
	"..#ww#....#ww#..",
	"..###......###..",
]
const LEGS_PASS := [
	".....#wwww#.....",
	"....#ww##ww#....",
	"...###....###...",
]
const LEGS_JUMP := [
	"...#ww#..#ww#...",
	"...###....###...",
	"................",
]
const LEGS_FALL := [
	"....#ww##ww#....",
	"...#ww#..#ww#...",
	"...##......##...",
]
# Le spectre n'a pas de jambes : une traîne qui ondule
const TAIL_A := [
	"...#wwwwwwww#...",
	"....#ww#ww#w#...",
	".....#.#..#.#...",
]
const TAIL_B := [
	"...#wwwwwwww#...",
	"...#w#ww#ww#....",
	"...#.#..#.#.....",
]


static func recolor(rows: Array, color: String) -> Array:
	var out := []
	for r in rows:
		out.append(String(r).replace("w", color))
	return out


static func build_frames(char_id: String) -> Dictionary:
	var head: Array = HEADS.get(char_id, HEADS["ombre"])
	var body: String = BODY_COLOR.get(char_id, "w")
	var torso := recolor(TORSO, body)
	var attack_torso := recolor(TORSO_ATTACK, body)
	var hurt_torso := recolor(TORSO_HURT, body)
	var idle: Array = LEGS_IDLE
	var spread: Array = LEGS_SPREAD
	var pass_legs: Array = LEGS_PASS
	var jump: Array = LEGS_JUMP
	var fall: Array = LEGS_FALL
	if char_id == "spectre":
		idle = TAIL_A
		spread = TAIL_B
		pass_legs = TAIL_A
		jump = TAIL_B
		fall = TAIL_A
	var f := {}
	f["idle"] = GameData.make_texture(head + torso + idle)
	f["run0"] = GameData.make_texture(head + torso + spread)
	f["run1"] = f["idle"]
	f["run2"] = GameData.make_texture(head + torso + pass_legs)
	f["run3"] = f["idle"]
	f["jump"] = GameData.make_texture(head + torso + jump)
	f["fall"] = GameData.make_texture(head + torso + fall)
	f["attack"] = GameData.make_texture(head + attack_torso + spread)
	f["hurt"] = GameData.make_texture(head + hurt_torso + fall)
	return f


# ---------- Dessin des armes (aussi utilisé par le magasin) ----------

static func poly(c: CanvasItem, pts: PackedVector2Array, fill: Color) -> void:
	c.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, Color.BLACK, 1.5)


static func shaft(c: CanvasItem, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	c.draw_line(a, b, Color.BLACK, width + 2.0)
	c.draw_line(a, b, color, width)


# hand = position de la main, dir = direction de la lame (vecteur unitaire)
static func draw_weapon_shape(c: CanvasItem, hand: Vector2, dir: Vector2, id: String, t: float) -> void:
	var side := Vector2(-dir.y, dir.x)
	match id:
		"dague":
			shaft(c, hand - dir * 3.0, hand + dir * 3.0, 2.0, Color(0.35, 0.35, 0.35))
			shaft(c, hand + dir * 3.0 - side * 4.0, hand + dir * 3.0 + side * 4.0, 1.5, Color.WHITE)
			poly(c, PackedVector2Array([hand + dir * 4.0 + side * 2.5, hand + dir * 15.0, hand + dir * 4.0 - side * 2.5]), Color.WHITE)
		"hache":
			shaft(c, hand - dir * 5.0, hand + dir * 24.0, 2.5, Color(0.45, 0.45, 0.45))
			var p := hand + dir * 20.0
			poly(c, PackedVector2Array([p - dir * 3.0, p + side * 10.0 - dir * 8.0, p + side * 13.0 + dir * 2.0, p + side * 9.0 + dir * 9.0, p + dir * 4.0]), Color.WHITE)
			poly(c, PackedVector2Array([p - dir * 1.0, p - side * 6.0 - dir * 3.0, p - side * 6.0 + dir * 3.0, p + dir * 2.0]), Color(0.7, 0.7, 0.7))
		"lance":
			shaft(c, hand - dir * 14.0, hand + dir * 30.0, 2.0, Color(0.5, 0.5, 0.5))
			var tip := hand + dir * 30.0
			poly(c, PackedVector2Array([tip - side * 4.0, tip + dir * 12.0, tip + side * 4.0, tip - dir * 2.0]), Color.WHITE)
			c.draw_line(tip - dir * 2.0, tip - dir * 6.0 + side * 3.0, Color.WHITE, 1.5)
		"marteau":
			shaft(c, hand - dir * 5.0, hand + dir * 22.0, 2.5, Color(0.45, 0.45, 0.45))
			var h := hand + dir * 24.0
			poly(c, PackedVector2Array([h - side * 10.0 - dir * 6.0, h + side * 10.0 - dir * 6.0, h + side * 10.0 + dir * 6.0, h - side * 10.0 + dir * 6.0]), Color.WHITE)
			c.draw_line(h - side * 5.0 - dir * 6.0, h - side * 5.0 + dir * 6.0, Color.BLACK, 1.0)
			c.draw_line(h + side * 5.0 - dir * 6.0, h + side * 5.0 + dir * 6.0, Color.BLACK, 1.0)
		"faux":
			shaft(c, hand - dir * 12.0, hand + dir * 28.0, 2.0, Color(0.4, 0.4, 0.4))
			var top := hand + dir * 28.0
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			for i in 7:
				var k := i / 6.0
				outer.append(top + side * (k * 26.0) - dir * (k * k * 14.0) + dir * 3.0)
				inner.append(top + side * (k * 24.0) - dir * (k * k * 14.0) - dir * (3.0 * (1.0 - k)))
			inner.reverse()
			var blade := outer.duplicate()
			blade.append_array(inner)
			poly(c, blade, Color.WHITE)
		"lame":
			var glow := 0.5 + 0.5 * sin(t * 6.0)
			for i in 4:
				c.draw_circle(hand + dir * (8.0 + i * 6.0), 7.0 + glow * 2.0, Color(1, 1, 1, 0.07))
			shaft(c, hand - dir * 4.0, hand + dir * 3.0, 2.5, Color(0.25, 0.25, 0.25))
			shaft(c, hand + dir * 3.0 - side * 6.0, hand + dir * 3.0 + side * 6.0, 1.5, Color.WHITE)
			var blade := PackedVector2Array()
			for i in 6:
				var k := i / 5.0
				blade.append(hand + dir * (4.0 + k * 26.0) + side * (3.0 - k * 3.0 + sin(k * PI) * 3.0))
			for i in range(5, -1, -1):
				var k := i / 5.0
				blade.append(hand + dir * (4.0 + k * 26.0) - side * (3.0 - k * 3.0))
			poly(c, blade, Color.WHITE)
			c.draw_circle(hand + dir * 18.0, 1.5 + glow, Color(0.2, 0.2, 0.2))
		_:
			# épée
			shaft(c, hand - dir * 4.0, hand + dir * 3.0, 2.5, Color(0.3, 0.3, 0.3))
			c.draw_circle(hand - dir * 5.0, 2.0, Color.WHITE)
			shaft(c, hand + dir * 3.0 - side * 6.0, hand + dir * 3.0 + side * 6.0, 2.0, Color.WHITE)
			var base := hand + dir * 4.0
			var tip := hand + dir * 26.0
			poly(c, PackedVector2Array([base + side * 3.0, tip - dir * 5.0 + side * 3.0, tip, tip - dir * 5.0 - side * 3.0, base - side * 3.0]), Color.WHITE)
			c.draw_line(base + dir * 2.0, tip - dir * 6.0, Color(0.6, 0.6, 0.6), 1.0)


# ---------- Mise en place ----------

func _ready() -> void:
	GameData.setup_inputs()
	sprite = $Sprite2D  # pas de @onready : main.gd peut rappeler _ready() si le script s'est détaché
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2, 2)
	if weapon_layer == null:
		weapon_layer = Node2D.new()
		add_child(weapon_layer)
		weapon_layer.draw.connect(draw_weapon)
	add_to_group("player")
	apply_stats()


func apply_stats() -> void:
	frames = build_frames(GameData.character)
	speed = GameData.move_speed()
	jump_velocity = GameData.jump_velocity()
	fire_delay = GameData.fire_delay()
	attack_length = GameData.attack_length()
	sprite.texture = frames["idle"]
	sprite.modulate.a = 0.85 if GameData.character == "spectre" else 1.0


func get_hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(10, 15), Vector2(20, 31))


func is_invulnerable() -> bool:
	return dash_time > 0.0 or dead


func _unhandled_input(event: InputEvent) -> void:
	# clavier : mémorise les appuis comme les boutons tactiles
	for action in ["ui_accept", "attaque", "feu", "dash"]:
		if event.is_action_pressed(action):
			GameData.tap(action)


# ---------- Boucle physique ----------

func _physics_process(delta: float) -> void:
	GameData.update_taps(delta)
	queue_redraw()

	if dead:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		position += velocity * delta
		sprite.rotation += 8.0 * delta
		weapon_layer.queue_redraw()
		return

	var on_floor := is_on_floor()
	if on_floor:
		air_time = 0.0
		jumps_left = 1 if GameData.has_double_jump() else 0
		if not was_on_floor:
			landed()
	else:
		air_time += delta
	was_on_floor = on_floor

	attack_cd = maxf(0.0, attack_cd - delta)
	fire_cd = maxf(0.0, fire_cd - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	cast_time = maxf(0.0, cast_time - delta)

	if attack_time > 0.0:
		attack_time -= delta
		var progress := 1.0 - attack_time / attack_length
		var hit_at := 0.55 if GameData.weapon == "marteau" else 0.3
		if not attack_hit_done and progress >= hit_at:
			attack_hit_done = true
			melee.emit(get_attack_rect(), GameData.melee_damage())
			weapon_special()

	# Ruée : vitesse fixe, pas de gravité
	if dash_time > 0.0:
		dash_time -= delta
		velocity = Vector2(facing * DASH_SPEED, 0)
		ghost_timer -= delta
		if ghost_timer <= 0.0:
			ghost_timer = 0.03
			spawn_ghost()
		move_and_slide()
		update_animation(delta)
		return

	gliding = false
	if not on_floor:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		# le spectre plane en gardant le saut appuyé
		if GameData.char_has("plane") and velocity.y > GLIDE_FALL and Input.is_action_pressed("ui_accept"):
			velocity.y = GLIDE_FALL
			gliding = true

	var direction := 0.0
	if can_control and hurt_time <= 0.0:
		direction = Input.get_axis("ui_left", "ui_right")
		handle_jump()
		handle_attack()
		handle_fire()
		handle_dash()

	if hurt_time > 0.0:
		hurt_time -= delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	elif direction != 0.0:
		velocity.x = direction * speed
		facing = signf(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 12.0 * delta)

	move_and_slide()
	update_animation(delta)


func handle_jump() -> void:
	# Saut au sol : is_action_pressed (jamais raté au tactile)
	var wants := Input.is_action_pressed("ui_accept") or GameData.has_tap("ui_accept")
	if wants and air_time < COYOTE_TIME and velocity.y >= 0.0:
		do_jump()
	elif GameData.has_tap("ui_accept") and air_time >= COYOTE_TIME and jumps_left > 0:
		# double saut : il faut un nouvel appui
		jumps_left -= 1
		do_jump()
		if level:
			level.fx.ring(global_position + Vector2(0, 14), 12.0, Color.WHITE, 0.3)
			level.fx.burst(global_position + Vector2(0, 14), 8, 70.0, Color.WHITE, 0.3, 2.0)


func do_jump() -> void:
	velocity.y = jump_velocity
	air_time = COYOTE_TIME
	GameData.clear_tap("ui_accept")
	sprite.scale = Vector2(1.5, 2.5)
	dust(5)


func handle_attack() -> void:
	if attack_cd > 0.0:
		return
	if Input.is_action_pressed("attaque") or GameData.has_tap("attaque"):
		GameData.clear_tap("attaque")
		attack_time = attack_length
		attack_cd = attack_length + 0.06
		attack_hit_done = false


func handle_fire() -> void:
	if fire_cd > 0.0:
		return
	if Input.is_action_pressed("feu") or GameData.has_tap("feu"):
		GameData.clear_tap("feu")
		fire_cd = fire_delay
		cast_time = 0.25
		sprite.scale = Vector2(2.4, 1.8)
		fire.emit(global_position + Vector2(facing * 16.0, -2.0), facing)


func handle_dash() -> void:
	if not GameData.has_dash() or dash_cd > 0.0:
		return
	if Input.is_action_pressed("dash") or GameData.has_tap("dash"):
		GameData.clear_tap("dash")
		dash_time = DASH_TIME
		dash_cd = 0.45 if GameData.character == "ninja" else 0.7
		attack_time = 0.0
		if level:
			level.fx.burst(global_position, 10, 90.0, Color.WHITE, 0.35, 2.0)


func get_attack_rect() -> Rect2:
	var zone: Vector2 = GameData.weapon_stat("zone")
	if GameData.weapon_stat("style") == "tour":
		return Rect2(global_position - zone * 0.5, zone)
	var x0 := global_position.x + 6.0 if facing > 0.0 else global_position.x - 6.0 - zone.x
	return Rect2(x0, global_position.y - zone.y * 0.5, zone.x, zone.y)


# Effets en plus selon l'arme
func weapon_special() -> void:
	if level == null:
		return
	match GameData.weapon:
		"marteau":
			level.shake(5.0)
			if is_on_floor():
				level.spawn_projectile(global_position + Vector2(facing * 28.0, 6.0), Vector2(facing * 260.0, 0), "joueur", "onde", 2)
				level.fx.burst(global_position + Vector2(facing * 28.0, 15.0), 12, 120.0, Color(0.85, 0.85, 0.85), 0.5, 3.0, 300.0, 60.0)
		"lame":
			level.spawn_projectile(global_position + Vector2(facing * 18.0, -2.0), Vector2(facing * 340.0, 0), "joueur", "croissant", 1)
		"faux":
			level.fx.ring(global_position, 30.0, Color.WHITE, 0.3)


func landed() -> void:
	sprite.scale = Vector2(2.6, 1.5)
	dust(7)


func dust(count: int) -> void:
	if level:
		level.fx.burst(global_position + Vector2(0, 15), count, 50.0, Color(0.85, 0.85, 0.85), 0.4, 2.5, 0.0, 20.0)


func spawn_ghost() -> void:
	var g := Sprite2D.new()
	g.texture = sprite.texture
	g.flip_h = sprite.flip_h
	g.scale = sprite.scale
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.global_position = sprite.global_position
	g.modulate = Color(1, 1, 1, 0.5)
	get_parent().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)
	tw.tween_callback(g.queue_free)


# ---------- Appelé par main.gd ----------

func bounce() -> void:
	if Input.is_action_pressed("ui_accept"):
		velocity.y = jump_velocity  # rebond plus haut si on garde le saut appuyé
	else:
		velocity.y = STOMP_BOUNCE
	air_time = COYOTE_TIME
	sprite.scale = Vector2(1.5, 2.5)


func take_hit(from_x: float) -> void:
	var dir := 1.0 if global_position.x >= from_x else -1.0
	velocity = Vector2(dir * 220.0, -260.0)
	hurt_time = 0.3
	attack_time = 0.0
	dash_time = 0.0


func die() -> void:
	dead = true
	can_control = false
	attack_time = 0.0
	velocity = Vector2(0, -380)
	sprite.texture = frames["hurt"]


# ---------- Animation ----------

func update_animation(delta: float) -> void:
	sprite.flip_h = facing < 0.0
	sprite.scale = sprite.scale.lerp(Vector2(2, 2), minf(1.0, 12.0 * delta))
	sprite.position.y = 0.0
	sprite.rotation = 0.0
	anim_time += delta
	var tex: Texture2D = frames["idle"]

	if hurt_time > 0.0:
		tex = frames["hurt"]
		sprite.rotation = -0.2 * facing
	elif attack_time > 0.0 or cast_time > 0.0:
		tex = frames["attack"]
	elif dash_time > 0.0:
		tex = frames["run0"]
		sprite.rotation = 0.15 * facing
	elif not is_on_floor():
		tex = frames["jump"] if velocity.y < 0.0 else frames["fall"]
		if gliding:
			sprite.rotation = sin(anim_time * 8.0) * 0.08
	elif absf(velocity.x) > 10.0:
		var i := int(anim_time * 12.0) % 4
		tex = frames["run%d" % i]
		if i % 2 == 1:
			sprite.position.y = -1.0  # petit rebond du corps
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = 0.25
			dust(2)
	else:
		# respiration
		if int(anim_time * 2.0) % 2 == 1:
			sprite.position.y = 1.0
	if GameData.character == "spectre":
		sprite.position.y += sin(anim_time * 3.0) * 1.5

	sprite.texture = tex
	weapon_layer.queue_redraw()


func _draw() -> void:
	# ombre au sol
	if is_on_floor() and not dead:
		draw_set_transform(Vector2(0, 16), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.45))
		draw_set_transform(Vector2.ZERO)


func draw_weapon() -> void:
	if dead:
		return
	var weapon_id := GameData.weapon
	var style: String = GameData.weapon_stat("style")

	if attack_time <= 0.0:
		# arme tenue en main, derrière le corps
		weapon_layer.z_index = -1
		var bob := sprite.position.y
		var rest := deg_to_rad(-80.0 if style != "arc" else -65.0)
		var rest_dir := Vector2(cos(rest) * facing, sin(rest))
		draw_weapon_shape(weapon_layer, Vector2(-facing * 4.0, 6.0 + bob), rest_dir, weapon_id, anim_time)
		return

	weapon_layer.z_index = 1
	var p := clampf(1.0 - attack_time / attack_length, 0.0, 1.0)
	var hand := Vector2(facing * 7.0, 3.0)

	if style == "pique":
		var reach := 2.0 + 30.0 * sin(p * PI)
		draw_weapon_shape(weapon_layer, hand + Vector2(facing * (reach - 8.0), 0), Vector2(facing, 0), weapon_id, anim_time)
		for k in 3:
			var yy := -6.0 + k * 6.0
			var tip := hand + Vector2(facing * (reach + 36.0), 0)
			weapon_layer.draw_line(tip + Vector2(-facing * (24.0 + k * 6.0), yy), tip + Vector2(-facing * 8.0, yy), Color(1, 1, 1, 0.35 * sin(p * PI)), 1.0)
		return

	var a0 := deg_to_rad(-115.0)
	var a1 := deg_to_rad(65.0)
	if style == "tour":
		a0 = deg_to_rad(-90.0)
		a1 = deg_to_rad(270.0)
		hand = Vector2(0, 0)
	var s := p * p * (3.0 - 2.0 * p)
	var a := lerpf(a0, a1, s)
	var reach_len := 30.0 if weapon_id == "lance" or weapon_id == "faux" else 26.0
	# traînée blanche
	var trail := PackedVector2Array()
	for k in 13:
		var ta := lerpf(maxf(a0, a - 2.0), a, k / 12.0)
		trail.append(hand + Vector2(cos(ta) * facing, sin(ta)) * (reach_len + 4.0))
	weapon_layer.draw_polyline(trail, Color(1, 1, 1, 0.3), 9.0, true)
	weapon_layer.draw_polyline(trail, Color(1, 1, 1, 0.85), 2.0, true)
	draw_weapon_shape(weapon_layer, hand, Vector2(cos(a) * facing, sin(a)), weapon_id, anim_time)
