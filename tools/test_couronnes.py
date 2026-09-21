# -*- coding: utf-8 -*-
"""COURONNES MISES EN SCENE (src/shared/Couronnes.lua + branchement).

Le defaut corrige : prendre une tour — le moment le plus important d'une partie — ne produisait
qu'un son et une secousse. Rien ne le NOMMAIT, et le camp qui PERD recevait exactement le meme
signal que celui qui gagne : la meme secousse annoncait la meilleure et la pire des nouvelles.

1) Les regles PURES sont EXECUTEES (lupa) : annonces distinctes des deux cotes, cas du Roi, double
   couronne, silence au premier etat, resynchronisation sur une nouvelle partie.
2) Le branchement est lu : le client annonce, secoue selon l'enjeu, et affiche une jauge lisible.
"""
import sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
CO = (R / "src/shared/Couronnes.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(CO)
def evs(a, b, c, d):
    t = M.evenements(a, b, c, d)
    return [t[i] for i in range(1, len(t) + 1)]

# --- SILENCE QUAND IL LE FAUT -------------------------------------------------------------------
if evs(None, None, 1, 0):
    e.append("au PREMIER etat recu, aucune annonce (rejoindre une partie en cours n'est pas une couronne)")
if evs(0, 0, 0, 0):
    e.append("sans changement, aucune annonce")
if M.remiseAZero(2, 1, 0, 0) is not True:
    e.append("un compteur qui redescend = nouvelle partie, il faut se resynchroniser")
if M.remiseAZero(0, 0, 1, 0) is not False:
    e.append("une hausse normale ne doit pas etre prise pour une remise a zero")

# --- DEUX ANNONCES DIFFERENTES ------------------------------------------------------------------
gain = evs(0, 0, 1, 0)
if len(gain) != 1 or gain[0].camp != "moi":
    e.append("prendre une tour doit produire UNE annonce, la sienne")
if "COURONNE" not in gain[0].texte.upper():
    e.append(f"le gain doit etre nomme, obtenu : {gain[0].texte}")
perte = evs(0, 0, 0, 1)
if len(perte) != 1 or perte[0].camp != "lui":
    e.append("perdre une tour doit produire une annonce distincte")
if perte[0].texte == gain[0].texte:
    e.append("LA MEME PHRASE pour la meilleure et la pire des nouvelles : c'est le defaut d'origine")
if tuple(perte[0].couleur.values()) == tuple(gain[0].couleur.values()):
    e.append("gain et perte doivent se distinguer aussi par la couleur")
# Les deux camps peuvent marquer dans le meme rafraichissement : la SIENNE d'abord.
deux = evs(0, 0, 1, 1)
if len(deux) != 2 or deux[0].camp != "moi":
    e.append("quand les deux marquent, la sienne doit etre annoncee en premier")

# --- DOUBLE COURONNE ET ROI ---------------------------------------------------------------------
if "DOUBLE" not in evs(0, 0, 2, 0)[0].texte.upper():
    e.append("deux couronnes d'un coup doivent etre dites")
roi = evs(1, 0, 3, 0)[0]
if "ROI" not in roi.texte.upper():
    e.append(f"la tour du Roi doit etre nommee, obtenu : {roi.texte}")
roiPerdu = evs(0, 1, 0, 3)[0]
if "ROI" not in roiPerdu.texte.upper() or roiPerdu.texte == roi.texte:
    e.append("perdre son Roi doit se dire, et differemment")
if M.secousse(3) <= M.secousse(1):
    e.append("la tour du Roi doit ebranler plus fort qu'une tour de cote")

# --- JAUGE --------------------------------------------------------------------------------------
if M.jauge(0) != "○○○" or M.jauge(2) != "●●○" or M.jauge(3) != "●●●":
    e.append(f"la jauge doit se lire d'un coup d'oeil, obtenu {M.jauge(0)} / {M.jauge(2)} / {M.jauge(3)}")
if M.jauge(9) != "●●●" or M.jauge(-1) != "○○○":
    e.append("une valeur hors bornes ne doit pas deformer la jauge")
if len(M.jauge(1)) != len(M.jauge(3)):
    e.append("la jauge doit garder la meme largeur (sinon le score saute a chaque couronne)")

# --- BRANCHEMENT --------------------------------------------------------------------------------
if 'item("ModuleScript", "Couronnes"' not in B:
    e.append("build : Couronnes non embarque")
if 'WaitForChild("Couronnes")' not in C:
    e.append("client : module Couronnes non requis")
if "Couronnes.evenements(sonCouronnesMoi, sonCouronnesEnnemi, moi, lui)" not in C:
    e.append("client : les annonces ne sont pas tirees du changement de score")
if "Couronnes.remiseAZero(" not in C:
    e.append("client : une nouvelle partie declencherait une pluie de couronnes deja acquises")
if "secouer(Couronnes.secousse(ev.total))" not in C:
    e.append("client : la secousse ne suit pas l'enjeu")
if "couronneLabel" not in C or "annoncerCouronne" not in C:
    e.append("client : rien n'est affiche a l'ecran")
if C.count("Couronnes.jauge(") < 4:
    e.append("client : la jauge n'est pas utilisee des deux cotes (joueur ET spectateur)")
if 'secouer(SECOUSSE.tour)' in C:
    e.append("client : l'ancienne secousse indifferenciee est encore la")

# --- VOL DE LA COURONNE JUSQU'AU SCORE (2026-09-21) ---------------------------------------------
# En 3D, au-dessus d'une tour adverse, la couronne montait sous l'affichage du score et y restait
# a moitie cachee (captures). Elle vole donc A L'ECRAN, de la tour au compteur, en 2,5 s.
if (M.VOL_DUREE or 0) != 2.5:
    e.append("vol : doit durer 2,5 s")
elif M.vol is None:
    e.append("vol : Couronnes.vol(t) absent")
else:
    d0 = M.vol(0); d1 = M.vol(1); dm = M.vol(0.5)
    if abs(d0.avance) > 1e-9 or abs(d1.avance - 1) > 1e-9:
        e.append("vol : doit partir de la tour (0) et finir sur le score (1)")
    if not (dm.echelle > d1.echelle and d0.echelle < dm.echelle):
        e.append("vol : la couronne doit grossir en partant puis se poser petite sur le score")
    if dm.arc <= 0:
        e.append("vol : trajet plat, sans arc")
if "Couronnes.vol(" not in C or "crownsLabel.AbsolutePosition" not in C:
    e.append("client : la couronne ne vole pas jusqu'au compteur de score")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : prendre une tour et en perdre une ne se disent plus de la meme facon")
sys.exit(1 if e else 0)
