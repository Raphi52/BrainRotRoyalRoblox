# -*- coding: utf-8 -*-
"""Banc de la DERNIERE GARDE (src/shared/Garde.lua) : le sursaut du Roi quand il reste seul.

Defaut mesure le 2026-09-20 (serie de 20 parties a niveaux egaux, robots aguerris) : 15 parties
sur 20 se terminent AVANT la fin du temps, donc par la chute du Roi. Une fois les deux tours de
princesse tombees, plus rien ne ralentit l'attaquant.

Ce qu'il verifie :
  1. la garde s'engage EXACTEMENT quand les deux princesses sont tombees et que le Roi tient ;
  2. elle ne deborde jamais : aucune princesse, aucun batiment pose n'en profite ;
  3. le facteur est borne, et le delai entre deux tirs diminue vraiment ;
  4. une entree farfelue (nil, table vide, valeurs absurdes) ne casse rien ;
  5. SIMULATION : sur une meme fenetre de temps, le Roi en garde tire plus que le Roi normal, et
     l'ecart est celui annonce — ni plus, ni moins ;
  6. le Roi en garde ne devient pas meilleur que les tours qu'il a perdues ;
  7. le serveur applique la regle, au bon endroit et a la bonne tour.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Garde.lua"
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
        print("ROUGE : %s absent — le Roi tombe sans jamais se defendre" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    G = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")

    facteur = float(G.FACTEUR)
    print("  cadence du Roi en derniere garde : x%.2f (plafond dur x%.2f)"
          % (facteur, float(G.FACTEUR_MAX)))

    def tours(p1=True, p2=True, roi=True):
        return lua.table_from([
            lua.table_from(dict(estRoi=False, vivante=p1)),
            lua.table_from(dict(estRoi=False, vivante=p2)),
            lua.table_from(dict(estRoi=True, vivante=roi)),
        ])

    # 1. quand la garde s'engage
    cas("debut de partie : aucune garde", False, G.engagee(tours()))
    cas("une princesse perdue : toujours pas", False, G.engagee(tours(p1=False)))
    cas("l'autre princesse perdue : toujours pas", False, G.engagee(tours(p2=False)))
    cas("les DEUX princesses tombees : la garde s'engage", True,
        G.engagee(tours(p1=False, p2=False)))
    cas("Roi tombe aussi : plus de garde, la partie est finie", False,
        G.engagee(tours(p1=False, p2=False, roi=False)))
    cas("camp intact de l'autre cote : pas de garde", False, G.engagee(tours()))

    # 2. la regle ne deborde pas
    roi = lua.table_from(dict(estRoi=True, vivante=True))
    princesse = lua.table_from(dict(estRoi=False, vivante=True))
    bati = lua.table_from(dict(estRoi=False, vivante=True, estBatimentPose=True))
    en_garde = tours(p1=False, p2=False)
    cas("le Roi en garde accelere", facteur, float(G.facteur(roi, en_garde)))
    cas("une princesse ne profite JAMAIS de la garde", 1.0,
        float(G.facteur(princesse, en_garde)))
    cas("un batiment pose non plus", 1.0, float(G.facteur(bati, en_garde)))
    cas("le Roi hors garde reste normal", 1.0, float(G.facteur(roi, tours())))
    cas("un Roi mort n'accelere pas", 1.0,
        float(G.facteur(lua.table_from(dict(estRoi=True, vivante=False)), en_garde)))

    # 3 + 4. bornes et entrees farfelues
    cas("le facteur ne depasse jamais le plafond", True, facteur <= float(G.FACTEUR_MAX))
    cas("et il accelere vraiment", True, facteur > 1)
    cas("sans tours : aucune garde", False, G.engagee(None))
    cas("liste vide : aucune garde", False, G.engagee(lua.table_from([])))
    cas("tour absente : facteur neutre", 1.0, float(G.facteur(None, en_garde)))
    cas("delai divise par le facteur", round(1.0 / facteur, 6),
        round(float(G.delai(1.0, facteur)), 6))
    cas("delai nul reste nul", 0.0, float(G.delai(0, facteur)))
    cas("delai negatif ne devient pas positif", 0.0, float(G.delai(-5, facteur)))
    cas("un facteur farfelu est plafonne", round(1.0 / float(G.FACTEUR_MAX), 6),
        round(float(G.delai(1.0, 99)), 6))
    cas("un facteur sous 1 ne RALENTIT jamais le Roi", 1.0, float(G.delai(1.0, 0.2)))
    cas("delai sans facteur : inchange", 0.85, round(float(G.delai(0.85, None)), 6))

    # 5. SIMULATION : combien de tirs sur 20 secondes de siege
    base = 0.85  # atkSpeed des tours, lu dans le serveur ci-dessous
    serveur = SERVEUR.read_text(encoding="utf-8")
    import re as _re
    m = _re.search(r"atkSpeed = ([\d.]+), speed = 0", serveur)
    if m:
        base = float(m.group(1))
    fenetre = 20.0
    normal = int(fenetre / G.delai(base, 1))
    garde = int(fenetre / G.delai(base, facteur))
    print("  sur %.0f s de siege : Roi normal %d tirs, Roi en derniere garde %d tirs (+%d)"
          % (fenetre, normal, garde, garde - normal))
    cas("le Roi en garde tire plus", True, garde > normal)
    # On compare les CADENCES, pas les tirs entiers : 23 et 35 tirs donnent 1,52 par simple
    # troncature, ce qui ferait echouer un banc juste. Le rapport des delais, lui, est exact.
    cas("et l'ecart est exactement celui annonce", round(facteur, 6),
        round(float(G.delai(base, 1)) / float(G.delai(base, facteur)), 6))

    # 6. il ne devient pas meilleur que ce qu'il a perdu. Une tour de princesse tire au meme
    # rythme ; deux princesses valent donc 2 tirs pour 1. Le Roi en garde doit rester EN DESSOUS.
    cas("un Roi en garde reste moins fort que ses deux princesses", True, facteur < 2.0)

    # 7. branchement reel
    cas("le serveur charge le module", True, 'WaitForChild("Garde")' in serveur)
    code = chr(10).join(l.split("--")[0] for l in serveur.splitlines())
    # Le serveur n'appelle pas `engagee` directement : il passe par `facteur`, qui l'appelle.
    # Ce qu'il doit faire, c'est construire l'etat des tours du camp et TRADUIRE ses propres
    # champs (`isKing`, `alive`) vers ceux de la regle — sans cette traduction, la regle rendrait
    # 1 pour toutes les tours, en silence.
    cas("le serveur construit l'etat des tours du camp", True, "etatTours(e.team)" in code)
    cas("le serveur demande le facteur de garde", True, "Garde.facteur(" in code)
    cas("et il traduit isKing vers estRoi", True, "estRoi = tw.isKing == true" in code)
    cas("la garde ne touche ni les unites ni les batiments poses", True,
        "if not e or not e.isBuilding or e.estBatimentPose then" in code)
    cas("le serveur s'en sert pour le delai de tir", True, "Garde.delai(" in code)
    cas("le module est livre dans la place", True,
        "shared/Garde.lua" in BUILD.read_text(encoding="utf-8"))

    # ANNONCE AU JOUEUR. Defaut mesure le 2026-09-21 : la regle change les combats (le Roi tire
    # 1,5 fois plus vite) et n'etait NULLE PART a l'ecran — seulement dans un journal serveur.
    # L'attaquant voyait son unite fondre sans comprendre, le defenseur ignorait son sursis.
    cas("le titre distingue MA garde", True, "ton Roi" in G.titre(True))
    cas("de celle d'en face", True, "ADVERSE" in G.titre(False) and "Son Roi" in G.mention(False))
    cas("les deux titres different", True, G.titre(True) != G.titre(False))
    # Le CHIFFRE doit y etre : « quelque chose a change » ne permet pas de decider si on pousse.
    cas("la mention porte le facteur reel", True, "1,5" in G.mention(True))
    cas("et il suit le module, pas un texte en dur", True,
        str(G.FACTEUR).replace(".", ",") in G.mention(False))
    # Ma garde rassure (or), celle d'en face avertit (rouge) : deux etats opposes ne peuvent pas
    # se lire pareil.
    cas("les deux teintes different", True,
        list(G.teinte(True).values()) != list(G.teinte(False).values()))
    cas("celle d'en face est rouge", True,
        list(G.teinte(False).values())[0] > list(G.teinte(False).values())[1])

    client = (ROOT / "src" / "client" / "GameClient.client.lua").read_text(encoding="utf-8")
    cas("l'etat de partie porte les deux gardes", True,
        "gardeMoi = Garde.engagee(etatTours(monCamp))" in code
        and "gardeLui = Garde.engagee(etatTours(3 - monCamp))" in code)
    cas("l'ecran de jeu charge le module", True, 'WaitForChild("Garde")' in client)
    cas("il l'affiche a chaque etat", True, "hud.majGarde(s)" in client)
    cas("les textes viennent du module", True,
        "hud.garde.mod.titre(pourMoi)" in client and "hud.garde.mod.mention(pourMoi)" in client)
    # La BASCULE est annoncee une fois ; la mention, elle, reste tant que la situation dure.
    cas("l'annonce ne se rejoue pas a chaque image", True, 'if cle ~= hud.garde.vue then' in client)
    cas("mais la mention reste pendant toute la garde", True,
        "hud.garde.titre.Visible = (moi or lui) and not s.result" in client)
    # Le MANUEL l'explique aussi, avec le chiffre du module.
    hub = (ROOT / "src" / "client" / "Hub.client.lua").read_text(encoding="utf-8")
    manuel = (ROOT / "src" / "shared" / "Manuel.lua").read_text(encoding="utf-8")
    cas("le manuel a une section DERNIERE GARDE", True, 'titre = "DERNIERE GARDE"' in manuel)
    cas("et son chiffre vient du module", True, ':WaitForChild("Garde")).FACTEUR' in hub)

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : quand il ne reste que le Roi, il se defend — sans valoir les tours perdues")
    return 0


if __name__ == "__main__":
    sys.exit(main())
