# Ombres — plateforme 2D noir et blanc (Godot 4.7, iPad)

Tout est généré en code : aucun fichier image importé.

## Contenu

- **9 niveaux** dans 3 mondes : la Forêt morte, la Grotte, le Château (pluie et éclairs).
- **3 boss** : le Corbeau, le Golem, le Roi Ombre. Chacun a plusieurs attaques et passe en « colère » à mi-vie.
- **Combat** : arme au corps à corps (épée, hache ou lance), boule de feu, écrasement en sautant dessus.
- **Ennemis** : marcheur, tireur, chauve-souris, sauteur, spectre.
- **À ramasser** : pièces, coeurs, 3 éclats de lune cachés par niveau, caisses cassables.
- **Magasin** : armure, bottes, forge, armes, boule de feu niv 2 et 3, double saut, ruée, aimant à pièces, et 3 personnages (Ombre, Lune, Roc).
- **Progression sauvegardée** automatiquement (`user://sauvegarde.cfg`).

## Fichiers

| Fichier | Rôle |
|---|---|
| `main.tscn` | Scène : `Node2D` (main.gd) › `Player` (player.gd), `StaticBody2D`, `CanvasLayer` (canvas_layer.gd) |
| `main.gd` | Menus/niveau, construction des cartes, caméra, collisions, HUD, décors, fin de niveau |
| `player.gd` | Joueur : déplacement, animations, arme, boule de feu, double saut, ruée |
| `enemy.gd` | Les 5 types d'ennemis |
| `boss.gd` | Les 3 boss |
| `fireball.gd` | Tous les projectiles |
| `pickup.gd` | Pièces, coeurs, éclats |
| `fx.gd` | Particules |
| `canvas_layer.gd` | Boutons tactiles |
| `menu.gd` | Écran titre, carte des niveaux, magasin |
| `game_data.gd` | Pièces, achats, sauvegarde, statistiques (pas besoin d'Autoload) |
| `levels.gd` | Les cartes des niveaux, en texte |

Les scripts autres que `main.gd`, `player.gd` et `canvas_layer.gd` ne s'attachent à aucun nœud : `main.gd` les charge.

## Modifier un niveau

Ouvrir `levels.gd` : chaque niveau est un dessin en texte, 1 caractère = 1 case de 32 px.
La légende est en haut du fichier. Toutes les lignes d'un niveau doivent avoir la même longueur.

## Contrôles au clavier (pour tester sur ordinateur)

Flèches : se déplacer · Espace : sauter · X : attaquer · C : boule de feu · Maj : ruée
