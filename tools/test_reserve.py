# -*- coding: utf-8 -*-
"""Banc de la RESERVE DEFENSIVE (src/shared/Reserve.lua) : ne pas tout depenser en attaque.

Mesure a l'origine (60 parties, robots aguerris, 2026-09-20) : 1352 « menace_sans_carte », elixir
median 1,9 et JAMAIS plus de 4,0. Ce n'est PAS un bug — seules les cartes payables sont
candidates, et la defense passe avant tout. Le defaut est en amont : rien n'empechait le robot de
descendre a sec EN ATTAQUANT, et la riposte le trouvait les mains vides.

Ce qu'il verifie :
  1. le montant garde n'est pas invente : c'est le cout MEDIAN relu dans le catalogue ;
  2. la reserve depend du palier — le debutant ne garde rien, c'est son niveau ;
  3. une attaque qui laisserait le robot sans reponse est refusee, et une autre passe ;
  4. le seuil annonce est exact, et tout reste borne ;
  5. COMBIEN de cartes restent jouables avec cette reserve — une regle qui n'en laisserait
     aucune figerait le robot ;
  6. la regle ne s'applique NI a la defense NI a la contre-attaque (verifie dans le serveur) ;
  7. le serveur applique la regle, au bon endroit, et le journal reste lisible.

Prerequis : python -m pip install lupa
"""
import pathlib
import re
import statistics
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Reserve.lua"
CARTES = ROOT / "src" / "shared" / "Cards.lua"
ROBOT = ROOT / "src" / "shared" / "Robot.lua"
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
        print("ROUGE : %s absent — le robot depense tout et subit la riposte" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    R = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")

    # 1. le montant vient du CATALOGUE, il n'est pas invente. On le recalcule ici : si quelqu'un
    # ajoute des cartes cheres, ce banc dira que la reserve a vieilli.
    cartes = CARTES.read_text(encoding="utf-8")
    couts = []
    for bloc in cartes.split(chr(9) + "{")[1:]:
        if not re.search(r'id = "(\w+)"', bloc) or "prix = " in bloc[:1400]:
            continue
        m = re.search(r"cost = (\d+)", bloc[:400])
        if m:
            couts.append(int(m.group(1)))
    mediane = statistics.median(couts)
    print("  %d cartes gratuites : cout min %d, median %.1f, max %d"
          % (len(couts), min(couts), mediane, max(couts)))
    cas("la reserve est le cout median du catalogue", mediane, float(R.MEDIANE))
    cas("et elle reste sous le plafond", True, float(R.MEDIANE) <= float(R.RESERVE_MAX))

    # 2. par palier. Les profils sont relus dans Robot.lua, pas recopies.
    robot = ROBOT.read_text(encoding="utf-8")
    paliers = re.findall(r'nom = "(\w+)".*?anticipe = (\w+)', robot)
    cas("les quatre paliers sont lus", 4, len(paliers))
    for nom, anticipe in paliers:
        profil = lua.table_from(dict(anticipe=(anticipe == "true")))
        attendu = float(R.MEDIANE) if anticipe == "true" else 0.0
        cas("palier %s : reserve %g" % (nom, attendu), attendu, float(R.pour(profil)))
    cas("sans profil : la regle s'applique quand meme", float(R.MEDIANE), float(R.pour(None)))

    reserve = float(R.MEDIANE)

    # 3. le coeur de la regle
    cas("7 d'elixir, carte a 5 : refuse (il resterait 2)", False,
        R.attaquePermise(7, 5, reserve))
    cas("8 d'elixir, carte a 5 : accepte (il reste 3)", True,
        R.attaquePermise(8, 5, reserve))
    cas("pile a la limite : accepte", True, R.attaquePermise(6, 3, reserve))
    cas("un demi-point en dessous : refuse", False, R.attaquePermise(5.9, 3, reserve))
    cas("elixir plein, petite carte : accepte", True, R.attaquePermise(10, 2, reserve))
    cas("sans reserve (debutant), tout passe", True, R.attaquePermise(5, 5, 0))
    cas("elixir insuffisant tout court : refuse", False, R.attaquePermise(1, 3, reserve))

    # 4. seuil annonce et bornes
    cas("seuil pour une carte a 4", 7.0, float(R.seuil(4, reserve)))
    cas("seuil pour une carte a 2", 5.0, float(R.seuil(2, reserve)))
    cas("une reserve farfelue est plafonnee", float(R.RESERVE_MAX) + 3,
        float(R.seuil(3, 99)))
    cas("une reserve negative ne devient pas un bonus", 3.0, float(R.seuil(3, -5)))
    cas("entrees absentes : rien ne casse", True, R.attaquePermise(None, None, None))

    # 5. LA REGLE NE FIGE PAS LE ROBOT : avec 10 d'elixir (le plein), combien de cartes du
    # catalogue restent engageables en attaque ? Si la reponse etait « aucune », le robot
    # n'attaquerait plus jamais et les parties finiraient toutes au temps mort.
    plein = 10
    jouables = sum(1 for c in couts if R.attaquePermise(plein, c, reserve))
    au_seuil = sum(1 for c in couts if R.attaquePermise(7, c, reserve))
    print("  a 10 d'elixir : %d cartes sur %d engageables ; a 7 : %d"
          % (jouables, len(couts), au_seuil))
    cas("a elixir plein, toutes les cartes restent engageables", len(couts), jouables)
    cas("et au seuil d'attaque, la majorite passe encore", True, au_seuil >= len(couts) / 2)
    # la reserve garantit VRAIMENT une reponse : apres la pire attaque permise, il peut encore
    # payer la carte la moins chere du jeu.
    pire = max(c for c in couts if R.attaquePermise(plein, c, reserve))
    cas("apres la plus grosse attaque permise, il peut encore repondre", True,
        (plein - pire) >= min(couts))

    # 6 + 7. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    code = chr(10).join(l.split("--")[0] for l in serveur.splitlines())
    cas("le serveur charge le module", True, 'WaitForChild("Reserve")' in serveur)
    cas("le serveur calcule la reserve du profil", True, "Reserve.pour(profil)" in code)
    cas("et l'applique a l'attaque", True, "Reserve.attaquePermise(" in code)
    cas("le journal dit a partir de quel elixir il attaquera", True, "Reserve.seuil(" in code)
    cas("la raison est nommee dans le journal", True, "reserve_defense" in code)
    # LE POINT CRITIQUE : la reserve ne doit jamais retarder une DEFENSE. Dans le serveur, la
    # defense et la contre-attaque sont des branches distinctes, decidees AVANT l'attaque ; le
    # test de reserve doit se trouver dans la branche d'attaque, apres elles.
    i_def = code.find('"defense_voie"')
    i_res = code.find("Reserve.attaquePermise(")
    cas("la defense est decidee AVANT le test de reserve", True, 0 < i_def < i_res)
    cas("le module est livre dans la place", True,
        "shared/Reserve.lua" in BUILD.read_text(encoding="utf-8"))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : il n'engage plus une poussee qui le laisserait sans reponse")
    return 0


if __name__ == "__main__":
    sys.exit(main())
