# -*- coding: utf-8 -*-
"""Garde-fou des 5 demandes du 2026-09-20 sur le hub.

1. les tuiles de boutique ne chevauchent plus nom / rarete (calcul reel des bandes verticales) ;
2. le bandeau porte bien les GEMMES, alimentees par la vue serveur ;
3. l'ecran BATAILLE montre le deck courant (vue.deck), sans nouvelle action serveur ;
4. les coffres sont DESSINES (couvercle + corps + bande + serrure), pas un aplat ;
5. CLAN et EVENEMENTS ne sont plus vides : ecusson + chiffres, et tuiles d'evenement.
"""
import re, sys, pathlib
H = (pathlib.Path(__file__).resolve().parent.parent / "src/client/Hub.client.lua").read_text(encoding="utf-8")
e = []

# 1 -- chevauchement : on relit les positions ecrites dans le code
def bande(motif, nom):
    m = re.search(motif, H)
    if not m:
        e.append("boutique : %s introuvable dans la tuile" % nom)
        return None
    h, y = float(m.group(1)), float(m.group(2))
    return (y, y + h)
nomC = bande(r'texte\(tuile, card\.name, UDim2\.new\(0\.9, 0, ([\d.]+), 0\), UDim2\.new\(0\.05, 0, ([\d.]+), 0\)\)', "le nom de carte")
rarC = bande(r'texte\(tuile, rar\.nom, UDim2\.new\(0\.9, 0, ([\d.]+), 0\), UDim2\.new\(0\.05, 0, ([\d.]+), 0\)', "la rarete")
if nomC and rarC and nomC[1] > rarC[0]:
    e.append("boutique : le nom descend a %.2f et la rarete commence a %.2f -> ils se chevauchent" % (nomC[1], rarC[0]))

# 2 -- gemmes au bandeau
if not re.search(r"valGemmes = jeton\(", H):
    e.append("bandeau : aucun jeton de gemmes")
if not re.search(r"valGemmes\.Text = tostring\(v\.gemmes", H):
    e.append("bandeau : les gemmes ne sont pas alimentees par la vue serveur")
xs = [float(x) for x in re.findall(r"jeton\((0\.\d+),", H)]
if len(xs) < 3:
    e.append("bandeau : %d jetons, il en faut 3 (pieces, gemmes, trophees)" % len(xs))
else:
    for a, b in zip(sorted(xs), sorted(xs)[1:]):
        if b - a < 0.18:
            e.append("bandeau : deux jetons a %.2f et %.2f, plus proches que leur largeur 0.18" % (a, b))

# 3 -- deck courant sur BATAILLE
# La rangee est desormais produite par UNE fabrique appelee deux fois (accueil + onglet CARTES).
# On verifie donc que l ecran d accueil en recoit bien une, pas une ligne de code precise.
if "majDeckBataille = function" not in H or "construireRangeeDeck(accueil" not in H:
    e.append("bataille : pas de rangee de deck sur l'ecran d'accueil")
if not re.search(r"local liste = \(vue and vue\.deck\) or \{\}", H):
    e.append("bataille : la rangee de deck ne lit pas vue.deck")
if H.index("local majOnglets") > H.index("-- DECK COURANT SUR BATAILLE"):
    e.append("bataille : la rangee de deck est ecrite avant `local majOnglets` -> le clic capturerait un nil")

# 4 -- coffres dessines
if "local function dessinerCoffre" not in H:
    e.append("coffres : aucun dessin de coffre")
for piece in ("couvercle", "corps", "bande", "serrure"):
    if not re.search(r"local %s = Instance\.new\(\"Frame\"\)" % piece, H):
        e.append("coffres : piece « %s » absente du dessin" % piece)
if not re.search(r"e\.coffre\.couvercle\.BackgroundColor3 = teinte", H):
    e.append("coffres : le type de coffre ne recolore pas le dessin")
# emplacement vide : c'est la BOITE entiere qui disparait. En masquant seulement corps et
# couvercle, la bande doree et la serrure flottaient dans le vide (capture du 2026-09-20 15:04).
# Ce qui compte : aucune piece ne doit rester peinte SEULE dans le vide sur un emplacement
# libre. Deux facons valables d y arriver : masquer la boite entiere, ou traiter les QUATRE
# pieces ENSEMBLE (silhouette grise et effacee, choix retenu le 2026-09-20).
boite_masquee = "e.coffre.boite.Visible = false" in H
ensemble = re.search(r"for _, part in ipairs\(\{ e\.coffre\.couvercle, e\.coffre\.corps, "
                     r"e\.coffre\.bande, e\.coffre\.serrure \}\) do", H) is not None
if not (boite_masquee or ensemble):
    e.append("coffres : un emplacement vide laisse des pieces peintes seules (bande, serrure)")

# 5 -- CLAN et EVENEMENTS remplis
for motif, msg in ((r"ecusson\.Parent = clanEcran", "clan : pas d'ecusson"),
                   (r"majClan = function", "clan : aucun chiffre mis a jour"),
                   (r"local function tuileEvenement", "evenements : pas de tuiles d'evenement"),
                   (r"majEvenements = function", "evenements : aucun chiffre mis a jour")):
    if not re.search(motif, H):
        e.append(msg)
# les trois rafraichissements doivent etre appeles DANS afficher(), la seule porte d'entree
# de la vue serveur : declares mais jamais appeles, les ecrans resteraient figes a zero.
_d = H.index("local function afficher(v)")
corps_afficher = H[_d:H.index(chr(10) + "end" + chr(10), _d)]
for appel in ("majClan()", "majEvenements()", "majDeckBataille()"):
    if appel not in corps_afficher:
        e.append("hub : %s n'est pas rappele par afficher() quand la vue change" % appel)

for x in e:
    print("ROUGE", x)
print("OK" if not e else "%d echec(s)" % len(e))
sys.exit(1 if e else 0)
