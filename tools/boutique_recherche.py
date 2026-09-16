"""Recherche des modeles Italian Brainrot dans la Boutique des createurs Roblox (lecture seule).

Pour chaque personnage : 10 premiers resultats par pertinence, details (nom, auteur, votes,
scripts) et image d'apercu. Ecrit tools/boutique/<id>.json + <assetId>.png. Aucune insertion.
"""
import json, pathlib, urllib.request, urllib.parse, time

ROOT = pathlib.Path(__file__).parent / "boutique"
ROOT.mkdir(exist_ok=True)
PERSOS = {
    "Tralalero": "tralalero tralala", "Bombardiro": "bombardiro crocodilo",
    "TungSahur": "tung tung tung sahur", "Patapim": "brr brr patapim",
    "Cappuccino": "cappuccino assassino", "Chimpanzini": "chimpanzini bananini",
    "Lirili": "lirili larila", "Ballerina": "ballerina cappuccina",
}

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
    q = urllib.parse.quote(mot)
    ids = [d["id"] for d in json.loads(get(f"https://apis.roblox.com/toolbox-service/v1/marketplace/10?keyword={q}&num=10&sortType=Relevance"))["data"]][:10]
    det = json.loads(get("https://apis.roblox.com/toolbox-service/v1/items/details?assetIds=" + ",".join(map(str, ids))))
    thumbs = json.loads(get("https://thumbnails.roblox.com/v1/assets?size=420x420&format=Png&assetIds=" + ",".join(map(str, ids))))
    turl = {t["targetId"]: t.get("imageUrl") for t in thumbs.get("data", [])}
    lignes = []
    for d in det.get("data", []):
        a = d.get("asset", {}); v = d.get("voting", {}); c = d.get("creator", {})
        aid = a.get("id")
        img = turl.get(aid)
        if img:
            (ROOT / f"{aid}.png").write_bytes(get(img))
        lignes.append({"id": aid, "nom": a.get("name"), "auteur": c.get("name"),
                       "upVotes": v.get("upVotes"), "downVotes": v.get("downVotes"),
                       "scripts": a.get("hasScripts"), "maj": a.get("updatedUtc")})
    (ROOT / f"{perso}.json").write_text(json.dumps(lignes, ensure_ascii=False, indent=1), encoding="utf-8")
    print(perso, len(lignes))
