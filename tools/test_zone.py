# -*- coding: utf-8 -*-
"""ZONE DE POSE SURLIGNEE (src/shared/Zone.lua + branchement).

Le defaut corrige : une carte armee, et rien ne disait OU elle pouvait atterrir — on decouvrait la
limite en se faisant refuser. Et la moitie adverse OUVERTE par une tour tombee, la regle la plus
valorisante du jeu, etait totalement invisible.

1) Les regles PURES sont EXECUTEES (lupa), et CONFRONTEES a la regle de pose du serveur
   (Regles.posePermise, Batiments.posePermise) : un surlignage qui ment est pire que pas de
   surlignage du tout.
2) Le branchement est lu : le client construit les dalles, ne les reconstruit pas a chaque image,
   les efface quand plus aucune carte n'est armee.
"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import zone  # decoupe par CONTENU (voir tools/bancs.py)
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
ZO = (R / "src/shared/Zone.lua").read_text(encoding="utf-8")
RG = (R / "src/shared/Regles.lua").read_text(encoding="utf-8")
BA = (R / "src/shared/Batiments.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(ZO)
Regles = lua.execute(RG)
Batiments = lua.execute(BA)
DEMI_L, DEMI_P = 28, 32

def rects(camp, carte, gauche=False, droite=False):
    t = M.rectangles(camp, carte, gauche, droite, DEMI_L, DEMI_P)
    return [t[i] for i in range(1, len(t) + 1)]
def carte(**kv):
    o = lua.eval("function() return {} end")()
    for k, v in kv.items():
        o[k] = v
    return o
def dans(r, x, z):
    return (abs(x - r.x) <= r.largeur / 2 + 1e-9) and (abs(z - r.z) <= r.longueur / 2 + 1e-9)
def couvert(rs, x, z):
    return any(dans(r, x, z) for r in rs)

# --- LES MEMES BORNES QUE LE SERVEUR ------------------------------------------------------------
if M.BANDE_RIVIERE != Batiments.BANDE_RIVIERE:
    e.append(f"la bande de riviere surlignee ({M.BANDE_RIVIERE}) ne colle pas a la regle serveur ({Batiments.BANDE_RIVIERE})")

# --- CAS NORMAL : SA MOITIE ---------------------------------------------------------------------
for camp in (1, 2):
    s = -1 if camp == 1 else 1
    rs = rects(camp, carte(id="u"))
    if len(rs) != 1 or rs[0].genre != "propre":
        e.append(f"camp {camp} : un seul rectangle « propre » attendu, obtenu {[r.genre for r in rs]}")
    # Confrontation point par point avec la REGLE DU SERVEUR : aucun mensonge tolere.
    for x in range(-27, 28, 3):
        for z in range(-31, 32, 2):
            permis = Regles.posePermise(camp, x, z, False, False) and abs(x) <= 27 and abs(z) <= 31
            if permis != couvert(rs, x, z):
                e.append(f"camp {camp} : desaccord avec le serveur en ({x},{z}) — serveur={permis}")
                break
        else:
            continue
        break

# --- VOIE OUVERTE PAR UNE TOUR TOMBEE -----------------------------------------------------------
rs = rects(1, carte(id="u"), gauche=True)
if not any(r.genre == "ouverte" for r in rs):
    e.append("une tour tombee doit OUVRIR une zone surlignee (la regle etait invisible)")
if couvert([r for r in rs if r.genre == "ouverte"], 20, 20):
    e.append("la voie gauche ne doit pas ouvrir le cote DROIT de la moitie adverse")
if not couvert(rs, -20, 20):
    e.append("la voie gauche ouverte doit couvrir le cote gauche de la moitie adverse")
# Confrontation avec le serveur, voie gauche ouverte.
for x in (-20, -5, 5, 20):
    for z in (-20, -5, 5, 20):
        permis = Regles.posePermise(1, x, z, True, False)
        if permis != couvert(rs, x, z):
            e.append(f"voie ouverte : desaccord avec le serveur en ({x},{z}) — serveur={permis}")
# Les deux voies ouvertes couvrent toute la moitie adverse.
rs2 = rects(1, carte(id="u"), gauche=True, droite=True)
if not (couvert(rs2, -20, 20) and couvert(rs2, 20, 20)):
    e.append("les deux voies ouvertes doivent couvrir les deux cotes")

# --- SORT ET CARTE QUI SE POSE PARTOUT ----------------------------------------------------------
for c in (carte(id="s", sort=True), carte(id="m", poseLibre=True)):
    rs = rects(1, c)
    if len(rs) != 1 or rs[0].genre != "totale":
        e.append("un sort (ou une carte qui se pose partout) doit surligner TOUTE l'arene")
    if not (couvert(rs, 0, 25) and couvert(rs, 0, -25)):
        e.append("la zone totale doit couvrir les deux moities")

# --- BATIMENT : PAS SUR LA RIVIERE --------------------------------------------------------------
rs = rects(1, carte(id="b", batiment=lua.eval("function() return { type = 'canon' } end")()))
for z in (-4, -3, -1):
    if couvert(rs, 0, z):
        e.append(f"un batiment ne doit pas etre surligne pres de la riviere (z={z})")
if not couvert(rs, 0, -20):
    e.append("un batiment doit pouvoir se poser au fond de sa moitie")
for x in (-20, 0, 20):
    for z in (-30, -20, -10, -6, -4, 0, 10):
        permis = Batiments.posePermise(1, x, z, None) and abs(x) <= 27 and abs(z) <= 31
        if permis != couvert(rs, x, z):
            e.append(f"batiment : desaccord avec le serveur en ({x},{z}) — serveur={permis}")

# --- COULEURS ET SIGNATURE ----------------------------------------------------------------------
couleurs = {g: tuple(M.couleur(g).values()) for g in ("propre", "ouverte", "totale")}
if len(set(couleurs.values())) != 3:
    e.append("les trois genres de zone doivent se distinguer par la couleur")
if tuple(M.couleur("inconnu").values()) != couleurs["propre"]:
    e.append("un genre inconnu doit retomber sur une couleur sure")
s1 = M.signature(1, carte(id="a"), False, False)
if s1 == M.signature(1, carte(id="b"), False, False):
    e.append("changer de carte doit changer la signature (sinon la zone ne se met pas a jour)")
if s1 == M.signature(1, carte(id="a"), True, False):
    e.append("une tour qui tombe doit changer la signature")
if s1 != M.signature(1, carte(id="a"), False, False):
    e.append("la signature doit etre stable a etat egal (sinon on reconstruit a chaque image)")

# --- ANNONCE ------------------------------------------------------------------------------------
if M.annonceOuverture(False, False) is not None:
    e.append("aucune annonce tant qu'aucune voie n'est ouverte")
if "gauche" not in M.annonceOuverture(True, False):
    e.append("l'annonce doit nommer le cote ouvert")
if M.annonceOuverture(True, True) == M.annonceOuverture(True, False):
    e.append("deux voies ouvertes, ce n'est pas la meme nouvelle qu'une seule")

# --- BRANCHEMENT --------------------------------------------------------------------------------
if 'item("ModuleScript", "Zone"' not in B:
    e.append("build : Zone non embarque")
if 'WaitForChild("Zone")' not in C:
    e.append("client : module Zone non requis")
if "Zone.rectangles(monCamp, card, gauche, droite" not in C:
    e.append("client : les dalles ne viennent pas de la regle")
if "Zone.signature(monCamp, card, gaucheOuverte, droiteOuverte)" not in C:
    e.append("client : la zone serait reconstruite a chaque image")
# fix-ok mesure a l'ecran : une dalle NEON pleine delavait toute la scene. La zone totale se
# dessine en LISERE, et plus aucune dalle n'est en neon.
if "ZoneBord" not in C:
    e.append("client : la zone totale serait un aplat sur toute l'arene (scene delavee)")
# fix-ok mesure a l'ecran (2e capture) : a 0,92 de transparence la dalle etait INVISIBLE sur
# l'herbe. C'est le CONTOUR qui porte l'information, dans tous les cas.
if "contour(rgb, r, 0.15)" not in C:
    e.append("client : sans contour net, le surlignage est illisible sur un fond clair")
if "0.92" in zone(C, "local function construireZone"):
    e.append("client : une dalle a 0,92 de transparence n'informe plus de rien")
    e.append("client : une dalle a 0,92 de transparence n'informe plus de rien")
if "Enum.Material.Neon" in C.split("local function construireZone")[1].split("end")[0]:
    e.append("client : dalle de zone en NEON — elle delave le decor et les unites")
if "effacerZone()" not in C or "local function effacerZone" not in C:
    e.append("client : le surlignage ne disparait pas quand plus aucune carte n'est armee")
if "Zone.annonceOuverture(gaucheOuverte, droiteOuverte)" not in C:
    e.append("client : l'ouverture d'une voie n'est jamais annoncee")
if "ouvertureAnnoncee" not in C:
    e.append("client : l'annonce serait repetee en boucle")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : le surlignage dit exactement ce que le serveur accepte, voie ouverte comprise")
sys.exit(1 if e else 0)
