# -*- coding: utf-8 -*-
"""QUALITE DE LA CONNEXION (src/shared/Reseau.lua + branchement).

Le defaut corrige : rien ne disait au joueur que SA connexion decrochait. Une pose qui arrive en
retard lui faisait conclure que le jeu est casse — ou que l'adversaire triche.

1) Les regles PURES sont EXECUTEES (lupa) : seuils, mediane resistante aux pics, fenetre glissante
   bornee, detection d'INSTABILITE (l'ecart, pas la lenteur), silence du serveur, phrases.
2) Le branchement est lu : le serveur fait un ECHO borne en cadence, le client mesure un vrai
   aller-retour, affiche le chiffre et l'avertissement, et suit la derniere arrivee d'etat.
"""
import re, sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
RE_ = (R / "src/shared/Reseau.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(RE_)
def liste(vals):
    t = lua.eval("function() return {} end")()
    for i, v in enumerate(vals, 1):
        t[i] = v
    return t
def py(t):
    return [t[i] for i in range(1, len(t) + 1)]

# --- SEUILS -------------------------------------------------------------------------------------
if not (M.BON < M.MOYEN < M.MAUVAIS):
    e.append("les seuils doivent etre ordonnes")
for ms, attendu in ((0, "bon"), (M.BON, "bon"), (M.BON + 1, "moyen"), (M.MOYEN, "moyen"),
                    (M.MOYEN + 1, "mauvais"), (2000, "mauvais")):
    if M.qualite(ms) != attendu:
        e.append(f"qualite({ms}) attendue {attendu}, obtenue {M.qualite(ms)}")
couleurs = {q: tuple(py(M.couleur(q))) for q in ("bon", "moyen", "mauvais")}
if len(set(couleurs.values())) != 3:
    e.append("les trois qualites doivent avoir trois couleurs distinctes")
if M.couleur("inconnu") is None:
    e.append("une qualite inconnue doit quand meme rendre une couleur (aucun ecran vide)")

# --- MEDIANE : un pic ne doit pas faire clignoter l'indicateur ----------------------------------
if M.mediane(liste([])) is not None:
    e.append("sans mesure, il n'y a pas de latence a afficher")
if M.mediane(liste([40])) != 40:
    e.append("une seule mesure doit etre rendue telle quelle")
if M.mediane(liste([40, 45, 300, 38, 42])) != 42:
    e.append("un aller-retour rate ne doit pas emporter la mediane")
if M.mediane(liste([10, 20, 30, 40])) != 25:
    e.append("sur un nombre pair de mesures, la mediane est la moyenne des deux du milieu")
if M.mediane(liste(["x", 10, 20])) != 15:
    e.append("une valeur qui n'est pas un nombre doit etre ignoree")

# --- FENETRE GLISSANTE : elle ne grossit jamais -------------------------------------------------
l = liste([])
for v in (10, 20, 30, 40, 50, 60, 70):
    l = M.ajouter(l, v)
vals = py(l)
if len(vals) != M.ECHANTILLONS:
    e.append(f"la fenetre doit rester a {M.ECHANTILLONS} mesures, obtenu {len(vals)}")
if vals[-1] != 70 or vals[0] != 30:
    e.append(f"la fenetre doit garder les PLUS RECENTES, obtenu {vals}")

# --- INSTABILITE : c'est l'ECART, pas la lenteur ------------------------------------------------
if M.instable(liste([40, 45])) is not False:
    e.append("avec moins de trois mesures, on n'accuse pas la connexion")
if M.instable(liste([200, 210, 205, 215])) is not False:
    e.append("une connexion lente mais REGULIERE n'est pas instable")
if M.instable(liste([40, 45, 400])) is not True:
    e.append("un ecart de plusieurs centaines de ms doit etre signale comme instable")
if M.instable(liste([40, 45, 40 + M.ECART_INSTABLE])) is not True:
    e.append("l'ecart limite doit compter comme instable")

# --- SILENCE DU SERVEUR -------------------------------------------------------------------------
if M.perdu(0.5) is not False or M.perdu(M.SILENCE) is not True:
    e.append("le silence du serveur doit basculer exactement au seuil")
if M.perdu(None) is not False:
    e.append("sans mesure de silence, on ne declare pas la connexion perdue")

# --- TEXTES -------------------------------------------------------------------------------------
if M.texte(None) != "-- ms":
    e.append("sans mesure, l'indicateur doit montrer des tirets, pas un zero trompeur")
if M.texte(41.6) != "42 ms":
    e.append("la latence s'arrondit au plus proche")
if M.avertissement(40, False, False) is not None:
    e.append("quand tout va bien, AUCUN bandeau ne doit s'afficher")
a_perdu = M.avertissement(40, False, True)
a_instable = M.avertissement(40, True, False)
a_lent = M.avertissement(600, False, False)
if not a_perdu or "perdue" not in a_perdu:
    e.append("la coupure doit etre nommee")
if not a_instable or "instable" not in a_instable:
    e.append("l'instabilite doit etre nommee, et dire ce qu'elle change pour le joueur")
if not a_lent or "wifi" not in a_lent:
    e.append("une connexion lente doit orienter le joueur vers SA connexion")
if len({a_perdu, a_instable, a_lent}) != 3:
    e.append("les trois avertissements doivent etre distincts")
# priorite : une coupure prime sur tout le reste
if M.avertissement(600, True, True) != a_perdu:
    e.append("la coupure doit primer sur l'instabilite et la lenteur")

# --- BRANCHEMENT SERVEUR ------------------------------------------------------------------------
if 'PingEvent.Name = "Ping"' not in S:
    e.append("serveur : aucun canal de mesure d'aller-retour")
if 'item("ModuleScript", "Reseau"' not in B:
    e.append("build : Reseau non embarque (le client resterait bloque)")
bloc = S.split("PingEvent.OnServerEvent")[1].split("PronosticEvent.OnServerEvent")[0]
if "PingEvent:FireClient(player, jeton)" not in bloc:
    e.append("serveur : l'echo ne renvoie pas le jeton du client")
if 'typeof(jeton) ~= "number"' not in bloc:
    e.append("serveur : un jeton qui n'est pas un nombre doit etre refuse")
if "maintenant - dernierPing[player] < 0.25" not in bloc:
    e.append("serveur : aucune cadence maximale sur l'echo (inondation possible)")
if re.search(r"latence|ping", bloc.lower()) and "os.time()" in bloc:
    e.append("serveur : il ne doit RIEN calculer, seulement renvoyer le jeton")

# --- BRANCHEMENT CLIENT -------------------------------------------------------------------------
if 'WaitForChild("Reseau")' not in C:
    e.append("client : module Reseau non requis")
if "PingEvent:FireServer(pingEnCours)" not in C:
    e.append("client : aucune mesure envoyee")
if "Reseau.ajouter(echantillons, (os.clock() - jeton) * 1000)" not in C:
    e.append("client : l'aller-retour n'est pas mesure en millisecondes")
if "dernierEtatRecu = os.clock()" not in C:
    e.append("client : la derniere arrivee d'etat n'est pas suivie (aucune detection de coupure)")
if "Reseau.perdu(os.clock() - dernierEtatRecu)" not in C:
    e.append("client : la coupure n'est pas detectee")
# AVANT le premier etat, aucune coupure ne peut etre affirmee : le bandeau s'affichait d'office au
# chargement (vu sur une capture moteur du 2026-09-20).
if "premierEtatRecu" not in C:
    e.append("client : « Connexion perdue » s'afficherait avant le premier etat, a chaque entree en partie")
if "premierEtatRecu and Reseau.perdu(" not in C:
    e.append("client : la detection de coupure ne verifie pas qu'un etat est deja arrive")
if "pingLabel" not in C or "Reseau.texte(ms)" not in C:
    e.append("client : la latence n'est pas affichee")
if "reseauAvertissement.Visible = texte ~= nil" not in C:
    e.append("client : le bandeau resterait affiche en permanence")
if "Reseau.couleur(q)" not in C:
    e.append("client : la couleur ne suit pas la qualite")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : la latence se mesure, se lit, et l'instabilite se dit sans accuser le jeu")
sys.exit(1 if e else 0)
