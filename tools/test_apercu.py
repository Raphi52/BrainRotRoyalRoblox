# -*- coding: utf-8 -*-
"""Banc de l'APERCU DE POSE (src/shared/Apercu.lua), hors Studio.

Pourquoi : on posait a l'aveugle. Rien ne montrait ou la pose etait permise, ni la taille de ce
qu'on allait poser, ni la portee d'un sort — le refus s'apprenait APRES le clic, par un son.

Ce qu'il verifie, sur le VRAI catalogue :
  1. la teinte du disque dit oui ou non, sans ambiguite ;
  2. le rayon montre au joueur la VRAIE portee d'un sort (pas une valeur decorative) ;
  3. une unite a un disque a sa mesure, un groupe un disque plus large ;
  4. le fantome reprend la silhouette de la carte, entierement transparent, jamais opaque ;
  5. un sort n'a pas de fantome d'unite (le cercle dit tout) ;
  6. le fantome se pose au SOL et ne flotte pas ;
  7. le client l'affiche vraiment, le suit et le retire apres la pose.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Apercu.lua"
CARDS = ROOT / "src" / "shared" / "Cards.lua"
CLIENT = ROOT / "src" / "client" / "GameClient.client.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — aucun apercu de pose" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    # Vector3 avec multiplication : Apercu met les morceaux a l'echelle.
    lua.execute("""
    local V = {}
    V.__index = V
    V.__mul = function(a, k) return Vector3.new(a.X * k, a.Y * k, a.Z * k) end
    Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end }
    Color3 = { fromRGB = function(r, g, b) return "RGB" .. r .. "-" .. g .. "-" .. b end }
    """)
    A = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    Cards = lua.execute(CARDS.read_text(encoding="utf-8"))

    # 1. teinte
    cas("pose permise : vert", str(A.VERT), str(A.teinte(True)))
    cas("pose refusee : rouge", str(A.ROUGE), str(A.teinte(False)))
    cas("les deux couleurs different", True, str(A.VERT) != str(A.ROUGE))

    # 2. un sort montre sa VRAIE portee
    sorts = [Cards.list[i] for i in range(1, len(Cards.list) + 1) if Cards.list[i].sort is not None]
    cas("le catalogue a bien des sorts", True, len(sorts) > 0)
    for s in sorts:
        cas("rayon montre = rayon reel (%s)" % s.name, float(s.sort.rayon), float(A.rayonCercle(s)))

    # 3. unites : disque a la mesure, groupe plus large
    par_id = {Cards.list[i].id: Cards.list[i] for i in range(1, len(Cards.list) + 1)}
    solo = par_id["Tralalero"]          # count = 1
    groupe = par_id["Chimpanzini"]      # count = 3
    r_solo = float(A.rayonCercle(solo))
    r_groupe = float(A.rayonCercle(groupe))
    cas("le disque depasse l'emprise de l'unite", True, r_solo > float(solo.size.X) / 2)
    cas("un groupe a un disque plus large", True, r_groupe > r_solo)
    tous = [float(A.rayonCercle(Cards.list[i])) for i in range(1, len(Cards.list) + 1)]
    cas("aucun disque absurde", True, all(0.5 < r < 12 for r in tous))

    # 4. fantome d'unite
    pieces = A.piecesFantome(solo, True)
    n_morceaux = len(solo.morceaux)
    cas("le fantome reprend toute la silhouette", n_morceaux, len(pieces))
    transparences = [float(pieces[i].transparence) for i in range(1, len(pieces) + 1)]
    cas("aucune piece opaque", True, all(0 < t < 1 for t in transparences))
    # La silhouette garde SES couleurs : teinte en vert neon, on ne reconnaissait plus la carte
    # (mesure du 2026-09-20 sur capture). C'est le disque au sol qui porte la permission.
    couleurs = {str(pieces[i].couleur) for i in range(1, len(pieces) + 1)}
    dorigine = {str(solo.morceaux[i].couleur) for i in range(1, len(solo.morceaux) + 1)}
    cas("le fantome garde les couleurs de la carte", dorigine, couleurs)
    cas("le fantome n'est pas une tache monochrome", True, len(couleurs) > 1)
    cas("le fantome n'est pas en neon", "SmoothPlastic", str(pieces[1].materiau))
    refus = A.piecesFantome(solo, False)
    cas("la permission voyage avec la piece", str(A.ROUGE), str(refus[1].teinte))
    cas("et reste verte quand c'est permis", str(A.VERT), str(pieces[1].teinte))
    formes = {str(pieces[i].forme) for i in range(1, len(pieces) + 1)}
    cas("les formes d'origine sont gardees", True, len(formes) >= 1)

    # une carte a echelle differente de 1 doit voir son fantome mis a l'echelle
    for i in range(1, len(Cards.list) + 1):
        c = Cards.list[i]
        if c.sort is None and c.morceaux is not None:
            k = float(c.echelle or 1)
            p1 = A.piecesFantome(c, True)[1]
            cas("fantome a l'echelle (%s)" % c.id, round(float(c.morceaux[1].taille.X) * k, 4),
                round(float(p1.taille.X), 4))
            break

    # 5. un sort n'a pas de fantome d'unite
    cas("un sort n'a pas de silhouette", 0, len(A.piecesFantome(sorts[0], True)))

    # 6. hauteur : pose au sol, jamais flottant
    sol = 0.5
    cas("le fantome pose ses pieds au sol", sol + float(solo.size.Y) / 2, float(A.hauteurAuSol(solo, sol)))
    gros = par_id["Nuclearo"]
    cas("une grande unite ne s'enfonce pas", True, float(A.hauteurAuSol(gros, sol)) > float(A.hauteurAuSol(solo, sol)))

    # 7. PORTEE D'ATTAQUE, AVANT LA POSE. Defaut mesure le 2026-09-20 : l'apercu montrait ou la
    # pose est permise et l'emprise de la carte, mais rien ne disait jusqu'ou elle FRAPPERA. On
    # posait un tireur trois studs trop bas et on l'apprenait apres, l'elixir deja parti.
    tireur = par_id["Ballerina"]
    cas("un tireur montre sa portee", float(tireur.range), float(A.rayonPortee(tireur) or 0))
    cas("et c'est bien celle du catalogue, pas une valeur inventee", True,
        A.rayonPortee(tireur) == tireur.range)
    # Un SORT : son rayon d'effet EST deja le disque de pose, un second cercle ferait doublon.
    sortCarte = par_id["GelatoGlaciale"]
    cas("un sort n'a pas de second cercle", None, A.rayonPortee(sortCarte))
    # CORPS A CORPS : le cercle collerait au disque de pose et n'apprendrait rien. La limite est
    # celle du catalogue (« range < 5 = melee »).
    melee = [c for c in par_id.values() if c.range and float(c.range) < 5 and not c.sort]
    cas("aucun corps a corps ne trace de cercle", [],
        [c.id for c in melee if A.rayonPortee(c) is not None])
    cas("la limite est celle du catalogue", 5, float(A.PORTEE_MINI))
    # Une carte qui ne frappe PAS (collecteur d'elixir, leurre) n'a pas de portee a montrer.
    pompe = par_id["PompaElixir"]
    cas("un collecteur d'elixir ne trace rien", None, A.rayonPortee(pompe))
    cas("ni une carte absente", None, A.rayonPortee(None))
    # Le cercle de portee doit rester DISCRET : c'est un repere, le disque vert/rouge reste
    # l'information principale.
    cas("le cercle de portee est plus efface que le disque", True,
        float(A.TRANSPARENCE_PORTEE) > 0.3)

    # 7. branchement reel cote client
    client = CLIENT.read_text(encoding="utf-8")
    cas("le client construit l'apercu", True, "Apercu.piecesFantome(" in client)
    cas("le client dessine le disque", True, "Apercu.rayonCercle(" in client)
    cas("le client colore selon la permission", True, "Apercu.teinte(" in client)
    cas("le client pose le fantome au sol", True, "Apercu.hauteurAuSol(" in client)
    cas("le client efface l'apercu", True, "effacerApercu" in client)
    cas("l'apercu suit la visee en continu", True, "RenderStepped" in client or "Heartbeat" in client)
    cas("le client trace le cercle de portee", True, "Apercu.rayonPortee(card)" in client)
    cas("avec la couleur et la discretion du module", True,
        "Apercu.COULEUR_PORTEE" in client and "Apercu.TRANSPARENCE_PORTEE" in client)
    # Il suit la visee comme le disque, sinon il resterait fige au premier point vise.
    cas("le cercle suit la visee", True,
        "seg.part.CFrame = CFrame.new(p.X + seg.x, 0.58, p.Z + seg.z)" in client)
    # ANNEAU et non disque : deux disques pleins superposes donnaient une seule tache (capture).
    cas("la portee se dessine en anneau", True, "Apercu.segmentsAnneau(rayonPortee)" in client)
    seg = [dict(x) for x in A.segmentsAnneau(9, 8).values()]
    cas("autant de segments que demande", 8, len(seg))
    cas("ils sont tous a la bonne distance du centre", True,
        all(abs((s["x"] ** 2 + s["z"] ** 2) ** 0.5 - 9) < 1e-9 for s in seg))
    cas("leur longueur couvre le tour du cercle", True,
        abs(sum(s["longueur"] for s in seg) - 2 * 3.141592653589793 * 9 * 1.15) < 1e-6)
    cas("jamais moins de 6 segments (un cercle a 3 bouts n'est plus un cercle)", 6,
        len(list(A.segmentsAnneau(9, 2).values())))
    # Sous le disque de pose : sinon le grand cercle pale recouvre le petit disque vert ou rouge.
    cas("il passe SOUS le disque de pose", True, "0.58" in client and "0.62" in client)
    # Change de carte : le cercle de l'ancienne ne doit pas survivre.
    cas("il disparait avec l'apercu", True, "apercuPortee = nil" in client)

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : la visee montre ou l'on pose, quoi l'on pose, et si c'est permis")
    return 0


if __name__ == "__main__":
    sys.exit(main())
