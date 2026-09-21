# -*- coding: utf-8 -*-
"""Banc du TUTORIEL (src/shared/Tutoriel.lua), hors Studio.

Ce qu'il verifie, et pourquoi :
  1. chaque etape ne laisse qu'UN SEUL geste possible (une carte jouable, les autres grisees) :
     c'est ce qui remplace le texte d'explication ;
  2. toutes les cartes citees (joueur ET robot) EXISTENT dans Cards.lua et sont GRATUITES —
     un tutoriel qui impose une carte payante est injouable pour le joueur neuf ;
  3. la carte imposee a l'etape du volant peut REELLEMENT toucher un volant, sinon l'etape
     est infaisable ;
  4. le robot reste muet pendant les premieres secondes (ROBOT_SILENCE) ;
  5. la sequence tient sous DUREE_MAX meme si le joueur traine a chaque etape ;
  6. le tutoriel n'est impose qu'a la PREMIERE partie ;
  7. une etape qui expire passe a la suivante : le tutoriel ne bloque jamais personne.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Tutoriel.lua"
CARDS = ROOT / "src" / "shared" / "Cards.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }")
lua.execute("Vector3 = { new = function(x, y, z) return { x, y, z } end }")
T = lua.execute(SRC.read_text(encoding="utf-8"))
cartes = {}
for c in lua.execute(CARDS.read_text(encoding="utf-8"))["list"].values():
    cartes[c["id"]] = c

n = T.nombreEtapes()
print("TUTORIEL : %d etapes, %d cartes au catalogue" % (n, len(cartes)))

print("\n1-3. chaque etape : une seule porte ouverte, sur une carte gratuite")
for i in range(1, n + 1):
    e = T.etape(i)
    impose = e["carte"]
    if impose is None:
        cas("etape %d (%s) : etape libre, tout est jouable" % (i, e["id"]), True,
            all(T.carteJouable(i, cid) for cid in cartes))
        continue
    jouables = [cid for cid in cartes if T.carteJouable(i, cid)]
    cas("etape %d (%s) : une seule carte jouable" % (i, e["id"]), [impose], jouables)
    cas("etape %d : la carte imposee existe" % i, True, impose in cartes)
    if impose in cartes:
        cas("etape %d : la carte imposee est gratuite" % i, None, cartes[impose]["prix"])
    robot = T.actionRobot(i)
    if robot is not None:
        cas("etape %d : la carte du robot existe" % i, True, robot in cartes)
    if e["finQuand"] == "volantAbattu":
        c = cartes[impose]
        peut = float(c["range"]) >= 5 or bool(c["flying"])
        cas("etape %d : la carte imposee peut toucher un volant" % i, True, peut)
        cas("etape %d : le robot y envoie bien un volant" % i, True,
            robot in cartes and bool(cartes[robot]["flying"]))

print("\n4. le robot se tait au debut")
premier = next((i for i in range(1, n + 1) if T.actionRobot(i) is not None), None)
cas("premiere action du robot apres ROBOT_SILENCE", True,
    premier is not None and T.debutEtape(premier) >= T.ROBOT_SILENCE)

print("\n5. la sequence tient dans le budget")
total = T.dureeTotale()
cas("duree totale sous DUREE_MAX (joueur qui traine partout)", True, total <= T.DUREE_MAX)
cas("duree totale proche de la cible (pas un tutoriel de 10 s)", True, total >= T.DUREE_CIBLE * 0.8)

print("5 bis. la duree est ANNONCEE au joueur")
# Defaut mesure le 2026-09-21 : le bouton « REVOIR LE TUTORIEL » n'annoncait aucune duree. Un
# joueur ne sait pas s'il s'engage pour une minute ou pour dix, et dans le doute il ne clique pas.
# Le chiffre existait (Tutoriel.dureeTotale) et n'etait affiche nulle part.
court = T.texteDuree()
cas("le libelle court donne un temps", True, ("min" in court) or (" s" in court))
# C'est un PLAFOND (chaque etape s'arrete des que le geste est fait) : « au plus », pas « environ ».
cas("la forme longue dit que c'est un maximum", True, T.texteDuree(True).endswith("au plus"))
cas("et garde le meme chiffre", True, T.texteDuree(True).startswith(court))
minutes = int(total // 60)
cas("le texte colle a la duree reelle", True,
    ((str(minutes) + " min") in court) if total >= 60 else ((str(int(total)) + " s") in court))
hub_txt = (ROOT / "src" / "client" / "Hub.client.lua").read_text(encoding="utf-8")
cas("le bouton porte la duree, calculee et non recopiee", True,
    '"REVOIR LE TUTORIEL - " .. Tutoriel.texteDuree()' in hub_txt)
cas("et la confirmation la redit en toutes lettres", True,
    "Tutoriel.texteDuree(true)" in hub_txt)

print("\n6. impose seulement a la premiere partie")
cas("joueur neuf", True, T.obligatoire(lua.table(parties=0)))
cas("joueur qui a deja joue", False, T.obligatoire(lua.table(parties=1)))
cas("profil absent", False, T.obligatoire(None))

print("\n7. aucune etape ne peut bloquer le joueur")
for i in range(1, n + 1):
    e = T.etape(i)
    attendu = (i + 1) if i < n else None
    cas("etape %d : expiration -> suivante" % i, attendu, T.suivante(i, False, e["duree"]))
    cas("etape %d : condition remplie -> suivante" % i, attendu, T.suivante(i, True, 0))
    cas("etape %d : ni l'un ni l'autre -> on reste" % i, i, T.suivante(i, False, 0))

print()
if ECHECS:
    print("ROUGE : %d echec(s) — %s" % (len(ECHECS), ", ".join(ECHECS[:4])))
    sys.exit(1)
print("VERT : chaque etape n'ouvre qu'un geste, sur des cartes gratuites, sans jamais bloquer")
sys.exit(0)
