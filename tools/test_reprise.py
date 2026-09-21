# -*- coding: utf-8 -*-
"""REPRISE APRES COUPURE (src/shared/Reprise.lua + branchement).

Le defaut corrige : le serveur traitait une COUPURE RESEAU comme un depart — forfait immediat,
victoire a l'autre. Deux secondes de wifi perdues valaient une defaite definitive.

1) Les regles PURES sont EXECUTEES (lupa) : quand la grace s'ouvre, combien de temps elle dure,
   qui peut reprendre le camp, et qui a le droit d'y jouer pendant l'absence.
2) Le branchement est lu : deconnexion et bouton MENU prennent des chemins DIFFERENTS, le robot
   ne prend pas un camp reserve, le retour rend le camp sans remise a neuf, et l'adversaire est prevenu.
"""
import re, sys, pathlib
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import zone  # decoupe par CONTENU (voir tools/bancs.py)
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
RP = (R / "src/shared/Reprise.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(RP)
D = M.DELAI

# --- QUAND LA GRACE S'OUVRE ---------------------------------------------------------------------
if M.permise(False, True, False) is not True:
    e.append("une coupure en duel humain doit ouvrir un delai de grace")
if M.permise(False, True, True) is not False:
    e.append("le bouton MENU reste un ABANDON : aucune grace (sinon on annule une defaite en partant)")
if M.permise(True, True, False) is not False:
    e.append("apres la fin de partie, aucune grace a ouvrir")
if M.permise(False, False, False) is not False:
    e.append("contre le robot, partir n'a aucune consequence : rien a reserver")

# --- DUREE ET EXPIRATION ------------------------------------------------------------------------
j = M.ouvrir(1, 42, 100.0)
if j.camp != 1 or j.userId != "42":
    e.append("le jeton doit porter le camp et le joueur")
if abs(M.reste(j, 100.0) - D) > 1e-9:
    e.append("a l'instant de la coupure, tout le delai doit rester")
if abs(M.reste(j, 100.0 + D / 2) - D / 2) > 1e-9:
    e.append("le temps restant doit decroitre")
if M.reste(j, 100.0 + D + 10) != 0:
    e.append("le temps restant ne descend jamais sous zero")
if M.expire(j, 100.0 + D - 0.1) is not False:
    e.append("le jeton ne doit pas expirer avant son delai")
if M.expire(j, 100.0 + D) is not True:
    e.append("le jeton doit expirer AU delai")
if M.reste(None, 0) != 0 or M.expire(None, 0) is not True:
    e.append("sans jeton, il n'y a rien a reprendre")

# --- QUI PEUT REPRENDRE LE CAMP -----------------------------------------------------------------
if M.correspond(j, 42, 110.0) is not True:
    e.append("le MEME joueur doit pouvoir reprendre son camp")
if M.correspond(j, "42", 110.0) is not True:
    e.append("l'identifiant doit etre compare en texte (userId arrive parfois en nombre)")
if M.correspond(j, 43, 110.0) is not False:
    e.append("un AUTRE joueur ne doit jamais recuperer un camp qui n'est pas le sien")
if M.correspond(j, 42, 100.0 + D + 1) is not False:
    e.append("passe le delai, plus personne ne reprend")
jetons = lua.eval("function(j) return { [1] = j } end")(j)
if M.campDe(jetons, 42, 110.0) != 1:
    e.append("campDe doit retrouver le camp du joueur qui revient")
if M.campDe(jetons, 43, 110.0) is not None:
    e.append("campDe ne doit rien rendre a un inconnu")
if M.campDe(jetons, 42, 100.0 + D + 1) is not None:
    e.append("campDe ne doit rien rendre apres expiration")
if M.campDe(lua.eval("function() return {} end")(), 42, 0) is not None:
    e.append("sans aucun jeton, aucun camp a reprendre")

# --- PENDANT L'ABSENCE, PERSONNE NE JOUE CE CAMP ------------------------------------------------
if M.robotAutorise(j) is not False:
    e.append("le robot ne doit PAS jouer un camp reserve (il depenserait l'elixir du joueur absent)")
if M.robotAutorise(None) is not True:
    e.append("sans reserve, le robot reprend le camp comme avant")

# --- CE QU'ON DIT A L'ADVERSAIRE ----------------------------------------------------------------
t = M.texteAbsence(12.3)
if not t or "13" not in t:
    e.append(f"le temps restant doit etre annonce, arrondi vers le haut, obtenu : {t}")
if M.texteAbsence(0) is not None or M.texteAbsence(None) is not None:
    e.append("sans temps restant, aucun message")

# --- BRANCHEMENT SERVEUR ------------------------------------------------------------------------
if 'WaitForChild("Reprise")' not in S:
    e.append("serveur : module Reprise non requis")
if 'item("ModuleScript", "Reprise"' not in B:
    e.append("build : Reprise non embarque (le serveur resterait bloque)")
if not re.search(r"quitter\(player, false\)", S):
    e.append("serveur : une DECONNEXION doit passer en depart NON volontaire")
if not re.search(r"quitter\(player, true\)", S):
    e.append("serveur : le bouton MENU doit rester un abandon volontaire")
# La grace passe par la REGLE (et non par un test ecrit a la main). Le deuxieme argument dit
# desormais « ce duel est-il entre humains », presents ou en train de revenir — cf. le cas double.
if "Reprise.permise(result ~= nil," not in S or "volontaire == true)" not in S:
    e.append("serveur : la grace n'est pas decidee par la regle")
if "reprises[camp] = Reprise.ouvrir(camp, player.UserId, os.clock())" not in S:
    e.append("serveur : aucun camp n'est mis de cote a la coupure")
if "local repris = Reprise.campDe(reprises, player.UserId, os.clock())" not in S:
    e.append("serveur : le joueur qui revient ne retrouve pas son camp")
if not re.search(r"if repris then\s*\n(?:.*\n)*?\s*occupant\[repris\] = player", S):
    e.append("serveur : le camp repris n'est pas rendu au joueur")
if "Reprise.robotAutorise(reprises[camp])" not in S:
    e.append("serveur : le robot prendrait la place du joueur coupe")
if not re.search(r"if Reprise\.expire\(jeton, os\.clock\(\)\) then", S):
    e.append("serveur : le delai de grace n'expire jamais (la partie resterait suspendue)")
if "humainAbsent[3 - camp] == true" not in S:
    e.append("serveur : l'adversaire perdrait son bonus « contre un humain » a cause d'une coupure")
if "adversaireAbsent = reprises[3 - monCamp]" not in S:
    e.append("serveur : l'adversaire n'est pas prevenu de la coupure d'en face")
# Fenetre elargie le 2026-09-21 : l'assertion cherchait la remise a zero dans les 600
# premiers caracteres de resetMatch. Ajouter un commentaire ou une ligne en tete de la
# fonction faisait donc echouer un banc alors que le code etait juste — une assertion qui
# depend de la POSITION du code, pas de son contenu. On lit maintenant le corps entier.
if "reprises = {}" not in S.split("local function resetMatch")[1].split(chr(10) + "end")[0]:
    e.append("serveur : les reserves ne sont pas remises a zero a la partie suivante")
# Garde-fou : la reprise ne doit PAS repasser par une remise a neuf de la partie.
bloc = S.split("local repris = Reprise.campDe")[1].split("return repris")[0]
if "resetMatch" in bloc:
    e.append("serveur : revenir effacerait la partie de celui qui est reste")

# --- LA PARTIE SE MET EN PAUSE PENDANT L'ABSENCE -------------------------------------------------
# Le defaut mesure le 2026-09-21 en relisant la boucle de partie : le chrono continuait de tourner
# et les unites deja posees frappaient les tours de l'absent. Au retour, il recuperait une partie
# ou il avait encaisse 45 s de degats sans pouvoir se defendre — une reprise pour rien.
if M.pausePermise(0) is not True:
    e.append("une premiere coupure doit mettre la partie en pause")
# ANTI-ABUS : couper son reseau quand on est en difficulte ne doit pas devenir une tactique.
if M.pausePermise(M.PAUSES_MAX) is not False:
    e.append("un joueur pourrait mettre la partie en pause autant de fois qu'il veut")
if M.PAUSES_MAX > 1:
    e.append("plus d'une pause par partie rend la coupure volontaire rentable")
for mauvais in (None, -3, "deux"):
    if M.pausePermise(mauvais) is not True:
        e.append("un compteur absent doit valoir zero pause utilisee, pas un refus")

# Le mot PAUSE doit apparaitre : sans lui, la victime croit que SON jeu a gele et quitte.
tp = M.textePause(30)
if not tp or "pause" not in tp.lower():
    e.append("le message de pause ne dit pas que la partie est en pause : %r" % tp)
if tp and "30" not in tp:
    e.append("le message de pause doit donner le temps restant : %r" % tp)
if M.textePause(0) is not None or M.textePause(None) is not None:
    e.append("aucun message de pause quand il n'y a plus de delai")
if tp == M.texteAbsence(30):
    e.append("pause et simple absence doivent se distinguer : rien ne bouge dans un cas, pas l'autre")

# --- BRANCHEMENT SERVEUR DE LA PAUSE --------------------------------------------------------------
if "Reprise.pausePermise(eq.pauses or 0)" not in S:
    e.append("serveur : la pause n'est jamais decidee")
# Le compteur vit dans l'equipe, recreee a chaque partie : « une pause par PARTIE » sans remise a zero.
if "eq.pauses = (eq.pauses or 0) + 1" not in S:
    e.append("serveur : les pauses ne sont pas comptees, l'anti-abus ne tient pas")
if "geleDepart = true" not in zone(S, "-- PARTIE EN PAUSE", "if geleDepart then"):
    e.append("serveur : la partie ne gele pas pendant l'absence")
# Elle repart dans les DEUX cas : retour du joueur, ou delai ecoule.
if "teams[repris].enPause = nil" not in S:
    e.append("serveur : la partie resterait gelee apres son retour")
if "teams[camp].enPause = nil" not in S:
    e.append("serveur : la partie resterait gelee alors que le delai est ecoule")
# La victime voit le mot PAUSE, pas le message d'absence ordinaire.
if "Reprise.textePause(Reprise.reste(reprises[3 - monCamp]" not in S:
    e.append("serveur : la victime ne sait pas que la partie est en pause")

# --- LES DEUX JOUEURS SAUTENT EN MEME TEMPS -------------------------------------------------------
# Cas tres ordinaire : un serveur qui tombe, une box qui redemarre, deux joueurs sur le meme
# reseau. Le serveur produisait DEUX injustices, mesurees le 2026-09-21 en le relisant.

# 1) LE SECOND A SAUTER n'avait droit a aucune reprise : on exigeait un adversaire PRESENT, or le
#    premier venait justement de partir. Il perdait son camp alors qu'il avait saute comme l'autre.
if M.duelHumain(True, False) is not True:
    e.append("un adversaire present fait bien un duel entre humains")
if M.duelHumain(False, True) is not True:
    e.append("le second a sauter doit garder son camp : l'autre est absent, mais il peut revenir")
if M.duelHumain(False, False) is not False:
    e.append("sans humain en face ni reprise ouverte, ce n'est plus un duel entre humains")
# La regle de reprise doit alors s'appliquer au second aussi.
if M.permise(False, M.duelHumain(False, True), False) is not True:
    e.append("le second a sauter n'obtient pas de reprise")
# Mais un depart VOLONTAIRE reste un abandon, meme quand l'autre est deja absent.
if M.permise(False, M.duelHumain(False, True), True) is not False:
    e.append("quitter par le menu reste un abandon, meme si l'autre a saute")

# 2) A L'EXPIRATION, la victoire n'etait donnee que s'il restait quelqu'un. Personne n'etant la,
#    AUCUNE fin n'etait declenchee : la partie restait gelee indefiniment.
if M.vainqueurApres(1, True) != 2:
    e.append("si l'autre est la, il gagne quand le delai expire")
if M.vainqueurApres(2, True) != 1:
    e.append("la victoire doit revenir au camp reste, quel que soit le camp absent")
# Personne en face : aucun vainqueur. On ne peut pas savoir qui l'aurait emporte, et c'est souvent
# le reseau — pas un joueur — qui a lache.
if M.vainqueurApres(1, False) is not None:
    e.append("personne ne doit gagner quand les deux ont saute")
if M.partieAbandonnee(True, True) is not True:
    e.append("deux camps vides : la partie doit etre rendue au serveur")
for a, b in ((True, False), (False, True), (False, False)):
    if M.partieAbandonnee(a, b) is not False:
        e.append("une partie avec encore un joueur ne doit pas etre annulee (%r, %r)" % (a, b))

# --- BRANCHEMENT SERVEUR DU CAS DOUBLE ------------------------------------------------------------
if "Reprise.duelHumain(occupant[3 - camp] ~= nil, reprises[3 - camp] ~= nil)" not in S:
    e.append("serveur : le second a sauter perdrait encore son camp")
if "Reprise.vainqueurApres(camp, occupant[3 - camp] ~= nil)" not in S:
    e.append("serveur : la victoire a l'expiration ne passe pas par la regle")
# Fenetre = la BOUCLE d'expiration, delimitee par son contenu et non par un nombre de caracteres.
# Un plafond fixe (1400) faisait echouer ce banc des qu'on ajoutait un commentaire dans la boucle,
# alors que le code etait juste : une assertion qui depend de la POSITION du code (2026-09-21).
bloc_exp = S.split("DELAI DE GRACE ECOULE")[1].split("-- Le bot ne remplace que le camp")[0]
if "Reprise.partieAbandonnee(occupant[1] == nil, occupant[2] == nil)" not in bloc_exp:
    e.append("serveur : une partie sans personne resterait gelee pour toujours")
if "resetMatch()" not in bloc_exp:
    e.append("serveur : la partie abandonnee n'est pas rendue au serveur")
# Aucun endMatch ne doit etre appele quand il n'y a pas de vainqueur : ce serait une defaite pour
# quelqu'un qui n'est meme plus la.
if "if not result and gagnant then" not in bloc_exp:
    e.append("serveur : une fin serait declenchee sans vainqueur")

# --- BRANCHEMENT CLIENT -------------------------------------------------------------------------
if "s.adversaireAbsent" not in C:
    e.append("client : la coupure d'en face n'est pas affichee")
if not re.search(r"attenteLabel\.Text = s\.adversaireAbsent", C):
    e.append("client : le message d'absence n'est pas ecrit a l'ecran")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : une coupure laisse son camp au joueur, et seul son silence prolonge donne la partie")
sys.exit(1 if e else 0)
