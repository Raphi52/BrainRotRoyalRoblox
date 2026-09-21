# -*- coding: utf-8 -*-
"""Banc de la VOIE (src/shared/Voie.lua) : par quel cote le robot attaque et defend.

Defaut MESURE puis confirme dans le code. Sur une melee complete (journal du 2026-09-20),
`raison=defense_voie1` apparait 123 fois contre 10 pour la voie 2. Cause : deux comparaisons qui
ne departagent pas les egalites —
    if tw.hp < pvMin                     (tours a PV IDENTIQUES en debut de partie)
    voieMenace = menace[1] >= menace[2]  (rend 1 meme quand les deux valent zero)
Les deux robots attaquaient donc le meme cote toute la partie, et defendaient le meme cote.

Ce qu'il verifie :
  1. une vraie difference de PV est RESPECTEE (on ne remplace pas un choix par du hasard) ;
  2. une egalite est DEPARTAGEE : sur 1000 tirages, les deux voies sortent chacune environ 50 % ;
  3. une petite egratignure ne suffit pas a rendre le robot previsible a nouveau ;
  4. la tour du Roi et les tours mortes ne comptent jamais ;
  5. la voie menacee suit la vraie menace, et se departage a egalite — zero contre zero compris ;
  6. SIMULATION du defaut d'origine : l'ancienne regle rejouee donne bien 100 % du meme cote ;
  7. le serveur applique les deux corrections.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Voie.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
BUILD = ROOT / "build.py"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — le robot attaque toujours le meme cote" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    V = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")

    GAUCHE, DROITE = int(V.GAUCHE), int(V.DROITE)
    tolerance = float(V.EGALITE_PV)
    print("  deux tours sont 'equivalentes' a moins de %.0f PV d'ecart" % tolerance)

    def tour(x, pv, vivante=True, roi=False):
        return lua.table_from(dict(x=x, pv=pv, vivante=vivante, roi=roi))

    def tours(*t):
        return lua.table_from(list(t))

    # 1. une vraie difference est respectee (dans les deux sens, et quel que soit le tirage)
    nette_gauche = tours(tour(-17, 1000), tour(17, 3400))
    nette_droite = tours(tour(-17, 3400), tour(17, 800))
    cas("tour gauche nettement plus faible : on va a gauche",
        [GAUCHE] * 5, [int(V.tourLaPlusFaible(nette_gauche, t / 5.0)) for t in range(5)])
    cas("tour droite nettement plus faible : on va a droite",
        [DROITE] * 5, [int(V.tourLaPlusFaible(nette_droite, t / 5.0)) for t in range(5)])
    cas("le hasard ne prend JAMAIS le pas sur une vraie difference", True,
        all(int(V.tourLaPlusFaible(nette_gauche, t / 100.0)) == GAUCHE for t in range(100)))

    # 2. l'egalite est departagee
    egales = tours(tour(-17, 3400), tour(17, 3400))
    tirees = [int(V.tourLaPlusFaible(egales, t / 1000.0)) for t in range(1000)]
    part_gauche = tirees.count(GAUCHE) / 10.0
    print("  tours a PV egaux, 1000 tirages : gauche %.1f %%, droite %.1f %%"
          % (part_gauche, 100 - part_gauche))
    cas("les deux voies sortent", True, GAUCHE in tirees and DROITE in tirees)
    cas("et a peu pres a parts egales", True, 40 <= part_gauche <= 60)

    # 3. une egratignure ne recree pas le biais
    presque = tours(tour(-17, 3400), tour(17, 3400 - tolerance / 2))
    tirees2 = [int(V.tourLaPlusFaible(presque, t / 200.0)) for t in range(200)]
    cas("une difference sous la tolerance reste un match nul", True,
        GAUCHE in tirees2 and DROITE in tirees2)
    franche = tours(tour(-17, 3400), tour(17, 3400 - tolerance * 2))
    cas("au-dela de la tolerance, le choix redevient ferme",
        [DROITE] * 20, [int(V.tourLaPlusFaible(franche, t / 20.0)) for t in range(20)])

    # 4. roi et tours mortes
    avec_roi = tours(tour(-17, 3400), tour(17, 3400), tour(0, 10, roi=True))
    cas("la tour du Roi n'est jamais visee", True,
        all(int(V.tourLaPlusFaible(avec_roi, t / 50.0)) in (GAUCHE, DROITE) for t in range(50)))
    une_morte = tours(tour(-17, 0, vivante=False), tour(17, 3400))
    cas("une tour tombee ne compte plus", [DROITE] * 10,
        [int(V.tourLaPlusFaible(une_morte, t / 10.0)) for t in range(10)])
    cas("aucune tour debout : aucune voie", None, V.tourLaPlusFaible(tours(tour(-17, 0, vivante=False)), 0.5))
    cas("liste vide", None, V.tourLaPlusFaible(tours(), 0.5))
    cas("liste absente", None, V.tourLaPlusFaible(None, 0.5))

    # 5. voie menacee
    cas("la menace de gauche l'emporte", GAUCHE, int(V.menacee(500, 100, 0.9)))
    cas("celle de droite aussi", DROITE, int(V.menacee(100, 500, 0.1)))
    cas("un seul PV de difference suffit", DROITE, int(V.menacee(100, 101, 0.1)))
    egal = [int(V.menacee(0, 0, t / 1000.0)) for t in range(1000)]
    part = egal.count(GAUCHE) / 10.0
    print("  aucune menace (0 contre 0), 1000 tirages : gauche %.1f %%" % part)
    cas("zero contre zero se departage", True, 40 <= part <= 60)
    cas("menaces egales non nulles aussi", True,
        len({int(V.menacee(300, 300, t / 100.0)) for t in range(100)}) == 2)

    # axe
    cas("la voie gauche est du cote des x negatifs", -17.0, float(V.axe(GAUCHE, 17)))
    cas("la voie droite du cote des x positifs", 17.0, float(V.axe(DROITE, 17)))

    # 6. SIMULATION du defaut d'origine, pour montrer ce qui est repare
    def ancienne_regle(liste_pv):
        """`tw.hp < pvMin` : a egalite, la premiere de la liste gagne toujours."""
        faible, pvmin = None, float("inf")
        for x, pv in liste_pv:
            if pv < pvmin:
                faible, pvmin = x, pv
        return GAUCHE if faible < 0 else DROITE

    debut_de_partie = [(-17, 3400), (17, 3400)]
    anciens = [ancienne_regle(debut_de_partie) for _ in range(100)]
    cas("l'ancienne regle donnait 100 % du meme cote", [GAUCHE] * 100, anciens)
    nouveaux = {int(V.tourLaPlusFaible(egales, t / 100.0)) for t in range(100)}
    cas("la nouvelle propose les deux", {GAUCHE, DROITE}, nouveaux)

    # 7. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Voie")' in serveur)
    cas("le serveur choisit la voie menacee avec le module", True,
        "Voie.menacee(menace[1], menace[2], math.random())" in serveur)
    cas("et la tour la plus faible aussi", True,
        "Voie.tourLaPlusFaible(tours, math.random())" in serveur)
    # On regarde le CODE, pas les commentaires : citer l'ancienne regle pour expliquer la
    # correction est utile, la laisser active serait le defaut.
    code = chr(10).join(l.split("--")[0] for l in serveur.splitlines())
    cas("l'ancienne comparaison stricte a disparu", False, "tw.hp < pvMin" in code)
    cas("l'ancien depart a egalite aussi", False, "menace[1] >= menace[2] and 1 or 2" in code)
    cas("le module est livre dans la place", True, "shared/Voie.lua" in BUILD.read_text(encoding="utf-8"))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : le robot respecte une vraie difference et tire au sort les egalites")
    return 0


if __name__ == "__main__":
    sys.exit(main())
