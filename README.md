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
| Bombombini Gusini | 4 | Oie-bombardier volante, zone |
| Cocofanto Elefanto | 5 | Tank lourd |
| Burbaloni Luliloli | 3 | Encaisseur bon marche |
| Bananita Dolfinita | 2 | Tireuse rapide et fragile |
| Giraffa Celeste | 5 | Portee record, 15 studs (900 pieces) |
| Zibra Zubra Zibralini | 3 | x2 charges rapides |
| Orcalero Orcala | 4 | Melee solide |
| Los Tralaleritos | 4 | x3 petits requins |
| Nuclearo Dinossauro | 6 | Colosse, zone (1500 pieces) |
| Frulli Frulla | 3 | Volant rapide, harceleur |
| Spaghettino Malfunziono | 3 | Distance moyenne |
| Trulimero Trulicina | 2 | x2 harceleurs tres rapides |
| Brri Brri Bicus Dicus | 4 | Volant frappeur (600 pieces) |
| Pizza Bombarda | 4 | SORT : explosion en zone |
| Freccine Spaghetti | 3 | SORT : volee large |
| Furia Brainrot | 2 | SORT : rage sur tes unites (400 pieces) |

**21 cartes offertes** des le depart pour **8 places** de deck : un joueur neuf peut deja composer
203 490 decks differents, et chaque carte achetee (7 payantes : Bombardiro 500, Brri Brri Bicus Dicus 600,
Tigrullini 700, Patapim 800, Giraffa 900, Vacca 1200, Nuclearo 1500) elargit le choix. `tools/test_catalogue.py`
garde cet invariant : si le catalogue offert repasse sous 8 + 2 cartes, le banc vire au rouge.

Equilibrage : `src/shared/Cards.lua`, mesure par `python tools/test_equilibre.py` — duels
DEUX A DEUX a elixir egal, avec les regles de combat de `GameServer` (portee, vitesse, zone,
`canHit`). Chaque paire se rencontre deux fois, chacune une fois en DEFENSE : sans cela la portee
ne sert a rien et les tireurs paraissent inutiles. Le banc vire au rouge si une carte gagne plus
de 70 % ou moins de 30 % de ses duels. Les cartes anti-tours (`targets = "buildings"`) ne peuvent
viser aucune unite : elles sont jugees a part, sur les PV de tour arraches par elixir.
Etat au 2026-09-20 (28 cartes) : toutes les cartes entre **31 % et 69 %**, anti-tours dans un rapport de 1,6.
Limites : combat en ligne, sans tours ni ponts ni cycle de cartes — le banc dit qui gagne un
echange, pas qui gagne une partie. Le contre-controle en conditions reelles reste
`build.py --autotest --run --sim="1-1:8;1-3:8"` (mesure du 2026-09-16 : 4-4 a niveaux egaux,
7-1 pour le camp de niveau 3). Les unites sont des blocs colores : remplace-les par des modeles 3D (Toolbox) pour le visuel.

## Regles de partie (src/shared/Regles.lua)
Fonctions PURES, verifiees hors Studio par `python tools/test_regles.py` :
- **Double elixir** dans le dernier TIERS du temps (60 s sur 180), **triple** en prolongation. La
  jauge change de couleur et une banniere l'annonce ; sans elle, le rythme changeait sans que
  personne ne le voie.
- **Prolongation** : une egalite de couronnes au chrono ne rend plus un match nul — on joue un
  tiers de temps de plus, la PREMIERE tour prise gagne, et si personne ne marque, c'est la tour la
  plus entamee qui perd. Seule une egalite PARFAITE reste nulle.
- **Zone de pose elargie** : casser une tour de cote ouvre la moitie adverse DE CE COTE. Une tour
  prise vaut desormais un avantage de terrain, pas seulement une couronne.
- **Anti-aerien du robot** : `Regles.peutViserVolant` — avec un volant sur le dos, le robot choisit
  d'abord une carte capable de le toucher, au lieu de poser une melee qui ne peut rien faire.
- Meme module cote CLIENT : il refusait les clics avec un test ecrit en dur pour le camp 1
  (`z > -3`), ce qui empechait le joueur du camp 2 de poser la moindre carte en duel humain.

## Sorts (src/shared/Sorts.lua)
Trois cartes ne posent AUCUNE unite : elles frappent une zone, n'importe ou dans l'arene, y
compris chez l'ennemi. C'etait le manque le plus visible du jeu — un paquet serre de petites
unites n'avait aucune reponse, et une tour presque morte ne pouvait pas etre achevee de loin.

| Sort | Cout | Effet |
|---|---|---|
| Pizza Bombarda | 4 | 340 degats, rayon 4,5 |
| Freccine Spaghetti | 3 | 165 degats, rayon 7 (large) |
| Furia Brainrot | 2 | +35 % vitesse et cadence a TES unites, 7 s, rayon 6 (400 pieces) |

Regles (pures, `python tools/test_sorts.py`) : un sort vise toute l'arene mais pas au-dela des
bords ; il epargne les allies (la rage, elle, ne touche QUE les allies, et jamais les tours) ; une
TOUR n'encaisse que 35 % des degats d'un sort, sinon deux sorts suffisaient a la raser sans jamais
attaquer ; la rage s'arrete NET a la fin de sa duree. Le robot vise le centre du paquet ennemi le
plus fourni, ou ses propres unites pour la rage.

## Difficulte du robot (src/shared/Robot.lua)
Sa FORCE suivait deja le joueur (`Economie.niveauRobot` monte le niveau de ses cartes), mais son
COMPORTEMENT etait le meme a 0 trophee et a 3000 : meme temps de reaction, aucune erreur, des la
premiere partie. Monter la puissance sans toucher au comportement rend le jeu plus dur sans le
rendre plus interessant — et decourage qui commence.

Quatre paliers, deduits des trophees du joueur d'EN FACE :

| Trophees | Palier | Reflexion | Erreurs | Attaque a |
|---|---|---|---|---|
| 0 – 199 | debutant | 3,2 s | 40 % | 9 elixir (tardif) |
| 200 – 599 | normal | 2,4 s | 22 % | 8 elixir |
| 600 – 1199 | aguerri | 1,7 s | 10 % | 7 elixir |
| 1200 + | expert | 1,1 s | 0 % | 6 elixir (agressif) |

Ce que « erreur » veut dire : le robot pose une carte AU HASARD parmi celles qu'il peut payer, au
lieu de la meilleure. Et seul un robot au-dessus du palier debutant pense a repondre aux volants.
Garanties tenues par le banc : difficulte MONOTONE (plus de trophees ne rend jamais le robot plus
facile), valeurs BORNEES (jamais inerte, jamais surhumain), et des trophees absents, negatifs ou
illisibles retombent sur le palier le plus tendre.
**CONTRE-ATTAQUE** : le robot defendait bien mais ne punissait jamais — une fois l'attaque
repoussee, il retournait a sa garde alors que l'adversaire venait de vider son elixir. Il relance
desormais dans la voie qu'il vient de defendre, a quatre conditions, toutes verifiees au banc :
une menace REELLE repoussee (>= 150 PV), des SURVIVANTS pour accompagner, dans une fenetre de
**6 secondes**, et assez d'elixir en gardant **1 en reserve**. Un robot de palier debutant ne
contre-attaque jamais.

Banc : `python tools/test_robot.py` (37 cas). En partie, le journal ecrit
`[BOT] camp=2 difficulte=debutant (trophees=0)` et, lors d'une relance,
`raison=contre_attaque_voie2`.
**OUVERTURE** : pendant le premier TIERS du temps, un robot qui sait economiser exige **+2 elixir**
avant d'ouvrir — il laisse l'adversaire s'engager le premier. La defense n'est jamais bridee, et le
seuil est plafonne a 10 (au-dela, le robot n'attaquerait plus jamais). Mesure en moteur (palier
expert) : il REFUSE a 7,7 pendant l'ouverture et joue a 8,2 (seuil 6 + 2) ; une fois l'ouverture
passee, il joue a **6,0**.

**ERREUR DE PLACEMENT** : la faute la plus courante d'un debutant n'est pas de choisir la mauvaise
carte, c'est de la poser au mauvais endroit. L'ecart de pose suit le palier — **6 studs** pour un
debutant, 3 pour un normal, 1,5 pour un aguerri, **0** pour un expert. La deviation est CENTREE
(aucun biais : il ne rate pas toujours du meme cote) et la pose reste dans sa moitie.
Mesure en moteur, ecart au pont le plus proche : **expert 1,1 a 1,6 de moyenne (max 2)** — soit le
hasard de base, sans deviation ; **debutant 2,5 a 3,7 de moyenne (max 7)**.
A savoir en lisant ces chiffres : une pose de SORT ne vise pas un pont mais le centre du paquet
ennemi, elle sort donc legitimement de cette fourchette.

Crochet de test : `python build.py --autotest --robot=expert` force un palier, pour observer en
moteur un comportement que les trophees d'un joueur neuf ne declenchent jamais.

## Charge : l'elan fait mal (src/shared/Charge.lua)
Avant : une unite de melee frappait **exactement pareil** qu'elle vienne de traverser l'arene ou
qu'elle soit posee au contact. Aucune raison de lancer une unite de loin, et aucune parade a lui
opposer en route.

Desormais, trois cartes prennent de l'**elan** : **Bobritto Bandito** (10 studs, x2),
**Tigrullini Watermelini** (12 studs, x2,2) et **Cocofanto Elefanto** (14 studs, x2,5). Tant que
l'unite court sans s'arreter, son compteur monte ; une fois la distance atteinte elle **accelere**
(x1,4 a x1,6) et son **premier** coup est majore. Apres ce coup, tout repart de zero.

La parade est la contrepartie exacte : **une seule image d'arret efface toute la charge**. Un mur,
un squelette, n'importe quoi qui la bloque lui vole son elan — et une unite freinee par la foule
met plus du double d'images a se lancer. Les cartes concernees sont declarees dans le module, pas
dans le catalogue : c'est une regle de combat, pas une propriete de carte.

Mesure en moteur (partie du 2026-09-20) : `[CHARGE] Cocofanto Elefanto lancee apres 14 studs,
coup a 450 au lieu de 180`. Banc : `tools/test_charge.py` (46 cas, dont une simulation image par
image a 30 im/s).

## Ciblage : menace et persistance (src/shared/Cible.lua)
Deux defauts mesures dans l'ancien `findTarget` :
- **aucune persistance** — la cible etait recalculee a chaque image. Deux ennemis a distance
  presque egale faisaient PAPILLONNER la tour : elle repartageait ses degats sans jamais achever
  personne. Mesure du banc : sur **100 images** d'oscillation de +/- 0,4 stud, l'ancien choix
  changeait de cible sans arret ; le nouveau : **0 changement**.
- **aucune notion de menace** — seule la distance comptait, donc une unite ANTI-TOURS fonçant sur
  la tour passait apres n'importe quel passant plus proche d'un demi-stud.

Les deux regles, pures :
- une **TOUR** compte une unite anti-tours comme **6 studs plus proche** (`BONUS_ANTI_TOUR`) : a
  distance comparable, c'est elle qu'on abat d'abord — mais un anti-tours vraiment loin ne passe
  pas devant un ennemi au contact ;
- une **UNITE** ne raisonne pas en menace : elle frappe ce qu'elle a devant, comme avant ;
- on ne change de cible que si la nouvelle est meilleure de **3 studs** (`MARGE_CHANGEMENT`).
Banc : `python tools/test_cibles.py` (21 cas, dont la mesure du papillonnage sur 100 images).

## Foule : les unites ne se traversent plus (src/shared/Foule.lua)
Avant, deux unites pouvaient occuper EXACTEMENT le meme point : un groupe de trois se fondait en
une seule silhouette, et « faire barrage » — la defense de base du genre — ne voulait rien dire
puisque rien ne bloquait rien.

Choix assume : AUCUNE physique Roblox (tout est ancre et deplace a la main ; y toucher casserait
l'animation et la replication). On calcule une POUSSEE de separation, en fonctions pures :
- chaque unite qui en chevauche une autre est repoussee le long de l'axe qui les separe, d'autant
  plus fort que le chevauchement est grand ;
- la poussee est **bornee a 6 studs/s** : une unite coincee entre deux autres ne se teleporte pas ;
- deux unites posees au MEME point partent en sens opposes (depart d'egalite par identifiant, sinon
  elles tremblent sur place) ;
- un **volant** ne gene que les volants ; une **tour** encombre tout le monde au sol, ne recule
  jamais, et laisse passer les volants ;
- genee de toutes parts, une unite **ralentit** (jusqu'a 35 % de sa vitesse) au lieu de pousser
  indefiniment : c'est ce qui donne une file qui avance et un mur qui retient.
La separation est calculee APRES tous les deplacements de l'image, pour que l'ordre des unites
dans la liste ne change pas le resultat.
Banc : `python tools/test_foule.py` (27 cas). Capture : `capture-foule-melee.png`.

## Apercu de pose (src/shared/Apercu.lua)
Tant qu'une carte est choisie, la visee MONTRE ce qui va se passer, au lieu de le decouvrir apres
le clic :
- un **disque au sol** suit le curseur, **VERT** si la pose passe, **ROUGE** sinon — meme regle que
  le serveur (`Regles.posePermise`), donc ce qui est vert est reellement accepte ;
- son **rayon** est la vraie mesure : l'emprise de l'unite (elargie pour un groupe), et pour un
  SORT son **rayon d'effet exact** — on voit ce qu'on va toucher avant de lacher ;
- un **fantome transparent** reprend la silhouette de la carte, pose au SOL, a la couleur du disque.
Tout est LOCAL au client : rien n'est replique, l'adversaire ne voit pas ou l'on hesite.
Banc : `python tools/test_apercu.py` (28 cas, sur le vrai catalogue).
Capture : `python build.py --autotest --apercu` fige la visee a un point fixe de la moitie du
joueur — sans utilisateur, la souris ne pointe jamais l'arene et l'apercu n'apparaitrait sur aucune
image.

## Raretes
Chaque carte porte une rarete DEDUITE de son prix (offerte = commune, < 800 = rare, < 1200 =
epique, au-dela = legendaire). Elle colore le cadre des tuiles en main, en boutique et dans le
deck. Rien a maintenir : une carte payante ajoutee se classe toute seule.

## Animations
Les pieces sont ANCREES (aucune physique, aucun Animator) : la pose est calculee a chaque image dans
`src/shared/Effets.lua` et appliquee par `animer` (GameServer). Chaque carte recoit une DEMARCHE
deduite de ses propres chiffres — donc aucune carte ne peut etre oubliee (`Effets.style`) :

| Style | Qui | Ce qu'on voit |
|---|---|---|
| vol | `flying` | flotte sans jamais poser pied, s'incline, plane meme a l'arret |
| bond | groupes rapides (`count >= 2`, vitesse >= 12) | saut ample, tangage marque |
| lourd | gros PV (>= 1800) ou tres lents (<= 6) | pas pesant, large roulis, peu de rebond |
| tir | longue portee (>= 9) | reste stable et RECULE a chaque tir au lieu de charger |
| marche | le reste | rebond et dandinement d'origine |

Deux moments s'ajoutent a la demarche : l'ARRIVEE (`Effets.apparition`, l'unite tombe de 9 studs et
rebondit pendant 0,45 s apres la pose — elle retombe exactement a sa place, aucune derive) et
l'AGONIE (`Effets.agonie`, l'unite abattue bascule, s'enfonce et s'efface en 0,45 s au lieu de
disparaitre d'un coup ; elle est deja hors du combat, l'equilibrage ne bouge pas).

Banc : `python tools/test_animations.py` — verifie que chaque carte a un style connu, que les cinq
styles donnent des poses differentes, qu'un volant plane a l'arret, que l'arrivee revient a zero et
que le corps abattu est bien detruit. Ces defauts-la ne cassent aucun autre test : ils ne se voient
qu'a l'ecran.

**CHIFFRES DE DEGATS** : chaque coup fait monter au-dessus de la cible ce qu'il enleve (« -95 »),
a la couleur du camp qui ENCAISSE. La taille du chiffre suit le montant, entre 16 et 42, plafonnee
a 250 de degats pour qu'un sort n'ecrase pas l'ecran. Au plus 25 chiffres par seconde en tout
(`Effets.limiteurChiffres`) : sans ce frein, une melee en produisait un par coup et par unite.
Banc : `python tools/test_degats.py` (24 cas).
LIMITE D'OUTILLAGE, pas de jeu : ces chiffres sont des `BillboardGui`, et `CaptureService` ne les
rend PAS — c'est pourquoi aucune capture de ce depot ne montre non plus les barres de vie ni les
noms d'unites, pourtant bien presents en jeu (deja mesure le 2026-09-14, voir GameServer:472).

## Syntaxe (garde-fou le moins cher du depot)
`python tools/test_syntaxe.py` compile TOUS les fichiers Lua de `src/` sans lancer Studio (les
constructions Luau `+=`, `-=` et `continue` sont traduites avant compilation). Mesure du
2026-09-20 : une edition automatique avait insere un vrai saut de ligne au milieu d'une chaine ;
ce banc l'a vu en une seconde, la ou Studio l'aurait montre plusieurs minutes plus tard.

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
   - **Places** : nombre max de joueurs par serveur = **6**. Les deux premiers arrivants prennent
     les camps, les suivants sont SPECTATEURS (chat, emotes, pronostic Rouge/Bleu a +15 pieces).
     Le mettre a 2 eteindrait tout le mode spectateur, qui est code et teste.
   - **Securite** : laisser « Autoriser les requetes HTTP » desactive (inutile ici).
4. Remplir la fiche : icone 512x512, miniature 1920x1080 (une capture de la voie de secours convient).
5. Tester : lancer le jeu depuis la page Roblox sur deux comptes / deux appareils.

Limite connue : les « vrais » modeles Brainrot sont des creations d'autres auteurs du catalogue ;
les personnages du jeu sont sculptes dans le code (aucun asset externe a importer).

## Robot (adversaire hors ligne)
- Deux robots coexistent : l'ALEATOIRE (temoin historique) et le REACTIF, qui defend la voie
  attaquee, garde son elixir et frappe la tour ennemie la plus faible. Mesure du 2026-09-18, deux
  series independantes de 20 parties (`sim-v20.log`, `sim-v20-seuil7.log`) : le reactif gagne
  **16 fois sur 20**. C'est donc lui qui joue contre les joueurs ; l'aleatoire ne sert plus que de
  temoin dans la simulation `--sim="v:N"`.
- **Paquet du robot** : celui du joueur d'EN FACE, sinon les seules cartes OFFERTES. Sans cette
  regle il tirait dans tout le catalogue et sortait des cartes a 1500 pieces contre un joueur neuf.
  Banc : `python tools/test_robot_deck.py`.

## Hub, boutique et monetisation

- **Hub** : a l'arrivee, ecran d'accueil (profil, JOUER, BOUTIQUE, BONUS DU JOUR). Le joueur ne prend
  un camp qu'en appuyant sur JOUER ; MENU le ramene au hub et rend son camp au robot.
- **Profil** (`src/server/Economie.lua`) : pieces, trophees, victoires, cartes debloquees, bonus du jour.
  Sauvegarde Roblox DataStore. Classement visible dans la liste des joueurs (Trophees, Pieces).
- **Recompenses** : victoire +30 pieces +30 trophees, defaite +10 / -15, egalite +15 / 0. Bonus du jour +50.
- **Serie de victoires** : +10 pieces par victoire enchainee au-dela de la premiere, plafonnee a
  5 (soit +50). Une defaite ou une egalite remet la serie a zero. Banc : `tools/test_serie.py`.
- **Quetes du jour** : 3 quetes tirees du numero du jour (memes quetes pour tout le monde, rien a
  sauvegarder cote serveur) — gagner des parties, poser des cartes, detruire des tours, lancer des
  sorts. Elles paient 50 a 80 pieces, se reclament une seule fois, et repartent a zero au
  changement de jour. Le serveur compte l'avancee lui-meme ; le client ne fait que demander.
- **Coffre gratuit** toutes les **4 h** (coffre d'argent), refuse si les 4 emplacements sont pleins.
  C'est le rendez-vous COURT qui fait revenir dans la journee, la ou le bonus quotidien n'en donne
  qu'un par jour. Les deux s'affichent dans l'onglet EVENEMENTS du hub.
  Banc : `python tools/test_quetes.py` (36 cas).
- **Boutique** : 7 cartes a debloquer (Bombardiro 500, Bicus 600, Tigrullini 700, Patapim 800,
  Giraffa 900, Vacca 1200, Nuclearo 1500) ; les 21 autres sont offertes.
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
  `tools/test_recus.py` (achats Robux + ecritures regroupees), `tools/test_robot_deck.py` (paquet du
  robot). Ces bancs demandent `pip install lupa`. `tools/harnais_economie.py` n'est PAS un banc :
  c'est le prelude Lua partage (il s'appelait test_economie_lib.py et passait pour un test muet).

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
  le catalogue est passe a 28 cartes dont 21 offertes pour que l'ecran ait quelque chose a decider.
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
