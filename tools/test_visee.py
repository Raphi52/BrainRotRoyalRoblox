# -*- coding: utf-8 -*-
"""Banc de la VISEE (src/shared/Visee.lua) : un tireur vise ou la cible SERA.

Defaut mesure avant ce module : le serveur visait la position COURANTE, et le tir mettait ensuite
son temps de vol a arriver. Comme un tir dont la cible a bouge de plus de MARGE_ESQUIVE est perdu,
un tireur ratait TOUTE unite rapide allant pourtant tout droit.

Ce qu'il verifie :
  1. la vitesse se deduit correctement de deux positions, et jamais de division par zero ;
  2. le point vise avance dans le sens du deplacement, proportionnellement au temps de vol ;
  3. une cible immobile (ou presque) n'est pas « anticipee » ;
  4. l'avance est BORNEE : une vitesse aberrante n'envoie pas le tir hors de l'arene ;
  5. SIMULATION contre la vraie regle d'esquive (Projectiles.MARGE_ESQUIVE) :
     - une unite qui va tout droit etait ratee avant, elle est touchee maintenant ;
     - une unite qui CHANGE de direction esquive encore — l'esquive n'est pas supprimee ;
  6. aucune carte n'a une anticipation parfaite sauf celles qui le meritent (tourelle) ;
  7. le serveur mesure la vitesse a chaque image et l'utilise pour viser.

Prerequis : python -m pip install lupa
"""
import math
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Visee.lua"
PROJ = ROOT / "src" / "shared" / "Projectiles.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
CARTES = ROOT / "src" / "shared" / "Cards.lua"
BUILD = ROOT / "build.py"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — les tireurs ratent toujours ce qui bouge" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    V = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    P = lua.execute("return (function() " + PROJ.read_text(encoding="utf-8") + " end)()")
    cartes = CARTES.read_text(encoding="utf-8")

    marge = float(P.MARGE_ESQUIVE)
    part_defaut = float(V.PART_DEFAUT)
    print("  marge d'esquive du jeu : %.1f studs ; anticipation par defaut : %.0f %%"
          % (marge, part_defaut * 100))

    # 0. COHERENCE ET AUDIT DES PROMESSES.
    # Sens direct : une carte declaree dans PARTS doit etre un tireur — anticiper n'a aucun sens
    # au contact. Sens inverse : une carte dont le TEXTE promet la distance doit vraiment porter
    # plus loin que la mediane des tireurs, sinon elle ment au joueur.
    import re as _re
    import statistics as _stat

    blocs = [b for b in cartes.split(chr(9) + "{")[1:]
             if _re.search(r'id = "(\w+)"', b) and _re.search(r'desc = "([^"]*)"', b)]

    def champ(bloc, cle, defaut=0.0):
        return float((_re.search(cle + r" = ([\d.]+)", bloc) or [0, defaut])[1])

    def ident(bloc):
        return _re.search(r'id = "(\w+)"', bloc).group(1)

    def desc(bloc):
        return _re.search(r'desc = "([^"]*)"', bloc).group(1).lower()

    unites = [b for b in blocs if "sort = " not in b[:1300] and "batiment = " not in b[:1300]]
    seuil = float(V.PORTEE_TIREUR)
    portees_tireurs = [champ(b, "range") for b in unites if champ(b, "range") >= seuil]
    mediane = _stat.median(portees_tireurs)
    print("  %d tireurs (portee >= %.0f), portee mediane %.1f studs"
          % (len(portees_tireurs), seuil, mediane))

    # sens direct
    declarees = sorted(V.PARTS.keys())
    for n in declarees:
        bloc = next((b for b in blocs if ident(b) == n), None)
        cas("%s existe au catalogue" % n, True, bloc is not None)
        if bloc is None:
            continue
        carte = lua.table_from(dict(range=champ(bloc, "range"),
                                    batiment="batiment = " in bloc[:1300]))
        ok, raison = V.coherente(n, carte)
        cas("%s a de quoi anticiper (portee %.1f)" % (n, champ(bloc, "range")), True,
            bool(ok) or raison)
        cas("%s : part bornee et au moins egale au defaut" % n, True,
            part_defaut <= float(V.PARTS[n]) <= float(V.PART_MAX))

    # sens inverse : le texte promet la distance
    PROMESSES = ("longue portee", "portee record", "tire loin", "de tres loin")
    menteuses = []
    for b in unites:
        if any(k in desc(b) for k in PROMESSES) and champ(b, "range") < mediane:
            menteuses.append("%s promet la distance avec seulement %.1f studs (mediane %.1f)"
                             % (ident(b), champ(b, "range"), mediane))
    cas("aucune carte ne promet une portee qu'elle n'a pas", [], menteuses)
    # « portee record » doit vraiment etre le record du catalogue
    record = max(unites, key=lambda b: champ(b, "range"))
    for b in unites:
        if "portee record" in desc(b):
            cas("%s dit 'portee record' et l'a vraiment" % ident(b), ident(record), ident(b))

    # le controle MORD
    cas("une carte de melee ne peut pas etre un tireur d'elite", False,
        bool(V.coherente(declarees[0], lua.table_from(dict(range=3, batiment=False)))[0]))
    cas("mais une tourelle fixe, oui", True,
        bool(V.coherente(declarees[0], lua.table_from(dict(range=3, batiment=True)))[0]))
    cas("et une carte non declaree anticipe quand meme, au defaut", part_defaut,
        float(V.part("Tralalero", False)))

    # 1. vitesse observee
    cas("vitesse deduite de deux positions", (10.0, 0.0),
        tuple(round(float(v), 6) for v in V.vitesseObservee(1.0, 0.0, 0.0, 0.0, 0.1)))
    cas("en diagonale aussi", (-5.0, 5.0),
        tuple(round(float(v), 6) for v in V.vitesseObservee(0.0, 1.0, 0.5, 0.5, 0.1)))
    cas("dt nul : aucune vitesse (pas de division par zero)", (0, 0),
        tuple(float(v) for v in V.vitesseObservee(1, 1, 0, 0, 0)))
    cas("dt negatif : aucune vitesse", (0, 0),
        tuple(float(v) for v in V.vitesseObservee(1, 1, 0, 0, -0.1)))
    cas("premiere image (aucune position precedente)", (0, 0),
        tuple(float(v) for v in V.vitesseObservee(1, 1, None, None, 0.1)))
    cas("une unite immobile a une vitesse nulle", (0.0, 0.0),
        tuple(round(float(v), 6) for v in V.vitesseObservee(3, 4, 3, 4, 0.1)))

    # 2. point vise
    x, z = V.point(0, 0, 10, 0, 0.5, 1.0)
    cas("anticipation complete : vitesse x temps", (5.0, 0.0), (round(float(x), 6), round(float(z), 6)))
    x, z = V.point(0, 0, 10, 0, 0.5, 0.5)
    cas("anticipation a moitie", (2.5, 0.0), (round(float(x), 6), round(float(z), 6)))
    x, z = V.point(0, 0, 0, -8, 1.0, 1.0)
    cas("elle suit le sens du deplacement", (0.0, -8.0), (round(float(x), 6), round(float(z), 6)))
    x, z = V.point(10, 20, 6, 8, 0.5, 1.0)
    cas("le point part bien de la cible", (13.0, 24.0), (round(float(x), 6), round(float(z), 6)))
    cas("temps de vol nul : on vise la cible", (7.0, 7.0),
        tuple(round(float(v), 6) for v in V.point(7, 7, 30, 30, 0, 1.0)))
    cas("part nulle : comportement d'avant le module", (7.0, 7.0),
        tuple(round(float(v), 6) for v in V.point(7, 7, 30, 30, 1.0, 0)))

    # 3. cible immobile
    cas("cible immobile : aucun decalage", (4.0, 4.0),
        tuple(round(float(v), 6) for v in V.point(4, 4, 0, 0, 1.0, 1.0)))
    petite = float(V.VITESSE_MORTE) / 2
    cas("cible qui fremit a peine : aucun decalage", (4.0, 4.0),
        tuple(round(float(v), 6) for v in V.point(4, 4, petite, 0, 1.0, 1.0)))

    # 4. borne
    x, z = V.point(0, 0, 500, 0, 3.0, 1.0)
    avance = math.hypot(float(x), float(z))
    cas("une vitesse aberrante est bornee", float(V.AVANCE_MAX), round(avance, 6))
    x, z = V.point(0, 0, 300, 400, 2.0, 1.0)
    cas("bornee en diagonale aussi", float(V.AVANCE_MAX),
        round(math.hypot(float(x), float(z)), 6))

    # 5. SIMULATION contre la vraie regle d'esquive du jeu.
    # Un tireur a 20 studs, projectile a la vitesse du jeu, cible a 8 studs/s.
    def tir(vitesse_cible, changement, part, distance=20.0):
        """Rend True si le tir TOUCHE. `changement` : facteur applique a la direction pendant le vol."""
        duree = float(P.duree(None, distance))
        vx, vz = vitesse_cible, 0.0
        px, pz = float(V.point(0, 0, vx, vz, duree, part)[0]), float(V.point(0, 0, vx, vz, duree, part)[1])
        # trajet reel de la cible pendant le vol
        ax = vx * duree * changement
        az = vz * duree * changement
        return not V.rate(px, pz, ax, az, marge)

    duree = float(P.duree(None, 20.0))
    # 8 studs/s tombe PILE sur la marge (4,0 studs parcourus pour 4,0 de marge) : ce n'est pas un
    # bon cas de test, l'egalite stricte n'est pas un rate. On prend une unite franchement rapide.
    rapide = 12.0
    print("  temps de vol sur 20 studs : %.2f s ; une unite a %.0f studs/s parcourt %.1f studs"
          % (duree, rapide, rapide * duree))
    cas("AVANT (aucune anticipation) : une unite rapide est ratee", False, tir(rapide, 1.0, 0))
    cas("APRES : la meme unite, tout droit, est touchee", True, tir(rapide, 1.0, part_defaut))
    cas("une unite lente etait deja touchee", True, tir(1.0, 1.0, 0))
    cas("et l'est toujours", True, tir(1.0, 1.0, part_defaut))
    # l'esquive doit SURVIVRE : la cible change d'avis pendant le vol
    cas("demi-tour pendant le vol : elle esquive encore", False, tir(rapide, -1.0, part_defaut))
    cas("arret net pendant le vol : elle esquive encore", False, tir(rapide, 0.0, part_defaut))
    cas("meme une anticipation parfaite laisse esquiver un demi-tour", False, tir(rapide, -1.0, 1.0))
    # ce qu'une unite MOYENNE subit : a 8 studs/s elle est pile a la limite, donc touchee de justesse
    cas("a la vitesse limite exacte, le tir passe", True, tir(8.0, 1.0, 0))

    # balayage : a quelle vitesse un tireur commencait-il a rater ?
    seuil_avant = next((v for v in [x * 0.5 for x in range(1, 40)] if not tir(v, 1.0, 0)), None)
    seuil_apres = next((v for v in [x * 0.5 for x in range(1, 40)] if not tir(v, 1.0, part_defaut)), None)
    print("  vitesse a partir de laquelle un tir droit est rate : avant %s studs/s, apres %s"
          % (seuil_avant, seuil_apres if seuil_apres else "jamais dans la plage testee"))
    cas("le module recule nettement ce seuil", True,
        seuil_avant is not None and (seuil_apres is None or seuil_apres > seuil_avant * 2))

    # 6. parts par carte
    parts = dict(V.PARTS)
    for ident, p in parts.items():
        cas("%s existe au catalogue" % ident, True, ('id = "%s"' % ident) in cartes)
        cas("%s : part entre 0 et 1" % ident, True, 0 <= float(p) <= float(V.PART_MAX))
    cas("une carte non listee prend la valeur par defaut", part_defaut,
        float(V.part("Tralalero", False)))
    cas("un batiment vise parfaitement (il ne fait que ca)", 1.0, float(V.part("Inconnu", True)))
    cas("la tourelle du jeu vise parfaitement", 1.0, float(V.part("TorreCannoli", False)))
    cas("mais la plupart des unites ne sont pas parfaites", True, part_defaut < 1.0)

    # 7. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Visee")' in serveur)
    cas("le serveur mesure la vitesse a chaque image", True, "majVitesses(dt)" in serveur)
    cas("la mesure a lieu avant les tirs", True,
        serveur.index("majVitesses(dt)\n\t\tmajTirs()") > 0 if "majVitesses(dt)\n\t\tmajTirs()" in serveur
        else serveur.index("majVitesses(dt)") < serveur.index("majTirs()\n\t\tmajStatuts"))
    cas("le serveur vise le point calcule", True, "Visee.point(ou.X, ou.Z, vx, vz, duree," in serveur)
    cas("le serveur utilise la part de la carte", True, "Visee.part(e.carte and e.carte.id" in serveur)
    cas("le serveur stocke la vitesse observee", True, "e.vitesseX, e.vitesseZ = Visee.vitesseObservee(" in serveur)
    cas("le module est livre dans la place", True, "shared/Visee.lua" in BUILD.read_text(encoding="utf-8"))
    # Un RECUL est un saut, pas une course. Sans remise a zero, la vitesse mesuree a l'image
    # suivante serait enorme et le tireur viserait tres loin devant une unite qui n'a pas avance.
    # Defaut trouve en relisant l'interaction entre Recul et Visee, avant qu'il ne se voie en jeu.
    cas("un recul d'unite ne fabrique pas une fausse vitesse", 2,
        serveur.count("cible.vitesseX, cible.vitesseZ = 0, 0"))
    cas("et la position de reference suit le saut", 2,
        serveur.count("cible.posPrecX, cible.posPrecZ = nx, nz"))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : les tireurs touchent ce qui va tout droit, et ratent encore ce qui change d'avis")
    return 0


if __name__ == "__main__":
    sys.exit(main())
