# -*- coding: utf-8 -*-
"""PASS DE SAISON (src/shared/PassSaison.lua + Economie + GameServer + Hub)."""
import sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
e = []
lua = LuaRuntime()
M = lua.execute((R / "src/shared/PassSaison.lua").read_text(encoding="utf-8"))
E = (R / "src/server/Economie.lua").read_text(encoding="utf-8")
G = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
H = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")

# points : l'issue, puis la LIGUE
if not (M.pointsPartie("victoire", 0) > M.pointsPartie("defaite", 0) > 0):
    e.append("une victoire doit rapporter plus qu'une defaite, et une defaite plus que rien")
if M.pointsPartie("victoire", 3) - M.pointsPartie("victoire", 0) != 3:
    e.append("bonus de ligue : +1 point par rang de ligue attendu")
# paliers
if M.palier(0) != 0 or M.palier(M.POINTS_PALIER) != 1 or M.palier(10**6) != M.PALIERS:
    e.append("palier faux aux bornes")
d, s = M.progression(M.POINTS_PALIER + 7)
if (d, s) != (7, M.POINTS_PALIER):
    e.append(f"progression : {d}/{s}")
# recompenses : chaque palier a les DEUX pistes, la premium vaut plus
for i in range(1, M.PALIERS + 1):
    if M.recompense(i, "gratuit") is None or M.recompense(i, "premium") is None:
        e.append(f"palier {i} sans recompense")
        break
if M.recompense(0, "gratuit") is not None or M.recompense(1, "vip") is not None:
    e.append("palier ou piste inconnus doivent rendre nil")
tot = {"gratuit": 0, "premium": 0}
for piste in tot:
    for i in range(1, M.PALIERS + 1):
        r = M.recompense(i, piste)
        tot[piste] += r.valeur if r.type == "pieces" else 0
if tot["premium"] <= tot["gratuit"]:
    e.append("la piste premium doit valoir plus que la gratuite")
# saison : un pass d'une autre saison repart a zero
etat = M.neuf(44)
etat.points = 200
n, remis = M.aJour(etat, 45)
if not remis or n.points != 0 or n.saison != 45:
    e.append("changement de saison : le pass doit repartir a zero")
_, remis2 = M.aJour(n, 45)
if remis2:
    e.append("meme saison : rien ne doit etre remis a zero")
# reclamer
etat = M.neuf(45)
etat.points = 3 * M.POINTS_PALIER
if not M.peutReclamer(etat, 2, "gratuit", False):
    e.append("palier atteint, piste gratuite : reclamable")
if M.peutReclamer(etat, 2, "premium", False)[0] if isinstance(M.peutReclamer(etat, 2, "premium", False), tuple) else M.peutReclamer(etat, 2, "premium", False):
    e.append("premium sans pass : doit etre refuse")
if M.peutReclamer(etat, 4, "gratuit", False) is True:
    e.append("palier non atteint : doit etre refuse")
etat.reclames.gratuit["2"] = True
if M.peutReclamer(etat, 2, "gratuit", False) is True:
    e.append("deja reclame : doit etre refuse")
if M.aPrendre(etat, True) != 5:
    e.append(f"a prendre : 2 gratuites + 3 premium attendues, {M.aPrendre(etat, True)}")
# ECRAN DE FIN : ce que la partie a rapporte au pass, et ou on en est
if M.texteFin is None:
    e.append("PassSaison.texteFin absent")
else:
    if M.texteFin(14, 3) != "+14 pass (palier 3/20)":
        e.append("fin de partie : " + str(M.texteFin(14, 3)))
    if M.texteFin(0, 3) is not None:
        e.append("fin de partie : aucun point, aucune mention")
    if "MAX" not in str(M.texteFin(12, M.PALIERS)):
        e.append("fin de partie : pass termine, le dire (MAX)")
if "passPalier" not in E:
    e.append("economie : le palier atteint n'est pas renvoye avec les gains")
if ".texteFin(g.passPoints, g.passPalier)" not in (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8"):
    e.append("ecran de fin : les points de pass ne sont pas affiches")
# branchements
if 'item("ModuleScript", "PassSaison"' not in B:
    e.append("build : PassSaison non embarque")
if "PassSaison.pointsPartie(" not in E or "Ligues.index(" not in E:
    e.append("economie : les parties ne font pas avancer le pass (avec bonus de ligue)")
if "PassSaison.aJour(" not in E or "Saison.numero(" not in E:
    e.append("economie : pas de remise a zero par saison")
if "Economie.reclamerPalier" not in E or "Economie.PASS_SAISON" not in E:
    e.append("economie : reclamation ou pass premium absents")
if 'action == "pass"' not in G:
    e.append("serveur : action pass absente")
if "PassSaison" not in H or "PanneauPass" not in H:
    e.append("hub : pas d'ecran de pass")
for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : 20 paliers, deux pistes, points par issue + ligue, remise a zero par saison, reclamation controlee")
sys.exit(1 if e else 0)
