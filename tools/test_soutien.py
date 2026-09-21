# -*- coding: utf-8 -*-
"""Banc du SOUTIEN (src/shared/Soutien.lua) : des cartes qui rendent les autres meilleures.

Defaut mesure avant ce module : toutes les cartes se jugeaient UNE PAR UNE. Poser deux cartes
ensemble ne valait jamais mieux que les poser separement — aucune raison de composer une poussee.

Ce qu'il verifie :
  1. seules les cartes declarees renforcent, et elles existent au catalogue ;
  2. le bonus ne s'applique QUE dans le rayon, et il tombe net au-dela ;
  3. jamais aux ennemis, jamais aux batiments, jamais a soi-meme ;
  4. NON-CUMULATIF : dix tambours identiques ne valent pas mieux qu'un seul ;
  5. deux soutiens DIFFERENTS se completent (chacun son meilleur effet), sans depasser le plafond ;
  6. la cadence RACCOURCIT le delai entre deux coups, elle ne l'allonge pas ;
  7. le bonus n'est jamais stocke : la mort du soutien le retire a l'instant meme ;
  8. le serveur applique reellement la regle.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Soutien.lua"
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
        print("ROUGE : %s absent — aucune carte n'en renforce une autre" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    S = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    cartes = CARTES.read_text(encoding="utf-8")

    noms = sorted(S.PROFILS.keys())
    print("  cartes de soutien : " + ", ".join(noms))
    cas("au moins trois soutiens", True, len(noms) >= 3)
    cas("une carte ordinaire ne renforce rien", None, S.profil("Tralalero"))

    # COHERENCE : un soutien tient AVEC les siens. On lit chaque porteur au catalogue, et on lui
    # demande aussi son elan de charge — une unite qui s'elance plus loin que son aura ne porte
    # abandonne ceux qu'elle renforce.
    import re as _re
    charge_src = (ROOT / "src" / "shared" / "Charge.lua").read_text(encoding="utf-8")

    def elan(ident):
        m = _re.search(ident + r"\s*=\s*\{ distance = ([\d.]+)", charge_src)
        return float(m.group(1)) if m else 0.0

    def fiche(ident):
        j = cartes.find('id = "%s"' % ident)
        bloc = cartes[j:j + 900]
        g = lambda cle, d: float((_re.search(cle + r" = ([\d.]+)", bloc) or [0, d])[1])
        return lua.table_from(dict(count=int(g("count", 1)), range=g("range", 0), hp=g("hp", 0)))

    for n in noms:
        ok, raison = S.coherente(n, fiche(n), elan(n))
        print("    %-12s portee %.1f | aura %.1f | elan de charge %.1f"
              % (n, float(fiche(n).range), float(S.profil(n).rayon), elan(n)))
        cas("%s tient avec les siens" % n, True, bool(ok) or raison)
    # le controle MORD : les trois refus, chacun sur un cas fabrique
    appui = lua.table_from(dict(count=1, range=8, hp=500))
    cas("un soutien qui charge plus loin que son aura est refuse", False,
        bool(S.coherente(noms[0], appui, 99)[0]))
    cas("un soutien de groupe est refuse", False,
        bool(S.coherente(noms[0], lua.table_from(dict(count=2, range=8, hp=500)), 0)[0]))
    cas("un soutien au contact est refuse", False,
        bool(S.coherente(noms[0], lua.table_from(dict(count=1, range=3, hp=500)), 0)[0]))
    cas("un soutien a distance, seul, sans charge : accepte", True,
        bool(S.coherente(noms[0], appui, 0)[0]))
    cas("et la regle ne dit rien des cartes sans aura", True,
        bool(S.coherente("Tralalero", lua.table_from(dict(count=9, range=1, hp=1)), 50)[0]))
    cas("estSoutien : non pour un sort", False, S.estSoutien("PizzaBombarda"))

    plafond = float(S.MAX)
    for n in noms:
        p = S.profil(n)
        cas("%s existe au catalogue" % n, True, ('id = "%s"' % n) in cartes)
        cas("%s : rayon utile et borne" % n, True, 0 < float(p.rayon) <= float(S.RAYON_MAX))
        cas("%s : degats bornes" % n, True, 1 <= float(p.degats) <= plafond)
        cas("%s : cadence bornee" % n, True, 1 <= float(p.cadence) <= plafond)
        cas("%s : il apporte au moins un effet" % n, True,
            float(p.degats) > 1 or float(p.cadence) > 1)

    def moi(x=0, z=0, camp=1, batiment=False, id="Tralalero"):
        return lua.table_from(dict(x=x, z=z, camp=camp, estBatiment=batiment, id=id))

    def s(id, x=0, z=0, camp=1, vivant=True):
        return lua.table_from(dict(id=id, x=x, z=z, camp=camp, vivant=vivant))

    def liste(*e):
        return lua.table_from(list(e))

    fort = max(noms, key=lambda n: float(S.profil(n).degats))
    pf = S.profil(fort)
    r, mult = float(pf.rayon), float(pf.degats)
    print("  reference : %s, rayon %.1f, degats x%.2f" % (fort, r, mult))

    # 2. rayon
    d, c = S.bonus(moi(), liste(s(fort, 0, 1)))
    cas("un allie colle au soutien est renforce", mult, float(d))
    d, c = S.bonus(moi(), liste(s(fort, 0, r - 0.01)))
    cas("juste dans le rayon : renforce", mult, float(d))
    d, c = S.bonus(moi(), liste(s(fort, 0, r + 0.01)))
    cas("juste au-dela : plus rien, net", 1.0, float(d))
    cas("aucun soutien : aucun bonus", (1.0, 1.0), tuple(float(v) for v in S.bonus(moi(), liste())))
    cas("liste absente : aucun bonus", (1.0, 1.0), tuple(float(v) for v in S.bonus(moi(), None)))
    cas("dansRayon compte bien en distance", True, S.dansRayon(3, 4, 5))
    cas("et exclut au-dela", False, S.dansRayon(3, 4, 4.99))

    # 3. camp, batiments, soi-meme
    d, _ = S.bonus(moi(camp=2), liste(s(fort, 0, 1, camp=1)))
    cas("un soutien ne renforce jamais l'ennemi", 1.0, float(d))
    d, _ = S.bonus(moi(batiment=True), liste(s(fort, 0, 1)))
    cas("une tour ne profite d'aucune aura", 1.0, float(d))
    d, _ = S.bonus(moi(id=fort), liste(s(fort, 0, 0)))
    cas("un soutien ne se renforce pas lui-meme", 1.0, float(d))
    d, _ = S.bonus(moi(x=5, z=5, id=fort), liste(s(fort, 5, 6)))
    cas("mais deux soutiens identiques se renforcent l'un l'autre", mult, float(d))
    d, _ = S.bonus(moi(), liste(s(fort, 0, 1, vivant=False)))
    cas("un soutien mort ne renforce rien", 1.0, float(d))

    # 4. non-cumul
    dix = liste(*[s(fort, 0, 1) for _ in range(10)])
    d, _ = S.bonus(moi(), dix)
    cas("dix tambours identiques ne valent pas plus qu'un", mult, float(d))

    # 5. complementarite + plafond
    cadenceur = max(noms, key=lambda n: float(S.profil(n).cadence))
    if cadenceur != fort:
        d, c = S.bonus(moi(), liste(s(fort, 0, 1), s(cadenceur, 0, 1)))
        cas("deux soutiens differents se completent (degats)", mult, float(d))
        cas("deux soutiens differents se completent (cadence)",
            float(S.profil(cadenceur).cadence), float(c))
    tous = liste(*[s(n, 0, 1) for n in noms])
    d, c = S.bonus(moi(), tous)
    cas("tous les soutiens a la fois : degats sous le plafond", True, 1 < float(d) <= plafond)
    cas("tous les soutiens a la fois : cadence sous le plafond", True, 1 < float(c) <= plafond)

    # 6. degats et delai
    cas("degats majores, en entier", int(round(100 * mult)), S.degats(100, mult))
    cas("sans bonus, degats inchanges", 100, S.degats(100, 1))
    cas("un multiplicateur absent ne change rien", 100, S.degats(100, None))
    cas("un multiplicateur farfelu est plafonne", S.degats(100, plafond), S.degats(100, 99))
    cas("une meilleure cadence RACCOURCIT le delai", 0.8, round(float(S.delaiAttaque(1.0, 1.25)), 6))
    cas("sans bonus le delai ne bouge pas", 1.0, float(S.delaiAttaque(1.0, 1)))
    cas("le delai ne s'allonge jamais", True, float(S.delaiAttaque(1.0, 0.5)) <= 1.0)

    # 7. rien n'est stocke : on rejoue la meme unite image par image autour d'une mort
    porteur = moi()
    vivants = [s(fort, 0, 1)]
    suite = []
    for image in range(6):
        if image == 3:
            vivants = []          # le soutien meurt
        d, _ = S.bonus(porteur, liste(*vivants))
        suite.append(round(float(d), 3))
    print("  degats image par image autour de la mort du soutien : %s" % suite)
    cas("renforce avant la mort", [round(mult, 3)] * 3, suite[:3])
    cas("normal des l'image suivante, sans reste", [1.0, 1.0, 1.0], suite[3:])

    # 9. HYSTERESIS : une unite a la FRONTIERE ne doit pas clignoter.
    # Mesure du 2026-09-20 : sans elle, une Bananita entrait 13 fois dans un rayon au cours de sa
    # courte vie (donc en sortait 12), et ses degats oscillaient entre 95 et 124 sans raison
    # visible. Meme remede que pour le papillonnage de cible.
    marge = float(S.MARGE_SORTIE)
    print("  marge de sortie : %.1f studs" % marge)
    cas("une marge existe", True, marge > 0)
    juste_dehors = liste(s(fort, 0, r + marge / 2))
    d_sans, _ = S.bonus(moi(), juste_dehors, False)
    d_avec, _ = S.bonus(moi(), juste_dehors, True)
    cas("juste dehors, sans hysteresis : aucun bonus", 1.0, float(d_sans))
    cas("mais on GARDE le bonus si on l'avait deja", mult, float(d_avec))
    tres_dehors = liste(s(fort, 0, r + marge + 0.01))
    d_loin, _ = S.bonus(moi(), tres_dehors, True)
    cas("au-dela de la marge, on le perd quand meme", 1.0, float(d_loin))

    # SIMULATION du papillonnage : une unite longe la frontiere, sa distance oscille legerement.
    import math as _m
    def parcours(hysteresis):
        renforcee, bascules = False, 0
        for image in range(200):
            dist = r + _m.sin(image / 4.0) * 0.6      # +/- 0,6 stud autour du rayon
            d, _c = S.bonus(moi(), liste(s(fort, 0, dist)), renforcee and hysteresis)
            neuf = float(d) > 1
            if neuf != renforcee:
                bascules += 1
            renforcee = neuf
        return bascules

    sans, avec = parcours(False), parcours(True)
    print("  200 images le long de la frontiere : %d bascules sans hysteresis, %d avec"
          % (sans, avec))
    cas("sans hysteresis, le bonus clignote", True, sans > 10)
    # 1 bascule, et une seule : l'ENTREE dans l'aura. C'est le comportement voulu — l'unite doit
    # bien etre renforcee a un moment ; ce qu'on supprime, ce sont les 16 allers-retours suivants.
    cas("avec, elle entre une fois et ne clignote plus", 1, avec)
    cas("soit au moins dix fois moins de changements", True, avec * 10 <= sans)

    # 8. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Soutien")' in serveur)
    cas("le serveur recalcule les auras a chaque image", True, "majSoutiens()" in serveur)
    cas("le serveur passe l'etat precedent (hysteresis)", True,
        "Soutien.bonus(moi, soutiens, (e.bonusDegats or 1) > 1" in serveur)
    # Depuis l'ajout du plafond commun, le serveur ne multiplie plus les bonus un par un : il les
    # COMPOSE dans Frappe. L'aura doit donc apparaitre dans cette composition.
    cas("le serveur majore les degats", True, "Frappe.composer({ e.bonusDegats or 1" in serveur)
    cas("et la composition est plafonnee", True, "Frappe.degats(e.dmg, total)" in serveur)
    cas("le serveur raccourcit le delai d'attaque", True, "Soutien.delaiAttaque(e.atkSpeed" in serveur)
    cas("le serveur reconnait les cartes de soutien", True, "Soutien.estSoutien(" in serveur)
    cas("le module est livre dans la place", True, "shared/Soutien.lua" in BUILD.read_text(encoding="utf-8"))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : les soutiens renforcent sans s'empiler, et leur mort retire le bonus a l'instant")
    return 0


if __name__ == "__main__":
    sys.exit(main())
