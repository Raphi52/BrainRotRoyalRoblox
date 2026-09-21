# -*- coding: utf-8 -*-
"""LISIBILITE DES DEUX CAMPS (src/shared/Camps.lua).

Le defaut corrige : les couleurs etaient ABSOLUES (camp 1 bleu, camp 2 rouge). Le joueur du camp 2
voyait donc SES unites en rouge et celles d'en face en bleu — il lisait le terrain a l'envers.

1) Les regles PURES sont EXECUTEES (lupa) : couleur et forme relatives au joueur, vue neutre du
   spectateur, cote ou poser le nom de l'adversaire.
2) Le branchement est lu : le serveur marque le camp sur les parts, le client repeint selon LUI,
   n'efface pas la couleur des cartes, et pose le nom de l'adversaire sur son cote.
"""
import re, sys, pathlib
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import zone  # decoupe par CONTENU (voir tools/bancs.py)
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
CA = (R / "src/shared/Camps.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(CA)
def rgb(t):
    return [t[1], t[2], t[3]]

AMI, ENNEMI = rgb(M.AMI), rgb(M.ENNEMI)
if AMI == ENNEMI:
    e.append("ami et ennemi ne peuvent pas partager la meme couleur")

# --- COULEUR RELATIVE AU JOUEUR -----------------------------------------------------------------
if rgb(M.couleur(1, 1)) != AMI:
    e.append("le camp 1 doit voir SES unites en couleur amie")
if rgb(M.couleur(2, 1)) != ENNEMI:
    e.append("le camp 1 doit voir celles d'en face en couleur ennemie")
# LE COEUR DU DEFAUT : le camp 2 doit voir exactement la meme chose de SON point de vue.
if rgb(M.couleur(2, 2)) != AMI:
    e.append("le camp 2 voit encore SES unites en couleur ennemie (defaut d'origine)")
if rgb(M.couleur(1, 2)) != ENNEMI:
    e.append("le camp 2 doit voir le camp 1 en couleur ennemie")
# Spectateur (monCamp nil ou 0) : couleurs du CAMP, pas de « chez moi ».
if rgb(M.couleur(1, 0)) != rgb(M.CAMP1) or rgb(M.couleur(2, 0)) != rgb(M.CAMP2):
    e.append("le spectateur doit garder les couleurs des camps")
if rgb(M.couleur(1, None)) != rgb(M.CAMP1):
    e.append("sans camp connu, on retombe sur les couleurs des camps")
if M.estAmi(1, 0) is not None or M.estAmi(2, None) is not None:
    e.append("un spectateur n'a pas d'allie")

# --- FORME : LISIBLE SANS LES COULEURS ----------------------------------------------------------
if M.forme(1, 1) != M.FORME_AMI or M.forme(2, 1) != M.FORME_ENNEMI:
    e.append("la forme de la marque ne distingue pas les camps")
if M.forme(2, 2) != M.FORME_AMI or M.forme(1, 2) != M.FORME_ENNEMI:
    e.append("la forme doit suivre le point de vue, comme la couleur")
if M.FORME_AMI == M.FORME_ENNEMI:
    e.append("deux formes identiques n'aident pas un joueur qui confond les couleurs")

# --- LIRE LES CAMPS SANS LES COULEURS -----------------------------------------------------------
# Un joueur sur douze confond le rouge et le vert-bleu : pour lui, le duel reposait sur une
# distinction qu'il ne voit pas.
for vu in (1, 2):
    if M.signauxDistincts(vu) < 3:
        e.append(f"camp {vu} : moins de trois signaux distincts (couleur, forme, segments)")
if M.signauxDistincts(0) < 2:
    e.append("spectateur : les deux camps doivent rester distinguables par au moins deux signaux")
# BARRES DE VIE : celle d'en face est segmentee, la sienne est pleine.
if M.segmentsBarre(1, 1) != 0 or M.segmentsBarre(2, 1) == 0:
    e.append("camp 1 : sa barre doit etre pleine, celle d'en face segmentee")
if M.segmentsBarre(2, 2) != 0 or M.segmentsBarre(1, 2) == 0:
    e.append("camp 2 : meme lecture de SON point de vue")
if M.segmentsBarre(1, 0) != 0 or M.segmentsBarre(2, 0) == 0:
    e.append("spectateur : les deux barres seraient identiques sans couleur")
if M.SEGMENTS_ENNEMI < 2:
    e.append("un seul trait ne se lit pas sur une barre de 90 px")
# TOURS : meme langage de forme que les unites.
if M.formeTour(1, 1) != M.forme(1, 1) or M.formeTour(2, 1) != M.forme(2, 1):
    e.append("les tours doivent parler le MEME langage de forme que les unites")
if M.formeTour(2, 2) != M.FORME_AMI:
    e.append("la tour du camp 2 doit etre « amie » pour le joueur du camp 2")

# --- CONTOUR ------------------------------------------------------------------------------------
contour = rgb(M.contour(2, 1))
if contour == ENNEMI:
    e.append("le contour doit etre une version ASSOMBRIE, pas la couleur pleine")
if any(contour[i] > ENNEMI[i] for i in range(3)):
    e.append("le contour ne doit jamais etre plus clair que la couleur du camp")

# --- COTE DE L'ADVERSAIRE ET SON NOM ------------------------------------------------------------
if M.coteAdverse(1) != 1 or M.coteAdverse(2) != -1:
    e.append("le cote adverse doit etre l'oppose du sien")
if M.coteAdverse(0) is not None or M.coteAdverse(None) is not None:
    e.append("un spectateur n'a pas de cote adverse")
if M.nomAdverse("Player2") != "Player2":
    e.append("le nom de l'adversaire doit etre repris tel quel")
for vide in ("", None, 7):
    if M.nomAdverse(vide) != "Robot":
        e.append("sans nom, une etiquette vide flotterait au-dessus de la tour")

# --- BRANCHEMENT SERVEUR ------------------------------------------------------------------------
if S.count('SetAttribute("Camp"') < 4:
    e.append("serveur : le camp n'est pas marque sur les parts (le client ne peut pas savoir qui est qui)")
if 'disque.Name = "DisqueCamp"' not in S:
    e.append("serveur : le disque au sol n'est pas nommable par le client")
if 'item("ModuleScript", "Camps"' not in B:
    e.append("build : Camps non embarque (le client resterait bloque)")

# --- BRANCHEMENT CLIENT -------------------------------------------------------------------------
if 'WaitForChild("Camps")' not in C:
    e.append("client : module Camps non requis")
if "local function relookerCamps" not in C or "relookerCamps()" not in C:
    e.append("client : aucune reprise des couleurs selon le joueur")
if "Camps.couleur(camp, vu)" not in C:
    e.append("client : la couleur n'est pas calculee pour CE joueur")
if not re.search(r'local vu = jeSuisSpectateur and 0 or monCamp', C):
    e.append("client : le spectateur serait traite comme un joueur")
if "marquerTour(part, camp, vu, couleur)" not in C:
    e.append("client : les tours ne portent aucune marque de forme")
if "segmenterBarre(fond, Camps.segmentsBarre(camp, vu))" not in C:
    e.append("client : les barres de vie ne sont pas segmentees selon le camp")
if "local function segmenterBarre" not in C or "TraitCamp" not in C:
    e.append("client : aucun trait de separation n'est dessine")
if C.count("Enum.PartType.Ball") < 2:
    e.append("client : la forme n'est appliquee qu'a un seul type d'objet")
if "Enum.PartType.Ball or Enum.PartType.Block" not in C:
    e.append("client : la forme de la marque ne change pas")
# Garde-fou : ne JAMAIS repeindre le corps d'une unite (il porte la couleur de sa carte).
if not re.search(r'if part\.Name == "KingTower" or part\.Name == "PrincessTower" then\s*\n\s*part\.Color = couleur', C):
    e.append("client : la couleur des CARTES serait ecrasee par celle du camp")
if "poserNomAdverse" not in C or "Camps.nomAdverse(nomAdverseVu)" not in C:
    e.append("client : le nom de l'adversaire n'est pas pose sur son cote")
if not re.search(r"local nomAdverseVu = nil", C.split("StateEvent.OnClientEvent")[0]):
    e.append("client : nomAdverseVu declare APRES son usage (il resterait vide)")

# --- LISIBILITE DES MARQUES A DISTANCE ----------------------------------------------------------
# Le defaut : la marque de camp posee au-dessus des tours avait une taille FIXE (1,8 stud). Au
# dessus de SES tours (~12 studs) elle se lisait ; au-dessus de celles d'en face (60-90 studs) la
# boule et le cube devenaient le meme point, et il ne restait que la couleur — le defaut daltonien
# corrige de pres revenait avec la distance.

# 1) La taille grandit AVEC la distance : une taille fixe en studs rétrecit a l'ecran comme 1/d.
proche, loin = M.tailleMarque(12), M.tailleMarque(85)
if not (loin > proche):
    e.append(f"la marque doit grandir avec la distance : {proche} a 12 studs, {loin} a 85")
# Taille ANGULAIRE : a l'ecran, la marque lointaine doit faire au moins la moitie de la proche
# (une taille fixe donnerait un rapport de 12/85, soit sept fois plus petite).
# De pres, la marque garde un plancher (on ne veut pas non plus qu'elle masque la tour) : l'angle
# proche est donc forcement le plus grand. Deux exigences chiffrees, a 85 studs — la distance
# d'une tour d'en face vue depuis son propre camp :
angleProche, angleLoin = proche / 12.0, loin / 85.0
if angleLoin < angleProche / 3:
    e.append(f"a l'ecran, la marque lointaine reste trop petite : {angleLoin:.4f} contre {angleProche:.4f}")
if loin < 2 * 1.8:
    e.append(f"a 85 studs, la marque ({loin:.2f}) ne fait pas le double de l'ancienne taille fixe (1,8)")
# Bornes : ni un point de pres, ni un ballon qui masque l'arene de loin.
if M.tailleMarque(0) < M.MARQUE_MIN or M.tailleMarque(5000) > M.MARQUE_MAX:
    e.append("la taille de marque sort de ses bornes")
for mauvais in (None, -40, "loin"):
    t = M.tailleMarque(mauvais)
    if t < M.MARQUE_MIN or t > M.MARQUE_MAX:
        e.append(f"une distance aberrante ({mauvais!r}) produit une marque de {t}")

# 2) CONTRASTE MESURE, pas juge a l'oeil. Le rapport de luminance vaut 1 pour deux teintes de meme
# clarte et 21 pour du noir sur blanc.
if round(M.contraste(lua.table_from([255, 255, 255]), lua.table_from([0, 0, 0]))) != 21:
    e.append("la mesure de contraste est fausse : blanc sur noir doit valoir 21")
if round(M.contraste(lua.table_from([90, 90, 90]), lua.table_from([90, 90, 90]))) != 1:
    e.append("la mesure de contraste est fausse : une couleur contre elle-meme doit valoir 1")

for vu, nom in ((1, "joueur du camp 1"), (2, "joueur du camp 2"), (0, "spectateur")):
    ma, sa = M.couleurMarque(1, vu), M.couleurMarque(2, vu)
    # LE COEUR DU DEFAUT : les deux marques doivent differer par la CLARTE, pas seulement par la
    # teinte — sinon elles se confondent des qu'elles sont petites, et en noir et blanc.
    c = M.contraste(ma, sa)
    if c < M.CONTRASTE_MIN:
        e.append(f"{nom} : les deux marques ont presque la meme clarte (contraste {c:.2f})")
    # Chaque marque doit se detacher de son propre liseré, sinon la silhouette — donc la FORME —
    # disparait de loin.
    for camp, couleur in ((1, ma), (2, sa)):
        cl = M.contraste(couleur, M.lisere(camp, vu))
        if cl < M.CONTRASTE_MIN:
            e.append(f"{nom} : la marque du camp {camp} se noie dans son liseré (contraste {cl:.2f})")
    # Et le liseré n'est pas le meme des deux cotes : clair sous une marque sombre, sombre sous une
    # marque claire.
    if rgb(M.lisere(1, vu)) == rgb(M.lisere(2, vu)):
        e.append(f"{nom} : le meme liseré pour les deux marques, alors que leurs clartes s'opposent")

# 3) Le liseré doit EPOUSER la forme. Une SelectionBox dessine une boite meme autour d'une boule :
# elle effacait la difference de forme et, epaisse, masquait la marque (capture du 2026-09-21).
if 'Instance.new("SelectionBox")' in C:
    e.append("client : un contour en boite effacerait la difference entre la boule et le cube")
if 'Instance.new("Highlight")' not in zone(C, "local function marquerTour"):
    e.append("client : la marque n'a pas de contour qui epouse sa forme")
if "bord.FillTransparency = 1" not in C:
    e.append("client : le contour remplirait la marque et masquerait sa couleur")

# 4) BRANCHEMENT : le client mesure vraiment la distance a la camera, et pose le liseré.
if "Camps.tailleMarque(" not in C:
    e.append("client : la taille de la marque ne depend pas de la distance")
if "camera.CFrame.Position" not in zone(C, "local function marquerTour"):
    e.append("client : la distance n'est pas mesuree depuis la camera")
if "marque.Size = Vector3.new(taille, taille, taille)" not in C:
    e.append("client : la taille calculee n'est jamais appliquee")
if "Camps.couleurMarque(camp, vu)" not in C:
    e.append("client : la marque reprend la couleur du corps, au lieu de sa couleur contrastee")
# MATERIAU AUTO-ECLAIRE : sans lui, la marque prend la lumiere et la clarte VUE n'est plus celle
# qui a ete calculee — mesure a l'ecran le 2026-09-21, les marques proches sortaient noires.
if "marque.Material = Enum.Material.Neon" not in C:
    e.append("client : la marque subit l'eclairage, sa clarte vue ne sera pas celle calculee")
if "Camps.lisere(camp, vu)" not in C:
    e.append("client : la marque n'a pas de liseré, donc pas de silhouette de loin")
# La marque doit etre rafraichie regulierement, sinon sa taille se fige au premier calcul.
if "attenteCamps = 0" + chr(10) + "		relookerCamps()" not in C:
    e.append("client : les marques ne sont pas rafraichies, leur taille resterait figee")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : camps lisibles — couleur relative, forme, segments, et marques contrastees a distance")
sys.exit(1 if e else 0)
