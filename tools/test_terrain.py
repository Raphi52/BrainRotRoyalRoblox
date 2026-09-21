# -*- coding: utf-8 -*-
"""Banc du TERRAIN (src/shared/Terrain.lua) : defendre chez soi vaut mieux qu'attaquer chez l'autre.

Defaut mesure avant ce module : un echange donnait exactement le meme resultat au pied de ses
propres tours et au fond du camp adverse. Defendre n'etait donc jamais plus rentable qu'attaquer.

Ce qu'il verifie :
  1. les deux conditions comptent : etre dans SA moitie, ET avoir une tour alliee a portee ;
  2. la tour de l'ADVERSAIRE ne protege jamais, et une tour TOMBEE non plus ;
  3. les batiments n'en profitent pas (les tours sont l'enjeu, pas un abri) ;
  4. la reduction n'est pas cumulative : deux tours ne protegent pas deux fois ;
  5. elle reste modeste et bornee, et un coup n'est JAMAIS annule ;
  6. franchir la riviere retire l'avantage a l'instant meme, dans les deux sens ;
  7. perdre sa tour le retire aussi — c'est la consequence lisible de la perte ;
  8. le serveur applique reellement la regle.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Terrain.lua"
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
        print("ROUGE : %s absent — defendre ne vaut toujours pas mieux qu'attaquer" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    T = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")

    R = float(T.RAYON)
    RED = float(T.REDUCTION)
    print("  rayon %.1f studs, reduction %.0f %% (plafond %.0f %%)" % (R, RED * 100, float(T.REDUCTION_MAX) * 100))
    cas("la reduction reste modeste", True, 0 < RED <= float(T.REDUCTION_MAX) <= 0.3)
    cas("le rayon est utile mais pas l'arene entiere", True, 5 <= R <= 20)

    def moi(camp=1, x=0.0, z=-20.0, batiment=False):
        return lua.table_from(dict(camp=camp, x=x, z=z, estBatiment=batiment))

    def tour(camp=1, x=0.0, z=-22.0, vivante=True):
        return lua.table_from(dict(camp=camp, x=x, z=z, vivante=vivante))

    def liste(*e):
        return lua.table_from(list(e))

    # 1. les deux conditions
    cas("chez soi et pres de sa tour : protege", RED, float(T.reduction(moi(), liste(tour()))))
    cas("chez soi mais aucune tour a portee", 0.0,
        float(T.reduction(moi(z=-20.0), liste(tour(z=-20.0 - R - 1)))))
    cas("chez l'adversaire, meme collee a une tour : rien", 0.0,
        float(T.reduction(moi(camp=1, z=20.0), liste(tour(camp=1, z=20.0)))))
    cas("aucune tour du tout", 0.0, float(T.reduction(moi(), liste())))
    cas("liste absente", 0.0, float(T.reduction(moi(), None)))
    cas("unite sans camp", 0.0, float(T.reduction(moi(camp=None), liste(tour()))))

    # moitie d'arene. LA CONVENTION EST CONTRE-INTUITIVE : camp 1 = z NEGATIFS. Elle n'est pas
    # recopiee de tete ici — elle est relue dans Regles.posePermise, la source du jeu. Ecrite a
    # l'envers, ce banc restait vert et le moteur n'accordait jamais l'avantage (mesure 15:43).
    regles = (ROOT / "src" / "shared" / "Regles.lua").read_text(encoding="utf-8")
    cas("la convention vient bien de Regles.posePermise", True,
        "local s = camp == 1 and -1 or 1" in regles)
    for camp, s in ((1, -1), (2, 1)):
        for z in (3, 12, 30):
            cas("camp %d : z=%d est chez lui" % (camp, z * s), True, T.chezSoi(camp, z * s))
            cas("camp %d : z=%d est chez l'autre" % (camp, -z * s), False, T.chezSoi(camp, -z * s))
    # la RIVIERE n'est a personne : sans cela, deux unites face a face y seraient toutes deux
    # protegees. Defaut trouve par ce banc meme (l'invariant ci-dessous), pas par la relecture.
    cas("la riviere n'est chez personne (camp 1)", False, T.chezSoi(1, 0))
    cas("la riviere n'est chez personne (camp 2)", False, T.chezSoi(2, 0))
    cas("hors riviere, les deux moities se partagent toute l'arene", True,
        all(T.chezSoi(1, z) != T.chezSoi(2, z) for z in (-30, -1, 1, 30)))

    # portee exacte
    cas("juste dans le rayon", RED, float(T.reduction(moi(z=-20.0), liste(tour(z=-20.0 - R + 0.01)))))
    cas("juste au-dela : plus rien, net", 0.0,
        float(T.reduction(moi(z=-20.0), liste(tour(z=-20.0 - R - 0.01)))))
    cas("aPortee compte bien en distance", True, T.aPortee(3, 4, 5))
    cas("et exclut au-dela", False, T.aPortee(3, 4, 4.99))

    # 2. tour ennemie, tour morte
    cas("la tour de l'adversaire ne protege pas", 0.0,
        float(T.reduction(moi(camp=1), liste(tour(camp=2)))))
    cas("une tour tombee ne protege plus", 0.0,
        float(T.reduction(moi(), liste(tour(vivante=False)))))
    cas("mais une autre tour debout prend le relais", RED,
        float(T.reduction(moi(), liste(tour(vivante=False), tour(x=3.0)))))

    # 3. batiments
    cas("une tour ne se protege pas elle-meme", 0.0,
        float(T.reduction(moi(batiment=True), liste(tour()))))

    # 4. non cumulatif
    cas("deux tours ne protegent pas deux fois", RED,
        float(T.reduction(moi(), liste(tour(), tour(x=2.0), tour(x=-2.0)))))

    # 5. degats
    cas("sans avantage, le coup passe entier", 100, T.degatsSubis(100, 0))
    attendu = max(1, int(100 * (1 - RED) + 0.5))
    cas("avec l'avantage, le coup est amorti", attendu, T.degatsSubis(100, RED))
    cas("les degats restent entiers", True, float(T.degatsSubis(137, RED)) == int(T.degatsSubis(137, RED)))
    cas("un coup n'est JAMAIS annule", True, T.degatsSubis(1, RED) >= 1)
    cas("une reduction farfelue est plafonnee", T.degatsSubis(100, float(T.REDUCTION_MAX)), T.degatsSubis(100, 0.99))
    cas("une reduction negative ne soigne pas", 100, T.degatsSubis(100, -1))
    cas("zero degat reste zero", 0, T.degatsSubis(0, RED))

    # 6 + 7. simulation : l'unite traverse l'arene, puis sa tour tombe
    tours_vivantes = [tour(camp=1, z=-22.0)]
    trajet = []
    for z in (-30, -22, -14, -11, -5, 0, 5, 15):
        trajet.append((z, round(float(T.reduction(moi(z=float(z)), liste(*tours_vivantes))), 3)))
    print("  reduction le long du trajet (z, reduction) : %s" % trajet)
    cas("protegee au pied de sa tour", RED, dict(trajet)[-22])
    cas("plus rien une fois la riviere franchie", 0.0, dict(trajet)[5])
    cas("l'avantage disparait avant meme la riviere", 0.0, dict(trajet)[-5])
    tours_mortes = [tour(camp=1, z=-22.0, vivante=False)]
    cas("tour perdue : l'avantage tombe avec elle", 0.0,
        float(T.reduction(moi(z=-22.0), liste(*tours_mortes))))

    # 7 bis. AUDIT DE LA PROMESSE. Le terrain n'est porte par aucune carte : sa promesse est
    # celle que le MANUEL fait au joueur. Ce bloc verifie que le manuel et la regle disent le
    # meme chiffre, et qu'aucun cumul ne fait secretement mieux que ce qui est annonce.
    manuel = (ROOT / "src" / "shared" / "Manuel.lua").read_text(encoding="utf-8")
    cas("le manuel annonce bien l'avantage de terrain", True, "AVANTAGE DE TERRAIN" in manuel)
    # il doit LIRE les valeurs de la regle, jamais les recopier : un chiffre en dur mentirait
    # le jour ou la regle change, et personne ne le verrait.
    cas("le manuel lit la reduction a la source", True, "v.terrainReduction" in manuel)
    cas("le manuel lit le rayon a la source", True, "v.terrainRayon" in manuel)
    hub = (ROOT / "src" / "client" / "Hub.client.lua").read_text(encoding="utf-8")
    cas("et ces valeurs viennent vraiment du module", True,
        "terrainReduction = Terrain.REDUCTION" in hub and "terrainRayon = Terrain.RAYON" in hub)
    # le manuel promet « dans ta moitie » ET « pres d'une de TES tours » : les deux conditions
    # doivent etre necessaires, sinon la phrase serait fausse par exces.
    cas("chez l'adversaire, pres d'une tour a soi : rien", 0.0,
        float(T.reduction(moi(z=22.0), liste(tour(camp=1, z=22.0)))))
    cas("chez soi, loin de toute tour : rien", 0.0,
        float(T.reduction(moi(z=-8.0), liste(tour(camp=1, z=-30.0)))))
    # AUCUN CUMUL : deux tours a soi qui couvrent la meme unite ne donnent pas plus que le
    # chiffre annonce. Le module a un plafond plus haut (REDUCTION_MAX) ; si un jour le calcul
    # additionnait les tours, le joueur encaisserait moins que ce que le manuel lui a promis.
    deux = float(T.reduction(moi(z=-22.0), liste(tour(camp=1, z=-22.0), tour(camp=1, z=-24.0))))
    print("  une tour couvre : %.0f %% | deux tours : %.0f %% | plafond dur : %.0f %%"
          % (RED * 100, deux * 100, float(T.REDUCTION_MAX) * 100))
    cas("deux tours ne protegent pas plus que ce qui est annonce", RED, deux)
    cas("et jamais au-dela du plafond dur", True, deux <= float(T.REDUCTION_MAX))

    # 8. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Terrain")' in serveur)
    cas("le serveur recalcule l'avantage a chaque image", True, "majTerrain()" in serveur)
    cas("le serveur amortit les degats subis", True, "Terrain.degatsSubis(amount, target.reductionTerrain)" in serveur)
    cas("le serveur ne compte que les tours vivantes", True, "vivante = tw.alive == true" in serveur)
    cas("le module est livre dans la place", True, "shared/Terrain.lua" in BUILD.read_text(encoding="utf-8"))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : defendre chez soi amortit, franchir la riviere ou perdre sa tour retire l'avantage")
    return 0


if __name__ == "__main__":
    sys.exit(main())
