# -*- coding: utf-8 -*-
"""MENU D'ACCUEIL : AUCUN BLOC N'EN RECOUVRE UN AUTRE (src/client/Hub.client.lua + src/shared/MiseMenu.lua).

Le defaut corrige (capture du 2026-09-21) : la rangee de coffres avait ete agrandie et remontee
« dans l'espace libre sous JOUER » (Hub.client.lua, commentaire de `rangee`). Cet espace n'etait
PAS libre : le duel prive (DUEL PRIVE, CODE AMI, REJOINDRE, NIVEAUX EGALISES) et « SI PERSONNE :
ROBOT » y vivaient deja. Ils se retrouvaient SOUS les coffres, a moitie caches, donc a peine
cliquables. On avait SUPPOSE l'espace libre au lieu de le mesurer.

Ce banc MESURE : il lit les positions REELLES dans le code du menu (et dans MiseMenu pour ce qui
en vient), puis refuse tout recouvrement entre deux blocs qui peuvent etre visibles EN MEME TEMPS.
Deux blocs d'etats exclusifs (JOUER, et les boutons de la recherche qui le remplacent) ont le
droit d'occuper la meme place : ils ne se montrent jamais ensemble.
"""
import re, sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
H = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
MM_PATH = R / "src/shared/MiseMenu.lua"
MM_SRC = MM_PATH.read_text(encoding="utf-8") if MM_PATH.exists() else None
e = []

def croise(a, b):
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]

# --- 1. LES POSITIONS REELLES --------------------------------------------------------------------
# a) creations directes : texte(accueil, ..., TAILLE, POSITION) / bouton(accueil, "X", TAILLE, POSITION)
blocs = {}
for m in re.finditer(r'^\s*(?:local\s+)?([\w\.]+)\s*=\s*(?:texte|bouton)\(accueil,\s*[^,]*,\s*'
                     r'UDim2\.new\(([^)]*)\),\s*UDim2\.new\(([^)]*)\)', H, re.M):
    nom, sz, pos = m.groups()
    sz = [float(x) for x in sz.split(",")]
    pos = [float(x) for x in pos.split(",")]
    blocs[nom] = [pos[0], pos[2], sz[0], sz[2]]
# b) instances posees a part (rangee de coffres, champ de code)
for nom in ("rangee", "champCode"):
    p = re.findall(r'^\s*' + nom + r'\.Position\s*=\s*UDim2\.new\(([^)]*)\)', H, re.M)
    s = re.findall(r'^\s*' + nom + r'\.Size\s*=\s*UDim2\.new\(([^)]*)\)', H, re.M)
    if p and s:
        pp = [float(x) for x in p[-1].split(",")]
        ss = [float(x) for x in s[-1].split(",")]
        blocs[nom] = [pp[0], pp[2], ss[0], ss[2]]

# c) ce que le menu place DEPUIS MiseMenu (la source unique, une fois la refonte faite)
M = None
if MM_SRC:
    M = LuaRuntime().execute(MM_SRC)
    for nom, cle in re.findall(r'MiseMenu\.placer\(([\w\.]+),\s*MiseMenu\.ACCUEIL\.(\w+),\s*UDim2\)', H):
        r = M.ACCUEIL[cle]
        blocs[nom] = [r.x, r.y, r.l, r.h]
    # Tout ce qui est range DANS le panneau des amis n'est plus sur l'accueil.
    for nom in re.findall(r'^\s*(\w+)\.Parent\s*=\s*panneau\s*$', H, re.M):
        blocs.pop(nom, None)

# Toujours caches, ou deplaces vers un autre ecran : ils ne comptent pas sur l'accueil.
HORS_ACCUEIL = {"ligneProfil"}
for nom in list(blocs):
    for dest in re.findall(r'^\s*' + re.escape(nom) + r'\.Parent\s*=\s*(\w+)\s*$', H, re.M):
        if dest not in ("accueil", "panneau"):
            HORS_ACCUEIL.add(nom)  # deplace vers un autre ecran
for n in HORS_ACCUEIL:
    blocs.pop(n, None)
# Etats EXCLUSIFS : JOUER est cache pendant la recherche, les boutons de recherche le remplacent.
RECHERCHE = {"boutonAnnuler", "boutonRobotVite"}
REPOS = {"boutonJouer"}

def ensemble(noms_a, noms_b):
    return (noms_a in RECHERCHE and noms_b in REPOS) or (noms_a in REPOS and noms_b in RECHERCHE)

# « SI PERSONNE : ROBOT » est lu AU CLIC sur JOUER : il doit rester visible au repos. Le cacher
# supprimerait la fonction — le banc le refuse explicitement.
if re.search(r'boutonPatience\.Visible\s*=\s*false', H):
    e.append("« SI PERSONNE : ROBOT » est cache : son choix est lu au clic sur JOUER, il doit rester visible")

# LE PANNEAU DES AMIS est une FENETRE : ouvert, il a le droit de passer devant l'accueil. Il est
# donc verifie a part (plus bas) et sorti du calcul de fond — avec UNE exigence qui reste : il ne
# doit jamais couvrir la ligne de message, ou s'ecrit la reponse du serveur a ses propres boutons.
fenetre = blocs.pop("panneau", None)
if fenetre and "message" in blocs and croise(fenetre, blocs["message"]):
    e.append("le panneau des amis couvre la ligne de message : le joueur ne verrait pas la reponse du serveur")

noms = sorted(blocs)
recouvrements = []
for i, a in enumerate(noms):
    for b in noms[i + 1:]:
        if ensemble(a, b):
            continue
        if croise(blocs[a], blocs[b]):
            recouvrements.append("%s / %s" % (a, b))
for r in recouvrements:
    e.append("recouvrement sur l'accueil : " + r)

# Rien ne doit sortir de l'ecran.
for n, (x, y, l, h) in blocs.items():
    if x < 0 or y < 0 or x + l > 1.0001 or y + h > 1.0001:
        e.append("hors de l'ecran : %s" % n)

# --- 2. LA SOURCE UNIQUE : MiseMenu --------------------------------------------------------------
if M is None:
    e.append("src/shared/MiseMenu.lua absent : les positions du menu restent ecrites a la main")
else:
    # Le panneau des amis se verifie pour lui-meme : ses controles ne se recouvrent pas entre eux.
    p = M.PANNEAU
    cles = [k for k in ("titre", "prive", "code", "rejoindre", "egalise", "codeAffiche", "fermer")]
    rp = {k: [p[k].x, p[k].y, p[k].l, p[k].h] for k in cles}
    for i, a in enumerate(cles):
        for b in cles[i + 1:]:
            if croise(rp[a], rp[b]):
                e.append("recouvrement dans le panneau des amis : %s / %s" % (a, b))
    for k, (x, y, l, h) in rp.items():
        if x < 0 or y < 0 or x + l > 1.0001 or y + h > 1.0001:
            e.append("hors du panneau des amis : %s" % k)
    # Le panneau passe DEVANT tout : c'est une fenetre, elle a le droit de couvrir l'accueil.
    if "panneau.ZIndex" not in H:
        e.append("le panneau des amis n'est pas garanti au premier plan")

# --- 3. BRANCHEMENT -------------------------------------------------------------------------------
B = (R / "build.py").read_text(encoding="utf-8")
if MM_SRC and 'source=src("shared/MiseMenu.lua")' not in B:
    e.append("MiseMenu n'est pas embarque dans la place : le menu attendrait le module a l'infini")
if MM_SRC and 'WaitForChild("MiseMenu")' not in H:
    e.append("le menu ne charge pas MiseMenu")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else
      "VERT : aucun bloc de l'accueil n'en recouvre un autre, dans aucun etat (%d blocs mesures)" % len(blocs))
sys.exit(1 if e else 0)
