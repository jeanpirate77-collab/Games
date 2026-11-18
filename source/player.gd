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
var run_phase := 0.0
var gliding := false
var squash := Vector2.ONE
var body_rot := 0.0
var hurt_flash := 0.0

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
var muzzle_flash := 0.0
var in_water := false
var swim_cd := 0.0
var trail: Array = []       # points de l'écharpe / cape (coordonnées du monde)

var sprite: Sprite2D
var body_layer: Node2D
var weapon_layer: Node2D

# =====================================================================
#  APPARENCE DES PERSONNAGES (dessinés en formes, pas en pixels)
# =====================================================================
#   tete / corps / jambes : couleurs     yeux : couleur des yeux
#   chapeau : forme de la tête            traine : écharpe, cape, bandeau ou plume qui flotte
const LOOKS := {
	"ombre": {"tete": Color(1, 1, 1), "corps": Color(0.93, 0.93, 0.93), "jambes": Color(0.22, 0.22, 0.22), "yeux": Color(0, 0, 0), "chapeau": "capuche", "traine": "echarpe", "traine_col": Color(0.1, 0.1, 0.1)},
	"lune": {"tete": Color(1, 1, 1), "corps": Color(0.62, 0.62, 0.62), "jambes": Color(0.28, 0.28, 0.28), "yeux": Color(0, 0, 0), "chapeau": "oreilles", "traine": "echarpe", "traine_col": Color(1, 1, 1)},
	"roc": {"tete": Color(0.3, 0.3, 0.3), "corps": Color(0.6, 0.6, 0.6), "jambes": Color(0.25, 0.25, 0.25), "yeux": Color(1, 1, 1), "chapeau": "cornes", "traine": "", "traine_col": Color(1, 1, 1)},
	"chevalier": {"tete": Color(0.8, 0.8, 0.8), "corps": Color(0.72, 0.72, 0.72), "jambes": Color(0.35, 0.35, 0.35), "yeux": Color(1, 1, 1), "chapeau": "heaume", "traine": "plume", "traine_col": Color(1, 1, 1)},
	"ninja": {"tete": Color(0.2, 0.2, 0.2), "corps": Color(0.22, 0.22, 0.22), "jambes": Color(0.14, 0.14, 0.14), "yeux": Color(1, 1, 1), "chapeau": "bandeau", "traine": "bandeau", "traine_col": Color(1, 1, 1)},
	"sorciere": {"tete": Color(1, 1, 1), "corps": Color(0.25, 0.25, 0.25), "jambes": Color(0.18, 0.18, 0.18), "yeux": Color(0, 0, 0), "chapeau": "sorciere", "traine": "cape", "traine_col": Color(0.16, 0.16, 0.16)},
	"spectre": {"tete": Color(1, 1, 1), "corps": Color(1, 1, 1), "jambes": Color(1, 1, 1), "yeux": Color(0, 0, 0), "chapeau": "spectre", "traine": "", "traine_col": Color(1, 1, 1)},
}

# point d'accroche (pour facing = 1), nombre de points, longueur d'un segment, épaisseur, monte (plume) ou tombe
const TRAILS := {
	"echarpe": {"accroche": Vector2(-2, -1), "n": 7, "seg": 3.6, "largeur": 3.5, "monte": false},
	"bandeau": {"accroche": Vector2(-7, -11), "n": 5, "seg": 3.2, "largeur": 2.2, "monte": false},
	"cape": {"accroche": Vector2(-3, -1), "n": 6, "seg": 3.4, "largeur": 7.0, "monte": false},
	"plume": {"accroche": Vector2(-2, -19), "n": 4, "seg": 3.2, "largeur": 3.5, "monte": true},
}


static func look_of(char_id: String) -> Dictionary:
	return LOOKS.get(char_id, LOOKS["ombre"])


static func ellipse(center: Vector2, rx: float, ry: float, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func limb(c: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	c.draw_line(a, b, col, w)
	c.draw_circle(a, w * 0.5, col)
	c.draw_circle(b, w * 0.5, col)


# Traîne simulée (pour le menu : on l'invente à partir du temps)
static func fake_trail(char_id: String, f: float, t: float) -> PackedVector2Array:
	var look := look_of(char_id)
	var pts := PackedVector2Array()
	if look["traine"] == "":
		return pts
	var info: Dictionary = TRAILS[look["traine"]]
	var anchor: Vector2 = info["accroche"]
	anchor.x *= f
	var up := -1.0 if info["monte"] else 1.0
	for i in int(info["n"]):
		pts.append(anchor + Vector2(-f * float(info["seg"]) * i * 0.9, up * i * 1.2 + sin(t * 5.0 + i * 0.9) * i * 0.4))
	return pts


static func draw_trail(c: CanvasItem, pts: PackedVector2Array, kind: String, col: Color, o: float) -> void:
	if pts.size() < 2 or kind == "":
		return
	var info: Dictionary = TRAILS[kind]
	var w: float = info["largeur"]
	if kind == "cape":
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for i in pts.size():
			var k := float(i) / (pts.size() - 1)
			var d := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var n := Vector2(-d.y, d.x)
			var half := lerpf(w * 0.5, w, k) + o
			left.append(pts[i] + n * half)
			right.append(pts[i] - n * half)
		right.reverse()
		left.append_array(right)
		c.draw_colored_polygon(left, col)
		return
	c.draw_polyline(pts, col, w + o * 2.0, true)
	c.draw_circle(pts[pts.size() - 1], (w + o * 2.0) * 0.5, col)
	if kind == "bandeau":
		# deux rubans
		var second := PackedVector2Array()
		for p in pts:
			second.append(p + Vector2(0, 2.5))
		c.draw_polyline(second, col, w * 0.8 + o * 2.0, true)


# st : "t" temps, "pose" (idle, run, jump, fall, attack, hurt, dash, glide), "run" phase de course,
#      "facing", "squash", "rot", "alpha", "flash", "trail" (points locaux), "hand_f", "hand_b"
static func draw_character(c: CanvasItem, char_id: String, st: Dictionary, xf := Transform2D.IDENTITY) -> void:
	var look := look_of(char_id)
	var f: float = st.get("facing", 1.0)
	var t: float = st.get("t", 0.0)
	var pose: String = st.get("pose", "idle")
	var phase: float = st.get("run", 0.0)
	var sq: Vector2 = st.get("squash", Vector2.ONE)
	var rot: float = st.get("rot", 0.0)
	var alpha: float = st.get("alpha", 1.0)
	var flash: bool = st.get("flash", false)
	var trail_pts: PackedVector2Array = st.get("trail", PackedVector2Array())
	if trail_pts.is_empty():
		trail_pts = fake_trail(char_id, f, t)
	var ghost := char_id == "spectre"

	# le corps s'écrase / s'étire autour des pieds
	var m := xf * Transform2D(rot, sq, 0.0, Vector2(0, 16)) * Transform2D(0.0, Vector2(0, -16))
	c.draw_set_transform_matrix(m)

	var bob := sin(t * 3.0) * 0.7
	if pose == "run":
		bob = -absf(sin(phase)) * 1.8
	if ghost:
		bob = sin(t * 3.0) * 1.5 - 2.0
	var head_c := Vector2(f * 0.5, -8.0 + bob)
	var body_c := Vector2(0, 4.0 + bob * 0.6)
	var hip_f := Vector2(f * 2.2, 8.5 + bob * 0.4)
	var hip_b := Vector2(-f * 2.2, 8.5 + bob * 0.4)
	var foot_f := hip_f + Vector2(0, 7.5)
	var foot_b := hip_b + Vector2(0, 7.5)
	match pose:
		"run":
			var a := sin(phase) * 0.8
			foot_f = hip_f + Vector2(sin(a) * f * 8.0, cos(a) * 7.5 - maxf(0.0, cos(phase)) * 2.0)
			foot_b = hip_b + Vector2(-sin(a) * f * 8.0, cos(a) * 7.5 - maxf(0.0, -cos(phase)) * 2.0)
		"jump", "dash":
			foot_f = hip_f + Vector2(f * 3.5, 4.5)
			foot_b = hip_b + Vector2(-f * 1.5, 6.0)
		"fall", "glide", "hurt":
			foot_f = hip_f + Vector2(f * 3.0, 7.0)
			foot_b = hip_b + Vector2(-f * 3.5, 6.5)
		"attack":
			foot_f = hip_f + Vector2(f * 4.0, 7.0)
			foot_b = hip_b + Vector2(-f * 4.0, 7.0)
	var shoulder_f := body_c + Vector2(f * 3.5, -3.0)
	var shoulder_b := body_c + Vector2(-f * 3.5, -3.0)
	var swing := sin(phase) * 4.0 if pose == "run" else 0.0
	var hand_f: Vector2 = st.get("hand_f", shoulder_f + Vector2(-swing * f + f * 1.5, 6.0))
	var hand_b: Vector2 = st.get("hand_b", shoulder_b + Vector2(swing * f - f * 1.0, 6.0))
	if pose == "hurt":
		hand_f = shoulder_f + Vector2(f * 3.0, -6.0)
		hand_b = shoulder_b + Vector2(-f * 3.0, -6.0)
	elif pose == "jump":
		hand_f = shoulder_f + Vector2(f * 3.0, -5.0)

	var hat: String = look["chapeau"]
	var k_col := Color(0, 0, 0, alpha)
	# deux passes : d'abord tout en noir un peu plus gros (contour), puis les couleurs
	for pass_i in 2:
		var o := 1.6 if pass_i == 0 else 0.0
		var head_col: Color = k_col if pass_i == 0 else tint(look["tete"], alpha, flash)
		var body_col: Color = k_col if pass_i == 0 else tint(look["corps"], alpha, flash)
		var leg_col: Color = k_col if pass_i == 0 else tint(look["jambes"], alpha, flash)
		var trail_col: Color = tint(look["traine_col"], alpha, flash)
		if pass_i == 0:
			# contour clair si l'écharpe est sombre (sinon invisible dans le noir)
			trail_col = Color(0.85, 0.85, 0.85, alpha) if trail_col.v < 0.3 else k_col
		var back_col: Color = k_col if pass_i == 0 else tint(look["corps"].darkened(0.3), alpha, flash)

		draw_trail(c, trail_pts, look["traine"], trail_col, o)
		limb(c, shoulder_b, hand_b, 3.4 + o * 2.0, back_col)
		if ghost:
			# corps de fantôme qui ondule
			var blob := PackedVector2Array()
			for i in 9:
				var a := PI + PI * i / 8.0
				blob.append(body_c + Vector2(cos(a) * (7.5 + o), sin(a) * (7.0 + o) - 2.0))
			for i in 7:
				var x := 7.5 + o - i * (15.0 + o * 2.0) / 6.0
				var y := 13.0 + o + (3.0 if i % 2 == 0 else -1.0) + sin(t * 6.0 + i) * 1.5
				blob.append(body_c + Vector2(x, y))
			c.draw_colored_polygon(blob, body_col)
		else:
			limb(c, hip_b, foot_b, 4.2 + o * 2.0, leg_col)
			c.draw_circle(foot_b + Vector2(f * 1.0, 0.5), 2.8 + o, leg_col)
			c.draw_colored_polygon(ellipse(body_c, 6.8 + o, 6.6 + o), body_col)
			limb(c, hip_f, foot_f, 4.2 + o * 2.0, leg_col)
			c.draw_circle(foot_f + Vector2(f * 1.0, 0.5), 2.8 + o, leg_col)
		# formes autour de la tête (derrière)
		match hat:
			"capuche":
				c.draw_colored_polygon(PackedVector2Array([head_c + Vector2(-f * 4.0, -6.0 - o), head_c + Vector2(-f * (13.0 + o), -9.0 - o), head_c + Vector2(-f * 7.0, 1.0 + o)]), head_col)
			"oreilles":
				for s in [-1.0, 1.0]:
					c.draw_colored_polygon(PackedVector2Array([head_c + Vector2(s * 5.0, -5.0), head_c + Vector2(s * (13.0 + o), -12.0 - o), head_c + Vector2(s * 7.5, 0.0)]), head_col)
			"cornes":
				for s in [-1.0, 1.0]:
					var horn_col: Color = k_col if pass_i == 0 else tint(Color(0.95, 0.95, 0.95), alpha, flash)
					c.draw_colored_polygon(PackedVector2Array([head_c + Vector2(s * 5.0, -6.0), head_c + Vector2(s * (12.0 + o), -17.0 - o), head_c + Vector2(s * 9.0, -3.0)]), horn_col)
		c.draw_circle(head_c, 8.6 + o, head_col)
		# formes autour de la tête (devant)
		match hat:
			"heaume":
				c.draw_colored_polygon(PackedVector2Array([head_c + Vector2(-2.0 - o, -8.0), head_c + Vector2(0, -11.5 - o), head_c + Vector2(2.0 + o, -8.0)]), head_col)
			"sorciere":
				var hat_col: Color = k_col if pass_i == 0 else tint(Color(0.2, 0.2, 0.2), alpha, flash)
				c.draw_colored_polygon(ellipse(head_c + Vector2(0, -5.5), 13.0 + o, 2.8 + o), hat_col)
				var tip := head_c + Vector2(-f * (8.0 + sin(t * 2.0) * 1.5), -26.0 - o)
				var m1 := head_c + Vector2(f * (2.0 + o), -16.0)
				var m2 := head_c + Vector2(-f * (4.0 + o), -15.0)
				var right_mid := m1 if f > 0.0 else m2
				var left_mid := m2 if f > 0.0 else m1
				c.draw_colored_polygon(PackedVector2Array([head_c + Vector2(-6.5 - o, -6.5), head_c + Vector2(6.5 + o, -6.5), right_mid, tip, left_mid]), hat_col)
		# bras de devant
		limb(c, shoulder_f, hand_f, 3.4 + o * 2.0, body_col)

	# ---------- détails ----------
	# volume : ombre sur le côté arrière, reflet sur la tête
	c.draw_circle(head_c + Vector2(-f * 3.0, -4.5), 1.6, Color(1, 1, 1, 0.55 * alpha))
	# liseré de lumière (rend lisibles les personnages sombres)
	var r0 := -PI * 0.5 - (0.6 if f > 0.0 else 0.9)
	var r1 := -PI * 0.5 + (0.9 if f > 0.0 else 0.6)
	c.draw_arc(head_c, 7.9, r0, r1, 10, Color(1, 1, 1, 0.45 * alpha), 1.4)
	if not ghost:
		# ceinture
		c.draw_line(body_c + Vector2(-6.0, 3.0), body_c + Vector2(6.0, 3.0), Color(0, 0, 0, 0.5 * alpha), 1.5)

	match hat:
		"heaume":
			c.draw_rect(Rect2(head_c + Vector2(-7.5 if f > 0.0 else -3.5, -3.0), Vector2(11.0, 4.0)), Color(0, 0, 0, alpha))
		"bandeau":
			c.draw_line(head_c + Vector2(-8.5, -4.5), head_c + Vector2(8.5, -4.5), Color(0, 0, 0, alpha), 4.5)
			c.draw_line(head_c + Vector2(-8.3, -4.5), head_c + Vector2(8.3, -4.5), tint(Color.WHITE, alpha, flash), 2.5)
		"sorciere":
			c.draw_line(head_c + Vector2(-6.0, -8.0), head_c + Vector2(6.0, -8.0), Color(0.85, 0.85, 0.85, alpha), 1.5)
		"oreilles":
			# croissant de lune sur le front
			c.draw_arc(head_c + Vector2(f * 1.0, -5.0), 2.0, -PI * 0.5, PI * 0.5, 6, Color(0, 0, 0, 0.7 * alpha), 1.2)

	# yeux
	var eye_col: Color = look["yeux"]
	eye_col.a = alpha
	var eye_y := head_c.y - 0.5
	var blink := fmod(t + 0.7, 3.4) < 0.12
	var ex1 := head_c.x + f * 1.2
	var ex2 := head_c.x + f * 4.8
	if pose == "hurt":
		for ex in [ex1, ex2]:
			c.draw_line(Vector2(ex - 1.5, eye_y - 1.5), Vector2(ex + 1.5, eye_y + 1.5), eye_col, 1.2)
			c.draw_line(Vector2(ex - 1.5, eye_y + 1.5), Vector2(ex + 1.5, eye_y - 1.5), eye_col, 1.2)
	elif blink:
		c.draw_line(Vector2(ex1 - 1.5, eye_y), Vector2(ex2 + 1.5, eye_y), eye_col, 1.2)
	elif ghost:
		for ex in [ex1, ex2]:
			c.draw_colored_polygon(ellipse(Vector2(ex, eye_y), 1.9, 3.0, 10), eye_col)
			c.draw_circle(Vector2(ex, eye_y + 0.8), 0.8, Color(1, 1, 1, alpha))
	else:
		var tall := 3.0 if pose != "attack" else 1.8
		for ex in [ex1, ex2]:
			c.draw_colored_polygon(ellipse(Vector2(ex, eye_y), 1.6, tall, 10), eye_col)
			c.draw_circle(Vector2(ex + f * 0.5, eye_y - 1.2), 0.7, Color(1, 1, 1, alpha) if eye_col.v < 0.5 else Color(0, 0, 0, alpha))
		if pose == "attack" or pose == "dash":
			# sourcils froncés
			c.draw_line(Vector2(ex1 - 1.5, eye_y - 3.8), Vector2(ex2 + 1.0, eye_y - 2.6), eye_col, 1.0)
	# petite bouche (sauf pour les visages masqués)
	if hat != "heaume" and hat != "bandeau" and hat != "cornes" and not blink:
		var mouth := Vector2(head_c.x + f * 3.2, head_c.y + 3.6)
		if pose == "hurt" or pose == "attack" or ghost:
			c.draw_circle(mouth, 1.2, eye_col)
		else:
			c.draw_arc(mouth, 1.6, 0.15 * PI, 0.85 * PI, 6, eye_col, 1.0)
	c.draw_set_transform(Vector2.ZERO)


static func tint(col: Color, alpha: float, flash: bool) -> Color:
	var out := Color(1, 1, 1, alpha) if flash else col
	out.a = alpha
	return out


# =====================================================================
#  DESSIN DES ARMES (aussi utilisé par le magasin et le bouton d'attaque)
# =====================================================================

static func poly(c: CanvasItem, pts: PackedVector2Array, fill: Color) -> void:
	c.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, Color.BLACK, 1.5)


static func shaft(c: CanvasItem, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	c.draw_line(a, b, Color.BLACK, width + 2.0)
	c.draw_line(a, b, color, width)


static func is_gun(id: String) -> bool:
	return id == "pistolet" or id == "fusil" or id == "arbalete"


# hand = position de la main, dir = direction de l'arme (vecteur unitaire)
static func draw_weapon_shape(c: CanvasItem, hand: Vector2, dir: Vector2, id: String, t: float) -> void:
	var side := Vector2(-dir.y, dir.x)
	# pour les armes à feu, la crosse est toujours vers le bas
	var down := side * (1.0 if dir.x >= 0.0 else -1.0)
	match id:
		"pistolet":
			poly(c, PackedVector2Array([hand - dir * 2.0 - down * 1.0, hand - dir * 2.0 + down * 7.0, hand - dir * 6.0 + down * 7.0, hand - dir * 5.0 - down * 1.0]), Color(0.3, 0.3, 0.3))
			poly(c, PackedVector2Array([hand - dir * 6.0 - down * 4.0, hand + dir * 13.0 - down * 4.0, hand + dir * 13.0 + down * 1.0, hand - dir * 6.0 + down * 1.0]), Color(0.85, 0.85, 0.85))
			c.draw_line(hand - dir * 4.0 - down * 2.5, hand + dir * 11.0 - down * 2.5, Color(0.4, 0.4, 0.4), 1.0)
			c.draw_circle(hand + dir * 1.0 + down * 2.5, 1.5, Color(0.2, 0.2, 0.2))
		"fusil":
			poly(c, PackedVector2Array([hand - dir * 3.0, hand - dir * 14.0 + down * 5.0, hand - dir * 15.0 + down * 1.0, hand - dir * 3.0 - down * 2.0]), Color(0.35, 0.35, 0.35))
			poly(c, PackedVector2Array([hand - dir * 3.0 - down * 3.5, hand + dir * 22.0 - down * 3.5, hand + dir * 22.0 - down * 0.5, hand - dir * 3.0 - down * 0.5]), Color(0.85, 0.85, 0.85))
			poly(c, PackedVector2Array([hand + dir * 5.0 - down * 0.5, hand + dir * 14.0 - down * 0.5, hand + dir * 14.0 + down * 2.5, hand + dir * 5.0 + down * 2.5]), Color(0.45, 0.45, 0.45))
			c.draw_line(hand + dir * 7.0 + down * 1.0, hand + dir * 12.0 + down * 1.0, Color.BLACK, 1.0)
		"arbalete":
			poly(c, PackedVector2Array([hand - dir * 8.0 - down * 1.5, hand + dir * 14.0 - down * 1.5, hand + dir * 14.0 + down * 2.0, hand - dir * 8.0 + down * 2.0]), Color(0.45, 0.45, 0.45))
			var front := hand + dir * 12.0
			var bow := PackedVector2Array()
			for i in 7:
				var k := -1.0 + i / 3.0
				bow.append(front + down * k * 10.0 - dir * (k * k * 4.0))
			c.draw_polyline(bow, Color.BLACK, 4.0)
			c.draw_polyline(bow, Color(0.9, 0.9, 0.9), 2.0)
			c.draw_line(bow[0], hand + dir * 2.0, Color(0.8, 0.8, 0.8), 1.0)
			c.draw_line(bow[6], hand + dir * 2.0, Color(0.8, 0.8, 0.8), 1.0)
			shaft(c, hand + dir * 1.0 - down * 2.5, hand + dir * 18.0 - down * 2.5, 1.5, Color.WHITE)
			c.draw_colored_polygon(PackedVector2Array([hand + dir * 18.0 - down * 4.5, hand + dir * 22.0 - down * 2.5, hand + dir * 18.0 - down * 0.5]), Color.WHITE)
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


static func muzzle_length(id: String) -> float:
	match id:
		"fusil":
			return 23.0
		"arbalete":
			return 22.0
	return 14.0


# =====================================================================
#  MISE EN PLACE
# =====================================================================

func _ready() -> void:
	GameData.setup_inputs()
	sprite = $Sprite2D  # pas de @onready : main.gd peut rappeler _ready() si le script s'est détaché
	sprite.visible = false  # le personnage est maintenant dessiné en formes
	if body_layer == null:
		body_layer = Node2D.new()
		add_child(body_layer)
		body_layer.draw.connect(draw_body)
		weapon_layer = Node2D.new()
		add_child(weapon_layer)
		weapon_layer.draw.connect(draw_weapon)
	add_to_group("player")
	# pentes : marcher dessus sans glisser ni décoller
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 14.0
	floor_constant_speed = true
	apply_stats()


func apply_stats() -> void:
	speed = GameData.move_speed()
	jump_velocity = GameData.jump_velocity()
	fire_delay = GameData.fire_delay()
	attack_length = GameData.attack_length()
	trail.clear()


func get_hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(10, 15), Vector2(20, 31))


func is_invulnerable() -> bool:
	return dash_time > 0.0 or dead


func _unhandled_input(event: InputEvent) -> void:
	# clavier : mémorise les appuis comme les boutons tactiles
	for action in ["ui_accept", "attaque", "feu", "dash"]:
		if event.is_action_pressed(action):
			GameData.tap(action)


# =====================================================================
#  BOUCLE PHYSIQUE
# =====================================================================

func _physics_process(delta: float) -> void:
	GameData.update_taps(delta)
	queue_redraw()
	hurt_flash = maxf(0.0, hurt_flash - delta)
	muzzle_flash = maxf(0.0, muzzle_flash - delta)
	update_trail(delta)

	if dead:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		position += velocity * delta
		body_rot += 8.0 * delta
		body_layer.queue_redraw()
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
		if not attack_hit_done and progress >= hit_at and not is_gun(GameData.weapon):
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
	update_water(delta)
	if in_water:
		# dans l'eau : on coule doucement, on nage en appuyant sur le saut
		velocity.y = minf(velocity.y + GRAVITY * 0.3 * delta, 110.0)
		swim_cd = maxf(0.0, swim_cd - delta)
		if can_control and swim_cd <= 0.0 and (Input.is_action_pressed("ui_accept") or GameData.has_tap("ui_accept")):
			GameData.clear_tap("ui_accept")
			swim_cd = 0.28
			# à la surface, on saute hors de l'eau
			var at_surface: bool = level != null and not level.is_water(global_position + Vector2(0, -20))
			velocity.y = jump_velocity * 0.9 if at_surface else -210.0
			squash = Vector2(0.85, 1.15)
			if level:
				level.fx.burst(global_position + Vector2(0, -10), 4, 30.0, Color(1, 1, 1, 0.7), 0.6, 2.0, -60.0)
	elif not on_floor:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		# le spectre plane en gardant le saut appuyé
		if GameData.char_has("plane") and velocity.y > GLIDE_FALL and Input.is_action_pressed("ui_accept"):
			velocity.y = GLIDE_FALL
			gliding = true

	var direction := 0.0
	if can_control and hurt_time <= 0.0:
		direction = Input.get_axis("ui_left", "ui_right")
		if not in_water:
			handle_jump()
		handle_attack()
		handle_fire()
		handle_dash()

	if hurt_time > 0.0:
		hurt_time -= delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	elif direction != 0.0:
		velocity.x = direction * speed * (0.7 if in_water else 1.0)
		facing = signf(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 12.0 * delta)

	move_and_slide()
	update_animation(delta)


func update_water(_delta: float) -> void:
	var now: bool = level != null and level.is_water(global_position)
	if now != in_water and level:
		level.sound("plouf")
		level.fx.burst(global_position + Vector2(0, -6), 14, 110.0, Color(1, 1, 1, 0.8), 0.5, 2.5, 500.0, 120.0)
		if now:
			velocity.y *= 0.3
	in_water = now
	if in_water and level and randf() < 0.05:
		level.fx.spawn(global_position + Vector2(facing * 6.0, -10.0), Vector2(randf_range(-5, 5), -40), Color(1, 1, 1, 0.6), 1.0, 2.0)


# Écharpe / cape : chaque point suit le précédent, tombe un peu et flotte au vent
func update_trail(delta: float) -> void:
	var look := look_of(GameData.character)
	var kind: String = look["traine"]
	if kind == "":
		trail.clear()
		return
	var info: Dictionary = TRAILS[kind]
	var n: int = info["n"]
	var seg: float = info["seg"]
	var anchor_local: Vector2 = info["accroche"]
	anchor_local.x *= facing
	var anchor := global_position + anchor_local + Vector2(0, -absf(sin(run_phase)) * 1.8 if absf(velocity.x) > 10.0 else 0.0)
	if trail.size() != n:
		trail.clear()
		for i in n:
			trail.append(anchor + Vector2(-facing * seg * i, 0))
	trail[0] = anchor
	var fall := -35.0 if info["monte"] else 45.0
	for i in range(1, n):
		var p: Vector2 = trail[i]
		p += Vector2(-facing * 14.0 + sin(anim_time * 7.0 + i * 0.8) * 10.0, fall + cos(anim_time * 5.0 + i) * 8.0) * delta
		var prev: Vector2 = trail[i - 1]
		var d := p - prev
		if d.length() > seg:
			p = prev + d.normalized() * seg
		trail[i] = p


func handle_jump() -> void:
	# Saut au sol : is_action_pressed (jamais raté au tactile)
	var wants := Input.is_action_pressed("ui_accept") or GameData.has_tap("ui_accept")
	if wants and air_time < COYOTE_TIME and velocity.y >= 0.0:
		do_jump()
		if level:
			level.sound("saut")
	elif GameData.has_tap("ui_accept") and air_time >= COYOTE_TIME and jumps_left > 0:
		# double saut : il faut un nouvel appui
		jumps_left -= 1
		do_jump()
		if level:
			level.sound("double_saut")
			level.fx.ring(global_position + Vector2(0, 14), 12.0, Color.WHITE, 0.3)
			level.fx.burst(global_position + Vector2(0, 14), 8, 70.0, Color.WHITE, 0.3, 2.0)


func do_jump() -> void:
	velocity.y = jump_velocity
	air_time = COYOTE_TIME
	GameData.clear_tap("ui_accept")
	squash = Vector2(0.75, 1.25)
	dust(5)


func handle_attack() -> void:
	if attack_cd > 0.0:
		return
	if Input.is_action_pressed("attaque") or GameData.has_tap("attaque"):
		GameData.clear_tap("attaque")
		if is_gun(GameData.weapon):
			shoot()
			return
		attack_time = attack_length
		attack_cd = attack_length + 0.06
		attack_hit_done = false
		if level:
			level.sound("coup")


# Armes à feu
func shoot() -> void:
	var id := GameData.weapon
	attack_cd = GameData.attack_length()
	attack_time = 0.14
	muzzle_flash = 0.07
	if level:
		level.sound(id)
	var muzzle := global_position + Vector2(facing * (9.0 + muzzle_length(id)), 1.0)
	if level:
		var count: int = GameData.weapon_stat("nombre")
		var spread: float = GameData.weapon_stat("ecart")
		var spd: float = GameData.weapon_stat("vitesse")
		for i in count:
			var a := (i - (count - 1) * 0.5) * spread + randf_range(-0.02, 0.02)
			level.spawn_projectile(muzzle, Vector2(facing * spd, 0).rotated(a * facing), "joueur", GameData.weapon_stat("proj"), GameData.melee_damage())
		# douille éjectée + fumée
		if id != "arbalete":
			level.fx.spawn(global_position + Vector2(facing * 6.0, -2.0), Vector2(-facing * randf_range(40, 80), -140), Color(0.75, 0.75, 0.75), 0.7, 2.0, 700.0)
		level.fx.burst(muzzle, 5, 50.0, Color(0.8, 0.8, 0.8, 0.6), 0.4, 3.0, 0.0, 20.0)
		if id == "fusil":
			level.shake(3.0)
			velocity.x -= facing * 120.0


func handle_fire() -> void:
	if fire_cd > 0.0:
		return
	if Input.is_action_pressed("feu") or GameData.has_tap("feu"):
		GameData.clear_tap("feu")
		fire_cd = fire_delay
		cast_time = 0.25
		squash = Vector2(1.2, 0.9)
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
			level.sound("ruee")
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
	squash = Vector2(1.3, 0.75)
	dust(7)
	if level:
		level.sound("atterrir", 0.15)


func dust(count: int) -> void:
	if level:
		level.fx.burst(global_position + Vector2(0, 15), count, 50.0, Color(0.85, 0.85, 0.85), 0.4, 2.5, 0.0, 20.0)


func spawn_ghost() -> void:
	# image fantôme pendant la ruée
	var g := Node2D.new()
	g.global_position = global_position
	var st := pose_state()
	st["alpha"] = 0.45
	st["trail"] = PackedVector2Array()
	var char_id := GameData.character
	g.draw.connect(func(): draw_character(g, char_id, st))
	get_parent().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)
	tw.tween_callback(g.queue_free)


# ---------- Appelé par main.gd et les obstacles ----------

func bounce() -> void:
	if Input.is_action_pressed("ui_accept"):
		velocity.y = jump_velocity  # rebond plus haut si on garde le saut appuyé
	else:
		velocity.y = STOMP_BOUNCE
	air_time = COYOTE_TIME
	squash = Vector2(0.75, 1.25)


func spring(force: float) -> void:
	if level:
		level.sound("ressort", 0.02)
	velocity.y = force
	air_time = COYOTE_TIME
	jumps_left = 1 if GameData.has_double_jump() else 0
	squash = Vector2(0.65, 1.4)


func take_hit(from_x: float) -> void:
	var dir := 1.0 if global_position.x >= from_x else -1.0
	velocity = Vector2(dir * 220.0, -260.0)
	hurt_time = 0.3
	hurt_flash = 0.15
	attack_time = 0.0
	dash_time = 0.0


func die() -> void:
	dead = true
	can_control = false
	attack_time = 0.0
	velocity = Vector2(0, -380)


# =====================================================================
#  ANIMATION ET DESSIN
# =====================================================================

func update_animation(delta: float) -> void:
	squash = squash.lerp(Vector2.ONE, minf(1.0, 12.0 * delta))
	body_rot = 0.0
	anim_time += delta
	if is_on_floor() and absf(velocity.x) > 10.0:
		run_phase += delta * 13.0
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = 0.25
			dust(2)
	if hurt_time > 0.0:
		body_rot = -0.25 * facing
	elif dash_time > 0.0:
		body_rot = 0.2 * facing
	elif gliding:
		body_rot = sin(anim_time * 8.0) * 0.08
	body_layer.queue_redraw()
	weapon_layer.queue_redraw()


func current_pose() -> String:
	if dead or hurt_time > 0.0:
		return "hurt"
	if attack_time > 0.0 or cast_time > 0.0:
		return "attack"
	if dash_time > 0.0:
		return "dash"
	if not is_on_floor():
		if gliding:
			return "glide"
		return "jump" if velocity.y < 0.0 else "fall"
	if absf(velocity.x) > 10.0:
		return "run"
	return "idle"


func weapon_hands() -> Dictionary:
	# position des mains selon l'arme (pour que les bras tiennent vraiment l'arme)
	var out := {}
	if attack_time > 0.0:
		out["hand_f"] = Vector2(facing * 9.0, 1.0) if is_gun(GameData.weapon) else Vector2(facing * 7.0, 3.0)
	elif is_gun(GameData.weapon):
		out["hand_f"] = Vector2(facing * 8.0, 3.0)
	else:
		out["hand_b"] = Vector2(-facing * 4.0, 6.0)
	return out


func pose_state() -> Dictionary:
	var local_trail := PackedVector2Array()
	for p in trail:
		local_trail.append(p - global_position)
	var st := {
		"t": anim_time, "pose": current_pose(), "run": run_phase, "facing": facing,
		"squash": squash, "rot": body_rot, "alpha": 0.85 if GameData.character == "spectre" else 1.0,
		"flash": hurt_flash > 0.0, "trail": local_trail,
	}
	st.merge(weapon_hands(), true)
	return st


func draw_body() -> void:
	draw_character(body_layer, GameData.character, pose_state())


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

	if style == "tir":
		# arme à feu : tenue devant, recul au tir
		weapon_layer.z_index = 1
		var recoil := 3.0 * (attack_time / 0.14) if attack_time > 0.0 else 0.0
		var aiming := attack_time > 0.0 or attack_cd > 0.0
		var hand := Vector2(facing * (9.0 - recoil), 1.0) if aiming else Vector2(facing * 8.0, 3.0)
		var dir := Vector2(facing, 0) if aiming else Vector2(facing * 0.9, 0.45).normalized()
		draw_weapon_shape(weapon_layer, hand, dir, weapon_id, anim_time)
		if muzzle_flash > 0.0:
			var m := hand + dir * muzzle_length(weapon_id)
			var star := PackedVector2Array()
			for i in 10:
				var a := TAU * i / 10.0
				var r := 9.0 if i % 2 == 0 else 3.5
				star.append(m + dir * 5.0 + Vector2(cos(a) * r * 1.3, sin(a) * r * 0.8))
			weapon_layer.draw_colored_polygon(star, Color.WHITE)
			weapon_layer.draw_circle(m + dir * 4.0, 12.0, Color(1, 1, 1, 0.25))
		return

	if attack_time <= 0.0:
		# arme tenue en main, derrière le corps
		weapon_layer.z_index = -1
		var rest := deg_to_rad(-80.0 if style != "arc" else -65.0)
		var rest_dir := Vector2(cos(rest) * facing, sin(rest))
		draw_weapon_shape(weapon_layer, Vector2(-facing * 4.0, 6.0), rest_dir, weapon_id, anim_time)
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
	var trail_pts := PackedVector2Array()
	for k in 13:
		var ta := lerpf(maxf(a0, a - 2.0), a, k / 12.0)
		trail_pts.append(hand + Vector2(cos(ta) * facing, sin(ta)) * (reach_len + 4.0))
	weapon_layer.draw_polyline(trail_pts, Color(1, 1, 1, 0.3), 9.0, true)
	weapon_layer.draw_polyline(trail_pts, Color(1, 1, 1, 0.85), 2.0, true)
	draw_weapon_shape(weapon_layer, hand, Vector2(cos(a) * facing, sin(a)), weapon_id, anim_time)
