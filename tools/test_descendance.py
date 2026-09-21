# -*- coding: utf-8 -*-
"""Banc de la DESCENDANCE (src/shared/Descendance.lua) : abattre le colosse ne suffit pas.

Defaut mesure avant ce module : une grosse unite mourait et il ne restait RIEN. Celui qui avait
paye 6 elixir perdait tout d'un coup, celui qui l'avait tuee n'avait plus rien a faire.

Ce qu'il verifie :
  1. seules les cartes declarees laissent quelque chose, et leurs FILLES existent au catalogue ;
  2. une fille est plus petite (moins chere) que sa mere — sinon la mort serait un cadeau ;
  3. les bornes tiennent (nombre, ecart) ;
  4. ANTI-CASCADE : une fille ne pond jamais a son tour, meme si on la declare comme sa propre mere ;
  5. les filles naissent en cercle, jamais au meme point, autour de l'endroit exact de la mort ;
  6. aLaMort rend nil pour tout le reste, et un plan complet pour une grosse carte ;
  7. simulation : une vague de morts ne fait pas exploser le nombre d'unites ;
  8. le serveur applique reellement la regle.

Prerequis : python -m pip install lupa
"""
import math
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Descendance.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
CARTES = ROOT / "src" / "shared" / "Cards.lua"
BUILD = ROOT / "build.py"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def cout_de(cartes, ident):
    """Cout en elixir lu dans le catalogue, pour l'identifiant donne."""
    marque = 'id = "%s"' % ident
    i = cartes.find(marque)
    if i < 0:
        return None
    j = cartes.find("cost = ", i)
    if j < 0:
        return None
    return int(cartes[j + 7:j + 10].strip().rstrip(","))


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — les colosses ne laissent rien" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    D = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    cartes = CARTES.read_text(encoding="utf-8")

    meres = sorted(D.PROFILS.keys())
    print("  cartes a descendance : " + ", ".join(meres))
    cas("au moins trois cartes laissent une descendance", True, len(meres) >= 3)
    cas("une carte ordinaire ne laisse rien", None, D.profil("Tralalero"))
    cas("un identifiant inconnu n'est pas une erreur", None, D.profil("RienDuTout"))
    cas("laisseQuelqueChose : non pour un sort", False, D.laisseQuelqueChose("PizzaBombarda"))

    # 1 + 2 + 3 : chaque profil tient debout
    for m in meres:
        p = D.profil(m)
        fille = p.fille
        cas("%s : la mere existe au catalogue" % m, True, ('id = "%s"' % m) in cartes)
        cas("%s : la fille %s existe au catalogue" % (m, fille), True, ('id = "%s"' % fille) in cartes)
        cas("%s : la fille n'est pas la mere" % m, True, fille != m)
        cm, cf = cout_de(cartes, m), cout_de(cartes, fille)
        cas("%s : la fille (%s elixir) est plus petite que la mere (%s)" % (m, cf, cm), True,
            cm is not None and cf is not None and cf < cm)
        cas("%s : nombre borne" % m, True, 1 <= int(p.nombre) <= int(D.NOMBRE_MAX))
        cas("%s : nombre entier" % m, True, float(p.nombre) == int(p.nombre))
        cas("%s : ecart borne" % m, True, 0 < float(p.ecart) <= float(D.ECART_MAX))
        # une fille ne doit jamais etre elle-meme une mere : sinon cascade au premier echange
        cas("%s : la fille ne pond pas elle-meme" % m, False, D.laisseQuelqueChose(fille))

    m0 = meres[0]
    # 1 bis. COHERENCE avec l'identite de la carte : la descendance est le privilege d'un
    # colosse SEUL, et elle ne doit jamais rendre plus de la moitie de ce qu'on vient d'abattre.
    import re as _re

    def fiche(ident):
        j = cartes.find('id = "%s"' % ident)
        bloc = cartes[j:j + 900]
        g = lambda cle, defaut: int((_re.search(cle + r" = (\d+)", bloc) or [0, defaut])[1])
        return lua.table_from(dict(count=g("count", 1), hp=g("hp", 0)))

    for m in meres:
        pr = D.profil(m)
        ok, raison = D.coherente(m, fiche(m), fiche(pr.fille))
        part = int(fiche(pr.fille).hp * int(pr.nombre) * 100 / max(1, fiche(m).hp))
        print("    %-10s rend %d%% de sa mere" % (m, part))
        cas("%s est un colosse seul, et rend peu" % m, True, bool(ok) or raison)
    # le garde-fou mord : groupe, poids plume, descendance trop genereuse
    grosse = lua.table_from(dict(count=1, hp=2000))
    cas("un groupe ne pond pas a sa mort", False,
        bool(D.coherente(m0, lua.table_from(dict(count=3, hp=2000)), None)[0]))
    cas("une unite legere non plus", False,
        bool(D.coherente(m0, lua.table_from(dict(count=1, hp=300)), None)[0]))
    cas("ni une descendance qui rend plus que la moitie", False,
        bool(D.coherente(m0, grosse, lua.table_from(dict(hp=900)))[0]))
    cas("mais une descendance modeste, oui", True,
        bool(D.coherente(m0, grosse, lua.table_from(dict(hp=200)))[0]))
    cas("et la regle ne dit rien des cartes sans descendance", True,
        bool(D.coherente("Tralalero", lua.table_from(dict(count=9, hp=1)), None)[0]))

    p0 = D.profil(m0)

    # 4. anti-cascade
    cas("une unite posee par le joueur peut pondre", True, D.autorisee(0))
    cas("une fille ne pond pas", False, D.autorisee(1))
    cas("ni une petite-fille", False, D.autorisee(2))
    cas("profondeur absente = posee par le joueur", True, D.autorisee(None))
    plan = D.aLaMort(m0, 0, 10, 20)
    cas("la mere a bien un plan", True, plan is not None)
    cas("sa fille naitra en profondeur 1", 1, int(plan.profondeur))
    cas("et cette fille ne pondra rien", None, D.aLaMort(m0, 1, 0, 0))

    # 5. positions
    pts = [(float(pt.x), float(pt.z)) for pt in plan.positions.values()]
    cas("autant de positions que de filles", int(p0.nombre), len(pts))
    cas("aucune fille au meme point", len(pts), len(set(pts)))
    ecart = float(p0.ecart)
    for (x, z) in pts:
        d = math.hypot(x - 10, z - 20)
        cas("fille posee a l'ecart annonce (%.1f)" % d, True, abs(d - ecart) < 1e-6)
    cas("les positions suivent le lieu de la mort", True,
        all(abs(float(pt.x) - 100) <= ecart + 1e-9 for pt in D.aLaMort(m0, 0, 100, 0).positions.values()))
    cas("sans profil, aucune position", 0, len(list(D.positions(0, 0, None).values())))

    # 6. aLaMort ne rend rien pour le reste
    cas("une carte ordinaire ne laisse rien a sa mort", None, D.aLaMort("Tralalero", 0, 0, 0))

    # 7. SIMULATION : 8 grosses unites meurent, puis TOUTES leurs filles meurent aussi.
    # Sans la garde de profondeur, ce serait une explosion sans fin ; on mesure le total reel.
    a_mourir = [(m0, 0)] * 8
    nes, tours = 0, 0
    while a_mourir and tours < 10:
        tours += 1
        suivants = []
        for (ident, prof) in a_mourir:
            plan = D.aLaMort(ident, prof, 0, 0)
            if plan:
                for _ in range(int(plan.nombre)):
                    nes += 1
                    suivants.append((plan.fille, int(plan.profondeur)))
        a_mourir = suivants
    print("  8 colosses morts -> %d unites nees en %d vagues" % (nes, tours))
    cas("la descendance s'arrete a la premiere generation", 8 * int(p0.nombre), nes)
    cas("et le calcul se termine", True, tours <= 3)

    # 8. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Descendance")' in serveur)
    cas("le serveur decide a la mort", True, "Descendance.aLaMort(" in serveur)
    cas("le serveur fait naitre les filles", True, "bebe.profondeur = ne.profondeur" in serveur)
    cas("l'unite porte sa profondeur des sa pose", True, "profondeur = 0," in serveur)
    cas("les filles naissent aux positions calculees", True, "ipairs(ne.positions)" in serveur)
    cas("le module est livre dans la place", True, "shared/Descendance.lua" in BUILD.read_text(encoding="utf-8"))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : les colosses laissent une descendance, et elle ne fait jamais boule de neige")
    return 0


if __name__ == "__main__":
    sys.exit(main())
