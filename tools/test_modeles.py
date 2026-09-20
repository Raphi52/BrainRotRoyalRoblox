"""Controle : chaque modele RETENU (tools/boutique/choix.json) a sa GEOMETRIE dans le jeu.

Choisir un modele ne le fait pas apparaitre a l'ecran : la place ne peut pas charger l'asset d'un
autre auteur a la volee (InsertService refuse), sa geometrie doit etre ECRITE dans modeles.json
puis reconstruite par build.py. Ce controle mesure exactement cet ecart-la.
"""
import json
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
choix = json.loads((RACINE / "tools/boutique/choix.json").read_text(encoding="utf-8"))
modeles = json.loads((RACINE / "tools/boutique/modeles.json").read_text(encoding="utf-8"))
place = (RACINE / "BrainRotRoyale.rbxlx").read_text(encoding="utf-8", errors="replace")

defauts = []
for perso, aid in sorted(choix.items()):
    m = modeles.get(perso)
    if not m:
        defauts.append(f"{perso} : modele choisi ({aid}) mais aucune geometrie exportee")
        continue
    if m.get("id") != aid:
        defauts.append(f"{perso} : geometrie de l'asset {m.get('id')} alors que le choix est {aid}")
    pieces = [p for p in m.get("pieces", []) if p.get("Transparency", 0) < 1]
    if not pieces:
        defauts.append(f"{perso} : geometrie vide (aucune piece visible)")
        continue
    # Pas un empilement de cubes : soit un maillage sculpte, soit une construction detaillee.
    if not any(p.get("MeshId") or any(e.get("MeshId") for e in p.get("enfants", [])) for p in pieces)             and len(pieces) < 10:
        defauts.append(f"{perso} : {len(pieces)} blocs sans maillage, c'est un empilement de cubes")
    if not re.search(rf'<Item class="Model" [^>]*>\s*<Properties>\s*<string name="Name">{perso}</string>', place):
        defauts.append(f"{perso} : absent du dossier Modeles de la place construite")

print(f"{len(choix)} modeles retenus, {len(modeles)} geometries, {len(defauts)} defauts")
for d in defauts:
    print("  -", d)
sys.exit(1 if defauts else 0)
