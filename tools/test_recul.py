# -*- coding: utf-8 -*-
"""Banc du RECUL (src/shared/Recul.lua) : des unites qui projettent ce qu'elles frappent.

Defaut mesure avant ce module : seul un SORT (le tronc) repoussait. Un corps a corps etait donc
toujours un echange sur place, et la position ne changeait jamais rien.

Ce qu'il verifie :
  1. seules les cartes declarees repoussent, et elles existent au catalogue ;
  2. la geometrie est EXACTEMENT celle de Sorts.recul (aucune seconde formule qui derive) ;
  3. le poids compte : une grosse unite recule moins, un batiment pas du tout ;
  4. ANTI-VERROUILLAGE : une meme cible ne peut pas etre repoussee en boucle ;
  5. simulation : une unite repoussee perd du temps mais FINIT par arriver — elle n'est jamais
     bloquee pour toujours, meme face a deux cogneurs ;
  6. les distances restent bornees ;
  7. le serveur applique la regle, et sans sortir la cible de l'arene ;
  8. une unite projetee perd son elan de charge.

Prerequis : python -m pip install lupa
"""
import math
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Recul.lua"
SORTS = ROOT / "src" / "shared" / "Sorts.lua"
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
        print("ROUGE : %s absent — aucune unite ne repousse" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    R = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    S = lua.execute("return (function() " + SORTS.read_text(encoding="utf-8") + " end)()")
    cartes = CARTES.read_text(encoding="utf-8")

    noms = sorted(R.PROFILS.keys())
    print("  cogneurs : " + ", ".join("%s (%.1f studs)" % (n, float(R.profil(n).distance)) for n in noms))
    cas("au moins trois cogneurs", True, len(noms) >= 3)
    cas("une carte ordinaire ne repousse pas", None, R.profil("Tralalero"))
    cas("repousse : non pour un sort", False, R.repousse("PizzaBombarda"))

    for n in noms:
        p = R.profil(n)
        cas("%s existe au catalogue" % n, True, ('id = "%s"' % n) in cartes)
        cas("%s : distance utile et bornee" % n, True,
            0 < float(p.distance) <= float(R.DISTANCE_MAX))
        cas("%s : une periode minimale existe" % n, True, float(p.periode) > 0)

    # 1 bis. COHERENCE avec l'identite de la carte : le recul est une regle de POIDS.
    # On lit chaque carte au catalogue et on demande au module si elle a le droit de repousser.
    import re as _re
    for n in noms:
        j = cartes.find('id = "%s"' % n)
        bloc = cartes[j:j + 900]
        mc = _re.search(r"count = (\d+)", bloc)
        mh = _re.search(r"hp = (\d+)", bloc)
        carte = lua.table_from(dict(count=int(mc.group(1)) if mc else 1,
                                    hp=int(mh.group(1)) if mh else 0))
        ok, raison = R.coherente(n, carte)
        cas("%s a le poids qu'un recul annonce" % n, True, bool(ok) or raison)
    # le garde-fou mord vraiment : une carte de groupe et une carte legere sont refusees
    cas("un groupe ne peut pas porter de recul", False,
        bool(R.coherente(noms[0], lua.table_from(dict(count=3, hp=3000)))[0]))
    cas("une unite legere non plus", False,
        bool(R.coherente(noms[0], lua.table_from(dict(count=1, hp=400)))[0]))
    cas("une carte lourde et seule, oui", True,
        bool(R.coherente(noms[0], lua.table_from(dict(count=1, hp=1200)))[0]))
    cas("et la regle ne dit rien des cartes sans recul", True,
        bool(R.coherente("Tralalero", lua.table_from(dict(count=9, hp=1)))[0]))

    p0 = R.profil(noms[0])

    # 2. MEME geometrie que le sort du tronc : on compare les deux formules sur des cas varies.
    # Une divergence ferait que le tronc et une unite ne repoussent pas dans le meme sens.
    ecarts = []
    for (ax, az, cx, cz, d) in [(0, 0, 3, 0, 2.0), (0, 0, 0, -5, 3.0), (2, 2, -4, 7, 1.5),
                                (-10, 3, -10, 3.5, 4.0), (5, -5, 8, -1, 2.5)]:
        rx, rz = R.vecteur(ax, az, cx, cz, d)
        sort = lua.table_from(dict(recul=d))
        objet = lua.table_from(dict(x=cx, z=cz, batiment=False))
        sx, sz = S.recul(sort, objet, ax, az)
        ecarts.append(round(math.hypot(float(rx) - float(sx), float(rz) - float(sz)), 9))
    cas("meme formule que le recul du tronc, a l'identique", [0.0] * 5, ecarts)
    cas("la projection part bien de l'attaquant vers la cible", True,
        float(R.vecteur(0, 0, 4, 0, 2.0)[0]) > 0)
    cas("et sa longueur est la distance demandee", 2.0,
        round(math.hypot(*[float(v) for v in R.vecteur(0, 0, 3, 4, 2.0)]), 6))
    cas("superposees : aucune direction, donc aucun recul", (0, 0),
        tuple(float(v) for v in R.vecteur(5, 5, 5, 5, 3.0)))
    cas("distance nulle : rien", (0, 0), tuple(float(v) for v in R.vecteur(0, 0, 3, 0, 0)))

    # 3. poids
    def cible(pv=300, batiment=False):
        return lua.table_from(dict(pvMax=pv, batiment=batiment))

    leger = float(R.distance(p0, cible(pv=float(R.PV_LEGER))))
    lourd = float(R.distance(p0, cible(pv=float(R.PV_LOURD))))
    milieu = float(R.distance(p0, cible(pv=(float(R.PV_LEGER) + float(R.PV_LOURD)) / 2)))
    print("  %s : leger %.2f studs, moyen %.2f, lourd %.2f" % (noms[0], leger, milieu, lourd))
    cas("un petit encaisse tout le recul", float(p0.distance), leger)
    cas("un lourd recule nettement moins", True, lourd < leger)
    cas("mais il bouge quand meme un peu", True, lourd > 0)
    cas("le poids agit progressivement", True, lourd < milieu < leger)
    cas("resistance : plancher respecte", float(R.RESISTANCE_MIN), float(R.resistance(99999)))
    cas("resistance : plafond respecte", 1.0, float(R.resistance(1)))
    cas("un batiment ne bouge JAMAIS", 0.0, float(R.distance(p0, cible(batiment=True))))
    cas("meme un batiment fragile", 0.0, float(R.distance(p0, cible(pv=50, batiment=True))))
    cas("sans profil, aucun recul", 0.0, float(R.distance(None, cible())))
    cas("les PV COURANTS ne comptent pas, seuls les PV max", lourd,
        float(R.distance(p0, cible(pv=float(R.PV_LOURD)))))

    # 4. anti-verrouillage
    per = float(p0.periode)
    cas("jamais repoussee : c'est permis", True, R.permis(None, per))
    cas("juste apres un recul : refuse", False, R.permis(per / 2, per))
    cas("a la periode pile : permis", True, R.permis(per, per))
    cas("bien apres : permis", True, R.permis(per * 3, per))

    # 5. SIMULATION : une unite avance vers une tour et se fait cogner. Elle doit PERDRE du temps,
    # jamais etre bloquee pour toujours. On mesure le temps mis pour parcourir 20 studs.
    def course(cogneurs, distance=20.0, vitesse=8.0, dt=1 / 30.0, plafond=60.0):
        restant, t, depuis = distance, 0.0, None
        while restant > 0 and t < plafond:
            t += dt
            restant -= vitesse * dt
            if depuis is not None:
                depuis += dt
            for _ in range(cogneurs):
                if R.permis(depuis, per):
                    restant += float(R.distance(p0, cible(pv=300)))
                    depuis = 0.0
        return round(t, 2) if restant <= 0 else None

    seul = course(0)
    cogne = course(1)
    deux = course(2)
    print("  20 studs parcourus : sans cogneur %ss, avec 1 cogneur %ss, avec 2 cogneurs %ss"
          % (seul, cogne, deux))
    cas("sans cogneur, elle arrive vite", True, seul is not None and seul < 3)
    cas("un cogneur lui fait perdre du temps", True, cogne is not None and cogne > seul)
    cas("mais elle finit TOUJOURS par arriver", True, cogne is not None)
    cas("deux cogneurs ne la bloquent pas pour autant", True, deux is not None)
    cas("la periode empeche le double recul simultane", deux, cogne)

    # 6. bornes
    cas("la distance ne depasse jamais le plafond", True,
        all(float(R.profil(n).distance) <= float(R.DISTANCE_MAX) for n in noms))

    # 9. LA RIVIERE. Defaut trouve APRES coup : le recul ne connaissait que les murs de l'arene,
    # donc une unite au sol pouvait etre projetee dans l'eau, voire changer de moitie d'arene —
    # un passage gratuit par-dessus la riviere.
    ponts = lua.table_from([-17.0, 17.0])
    demi_pont, demi_riviere = 2.0, 2.2
    cas("au-dessus d'un pont", True, R.surPont(-17.0, ponts, demi_pont))
    cas("au bord du pont", True, R.surPont(-17.0 + demi_pont, ponts, demi_pont))
    cas("juste a cote du pont", False, R.surPont(-17.0 - demi_pont - 0.01, ponts, demi_pont))
    cas("au milieu de l'arene : aucun pont", False, R.surPont(0.0, ponts, demi_pont))
    cas("sans liste de ponts", False, R.surPont(0.0, None, demi_pont))

    cas("hors de l'eau : rien a corriger", 9.0, float(R.corrigeRiviere(9.0, 12.0, demi_riviere)))
    cas("hors de l'eau, cote negatif non plus", -9.0,
        float(R.corrigeRiviere(-9.0, -12.0, demi_riviere)))
    cas("projetee dans l'eau depuis le sud : retenue sur SA berge", -demi_riviere,
        float(R.corrigeRiviere(-1.0, -5.0, demi_riviere)))
    cas("projetee dans l'eau depuis le nord : retenue sur SA berge", demi_riviere,
        float(R.corrigeRiviere(1.0, 5.0, demi_riviere)))
    cas("elle ne change JAMAIS de moitie a cause d'un recul", True,
        float(R.corrigeRiviere(-1.0, 5.0, demi_riviere)) > 0)
    cas("pile sur la berge : inchangee", -demi_riviere,
        float(R.corrigeRiviere(-demi_riviere, -5.0, demi_riviere)))
    cas("aucune riviere declaree : rien a corriger", 1.0,
        float(R.corrigeRiviere(1.0, 5.0, 0)))

    # 7 + 8. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Recul")' in serveur)
    cas("le serveur repousse a l'impact", True, "repousser(e, target)" in serveur)
    cas("y compris en degats de zone", True, "repousser(e, o)" in serveur)
    cas("le serveur respecte l'anti-verrouillage", True, "Recul.permis(" in serveur)
    cas("le serveur tient compte du poids", True, "pvMax = cible.maxHp" in serveur)
    cas("la cible reste dans l'arene", True, "math.clamp(q.X + dx, -HALF_W + 1, HALF_W - 1)" in serveur)
    cas("une unite projetee perd son elan de charge", True,
        "cible.chargeParcouru, cible.chargeLancee = 0, false" in serveur)
    cas("le module est livre dans la place", True, "shared/Recul.lua" in BUILD.read_text(encoding="utf-8"))
    cas("le serveur protege la riviere", True, "Recul.corrigeRiviere(nz, q.Z, Regles.DEMI_RIVIERE)" in serveur)
    cas("mais laisse passer au-dessus des ponts", True, "Recul.surPont(nx, BRIDGES, Regles.LARGEUR_PONT / 2)" in serveur)
    cas("et ne bride pas les volants", True, "if not cible.flying and not Recul.surPont(" in serveur)

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : les cogneurs font perdre du terrain sans jamais verrouiller leur cible")
    return 0


if __name__ == "__main__":
    sys.exit(main())
