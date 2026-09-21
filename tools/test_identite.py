# -*- coding: utf-8 -*-
"""AUDIT (lecture seule) : quelles cartes ont une IDENTITE, et lesquelles se jouent toutes pareil ?

Une carte a une identite des qu'une regle du jeu la distingue : un sort, un batiment, un statut
inflige (gel, poison, ralentissement), un bouclier, une explosion a la mort, une descendance, une
aura de soutien, une specialite (anti-air / anti-groupe), une charge, un recul, une visee
particuliere, le vol, les degats de zone, ou le fait d'arriver en groupe.

Une carte sans AUCUN de ces traits n'est qu'un tas de points de vie et de degats : elle se
remplace par n'importe quelle autre de meme cout, et le joueur n'a aucune raison de la choisir.
"""
import io
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHARED = ROOT / "src" / "shared"


def profils(fichier, table):
    """Identifiants declares dans une table PROFILS/PARTS d'un module de regles."""
    p = SHARED / fichier
    if not p.exists():
        return set()
    s = p.read_text(encoding="utf-8")
    m = re.search(table + r"\s*=\s*\{(.*?)\n\}", s, re.S)
    if not m:
        return set()
    return set(re.findall(r"^\s*(\w+)\s*=", m.group(1), re.M))


def main():
    cartes = (SHARED / "Cards.lua").read_text(encoding="utf-8")
    traits = {
        "charge": profils("Charge.lua", "Charge.PROFILS"),
        "descendance": profils("Descendance.lua", "Descendance.PROFILS"),
        "soutien": profils("Soutien.lua", "Soutien.PROFILS"),
        "specialite": profils("Specialite.lua", "Specialite.PROFILS"),
        "recul": profils("Recul.lua", "Recul.PROFILS"),
        "visee": profils("Visee.lua", "Visee.PARTS"),
        "assassin": profils("Assassin.lua", "Assassin.PROFILS"),
    }

    lignes = []
    for bloc in cartes.split("\t{")[1:]:
        m = re.search(r'id = "(\w+)"', bloc)
        if not m:
            continue
        ident = bloc[:1600]
        nom = re.search(r'name = "([^"]+)"', ident)
        cout = re.search(r"cost = (\d+)", ident)
        mes = []
        if "sort = " in ident:
            mes.append("sort")
        if "batiment = " in ident:
            mes.append("batiment")
        if "flying = true" in ident:
            mes.append("vol")
        if re.search(r"splash = [\d.]+", ident):
            mes.append("zone")
        if re.search(r"count = ([2-9])", ident):
            mes.append("groupe")
        for mot, etiquette in (("bouclier", "bouclier"), ("soin = ", "soin"), ("mort = ", "explose"),
                               ("gel = ", "gel"), ("poison = ", "poison"), ("lent = ", "ralentit"),
                               ("poseLibre = true", "pose libre"),
                               ('targets = "buildings"', "anti-tours")):
            if mot in ident:
                mes.append(etiquette)
        for nom_trait, ids in traits.items():
            if m.group(1) in ids:
                mes.append(nom_trait)
        lignes.append((m.group(1), nom.group(1) if nom else m.group(1),
                       int(cout.group(1)) if cout else 0, sorted(set(mes))))

    fades = [l for l in lignes if not l[3]]
    print("cartes au catalogue : %d" % len(lignes))
    print("cartes SANS aucune particularite : %d" % len(fades))
    print()
    print("%-22s %-4s %s" % ("CARTE", "COUT", "CE QUI LA DISTINGUE"))
    for ident, nom, cout, mes in sorted(lignes, key=lambda l: (len(l[3]), l[2])):
        print("%-22s %-4d %s" % (nom[:22], cout, ", ".join(mes) if mes else "-- RIEN --"))

    # GARDE-FOU. Une seule carte a le droit d'etre « nue » : Tralalero Tralala, la carte de
    # reference du jeu — c'est elle qui sert de metre-etalon a toutes les autres, et lui inventer
    # un gadget retirerait ce point de comparaison. Toute AUTRE carte sans aucun trait est un
    # defaut : elle se remplace par n'importe quelle carte de meme cout, et le joueur n'a aucune
    # raison de la choisir. Ce banc existe pour qu'une prochaine carte fade se voie tout de suite.
    permises = {"Tralalero"}
    surprises = sorted(l[1] for l in fades if l[0] not in permises)
    print()
    if surprises:
        print("ROUGE : carte(s) sans aucune identite : " + ", ".join(surprises))
        print("  -> donne-lui un trait (statut, aura, specialite, charge, recul...) ou dis pourquoi")
        print("     elle doit rester nue, en l'ajoutant a `permises` dans ce fichier.")
        return 1
    manquantes = sorted(i for i in permises if i not in {l[0] for l in lignes})
    if manquantes:
        print("ROUGE : exception(s) inutile(s), ces cartes n'existent plus : " + ", ".join(manquantes))
        return 1
    print("VERT : chaque carte a une raison d'etre jouee (seule %s reste la carte de reference)"
          % ", ".join(sorted(permises)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
