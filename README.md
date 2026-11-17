# Ombres — plateforme 2D noir et blanc (Godot 4.7, iPad)

Tout est généré en code : aucun fichier image importé.

| Fichier | Rôle |
|---|---|
| `main.tscn` | Scène : `Node2D` (main.gd) › `Player`, `StaticBody2D` (sol), `CanvasLayer` (boutons) |
| `main.gd` | Niveau, décor, caméra, ennemis, score, vies, points de passage, fin |
| `player.gd` | Déplacement, saut, animation de marche (4 images), rebond après écrasement |
| `enemy.gd` | Ennemis « marcheur » (patrouille) et « tireur » (boule toutes les 2 s) |
| `fireball.gd` | Boule tirée par les tireurs |
| `canvas_layer.gd` | Boutons tactiles ◀ ▶ ▲ (multitouch et souris) |

Modifier le niveau : tableaux `GROUND`, `PLATFORMS`, `BLOCKS`, `SPIKES`, `ENEMIES`,
`CHECKPOINTS` en haut de `main.gd`. Zoom : `VIEW_HEIGHT` (hauteur de monde visible).
