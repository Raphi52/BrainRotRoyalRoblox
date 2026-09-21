# -*- coding: utf-8 -*-
"""QUI EST EN FACE (src/shared/Adversaire.lua + branchement).

Le defaut corrige : le seul indice qu'on affrontait une machine etait le mot « Bot » dans la ligne
de score, a cote d'un pseudo. Un joueur pouvait enchainer des parties contre le robot sans le
savoir — et perdre contre « quelqu'un » qui n'existe pas donne l'impression d'un jeu truque.

1) Les regles PURES sont EXECUTEES (lupa) : reconnaissance du robot, nom avec son NIVEAU, badge,
   annonce du coup d'envoi, compte a rebours de la recherche, mention dans le bilan.
2) Le branchement est lu : le serveur envoie les trois informations, le client les affiche SANS
   repeter l'annonce, le hub annonce la bascule vers le robot avant qu'elle n'arrive.
"""
import sys, pathlib, re
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
AD = (R / "src/shared/Adversaire.lua").read_text(encoding="utf-8")
ROB = (R / "src/shared/Robot.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
HUB = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(AD)

# TOUTES LES FONCTIONS EXISTENT DES LE CHARGEMENT, avant le moindre appel. Defaut mesure le
# 2026-09-21 : deux fonctions avaient ete inserees PAR ERREUR a l'interieur d'une branche de
# `Adversaire.nom` ; elles n'existaient qu'une fois `nom` appele avec un palier. Ce banc appelait
# `nom` plus haut, les definissait par effet de bord, et passait VERT — tandis que le serveur,
# lui, plantait a chaque etat (« GameServer:3494 : attempt to call a nil value », 150 fois) et
# que le client restait fige. On controle donc sur un module FRAIS, jamais appele.
_frais = LuaRuntime().execute(AD)
_absentes = [n for n in re.findall(r"^function Adversaire\.(\w+)", AD, re.M) if _frais[n] is None]

# --- RECONNAITRE LE ROBOT -----------------------------------------------------------------------
if M.estRobot("Alice") is not False:
    e.append("un pseudo doit etre reconnu comme humain")
for vide in (None, "", 42, True):
    if M.estRobot(vide) is not True:
        e.append(f"sans pseudo ({vide!r}), c'est le robot")

# --- LE NOM PORTE LE NIVEAU ---------------------------------------------------------------------
if M.nom("Alice") != "Alice":
    e.append("le pseudo d'un humain doit etre rendu tel quel")
if M.nom("Alice", "expert") != "Alice":
    e.append("un humain ne doit jamais porter un niveau de robot")
n = M.nom(None, "aguerri")
if "aguerri" not in n or M.NOM_ROBOT not in n:
    e.append(f"le robot doit annoncer son NIVEAU, obtenu : {n}")
if M.nom(None) != M.NOM_ROBOT:
    e.append("sans palier connu, on affiche le robot sans niveau invente")
if M.nom(None, "palier-inconnu") != M.NOM_ROBOT:
    e.append("un palier inconnu ne doit pas etre affiche brut a l'ecran")
# Les paliers du module Robot doivent TOUS avoir une traduction : sinon le joueur verrait « Robot »
# tout court sur certains niveaux, sans savoir pourquoi.
for palier in ("debutant", "normal", "aguerri", "expert"):
    if f'nom = "{palier}"' not in ROB:
        e.append(f"le palier {palier} n'existe plus dans Robot.lua : la traduction est perimee")
    if M.NIVEAUX[palier] is None:
        e.append(f"le palier {palier} n'a aucun libelle")

# --- BADGE ET ANNONCE ---------------------------------------------------------------------------
if M.badge("Alice") is not None:
    e.append("aucun badge face a un humain")
if M.badge(None) != "ROBOT":
    e.append("le badge doit nommer la machine")
if M.annonce("Alice", "expert") is not None:
    e.append("on n'annonce pas ce qui va de soi (adversaire humain)")
a = M.annonce(None, "normal")
if not a or "robot" not in a.lower() or "normal" not in a:
    e.append(f"l'annonce doit nommer le robot ET son niveau, obtenu : {a}")
if M.annonce(None) is None or "robot" not in M.annonce(None).lower():
    e.append("sans palier, l'annonce doit quand meme dire que c'est un robot")

# --- ATTENTE : LA BASCULE S'ANNONCE -------------------------------------------------------------
t = M.attente(12)
if "12" not in t or "robot" not in t.lower():
    e.append(f"pendant la recherche, le compte a rebours vers le robot doit etre dit : {t}")
if M.attente(0) == t:
    e.append("a zero, le message doit changer (le robot est la)")
if "robot" not in M.attente(0).lower():
    e.append("a zero, on doit dire qu'on affronte le robot")
if M.attente(-5) != M.attente(0):
    e.append("un temps negatif doit se comporter comme zero")
if "1" not in M.attente(0.2):
    e.append("une fraction de seconde doit s'arrondir VERS LE HAUT (0,2 s -> 1 s)")

# --- FICHE : QUI EST EN FACE, EN CHIFFRES ------------------------------------------------------
f = M.fiche("Alice", None, 640, 3)
if "Alice" not in f or "640" not in f or "3" not in f:
    e.append(f"la fiche doit porter le nom, les trophees et le niveau : {f}")
if M.fiche("Alice", None, None, None) != "Alice":
    e.append("sans chiffres connus, on n'invente rien — le nom suffit")
if "trophees" in M.fiche("Alice", None, None, 3):
    e.append("des trophees inconnus ne doivent pas apparaitre a zero")
fr = M.fiche(None, "aguerri", None, 3)
if "aguerri" not in fr:
    e.append("le robot doit annoncer son palier dans sa fiche")
if "trophees" in fr:
    e.append("le robot n'a pas de trophees : ne pas en inventer")
if M.fiche("Alice", None, 640.7, 3.9) != M.fiche("Alice", None, 640, 3):
    e.append("les chiffres doivent etre tronques proprement, sans decimales a l'ecran")

# --- ECART DE NIVEAU, DIT FRANCHEMENT -----------------------------------------------------------
if M.ecartNiveau(3, 3) is not None or M.ecartNiveau(3, 4) is not None:
    e.append("un ecart d'un niveau ne merite pas d'etre signale (on ne cherche pas d'excuse)")
plus = M.ecartNiveau(1, 3)
if not plus or "2" not in plus:
    e.append(f"deux niveaux de retard doivent etre dits : {plus}")
moins = M.ecartNiveau(5, 3)
if not moins or moins == plus:
    e.append("l'avantage doit etre dit aussi, et autrement que le retard")
if M.ecartNiveau(None, 3) is not None or M.ecartNiveau(3, None) is not None:
    e.append("sans niveau connu des deux cotes, on ne dit rien")
if M.ECART_NOTABLE < 2:
    e.append("signaler un seul niveau d'ecart serait du bruit")

# --- MENTION DANS LE BILAN ----------------------------------------------------------------------
if M.mention("Alice") is not None:
    e.append("aucune mention pour une partie contre un humain")
if not M.mention(None) or "robot" not in M.mention(None).lower():
    e.append("le bilan doit rappeler que la partie etait contre le robot")

# --- BRANCHEMENT --------------------------------------------------------------------------------
if 'item("ModuleScript", "Adversaire"' not in B:
    e.append("build : Adversaire non embarque")
if 'WaitForChild("Adversaire")' not in S:
    e.append("serveur : module Adversaire non requis")
if 'return adversaire and adversaire.DisplayName or "Bot"' in S:
    e.append("serveur : l'ancien « Bot » tout court est encore affiche")
# LIGNE DE SCORE : nom COURT (le palier vit dans la fiche, sinon le texte deborde).
if "Adversaire.nomCourt(adversaire and adversaire.DisplayName)" not in S:
    e.append("serveur : la ligne de score ne porte pas le nom court")
if M.nomCourt(None) != M.NOM_ROBOT or M.nomCourt("Alice") != "Alice":
    e.append("le nom court doit rester lisible pour les deux cas")
if "(" in M.nomCourt(None):
    e.append("le nom court ne doit pas trainer un palier entre parentheses")
for champ in ("annonceAdversaire = Adversaire.annonce(",
              "mentionAdversaire = occupant[3 - monCamp]",
              "ficheAdversaire = Adversaire.fiche("):
    if champ not in S:
        e.append("serveur : champ manquant dans l'etat -> " + champ)
# fix-ok mesure a l'ecran (2026-09-20) : le badge pose a cote du score en RECOUVRAIT la fin, et
# l'information apparaissait deux fois. Il vit desormais en tete de la fiche.
if "badgeAdversaire" in C:
    e.append("client : le badge separe est revenu — il recouvre la ligne de score")
if M.badge(None) not in M.fiche(None, "aguerri", None, 3):
    e.append("la fiche doit porter la mention ROBOT (le badge separe a ete retire)")
if M.badge("Alice") is not None or M.badge("Alice") == M.badge(None):
    e.append("un humain ne doit porter aucune mention de machine")
if "annonceAdversaireVue" not in C:
    e.append("client : l'annonce serait repetee a chaque etat (10 fois par seconde)")
if "annoncer(s.annonceAdversaire)" not in C:
    e.append("client : l'annonce du coup d'envoi n'est pas jouee")
if "ficheAdversaire = Adversaire.fiche(" not in S:
    e.append("serveur : la fiche de l'adversaire n'est pas envoyee")
if "ecartNiveau = Adversaire.ecartNiveau(" not in S:
    e.append("serveur : l'ecart de niveau n'est pas calcule")
if "hud.ficheAdversaire.Text = (not s.spectateur and s.ficheAdversaire)" not in C:
    e.append("client : la fiche n'est pas affichee, ou le serait pour un spectateur")
if "ecartNiveauVu" not in C:
    e.append("client : l'ecart de niveau serait repete a chaque etat")
if "s.mentionAdversaire" not in C:
    e.append("client : le bilan ne rappelle pas que c'etait le robot")
# Le compte a rebours vient desormais du SERVEUR (il depend du choix « attendre un humain ») :
# on verifie que la bascule est annoncee, pas la facon de calculer le temps.
if "Adversaire.attente(" not in HUB:
    e.append("hub : la bascule vers le robot n'est pas annoncee pendant la recherche")
if "Personne pour l'instant : tu affrontes le robot\"" in HUB:
    e.append("hub : l'ancien message en dur est encore la (deux sources de verite)")

# BONUS CONTRE UN JOUEUR. Defaut mesure le 2026-09-21 : une victoire contre un humain rapporte
# 20 pieces de plus (Economie), et ce n'etait dit NULLE PART — ni avant de choisir le robot, ni
# apres la partie. Le joueur prenait le robot par facilite sans savoir ce qu'il y laissait.
ECO = (R / "src" / "server" / "Economie.lua").read_text(encoding="utf-8")
if M.mention(None, 20, True) != "(contre le robot : pas de bonus de +20)":
    e.append("une victoire contre le robot doit dire le bonus manque")
if M.mention("Alice", 20, True) != "(victoire contre un joueur : +20 pieces de bonus)":
    e.append("une victoire contre un joueur doit dire son bonus")
if M.mention("Alice", 20, False) is not None:
    e.append("une defaite contre un joueur n'a pas de bonus a annoncer")
if M.mention(None, 20, False) != "(partie contre le robot)":
    e.append("une defaite contre le robot garde la mention simple")
if M.mention(None) != "(partie contre le robot)" or M.mention("Alice") is not None:
    e.append("sans bonus fourni, la mention doit rester celle d'avant")
if "+20" not in M.texteAttente(False, 20) or "+20" not in M.texteAttente(True, 20):
    e.append("le reglage d'attente doit annoncer le bonus, dans les deux positions")
if "+" in M.texteAttente(False, 0):
    e.append("sans bonus, le reglage n'invente pas de gain")
# TROPHEES CONTRE LE ROBOT (regle Arenes.PART_ROBOT, posee le 2026-09-21) : l'ecran de fin montrait
# « +10 trophees » sans dire pourquoi pas 30, et rien ne le disait avant de choisir le robot.
ARE = (R / "src" / "shared" / "Arenes.lua").read_text(encoding="utf-8")
if M.diviseurRobot(1 / 3) != 3:
    e.append("une part de 1/3 doit se lire « divises par 3 »")
if M.diviseurRobot(1) is not None or M.diviseurRobot(None) is not None:
    e.append("sans reduction, aucun diviseur a annoncer")
if M.mention(None, 20, True, 1 / 3) != "(contre le robot : trophees divises par 3, pas de bonus de +20)":
    e.append("la victoire contre le robot doit dire les trophees divises ET le bonus manque")
if "3 fois plus de trophees" not in M.texteAttente(False, 20, 1 / 3):
    e.append("le reglage d'attente doit dire que le joueur rapporte plus de trophees")
if "partRobot = Arenes.PART_ROBOT," not in ECO:
    e.append("serveur : la part des trophees contre le robot n'est pas envoyee a l'ecran")
if "Arenes.PART_ROBOT = 1 / 3" not in ARE:
    e.append("la regle lue n'est plus celle d'Arenes : l'annonce ne suivrait plus le jeu")
if "Economie.BONUS_HUMAIN = BONUS_HUMAIN" not in ECO or "bonusHumain = BONUS_HUMAIN," not in ECO:
    e.append("serveur : le bonus n'est pas expose a l'ecran")
if "Adversaire.mention(nil, Economie.BONUS_HUMAIN, vainqueur ~= nil and vainqueur == monCamp, Arenes.PART_ROBOT)" not in S:
    e.append("serveur : la mention de fin ne recoit ni le bonus ni l'issue")
if ".texteAttente(attendreHumain, vue and vue.bonusHumain, vue and vue.partRobot)" not in HUB:
    e.append("hub : le reglage d'attente ne dit pas ce qu'il change")

# ENJEU EN TROPHEES. Regle Arenes du 2026-09-21 : contre un joueur, l'enjeu suit l'ecart de
# trophees ; contre le robot, le tiers. Rien ne l'affichait : on decouvrait son gain a la fin.
if M.enjeu(38, -11) != "Enjeu : +38 trophees si tu gagnes, -11 si tu perds":
    e.append("l'enjeu doit donner le gain ET la perte")
if M.enjeu(10, 0) != "Enjeu : +10 trophees si tu gagnes":
    e.append("sans perte possible (plancher), l'enjeu ne promet pas de perte")
if M.enjeu(0, 0) != "":
    e.append("sans enjeu, aucune ligne")
if M.raisonEnjeu(1.27) != "adversaire plus fort : +27 % de trophees":
    e.append("un enjeu gonfle doit dire que l'adversaire est plus fort")
if M.raisonEnjeu(0.8) != "adversaire plus faible : -20 % de trophees":
    e.append("un enjeu reduit doit dire que l'adversaire est plus faible")
if M.raisonEnjeu(1.02) is not None:
    e.append("un enjeu ordinaire ne se commente pas")
if M.mentionJoueur("Alice", 20, True, 1.3) != "(victoire contre un joueur : +20 pieces de bonus, adversaire plus fort : +30 % de trophees)":
    e.append("la fin contre un joueur doit expliquer un gain gonfle")
if M.mentionJoueur("Alice", 20, False, 1.3) is not None:
    e.append("une defaite ne commente pas le gain qu'elle n'a pas eu")
if "enjeu = (not result) and Adversaire.enjeu(" not in S or 'Arenes.variation("victoire"' not in S:
    e.append("serveur : l'enjeu n'est pas calcule avec la regle reelle, ou reste affiche apres la fin")
if "hud.enjeuLabel.Text = (not s.spectateur and s.enjeu)" not in C:
    e.append("client : l'enjeu n'est pas affiche pendant le duel")

if _absentes:
    e.append("fonctions absentes au chargement (definies dans une branche ?) : " + ", ".join(_absentes))

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : on sait toujours si l'on affronte un humain ou le robot, et a quel niveau")
sys.exit(1 if e else 0)
