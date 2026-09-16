# -*- coding: utf-8 -*-
"""Banc d'EQUILIBRE carte par carte, hors Studio.

Pourquoi il existe : build.py --autotest --sim mesure l'ecart de NIVEAUX entre deux camps
(1-1, 1-3, 3-5) et ne dit rien de chaque carte. Ici on fait s'affronter les cartes DEUX A DEUX
a ELIXIR EGAL, avec les regles de combat lues dans src/server/GameServer.server.lua :

  - chaque carte pose `count` unites de `hp` PV et `dmg` degats (GameServer:462) ;
  - une unite avance a `speed` studs/s jusqu'a etre a `range` de sa cible, puis frappe
    toutes les `atkSpeed` secondes (GameServer:1381) ;
  - `canHit` (GameServer:474) : une carte `targets = "buildings"` ne peut pas toucher une
    unite, et une MELEE (range < 5) non volante ne peut pas toucher un volant ;
  - `splash` (GameServer:608) : les degats touchent tous les ennemis dans le rayon.

A elixir egal : la carte a 2 elixir est posee 3 fois face a la carte a 3 elixir posee 2 fois
(chaque camp depense 6 elixir). C'est la comparaison qui compte dans une partie, ou l'elixir
est la seule ressource.

LIMITES ASSUMEES, a ne pas confondre avec une partie reelle : combat en LIGNE (une seule
dimension), pas de tours, pas de ponts, pas de cycle de cartes, niveaux 1 des deux cotes.
Le banc dit qui gagne un echange direct, pas qui gagne une partie.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
CARDS = ROOT / "src" / "shared" / "Cards.lua"

DT = 0.1
DUREE_MAX = 120.0
DISTANCE_DEPART = 30.0
# Tour de la couronne, lue dans GameServer.server.lua:260-261 (camp au niveau 1).
TOUR = dict(hp=3400, dmg=55, rng=14.0, atk=0.85)


class Unite:
    def __init__(self, carte, x, camp, i):
        self.c = carte
        self.x = x + i * 0.6
        self.camp = camp
        self.hp = carte["hp"]
        self.cd = 0.0

    @property
    def vivante(self):
        return self.hp > 0


def peut_toucher(att, cible):
    """canHit, GameServer.server.lua:474."""
    if att.c["targets"] == "buildings" and not cible.c.get("batiment"):
        return False
    if cible.c.get("flying") and att.c["range"] < 5 and not att.c.get("flying"):
        return False
    return True


def duel(a, na, b, nb, defenseur=None):
    """Rend (pv_restants_a, pv_restants_b) en proportion, apres DUREE_MAX au plus.

    `defenseur` (0 = a, 1 = b, None = personne) reste sur place et laisse l'autre traverser.
    Sans cela, les deux camps se rejoignent au milieu et la PORTEE ne sert presque a rien :
    la mesure du 2026-09-16 mettait alors les quatre tireurs en bas de tableau, quelles que
    soient leurs statistiques. Dans une partie, une carte a distance est posee en defense et
    tire pendant toute la traversee adverse. Chaque paire se rencontre donc DEUX fois, chacune
    une fois en defense, et le score est la moyenne.
    """
    ga = [Unite(a, 0.0, 0, i) for i in range(na * a["count"])]
    gb = [Unite(b, DISTANCE_DEPART, 1, i) for i in range(nb * b["count"])]
    total_a = sum(u.hp for u in ga) or 1
    total_b = sum(u.hp for u in gb) or 1
    t = 0.0
    while t < DUREE_MAX:
        vivants = [u for u in ga + gb if u.vivante]
        if not [u for u in ga if u.vivante] or not [u for u in gb if u.vivante]:
            break
        for u in vivants:
            if not u.vivante:
                continue
            adverses = [o for o in (gb if u.camp == 0 else ga) if o.vivante and peut_toucher(u, o)]
            if not adverses:
                continue  # impuissante : elle ne peut rien viser (ex. carte anti-tours)
            cible = min(adverses, key=lambda o: abs(o.x - u.x))
            d = abs(cible.x - u.x)
            if d > u.c["range"] and u.camp != defenseur:
                pas = min(d - u.c["range"], u.c["speed"] * DT)
                u.x += pas if cible.x > u.x else -pas
                d = abs(cible.x - u.x)
            u.cd -= DT
            if d <= u.c["range"] and u.cd <= 0:
                u.cd = u.c["atkSpeed"]
                if u.c.get("splash"):
                    for o in adverses:
                        if abs(o.x - cible.x) <= u.c["splash"]:
                            o.hp -= u.c["dmg"]
                else:
                    cible.hp -= u.c["dmg"]
        t += DT
    reste_a = sum(max(0, u.hp) for u in ga) / total_a
    reste_b = sum(max(0, u.hp) for u in gb) / total_b
    return reste_a, reste_b


def degats_de_tour_par_elixir(c):
    """PV arraches a une tour par UN elixir de cette carte, jusqu'a ce qu'elle meure.

    Une seule pose, la tour riposte. C'est la mesure qui juge les cartes anti-tours :
    les faire jouer des duels qu'elles ne peuvent PAS mener (canHit les empeche de viser
    une unite) ne mesurerait que cette interdiction.
    """
    unites = [Unite(c, 0.0, 0, i) for i in range(c["count"])]
    tour = dict(hp=TOUR["hp"], cd=0.0, x=DISTANCE_DEPART)
    t = 0.0
    while t < DUREE_MAX:
        vivantes = [u for u in unites if u.vivante]
        if not vivantes or tour["hp"] <= 0:
            break
        for u in vivantes:
            d = abs(tour["x"] - u.x)
            if d > u.c["range"]:
                u.x += min(d - u.c["range"], u.c["speed"] * DT)
                d = abs(tour["x"] - u.x)
            u.cd -= DT
            if d <= u.c["range"] and u.cd <= 0:
                u.cd = u.c["atkSpeed"]
                tour["hp"] -= u.c["dmg"]
        # riposte de la tour sur l'unite la plus proche a portee
        a_portee = [u for u in vivantes if abs(tour["x"] - u.x) <= TOUR["rng"]]
        tour["cd"] -= DT
        if a_portee and tour["cd"] <= 0:
            tour["cd"] = TOUR["atk"]
            min(a_portee, key=lambda u: abs(tour["x"] - u.x)).hp -= TOUR["dmg"]
        t += DT
    return (TOUR["hp"] - max(0, tour["hp"])) / c["cost"]


def charger_cartes():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }")
    lua.execute("Vector3 = { new = function(x, y, z) return { x, y, z } end }")
    brut = lua.execute(CARDS.read_text(encoding="utf-8"))["list"]
    cartes = []
    for c in brut.values():
        cartes.append(dict(id=c["id"], name=c["name"], cost=int(c["cost"]), hp=float(c["hp"]),
                           dmg=float(c["dmg"]), range=float(c["range"]), speed=float(c["speed"]),
                           atkSpeed=float(c["atkSpeed"]), count=int(c["count"]),
                           targets=c["targets"], flying=bool(c["flying"]),
                           splash=float(c["splash"]) if c["splash"] else None,
                           prix=int(c["prix"]) if c["prix"] else None, batiment=False))
    return cartes


def main():
    cartes = charger_cartes()
    # Deux roles, deux mesures. Une carte `targets = "buildings"` ne peut viser aucune unite
    # (canHit) : la classer sur des duels ne mesurerait que cette regle, pas son equilibre.
    combattantes = [c for c in cartes if c["targets"] != "buildings"]
    antitours = [c for c in cartes if c["targets"] == "buildings"]
    print("%d cartes : %d polyvalentes, %d anti-tours" % (len(cartes), len(combattantes), len(antitours)))

    scores = {c["id"]: 0.0 for c in combattantes}
    duels = {c["id"]: 0 for c in combattantes}
    for i, a in enumerate(combattantes):
        for b in combattantes[i + 1:]:
            # elixir egal : chacun depense cost_a * cost_b ; chacun defend une fois
            for qui_defend in (0, 1):
                ra, rb = duel(a, b["cost"], b, a["cost"], defenseur=qui_defend)
                if ra > rb:
                    pa, pb = 1.0, 0.0
                elif rb > ra:
                    pa, pb = 0.0, 1.0
                else:
                    pa = pb = 0.5
                scores[a["id"]] += pa
                scores[b["id"]] += pb
                duels[a["id"]] += 1
                duels[b["id"]] += 1

    print("\nDUELS A ELIXIR EGAL — cartes polyvalentes")
    print("%-28s %5s %6s %10s  %s" % ("CARTE", "COUT", "TAUX", "TOUR/ELIX", "REMARQUE"))
    lignes = []
    for c in sorted(combattantes, key=lambda c: -scores[c["id"]] / duels[c["id"]]):
        taux = scores[c["id"]] / duels[c["id"]]
        remarque = []
        if c["range"] < 5 and not c["flying"]:
            remarque.append("melee : ne touche pas les volants")
        if c["prix"]:
            remarque.append("%d pieces" % c["prix"])
        lignes.append((c, taux))
        print("%-28s %5d %5.0f%% %10.0f  %s"
              % (c["name"], c["cost"], taux * 100, degats_de_tour_par_elixir(c), ", ".join(remarque)))

    print("\nCARTES ANTI-TOURS — jugees sur les PV de tour arraches par elixir")
    print("%-28s %5s %10s  %s" % ("CARTE", "COUT", "TOUR/ELIX", "REMARQUE"))
    degats = []
    for c in sorted(antitours, key=lambda c: -degats_de_tour_par_elixir(c)):
        d = degats_de_tour_par_elixir(c)
        degats.append((c, d))
        print("%-28s %5d %10.0f  %s"
              % (c["name"], c["cost"], d, ("%d pieces" % c["prix"]) if c["prix"] else ""))

    dominantes = [c["name"] for c, t in lignes if t >= 0.70]
    inutiles = [c["name"] for c, t in lignes if t <= 0.30]
    print("\nDOMINENT (>= 70 %% des duels) : %s" % (", ".join(dominantes) or "aucune"))
    print("NE SERVENT JAMAIS (<= 30 %%) : %s" % (", ".join(inutiles) or "aucune"))

    volants = [c["name"] for c in cartes if c["flying"]]
    anti_air = [c for c in cartes if c["range"] >= 5 or c["flying"]]
    # CRITERE CHOISI (2026-09-16) : ce qui compte n'est pas le nombre TOTAL de cartes capables
    # de toucher un volant, mais ce qu'un joueur peut mettre dans son deck sans rien acheter.
    # Un seuil sur le total (« la moitie du catalogue ») ne dit rien du joueur neuf.
    anti_air_offertes = [c for c in anti_air if not c["prix"]]
    print("\nvolants : %s" % ", ".join(volants))
    print("capables de les toucher : %d cartes sur %d, dont %d offertes (%s)"
          % (len(anti_air), len(cartes), len(anti_air_offertes),
             ", ".join(c["name"] for c in anti_air_offertes)))

    # Un rapport de plus de 2 entre la meilleure et la pire carte anti-tours veut dire qu'une
    # seule d'entre elles merite une place de deck.
    rapport = degats[0][1] / degats[-1][1] if degats and degats[-1][1] > 0 else float("inf")
    print("rapport entre la meilleure et la pire anti-tours : x%.1f" % rapport)

    echecs = []
    if dominantes:
        echecs.append("%d carte(s) dominent" % len(dominantes))
    if inutiles:
        echecs.append("%d carte(s) inutiles" % len(inutiles))
    if rapport > 2:
        echecs.append("les anti-tours ne se valent pas (x%.1f)" % rapport)
    if len(anti_air_offertes) < 3:
        echecs.append("un joueur neuf n'a que %d reponse(s) aux volants" % len(anti_air_offertes))
    if echecs:
        print("ROUGE : " + " | ".join(echecs))
        return 1
    print("VERT : aucune carte ne domine ni ne devient inutile")
    return 0


sys.exit(main())
