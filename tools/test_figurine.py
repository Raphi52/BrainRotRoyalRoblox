# -*- coding: utf-8 -*-
"""IMAGES DES CARTES (src/shared/Portrait.lua + src/shared/Figurine.lua).

Le defaut corrige (2026-09-21) : les cartes etaient des aplats de couleur portant un nom. Seules les
17 cartes dotees d'un modele 3D avaient une image, et seulement dans la rangee du deck de l'accueil.

1) Regle PURE executee (lupa) : CHAQUE carte du catalogue a une image (modele, silhouette ou
   embleme) ; chaque sort recoit un embleme bien forme.
2) La silhouette du menu est assemblee avec LA MEME formule que le serveur (GameServer, `habiller`).
3) Branchement lu : module embarque, image dans la main et dans les cartes a venir.
"""
import re, sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
P = (R / "src/shared/Portrait.lua").read_text(encoding="utf-8")
F = (R / "src/shared/Figurine.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
CARDS = (R / "src/shared/Cards.lua").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(P)

# --- 1. CHAQUE CARTE A UNE IMAGE --------------------------------------------------------------------
# Lecture du catalogue par contenu : id, et presence de morceaux / sort dans son bloc.
modeles = set(re.findall(r'\[\s*"(\w+)"\s*\]\s*=\s*\{\s*rbx', (R / "build.py").read_text(encoding="utf-8")))
ids = re.findall(r'^\s*id\s*=\s*"(\w+)"', CARDS, re.M)
blocs = re.split(r'^\s*id\s*=\s*"', CARDS, flags=re.M)[1:]
sans = []
compte = {"modele": 0, "morceaux": 0, "embleme": 0}
for bloc in blocs:
    cid = bloc.split('"', 1)[0]
    corps = bloc.split('\n\tid =', 1)[0]
    carte = lua.table()
    if "morceaux" in corps:
        carte.morceaux = lua.table(1)
    if re.search(r'\bsort\s*=\s*\{', corps):
        carte.sort = lua.table()
    genre = M.source(carte, False)
    if genre is None:
        sans.append(cid)
    else:
        compte[genre] += 1
if len(blocs) < 40:
    e.append("catalogue mal lu : %d cartes seulement" % len(blocs))
for cid in sans:
    e.append("la carte %s n'a aucune image (ni modele, ni silhouette, ni embleme)" % cid)
t = lua.table()
if M.source(t, True) != "modele":
    e.append("un modele 3D doit passer avant tout le reste")
if M.source(None, False) is not None:
    e.append("une carte inconnue ne doit rien afficher")

# --- EMBLEMES : un par effet, et bien formes -------------------------------------------------------
meme = lua.eval("function(a, b) return rawequal(a, b) end")
def sort(**kw):
    s = lua.table()
    for k, v in kw.items():
        s[k] = v
    return s
if not meme(M.embleme(sort(cibles=3)), M.EMBLEMES.eclair):
    e.append("un sort a plusieurs cibles doit montrer l'eclair")
if not meme(M.embleme(sort(recul=10)), M.EMBLEMES.tronc):
    e.append("un sort qui repousse doit montrer le tronc")
for effet in ("gel", "poison", "soin", "rage"):
    if not meme(M.embleme(sort(effet=effet)), M.EMBLEMES[effet]):
        e.append("l'effet %s n'a pas son embleme" % effet)
if not meme(M.embleme(sort(effet="inconnu")), M.EMBLEMES.degats):
    e.append("un effet inconnu doit retomber sur la bombe")
for nom, pieces in M.EMBLEMES.items():
    n = 0
    for _, pc in pieces.items():
        n += 1
        if pc.forme not in ("bloc", "boule", "cylindre"):
            e.append("embleme %s : forme inconnue %r" % (nom, pc.forme))
        if min(pc.taille.x, pc.taille.y, pc.taille.z) <= 0:
            e.append("embleme %s : piece de taille nulle" % nom)
        if not 0 <= pc.clair <= 1:
            e.append("embleme %s : eclaircissement hors de [0,1]" % nom)
    if n == 0:
        e.append("embleme %s vide" % nom)

# --- 2. MEME SILHOUETTE QUE SUR LE TERRAIN -----------------------------------------------------------
FORMULE = "m.pos * k + Vector3.new(0, (k - 1) * %s.size.Y / 2, 0)"
if FORMULE % "card" not in S:
    e.append("serveur : la formule de pose des morceaux a change, verifier la figurine")
if FORMULE % "carte" not in F:
    e.append("la figurine n'assemble pas la silhouette comme le serveur")
if "m.taille * k" not in F:
    e.append("la figurine ne met pas les morceaux a l'echelle de la carte")
if "math.rad(carte.modeleRotY or 0)" not in F:
    e.append("la figurine ne tourne pas le modele comme le serveur")
# Un modele a maillage (bloc de 1 stud + SpecialMesh) ne se cadre pas : sa boite ment.
if 'FindFirstChildWhichIsA("SpecialMesh", true) == nil' not in F or "Portrait.source(carte, mesurable)" not in F:
    e.append("un modele a maillage non mesurable serait cadre au hasard")
import json
MOD = json.loads((R / "tools/boutique/modeles.json").read_text(encoding="utf-8"))
for mid, v in MOD.items():
    maillage = any(c.get("ClassName") == "SpecialMesh" for pc in v["pieces"] for c in pc.get("enfants", []))
    if maillage and ('id = "%s"' % mid) in CARDS:
        corps = CARDS.split('id = "%s"' % mid, 1)[1].split(chr(10) + chr(9) + "id =", 1)[0]
        if "morceaux" not in corps:
            e.append("%s : modele a maillage SANS silhouette de repli, la carte n'aurait pas d'image juste" % mid)
# Idempotent : la main se rafraichit plusieurs fois par seconde.
if 'vue:GetAttribute("Carte") == id' not in F:
    e.append("la figurine serait reconstruite a chaque rafraichissement")

# --- 3. BRANCHEMENT -----------------------------------------------------------------------------------
if 'source=src("shared/Figurine.lua")' not in B:
    e.append("Figurine n'est pas embarquee dans la place : le client attendrait le module a l'infini")
if B.find('shared/Portrait.lua') > B.find('shared/Figurine.lua'):
    e.append("Figurine est embarquee avant Portrait, dont elle depend")
if C.count('WaitForChild("Figurine")).rendre(b.vue') < 2:
    e.append("la main n'affiche pas (ou n'efface pas) l'image des cartes")
if 'WaitForChild("Figurine")).rendre(a.vue' not in C:
    e.append("les cartes a venir n'ont pas d'image")
if "marge.PaddingTop = UDim.new(0, 62)" not in C:
    e.append("le texte de la carte en main passerait sur l'image")
if "decale.PaddingLeft" not in C:
    e.append("le texte des cartes a venir passerait sur l'image")

# Menu : collection (boutique) et grille du deck. Chaque tuile rend sa figurine, et aucun texte
# de la tuile ne passe sur l'image (rectangles lus dans le code, x/y/l/h en fraction de tuile).
H = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
def croise(a, b):
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]
def rects(bloc, motif):
    out = []
    for m in re.finditer(motif, bloc):
        sz = [float(x) for x in m.group(1).split(",")]
        ps = [float(x) for x in m.group(2).split(",")]
        out.append([ps[0], ps[2], sz[0], sz[2]])
    return out
for nom, debut, fin in (("collection", 'local tuile = Instance.new("Frame")', "tuiles[card.id] ="),
                        ("deck", 'tuile.Parent = deckGrille', "tuilesDeck[card.id] =")):
    i = H.find(debut)
    bloc = H[i:H.find(fin, i)] if i >= 0 else ""
    if "fig.rendre(vueTuile, card.id)" not in bloc:
        e.append("%s : les tuiles n'ont pas d'image" % nom)
        continue
    img = rects(bloc, r'vueTuile\.Size = UDim2\.new\(([^)]*)\)\s*vueTuile\.Position = UDim2\.new\(([^)]*)\)')[0]
    textes = rects(bloc, r'(?:texte|bouton)\(tuile,[^\n]*?UDim2\.new\(([^)]*)\),\s*UDim2\.new\(([^)]*)\)')
    textes += rects(bloc, r'pastilleNiv\.Size = UDim2\.new\(([^)]*)\)\s*pastilleNiv\.Position = UDim2\.new\(([^)]*)\)')
    textes += rects(bloc, r'infoDeck = bouton\(tuile, "\?", UDim2\.new\(([^)]*)\), UDim2\.new\(([^)]*)\)')
    if len(textes) < 4:
        e.append("%s : textes de la tuile mal lus (%d)" % (nom, len(textes)))
    for t in textes:
        if croise(img, t):
            e.append("%s : un texte (%s) passe sur l'image" % (nom, t))

for x in e:
    print("ROUGE " + x)
print("%d echec(s)" % len(e) if e else
      "VERT : %d cartes, toutes avec une image (modele/silhouette %d, embleme %d)"
      % (len(blocs), compte["morceaux"] + compte["modele"], compte["embleme"]))
sys.exit(1 if e else 0)
