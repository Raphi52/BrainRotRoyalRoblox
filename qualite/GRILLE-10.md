# Grille 10/10 — Brainrot Royale

Lot 1 du plan « passer le jeu de 1/10 à 10/10 » (plan-59c9ac57, fil chef conv-1263).
Ce fichier fixe la CIBLE et la MESURE DE DÉPART. Il ne change aucun code.

> **État au 2026-10-29 : grille écrite, notes de départ NON MESURÉES.**
> Première capture (accueil) : `tools/studio-capture-moteur.ps1` a rendu le **code 5** —
> Studio n'est plus connecté à Roblox. Journal
> `%LOCALAPPDATA%\Roblox\logs\0.745.0.7451137_20261029T091040Z_Studio_72BDD_last.log` :
> « Authenticated : NO » et « Secure Storage read failed … 0x00000490 ». Studio venait de se mettre
> à jour tout seul de 0.741.19 vers 0.745.0 au lancement (journal 0.741 de 09:10:20Z :
> « interruptWithApplicationUpdateIfAvailable »). Seul l'utilisateur peut se reconnecter : ouvrir
> Studio une fois, se connecter, puis relancer le protocole plus bas.
> Aucune capture existante n'est plus récente que le code (dernière capture : 2026-09-29 ;
> dernier changement de `GameClient`/`Hub` : 2026-10-01). Les anciennes captures ne servent donc
> pas de départ.

## Comment noter

- Chaque critère se lit sur **une capture** du moteur, sans lire le code.
- Barème d'un critère : **10** = au niveau de Clash Royale (CR) · **7** = présent, défaut mineur
  qu'il faut chercher · **4** = défaut visible au premier coup d'œil · **0** = absent ou cassé.
- Note d'un écran = moyenne de ses critères, arrondie à l'entier. **Plafond** : un critère à 2 ou
  moins plafonne l'écran à 4 (un défaut bloquant ne se rattrape pas par la moyenne).
- Note du jeu = moyenne des 9 écrans.
- Les tailles se mesurent **en proportion** de la capture : la fenêtre du bureau caché change de
  largeur d'un lancement à l'autre (812, 1296, 1452 px observés). Toujours noter la taille de
  l'image (`largeur × hauteur`) à côté de la mesure.
- Repère CR pour les tailles : l'arène fait **18 cases de large sur 32 de long** (sources fan, pas
  d'officiel : [fandom](https://clashroyale.fandom.com/wiki/User_blog:Kjx_and_lgym/How_to_play_troop_type_cards),
  [metagamenation](https://metagamenation.com/clash-royale-field-master-the-arena-layout-and-dominate-every-battle-in-2026/)).
  Une **case** = largeur visible de l'arène ÷ 18.

## Critères par écran

### 1. Bataille — début (`bataille-debut`)

| # | Critère observable | Mesure sur la capture | 10/10 (réf. CR) | Départ |
|---|---|---|---|---|
| D1 | Arène éclairée et lisible | Le sol, la rivière, les ponts et les deux moitiés se distinguent sans plisser les yeux ; aucune zone noire | Arène de jour, couleurs franches, contraste fort sol/rivière/chemins | — |
| D2 | Tours reconnaissables | On reconnaît 3 tours par camp (roi au centre, 2 de princesse) à leur silhouette, sans légende | Tours dessinées comme des tours (créneaux, toit, garde), roi plus gros que princesses | — |
| D3 | Camps lisibles | Couleur du camp (bleu/rouge) visible sur chaque tour et chaque barre de vie | Bleu en bas, rouge en haut, partout | — |
| D4 | Main de cartes lisible | 4 cartes + la suivante, portrait et coût d'élixir lisibles, aucune carte coupée | Main en bas, portraits nets, gouttes d'élixir chiffrées | — |
| D5 | Barre d'élixir et chrono lisibles | Chiffre d'élixir et temps restant lisibles d'un coup d'œil | Barre violette graduée + chrono en haut à droite | — |
| D6 | Aucune info de debug | Ni ping (« -- ms »), ni liste « Il a posé : », ni texte technique | Rien d'autre que le jeu | — |
| D7 | Aucun texte posé sur un autre ni coupé en « … » | Contrôle visuel de chaque texte | Zéro recouvrement, zéro troncature | — |

### 2. Bataille — mêlée (`bataille-melee`)

| # | Critère observable | Mesure sur la capture | 10/10 (réf. CR) | Départ |
|---|---|---|---|---|
| M1 | Unités assez grandes | Largeur à l'écran de la plus petite unité, en px et en cases | ≥ **1 case** (largeur d'arène ÷ 18) pour une unité de base ; grosses unités ≥ 2 cases (cible choisie, calée sur la grille CR) | — |
| M2 | Unités identifiables | On nomme chaque unité à sa silhouette/couleur, sans étiquette | Chaque troupe a une silhouette propre | — |
| M3 | Camp de chaque unité lisible | Bleu/rouge visible sur chaque unité (barre, socle ou teinte) | Barre de vie colorée par camp au-dessus de chaque unité | — |
| M4 | Mêlée lisible | Dans le paquet le plus dense, on compte les unités et on voit qui frappe qui | Unités qui se chevauchent peu, barres de vie séparées | — |
| M5 | Coups visibles | Au moins un effet de coup ou de projectile visible sur l'image (éclat, flèche, impact) | Chaque attaque a un effet visible (et un son — vérifié hors capture) | — |
| M6 | Dégâts lisibles sur les tours | Barre de vie de chaque tour lisible, chiffre de PV lisible | Barre + chiffre sur chaque tour | — |
| M7 | Une seule bannière à la fois | Nombre de bannières/messages centraux visibles | 0 ou 1 | — |
| M8 | Aucun texte sur un autre, aucun debug | Bannière (« … VA TOMBER ! ») hors du score ; ni ping ni « Il a posé » | Zéro recouvrement, zéro debug | — |

### 3. Fin de partie (`fin`)

| # | Critère observable | Mesure sur la capture | 10/10 (réf. CR) | Départ |
|---|---|---|---|---|
| F1 | Résultat évident | VICTOIRE / DÉFAITE / ÉGALITÉ lisible en une seconde, en gros | Grand bandeau de résultat, couleur du gagnant | — |
| F2 | Couronnes lisibles | Score en couronnes des deux camps, en icônes | 0-3 couronnes par camp, en grand | — |
| F3 | Gains lisibles | Trophées et récompenses, chiffrés, sans texte coupé | Trophées +/- et coffre gagné, chiffrés | — |
| F4 | Un seul bouton d'action évident | Bouton principal (« OK » / « Rejouer ») visible et seul en avant | Un gros bouton « OK » | — |
| F5 | Aucun bloc sur un autre | Bouton, récapitulatif, résumé, main : aucun ne recouvre l'autre | Zéro recouvrement | — |
| F6 | Fond calme | L'arène derrière est assombrie ou floutée, plus aucune info de jeu (main, élixir, ping) | Seul l'écran de fin est lu | — |

### 4. Accueil — onglet BATAILLE (`accueil`)

| # | Critère observable | Mesure sur la capture | 10/10 (réf. CR) | Départ |
|---|---|---|---|---|
| A1 | Bouton BATAILLE dominant | Le bouton de combat est l'élément le plus visible de l'écran | Gros bouton jaune « Bataille » au centre bas | — |
| A2 | Arène courante visible | Image de l'arène + nom + trophées au centre | Illustration de l'arène au centre | — |
| A3 | Coffres lisibles | Les emplacements de coffres et leur état (vide, en cours, prêt) se lisent | 4 emplacements, état et minuterie visibles | — |
| A4 | Soldes lisibles | Pièces, gemmes, trophées en haut, chiffres complets | Barre de ressources en haut | — |
| A5 | Barre d'onglets claire | 5 onglets avec icône, onglet actif mis en avant | Barre d'onglets en bas, actif plus grand | — |
| A6 | Aucun texte sur un autre ni coupé | Contrôle visuel | Zéro recouvrement, zéro « … » | — |
| A7 | Style cohérent | Mêmes boutons (lèvre, contour), mêmes polices, même palette | Une seule identité graphique | — |

### 5. BOUTIQUE (`boutique`)

| # | Critère observable | Mesure sur la capture | 10/10 (réf. CR) | Départ |
|---|---|---|---|---|
| S1 | Titre dégagé | Le titre de l'écran n'est recouvert par rien (ex. « Il te manque N pieces ») | Titre seul sur sa ligne | — |
| S2 | Offres en grille régulière | Cartes d'offre alignées, même taille, même marge | Grille propre, offre du jour mise en avant | — |
| S3 | Prix lisible sur chaque offre | Prix + icône de monnaie sur chaque offre | Prix dans un bouton vert | — |
| S4 | Aucun texte coupé en « … » | Nom, description, prix de chaque offre entiers | Zéro troncature | — |
| S5 | Visuel de chaque offre | Chaque offre montre son objet (carte, coffre, gemmes) | Illustration par offre | — |
| S6 | État d'achat clair | On voit ce qu'on peut acheter et ce qui est hors de prix, sans phrase posée par-dessus | Prix grisé/rouge si trop cher | — |

### 6. CARTES / deck (`cartes`)

| # | Critère observable | Mesure sur la capture | 10/10 (réf. CR) | Départ |
|---|---|---|---|---|
| C1 | Deck de 8 visible d'un bloc | Les 8 cartes du deck en 2 rangées de 4, sans défiler | Deck en haut, 2×4 | — |
| C2 | Carte lisible | Portrait, coût d'élixir, niveau de chaque carte lisibles | Portrait plein cadre + goutte + niveau | — |
| C3 | Rareté visible | Couleur de cadre par rareté (commune, rare, épique, légendaire) | Cadre coloré par rareté | — |
| C4 | Coût moyen affiché | Élixir moyen du deck lisible | « Coût moyen : 3,5 » | — |
| C5 | Collection séparée du deck | Les cartes hors deck sont visuellement séparées et lisibles | Section « Collection » dessous | — |
| C6 | Aucun texte coupé ni sur un autre | Noms de cartes entiers | Zéro « … », zéro recouvrement | — |

### 7. CLAN (`clan`)

| # | Critère observable | Mesure sur la capture | 10/10 (réf. CR) | Départ |
|---|---|---|---|---|
| L1 | Écran rempli | L'écran montre un contenu (clan, membres, ou appel à rejoindre), pas un vide | Liste de membres ou recherche de clan | — |
| L2 | Titre et identité du clan | Nom, blason, trophées du clan lisibles | En-tête de clan avec blason | — |
| L3 | Liste lisible | Chaque ligne : nom, rôle, trophées, sans troncature | Lignes alignées, colonnes nettes | — |
| L4 | Action principale évidente | Un bouton clair (rejoindre, demander des cartes, discuter) | Un bouton principal | — |
| L5 | Aucun texte coupé ni sur un autre | Contrôle visuel | Zéro « … », zéro recouvrement | — |
| L6 | Style cohérent avec les autres onglets | Mêmes boutons, mêmes polices | Même identité que BATAILLE | — |

### 8. ÉVÉNEMENTS (`evenements`)

| # | Critère observable | Mesure sur la capture | 10/10 (réf. CR) | Départ |
|---|---|---|---|---|
| E1 | Écran rempli | Au moins un événement présenté (pas un vide) | Bannières d'événements | — |
| E2 | Événement illustré | Chaque événement a une image, un titre, une règle en une ligne | Bannière illustrée | — |
| E3 | Durée visible | Temps restant ou date de fin lisible | Minuterie par événement | — |
| E4 | Récompense visible | Ce qu'on gagne est montré (icône + quantité) | Récompenses en icônes | — |
| E5 | Bouton d'entrée évident | Un bouton « Jouer » par événement | Bouton jaune | — |
| E6 | Aucun texte coupé ni sur un autre | Contrôle visuel | Zéro « … », zéro recouvrement | — |

### 9. Tutoriel (`tuto`)

| # | Critère observable | Mesure sur la capture | 10/10 (réf. CR) | Départ |
|---|---|---|---|---|
| T1 | Consigne courte et lisible | Une seule consigne, ≤ 2 lignes, lisible | Bulle courte | — |
| T2 | Geste montré | Main/flèche qui montre quoi glisser et où | Main animée de la carte vers la case | — |
| T3 | Cible visible dans l'arène | La zone où poser est marquée | Case en surbrillance | — |
| T4 | Le reste ne parasite pas | Pas d'autre bannière, ni debug, ni liste concurrente | Seul le tutoriel parle | — |
| T5 | Consigne hors du jeu utile | La bulle ne cache ni la main de cartes ni la cible | Bulle dans une zone vide | — |
| T6 | Mêmes critères d'arène que la bataille | D1 et D2 appliqués à l'arène du tutoriel | Arène lisible, tours reconnaissables | — |

## Note de départ par écran

| Écran | Capture | Note de départ |
|---|---|---|
| Bataille — début | `captures/lot1-bataille-debut.png` | **non mesurée** — Studio déconnecté |
| Bataille — mêlée | `captures/lot1-bataille-melee.png` | **non mesurée** |
| Fin de partie | `captures/lot1-fin.png` | **non mesurée** |
| Accueil (BATAILLE) | `captures/lot1-accueil.png` | **non mesurée** (code 5 au 1er essai) |
| BOUTIQUE | `captures/lot1-boutique.png` | **non mesurée** |
| CARTES / deck | `captures/lot1-cartes.png` | **non mesurée** |
| CLAN | `captures/lot1-clan.png` | **non mesurée** |
| ÉVÉNEMENTS | `captures/lot1-evenements.png` | **non mesurée** |
| Tutoriel | `captures/lot1-tuto.png` | **non mesurée** |

## Défauts à reconfirmer (top 15 non classé : sans capture, l'impact ne se mesure pas)

Ce qui est **prouvé par le code** est marqué « code » ; le reste vient d'anciennes captures et
reste une hypothèse jusqu'à la nouvelle mesure. Les places 9 à 15 se remplissent après les captures.

| # | Défaut | Preuve actuelle | Lot | Critères |
|---|---|---|---|---|
| 1 | Ping « -- ms » affiché pendant la partie | code : `src/client/GameClient.client.lua:1740` (création), `:2795` (visible dès que la partie tourne) | A | D6, M8 |
| 2 | Liste « Il a pose : » affichée pendant la partie | code : `src/client/GameClient.client.lua:1596` | A | D6, M8 |
| 3 | Bannière « … VA TOMBER ! » posée sur le score | texte : `src/shared/Lecture.lua:162` ; recouvrement vu sur ancienne capture | A | M7, M8 |
| 4 | Bataille sombre | ancienne capture ; réglages dans `src/server/GameServer.server.lua:306-312` (heure par thème, `Brightness` 2.4, `OutdoorAmbient` 120,130,150) | B | D1 |
| 5 | Tours en blocs surmontés de ronds blancs | ancienne capture | B | D2 |
| 6 | Unités minuscules | ancienne capture ; à mesurer en cases (M1) | B | M1, M2 |
| 7 | « Il te manque N pieces pour la moins chere » posé sur le titre de la boutique | texte : `src/shared/Collection.lua:123` ; recouvrement vu sur ancienne capture | D | S1, S6 |
| 8 | Textes coupés en « … » dans les cartes de la boutique | code : `src/client/Hub.client.lua:1109-1116` — le résumé d'effet de chaque tuile est en 11 px, une ligne, tronqué en « … » **volontairement** (« la fiche dit le reste ») ; vu sur ancienne capture | D | S4, C6 |
| 9–15 | à établir sur les captures du protocole ci-dessous | — | — | — |

## Protocole de capture (à rejouer après reconnexion de Studio)

Règles : une capture à la fois (le script tient un verrou de connexion, et plusieurs Studio en même
temps déconnectent le poste) ; jamais la place partagée en direct ; jamais fermer un Studio qu'on
n'a pas lancé. Code 5 = Studio déconnecté : s'arrêter.

| Écran | Drapeaux `build.py --autotest …` | `-Secondes` | La photo doit montrer |
|---|---|---|---|
| bataille-debut | `--partie --capture-delai=8` | 45 | arène et main au coup d'envoi |
| bataille-melee | `--melee` | 60 | robots en rafale, photo à 25 s |
| fin | `--partie --court --capture-delai=45` | 75 | écran de fin (partie de 25 s en mode court ; si la photo montre encore la partie — prolongation —, monter le délai) |
| accueil | `--hub --onglet=bataille` | 45 | menu, onglet BATAILLE, photo à 12 s |
| boutique | `--boutique` | 60 | boutique ouverte, photo à 25 s |
| cartes | `--deck` | 60 | écran DECK |
| clan | `--hub --onglet=clan` | 45 | onglet CLAN |
| evenements | `--hub --onglet=evenements` | 45 | onglet ÉVÉNEMENTS |
| tuto | `--tuto` | 60 | une étape du tutoriel |

Pour chaque écran : construire, copier aussitôt sous un nom privé, vérifier que la copie porte bien
NOS drapeaux (un autre lot peut reconstruire la place partagée entre les deux), puis capturer :

```bash
cd /d/BrainRotRoyale
ecran=accueil; sec=45; set -- --hub --onglet=bataille   # une ligne du tableau
python build.py --autotest "$@"
cp BrainRotRoyale.autotest.rbxlx captures/lot1-$ecran.rbxlx
grep -o 'name="Name">BRR_[A-Z_a-z]*' captures/lot1-$ecran.rbxlx | sed 's/.*>//' | sort -u   # attendu ci-dessous
powershell -NoProfile -File tools/studio-capture-moteur.ps1 -Place captures/lot1-$ecran.rbxlx \
  -Id lot1-$ecran -Secondes $sec -Output captures/lot1-$ecran.png; echo "CODE=$?"
```

Drapeaux attendus dans la copie (mesurés le 2026-10-29), en plus de `BRR_AUTOTEST BRR_Capture BRR_JOUEURS` :
bataille-debut `BRR_CAP_DELAI BRR_PARTIE` · bataille-melee `BRR_MELEE BRR_PARTIE` ·
fin `BRR_CAP_DELAI BRR_COURT BRR_PARTIE` · accueil/clan/evenements `BRR_HUB BRR_ONGLET` (valeur =
l'onglet) · boutique `BRR_BOUTIQUE BRR_HUB` · cartes `BRR_DECK BRR_HUB` · tuto `BRR_TUTO`.
