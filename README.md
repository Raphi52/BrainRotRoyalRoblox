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

## Temps d'arrivee : une unite ne frappe plus en tombant du ciel (src/shared/Deploiement.lua)
Defaut lu dans le code : `addEntity` posait `e.cooldown = 0`, et rien n'empechait une unite de se
deplacer des sa premiere image. Une carte posee **agissait instantanement**. Trois consequences,
toutes mauvaises :
- **aucun contre-jeu a la pose** — poser une unite au contact d'un ennemi le frappait avant qu'il
  puisse reagir, et l'adversaire ne pouvait rien y faire ;
- **le jeu mentait a l'oeil** — l'animation d'arrivee dure 0,45 s (l'unite tombe du ciel, touche
  le sol vers 0,25 s, rebondit) et pendant tout ce temps elle frappait deja. Une unite qui attaque
  alors qu'elle est encore en l'air, c'est ce que le joueur voyait ;
- **l'invulnerabilite de pose ne jouait que dans un sens** : elle protegeait une unite qui,
  elle, pouvait deja agir.

Une unite met desormais **0,45 s** avant de pouvoir frapper ou avancer. Cette duree n'est pas un
chiffre invente : c'est **exactement celle de l'animation d'arrivee**, pour que la regle et
l'image disent la meme chose. Le banc verifie que les deux restent egales — changer l'une sans
l'autre devient visible.

Point verifie explicitement : le deploiement (0,45 s) dure **plus longtemps** que
l'invulnerabilite de pose (0,35 s). Il reste donc **0,10 s** ou l'unite est vulnerable ET inerte —
sans cette fenetre, elle serait protegee pendant toute sa periode d'inaction et la regle
n'offrirait aucun contre-jeu. Les tours ne sont pas concernees.

Preuve en moteur : **155 unites** passees par le temps d'arrivee sur une melee, chacune 0,45 s,
zero erreur — et le depouillement de la partie reste entierement vert.
Banc : `tools/test_deploiement.py`.

## Sante du jeu, mesuree sur 20 parties (2026-09-20)
Serie de 20 parties normales robot contre robot, a niveaux strictement egaux :

| indicateur | resultat | lecture |
|---|---|---|
| etiquette « fort » | **9 / 20** (p = 0,82) | aucun avantage : l'etiquette est arbitraire a niveaux egaux |
| camp 1 (cote) | **11 / 20** (p = 0,82) | aucun biais de cote |
| egalites | **0 / 20** | les matchs se decident toujours |
| scores | 3-1 x8 · 3-0 x6 · 2-1 x4 · 1-0 x1 · 2-0 x1 | de la variete, pas que des ecrasements |
| unites bloquees | **0** | la correction du pont tient |
| poses refusees | **0** | la correction du placement tient |
| erreurs de script | **0** | |

Les « 6 parties sur 8 qui finissent 3-0 » reperes sur une serie courte etaient bien du bruit : sur
vingt parties les 3-0 ne font que **30 %**. C'est exactement pour cela que l'outil ne juge un
desequilibre qu'a partir de dix parties, et affiche la probabilite qu'il vienne du hasard.

## Depouiller une partie en une commande (tools/depouille.py)
Cinq defauts reels du jeu ont ete trouves en lisant des journaux de partie et en comparant des
comptes : `pose_refusee` x31, `defense_voie1` 123 contre 10, trois cartes de soutien a zero pose,
5,8 entrees d'aura par unite, quatre unites bloquees au meme endroit. **Chacun se voyait dans un
simple compte.** L'outil fait ces comptes automatiquement, avec des seuils nommes et justifies par
la mesure qui les a produits :

```
python tools/depouille.py            # le journal de partie le plus recent
python tools/depouille.py <chemin>   # un journal precis
```

Il verifie les erreurs de script, les poses refusees, les unites bloquees (avec l'endroit exact),
l'equilibre des voies, le papillonnage des auras, les cartes a regle presentes dans les decks
tires, et le temps pendant lequel le terrain reste vide. Sur une SERIE (`--sim`) d'au moins dix
parties, il juge aussi l'**equilibre entre les deux camps**, l'**equilibre des cotes** et la
**variete des scores**, chacun avec la probabilite que l'ecart vienne du simple hasard — une seule
partie ne dit rien d'un desequilibre, il faut du volume. Le detecteur a ete verifie sur un journal
fabrique expres (20 victoires du meme camp, toutes 3-0) : il rend bien p = 0,00 et signale les
deux anomalies, sans crier au loup sur l'axe des cotes qui, lui, restait equilibre. Il ne remplace pas la lecture : **il dit
ou regarder**. Un indicateur vert ne prouve pas que la partie est saine, seulement que ces
defauts-la ne sont pas revenus.

**Il a servi des sa premiere execution — en corrigeant une de MES mesures.** Il signalait
« Bobritto Bandito : 8,1 entrees d'aura par unite ». Verification faite, la trace `[SOUTIEN]`
se declenchait a TOUT changement de valeur, y compris quand une unite passe legitimement de
l'aura de Zibra (x1,15) a celle de Lirili (x1,30). La trace distingue desormais **ENTRE** (aucune
aura -> renforcee, ce qui mesure le papillonnage) et **CHANGE** (d'une aura a une autre, legitime).
Mesure refaite avec la trace juste : **0,5 entree par unite**, pour un seuil de 2,5. Il n'y avait
pas de defaut du jeu — il y avait un defaut de ma mesure.

## Franchir la riviere sans ramer devant le pont (src/shared/Traversee.lua)
Defaut **mesure en moteur** sur une serie de 6 parties normales : quatre unites restent
**bloquees**, et toutes les quatre au **meme endroit** — `z = -4`, aux abords du pont droit
(x = 15 et 18, le pont etant a 17).

L'ancien calcul visait le point d'entree du pont **sur la propre rive** de l'unite tant qu'elle
n'etait pas alignee lateralement :

```lua
if math.abs(pos.X - bx) > 0.8 then
    goal = Vector3.new(bx, pos.Y, sideOf(pos.Z) * 4)   -- sur SA berge
```

Son but n'avait donc **aucune composante vers l'autre berge** : elle ne progressait pas d'un stud
vers l'ennemi tant qu'elle n'etait pas alignee. Seule, elle s'alignait en une seconde et tout
allait bien — mais **la foule la pousse lateralement en permanence**, et la condition « mal
alignee » restait alors vraie indefiniment. L'unite ramait devant le pont.

C'est pour cela que le defaut ne se voyait que par intermittence : il fallait que la foule pousse
assez fort, assez longtemps. Les deux regles rejouees pas a pas, depart (15, -20) :

| poussee laterale | ancienne regle | nouvelle |
|---|---|---|
| aucune | franchit en 3,5 s | franchit en 3,5 s |
| 2 studs/s | **bloquee** (z plafonne a -1,8) | franchit en 3,6 s |
| 4 studs/s | **bloquee** (z plafonne a -3,1) | franchit en 4,1 s |
| 6 studs/s | **bloquee** | franchit en 5,8 s |

La regle tient en une phrase : loin de l'eau on se dirige vers l'entree du pont, **des qu'on l'a
atteinte on vise l'autre rive** — et l'alignement lateral se fait en marchant.

**Hypothese ecartee par le banc lui-meme** : je croyais d'abord a un « point fixe » (but egal a la
position courante). Le balayage des **14 577 positions** de l'arene n'en a trouve aucun, ni avant
ni apres. Le vrai mecanisme est le verrouillage lateral ci-dessus, et il ne se voit qu'en rejouant
la marche **avec** la poussee de la foule.

Mesure apres correction, meme serie de 6 parties : **4 unites bloquees -> 0**.
Banc : `tools/test_traversee.py`.

## Le soutien redevient jouable pour le robot (correction de Reponse.lua)
Defaut trouve en depouillant un journal de partie complet, et c'etait **une regression de la regle
precedente**. `Reponse.lua` notait un soutien « bon en attaque, catastrophique en defense »
(-50 points). Or le robot **defend la plupart du temps** : les trois cartes de soutien du jeu —
Lirili Larila, Spaghettino Malfunziono, Zibra Zubra Zibralini — n'ont donc ete jouees **aucune
fois** sur une partie entiere. Une carte que l'adversaire ne joue jamais n'existe pas.

La regle etait mal posee. Ce qui compte n'est pas d'attaquer ou de defendre, c'est d'avoir
**quelqu'un a renforcer** : renforcer ses defenseurs est parfaitement legitime, poser un tambour
dans une moitie vide ne l'est pas. Le robot compte donc desormais ses **allies presents**, et le
malus « pose tout seul » est passe de -50 a **-12** — assez pour que ce soit un mauvais choix,
trop peu pour que la carte devienne morte. Le banc verifie explicitement que ce malus reste
**bien plus petit que les bonus** du jeu.

Mesure en moteur, meme scenario : Lirili **0 -> 6** poses, Zibra **0 -> 6**, et 264 auras de
soutien appliquees en combat.

Au passage, une fausse piste ecartee **par la mesure** : sur 308 poses, seules 18 cartes
distinctes apparaissent. Ce n'est pas un defaut — `Cycle.TAILLE_PAQUET = 8`, le deck fait huit
cartes par camp, comme dans le genre. Les cartes absentes ne sont simplement pas dans les decks
tires.

## Par quel cote le robot attaque (src/shared/Voie.lua)
Defaut releve dans le meme journal que le precedent : `raison=defense_voie1` apparait **123 fois**
contre **10** pour la voie 2. Un robot qui defend douze fois plus un cote que l'autre n'est pas un
adversaire — il est previsible, et la moitie de l'arene ne sert plus a rien.

La cause tient dans **un signe**. Le robot visait « la tour adverse la plus faible » :

```lua
if tw.hp < pvMin then faible = tw end   -- comparaison STRICTE
```

Or au debut d'une partie les deux tours de princesse ont **exactement** les memes points de vie :
la premiere de la liste gagnait donc toujours, et c'etait toujours la meme. Les deux robots
attaquaient le meme cote toute la partie, et defendaient par consequent le meme cote. Meme piege
une ligne plus haut pour la voie menacee : `menace[1] >= menace[2] and 1 or 2` rend 1 des que les
deux menaces sont egales — **y compris quand elles valent zero**.

La correction n'est pas « mettre du hasard partout » : une **egalite** se departage, une **vraie
difference** se respecte. Une tolerance de 150 PV evite qu'une simple egratignure refige le choix,
et le banc verifie les deux sens — sur 100 tirages avec une tour nettement plus faible, le hasard
ne prend **jamais** le pas.

Mesure en moteur, meme scenario rejoue :

| | voie 1 | voie 2 | rapport |
|---|---|---|---|
| avant | 123 | 10 | **12,3 : 1** |
| apres | 56 | **95** | **1 : 1,7** |

C'est desormais la voie 2 qui domine cette partie-la : le cote n'est plus fige, et le
desequilibre restant est le comportement voulu. Banc : `tools/test_voie.py`.

## Ou le robot pose ses batiments (src/shared/Emplacement.lua)
Defaut **mesure en moteur**, pas suppose. Sur une melee complete (journal du 2026-09-20),
`[BOT] ... raison=pose_refusee` apparait **31 fois** — et les 31 concernent la **meme carte**,
Muro Spaghetti, un batiment. Le robot lui calculait une position prevue pour des **unites** (axe
de la voie, z tire au hasard) sans jamais regarder ou se trouvaient ses **propres** batiments. Or
la regle du jeu refuse un batiment a moins de **4 studs** d'un autre : il reproposait donc le meme
point et se faisait refuser en boucle. Environ **10 % de ses decisions** partaient a la poubelle,
et la carte restait coincee dans sa main.

Il cherche desormais une place **reellement libre** : d'abord dans la voie a couvrir, puis en
s'ecartant progressivement, entre 6 et 16 studs de la riviere. Et s'il n'y a **aucune** place, il
**passe son tour** (`batiment_sans_place`) au lieu d'insister sur une pose que le jeu refusera.

Point de conception qui compte : le module **ne recopie pas** la regle de pose — on lui passe
`Batiments.posePermise`, la regle du jeu elle-meme. Deux verites qui divergent, c'est le defaut
suivant ; le banc verifie d'ailleurs qu'aucune distance n'est ecrite en dur dans le module.

Mesure apres correction, meme scenario : **pose_refusee = 0**, `batiment_sans_place = 0`, et le
robot ecarte bien ses tourelles — `-17,-6` puis `-11,-6` puis `-23,-6` puis `-14,-9`.
Banc : `tools/test_emplacement.py`.

## Le robot repond a ce qui arrive (src/shared/Reponse.lua)
Avant, `botThink` prenait **« la carte la plus chere qu'il peut payer »**, avec un seul filtre :
savoir viser les volants. Deux consequences :
- il **ignorait tout** ce que le jeu a appris depuis — anti-air x2, anti-groupe x1,8, assassins,
  auras de soutien. Les regles existaient, l'adversaire ne s'en servait pas ;
- « la plus chere » n'est meme pas un bon critere : il vidait son elixir sur une grosse carte sans
  rapport avec la menace, alors qu'une petite carte bien choisie repousse la meme attaque pour
  trois fois moins.

Le robot NOTE desormais chaque carte jouable face a la situation. Ce que le banc mesure, en
comparant directement les deux robots sur la meme main :

| scene | ancien robot | nouveau robot |
|---|---|---|
| des volants arrivent | la grosse melee (6 elixir, **incapable de viser en l'air**) | l'**anti-air** a 2 elixir |
| un essaim arrive | la grosse carte mono-cible | l'**anti-groupe** |
| un tireur s'installe | la grosse carte | l'**assassin** a 2 elixir |

Quelques regles qui se lisent : un **soutien ne defend rien tout seul** (il ne vaut que derriere une
poussee), a pertinence egale on prend la **moins chere** — l'inverse exact de l'ancien critere —,
et une carte incapable de toucher la menace est presque exclue. Le **palier debutant continue
d'ignorer la menace** : c'est ce qui rend une premiere partie gagnable, et c'etait deja le sens du
palier. Banc : `tools/test_reponse.py`.

## Assassin : aller chercher les tireurs derriere le mur (src/shared/Assassin.lua)
Deux defauts qui se repondent, l'un trouve par un audit, l'autre par le jeu lui-meme :
- l'audit du catalogue (`tools/test_identite.py`) montrait **Cappuccino Assassino** comme l'une
  des deux seules cartes **sans aucune particularite** — alors que sa description promet un
  « assassin ». Le jeu ne tenait que la moitie de la promesse : elle etait rapide, et elle tapait
  le premier venu comme tout le monde ;
- rien ne contrait un **tireur protege**. Une unite a distance placee derriere un mur de melee
  etait intouchable : les attaquants s'arretaient sur le mur, exactement comme le defenseur le
  voulait.

L'assassin traite desormais un tireur ennemi (portee >= 5) comme s'il etait **9 studs plus
proche**. Ce n'est pas un chemin de ciblage a part : c'est un **bonus de priorite**, comme la
menace anti-tour d'une tour. Il herite donc de toute la machinerie deja verifiee — persistance de
la cible, hysteresis, pas de papillonnage.

Trois garde-fous : un **batiment** n'est jamais une proie (sinon l'assassin ne serait qu'une carte
anti-tours de plus), le bonus est **borne** (un archer a l'autre bout de l'arene ne fait pas
ignorer ce qui est au contact), et les deux modules partagent la **meme** portee de tireur — le
banc verifie qu'elles ne peuvent pas diverger en silence. Banc : `tools/test_assassin.py`.

## Chaque carte a une raison d'etre jouee (tools/test_identite.py)
Garde-fou permanent, ne depend d'aucune opinion : il croise le catalogue avec **toutes** les
regles du jeu (sort, batiment, vol, zone, groupe, bouclier, soin, explosion, gel, poison,
ralentissement, pose libre, anti-tours, charge, descendance, soutien, specialite, recul, visee,
assassin) et refuse une carte qui n'en porte **aucune** — elle se remplacerait par n'importe
quelle carte de meme cout, et le joueur n'aurait aucune raison de la choisir.

Une seule exception, nommee dans le fichier : **Tralalero Tralala**, la carte de reference du jeu.
C'est elle qui sert de metre-etalon a toutes les autres ; lui inventer un gadget retirerait ce
point de comparaison. Le banc a ete verifie **rouge** (exception retiree) puis **vert**.

## Visee : un tireur vise ou la cible SERA (src/shared/Visee.lua)
Le jeu faisait deja voler ses projectiles (`Projectiles`), et un tir dont la cible a bouge de plus
de 4 studs est perdu — c'est l'esquive, et c'est une bonne regle. Mais le serveur visait la
position **courante** de la cible : un tireur ratait donc **toute unite rapide**, meme allant
parfaitement **tout droit**, sans que le joueur n'ait rien fait. Rater ce qui va tout droit n'est
pas une esquive, c'est un defaut.

Le tireur anticipe desormais le deplacement pendant le temps de vol, avec une part propre a la
carte : **85 %** par defaut, **100 %** pour une tourelle (elle ne fait que ca) et pour les longues
portees (Giraffa, Tigrullini). L'anticipation est volontairement **imparfaite** — a 100 % pour
tout le monde, l'esquive n'existerait plus et les unites rapides perdraient tout interet.

Mesure du banc, contre la vraie marge d'esquive du jeu :

| situation | avant | apres |
|---|---|---|
| unite a 12 studs/s, **tout droit** | ratee | **touchee** |
| meme unite, **demi-tour** pendant le vol | ratee | **ratee** (l'esquive vit) |
| meme unite, **arret net** pendant le vol | ratee | **ratee** |
| vitesse a partir de laquelle un tir droit rate | **8,5 studs/s** | jamais dans la plage testee |

La vitesse n'existait nulle part dans le serveur (les unites sont deplacees a la main, sans
physique) : elle est **mesuree** entre deux images. Un **recul** est donc traite a part — c'est un
saut, pas une course : sans cela, une unite projetee aurait paru filer a toute vitesse et les
tireurs auraient vise tres loin devant elle. Banc : `tools/test_visee.py`.

## Frappe : jusqu'ou les bonus s'empilent (src/shared/Frappe.lua)
Trois regles majorent le meme coup — **Soutien** (x1,5 max), **Specialite** (x2,5 max) et
**Charge** (x3 max) — et elles se **multipliaient sans plafond commun** : **x11,25** possible en
theorie. Personne ne s'en apercevait, parce que la meilleure combinaison reellement jouable
atteint **x3,25** (Cocofanto lance sous une aura). Mais la prochaine carte qui cumulerait les trois
aurait fait n'importe quoi, une fois le jeu publie.

Plafond commun : **x4**. C'est un **garde-fou, pas un affaiblissement** — le banc verifie que la
meilleure combinaison actuelle (x3,25) passe **sans etre rabotee**, et qu'un futur cumul des trois
serait bien retenu. Un plafonnement est **trace** (`(PLAFONNE)` dans le journal) : s'il mord
souvent, c'est un signal d'equilibrage, pas un detail. Aucun bonus ne peut **affaiblir** un coup.
Banc : `tools/test_frappe.py`.

## Recul a l'impact : des unites qui projettent (src/shared/Recul.lua)
Avant : seul un **sort** (le tronc) repoussait. Aucune unite ne le faisait, donc un corps a corps
etait toujours un echange **sur place** — celui qui frappait le plus fort gagnait, et la position
ne changeait jamais rien. Le recul apporte ce qui manquait : gagner du **temps**. Repousser une
unite de 3 studs, c'est lui faire refaire le chemin pendant que la tour tire.

Trois cogneurs : **Burbaloni Luliloli** (2,5 studs), **Los Tralaleritos** (2,0) et
**Cocofanto Elefanto** (3,5).

La geometrie n'est **pas** reecrite : c'est la meme formule que `Sorts.recul`, et le banc verifie
que les deux donnent **exactement** le meme resultat sur cinq configurations. Une divergence ferait
que le tronc et une unite ne repoussent pas dans le meme sens.

Trois garde-fous :
- **le poids** — au-dela de 600 PV la cible resiste, jusqu'a un plancher de 30 % a 2000 PV. Visible
  en moteur : `Los Tralaleritos projette Cocofanto Elefanto 0.6 studs` (2200 PV) contre
  `Cocofanto Elefanto projette Scudo Banana 3.5 studs` ;
- **l'anti-verrouillage** — une meme cible ne peut pas etre repoussee plus d'une fois toutes les
  0,8 s. Sans cela, deux cogneurs la repousseraient en boucle et elle ne pourrait plus JAMAIS
  agir : une unite injouable est pire qu'une unite trop forte. Le banc le mesure — 20 studs
  parcourus en **2,5 s** sans cogneur, **4,07 s** avec un cogneur, et **exactement pareil avec
  deux** ;
- **les batiments ne bougent jamais**, sinon le mur defensif perdrait tout son interet.

Une unite projetee **perd son elan de charge** : elle ne court plus, elle recule.

Defaut trouve APRES la livraison, en relisant le module : le recul ne connaissait que les murs de
l'arene. Une unite **au sol** pouvait donc etre projetee **dans la riviere**, voire de l'autre
cote — un passage gratuit. Elle est desormais retenue sur **sa** berge, sauf au-dessus d'un pont,
et un volant n'est pas concerne (il survole).
Preuve en moteur : **46 projections** sur une serie de parties. Banc : `tools/test_recul.py`.

## Specialites : anti-air et anti-groupe (src/shared/Specialite.lua)
Avant : une unite faisait les **memes degats a tout le monde**. Un volant se repoussait avec
n'importe quel tireur, un essaim avec n'importe quelle unite de zone — aucune raison de GARDER une
carte pour la menace qu'elle contre, alors que c'est de la que vient la decision interessante du
genre (« je garde ma defense anti-air, il a des volants »).

Deux specialites, pas plus, pour rester lisibles :
- **anti-air x2,0** — Ballerina Cappuccina et Bananita Dolfinita, les deux petites defenses a
  longue portee ;
- **anti-groupe x1,8** — Tung Tung Tung Sahur et Bombombini Gusini, les frappes de zone.

Le bonus se calcule **cible par cible**, au moment du coup : il ne sert a rien contre le reste. Un
batiment n'est ni un volant ni un essaim, donc rien ne le « contre » — les tours ne tombent pas
plus vite. Un essaim volant, lui, est bien contre par les **deux** specialites.

Controle de coherence verifie au banc **contre le catalogue reel** : un anti-air doit pouvoir viser
autre chose que des batiments, un anti-groupe doit vraiment frapper en **zone**. Sans ce controle,
on pourrait declarer anti-air une carte incapable de toucher un volant — une promesse que le jeu ne
tiendrait pas. Le banc verifie aussi que chaque menace du catalogue (6 volants, 6 cartes en essaim)
a bien un contre, et qu'au moins un anti-air est disponible **sans achat**.

Preuve en moteur (melee du 2026-09-20), ou l'on voit les regles se composer :
`[SPECIALITE] Bananita Dolfinita contre Bombombini Gusini x2.0 : 150 -> 300` — 115 de base, 150
avec l'aura de soutien, 300 contre un volant. Banc : `tools/test_specialite.py`.

## Terrain : defendre chez soi vaut mieux qu'attaquer chez l'autre (src/shared/Terrain.lua)
Avant : un echange donnait **exactement** le meme resultat au pied de ses propres tours et au fond
du camp adverse. Defendre n'etait donc jamais plus rentable qu'attaquer, et la seule strategie
raisonnable etait de pousser en permanence — alors que le genre repose sur l'alternance.

Une unite qui se bat **dans sa moitie**, a **11 studs** d'une de ses tours **encore debout**,
encaisse **15 % de degats en moins** (plafond dur : 25 %). Volontairement defensif : elle ne frappe
pas plus fort, sinon une defense bien placee deviendrait imprenable et les parties finiraient a
egalite. Les deux conditions comptent : franchir la riviere **ou** perdre la tour retire l'avantage
a l'instant meme — c'est ce qui donne a la perte d'une tour une consequence immediate et lisible.
Un coup n'est jamais annule (plancher a 1 degat), les tours ne se protegent pas elles-memes, et
deux tours ne protegent pas deux fois.

**Deux defauts que la mesure a rattrapes**, et ils valent d'etre notes :
1. la convention des camps est **contre-intuitive** — le camp 1 occupe les z **negatifs**
   (`Regles.posePermise`). Ecrite a l'envers, la regle accordait l'avantage a l'attaquant, **et le
   banc restait vert** : il testait la meme convention fausse. C'est le moteur (zero declenchement
   sur une partie entiere) qui l'a montre. Le banc relit desormais la convention **dans
   Regles.lua** au lieu de la recopier ;
2. a `z = 0` exactement, les **deux** camps etaient « chez eux » : deux unites face a face sur la
   riviere auraient ete toutes deux protegees. La riviere n'appartient plus a personne.

Preuve en moteur : **87 declenchements** sur une melee, dont
`[TERRAIN] Los Tralaleritos defend chez lui : degats subis -15%`. Banc : `tools/test_terrain.py`.

## Soutien : des cartes qui rendent les autres meilleures (src/shared/Soutien.lua)
Avant : toutes les cartes se jugeaient **une par une**. Poser deux cartes ensemble ne valait jamais
mieux que les poser separement — donc aucune raison de composer une poussee, juste d'empiler la
carte la plus rentable. Le soigneur (Dottore Pizza) existait deja, mais il **repare** les degats
subis ; il ne change pas ce que les allies FONT.

Trois cartes portent desormais une aura : **Lirili Larila** (7 studs, degats **x1,30**),
**Spaghettino Malfunziono** (6 studs, cadence **x1,25**) et **Zibra Zubra Zibralini** (6,5 studs,
x1,15 et x1,10).

Deux regles font tout l'interet :
- **non-cumulatif** — dix fois la meme carte ne valent pas mieux qu'une seule (on garde le
  MEILLEUR de chaque effet), mais deux soutiens **differents** se completent. La strategie
  gagnante devient de composer, pas d'empiler ;
- **rien n'est stocke sur l'unite renforcee** — le bonus est recalcule a chaque image a partir des
  soutiens vivants. Sortir du rayon ou **tuer le soutien retire le bonus au meme instant**, sans
  le moindre reste. La parade est lisible : on tue le tambour, la poussee retombe.

Ni les ennemis, ni les batiments, ni le soutien lui-meme n'en profitent, et le plafond global est
**x1,5** quoi qu'il arrive.

**Hysteresis, ajoutee apres mesure.** Une unite qui marche a la FRONTIERE d'une aura entrait et
sortait en permanence : sur une partie entiere, une Bananita entrait **13 fois** dans un rayon au
cours de sa courte vie — donc elle en sortait 12. Ses degats oscillaient entre 95 et 124 sans que
rien de visible ne change, ce qui est illisible pour le joueur. Une fois renforcee, une unite le
reste donc jusqu'a s'eloigner de **1,5 stud** de plus. C'est le meme remede que pour le
papillonnage de cible.

Mesure, a nombre de poses identique (308) : traces d'aura **926 -> 457**, et pour Boneca Ambalabu
**5,8 entrees par unite -> 0,9**. Chaque unite entre une fois, au lieu de faire six allers-retours.
Le banc simule 200 images le long de la frontiere : **17 bascules** sans hysteresis, **1** avec —
l'entree, qui doit bien avoir lieu.

Preuve en moteur (melee du 2026-09-20) : les deux effets se combinent bien sur une meme unite —
`[SOUTIEN] Frulli Frulla degats x1.30 cadence x1.25`. Banc : `tools/test_soutien.py`.

## Descendance : abattre le colosse ne suffit pas (src/shared/Descendance.lua)
Avant : une grosse unite mourait et il ne restait **rien**. Celui qui avait paye 6 elixir perdait
tout d'un coup, celui qui l'avait tuee n'avait plus rien a faire.

Quatre cartes laissent desormais une descendance a leur mort : **Boneca Ambalabu** (2 Trippi
Troppi, poupee gigogne), **Frigo Camelo** (2 Bananita Dolfinita), **Orcalero Orcala**
(2 Trippi Troppi) et **Nuclearo Dinossauro** (3 Chimpanzini Bananini). Les filles naissent
**en cercle** autour du lieu exact de la mort, jamais au meme point — sinon elles passeraient une
seconde a se repousser (Foule) avant d'avancer.

## « Menace sans carte jouable » : le chiffre qui n'etait pas un bug (src/shared/Reserve.lua)

Un compteur sautait aux yeux dans les journaux : **1352 « menace_sans_carte » sur 60 parties**,
soit 16,8 % des decisions du robot. Traduction apparente : un camp sur six est attaque sans
pouvoir repondre. De quoi partir chercher un defaut de logique.

**Il n'y en a pas.** Deux lectures suffisent a le prouver :
  * la liste des cartes candidates ne contient QUE les cartes payables
    (`if c and t.elixir >= c.cost then`, GameServer) — « aucune carte » veut donc dire
    « aucune carte payable », pas « le robot a mal choisi » ;
  * `Reponse.choisir` prend toujours le meilleur score, **sans seuil** : il ne refuse jamais une
    carte qu'il pourrait jouer ;
  * la defense est decidee AVANT tout le reste (`elseif enDanger then`), donc il ne garde jamais
    son elixir alors qu'il est menace.
La mesure le confirme sans ambiguite : dans ces 1352 cas, l'elixir vaut **1,9 en mediane et
jamais plus de 4,0**. Le robot n'a litteralement rien a jouer.

### La conclusion que j'avais tiree, et pourquoi elle etait fausse

Premiere lecture : le taux monte avec le palier (16,6 % en aguerri, 21,8 % en expert), donc
« c'est un artefact de la frequence de decision — un robot qui reflechit plus souvent constate
plus souvent qu'il est a sec ». **Cette conclusion etait fausse aux deux tiers**, et c'est la
mesure par seconde de JEU qui l'a montre. Elle exigeait de remarquer que la simulation tourne a
`SIM_ACCEL = 8` : le temps mural du journal n'est PAS le temps de jeu.

| Palier | Reflexion | Attaque des | Decisions/s | **Cartes posees/s** | Elixir median | « menace » /s |
|---|---|---|---|---|---|---|
| normal | 2,4 s | 8 | 0,69 | **0,356** | 4,9 | **0,066** |
| aguerri | 1,7 s | 7 | 0,82 | **0,365** | 4,1 | **0,136** |
| expert | 1,1 s | 6 | 1,06 | **0,369** | 3,5 | **0,232** |

Rapporte a la seconde de jeu, l'ecart ne se reduit pas : il **triple** (x3,5 de normal a expert).
La decomposition est exacte — `menace/s = decisions/s x probabilite d'etre a sec` :

    facteur cadence   x1,53  ->  34 % de l'ecart
    facteur situation x2,30  ->  66 % de l'ecart

La cadence compte donc pour un tiers seulement. Les deux tiers sont un ecart **reel**, et sa cause
se lit dans la derniere colonne du tableau : les trois paliers posent **le meme nombre de cartes
par seconde** (0,356 / 0,365 / 0,369) — ils depensent autant. Ce qui change, c'est le SEUIL
d'attaque : un robot qui engage des 6 d'elixir vit structurellement plus bas qu'un robot qui
attend 8, et son elixir median suit exactement ce seuil (8 -> 4,9 ; 7 -> 4,1 ; 6 -> 3,5). Il n'est
pas mal programme : il joue plus agressivement, et l'agressivite se paie en moments de disette.

Deux lecons, et la seconde a coute une conclusion fausse : **un compteur « par decision » melange
la situation et la cadence a laquelle on la regarde** — mais **le rapporter a la bonne unite ne
suffit pas a savoir lequel des deux domine** : il faut les separer par le calcul, sur au moins
trois points de mesure. `tools/depouille.py` affiche desormais les deux formes cote a cote.

### Le vrai defaut, en amont : attaquer sans garder de quoi repondre

Rien n'empechait le robot de descendre a sec EN ATTAQUANT : il engageait des qu'il atteignait son
seuil, et la riposte le trouvait les mains vides. La regle ajoutee : **une carte d'attaque ne part
que s'il reste, apres l'avoir payee, de quoi jouer une carte de defense**. Le montant garde n'est
pas invente — c'est le cout MEDIAN du catalogue (3 elixir : 7 cartes a 2, 13 a 3, 10 a 4, 2 a 5),
donc 20 cartes sur 32 restent disponibles en reponse. La reserve ne s'applique **ni a la defense
ni a la contre-attaque** (repondre a une menace deja la prime sur toute reserve), **ni au palier
debutant** (son imprevoyance fait partie de son niveau).

**Effet mesure, sans arrondi favorable :**

| Palier | Attaques retenues | Effet sur « menace sans carte » |
|---|---|---|
| aguerri (attaque des 7) | **22** sur 60 parties | **−1 %** — du bruit |
| expert (attaque des 6) | **34** sur 20 parties, soit **12 % des poussees envisagees** | mesurable |

En aguerri la regle ne sert presque a rien, et il faut le dire : **le seuil d'attaque a 7
garantissait deja la reserve** pour toutes les cartes a 4 ou moins. Elle ne mord vraiment qu'au
palier expert, qui engage des 6. Elle est gardee pour cela, et comme garde-fou : l'invariant
« ne jamais engager sans reponse » n'etait jusqu'ici qu'un effet de bord d'un seuil, il est
desormais ecrit et verifie.

## CE QUI SEPARE VRAIMENT LES PALIERS : la vitesse, dans le mauvais sens (resultat final)

**A lire avant les sections qui suivent** : plusieurs y concluent « la patience gagne,
r = +0,98 ». **Cette conclusion est fausse.** Elle reposait sur des duels mesures AVANT la
reparation de l'alternance des cotes (voir plus bas), donc biaises. Elle a ete refutee par
l'experience suivante — duel normal contre expert, **60 parties par reglage, alternance des cotes
verifiee par le depouilleur**, une seule variable changee a la fois :

| Reglage de l'expert | Reflexion | Victoires de l'expert | p |
|---|---|---|---|
| patient, seuil d'attaque 9 | 1,1 s | **35 %** | 0,027 |
| agressif, seuil d'attaque 5 | 1,1 s | **42 %** | 0,25 |
| seuil d'attaque 9 | **2,4 s** (celle du normal) | **67 %** | **0,013** |

Le seuil d'attaque ne decidait **rien** : patient ou agressif, l'expert perdait, et l'ecart entre
les deux reglages n'est pas significatif (p = 0,57). La seule chose constante dans ses defaites
etait sa **vitesse de reflexion** — et la ramener a celle du normal suffit a le rendre nettement
superieur, **au-dela de l'objectif de 60 %**.

L'explication tient debout avec tout ce qui a ete mesure avant : un robot qui reflechit trop vite
**reagit a tout**, se disperse, et perd. La vitesse passait pour une qualite ; dans ce jeu,
limite par l'elixir et non par la vitesse de decision, c'est un defaut.

**Reglage retenu :** debutant 3,2 s, et **2,4 s pour normal, aguerri et expert**. Les paliers hauts
se separent desormais par ce qui rapporte : moins d'erreurs (22 % / 10 % / 0 %), un placement
plus juste, et la lecture de l'elixir adverse (`Fenetre.lua`). Deux bancs exigeaient encore
« l'expert reflechit plus vite » ; ils exigent maintenant l'inverse, preuve a l'appui.

**L'echelle complete, mesuree** (60 parties par duel, alternance des cotes verifiee, zero erreur) :

| Duel | Score | Le superieur gagne | p (seul) |
|---|---|---|---|
| normal vs aguerri | 24 - 36 | **aguerri 60 %** | 0,155 |
| aguerri vs expert | 22 - 38 | **expert 63 %** | 0,052 |
| normal vs expert | 20 - 40 | **expert 67 %** | **0,013** |

L'aguerri **s'intercale** : il bat le normal et perd contre l'expert. La gradation est coherente
avec une echelle bien ordonnee — un palier d'ecart donne 60 a 63 %, deux paliers d'ecart 67 %.
Pris un par un, les deux duels adjacents ne franchissent pas le seuil de 0,05 (0,155 et 0,052) ;
reunis, **le palier superieur gagne 74 parties sur 120, soit 62 %, p = 0,013**.

**Le bas de l'echelle, lui, n'est PAS ordonne** (mesure du 2026-09-21, 60 parties par reglage) :

| Duel | Reflexion du debutant | Score | Le normal gagne | p |
|---|---|---|---|---|
| debutant vs normal | 3,2 s (reglage retenu) | 33 - 27 | **45 %** | 0,52 |
| debutant vs normal | 2,4 s (test) | 29 - 31 | **52 %** | 0,90 |

Le debutant **tient tete au normal** — et un debutant est celui qu'affronte un joueur NEUF : il
devrait etre nettement plus facile. L'hypothese en miroir de celle de l'expert (« sa lenteur
l'avantage ») a ete testee et **refutee** : a vitesse egale, rien ne change (45 % -> 52 %, ecart
non significatif). Le reglage d'origine est donc conserve. Les autres differences entre les deux
paliers — 40 % d'erreurs contre 22 %, pas de defense anticipee, pas de contre-attaque, pas de
reserve defensive, un placement six fois moins precis — **ne produisent aucun ecart mesurable**,
et la cause n'est pas encore identifiee.

L'echelle mesuree a donc trois marches, pas quatre : **debutant ~ normal < aguerri < expert**.

### Pourquoi le debutant tient tete au normal : deux defauts qui se compensent

Methode : le debutant devient une **copie exacte du normal sauf UNE caracteristique**, puis
affronte le normal sur 60 parties. L'ecart mesure est l'effet de ce seul defaut. Un **temoin**
(copie parfaite) calibre le bruit. Outil : `tools/sonde_debutant.sh`.

| Defaut du debutant, seul | Score | Le normal gagne | p | Lecture |
|---|---|---|---|---|
| aucun (temoin) | 30 - 30 | **50 %** | 1,00 | methode calibree |
| 40 % d'erreurs au lieu de 22 % | 31 - 29 | 48 % | 0,90 | **sans effet** |
| pas de contre-attaque | 29 - 31 | 52 % | 0,90 | **sans effet** |
| placement 6 studs au lieu de 3 | 29 - 31 | 52 % | 0,90 | **sans effet** |
| seuil d'attaque 6 au lieu de 7 | 28 - 32 | 53 % | 0,70 | **sans effet** |
| pas de defense anticipee | 23 - 37 | **62 %** | 0,09 | **le penalise** |
| **n'economise pas en ouverture** | **41 - 19** | **32 %** | **0,006** | **l'AVANTAGE** |

Tout s'explique. Le debutant porte deux defauts qui comptent, et ils vont en **sens contraire** :
ne pas anticiper les menaces lui coute une douzaine de points ; ne pas economiser en ouverture lui
en **rapporte** dix-huit. Ils s'annulent, et le reste est neutre — d'ou les 45 % mesures.

Le vrai defaut est donc chez les autres paliers : **« economiser en ouverture »**
(`economise = true`, qui exige `Robot.SUPPLEMENT_OUVERTURE` = 2 elixir de plus avant d'ouvrir
soi-meme) est un **handicap**, avec le resultat le plus net de toute la serie (p = 0,006).
Attendre au debut de partie laisse l'initiative a l'adversaire. Normal, aguerri et expert le
portent tous les trois.

Deux constats de plus, utiles pour la suite : le choix de la carte compte tres peu (jouer au
hasard 40 % du temps ne coute rien), et le placement non plus a quelques studs pres. Ce qui fait
gagner dans ce jeu, c'est **le moment** — ouvrir tot, repondre a la bonne menace.

**Le retrait a ete essaye, et il a echoue** (2026-09-21, 60 parties par duel, alternance verifiee).
« Economiser en ouverture » a ete retire aux trois paliers hauts :

| Duel | Avant | Apres le retrait | p |
|---|---|---|---|
| debutant vs normal | normal 45 % | normal **53 %** | 0,70 — gain non etabli |
| normal vs expert | expert 67 % | expert **37 %** | 0,052 — **effondrement** |

Le retrait profite surtout au palier dont le seuil d'attaque est bas (le normal, 7 -> ouvre deux
elixir plus tot) ; l'expert, deja borne par sa lecture de l'adversaire et par le plafond d'elixir,
n'y gagne presque rien. Le haut de l'echelle s'inverse pour un bas a peine ameliore : **reglage
d'origine restaure**. La lecon de methode est nette : **l'effet d'un trait mesure sur UN palier ne
predit pas l'effet du meme trait retire a TOUS** — les paliers interagissent entre eux.

**Second essai, cible sur le seul debutant** : lui donner « economiser en ouverture » (le trait
que la sonde designait comme son avantage), sans toucher aux autres. Resultat sur 60 parties :
**30 - 30**, le normal passe de 45 % a **50 %** (p = 1,0). Aucun effet mesurable — la sonde
laissait esperer ~62 %. Change annule. Deux essais, deux echecs : les traits du robot ne
s'additionnent pas, et **la cause qui rend le debutant aussi fort que le normal reste a trouver**.

**Methode, et pourquoi il a fallu quatre essais :** la correction du seuil (patience), puis celle
de la sur-defense, puis la lecture de l'adversaire etaient chacune raisonnables et **chacune a
echoue** a rendre l'expert superieur. Seule l'experience qui change UNE variable en gardant les
autres fixes a designe la vraie cause. Une hypothese seduisante n'est pas une cause tant qu'on
n'a pas fait varier ce facteur seul.

## Les quatre paliers de robot n'etaient PAS classes par force (src/shared/Robot.lua)

Le jeu promet une difficulte qui monte avec les trophees : debutant, normal, aguerri, expert.
Cette promesse n'avait **jamais ete verifiee en partie** — et pour une raison simple : `BRR_ROBOT`
n'acceptait qu'un seul nom, donc les deux camps jouaient toujours au meme niveau. Le classement
reposait entierement sur l'intention des reglages.

`Robot.paliersDuel` permet desormais d'ecrire `--robot=normal:expert` : un palier par camp, et les
deux cotes **s'echangent a chaque partie** — sans cette alternance, on mesurerait la force du
palier et l'avantage de cote dans le meme chiffre.

**Les six duels, deux a deux, 20 parties chacun (120 parties) :**

| Duel | Score | p |
|---|---|---|
| debutant vs normal | **11 - 9** | 0,82 |
| normal vs aguerri | **11 - 9** | 0,82 |
| aguerri vs expert | 9 - 11 | 0,82 |
| debutant vs aguerri | **11 - 9** | 0,82 |
| debutant vs expert | **13 - 7** | 0,26 |
| normal vs expert | **13 - 7** | 0,26 |

Victoires totales, sur 60 parties chacun : **debutant 35, normal 33, aguerri 27, expert 25** —
c'est-a-dire **l'INVERSE EXACT de l'ordre voulu** (1 chance sur 24 si l'ordre etait du hasard), et
le palier « superieur » ne gagnait que **43 %** de ses parties.

### La cause : un reglage qui allait dans le mauvais sens, et qui dominait tous les autres

| Palier | Reflexion | Erreur | Attaque des | Victoires /60 |
|---|---|---|---|---|
| debutant | 3,2 s | 40 % | **9** | **35** |
| normal | 2,4 s | 22 % | **8** | **33** |
| aguerri | 1,7 s | 10 % | **7** | **27** |
| expert | 1,1 s | 0 % | **6** | **25** |

Entre le seuil d'attaque et les victoires : **r = +0,98**. Plus un robot attaque TOT, plus il
PERD — il descend a sec et subit la riposte (c'est exactement ce que la mesure de « menace sans
carte » montrait plus haut). On croyait rendre l'expert « plus agressif » en lui donnant 6 ; on le
rendait imprudent, et cette imprudence **annulait** son meilleur temps de reflexion et son absence
d'erreurs.

**Correction : le seuil d'attaque MONTE desormais avec le niveau** (6 / 7 / 8 / 9). L'imprudence
appartient au debutant, la patience a l'expert — ce qui decrit d'ailleurs bien mieux un joueur qui
progresse. Un banc fige les trois progressions (reflexion et erreur decroissantes, seuil
croissant) et a ete vu ROUGE sur l'ancien reglage.

### AVERTISSEMENT sur les mesures de duels ci-dessous

Un biais du harnais, trouve le 2026-09-21, ENTACHE tous les duels rapportes dans cette section :
le profil du robot n'etait assigne qu'aux camps **sans joueur** (`occupant[camp] == nil`), or en
Studio un joueur local en occupe toujours un. Ce camp gardait donc le palier de la premiere partie
pendant que l'autre alternait — **l'alternance des cotes n'avait jamais lieu**, et les chiffres
melangent la force du palier avec l'avantage de cote. C'est le MEME piege que le « camp muet »
plus bas, et il a fallu le rencontrer deux fois pour le voir.
Corrige : en serie (`BRR_SIM`), les deux camps recoivent leur profil. `tools/depouille.py` porte
desormais un controle « alternance des cotes dans le duel » qui refuse une mesure ou un camp garde
le meme palier du debut a la fin.

### Les six duels REJOUES apres correction (120 parties de plus)

| Duel | Le superieur AVANT | APRES |
|---|---|---|
| debutant vs normal | 45 % | **55 %** |
| normal vs aguerri | 45 % | **55 %** |
| aguerri vs expert | 55 % | 55 % |
| debutant vs aguerri | 45 % | **60 %** |
| debutant vs expert | 35 % | **50 %** |
| normal vs expert | 35 % | **45 %** |
| **agregat** | **52/120 = 43 %** | **64/120 = 53 %** |

**Ce qui est corrige, et c'est net :** l'inversion a disparu. Le debutant passe de **PREMIER**
(35 victoires) a **DERNIER** (27), et la correlation entre le rang du palier et ses victoires
passe de **r = -0,98 a r = +0,60**. Le reglage n'agit plus contre l'intention.

**Ce qui n'est PAS acquis, et il faut le dire :** aucun classement n'est *etabli*. Le palier
superieur gagne 53 % (p = 0,52 — indistinguable de 50/50), et les trois paliers hauts sont a
egalite : **aguerri 32, normal 31, expert 30** sur 60 parties chacun. Les 120 parties jouees
permettaient de detecter un ecart d'au moins **63 %** ; il n'y en a pas. Pour etablir l'ecart
actuel il faudrait environ **2 200 parties**, pour un ecart qu'un joueur SENTIRAIT (60 %),
environ **200**.

Conclusion utile pour le jeu, et non pour la statistique : **la difficulte separe le debutant du
reste, mais normal, aguerri et expert se valent**. Leurs differences restantes — temps de
reflexion et taux d'erreur — ne suffisent pas a creer un ecart perceptible. C'est le prochain
chantier d'equilibrage, et il devra se mesurer, pas se supposer : le seuil d'attaque avait
justement l'air d'une bonne idee.

`tools/duel_paliers.sh <a:b> <sortie>` rejoue un duel de 20 parties dans le bureau cache.

## Pourquoi l'expert reste le plus faible : il SUR-DEFEND (src/shared/Fenetre.lua)

Une fois l'alternance des cotes reparee, la mesure devient lisible — et severe. Duel
**normal contre expert, 60 parties** : l'expert gagne **40 %**. Il est toujours le plus faible.

La cause se lit dans deux colonnes :

| Palier | Decisions | Defenses | Attaques | Defenses par attaque | Elixir median a la pose |
|---|---|---|---|---|---|
| normal | 2 863 | 1 088 | 289 | **3,8** | **6,0** |
| expert | 6 056 | 1 247 | **139** | **9,0** | **4,1** |

L'expert reflechit deux fois plus vite (1,1 s contre 2,4 s). Il REAGIT donc a deux fois plus de
menaces, repose une carte a chaque cycle de reflexion, **depense tout en defense** — et n'a plus
rien pour attaquer : 139 attaques contre 289. Son elixir median a la pose tombe a 4,1 alors que
son seuil d'attaque est de 9. Le reglage cense le rendre meilleur (la vitesse) le rend
**sur-defensif**, et la sur-defense perd.

### Ce qui a ete tente, et ce que ca a appris

La competence ajoutee — **lire l'elixir adverse** (`Fenetre.lua`) — fonctionne et ne triche pas :
le robot part de la MEME estimation que celle affichee au joueur (`Lecture.elixirEstime`), jamais
du compteur reel d'en face, puis l'entache d'une erreur d'autant plus grande que son palier lit
mal (0 = ne regarde pas · 0,6 = se trompe de deux elixir · 1 = lit juste). Elle se voit en partie :
22 a 25 % des poussees.

Mais son premier usage etait **a l'envers**, et la mesure l'a dit : « fenetre ouverte -> attaquer
plus tot » a donne **38 %** de victoires a l'expert, qui posait alors a 4,0 d'elixir de mediane
contre 5,8 au normal. On avait refabrique un robot imprudent — le defaut exact corrige la veille.
Sens inverse applique (« fenetre fermee -> attendre davantage ») : **40 %**. L'ecart n'est pas la.

**Objectif non atteint** : le but etait ~60 % pour le palier superieur. La cause est maintenant
nommee et chiffree — la sur-defense — et elle n'est pas dans la lecture de l'adversaire mais dans
le fait qu'une menace deja traitee est re-defendue a chaque cycle de reflexion.

### La sur-defense corrigee (src/shared/Defense.lua) — et ce qu'elle ne suffit pas a regler

Le serveur decidait « defendre » des qu'une menace existait (`elseif enDanger then`), sans
regarder ce qui la couvrait deja. Nouvelle regle : **on ne defend pas une menace que ses propres
unites tiennent deja**, la force engagee se comptant en points de vie comme la menace elle-meme.
Le banc rejoue le defaut : contre une meme menace de 12 s, les robots posaient **5, 8 et 11
cartes** selon leur vitesse ; ils en posent **2**, tous, apres correction.

**Mesure en partie, normal contre expert, 60 parties, alternance des cotes verifiee :**

| Indicateur | Expert AVANT | Expert APRES | Normal APRES |
|---|---|---|---|
| defenses par attaque | **9,0** | **3,8** | 1,8 |
| attaques lancees | 139 | **351** (x2,5) | 593 |
| elixir median a la pose | 4,1 | **6,1** | 7,2 |
| defenses evitees (menace deja couverte) | — | 896 | 236 |
| **victoires de l'expert** | **40 %** | **42 %** (p = 0,25) | |

La sur-defense est **reellement corrigee** : l'expert defend deux fois et demie moins par
attaque, garde deux elixir de plus en poche et attaque deux fois et demie plus souvent. Mais
**son taux de victoire ne bouge presque pas**, et l'objectif de ~60 % n'est pas atteint.

La raison est dans la derniere colonne : la correction est **universelle** — le normal en profite
aussi, et plus encore (1,8 defense par attaque, 7,2 d'elixir). L'ecart relatif demeure :
**l'expert defend toujours deux fois plus que le normal** (3,8 contre 1,8). Sa vitesse de
reflexion lui fait encore voir, et traiter, plus de menaces — la regle de couverture reduit la
sur-reaction, elle ne l'annule pas.

Troisieme mesure qui dit la meme chose : **dans l'equilibrage actuel, tout ce qui rend le robot
plus reactif le dessert.** Une echelle de difficulte fondee sur la vitesse ne peut donc pas
fonctionner tant que la reactivite ne se traduit pas en avantage.

## Derniere garde : le Roi se defend quand il ne reste que lui (src/shared/Garde.lua)

Defaut mesure sur une serie de 20 parties a niveaux egaux : **15 sur 20 se terminaient avant la
fin du temps**, donc par la chute du Roi. Une fois les deux tours de princesse tombees, plus rien
ne ralentissait l'attaquant — le Roi tire moins loin (12 contre 14) et pas plus vite. Le camp mene
n'avait aucun moment pour se refaire.

La regle : quand un camp a perdu ses **deux** tours de princesse, son Roi tire **1,5 fois plus
souvent**. Elle ne donne **ni points de vie ni degats** — des points de vie allongeraient les
parties sans rien rendre lisible, et des degats changeraient des echanges regles ailleurs
(`Frappe`). La cadence, elle, **se voit et s'entend** : le Roi se met a tirer vite, les deux
joueurs comprennent que la derniere garde a commence.

Bornes verifiees au banc : plafond dur a x2 (un Roi seul ne doit jamais valoir mieux que les deux
tours qu'il a perdues), aucune tour de princesse et aucun batiment pose n'en profite, et le delai
de tir ne devient jamais nul. Un piege evite au passage : le serveur nomme ses champs `isKing` et
`alive`, la regle pure parle de `estRoi` et `vivante` — **sans traduction explicite, la regle
aurait rendu 1 pour toutes les tours, en silence**, et aucun test ne s'en serait plaint. Le banc
verifie donc la traduction elle-meme.

**Resultat mesure, sans arrondi favorable.** Sur 60 parties apres la mise en place :

| Indicateur | Avant (20 parties) | Apres (60 parties) |
|---|---|---|
| parties finies par KO | **75 %** | **65 %** |
| temps restant median | 9 s | 15 s |
| gardes engagees | — | **19** (camp 1 : 9, camp 2 : 10) |

La baisse du taux de KO **n'est PAS etablie** : Fisher exact bilateral, **p = 0,58**. La tendance
va dans le bon sens, le volume ne la prouve pas, et monter le facteur jusqu'a obtenir un beau
chiffre serait de l'equilibrage a l'aveugle. Ce qui EST prouve : la garde s'engage au bon moment,
sur les deux camps, sans effet de bord (0 erreur, tous les indicateurs de dépouillement verts), et
**dans 6 des 17 parties ou elle s'est declenchee (35 %), le camp acule a tenu jusqu'a la fin du
temps**. La regle est gardee pour ce qu'elle apporte a la lisibilite de la fin de partie, pas pour
un effet statistique qu'elle n'a pas demontre.

## Le banc qui mesurait un camp contre le vide

Defaut du HARNAIS, trouve le 2026-09-20 en voulant controler un changement d'equilibrage. Une
serie de 20 parties a niveaux egaux rendait un verdict spectaculaire :

    camp 1 : 0 victoire sur 20, p = 0,00
    variete des scores : 3-0 revient 20 fois sur 20

De quoi conclure a un desequilibre grave. **C'etait faux.** Le compte des decisions le disait :
**camp 1 : 3 decisions, camp 2 : 721**. Le camp 1 ne jouait pas du tout.

La cause tient en une ligne : le mode « bot contre bot » ne s'allume que si **aucun joueur** n'est
present trois secondes apres le demarrage — or en Studio, un joueur local existe **toujours**. Le
camp qu'il occupait n'avait donc aucun robot, et restait immobile pendant que l'autre le rasait.
Corrige : une serie `BRR_SIM` pilote desormais **les deux camps**, joueur present ou non.

Meme serie, apres correction :

| Indicateur | Avant | Apres |
|---|---|---|
| decisions camp 1 / camp 2 | **3 / 721** | **1211 / 1554** |
| victoires du camp 1 | **0 / 20** (p = 0,00) | **10 / 20** (p = 1,00) |
| scores | **3-0 vingt fois** | 3-0 x6, 2-1 x5, 1-0 x4, 3-1 x4 |
| equilibre des voies | non evaluable | 411 contre 519 (rapport 1,3) |

Le dépouilleur porte maintenant ce controle **avant** tous les indicateurs d'equilibre : si un camp
ne joue pas, il le dit et n'accuse pas le jeu d'un defaut qui est celui du banc. La lecon vaut
au-dela de ce projet : **un indicateur d'equilibre n'a de sens que si les deux cotes jouent**, et
cela se verifie par un compte, pas par confiance.

## Audit des promesses : une carte ne ment jamais sur ce qu'elle fait

Chaque regle de combat est relue **contre le texte des cartes**, dans les deux sens, par les bancs
eux-memes. Ce n'est pas du confort : une carte qui promet sans tenir, ou qui fait sans annoncer,
est un defaut que rien d'autre ne voit — les chiffres sont justes, les tests verts, et le joueur
se trompe quand meme.

Sens direct — une carte porteuse d'une regle doit en avoir l'identite :

| Regle | Ce qu'exige le garde-fou | Trouve par la mesure |
|---|---|---|
| **Charge** | pas de charge sur un « tireur » ; la portee ne depasse pas la moitie de l'elan | Zibra annoncait une charge et n'en avait pas ; Tigrullini en avait une sans l'annoncer |
| **Recul** | une seule unite, et un vrai poids (`hp > 600`) | **Los Tralaleritos retire** : 3 bebes requins a 500 pv projetaient **7,4 fois par pose**, plus que l'elephant a 2400 pv (3,4). Remplace par **Orcalero**, dont la carte dit « cogneuse solide » |
| **Descendance** | un colosse **seul** (`hp >= 1000`), et une descendance qui vaut au plus **la moitie** de la mere | **Orcalero rendait 50,7 %** — sa descendance passe de 2 Trulimero a 2 Trippi (40 %) |
| **Specialite** | un anti-air doit pouvoir viser le ciel, un anti-groupe frapper en zone | les 4 etaient deja coherentes |

Les quatre regles suivantes ont ete passees au meme crible :

| Regle | Ce qu'exige le garde-fou | Trouve par la mesure |
|---|---|---|
| **Soutien** | une seule unite, qui tient a distance (portee >= 5) et qui **ne charge pas** | **Zibra retiree** : elle s'elancait sur **9 studs** pour une aura de **6,5** — elle abandonnait mathematiquement ceux qu'elle renforcait, et son texte ne promet que « charge rapide ». Remplacee par **Glorbo** (1 unite, portee 8, aucune charge) |
| **Visee** | une part d'anticipation superieure au defaut n'appartient qu'a un tireur ; « portee record » doit etre le record reel | **Aquila Frizzante disait « tire loin » avec 6,5 studs**, sous la mediane des tireurs (7,2). Son **texte** est corrige, pas ses chiffres : desequilibrer une carte volante a 4 elixir pour sauver une phrase serait le mauvais echange |
| **Assassin** | au contact, rapide (>= 14) et fragile (<= 600 pv) | deja coherent : Cappuccino a **la vitesse maximale du jeu** (16), 320 pv, portee 3 |
| **Terrain** | le **manuel** et la regle doivent dire le meme chiffre, sans cumul cache | deja coherent : le manuel **lit** `Terrain.REDUCTION` au lieu de recopier 15 %, et deux tours ne protegent pas plus qu'une |

Piege ecarte en cours de route, et c'est le plus instructif : j'ai cru a un trou — Glorbo, Frigo et
Regina Ghiaccio, tous tireurs, absents de `Visee.PARTS`. **Faux.** `Visee.part` rend
`PART_DEFAUT` (0,85) a toute carte non declaree : ils anticipent deja. `PARTS` n'est pas la liste
de ceux qui visent, c'est le **reglage fin des meilleurs**. La regle est desormais ecrite dans le
module, pour que personne ne refasse cette lecture.

Sens inverse — on part des **descriptions**, sur les 47 cartes : celle qui promet « en zone » doit
l'avoir, celle qui promet le ciel doit le viser. Une subtilite mesuree ici : « en zone » se tient
de **trois** facons dans ce jeu — degats d'eclaboussure, **explosion a la mort**
(`Statuts.explosionMort`) ou rayon d'un sort. Ne compter que la premiere accusait a tort **Bomba
Salsiccia**, dont la carte dit « explose **en mourant** ». Le banc verifie aussi que le controle
**mord encore**, sur deux cartes fabriquees qui trahissent leur texte.

Preuve en moteur (melee, robot aguerri) : `[RECUL] Orcalero Orcala projette` x5,
`[DESCENDANCE] Orcalero Orcala laisse 2 Trippi Troppi`, et **Tralaleritos pose sans projeter une
seule fois**. Zero erreur de script.

Garde essentielle : **une fille ne pond jamais a son tour** (`Descendance.PROFONDEUR_MAX = 1`).
Sans elle, une carte mal declaree ferait boule de neige a l'infini, et chaque mort prise isolement
resterait pourtant correcte. Le banc le mesure : 8 colosses morts donnent **16 unites en
2 vagues**, puis plus rien.

Choix des meres corrige par la mesure : les quatre premieres retenues etaient payantes ou rares
(Giraffa, Vacca) et sur une melee complete de 190 s **aucune n'avait ete jouee une seule fois** —
la regle ne s'appliquait a personne. Preuve en moteur apres correction : les quatre meres
observees, dont `[DESCENDANCE] Nuclearo Dinossauro laisse 3 Chimpanzini Bananini`.
Banc : `tools/test_descendance.py`.

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

**Choix des cartes corrige par un audit des descriptions (2026-09-20).** Les charges avaient ete
attribuees sans les lire, et le resultat se contredisait :

| carte | description | avant | apres |
|---|---|---|---|
| **Zibra Zubra Zibralini** | « deux zebres, **charge** rapide » | **aucune charge** | x1,8 apres 9 studs |
| **Tigrullini Watermelini** | « **tireur longue portee** » | x2,2 | **retiree** |

La carte qui **promettait** une charge n'en avait pas, et un **tireur** en avait une — or un
tireur s'arrete a 13 studs pour tirer, il ne court jamais assez longtemps pour charger : la regle
etait un mensonge. Un garde-fou empeche desormais les deux erreurs, dans les deux sens : toute
carte dont la description annonce une charge doit en avoir une, aucune carte a charge ne peut se
decrire comme un tireur, et sa **portee** doit rester inferieure a la moitie de sa distance d'elan.
Le garde-fou a ete verifie **rouge** (en remettant Tigrullini) puis **vert**.

Mesure en moteur : `[CHARGE] Zibra Zubra Zibralini lancee apres 9 studs, coup a 162 au lieu de 90`
et `[CHARGE] Cocofanto Elefanto lancee apres 14 studs, coup a 450 au lieu de 180`.
Banc : `tools/test_charge.py`.

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
La publication engage ton compte : elle se fait a la main dans Studio. Pour passer en PUBLIC et
vendre, voir aussi « A faire avec TON compte » plus bas (eligibilite, questionnaire, produits).

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
- **Verrou de session** (2026-09-26) : chaque match change le joueur de serveur (serveur reserve).
  Le profil porte le serveur qui le tient (`_session`) ; il se lit et s'ecrit par `UpdateAsync`.
  Le serveur d'arrivee attend que celui de depart l'ait rendu (au plus ~14 s, puis reprise de
  force si l'ancien est mort), et un serveur a qui le profil a ete repris n'ecrit plus rien.
  Avant, le serveur d'arrivee pouvait lire le profil avant la derniere ecriture de l'autre, puis
  l'ecraser : victoire, coffre ou achat en pieces perdus. Banc : `tools/test_verrou_session.py`.
- **Pass payes en jeu** (2026-09-26) : Roblox garde en cache la reponse de
  `UserOwnsGamePassAsync` pour la session ; un pass achete en jeu restait « non possede » jusqu'a
  la reconnexion. L'evenement `PromptGamePassPurchaseFinished` fait foi (`Economie.noterPassAchete`)
  et le serveur pousse la vue a jour au client (`Remotes.Vue`). Le **VIP** est desormais propose
  dans la boutique (offre Robux « Pass VIP : pieces x2 ») tant qu'il n'est pas possede.
  Banc : `tools/test_pass_achete.py`.
- **Tests** : `python build.py --autotest --ecotest` (83 cas au 2026-09-26, journal [ECOTEST]),
  `--hub` (accueil ouvert), `--boutique` (boutique ouverte), a capturer avec `tools/studio-capture-moteur.ps1`.
  Hors Studio (rapide, sans compte) : `python tools/test_economie.py`, `tools/test_deck.py`,
  `tools/test_recus.py` (achats Robux + ecritures regroupees), `tools/test_robot_deck.py` (paquet du
  robot). Ces bancs demandent `pip install lupa`. `tools/harnais_economie.py` n'est PAS un banc :
  c'est le prelude Lua partage (il s'appelait test_economie_lib.py et passait pour un test muet).

### Etat de la publication (2026-09-26)
- Experience **Brainrot Royale** publiee en **PRIVE** : universe `10768149063`, place `126168119650545`
  (compte viralstudiogames). Creation en equipe et partage de donnees Gen AI desactives.
- Offres creees sur create.roblox.com, **prix fixes** (tarification geree desactivee : l'activer
  demande d'accepter ses conditions et laisse Roblox tester les prix) et branchees dans `Economie.lua` :

  | Offre | Type | Identifiant | Prix |
  |---|---|---|---|
  | Sac de 500 pieces | Developer Product | 3714887785 | 49 R$ |
  | Coffre de 1500 pieces | Developer Product | 3714889079 | 129 R$ |
  | Poignee de 80 gemmes | Developer Product | 3714889708 | 99 R$ |
  | VIP (pieces x2) | Game Pass | 1999832722 | 199 R$ |
  | Pass de saison premium | Game Pass | 1999634739 | 299 R$ |

  Verifie par `MarketplaceService:GetProductInfo` dans Studio (nom, prix, en vente). Un Game Pass est
  PERMANENT : le pass de saison ouvre la piste premium de toutes les saisons (sa description le dit).
- Restent a faire par le proprietaire : etapes 0 et 3 ci-dessous (eligibilite, questionnaire de
  maturite), puis passer l'experience en Public ; nombre max de joueurs par serveur (6, voir plus haut).
- **Test d'achat de bout en bout** (2026-09-26, Studio sur la place en ligne, acces aux API active) :
  achat test du Sac de 500 pieces -> journal `[ECO] ... achat Robux Sac de 500 pieces, +500 pieces`,
  solde 100 -> 600 ; victoire -> `+60 pieces` (30 x 2, VIP actif) ; profil relu apres arret a
  660 pieces. Le VIP n'est PAS achetable par le compte createur : Roblox lui attribue d'office ses
  propres pass (API d'inventaire), donc l'offre est masquee et le x2 deja actif. Un achat de pass en
  jeu se teste avec un SECOND compte.
- **Version en ligne en retard d'une correction** : la place publiee precede le verrou par SESSION
  (reconnexion sur le meme serveur) et la fin du double rendu a la fermeture (faux avertissement
  « profil repris par un autre serveur »). `BrainRotRoyale.rbxlx` les contient : republier par
  Fichier > Publier sur Roblox > Mettre a jour l'experience existante, ou SANS Studio :
  `python tools/publier_place.py` (reconstruit puis publie par l'API Open Cloud ; cle dans la
  variable `ROBLOX_API_KEY`, droit « universe-places » en ecriture sur l'experience ; jamais
  affichee). Banc hors ligne : `tools/test_publier_place.py` (faux serveur local).

### A faire avec TON compte (rien n'est vendu tant que ce n'est pas fait)
0. **Eligibilite** (obligatoire depuis le 17/12/2025 pour publier ou mettre a jour une experience
   PUBLIQUE) : verification d'identite, OU un achat en argent reel sur le compte depuis le
   01/01/2025. A verifier sur create.roblox.com/settings/eligibility/public-publish.
1. Publier le jeu (Fichier > Publier sur Roblox). Sans publication, la sauvegarde est refusee
   (« You must publish this place to the web to access DataStore »).
2. Parametres du jeu > Securite : cocher **Enable Studio Access to API Services** pour tester la sauvegarde dans Studio.
3. create.roblox.com > l'experience : remplir le **questionnaire de maturite et de conformite**
   (obligatoire ; c'est une declaration du proprietaire du compte, elle ne se delegue pas).
4. create.roblox.com > l'experience > Monetization — 3 **Developer Products** et 2 **Game Passes**,
   identifiants a reporter dans `src/server/Economie.lua` puis `python build.py` et republier :
   - `Economie.PRODUITS[1]` « Sac de 500 pieces », `[2]` « Coffre de 1500 pieces »,
     `[3]` « Poignee de 80 gemmes » ;
   - `Economie.PASS_VIP` « VIP » (pieces x2) ; `Economie.PASS_SAISON` « Pass de saison premium ».
   Tant qu'un identifiant vaut 0, l'offre est masquee. Les prix sont un choix du createur.
5. Encaisser en argent reel (DevEx) : au moins 30 000 Robux GAGNES, 13 ans ou plus, e-mail
   verifie, formulaire fiscal W-8 (hors Etats-Unis). Taux standard 0,0038 $ par Robux gagne.

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
