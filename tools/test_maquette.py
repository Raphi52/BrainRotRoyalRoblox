# -*- coding: utf-8 -*-
"""ILE MAQUETTE (src/shared/Maquette.lua + branchement dans GameServer).

Le defaut corrige : l'arene flottait dans le vide — un plan d'herbe uni, 26 arbres « sucette »,
un sol de deux dalles d'une seule couleur. La maquette pose un plateau a falaises, de l'eau tout
autour, un sol en damier et un decor dense.

LA CONTRAINTE, ET C'EST ELLE QUE CE BANC DEFEND : APPARENCE SEULE, JEU INTACT.
1) Les pieces sont EXECUTEES (lupa) pour chaque theme, avec les dimensions lues dans le serveur :
   - aucune piece ne mord sur le terrain, sauf le damier (pose SUR l'herbe, 0,03 d'epaisseur), les
     traces qui y etaient deja (gardees a l'identique) et ce qui reste cache SOUS l'herbe ;
   - la geometrie est la MEME pour tous les themes (seules couleurs et matieres changent) ;
   - l'ile est symetrique par demi-tour : les deux joueurs voient le meme paysage ;
   - matieres et formes connues de Roblox, tailles coherentes avec la forme ;
   - un plafond de pieces (l'arene est reconstruite a chaque duel, et tourne sur mobile).
2) Le branchement est lu : tout passe par deco() (sans collision, invisible aux clics), dans un
   sous-dossier, et les pieces qui portent les regles ne sont pas touchees.
"""
import math
import pathlib
import re
import sys
from collections import Counter

from lupa import LuaRuntime

from bancs import corps_fonction

R = pathlib.Path(__file__).resolve().parent.parent
MQ = (R / "src/shared/Maquette.lua").read_text(encoding="utf-8")
DE = (R / "src/shared/Decor.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
CARTES = (R / "src/shared/Cards.lua").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(MQ)
D = lua.execute(DE)
themes = [D.THEMES[i] for i in range(1, len(D.THEMES) + 1)]

# --- LES DIMENSIONS VIENNENT DU SERVEUR, PAS D'UNE COPIE DANS LE BANC ------------------------------
m = re.search(r"local HALF_W, HALF_L = (\d+), (\d+)", S)
W, L = int(m.group(1)), int(m.group(2))
VOIE = math.floor(W * 0.61) if "local VOIE_X = math.floor(HALF_W * 0.61)" in S else None
if VOIE is None:
    e.append("serveur : l'axe des ponts n'est plus HALF_W * 0.61 — mettre le banc a jour")
    VOIE = 19
DESSUS = float(re.search(r"local GROUND_Y = ([\d.]+)", S).group(1))
riviere = re.search(r'Name = "River", Size = Vector3\.new\(HALF_W \* 2, [\d.]+, ([\d.]+)\)', S)
DEMI_RIVIERE = float(riviere.group(1)) / 2 if riviere else 2
if "demiRiviere = %g" % DEMI_RIVIERE not in S:
    e.append("serveur : demiRiviere ne suit plus la largeur de la piece River")
dim = lua.table_from({"demiLargeur": W, "demiLongueur": L, "voies": lua.table_from([-VOIE, VOIE]),
                      "dessus": DESSUS, "demiRiviere": DEMI_RIVIERE})


def lire(theme):
    P = M.pieces(dim, theme)
    out = []
    for i in range(1, len(P) + 1):
        p = P[i]
        out.append({
            "nom": p.nom, "forme": p.forme, "role": p.role, "matiere": p.matiere,
            "taille": tuple(p.taille[k] for k in (1, 2, 3)), "pos": tuple(p.pos[k] for k in (1, 2, 3)),
            "rot": tuple(p.rot[k] for k in (1, 2, 3)), "couleur": tuple(p.couleur[k] for k in (1, 2, 3)),
            "transparence": p.transparence, "reflet": p.reflet, "ombre": p.ombre,
        })
    return out


def geometrie(pieces):
    return [(p["nom"], p["forme"], p["role"], tuple(round(v, 6) for v in p["taille"]),
             tuple(round(v, 6) for v in p["pos"]), tuple(round(v, 6) for v in p["rot"])) for p in pieces]


par_theme = {t.id: lire(t) for t in themes}
ref = par_theme[themes[0].id]

# --- REPRODUCTIBLE, ET LA MEME GEOMETRIE POUR TOUS LES THEMES --------------------------------------
if geometrie(lire(themes[0])) != geometrie(ref):
    e.append("deux appels ne rendent pas la meme ile : le decor changerait d'une partie a l'autre")
for tid, pieces in par_theme.items():
    if geometrie(pieces) != geometrie(ref):
        e.append(f"theme {tid} : la GEOMETRIE de l'ile change avec le theme (seules couleurs et matieres le peuvent)")

# --- BUDGET ----------------------------------------------------------------------------------------
if len(ref) > M.MAX_PIECES:
    e.append(f"{len(ref)} pieces : au-dela du plafond de {M.MAX_PIECES} (reconstruite a chaque duel, sur mobile)")
compte = Counter(p["nom"] for p in ref)
for nom, mini in (("Dalle", 150), ("Falaise", 60), ("Tronc", 30), ("Feuillage", 90), ("Ilot", 4), ("Cascade", 2)):
    if compte[nom] < mini:
        e.append(f"seulement {compte[nom]} pieces « {nom} » (au moins {mini}) : le decor dense a maigri")

# --- FORMES ET MATIERES CONNUES DE ROBLOX ----------------------------------------------------------
# Matieres de pieces : deja employees par le jeu, ou listees par la documentation Roblox
# (https://create.roblox.com/docs/parts/materials). Un nom inconnu ferait echouer Enum.Material[...]
# et, avec lui, toute la construction de l'arene.
MATIERES = {"Grass", "LeafyGrass", "Rock", "Slate", "Cobblestone", "Wood", "Ground", "Glass",
            "SmoothPlastic", "CrackedLava", "Neon", "Basalt", "Ice", "Limestone", "Sand", "Snow"}
FORMES = {"Block", "Ball", "Cylinder", "Ellipsoide"}
ROLES = {"damier", "trace", "bord", "nature", "eau"}
for tid, pieces in par_theme.items():
    for p in pieces:
        if p["matiere"] not in MATIERES:
            e.append(f"theme {tid} : matiere inconnue « {p['matiere']} » ({p['nom']})")
        if not all(isinstance(c, int) and 0 <= c <= 255 for c in p["couleur"]):
            e.append(f"theme {tid} : couleur hors bornes {p['couleur']} ({p['nom']})")
        if not (0 <= p["transparence"] < 1):
            e.append(f"theme {tid} : transparence absurde ({p['nom']})")
for p in ref:
    t = p["taille"]
    if p["forme"] not in FORMES:
        e.append(f"forme inconnue « {p['forme']} » ({p['nom']})")
    if p["role"] not in ROLES:
        e.append(f"role inconnu « {p['role']} » ({p['nom']})")
    if min(t) <= 0 or max(t) > 2048:
        e.append(f"{p['nom']} : taille {t} hors des bornes d'une piece Roblox")
    # Roblox force une BOULE a rester une sphere, et un CYLINDRE a une section ronde : une taille
    # qui ne l'est pas serait silencieusement retaillee — le decor ne ressemblerait plus au banc.
    if p["forme"] == "Ball" and not (abs(t[0] - t[1]) < 1e-9 and abs(t[1] - t[2]) < 1e-9):
        e.append(f"{p['nom']} : boule non spherique {t} (prendre « Ellipsoide »)")
    if p["forme"] == "Cylinder" and abs(t[1] - t[2]) > 1e-9:
        e.append(f"{p['nom']} : cylindre a section non ronde {t}")

# --- AUCUNE PIECE NE MORD SUR LE TERRAIN -----------------------------------------------------------
def emprise(p):
    """Rectangle au sol (xmin, xmax, zmin, zmax), rotation comprise. Majore : une piece penchee
    deborde au plus de sa demi-hauteur fois le sinus de sa pente."""
    sx, sy, sz = p["taille"]
    if p["forme"] == "Cylinder" and abs(p["rot"][2]) == 90:
        sx, sy = sy, sx  # cylindre redresse : sa longueur est verticale
    ry = math.radians(p["rot"][1])
    ex = abs(math.cos(ry)) * sx / 2 + abs(math.sin(ry)) * sz / 2
    ez = abs(math.sin(ry)) * sx / 2 + abs(math.cos(ry)) * sz / 2
    pente = math.radians(max(abs(p["rot"][0]), abs(p["rot"][2])) if p["forme"] != "Cylinder" else 0)
    ex += abs(math.sin(pente)) * sy / 2
    ez += abs(math.sin(pente)) * sy / 2
    x, _, z = p["pos"]
    return x - ex, x + ex, z - ez, z + ez


def sommet(p):
    sy = p["taille"][0] if (p["forme"] == "Cylinder" and abs(p["rot"][2]) == 90) else p["taille"][1]
    return p["pos"][1] + sy / 2


EPS = 1e-6
for p in ref:
    x0, x1, z0, z1 = emprise(p)
    mord = x1 > -W + EPS and x0 < W - EPS and z1 > -L + EPS and z0 < L - EPS
    if not mord:
        continue
    if p["role"] == "damier":
        continue  # verifie a part, plus bas
    if p["role"] == "trace":
        continue  # verifiees a l'identique, plus bas
    if sommet(p) <= DESSUS - 0.3 + EPS:
        continue  # cachee SOUS l'herbe du terrain (plateau, socle, mer)
    e.append(f"{p['nom']} en {tuple(round(v, 1) for v in p['pos'])} MORD SUR LE TERRAIN : le decor cacherait le jeu")

# --- LE DAMIER : SUR L'HERBE, UNE CASE SUR DEUX, JAMAIS DANS L'EAU NI SOUS UNE ALLEE -------------
dalles = [p for p in ref if p["role"] == "damier"]
T = M.DALLE
berge = DEMI_RIVIERE + 0.5
for p in dalles:
    x0, x1, z0, z1 = emprise(p)
    if x0 < -W - EPS or x1 > W + EPS or z0 < -L - EPS or z1 > L + EPS:
        e.append(f"case de damier hors du terrain en {p['pos']}")
    bas, haut = p["pos"][1] - p["taille"][1] / 2, sommet(p)
    if abs(bas - DESSUS) > EPS or haut > DESSUS + 0.035:
        e.append(f"case de damier a la mauvaise hauteur ({bas:.3f}..{haut:.3f}) : elle doit reposer sur l'herbe, 0,035 au plus")
    if z1 > -berge + EPS and z0 < berge - EPS:
        e.append(f"case de damier dans la riviere en {p['pos']}")
    for bx in (-VOIE, VOIE):
        if x1 > bx - 1.6 + EPS and x0 < bx + 1.6 - EPS:
            e.append(f"case de damier sous l'allee x={bx} : les deux surfaces scintilleraient")
    if p["ombre"] or p["matiere"] != "Grass":
        e.append("une case de damier doit etre de l'herbe, sans ombre portee")
# une case sur deux : chaque case foncee est au bon rang de parite
for p in dalles:
    i = math.floor((p["pos"][0] + W) / T)
    j = math.floor((p["pos"][2] + L) / T)
    if (i + j) % 2 != 0:
        e.append(f"damier : case foncee au mauvais rang ({i}, {j})")
couvert = sum(p["taille"][0] * p["taille"][2] for p in dalles)
utile = 2 * W * (2 * L - 2 * berge) - 2 * 3.2 * (2 * L - 2 * berge)
if not (0.4 * utile < couvert < 0.6 * utile):
    e.append(f"le damier couvre {couvert:.0f} studs2 sur {utile:.0f} : ce n'est plus une case sur deux")

# --- LES TRACES DEJA SUR LE TERRAIN SONT GARDEES A L'IDENTIQUE -------------------------------------
attendu = sorted(
    [("Allee", (3.2, 0.06, L * 2 - 4), (bx, 0.53, 0)) for bx in (-VOIE, VOIE)]
    + [("Rambarde", (0.4, 1, 6), (bx + s * 2.1, 1.1, 0)) for bx in (-VOIE, VOIE) for s in (-1, 1)]
    + [("Berge", (W * 2, 0.7, 0.6), (0, 0.55, s * 2.2)) for s in (-1, 1)])
vu = sorted((p["nom"], tuple(round(v, 6) for v in p["taille"]), tuple(round(v, 6) for v in p["pos"]))
            for p in ref if p["role"] == "trace")
attendu = [(n, tuple(round(v, 6) for v in t), tuple(round(v, 6) for v in q)) for n, t, q in attendu]
if vu != attendu:
    e.append("les traces du terrain (allees, rambardes, berges) ont bouge par rapport a l'ancien decor")

# --- LES DEUX JOUEURS VOIENT LE MEME PAYSAGE (symetrie par demi-tour) -----------------------------
def cle(p, miroir=False):
    x, y, z = p["pos"]
    if miroir:
        x, z = -x, -z
    return (p["nom"], tuple(round(v, 4) for v in p["taille"]), round(x, 4), round(y, 4), round(z, 4))


if Counter(cle(p) for p in ref) != Counter(cle(p, True) for p in ref):
    e.append("l'ile n'est pas symetrique par demi-tour : le joueur d'en face verrait un autre paysage")

# --- NOMS : AUCUNE CONFUSION AVEC UNE PIECE DE JEU ------------------------------------------------
# Le client reconnait les unites a leur NOM (Cards.byId[enfant.Name]) et les tours a KingTower /
# PrincessTower : une piece de decor qui porterait un de ces noms jouerait un son de mort a sa
# disparition, ou recevrait une etiquette.
ids_cartes = set(re.findall(r'\bid\s*=\s*"(\w+)"', CARTES))
reserves = {"GroundPlayer", "GroundEnemy", "River", "Bridge", "DeployZone", "KingTower",
            "PrincessTower", "CouronneGagnee"} | ids_cartes
for nom in sorted({p["nom"] for p in ref} & reserves):
    e.append(f"la piece de decor « {nom} » porte le nom d'une piece de jeu")

# --- LE THEME NE DONNE QUE DES COULEURS ET UN LIQUIDE CONNU ---------------------------------------
for t in themes:
    if t.liquide is not None and not M.LIQUIDES[t.liquide]:
        e.append(f"theme {t.id} : liquide inconnu « {t.liquide} »")
if not any(t.liquide == "lave" for t in themes):
    e.append("aucun theme a lave : le volcan serait entoure d'eau")
lave = [p for p in par_theme["volcan"] if p["nom"] == "Mer"] if "volcan" in par_theme else []
if lave and lave[0]["matiere"] != "CrackedLava":
    e.append("theme volcan : la mer devrait etre de la lave")
if "function(" in MQ.split("Maquette.pieces")[0] and "Random.new" in MQ:
    e.append("Maquette utilise Random.new : le banc ne verrait plus le meme decor que le serveur")

# --- BRANCHEMENT SERVEUR ---------------------------------------------------------------------------
if 'item("ModuleScript", "Maquette", source=src("shared/Maquette.lua"))' not in B:
    e.append("build : Maquette non embarque")
corps = corps_fonction(S, "local function decorerArene()")
for attendu_srv, motif in (
        ('WaitForChild("Maquette")', "le module n'est pas requis"),
        ("Maquette.pieces(", "les pieces ne sont pas demandees au module"),
        ("deco({", "les pieces ne passent pas par deco() (collision et clics)"),
        ('dossier.Name = "Decor"', "les pieces ne sont pas rangees dans le sous-dossier Decor"),
        ("dossier.Parent = arena", "le sous-dossier n'est pas dans l'arene (il ne serait pas detruit avec elle)"),
        ("CFrame.Angles(math.rad(d.rot[1]), math.rad(d.rot[2]), math.rad(d.rot[3]))", "la rotation n'est pas appliquee dans l'ordre du module"),
        ("Enum.MeshType.Sphere", "les ellipsoides ne recoivent pas leur maillage"),
        ("demiLargeur = HALF_W, demiLongueur = HALF_L, voies = BRIDGES", "les dimensions ne viennent pas du terrain"),
        ("dessus = GROUND_Y", "la hauteur de l'herbe ne vient pas de GROUND_Y")):
    if attendu_srv not in corps:
        e.append("serveur : " + motif)
# UNE SEULE ENTREE DANS LE JEU : chaque piece nait dans le dossier (Parent pose en dernier par
# makePart), et le dossier n'est accroche a l'arene qu'une fois rempli. Sinon sept cents pieces
# entreraient dans l'arene puis en ressortiraient — autant d'evenements pour le client.
if "Parent = dossier" not in corps:
    e.append("serveur : les pieces ne naissent pas dans le dossier Decor")
if corps.find("dossier.Parent = arena") < corps.find("for _, d in ipairs(pieces)"):
    e.append("serveur : le dossier Decor est accroche a l'arene AVANT d'etre rempli")
mp = corps_fonction(S, "local function makePart(props)")
if 'if k == "Parent" then' not in mp or "p.Parent = parent" not in mp:
    e.append("serveur : makePart ne pose plus le parent en dernier")
if "Instance.new(\"Part\")" in corps or "makePart(" in corps:
    e.append("serveur : une piece de decor est posee hors de deco() — elle serait cliquable ou solide")
dec = corps_fonction(S, "local function deco(props)")
if "props.CanCollide = false" not in dec or "props.CanQuery = false" not in dec:
    e.append("serveur : deco() ne rend plus les pieces non solides et invisibles aux clics")
# Le fichier est au plafond des 200 locales : le module doit etre requis DANS la fonction.
if re.search(r"^local Maquette\b", S, re.M):
    e.append("serveur : Maquette requis en tete du script (plafond des 200 locales)")
# LES PIECES DE REGLES NE SONT PAS TOUCHEES : buildArena les pose toujours, avec les memes tailles.
arene = corps_fonction(S, "local function buildArena()")
for piece in ('Name = "GroundPlayer", Size = Vector3.new(HALF_W * 2, 1, HALF_L), Position = Vector3.new(0, 0, -HALF_L / 2)',
              'Name = "GroundEnemy", Size = Vector3.new(HALF_W * 2, 1, HALF_L), Position = Vector3.new(0, 0, HALF_L / 2)',
              'Name = "River", Size = Vector3.new(HALF_W * 2, 1.1, 4), Position = Vector3.new(0, 0.05, 0)',
              'Name = "Bridge", Size = Vector3.new(4, 1.3, 6), Position = Vector3.new(bx, 0.15, 0)',
              'Name = "DeployZone", Size = Vector3.new(HALF_W * 2, 0.05, HALF_L - 2)'):
    if piece not in arene:
        e.append("buildArena : piece de regle modifiee -> " + piece.split(",")[0])
if "decorerArene()" not in arene:
    e.append("buildArena : l'ile n'est plus posee")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else
      f"VERT : ile maquette de {len(ref)} pieces, {len(dalles)} cases de damier, rien sur le terrain, "
      f"meme geometrie pour les {len(themes)} themes")
sys.exit(1 if e else 0)
