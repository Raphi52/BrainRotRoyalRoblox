"""Recherche des modeles Italian Brainrot dans la Boutique des createurs Roblox (lecture seule).

Pour chaque personnage : 10 premiers resultats par pertinence, details (nom, auteur, votes,
scripts) et image d'apercu. Ecrit tools/boutique/<id>.json + <assetId>.png. Aucune insertion.
"""
import json, pathlib, re, urllib.request, urllib.parse, time

ROOT = pathlib.Path(__file__).parent / "boutique"
ROOT.mkdir(exist_ok=True)
# PERSOS vient de Cards.lua : la liste figee de 8 noms ne couvrait que 8 des 28 unites,
# c'est la cause des 20 personnages restes en cubes. fix-ok: recherche limitee a 8 noms codes en dur.
CARDS = pathlib.Path(__file__).parent.parent / "src" / "shared" / "Cards.lua"
def personnages():
    import re as _re
    texte = CARDS.read_text(encoding="utf-8")
    sortie = {}
    for bloc in texte.split("\n\t{")[1:]:
        m = _re.search(r'id = "(\w+)"', bloc)
        n = _re.search(r'name = "([^"]+)"', bloc)
        if m and n and "hauteurModele" in bloc:
            sortie[m.group(1)] = n.group(1).lower()
    return sortie
PERSOS = personnages()

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for essai in range(3):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read()
        except Exception as e:
            err = e
            time.sleep(2 + essai * 3)
    raise err

for perso, mot in PERSOS.items():
    if (ROOT / (perso + ".json")).exists():
        print(perso, "deja recherche"); continue
    # Le filtre de mots de Roblox masque parfois une requete entiere (reponse
    # totalResults=0, filteredKeyword="######"). fix-ok: recherche rendue vide par la
    # censure du mot-cle -> on retente le nom entier puis chaque mot isole.
    def chercher(mot):
        essais = [(m, t) for t in ("Relevance", "MostTaken") for m in [mot] + mot.split()]
        vus = []
        for tentative, tri in essais:
            url = "https://apis.roblox.com/toolbox-service/v1/marketplace/10?keyword=%s&num=30&sortType=%s" % (urllib.parse.quote(tentative), tri)
            rep = json.loads(get(url))
            for d in rep.get("data", []):
                if d["id"] not in vus:
                    vus.append(d["id"])
            if len(vus) >= 60:
                break
            time.sleep(1)
        return vus[:60]
    ids = chercher(mot)
    if not ids:
        print(perso, "aucun resultat"); continue
    def details(liste):
        url = "https://apis.roblox.com/toolbox-service/v1/items/details?assetIds=" + ",".join(map(str, liste))
        try:
            return json.loads(get(url)).get("data", [])
        except Exception:
            if len(liste) == 1:
                return []  # asset refuse par le service (400) : on le laisse tomber
            moitie = len(liste) // 2
            return details(liste[:moitie]) + details(liste[moitie:])
    det = {"data": details(ids)}
    turl = {}
    for aid in ids:  # un seul id a la fois : un id refuse faisait tomber le lot entier (400)
        try:
            for t in json.loads(get("https://thumbnails.roblox.com/v1/assets?size=420x420&format=Png&assetIds=%d" % aid)).get("data", []):
                turl[t["targetId"]] = t.get("imageUrl")
        except Exception as e:
            print(perso, aid, "apercu indisponible", e)
    lignes = []
    for d in det.get("data", []):
        a = d.get("asset", {}); v = d.get("voting", {}); c = d.get("creator", {})
        aid = a.get("id")
        img = turl.get(aid)
        if img and not (ROOT / f"{aid}.png").exists():
            try:
                (ROOT / f"{aid}.png").write_bytes(get(img))
            except Exception as e:
                print(perso, aid, "apercu KO", e)
        lignes.append({"id": aid, "nom": a.get("name"), "auteur": c.get("name"),
                       "upVotes": v.get("upVotes"), "downVotes": v.get("downVotes"),
                       "scripts": a.get("hasScripts"), "maj": a.get("updatedUtc")})
    (ROOT / f"{perso}.json").write_text(json.dumps(lignes, ensure_ascii=False, indent=1), encoding="utf-8")
    print(perso, len(lignes))
