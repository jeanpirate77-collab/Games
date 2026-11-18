# Ombres — plateforme 2D noir et blanc (Godot 4.7, iPad)

Tout est généré en code : aucun fichier image importé.

## Contenu

- **20 niveaux** dans 5 mondes : la Forêt morte, la Grotte, les Marais (acide), les Nuages (îles flottantes), le Château (pluie et éclairs).
- **5 boss** : le Corbeau, le Golem, le Crapaud géant, le Dragon de brume, le Roi Ombre. Chacun a plusieurs attaques et passe en « colère » à mi-vie.
- **10 armes**, toujours visibles en main : épée, dague, hache, lance, marteau (onde de choc), faux (frappe tout autour), lame lunaire (lance un croissant), **pistolet**, **fusil à pompe**, **arbalète** (traverse les ennemis). Plus la boule de feu et l'écrasement en sautant dessus.
- **Ennemis** : marcheur, tireur, chauve-souris, sauteur, spectre, oeil volant, chevalier noir (on ne peut pas lui sauter dessus).
- **Obstacles** : pics, acide, plateformes fragiles, ressorts, scies, jets de flammes, stalactites qui tombent, pendules, boules à pointes tournantes, canons, courants d'air, plateformes mobiles (horizontales et verticales), caisses.
- **Relief** : niveaux de 18 cases de haut avec collines, pentes, falaises, souterrains, puits, bassins où l'on nage, murs fissurés qui cachent des coffres.
- **Sons et musique** générés par le code (bouton SON dans le titre et la pause).
- **À ramasser** : pièces, coeurs, 3 éclats de lune cachés par niveau, caisses cassables.
- **7 personnages** dessinés en formes lisses (écharpe ou cape qui flotte, yeux qui clignent) : Ombre, Lune, Roc, Ninja (ruée offerte), Sorcière (triple feu), Chevalier (+2 coeurs), Spectre (double saut, plane).
- **Jusqu'à 16 coeurs** : Armure (5 niveaux), Cristal de vie (3 niveaux), un réceptacle de coeur après chaque boss, bonus de certains personnages.
- **Magasin** : coeurs, bottes, forge, armes, boule de feu niv 2 et 3, double saut, ruée, aimant à pièces, personnages.
- **Graphismes** : lumières dynamiques (joueur, lanternes, porte, boules de feu), filtre « film noir » (grain + lueur), brume, rayons de lune, silhouettes au premier plan, ombres au sol.
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
| `sfx.gd` | Bruitages et musiques fabriqués par le code |
| `obstacle.gd` | Acide, plateformes fragiles, ressorts, scies, flammes, stalactites, pendules, torches |
| `canvas_layer.gd` | Boutons tactiles |
| `menu.gd` | Écran titre, carte des niveaux, magasin |
| `game_data.gd` | Pièces, achats, sauvegarde, statistiques (pas besoin d'Autoload) |
| `levels.gd` | Charge les niveaux depuis `niveaux.txt` |
| `niveaux.txt` | Les cartes des niveaux, en texte |

Couleurs : les coeurs sont rouges, les pièces dorées et le feu orange ; le reste du jeu reste en noir et blanc.

Les scripts autres que `main.gd`, `player.gd` et `canvas_layer.gd` ne s'attachent à aucun nœud : `main.gd` les charge.

## Installation sur iPad (Xogot)

La version gratuite de Xogot limite le projet à **200 Ko** de scripts et de scènes.
Les scripts à la racine sont donc **compactés** (sans commentaires ni espaces inutiles) : environ 180 Ko.

Fichiers à mettre dans le projet (à la racine `res://`) :
- les 13 scripts `.gd` de la racine
- `main.tscn`
- **`niveaux.txt`** (les cartes des niveaux ; un fichier texte ne compte pas dans la limite)

Ne copiez **pas** les dossiers `source/` et `outils/` dans le projet iPad.

- `source/` : les mêmes scripts, lisibles et commentés (pour lire ou modifier le code).
- `outils/compacter.py` : refabrique les scripts compacts à partir de `source/`.
- `outils/niveaux.py` : refabrique `niveaux.txt` à partir des morceaux de niveaux.

Pour exporter le jeu plus tard : dans les préréglages d'export, ajouter `*.txt` aux fichiers non-ressources à inclure.

## Si l'écran devient noir

Le filtre « film noir » utilise un shader. S'il pose problème sur votre appareil, mettre `const POST_FX := false` en haut de `main.gd`.
Pour régler l'obscurité de chaque monde : `const DARKNESS` juste en dessous.

## Modifier un niveau

Ouvrir `niveaux.txt` : chaque niveau est un dessin en texte, 1 caractère = 1 case de 32 px.
La légende est en haut du fichier. Toutes les lignes d'un niveau doivent avoir la même longueur.

## Contrôles au clavier (pour tester sur ordinateur)

Flèches : se déplacer · Espace : sauter · X : attaquer · C : boule de feu · Maj : ruée
