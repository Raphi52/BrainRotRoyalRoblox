# Grille 10/10 — Brainrot Royale

Lot 1 du plan « passer le jeu de 1/10 à 10/10 » (plan-59c9ac57, fil chef conv-1263).
Ce fichier fixe la CIBLE et la MESURE DE DÉPART. Il ne change aucun code.

> **Départ mesuré le 2026-10-29 : 4/10** (moyenne des 9 écrans), sur le code du commit
> `0eb89e6` (= `108ee7f` pour `src/` : `0eb89e6` n'ajoute que ce fichier).
> Les 4 écrans de bataille ont été construits dans une **copie séparée du dépôt au dernier
> commit** : d'autres lots modifiaient `src/` au même moment (`Maquette.lua`, `Decor.lua`,
> `GameServer.server.lua`, `GameClient.client.lua`, `Mise.lua`), et une première série construite
> dans le dossier partagé montrait déjà une partie de leur travail (plus de ping, autre décor) :
> elle a été écartée. Les 5 écrans de menu ont été construits dans le dossier partagé : leurs
> fichiers (`Hub.client.lua`, `MiseMenu.lua`, `Habillage.lua`) étaient identiques au commit.
> Toutes les images font **1452 × 793 px**. Les numéros de ligne cités sont ceux du commit `0eb89e6`.

## Comment noter

- Chaque critère se lit sur **une capture** du moteur, sans lire le code.
- Barème d'un critère : **10** = au niveau de Clash Royale (CR) · **7** = présent, défaut mineur
  qu'il faut chercher · **4** = défaut visible au premier coup d'œil · **0** = absent ou cassé.
- Note d'un écran = moyenne de ses critères, arrondie à l'entier. **Plafond** : un critère à 2 ou
  moins plafonne l'écran à 4 (un défaut bloquant ne se rattrape pas par la moyenne).
- Note du jeu = moyenne des 9 écrans.
- Les tailles se mesurent **en proportion** de la capture : la fenêtre du bureau caché change de
  largeur d'un lancement à l'autre (812, 1296, 1452 px observés). Toujours noter la taille de
  l'image à côté de la mesure.
- Repère CR pour les tailles : l'arène fait **18 cases de large sur 32 de long** (sources fan, pas
  d'officiel : [fandom](https://clashroyale.fandom.com/wiki/User_blog:Kjx_and_lgym/How_to_play_troop_type_cards),
  [metagamenation](https://metagamenation.com/clash-royale-field-master-the-arena-layout-and-dominate-every-battle-in-2026/)).
  Une **case** = largeur de l'arène au niveau de la rivière ÷ 18. Mesuré sur `lot1-tuto.png` :
  rivière de x=365 à x=1112 → **≈ 41 px par case**.

## Note de départ par écran

| Écran | Capture | Moyenne | Note de départ |
|---|---|---|---|
| Bataille — début | `captures/lot1-bataille-debut.png` | 3,6 | **4** |
| Bataille — mêlée | `captures/lot1-bataille-melee.png` | 2,3 | **2** |
| Fin de partie | `captures/lot1-fin.png` | 5,2 | **4** (plafond : F2) |
| Accueil (BATAILLE) | `captures/lot1-accueil.png` | 6,0 | **4** (plafond : A2) |
| BOUTIQUE | `captures/lot1-boutique.png` | 5,2 | **5** |
| CARTES / deck | `captures/lot1-cartes.png` | 7,0 | **7** |
| CLAN | `captures/lot1-clan.png` | 6,3 | **4** (plafond : L1) |
| ÉVÉNEMENTS | `captures/lot1-evenements.png` | 4,5 | **4** (plafond : E2, E3) |
| Tutoriel | `captures/lot1-tuto.png` | 1,7 | **2** |
| **Jeu** | | | **4/10** |

## Critères par écran, notés

### 1. Bataille — début (`lot1-bataille-debut.png`, 2:52, « Arene de nuit ») — 4/10

| # | Critère observable | 10/10 (réf. CR) | Départ | Ce que montre la capture |
|---|---|---|---|---|
| D1 | Arène éclairée et lisible | Arène de jour, couleurs franches | **2** | Arène de nuit presque noire : sol, chemins et rivière se devinent à peine |
| D2 | Tours reconnaissables | Tours dessinées, roi plus gros | **3** | Blocs de briques ; côté bleu, une grosse boule blanche (~45 px) sur chaque tour ; côté rouge, un drapeau hexagonal |
| D3 | Camps lisibles | Bleu en bas, rouge en haut | **6** | Bleu/rouge présents, mais écrasés par la nuit |
| D4 | Main de cartes lisible | Portraits nets, goutte d'élixir chiffrée | **4** | Aucune goutte de coût : « 2 elixir » écrit dans le nom ; « JAUGE PLEINE — 3 elixir perdus » posé sur le texte des cartes ; 2 cartes « A VENIR » (CR : 1) |
| D5 | Élixir et chrono lisibles | Barre graduée + chrono | **7** | « 10 » et « 2:52 » lisibles |
| D6 | Aucune info de debug | Rien d'autre que le jeu | **1** | « 50 ms », « Adversaire : ~6 elixir », « Il a pose : - Aquila Frizzante (4) - Cappuccino Assassino (2) », « Connexion instable : tes poses peuvent arriver en retard. » |
| D7 | Aucun texte sur un autre ni coupé | Zéro recouvrement | **2** | 4 lignes d'info (arène, « ROBOT · Robot (debutant) · cartes niveau 1 », enjeu, connexion) écrites SUR les tours adverses ; bandeau « TA TOUR GAUCHE est attaquee » en plus |

### 2. Bataille — mêlée (`lot1-bataille-melee.png`, 2:35, nuit) — 2/10

Réserve : `--melee` fait poser des robots en rafale ; la densité est forcée, la lisibilité de
chaque unité ne l'est pas.

| # | Critère observable | 10/10 (réf. CR) | Départ | Ce que montre la capture |
|---|---|---|---|---|
| M1 | Unités assez grandes | Unité de base ≥ 1 case (≈ 41 px ici) | **3** | Unité de base ≈ **23 px** = 0,56 case (mesure sur `lot1-tuto.png`, Trippi Troppi) ; la boule blanche d'une tour est 2× plus grosse qu'une unité |
| M2 | Unités identifiables | Silhouette propre à chaque troupe | **1** | Deux tas lumineux : aucune unité nommable |
| M3 | Camp de chaque unité lisible | Barre de vie colorée par camp | **5** | Halo et rond de ~10 px cyan/rouge au-dessus de chaque unité, visibles de nuit ; aucune barre de vie |
| M4 | Mêlée lisible | On compte les unités | **1** | Impossible de compter ni de voir qui frappe qui |
| M5 | Coups visibles | Effet par attaque (+ son, hors capture) | **2** | Aucun impact ni projectile ne se distingue des halos de camp |
| M6 | Dégâts lisibles sur les tours | Barre + chiffre par tour | **2** | Barres fines sous les tours, aucun chiffre, illisibles de nuit |
| M7 | Une seule bannière à la fois | 0 ou 1 | **3** | « Hors de ta zone de pose » + bloc d'info sous le score + « Burbaloni Lulilolli revient dans 4 cartes » flottant |
| M8 | Aucun texte sur un autre, aucun debug | Zéro | **1** | « 39 ms », « Il a pose : … x8 / x7 / x10 », « Tu as pose : … x12 », « Adversaire : ~0 elixir » ; refus écrit sur mes propres tours |

### 3. Fin de partie (`lot1-fin.png`, DÉFAITE 0-1, nuit) — 4/10

| # | Critère observable | 10/10 (réf. CR) | Départ | Ce que montre la capture |
|---|---|---|---|---|
| F1 | Résultat évident | Grand bandeau, couleur du gagnant | **7** | « DEFAITE… » en très gros, blanc, sans couleur |
| F2 | Couronnes lisibles | 0-3 couronnes par camp, en grand | **2** | Aucune couronne sur l'écran de fin ; seul le score du haut (« ○○○ - ●○○ »), assombri |
| F3 | Gains lisibles | Trophées et coffre, chiffrés, en grand | **3** | « +0 trophees +20 pieces +4 pass (palier 0/20) (partie contre le robot) » en ~13 px, coupé sur 2 lignes |
| F4 | Un seul bouton évident | Un gros bouton « OK » | **6** | « Rejouer » seul, mais rectangle jaune plat, sans le style des boutons du menu |
| F5 | Aucun bloc sur un autre | Zéro recouvrement | **8** | Blocs bien séparés (rectangles de `Mise.fin`) |
| F6 | Fond calme | Seul l'écran de fin se lit | **5** | Tableau de stats en 11 px + bloc « Code : BRR1-D01-24-21-0 » en police machine ; chrono, score et ligne du robot restent visibles |

### 4. Accueil — onglet BATAILLE (`lot1-accueil.png`) — 4/10

| # | Critère observable | 10/10 (réf. CR) | Départ | Ce que montre la capture |
|---|---|---|---|---|
| A1 | Bouton BATAILLE dominant | Gros bouton jaune au centre | **8** | « JOUER » vert, large, au centre |
| A2 | Arène courante visible | Illustration de l'arène au centre | **2** | Aucune image : l'arène tient dans une ligne de ~11 px (« Cour des Brainrots - Plage Tralalero dans 200 trophees… ») ; à sa place, le titre « BRAINROT ROYALE » |
| A3 | Coffres lisibles | 4 emplacements, état et minuterie | **5** | 4 coffres gris identiques « vide / Gagne une partie » |
| A4 | Soldes lisibles | Barre de ressources en haut | **8** | 100 pièces, 0 gemme, 0 trophée |
| A5 | Barre d'onglets claire | 5 onglets, actif mis en avant | **7** | Actif plus grand et nommé ; l'onglet BOUTIQUE est un **cadenas** |
| A6 | Aucun texte sur un autre ni coupé | Zéro | **7** | Rien ne se chevauche ; textes de 10-11 px (« Saison 48 : 5 j 14 h · sommet 0 ») |
| A7 | Style cohérent | Une identité graphique | **5** | Colonne de 4 boutons texte de couleurs différentes (« REVOIR LE TUTORIEL - 1 min », « REGLES DU JEU »…), fond bleu nuit uni |

À noter, hors note : « (progression non sauvegardee dans Studio) » n'apparaît que dans Studio.

### 5. BOUTIQUE (`lot1-boutique.png`) — 5/10

| # | Critère observable | 10/10 (réf. CR) | Départ | Ce que montre la capture |
|---|---|---|---|---|
| S1 | Titre dégagé | Titre seul sur sa ligne | **3** | « … Bombardiro Crocodilo » passe SOUS le « BO » de BOUTIQUE (vérifié à l'agrandi) ; « Il te manque 500 pieces pour la moins chere » collé à gauche du titre |
| S2 | Offres en grille régulière | Grille propre | **8** | Grille 4 × 3 régulière |
| S3 | Prix lisible sur chaque offre | Prix dans un bouton vert | **3** | 2 tuiles sur 12 ont un prix (« 500 pieces », « 800 pieces ») ; les 3 offres Robux n'affichent pas leur prix |
| S4 | Aucun texte coupé en « … » | Zéro troncature | **6** | Aucun « … » visible ; textes d'effet de 9-10 px, noms de taille incohérente (« Lirili Larila », « Trippi Troppi » 2× plus gros) |
| S5 | Visuel de chaque offre | Illustration par offre | **8** | Chaque tuile a son personnage |
| S6 | État d'achat clair | Prix grisé si trop cher | **3** | 10 tuiles sur 12 : bouton gris « IL MANQUE 2 EXEMPLAIRES » — c'est une collection, pas une boutique |

### 6. CARTES / deck (`lot1-cartes.png`) — 7/10

| # | Critère observable | 10/10 (réf. CR) | Départ | Ce que montre la capture |
|---|---|---|---|---|
| C1 | Deck de 8 visible d'un bloc | 2 × 4 en haut | **8** | « TON DECK » : 8 cartes sur une rangée, en bas |
| C2 | Carte lisible | Portrait plein cadre, goutte, niveau | **6** | Portraits petits dans la collection ; tailles de nom incohérentes |
| C3 | Rareté visible | Cadre coloré par rareté | **6** | Bleu (rare), violet (épique) ; le cadre jaune veut dire « dans le deck », pas une rareté |
| C4 | Coût moyen affiché | « Coût moyen : 3,5 » | **8** | « Cout moyen 2,8 - LEGER - 2 cartes anti-air » |
| C5 | Collection séparée du deck | Section dessous | **7** | Séparées, mais la collection est au-dessus et répète « DANS LE DECK » |
| C6 | Aucun texte coupé ni sur un autre | Zéro | **7** | Rien de coupé ; « deck plein : retire une carte » en ~9 px |

### 7. CLAN (`lot1-clan.png`) — 4/10

| # | Critère observable | 10/10 (réf. CR) | Départ | Ce que montre la capture |
|---|---|---|---|---|
| L1 | Écran rempli | Membres ou recherche de clan | **2** | 18 lignes sur 20 vides : 9 « place libre », « classement indisponible ici » puis « 2. - » à « 10. - » (le classement est peut-être vide parce que la capture est faite dans Studio) |
| L2 | Titre et identité du clan | En-tête avec blason | **6** | « CLAN BRAINROT », losange jaune, « 1 joueur en ligne » |
| L3 | Liste lisible | Lignes alignées | **7** | Lisible |
| L4 | Action principale évidente | Un bouton principal | **7** | « INVITER » + une phrase d'explication |
| L5 | Aucun texte coupé ni sur un autre | Zéro | **9** | Rien |
| L6 | Style cohérent | Même identité que BATAILLE | **7** | Même barre du haut, mêmes onglets |

### 8. ÉVÉNEMENTS (`lot1-evenements.png`) — 4/10

| # | Critère observable | 10/10 (réf. CR) | Départ | Ce que montre la capture |
|---|---|---|---|---|
| E1 | Écran rempli | Bannières d'événements | **6** | Bonus du jour, série, coffres, quêtes, coffre gratuit — mais aucun « événement » (mode spécial) |
| E2 | Événement illustré | Bannière illustrée | **2** | Aucune image : boîtes de texte |
| E3 | Durée visible | Minuterie | **2** | Aucune durée, ni pour le bonus du jour ni pour les quêtes |
| E4 | Récompense visible | Icône + quantité | **4** | « +50 », « coffre d'argent » en texte ; quêtes sans récompense |
| E5 | Bouton d'entrée évident | Bouton « Jouer » | **6** | « BONUS DU JOUR : +50 » et « RECUPERER » ; aucun « Jouer » |
| E6 | Aucun texte coupé ni sur un autre | Zéro | **7** | Barres de quêtes vides, sans libellé, détachées du texte à gauche ; rangée de 4 coffres en double de l'accueil |

### 9. Tutoriel (`lot1-tuto.png`, étape 3/5, « Vallee du couchant ») — 2/10

Réserve : la copie de test ne joue pas le tutoriel ; l'étape 3 (« regarder ses unités avancer »)
est photographiée sans joueur. Le tutoriel est muet par conception (`src/shared/Tutoriel.lua:31` :
« ce que le client met en scène, sans un mot »).

| # | Critère observable | 10/10 (réf. CR) | Départ | Ce que montre la capture |
|---|---|---|---|---|
| T1 | Consigne courte et lisible | Bulle courte | **1** | Seul « ETAPE 3 / 5 » ; aucune consigne |
| T2 | Geste montré | Main de la carte vers la case | **1** | Rien à cette étape |
| T3 | Cible visible | Case en surbrillance | **1** | Rien |
| T4 | Le reste ne parasite pas | Seul le tutoriel parle | **1** | « 50 ms », « Adversaire : ~10 elixir », « Tu as pose : … », « Hors de ta zone de pose », lignes d'info, carte « IL MANQUE 1 » dans la main |
| T5 | Bulle hors du jeu utile | Bulle dans une zone vide | **1** | Le panneau « ETAPE 3 / 5 » couvre la tour du roi adverse ET est écrit par-dessus « ROBOT · Robot (debutant)… » et « Enjeu : … » |
| T6 | Arène (D1, D2) | Arène lisible, tours reconnaissables | **5** | Décor clair (couchant) ; mêmes tours en blocs à boule blanche |

## Top 15 des défauts les plus visibles, classés par impact

| # | Défaut | Preuve (capture → fichier) | Lot | Critères |
|---|---|---|---|---|
| 1 | **Infos de debug en pleine partie** : ping « 50 ms », « Il a pose : … x8 », « Tu as pose : … x12 », « Adversaire : ~6 elixir » | début, mêlée, tuto → `GameClient.client.lua:1596` (liste), `:1740` et `:2795` (ping) | A | D6, M8, T4 |
| 2 | **Arène de nuit presque noire** (3 photos de bataille sur 4 tombent sur ce décor) | début, mêlée, fin → éclairage `GameServer.server.lua:306-312`, décors `Decor.lua` | B | D1 |
| 3 | **Unités minuscules** : ≈ 23 px pour une case de 41 px (0,56 case) ; pas de barre de vie par unité, juste un rond de ~10 px | mêlée, tuto → `Figurine.lua`, échelle des modèles dans `GameServer` | B | M1, M2, M3 |
| 4 | **Tours méconnaissables** : blocs de briques + grosse boule blanche (bleu) ou drapeau hexagonal (rouge) | les 4 captures de bataille → `Maquette.lua`, construction des tours dans `GameServer` | B | D2, T6 |
| 5 | **4 lignes d'info écrites sur les tours adverses** (arène, niveau du robot, enjeu, « Connexion instable ») | début, mêlée, tuto, fin → `GameClient.client.lua` + `Mise.lua` | A | D7 |
| 6 | **Coups sans effet lisible** : en mêlée, aucun impact ni projectile ne se distingue (le son ne se juge pas sur une capture) | mêlée → `Effets.lua`, `Projectiles.lua`, `Sons` | C | M5 |
| 7 | **Bandeau d'alerte qui inverse gauche et droite** pour le joueur du bas : « TA TOUR GAUCHE est attaquee » alors que l'ennemi est à la tour de droite | 3 captures (série écartée) + code : `GameServer.server.lua:3499` passe `x` brut, `Lecture.lua:146` dit « gauche » si x < 0, or la caméra du camp 1 (`GameClient.client.lua:187-194`) montre x < 0 à DROITE | A | M8 |
| 8 | **Refus « Hors de ta zone de pose » en gros sur mes propres tours** | mêlée, tuto → `GameClient.client.lua:3264` | A | M7, T4 |
| 9 | **Main de cartes** : pas de goutte de coût, « JAUGE PLEINE — 3 elixir perdus » posé sur le texte des cartes | début → `GameClient.client.lua`, `Mise.lua` | A | D4 |
| 10 | **Écran de fin pauvre** : aucune couronne, gains en 13 px coupés sur 2 lignes, stats et « Code : BRR1-… » en police machine, bouton plat | fin → `GameClient.client.lua`, `Mise.fin` | A | F2, F3, F6 |
| 11 | **Tutoriel sans consigne**, et son panneau « ETAPE 3 / 5 » couvre la tour du roi adverse et les lignes d'info | tuto → `GameClient.client.lua:1397-1399` (position fixe `0, 124`) | A | T1, T5 |
| 12 | **Accueil sans image d'arène** : une ligne de 11 px, et une colonne de 4 boutons texte | accueil → `Hub.client.lua` | D | A2, A7 |
| 13 | **Boutique : le sous-titre passe sous « BOUTIQUE »**, « Il te manque 500 pieces » collé au titre | boutique → `Hub.client.lua`, texte `Collection.lua:123` | D | S1 |
| 14 | **Boutique sans prix** : 10 tuiles sur 12 = « IL MANQUE 2 EXEMPLAIRES » en gris, Robux sans montant ; textes de 9-10 px, noms de tailles incohérentes | boutique, cartes → `Hub.client.lua` (tuiles ~1100-1120) | D | S3, S4, S6, C2 |
| 15 | **Événements et clan creux** : ni image ni minuterie, coffres en double de l'accueil ; clan = 9 « place libre » | événements, clan → `Hub.client.lua` | D | E2, E3, L1 |

Répartition : **A** 7 défauts (1, 5, 7, 8, 9, 10, 11) · **B** 3 (2, 3, 4) · **C** 1 (6) · **D** 4 (12-15).

Vus aussi, hors top 15 : barre de 6 émotes toujours affichée (CR : un bouton) ; texte flottant
« X revient dans N cartes » sur l'arène ; onglet BOUTIQUE dessiné comme un cadenas ; 2 cartes
« A VENIR » au lieu d'une.

### Ce que deviennent les défauts « à reconfirmer »

| Défaut signalé sur d'anciennes captures | Verdict sur la capture du 2026-10-29 |
|---|---|
| Bataille sombre | **Confirmé** : décor « Arene de nuit » (début, mêlée, fin) |
| Tours en blocs surmontées de ronds blancs | **Confirmé** (les 4 captures de bataille) |
| Unités minuscules | **Confirmé et mesuré** : 0,56 case |
| « TA TOUR DU ROI VA TOMBER » posé sur le score | **Non vu** : seul « … est attaquee » est apparu, sous le score sans le toucher. Mais le bandeau nomme le mauvais côté (défaut 7) |
| Ping et liste « Il a posé » à l'écran | **Confirmé** (défaut 1) |
| Boutique : « Il te manque 500 pieces » posé sur le titre | **Confirmé autrement** : collé au titre, et c'est la ligne d'en dessous qui passe sous « BOUTIQUE » (défaut 13) |
| Textes coupés en « … » dans les cartes | **Non vu** : aucun « … » sur la boutique ni sur les cartes ; le code le permet encore (`Hub.client.lua:1116`) |

## Protocole de capture (à rejouer par les lots suivants)

Règles : une capture à la fois par lot ; jamais la place partagée en direct ; jamais fermer un
Studio qu'on n'a pas lancé. Code 5 = Studio déconnecté : s'arrêter, seul l'utilisateur peut se
reconnecter.

| Écran | Drapeaux `build.py --autotest …` | `-Secondes` | La photo doit montrer |
|---|---|---|---|
| bataille-debut | `--partie --capture-delai=8` | 45 | arène et main au coup d'envoi |
| bataille-melee | `--melee` | 60 | robots en rafale, photo à 25 s |
| fin | `--partie --court --capture-delai=85` | 110 | écran de fin (à 45 s il restait encore 0:15 de partie) |
| accueil | `--hub --onglet=bataille` | 45 | menu, onglet BATAILLE |
| boutique | `--boutique` | 60 | boutique ouverte |
| cartes | `--deck` | 60 | écran DECK |
| clan | `--hub --onglet=clan` | 45 | onglet CLAN |
| evenements | `--hub --onglet=evenements` | 45 | onglet ÉVÉNEMENTS |
| tuto | `--tuto --partie` | 60 | une étape du tutoriel. **Sans `--partie`**, la copie de test ajoute ses rangées d'unités (`GameServer.server.lua:4099`) : la photo est faussée |

Trois pièges mesurés le 2026-10-29, avec plusieurs lots qui capturent en même temps :

1. **Construire depuis le bon code.** Pour mesurer l'état d'un commit pendant que d'autres lots
   modifient `src/`, construire dans une copie séparée :
   `git worktree add --detach <dossier> HEAD`, lancer `python build.py --autotest …` dans ce
   dossier, puis copier `BrainRotRoyale.autotest.rbxlx` sous `captures/lot<N>-<ecran>.rbxlx`.
2. **La photo disparaît.** 4 captures sur 7 ont rendu le code 3 « capture annoncee par le moteur
   mais aucun fichier dans le stock » : un autre Studio qui démarre vide
   `%LOCALAPPDATA%\Roblox\tmp-capture-storage` avant que le script ne récupère l'image (cause
   probable : 3 échecs sur 3 coïncident avec un démarrage). Parade qui a marché à chaque fois :
   une veille qui copie chaque fichier `wob-*` dès qu'il apparaît vers un dossier privé.
3. **La mauvaise photo.** Quand la sortie du script porte `"correlation":"heure (incertain …)"`,
   l'image copiée peut être celle d'un autre Studio (vu 2 fois, empreintes différentes) : prendre
   toujours `wob-<pid de notre Studio>`.

Drapeaux attendus dans la copie, en plus de `BRR_AUTOTEST BRR_Capture BRR_JOUEURS` :
bataille-debut `BRR_CAP_DELAI BRR_PARTIE` · bataille-melee `BRR_MELEE BRR_PARTIE` ·
fin `BRR_CAP_DELAI BRR_COURT BRR_PARTIE` · accueil/clan/evenements `BRR_HUB BRR_ONGLET` ·
boutique `BRR_BOUTIQUE BRR_HUB` · cartes `BRR_DECK BRR_HUB` · tuto `BRR_PARTIE BRR_TUTO`.
