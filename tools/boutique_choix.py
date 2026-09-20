"""Choisit, pour chaque unite de Cards.lua, le meilleur modele 3d SANS SCRIPT de la Boutique.

Lecture seule reseau : n'utilise que les fiches deja telechargees par boutique_recherche.py.
Regle de securite : un modele portant des scripts n'est JAMAIS retenu (vecteur de code hostile).
Classement : correspondance du nom, puis votes positifs, puis fraicheur.
Ecrit tools/boutique/choix.json + une planche de controle planche-choix.png (apercus reels).
"""
import hashlib, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).parent
BOUT = ROOT / "boutique"
CARDS = ROOT.parent / "src" / "shared" / "Cards.lua"

def unites():
    texte = CARDS.read_text(encoding="utf-8")
    out = {}
    for bloc in texte.split("\n\t{")[1:]:
        m = re.search(r'id = "(\w+)"', bloc)
        n = re.search(r'name = "([^"]+)"', bloc)
        if m and n and "hauteurModele" in bloc:
            out[m.group(1)] = n.group(1)
    return out

# Empreinte de l'image "</>" que Roblox renvoie quand un asset n'a AUCUN rendu 3d.
# fix-ok: 5 choix pointaient sur ce substitut, invisible dans le json, visible sur la planche.
SANS_RENDU = "3f0c863cf03476b448b70fdc5676fffe"
def apercu_ok(png):
    if not png.exists() or png.stat().st_size < 1000:
        return False
    try:
        from PIL import Image
    except ImportError:
        return True
    im = Image.open(png).convert("RGB").resize((32, 32))
    return hashlib.md5(im.tobytes()).hexdigest() != SANS_RENDU

def mots(txt):
    return set(re.findall(r"[a-z]+", (txt or "").lower()))

def score(r, nom):
    attendus = mots(nom) - {"la", "los"}
    trouves = mots(r.get("nom")) & attendus
    return (len(trouves) / max(1, len(attendus)),
            (r.get("upVotes") or 0) - (r.get("downVotes") or 0),
            r.get("maj") or "")

# Assets refuses a l'export Studio (« User is not authorized ») : payants ou retires. Les garder
# donnerait un choix qui ne peut PAS entrer dans le jeu — ils sont exclus a la source.
REFUSES = set(json.loads((BOUT / "refuses.json").read_text(encoding="utf-8"))) if (BOUT / "refuses.json").exists() else set()

cartes = unites()
choix = json.loads((BOUT / "choix.json").read_text(encoding="utf-8"))
rapport = []
for ident, nom in cartes.items():
    fiche = BOUT / f"{ident}.json"
    if not fiche.exists():
        rapport.append((ident, None, "aucune recherche"))
        continue
    libres = [r for r in json.loads(fiche.read_text(encoding="utf-8"))
              if r.get("id") and r["id"] not in REFUSES and not r.get("scripts") and apercu_ok(BOUT / f"{r['id']}.png")]
    if not libres:
        rapport.append((ident, None, "aucun modele sans script avec apercu"))
        continue
    best = max(libres, key=lambda r: score(r, nom))
    if score(best, nom)[0] < 0.5:
        rapport.append((ident, None, "aucun modele au nom correspondant"))
        choix.pop(ident, None)
        continue
    ancien = choix.get(ident)
    ancien_r = {r["id"]: r for r in json.loads(fiche.read_text(encoding="utf-8"))}.get(ancien)
    # On ne remplace un choix deja valide (sans script) que s'il n'existe pas.
    if ancien in REFUSES:
        ancien, ancien_r = None, None
    if (ancien and ancien_r is not None and not ancien_r.get("scripts")
            and apercu_ok(BOUT / f"{ancien}.png")):
        rapport.append((ident, ancien, "conserve"))
        continue
    if ancien and ancien_r is None:
        rapport.append((ident, ancien, "conserve (export Studio)"))
        continue
    choix[ident] = best["id"]
    rapport.append((ident, best["id"], f"choisi : {best['nom']} par {best['auteur']}"))

manquants = sorted(i for i, a, _ in rapport if a is None)
(BOUT / "a_trouver.json").write_text(json.dumps(manquants, indent=1), encoding="utf-8")
(BOUT / "choix.json").write_text(json.dumps(choix, indent=1, ensure_ascii=False), encoding="utf-8")
for l in rapport:
    print(" ", *l)
print(f"{len(cartes)} unites, {len(choix)} choix, {len(manquants)} a trouver : {manquants}")

# Planche de controle : les apercus reels des modeles retenus, lisibles a l'oeil.
try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit(0)
noms = sorted(cartes)
COL, CELL = 6, 180
lignes = (len(noms) + COL - 1) // COL
planche = Image.new("RGB", (COL * CELL, lignes * (CELL + 18)), (24, 26, 34))
d = ImageDraw.Draw(planche)
for i, ident in enumerate(noms):
    x, y = (i % COL) * CELL, (i // COL) * (CELL + 18)
    aid = choix.get(ident)
    p = BOUT / f"{aid}.png" if aid else None
    if p and p.exists():
        planche.paste(Image.open(p).convert("RGB").resize((CELL, CELL)), (x, y))
    else:
        d.rectangle([x, y, x + CELL, y + CELL], fill=(60, 30, 30))
        d.text((x + 8, y + CELL // 2), "MANQUANT", fill=(255, 140, 140))
    d.text((x + 4, y + CELL + 3), ident, fill=(230, 230, 240))
sortie = BOUT / "planche-choix.png"
planche.save(sortie)
print("planche:", sortie)
