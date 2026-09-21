# -*- coding: utf-8 -*-
"""Banc de l'ASSASSIN (src/shared/Assassin.lua) : aller chercher les tireurs derriere le mur.

Deux defauts mesures, et ils se repondent :
  1. l'audit du catalogue (tools/audit_identite.py) montrait Cappuccino Assassino comme l'une des
     deux seules cartes sans AUCUNE particularite, alors que sa description promet un « assassin » ;
  2. rien ne contrait un TIREUR protege par un mur de melee : les attaquants s'arretaient sur le
     mur, exactement comme le defenseur le voulait.

Ce qu'il verifie :
  1. seules les cartes declarees chassent, et elles existent au catalogue ;
  2. un tireur est reconnu par sa PORTEE, et jamais un batiment (sinon l'assassin ne serait
     qu'une carte anti-tours de plus) ;
  3. le bonus passe bien par Cible.priorite — donc l'assassin herite de la persistance et de
     l'hysteresis, sans second chemin de ciblage ;
  4. SCENE REELLE : un tireur derriere un mur de melee. L'assassin choisit le tireur, une unite
     ordinaire choisit le mur ;
  5. mais le bonus reste BORNE : un tireur a l'autre bout de l'arene ne fait pas ignorer ce qui
     est au contact ;
  6. l'assassin ne devient pas anti-tours : face a une tour et a un tireur, il prend le tireur ;
  7. les deux modules portent la MEME portee de tireur (aucune divergence silencieuse) ;
  8. le serveur pose bien le trait sur l'unite.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHARED = ROOT / "src" / "shared"
SRC = SHARED / "Assassin.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
CARTES = SHARED / "Cards.lua"
BUILD = ROOT / "build.py"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — les tireurs restent intouchables derriere leur mur" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    A = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    C = lua.execute("return (function() " + (SHARED / "Cible.lua").read_text(encoding="utf-8") + " end)()")
    cartes = CARTES.read_text(encoding="utf-8")

    noms = sorted(A.PROFILS.keys())
    portee = float(A.PORTEE_TIREUR)
    print("  assassins : %s ; une cible est un tireur a partir de %.0f studs de portee"
          % (", ".join(noms), portee))
    cas("au moins un assassin", True, len(noms) >= 1)
    for n in noms:
        cas("%s existe au catalogue" % n, True, ('id = "%s"' % n) in cartes)
        cas("%s : bonus borne" % n, True, 0 < float(A.profil(n).bonus) <= float(A.BONUS_MAX))

    # COHERENCE avec la carte reelle : « assassin ultra rapide » doit se lire dans les chiffres.
    import re as _re

    def fiche(ident):
        j = cartes.find('id = "%s"' % ident)
        bloc = cartes[j:j + 900]
        g = lambda cle: float((_re.search(cle + r" = ([\d.]+)", bloc) or [0, 0])[1])
        return lua.table_from(dict(range=g("range"), speed=g("speed"), hp=g("hp"),
                                   count=int(g("count") or 1)))

    vitesses = [float((_re.search(r"speed = ([\d.]+)", b) or [0, 0])[1])
                for b in cartes.split(chr(9) + "{")[1:]
                if _re.search(r"speed = ([\d.]+)", b)]
    import statistics as _stat
    for n in noms:
        f = fiche(n)
        ok, raison = A.coherente(n, f)
        print("    %-12s portee %.1f | vitesse %.0f (mediane du jeu %.0f, max %.0f) | %d pv"
              % (n, float(f.range), float(f.speed), _stat.median(vitesses), max(vitesses),
                 int(f.hp)))
        cas("%s est bien un assassin rapide et fragile" % n, True, bool(ok) or raison)
        cas("%s est parmi les plus rapides du jeu" % n, True, float(f.speed) >= max(vitesses) - 2)
    # LE CONTROLE MORD : les trois refus, chacun sur un cas fabrique
    n0 = noms[0]
    cas("un assassin qui tirerait de loin est refuse", False,
        bool(A.coherente(n0, lua.table_from(dict(range=9, speed=16, hp=300)))[0]))
    cas("un assassin lent est refuse", False,
        bool(A.coherente(n0, lua.table_from(dict(range=3, speed=8, hp=300)))[0]))
    cas("un assassin trop resistant est refuse", False,
        bool(A.coherente(n0, lua.table_from(dict(range=3, speed=16, hp=2000)))[0]))
    cas("rapide, fragile et au contact : accepte", True,
        bool(A.coherente(n0, lua.table_from(dict(range=3, speed=16, hp=300)))[0]))
    cas("et la regle ne dit rien des autres cartes", True,
        bool(A.coherente("Tralalero", lua.table_from(dict(range=99, speed=1, hp=9999)))[0]))

    # AUDIT INVERSE : une carte dont le texte se dit « assassin » doit porter la regle.
    manquantes = []
    for b in cartes.split(chr(9) + "{")[1:]:
        mi = _re.search(r'id = "(\w+)"', b)
        md = _re.search(r'desc = "([^"]*)"', b)
        if mi and md and "assassin" in md.group(1).lower() and not A.estAssassin(mi.group(1)):
            manquantes.append(mi.group(1))
    cas("toute carte qui se dit assassin en est un", [], manquantes)
    cas("une carte ordinaire ne chasse pas", None, A.profil("Tralalero"))
    cas("estAssassin : non", False, A.estAssassin("Tralalero"))
    cas("estAssassin : oui", True, A.estAssassin(noms[0]))

    bonus = float(A.profil(noms[0]).bonus)

    def ennemi(nom, distance, portee_=3.0, batiment=False, vise="any"):
        return lua.table_from(dict(nom=nom, distance=distance, range=portee_,
                                   isBuilding=batiment, targets=vise))

    # 2. reconnaissance d'un tireur
    cas("une unite a longue portee est un tireur", True, A.estTireur(ennemi("archer", 5, 9.0)))
    cas("pile au seuil aussi", True, A.estTireur(ennemi("archer", 5, portee)))
    cas("juste en dessous : ce n'est pas un tireur", False,
        A.estTireur(ennemi("brute", 5, portee - 0.01)))
    cas("une melee n'en est pas un", False, A.estTireur(ennemi("brute", 5, 3.0)))
    cas("un BATIMENT n'en est jamais un", False,
        A.estTireur(ennemi("tour", 5, 20.0, batiment=True)))
    cas("cible absente", False, A.estTireur(None))

    # 3. bonus
    moi = lua.table_from(dict(chasseTireurs=bonus, isBuilding=False))
    ordinaire = lua.table_from(dict(isBuilding=False))
    cas("l'assassin gagne le bonus contre un tireur", bonus,
        float(A.bonus(moi, ennemi("archer", 5, 9.0))))
    cas("rien contre une melee", 0.0, float(A.bonus(moi, ennemi("brute", 5, 3.0))))
    cas("rien contre une tour", 0.0, float(A.bonus(moi, ennemi("tour", 5, 20.0, batiment=True))))
    cas("une unite ordinaire ne gagne rien", 0.0,
        float(A.bonus(ordinaire, ennemi("archer", 5, 9.0))))

    # et surtout : la priorite REELLE du jeu (Cible) doit en tenir compte
    cas("Cible applique le bonus de chasse", 12.0 - bonus,
        float(C.priorite(moi, ennemi("archer", 12, 9.0), 12)))
    cas("Cible ne l'applique pas a une melee", 12.0,
        float(C.priorite(moi, ennemi("brute", 12, 3.0), 12)))
    cas("ni pour une unite ordinaire", 12.0,
        float(C.priorite(ordinaire, ennemi("archer", 12, 9.0), 12)))
    cas("une tour garde SA propre logique de menace", 12.0 - float(C.BONUS_ANTI_TOUR),
        float(C.priorite(lua.table_from(dict(isBuilding=True)),
                         ennemi("belier", 12, 3.0, vise="buildings"), 12)))

    # 7. les deux modules doivent parler de la MEME portee
    cas("Assassin et Cible partagent la portee de tireur", portee, float(C.PORTEE_TIREUR))

    # 4. SCENE REELLE : un tireur cache derriere un mur de melee.
    def liste(*e):
        return lua.table_from(list(e))

    mur = ennemi("mur", 3.0, 3.0)          # au contact
    archer = ennemi("archer", 9.0, 9.0)    # 6 studs plus loin, derriere le mur
    cas("un assassin passe le mur et vise l'archer", "archer",
        C.choisir(moi, liste(mur, archer), None).nom)
    cas("une unite ordinaire s'arrete sur le mur", "mur",
        C.choisir(ordinaire, liste(mur, archer), None).nom)
    cas("l'ordre de la liste ne change rien", "archer",
        C.choisir(moi, liste(archer, mur), None).nom)

    # 5. le bonus reste borne : un archer TRES loin ne fait pas ignorer ce qui est au contact
    colle = ennemi("colle", 1.0, 3.0)
    tres_loin = ennemi("loin", 1.0 + bonus + 2, 9.0)
    cas("un archer trop loin ne passe pas devant le contact", "colle",
        C.choisir(moi, liste(colle, tres_loin), None).nom)

    # 6. il ne devient pas anti-tours
    tour = ennemi("tour", 4.0, 20.0, batiment=True)
    cas("face a une tour et a un archer, il prend l'archer", "archer",
        C.choisir(moi, liste(tour, archer), None).nom)

    # la persistance dont il herite : il ne papillonne pas entre deux archers
    a1 = ennemi("A", 9.0, 9.0)
    a2 = ennemi("B", 9.0 - float(C.MARGE_CHANGEMENT) + 0.5, 9.0)
    cas("il garde sa cible tant qu'aucune n'est nettement meilleure", "A",
        C.choisir(moi, liste(a1, a2), a1).nom)

    # 8. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Assassin")' in serveur)
    cas("le serveur pose le trait sur l'unite", True,
        "chasseTireurs = (Assassin.profil(card.id) or {}).bonus," in serveur)
    cible_src = (SHARED / "Cible.lua").read_text(encoding="utf-8")
    cas("le ciblage lit ce trait", True, "defenseur.chasseTireurs" in cible_src)
    cas("et n'ouvre aucun second chemin de ciblage", 1, serveur.count("Cible.choisir(") + serveur.count("e.cibleEnCours = best"))
    cas("le module est livre dans la place", True, "shared/Assassin.lua" in BUILD.read_text(encoding="utf-8"))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : l'assassin traverse le mur pour l'archer, sans devenir une carte anti-tours")
    return 0


if __name__ == "__main__":
    sys.exit(main())
