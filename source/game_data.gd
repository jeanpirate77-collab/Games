extends RefCounted

# Données conservées entre les niveaux (pièces, achats, progression) et sauvegardées.
# Pas besoin d'Autoload : les autres scripts font
#     const GameData = preload("res://game_data.gd")
# puis GameData.coins, GameData.buy(...), etc.

const SAVE_PATH := "user://sauvegarde.cfg"

# Armes : dégâts, durée du coup (s), zone touchée (largeur, hauteur), style d'animation
#   "arc" : coup de haut en bas   "pique" : coup droit devant   "tour" : tour complet
#   "tir" : arme à feu -> projectile "proj", vitesse, nombre de projectiles, écart entre eux
const WEAPONS := {
	"epee": {"degats": 1, "duree": 0.28, "zone": Vector2(40, 38), "style": "arc"},
	"dague": {"degats": 1, "duree": 0.16, "zone": Vector2(30, 30), "style": "arc"},
	"hache": {"degats": 2, "duree": 0.45, "zone": Vector2(40, 48), "style": "arc"},
	"lance": {"degats": 1, "duree": 0.36, "zone": Vector2(68, 18), "style": "pique"},
	"marteau": {"degats": 3, "duree": 0.6, "zone": Vector2(44, 52), "style": "arc"},
	"faux": {"degats": 2, "duree": 0.5, "zone": Vector2(96, 54), "style": "tour"},
	"lame": {"degats": 2, "duree": 0.3, "zone": Vector2(44, 40), "style": "arc"},
	"pistolet": {"degats": 2, "duree": 0.32, "zone": Vector2.ZERO, "style": "tir", "proj": "balle", "vitesse": 560.0, "nombre": 1, "ecart": 0.0},
	"fusil": {"degats": 1, "duree": 0.75, "zone": Vector2.ZERO, "style": "tir", "proj": "plomb", "vitesse": 460.0, "nombre": 5, "ecart": 0.11},
	"arbalete": {"degats": 3, "duree": 0.7, "zone": Vector2.ZERO, "style": "tir", "proj": "carreau", "vitesse": 600.0, "nombre": 1, "ecart": 0.0},
}

# Personnages : bonus de coeurs, vitesse, saut, recharge du feu, dégâts, pouvoirs offerts
const CHARACTERS := {
	"ombre": {"coeurs": 0, "vitesse": 1.0, "saut": -440.0, "feu": 1.0, "degats": 0, "pouvoirs": []},
	"lune": {"coeurs": 0, "vitesse": 1.15, "saut": -480.0, "feu": 0.75, "degats": 0, "pouvoirs": []},
	"roc": {"coeurs": 1, "vitesse": 0.9, "saut": -440.0, "feu": 1.0, "degats": 1, "pouvoirs": []},
	"chevalier": {"coeurs": 2, "vitesse": 0.85, "saut": -430.0, "feu": 1.2, "degats": 1, "pouvoirs": []},
	"ninja": {"coeurs": 0, "vitesse": 1.25, "saut": -460.0, "feu": 1.0, "degats": 0, "pouvoirs": ["dash"]},
	"sorciere": {"coeurs": 0, "vitesse": 1.0, "saut": -440.0, "feu": 0.55, "degats": 0, "pouvoirs": ["triple"]},
	"spectre": {"coeurs": 1, "vitesse": 1.05, "saut": -450.0, "feu": 0.9, "degats": 0, "pouvoirs": ["double_saut", "plane"]},
}

# Catalogue du magasin.
#   type "niveau" : amélioration à plusieurs niveaux (prix[i] = prix du niveau i+1)
#   type "arme" / "perso" : à acheter une fois, puis à équiper
const ITEMS := [
	{"id": "armure", "cat": "COEURS", "nom": "Armure", "desc": "+1 coeur maximum par niveau", "prix": [50, 100, 160, 240, 340], "type": "niveau"},
	{"id": "cristal", "cat": "COEURS", "nom": "Cristal de vie", "desc": "+1 coeur maximum par niveau", "prix": [120, 250, 400], "type": "niveau"},
	{"id": "bottes", "cat": "COEURS", "nom": "Bottes légères", "desc": "+10 % de vitesse par niveau", "prix": [80, 170], "type": "niveau"},
	{"id": "epee", "cat": "ARMES", "nom": "Épée", "desc": "Équilibrée. Dégâts 1", "prix": [0], "type": "arme"},
	{"id": "dague", "cat": "ARMES", "nom": "Dague", "desc": "Très rapide, courte. Dégâts 1", "prix": [60], "type": "arme"},
	{"id": "hache", "cat": "ARMES", "nom": "Hache", "desc": "Lente mais dégâts 2", "prix": [110], "type": "arme"},
	{"id": "lance", "cat": "ARMES", "nom": "Lance", "desc": "Très longue portée. Dégâts 1", "prix": [130], "type": "arme"},
	{"id": "marteau", "cat": "ARMES", "nom": "Marteau", "desc": "Dégâts 3 + onde de choc au sol", "prix": [190], "type": "arme"},
	{"id": "faux", "cat": "ARMES", "nom": "Faux", "desc": "Tourne et frappe des deux côtés. Dégâts 2", "prix": [230], "type": "arme"},
	{"id": "lame", "cat": "ARMES", "nom": "Lame lunaire", "desc": "Dégâts 2 + lance un croissant de lune", "prix": [350], "type": "arme"},
	{"id": "pistolet", "cat": "ARMES", "nom": "Pistolet", "desc": "Tire des balles rapides. Dégâts 2", "prix": [240], "type": "arme"},
	{"id": "fusil", "cat": "ARMES", "nom": "Fusil à pompe", "desc": "5 plombs en éventail, courte portée", "prix": [300], "type": "arme"},
	{"id": "arbalete", "cat": "ARMES", "nom": "Arbalète", "desc": "Carreau qui traverse les ennemis. Dégâts 3", "prix": [380], "type": "arme"},
	{"id": "forge", "cat": "ARMES", "nom": "Forge", "desc": "+1 dégât pour toutes les armes", "prix": [90, 180, 300], "type": "niveau"},
	{"id": "feu", "cat": "POUVOIRS", "nom": "Boule de feu", "desc": "Niv 2 : recharge rapide. Niv 3 : triple tir", "prix": [0, 90, 200], "type": "niveau"},
	{"id": "double_saut", "cat": "POUVOIRS", "nom": "Double saut", "desc": "Sauter une 2e fois en l'air", "prix": [150], "type": "niveau"},
	{"id": "dash", "cat": "POUVOIRS", "nom": "Ruée", "desc": "Bouton >> : ruée rapide et invincible", "prix": [120], "type": "niveau"},
	{"id": "aimant", "cat": "POUVOIRS", "nom": "Aimant", "desc": "Attire les pièces proches", "prix": [70], "type": "niveau"},
	{"id": "ombre", "cat": "PERSOS", "nom": "Ombre", "desc": "Équilibré", "prix": [0], "type": "perso"},
	{"id": "lune", "cat": "PERSOS", "nom": "Lune", "desc": "Rapide, saute plus haut, feu plus rapide", "prix": [160], "type": "perso"},
	{"id": "roc", "cat": "PERSOS", "nom": "Roc", "desc": "+1 coeur, +1 dégât, un peu lent", "prix": [220], "type": "perso"},
	{"id": "ninja", "cat": "PERSOS", "nom": "Ninja", "desc": "Très rapide, ruée offerte", "prix": [260], "type": "perso"},
	{"id": "sorciere", "cat": "PERSOS", "nom": "Sorcière", "desc": "Triple boule de feu, recharge très rapide", "prix": [280], "type": "perso"},
	{"id": "chevalier", "cat": "PERSOS", "nom": "Chevalier", "desc": "+2 coeurs, +1 dégât, lent", "prix": [320], "type": "perso"},
	{"id": "spectre", "cat": "PERSOS", "nom": "Spectre", "desc": "+1 coeur, double saut, plane (garder le saut)", "prix": [380], "type": "perso"},
]

static var coins := 0
static var upgrades := {"epee": 1, "ombre": 1, "feu": 1}
static var character := "ombre"
static var weapon := "epee"
static var unlocked := 0          # dernier niveau débloqué
static var shards := {}           # index du niveau -> éclats trouvés (meilleur score)
static var containers := {}       # réceptacles de coeur trouvés (un par boss)
static var screen := "titre"      # "titre", "carte", "magasin" ou "niveau"
static var current_level := 0
static var taps := {}             # appuis récents (pour ne jamais rater un tap)
static var loaded := false
static var sfx_on := true
static var music_on := true


# ---------- Sauvegarde ----------

static func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("jeu", "coins", coins)
	cfg.set_value("jeu", "upgrades", upgrades)
	cfg.set_value("jeu", "character", character)
	cfg.set_value("jeu", "weapon", weapon)
	cfg.set_value("jeu", "unlocked", unlocked)
	cfg.set_value("jeu", "shards", shards)
	cfg.set_value("jeu", "containers", containers)
	cfg.set_value("jeu", "version", 2)
	cfg.set_value("options", "sons", sfx_on)
	cfg.set_value("options", "musique", music_on)
	cfg.save(SAVE_PATH)


static func load_game() -> void:
	if loaded:
		return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = cfg.get_value("jeu", "coins", 0)
	upgrades = cfg.get_value("jeu", "upgrades", upgrades)
	character = cfg.get_value("jeu", "character", "ombre")
	weapon = cfg.get_value("jeu", "weapon", "epee")
	unlocked = cfg.get_value("jeu", "unlocked", 0)
	shards = cfg.get_value("jeu", "shards", {})
	containers = cfg.get_value("jeu", "containers", {})
	sfx_on = cfg.get_value("options", "sons", true)
	music_on = cfg.get_value("options", "musique", true)
	if int(cfg.get_value("jeu", "version", 1)) < 2:
		migrate_v1()
	if not WEAPONS.has(weapon):
		weapon = "epee"
	if not CHARACTERS.has(character):
		character = "ombre"


# Ancienne sauvegarde (3 mondes de 3 niveaux) -> nouvelle (5 mondes de 4 niveaux,
# le Château devient le dernier monde)
static func old_to_new(i: int) -> int:
	var w := floori(i / 3.0)
	var k := i % 3
	var slot: int = [0, 1, 4][clampi(w, 0, 2)]
	return slot * 4 + (3 if k == 2 else k)


static func migrate_v1() -> void:
	unlocked = old_to_new(unlocked)
	var s2 := {}
	for k in shards:
		s2[old_to_new(int(k))] = shards[k]
	shards = s2
	var c2 := {}
	for k in containers:
		c2[old_to_new(int(k))] = true
	containers = c2


static func total_shards() -> int:
	var n := 0
	for k in shards:
		n += int(shards[k])
	return n


# ---------- Magasin ----------

static func get_level(id: String) -> int:
	return int(upgrades.get(id, 0))


static func next_price(item: Dictionary) -> int:
	var lvl := get_level(item["id"])
	var prices: Array = item["prix"]
	if lvl >= prices.size():
		return -1
	return int(prices[lvl])


static func buy(item: Dictionary) -> bool:
	var price := next_price(item)
	if price < 0 or coins < price:
		return false
	coins -= price
	upgrades[item["id"]] = get_level(item["id"]) + 1
	if item["type"] == "arme":
		weapon = item["id"]
	elif item["type"] == "perso":
		character = item["id"]
	save_game()
	return true


# ---------- Statistiques du joueur ----------

static func char_stat(key: String):
	var data: Dictionary = CHARACTERS.get(character, CHARACTERS["ombre"])
	return data[key]


static func weapon_stat(key: String):
	var data: Dictionary = WEAPONS.get(weapon, WEAPONS["epee"])
	return data[key]


static func char_has(power: String) -> bool:
	var powers: Array = char_stat("pouvoirs")
	return powers.has(power)


static func max_hearts() -> int:
	return 3 + get_level("armure") + get_level("cristal") + containers.size() + int(char_stat("coeurs"))


static func melee_damage() -> int:
	return int(weapon_stat("degats")) + get_level("forge") + int(char_stat("degats"))


static func move_speed() -> float:
	return 170.0 * (1.0 + 0.1 * get_level("bottes")) * float(char_stat("vitesse"))


static func jump_velocity() -> float:
	return float(char_stat("saut"))


static func fire_delay() -> float:
	var d := 1.0 if get_level("feu") >= 2 else 1.6
	return d * float(char_stat("feu"))


static func fire_triple() -> bool:
	return get_level("feu") >= 3 or char_has("triple")


static func has_double_jump() -> bool:
	return get_level("double_saut") > 0 or char_has("double_saut")


static func has_dash() -> bool:
	return get_level("dash") > 0 or char_has("dash")


static func attack_length() -> float:
	return float(weapon_stat("duree"))


# ---------- Entrées ----------

static func setup_inputs() -> void:
	# Actions en plus de ui_left / ui_right / ui_accept (touches pour tester au clavier)
	var keys := {"attaque": KEY_X, "feu": KEY_C, "dash": KEY_SHIFT}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = keys[action]
			InputMap.action_add_event(action, ev)


# Un tap est mémorisé 0,15 s : même un appui très court n'est jamais perdu
static func tap(action: String) -> void:
	taps[action] = 0.15


static func has_tap(action: String) -> bool:
	return float(taps.get(action, 0.0)) > 0.0


static func clear_tap(action: String) -> void:
	taps[action] = 0.0


static func update_taps(delta: float) -> void:
	for k in taps.keys():
		taps[k] = maxf(0.0, float(taps[k]) - delta)


# ---------- Pixel art ----------

# Crée une texture à partir de lignes de texte.
# "." transparent, "#" noir, "w" blanc, "g" gris clair, "d" gris foncé
static func make_texture(rows: Array, invert := false) -> ImageTexture:
	var w: int = rows[0].length()
	var h: int = rows.size()
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var line: String = rows[y]
		for x in line.length():
			var c := line[x]
			var col := Color(0, 0, 0, 0)
			match c:
				"#":
					col = Color.WHITE if invert else Color.BLACK
				"w":
					col = Color.BLACK if invert else Color.WHITE
				"g":
					col = Color(0.62, 0.62, 0.62)
				"d":
					col = Color(0.3, 0.3, 0.3)
			if col.a > 0.0:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
