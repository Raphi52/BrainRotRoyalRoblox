# Brainrot Royale

Clash Royale-like pour Roblox Studio, cartes Italian Brainrot. En ligne : JOUER cherche un adversaire (file partagee entre serveurs, un serveur reserve par match) ; robot si personne apres 20 s. Dans Studio : joueur contre bot.

## Ouvrir
1. Double-cliquer `BrainRotRoyale.rbxlx` (ou Studio > Fichier > Ouvrir).
2. Bouton **Play** (F5).
3. Cliquer une carte, puis cliquer sur ta moitie d'arene (en bas) pour la poser.

Apres modification de `src/`, regenerer : `python build.py`.
(Avec Rojo : `rojo serve` utilise `default.project.json`.)

## Regles
- Elixir : 5 au depart, max 10, +1 toutes les 2,8 s.
- 3 tours par camp ; le Roi s'active quand il est touche ou qu'une tour tombe.
- Roi detruit = victoire (3 couronnes). Sinon, apres 3:00, plus de couronnes gagne.

## Cartes
| Carte | Cout | Role |
|---|---|---|
| Tralalero Tralala | 3 | Melee rapide |
| Bombardiro Crocodilo | 5 | Volant, zone, vise les tours |
| Tung Tung Tung Sahur | 4 | Melee zone |
| Brr Brr Patapim | 5 | Tank, vise les tours |
| Cappuccino Assassino | 2 | Assassin rapide |
| Chimpanzini Bananini | 3 | x3 petits |
| Lirili Larila | 3 | Distance |
| Ballerina Cappuccina | 2 | Distance legere |
| Bobritto Bandito | 3 | Melee solide |
| Trippi Troppi | 2 | x2 harceleurs rapides |
| Boneca Ambalabu | 4 | Tank, vise les tours |
| Glorbo Fruttodrillo | 4 | Distance, zone |
| Frigo Camelo | 5 | Mur qui riposte de loin |
| Tigrullini Watermelini | 4 | Tireur longue portee (700 pieces) |
| La Vacca Saturno Saturnita | 6 | Volante, zone, vise tout (1200 pieces) |

**11 cartes offertes** des le depart pour **8 places** de deck : un joueur neuf peut deja composer
165 decks differents, et chaque carte achetee (4 payantes) elargit le choix. `tools/test_catalogue.py`
garde cet invariant : si le catalogue offert repasse sous 8 + 2 cartes, le banc vire au rouge.

Equilibrage : `src/shared/Cards.lua`, mesure par `python tools/test_equilibre.py` — duels
DEUX A DEUX a elixir egal, avec les regles de combat de `GameServer` (portee, vitesse, zone,
`canHit`). Chaque paire se rencontre deux fois, chacune une fois en DEFENSE : sans cela la portee
ne sert a rien et les tireurs paraissent inutiles. Le banc vire au rouge si une carte gagne plus
de 70 % ou moins de 30 % de ses duels. Les cartes anti-tours (`targets = "buildings"`) ne peuvent
viser aucune unite : elles sont jugees a part, sur les PV de tour arraches par elixir.
Etat au 2026-09-16 : toutes les cartes entre **32 % et 68 %**, anti-tours dans un rapport de 1,6.
Limites : combat en ligne, sans tours ni ponts ni cycle de cartes — le banc dit qui gagne un
echange, pas qui gagne une partie. Le contre-controle en conditions reelles reste
`build.py --autotest --run --sim="1-1:8;1-3:8"` (mesure du 2026-09-16 : 4-4 a niveaux egaux,
7-1 pour le camp de niveau 3). Les unites sont des blocs colores : remplace-les par des modeles 3D (Toolbox) pour le visuel.

## Test automatique (sans toucher l'ecran)
`python build.py --autotest` puis `powershell -ExecutionPolicy Bypass -File tools/studio-run-cache.ps1 -Secondes 200`
Studio s'ouvre sur un bureau Windows cache ; un plugin temporaire (`tools/BRR_AutoRun.lua`, retire a la fin) lance **Play**
via `StudioTestService:ExecutePlayModeAsync`. Le client de test lit l'interface, sonde ou tombe chaque point de l'ecran
dans l'arene et pose des cartes par le vrai chemin du clic ; tout est ecrit en lignes `[BRR]` dans le journal Studio.
(Sans joueur, en mode Run, le serveur fait jouer bot contre bot.)

## Capture 3D

### Voie par defaut : le moteur capture lui-meme (rien sur l'ecran)
`python build.py --autotest` puis
`powershell -ExecutionPolicy Bypass -File tools/studio-capture-moteur.ps1` : Studio tourne dans un
bureau Windows CACHE, la partie se lance seule, et le script client `tools/BRR_Capture.client.lua`
(copie de test uniquement) demande l'image au moteur via `CaptureService:CaptureScreenshot`. Studio
l'ecrit dans `%LOCALAPPDATA%\Roblox	mp-capture-storage`, le script la copie dans
`capture-moteur.png` et compte ses couleurs (1 = rate, plusieurs centaines = vue rendue).
**Aucune fenetre n'apparait sur l'ecran de l'utilisateur.** Mesure du 2026-09-14 : 592x1348,
823-838 couleurs.

Une limite : l'image est la vue du JEU seule, sans l'interface de Studio. Son FORMAT suit celui de
la session d'affichage (mesure du 2026-09-14 : session Bureau a distance en portrait -> image
592x1348 ; la meme session en paysage -> 1296x930). Ce n'est pas le bureau cache qui l'impose.

### Voie de secours : hors de la zone visible, avec l'interface de Studio
`powershell -ExecutionPolicy Bypass -File tools/studio-capture-3d.ps1` : Studio tourne sur le
bureau REEL, hors ecran, et `capture-3d.png` montre toute la fenetre de Studio, en paysage. A
n'utiliser que s'il faut voir l'interface : il laisse ~17 ms de fenetre de chargement peinte sur
l'ecran de l'utilisateur (voir D:\AutoWinOS\scripts\hors-ecran-capture.ps1).

## Mettre le jeu en ligne (a faire avec TON compte Roblox)

Le code gere deja deux joueurs par serveur (camp 1, camp 2, bot sur le camp vide, spectateurs).
La publication engage ton compte : elle se fait a la main dans Studio.

1. Ouvrir `BrainRotRoyale.rbxlx` dans Roblox Studio (la version normale, PAS `.autotest`).
2. `Fichier > Publier sur Roblox` : creer une nouvelle experience, nom « Brainrot Royale ».
3. `Accueil > Parametres du jeu` :
   - **Autorisations** : Public (ou Prive pour tester entre amis).
   - **Places** : nombre max de joueurs par serveur = **2** (au-dela, les arrivants sont spectateurs).
   - **Securite** : laisser « Autoriser les requetes HTTP » desactive (inutile ici).
4. Remplir la fiche : icone 512x512, miniature 1920x1080 (une capture de la voie de secours convient).
5. Tester : lancer le jeu depuis la page Roblox sur deux comptes / deux appareils.

Limite connue : les « vrais » modeles Brainrot sont des creations d'autres auteurs du catalogue ;
les personnages du jeu sont sculptes dans le code (aucun asset externe a importer).

## Hub, boutique et monetisation

- **Hub** : a l'arrivee, ecran d'accueil (profil, JOUER, BOUTIQUE, BONUS DU JOUR). Le joueur ne prend
  un camp qu'en appuyant sur JOUER ; MENU le ramene au hub et rend son camp au robot.
- **Profil** (`src/server/Economie.lua`) : pieces, trophees, victoires, cartes debloquees, bonus du jour.
  Sauvegarde Roblox DataStore. Classement visible dans la liste des joueurs (Trophees, Pieces).
- **Recompenses** : victoire +30 pieces +30 trophees, defaite +10 / -15, egalite +15 / 0. Bonus du jour +50.
- **Boutique** : Bombardiro (500) et Patapim (800) a debloquer ; les 6 autres sont offertes.
- **Achats Robux** : chaque `PurchaseId` honore est inscrit dans un DataStore dedie `BRR_Recus`.
  Roblox rappelle `ProcessReceipt` jusqu'a obtenir une reponse : sans cette trace, un rappel apres
  coup recreditait le joueur. L'achat n'est confirme (`PurchaseGranted`) que si le profil a
  REELLEMENT ete ecrit sur le disque ; sinon le credit est repris et la vente reste ouverte.
- **Ecritures regroupees** : les gestes ordinaires (recompense, coffre, niveau, achat en pieces,
  bonus, deck) marquent le profil « sale » (`Economie.marquerSale`) et une seule ecriture part au
  plus toutes les 30 s (`DELAI_ECRITURE`), plus une ecriture immediate au depart du joueur et a la
  fermeture du serveur. Roblox plafonne les `SetAsync` par cle : un ecrit par geste se faisait
  rejeter sous charge.
- **Tests** : `python build.py --autotest --ecotest` (19 cas, journal [ECOTEST]),
  `--hub` (accueil ouvert), `--boutique` (boutique ouverte), a capturer avec `tools/studio-capture-moteur.ps1`.
  Hors Studio (rapide, sans compte) : `python tools/test_economie.py`, `tools/test_deck.py`,
  `tools/test_recus.py` (achats Robux + ecritures regroupees). Ces bancs demandent `pip install lupa`.

### A faire avec TON compte (rien n'est vendu tant que ce n'est pas fait)
1. Publier le jeu (Fichier > Publier sur Roblox). Sans publication, la sauvegarde est refusee
   (« You must publish this place to the web to access DataStore »).
2. Parametres du jeu > Securite : cocher **Enable Studio Access to API Services** pour tester la sauvegarde dans Studio.
3. create.roblox.com > l'experience > Monetization :
   - creer 2 **Developer Products** (ex. 500 pieces, 1500 pieces) et reporter leurs identifiants dans
     `Economie.PRODUITS` ;
   - creer un **Game Pass** « VIP » (pieces x2) et reporter son identifiant dans `Economie.PASS_VIP`.
   Tant qu'un identifiant vaut 0, l'offre est masquee.

## Deck
- Le joueur compose un deck de **8 cartes** (`Economie.DECK_TAILLE`) parmi celles qu'il possede,
  via le bouton **DECK** de l'accueil. Le choix est garde dans son profil (`p.deckChoisi`).
- Le serveur ne croit jamais le client : `Economie.choisirDeck` refuse une taille differente de 8,
  un doublon, une carte inconnue ou une carte non possedee, et rend le motif du refus.
- Un deck deja sauvegarde est **reverifie a chaque chargement** : si une carte a disparu du
  catalogue, le deck est abandonne et le joueur rejoue avec toutes ses cartes, plutot que de se
  retrouver avec une main trouee.
- Tant que le joueur possede moins de 8 cartes, aucun choix n'est possible : il joue avec tout.
  C'etait le cas au depart (8 cartes au catalogue pour 8 places, vu a l'ecran le 2026-09-16) ;
  le catalogue est passe a 15 cartes dont 11 offertes pour que l'ecran ait quelque chose a decider.
- Les grilles de la boutique et du deck **defilent** (`grilleDefilante`, `Hub.client.lua`) : la mise
  en page ne depend plus du nombre de cartes.
- Tests : `python tools/test_deck.py`, `python tools/test_catalogue.py`.

## Coffres
- Chaque **victoire** donne un coffre s'il reste une place (**4 emplacements**). Tirage : bois 70 %, argent 25 %, or 5 %.
- Ouverture en attente, **une seule a la fois** : bois 15 min, argent 1 h, or 3 h (`Economie.COFFRES`).
- Contenu : pieces (bois 20-40, argent 60-100, or 150-250) et chance de debloquer une carte verrouillee
  (10 % / 35 % / 100 %) ; si tout est debloque, pieces supplementaires a la place.
- Tests : `--ecotest` (cas coffres inclus), `--coffres` (accueil avec un coffre dans chaque etat).

## Niveaux de cartes
- Niveau 1 a 5. Chaque niveau au-dessus de 1 : **+10 % de points de vie et de degats** (niveau 5 = +40 %).
- Passer au niveau suivant : **2 / 4 / 10 / 20 exemplaires** et **50 / 150 / 400 / 1000 pieces** (`Economie.EXEMPLAIRES`, `Economie.COUT_NIVEAU`).
- Les coffres donnent des exemplaires d'une carte debloquee : bois 3, argent 8, or 20.
- En partie, le bonus est celui du **joueur** qui tient le camp ; le robot reste niveau 1.
- Tests : `--ecotest` (cas niveaux inclus), `--niveaux` (boutique avec des niveaux varies).

## Niveau du robot et des tours
- Le robot joue toutes ses cartes au **niveau moyen du deck du joueur d'en face** (arrondi). Les trophees ne comptent plus.
- Les **tours** de chaque camp ont le niveau moyen des cartes de ce camp. Degats au multiplicateur simple, **PV au multiplicateur puissance 1,5** (x1,31 au niveau 3, x1,66 au niveau 5) ; une tour entamee garde sa proportion de PV.
- Duree mesuree (7 parties par niveau) : exposant 1 -> ~104 s aux niveaux 3/5 ; exposant 2 -> 160 s ; **exposant 1,5 -> 116 s / 122 s**, contre 112 s au niveau 1 (tools/sim-C, D, E).
- Mesure (tools/sim-C.txt) : a niveaux egaux 1, 3 et 5, 4 victoires sur 7 pour chaque serie.

## Simulation d'equilibre
`python build.py --autotest --run --sim="1-1:8;1-3:8"` puis `powershell -NoProfile -File tools/studio-capture-moteur.ps1 -Secondes 500`
(l'image manque, c'est normal : sans joueur, seul le journal compte). Parties robot contre robot a niveaux imposes,
temps x8, camp fort alterne ; une ligne [SIM] par partie. Resultats du 2026-09-14 : tools/sim-A.txt, tools/sim-B.txt.
