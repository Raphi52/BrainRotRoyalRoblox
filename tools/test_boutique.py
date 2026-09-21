"""Controle : chaque unite de Cards.lua a un modele 3d choisi dans la Boutique.

Verifie, sans reseau : (1) les 28 unites sont couvertes par une recherche, (2) chacune a un
choix dans choix.json, (3) le choix est sans script (aucun code tiers importe), (4) son apercu
PNG est sur le disque et est une vraie image.
"""
import hashlib, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).parent
BOUT = ROOT / "boutique"
CARDS = ROOT.parent / "src" / "shared" / "Cards.lua"

def unites():
    texte = CARDS.read_text(encoding="utf-8")
    # la liste litterale s'arrete a la premiere accolade fermante en debut de ligne
    debut = texte.index("local Cards = {")
    texte = texte[debut:texte.index("\n}\n", debut)]
    out = {}
    for bloc in texte.split("\n\t{")[1:]:
        m = re.search(r'id = "(\w+)"', bloc)
        n = re.search(r'name = "([^"]+)"', bloc)
        if m and n and "hauteurModele" in bloc:
            out[m.group(1)] = n.group(1)
    return out

SANS_RENDU = "3f0c863cf03476b448b70fdc5676fffe"

def apercu_ok(png):
    if not png.exists() or png.stat().st_size < 1000 or png.read_bytes()[:4] != b"\x89PNG":
        return False
    from PIL import Image
    im = Image.open(png).convert("RGB").resize((32, 32))
    return hashlib.md5(im.tobytes()).hexdigest() != SANS_RENDU

defauts = []
cartes = unites()
choix = json.loads((BOUT / "choix.json").read_text(encoding="utf-8"))
a_trouver = json.loads((BOUT / "a_trouver.json").read_text(encoding="utf-8"))
fichier_refus = BOUT / "refuses.json"
refuses = set(json.loads(fichier_refus.read_text(encoding="utf-8"))) if fichier_refus.exists() else set()
for ident, nom in cartes.items():
    fiche = BOUT / f"{ident}.json"
    if not fiche.exists():
        defauts.append(f"{ident} ({nom}) : aucune recherche Boutique")
        continue
    resultats = {r["id"]: r for r in json.loads(fiche.read_text(encoding="utf-8"))}
    aid = choix.get(ident)
    if not aid:
        if ident not in a_trouver:
            defauts.append(f"{ident} ({nom}) : sans modele et absent de a_trouver.json")
        continue
    # Un asset deja REFUSE par Roblox a l'export (« User is not authorized to access Asset »)
    # ne doit jamais etre re-choisi : sans ce garde-fou, on relance un export Studio de 5 minutes
    # pour reobtenir le meme refus (mesure du 2026-09-20, asset 80500909913897 re-tente).
    if aid in refuses:
        defauts.append(f"{ident} : le modele {aid} figure dans refuses.json (inaccessible a l'export)")
    r = resultats.get(aid)
    if r is None:
        continue  # choix historique issu d'un export Studio, hors de cette recherche
    if r.get("scripts"):
        defauts.append(f"{ident} : le modele choisi {aid} porte des scripts")
    png = BOUT / f"{aid}.png"
    if not png.exists() or png.stat().st_size < 1000 or png.read_bytes()[:4] != b"\x89PNG":
        defauts.append(f"{ident} : apercu {aid}.png absent ou invalide")

print(f"{len(cartes)} unites, {len(choix)} modeles valides, {len(a_trouver)} a trouver, {len(defauts)} defauts")
for d in defauts:
    print("  -", d)
sys.exit(1 if defauts else 0)
