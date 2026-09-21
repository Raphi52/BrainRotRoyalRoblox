# -*- coding: utf-8 -*-
"""ATTENDRE UN HUMAIN PLUTOT QUE LE ROBOT (src/server/Matchmaking.lua + branchement).

Le defaut corrige : au bout de 20 s, la bascule vers le robot etait SUBIE. Un joueur qui voulait
un vrai adversaire n'avait aucun moyen de le dire — et se retrouvait contre une machine.

Le piege de la correction : « attendre un humain » sans limite ni sortie serait un piege. D'ou
DEUX garde-fous testes ici : un plafond d'attente, et un bouton pour prendre le robot tout de suite.

1) Les regles PURES sont EXECUTEES (lupa).
2) Le branchement est lu : le choix voyage depuis le hub, la sortie de secours existe, et le temps
   restant est ANNONCE au lieu d'etre subi.
"""
import sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
MM = (R / "src/server/Matchmaking.lua").read_text(encoding="utf-8")
GS = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
HUB = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(MM)
COURT, LONG = M.ATTENTE_MAX, M.ATTENTE_PATIENTE

# --- LE SEUIL DEPEND DU CHOIX -------------------------------------------------------------------
if M.robotDu(0, COURT - 0.1, False) is not False:
    e.append("sans patience, le robot ne doit pas arriver avant le seuil")
if M.robotDu(0, COURT, False) is not True:
    e.append("sans patience, le robot arrive AU seuil (comportement d'origine)")
if M.robotDu(0, COURT, True) is not False:
    e.append("AVEC patience, le robot ne doit PAS arriver a 20 s — c'est tout l'objet du choix")
if M.robotDu(0, LONG, True) is not True:
    e.append("le plafond d'attente patiente doit finir par donner le robot")
if M.robotDu(0, LONG - 1, True) is not False:
    e.append("juste avant le plafond, on attend encore")
# L'ancien appel a deux arguments doit continuer a marcher (aucune regression).
if M.robotDu(0, COURT) is not True or M.robotDu(0, COURT - 1) is not False:
    e.append("l'appel d'origine (sans patience) doit garder son comportement")
if not (LONG > COURT * 3):
    e.append("un plafond patient a peine plus long que 20 s ne sert a rien")
if LONG > 600:
    e.append("au-dela de dix minutes, ce n'est plus une attente, c'est un abandon")

# --- TEMPS RESTANT, POUR L'ANNONCER -------------------------------------------------------------
if M.avantRobot(0, 0, False) != COURT:
    e.append("au depart, tout le delai reste")
if M.avantRobot(0, 5, False) != COURT - 5:
    e.append("le temps restant doit decroitre")
if M.avantRobot(0, 999, False) != 0:
    e.append("le temps restant ne descend jamais sous zero")
if M.avantRobot(0, 30, True) != LONG - 30:
    e.append("en mode patient, le compte a rebours doit suivre le plafond long")

# --- SORTIE DE SECOURS --------------------------------------------------------------------------
if "function M.robotMaintenant(player, robot)" not in MM:
    e.append("aucune sortie de secours : « attendre un humain » serait un piege de 3 minutes")
bloc = MM.split("function M.robotMaintenant")[1].split("function M.resteAvantRobot")[0]
if 'etat.etat == "attente"' not in bloc:
    e.append("prendre le robot ne doit marcher que pendant l'attente")
if "sortirDeLaFile(player)" not in bloc:
    e.append("prendre le robot doit RETIRER le joueur de la file (sinon il reste appariable)")
if "robot(player)" not in bloc:
    e.append("prendre le robot doit reellement lancer la partie")

# --- BRANCHEMENT SERVEUR ------------------------------------------------------------------------
if "function M.entrer(player, robot, profil, patient)" not in MM:
    e.append("matchmaking : le choix n'atteint pas la file")
if 'patient = patient == true' not in MM:
    e.append("matchmaking : la patience n'est pas retenue pour ce joueur")
if "M.robotDu(etat.debut, os.clock(), etat.patient)" not in MM:
    e.append("matchmaking : le tour de recherche ignore la patience")
if 'end, arg == "patient")' not in GS:
    e.append("serveur : JOUER ne transmet pas le choix du joueur")
if 'action == "robotMaintenant"' not in GS or "Matchmaking.robotMaintenant(player, rejoindre)" not in GS:
    e.append("serveur : la sortie de secours n'est pas exposee")
if "avantRobot = math.ceil(Matchmaking.resteAvantRobot(player))" not in GS:
    e.append("serveur : le temps restant n'est pas envoye (la bascule resterait une surprise)")

# --- BRANCHEMENT HUB ----------------------------------------------------------------------------
if "attendreHumain" not in HUB or "boutonPatience" not in HUB:
    e.append("hub : aucun reglage pour attendre un humain")
if '"jouer", attendreHumain and "patient" or nil' not in HUB:
    e.append("hub : le choix n'est pas envoye avec la demande de partie")
if "boutonRobotVite" not in HUB or 'InvokeServer("robotMaintenant")' not in HUB:
    e.append("hub : aucun bouton pour prendre le robot tout de suite")
if "r2.avantRobot or 0" not in HUB:
    e.append("hub : le compte a rebours affiche n'est pas celui du serveur")
if "robot dans %d s" not in HUB:
    e.append("hub : en attente patiente, le joueur ne voit pas quand le robot arrivera")
if "boutonRobotVite.Visible = false" not in HUB:
    e.append("hub : la sortie de secours resterait affichee hors recherche")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : attendre un humain est un CHOIX, borne dans le temps et quittable a tout moment")
sys.exit(1 if e else 0)
