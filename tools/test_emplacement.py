# -*- coding: utf-8 -*-
"""Banc de l'EMPLACEMENT (src/shared/Emplacement.lua) : ou le robot pose un batiment.

Defaut MESURE en moteur, pas suppose (melee du 2026-09-20, journal 191212Z) :
`[BOT] ... raison=pose_refusee` apparait 31 fois sur une seule partie, et les 31 concernent la
meme carte — Muro Spaghetti, un batiment. Le robot lui calculait une position prevue pour des
unites, sans regarder ou etaient ses propres batiments ; la regle du jeu refuse un batiment a
moins de 4 studs d'un autre, donc il reproposait le meme point en boucle.

Ce qu'il verifie :
  1. les candidats restent dans la moitie du camp, hors de la bande de riviere, dans l'arene ;
  2. ils sont ordonnes : on reste d'abord dans la voie visee, on s'en ecarte seulement ensuite ;
  3. il trouve une place quand il y en a une, et la PREMIERE acceptee ;
  4. SCENE REELLE : un batiment deja pose bloque son point habituel -> il en trouve un autre,
     a plus de l'ecart minimal du premier (verifie avec la VRAIE regle du jeu, pas une copie) ;
  5. arene saturee : il rend nil, pour que le robot PASSE au lieu d'insister ;
  6. la regle n'est jamais recopiee : sans fonction de validation, il ne propose rien ;
  7. le serveur l'utilise, et passe son tour quand il n'y a pas de place.

Prerequis : python -m pip install lupa
"""
import math
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHARED = ROOT / "src" / "shared"
SRC = SHARED / "Emplacement.lua"
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
        print("ROUGE : %s absent — le robot repropose la meme case refusee" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    E = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    # LA VRAIE regle du jeu, chargee telle quelle : le banc ne la recopie pas.
    B = lua.execute("return (function() " + (SHARED / "Batiments.lua").read_text(encoding="utf-8") + " end)()")

    bande = float(B.BANDE_RIVIERE)
    ecart = float(B.ECART_MINIMAL)
    print("  regle du jeu : bande de riviere %.0f studs, ecart minimal entre batiments %.0f studs"
          % (bande, ecart))

    VOIE_X, HALF_W = 17.0, 28.0
    s = -1  # camp 1

    # 1 + 2. les candidats
    cands = [(float(c.x), float(c.z)) for c in E.candidats(VOIE_X, s, HALF_W - 2).values()]
    print("  %d emplacements candidats, du plus au moins prefere" % len(cands))
    cas("il y a des candidats", True, len(cands) > 5)
    cas("tous dans la moitie du camp", True, all(z < 0 for _, z in cands))
    cas("tous hors de la bande de riviere", True, all(abs(z) >= bande for _, z in cands))
    cas("tous dans l'arene", True, all(abs(x) <= HALF_W - 2 for x, _ in cands))
    cas("le premier candidat est dans la voie visee", VOIE_X, cands[0][0])
    cas("et au plus pres de la riviere (on intercepte, on ne se cache pas)",
        float(E.Z_MIN) * -1, cands[0][1])
    ecarts = [abs(x - VOIE_X) for x, _ in cands[:3]]
    cas("on s'ecarte progressivement de la voie", True, ecarts == sorted(ecarts))
    cas("aucun doublon", len(cands), len(set(cands)))

    # 3. recherche avec la vraie regle, terrain vide
    def permise_avec(autres_py):
        autres = lua.table_from([lua.table_from(dict(x=a[0], z=a[1])) for a in autres_py])
        return lua.eval("function(B, camp, autres) return function(x, z) "
                        "return B.posePermise(camp, x, z, autres) end end")(B, 1, autres)

    x, z = E.pourBatiment(VOIE_X, s, HALF_W - 2, permise_avec([]))
    cas("terrain vide : il trouve une place", True, x is not None)
    cas("et c'est le premier candidat", cands[0], (float(x), float(z)))
    cas("cette place est acceptee par la VRAIE regle du jeu", True,
        B.posePermise(1, x, z, lua.table_from([])))

    # 4. SCENE REELLE : son point habituel est deja occupe
    occupe = [(float(cands[0][0]), float(cands[0][1]))]
    x2, z2 = E.pourBatiment(VOIE_X, s, HALF_W - 2, permise_avec(occupe))
    cas("place prise : il en trouve une autre", True, x2 is not None)
    cas("et ce n'est plus la meme", True, (float(x2), float(z2)) != cands[0])
    d = math.hypot(float(x2) - occupe[0][0], float(z2) - occupe[0][1])
    print("  batiment deja pose en (%.0f, %.0f) -> nouvelle place (%.0f, %.0f), a %.1f studs"
          % (occupe[0][0], occupe[0][1], float(x2), float(z2), d))
    cas("a plus que l'ecart minimal du premier", True, d >= ecart)
    cas("acceptee par la vraie regle", True,
        B.posePermise(1, x2, z2, lua.table_from([lua.table_from(dict(x=occupe[0][0], z=occupe[0][1]))])))

    # avec deux batiments poses, il trouve encore
    occupe2 = occupe + [(float(x2), float(z2))]
    x3, z3 = E.pourBatiment(VOIE_X, s, HALF_W - 2, permise_avec(occupe2))
    cas("deux places prises : il en trouve une troisieme", True, x3 is not None)
    cas("loin des deux", True,
        all(math.hypot(float(x3) - a[0], float(z3) - a[1]) >= ecart for a in occupe2))

    # 5. arene saturee : il doit renoncer
    satures = [(c[0], c[1]) for c in cands]
    rien = E.pourBatiment(VOIE_X, s, HALF_W - 2, permise_avec(satures))
    cas("toutes les places prises : il renonce (pas d'insistance)", None, rien)

    # 6. aucune regle recopiee
    cas("sans fonction de validation, il ne propose rien", None,
        E.pourBatiment(VOIE_X, s, HALF_W - 2, None))
    # On cherche la duplication dans le CODE, pas dans les commentaires : citer la regle en
    # commentaire est utile, la recopier en dur serait le defaut (deux verites qui divergent).
    code = chr(10).join(l.split("--")[0] for l in SRC.read_text(encoding="utf-8").splitlines())
    cas("le module ne recopie pas la distance entre batiments", False, "ECART_MINIMAL" in code)
    cas("ni la bande de riviere", False, "BANDE_RIVIERE" in code)
    cas("et il n'invente aucune distance en dur", False, ("< 4" in code or "4 studs" in code))

    # l'autre camp fonctionne pareil, en miroir
    xm, zm = E.pourBatiment(-VOIE_X, 1, HALF_W - 2, lua.eval(
        "function(B, autres) return function(x, z) return B.posePermise(2, x, z, autres) end end")(
        B, lua.table_from([])))
    cas("camp 2 : il trouve aussi une place", True, xm is not None)
    cas("et elle est bien dans SA moitie (z positifs)", True, float(zm) > 0)

    # 7. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Emplacement")' in serveur)
    cas("le serveur cherche une place libre", True, "Emplacement.pourBatiment(voieX, s, HALF_W - 2, permise)" in serveur)
    cas("il donne la vraie regle du jeu", True, "return Batiments.posePermise(team, px, pz, autres)" in serveur)
    cas("il regarde ses propres batiments", True, "o.estBatimentPose and o.team == team" in serveur)
    cas("et il PASSE quand il n'y a pas de place", True, '"batiment_sans_place"' in serveur)
    cas("l'ancien tirage au hasard a disparu", False, "z = s * math.random(12, 18)" in serveur)
    cas("le module est livre dans la place", True, "shared/Emplacement.lua" in BUILD.read_text(encoding="utf-8"))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : le robot pose ses batiments la ou c'est permis, et passe son tour sinon")
    return 0


if __name__ == "__main__":
    sys.exit(main())
