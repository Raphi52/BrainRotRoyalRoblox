"""Replie le journal d'export Studio (tools/boutique/export2.log) dans tools/boutique/modeles.json.

Le plugin ne peut pas ecrire de fichier : il imprime une ligne [BRRMOD] par modele (taille, id) et
une ligne [BRRMODP] par piece. On ne recopie QUE de la geometrie — aucun script d'asset.
"""
import json
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
log = (RACINE / "tools/boutique/export2.log").read_text(encoding="utf-8-sig", errors="replace")
cible = RACINE / "tools/boutique/modeles.json"
modeles = json.loads(cible.read_text(encoding="utf-8"))
# La ligne d'erreur du plugin ne porte que le personnage : l'identifiant vient du choix.
choix = json.loads((RACINE / "tools/boutique/choix.json").read_text(encoding="utf-8"))

entetes, pieces, refuses = {}, {}, set()
fichier_refus = RACINE / "tools/boutique/refuses.json"
if fichier_refus.exists():
    refuses = set(json.loads(fichier_refus.read_text(encoding="utf-8")))
for ligne in log.splitlines():
    m = re.search(r"\[(BRRMOD|BRRMODP)\] (\{.*\})\s*$", ligne)
    if not m:
        continue
    d = json.loads(m.group(2))
    if m.group(1) == "BRRMOD":
        if "erreur" in d:
            # Un asset paye ou retire rend « User is not authorized » : le choix est mort, on le
            # note pour que boutique_choix.py ne le reprenne plus (cause, pas symptome).
            if "not authorized" in d["erreur"] or "not exist" in d["erreur"]:
                refuses.add(choix.get(d["perso"]))
            print(f"  ! {d['perso']} ({choix.get(d['perso'])}) : {d['erreur']}")
            continue
        entetes[d["perso"]] = d
    else:
        pieces.setdefault(d["perso"], {})[d["i"]] = d["p"]

n = 0
for perso, e in entetes.items():
    ps = [p for _, p in sorted(pieces.get(perso, {}).items())]
    if len(ps) != e["n"]:
        print(f"  ! {perso} : {len(ps)} pieces recues pour {e['n']} annoncees — ignore")
        continue
    # QUALITE : le defaut a corriger etait « les personnages sont des empilements de cubes ». Un
    # asset sans aucun maillage ET de moins de 10 pieces en est un aussi — le poser ne gagne rien.
    # fix-ok: verifie a l'oeil sur les apercus (Boneca = 5 blocs, illisible ; Giraffa = 22, lisible).
    maille = any(p.get("MeshId") or any(c.get("MeshId") for c in p.get("enfants", [])) for p in ps)
    if not maille and len(ps) < 10:
        print(f"  ! {perso} ({e['id']}) : {len(ps)} blocs sans maillage — trop grossier, refuse")
        refuses.add(e["id"])
        continue
    modeles[perso] = {"id": e["id"], "taille": e["taille"], "pieces": ps}
    n += 1

# Menage : une geometrie dont l'asset est refuse, ou qui ne correspond plus au choix courant,
# resterait dans le jeu sans que personne ne l'ait choisie.
for perso in [k for k, v in modeles.items() if v.get("id") in refuses or choix.get(perso if False else k) != v.get("id")]:
    print(f"  - {perso} : geometrie perimee retiree ({modeles[perso].get('id')})")
    modeles.pop(perso)

refuses.discard(None)
fichier_refus.write_text(json.dumps(sorted(refuses), indent=1), encoding="utf-8")
cible.write_text(json.dumps(modeles, ensure_ascii=False, indent=1), encoding="utf-8")
print(f"{len(refuses)} assets refuses par Roblox")
print(f"{n} modeles fusionnes, {len(modeles)} geometries au total")
sys.exit(0 if n else 1)
