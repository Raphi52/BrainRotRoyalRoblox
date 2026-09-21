# -*- coding: utf-8 -*-
"""MISE EN PAGE DU DUEL (src/shared/Mise.lua + branchement).

Le defaut corrige : toutes les positions etaient ecrites en PIXELS FIXES. Sur un ecran large tout
tenait ; sur une fenetre etroite, les blocs se marchaient dessus — et on ne s'en apercevait qu'en
changeant de machine.

CE BANC BALAIE DES DIZAINES DE FORMATS et refuse le moindre chevauchement. C'est exactement ce
qu'une capture ne peut pas faire : elle ne montre qu'UNE taille d'ecran.
"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import zone  # decoupe par CONTENU (voir tools/bancs.py)
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
MI = (R / "src/shared/Mise.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(MI)
def blocs(L, H):
    t = M.blocs(L, H)
    return [t[i] for i in range(1, len(t) + 1)]
def noms(t):
    return [t[i] for i in range(1, len(t) + 1)]

# --- BALAYAGE DE FORMATS ------------------------------------------------------------------------
FORMATS = [
    (1920, 1080, "bureau 16:9"), (1452, 793, "fenetre de capture"), (1280, 720, "720p"),
    (1024, 768, "4:3"), (900, 600, "petite fenetre"), (800, 600, "vieux 4:3"),
    (768, 1024, "tablette portrait"), (592, 1348, "telephone portrait etroit"),
    (540, 960, "telephone"), (480, 800, "petit telephone"), (2560, 1440, "grand ecran"),
    (1366, 768, "portable"), (1080, 1920, "telephone vertical"), (640, 480, "minuscule"),
]
for L, H, nom in FORMATS:
    bs = blocs(L, H)
    ch = noms(M.chevauchements(M.blocs(L, H)))
    if ch:
        e.append(f"{nom} ({L}x{H}) : blocs qui se recouvrent -> {', '.join(ch)}")
    hors = noms(M.hors(M.blocs(L, H), L, H))
    if hors:
        e.append(f"{nom} ({L}x{H}) : blocs hors de l'ecran -> {', '.join(hors)}")
    # le chrono et la main de cartes ne disparaissent JAMAIS : sans eux, on ne joue plus.
    for vital in ("chrono", "score", "main", "lecture"):
        b = M.trouver(M.blocs(L, H), vital)
        if b is None or b.visible is not True:
            e.append(f"{nom} ({L}x{H}) : le bloc vital « {vital} » est absent")

# --- TAILLES ABSURDES : LE PREMIER CALCUL SE FAIT SUR UN ECRAN 1x1 ------------------------------
# Mesure a l'ecran : au chargement, Roblox rend une vue de 1x1 et la mise en page sortait des
# blocs de largeur NEGATIVE (« emotes@12,214+-23x40 »).
for L, H in ((1, 1), (0, 0), (10, 10), (None, None), (-500, -500)):
    bs = M.blocs(L, H)
    for b in [bs[i] for i in range(1, len(bs) + 1)]:
        if b.l <= 0 or b.h <= 0:
            e.append(f"ecran {L}x{H} : le bloc « {b.nom} » a une dimension nulle ou negative ({b.l}x{b.h})")
            break
        if b.x < 0 or b.y < 0:
            e.append(f"ecran {L}x{H} : le bloc « {b.nom} » sort par le haut ou la gauche")
            break

# --- BALAYAGE FIN (toutes les largeurs de 360 a 2000 par pas de 20) -----------------------------
mauvais = 0
for L in range(360, 2001, 20):
    for H in (480, 720, 1080):
        if noms(M.chevauchements(M.blocs(L, H))) or noms(M.hors(M.blocs(L, H), L, H)):
            mauvais += 1
if mauvais:
    e.append(f"{mauvais} formats en echec sur le balayage fin (largeurs 360-2000)")

# --- LA RANGEE DE BOUTONS DU HUB EST UNE ZONE RESERVEE ------------------------------------------
# Mesure a l'ecran : sur un ecran etroit, la pile centrale passait DERRIERE MENU / REGLES / SON.
for L, H, nom in FORMATS:
    bs = M.blocs(L, H)
    hub = M.trouver(bs, "boutonsHub")
    if hub is None:
        e.append("la rangee de boutons du hub n'est pas prise en compte")
        break
    for autre in ("chrono", "score", "lieu", "progression", "fiche", "lecture", "emotes"):
        b = M.trouver(bs, autre)
        if b and b.visible and b.x < hub.x + hub.l and hub.x < b.x + b.l and b.y < hub.y + hub.h and hub.y < b.y + b.h:
            e.append(f"{nom} ({L}x{H}) : « {autre} » passe derriere les boutons du hub")

# --- LE CLIENT DOIT RESPECTER LE SACRIFICE ------------------------------------------------------
# Mesure a l'ecran : la boucle d'etat remettait le bloc retire a Visible = true juste apres.
if "hud.misePermet" not in C:
    e.append("client : rien ne retient ce que la mise en page a retire")
if "hud.mesCartesTexte.Visible = hud.misePermet.mesCartes ~= false" not in C:
    e.append("client : le bloc sacrifie revient a chaque rafraichissement d'etat")
if "hud.ficheAdversaire.Visible = hud.misePermet.fiche ~= false" not in C:
    e.append("client : la fiche sacrifiee revient a chaque rafraichissement d'etat")

# --- REGLES DE SACRIFICE ------------------------------------------------------------------------
# Sur un ecran etroit, on RETIRE l'information la moins vitale plutot que de la superposer.
etroit = M.blocs(600, 900)
if M.trouver(etroit, "mesCartes").visible is not False:
    e.append("ecran etroit : son propre historique devrait ceder la place (on le connait deja)")
if M.trouver(etroit, "lecture").visible is not True:
    e.append("ecran etroit : la lecture de l'ADVERSAIRE doit rester (elle decide des poses)")
court = M.blocs(1280, 500)
if M.trouver(court, "lieu").visible is not False or M.trouver(court, "progression").visible is not False:
    e.append("ecran court : le lieu et la progression devraient ceder la place")
if M.trouver(court, "chrono").visible is not True:
    e.append("ecran court : le chrono doit rester")
large = M.blocs(1920, 1080)
for nom in ("lieu", "progression", "fiche", "mesCartes"):
    if M.trouver(large, nom).visible is not True:
        e.append(f"grand ecran : « {nom} » ne devrait PAS etre sacrifie")

# --- ECRAN DE FIN DE PARTIE ---------------------------------------------------------------------
# Le defaut mesure a l'ecran (capture du 2026-09-20) : « Rejouer » etait pose a un offset ECRIT A
# LA MAIN sous le recapitulatif. A chaque bloc ajoute en dessous il repassait par-dessus — d'abord
# le resume partageable, puis la main de cartes. On balaie donc les memes formats.
for L, H, nom in FORMATS:
    fins = M.fin(L, H)
    ch = noms(M.chevauchements(fins))
    if ch:
        e.append(f"fin de partie {nom} ({L}x{H}) : blocs qui se recouvrent -> {', '.join(ch)}")
    hors = noms(M.hors(fins, L, H))
    if hors:
        e.append(f"fin de partie {nom} ({L}x{H}) : blocs hors de l'ecran -> {', '.join(hors)}")
    # Le resultat et le bouton pour repartir ne disparaissent jamais : sans eux l'ecran est mort.
    for vital in ("fintitre", "finrejouer"):
        b = M.trouver(fins, vital)
        if b is None or b.visible is not True:
            e.append(f"fin de partie {nom} ({L}x{H}) : le bloc vital « {vital} » manque")
    # Le resume partageable est la SEULE chose qu'on emporte hors du jeu : il se sacrifie APRES le
    # recapitulatif, jamais avant.
    rec, par = M.trouver(fins, "finrecap"), M.trouver(fins, "finpartage")
    if par.visible is not True and rec.visible is True:
        e.append(f"fin de partie {nom} ({L}x{H}) : le resume est retire alors que le recap reste")

# balayage large : aucun format ne doit produire un recouvrement sur l'ecran de fin
for L in range(320, 2001, 97):
    for H in range(240, 1441, 83):
        ch = noms(M.chevauchements(M.fin(L, H)))
        if ch:
            e.append(f"fin de partie ({L}x{H}) : recouvrement -> {', '.join(ch)}")
            break

# La pile de fin ne doit jamais recouvrir la main de cartes ni les boutons du hub : c'est
# exactement ce que la capture a montre.
for L, H, nom in FORMATS:
    fins = M.fin(L, H)
    rej, main = M.trouver(fins, "finrejouer"), M.trouver(fins, "main")
    # La main de cartes est RETIREE sur l'ecran de fin (ces cartes ne se posent plus) : c'est ce
    # qui rend la place a la pile. Si elle revenait visible, « Rejouer » retomberait dessus.
    if main.visible is not False:
        e.append(f"fin de partie {nom} ({L}x{H}) : la main de cartes devrait etre retiree")
    if rej.y + rej.h > H:
        e.append(f"fin de partie {nom} ({L}x{H}) : « Rejouer » sort par le bas de l'ecran")
    if rej.y < M.HAUT_BOUTONS:
        e.append(f"fin de partie {nom} ({L}x{H}) : la pile de fin remonte sous les boutons du hub")

# Branchement : le client applique bien cette mise en page, et ne replace plus rien a la main.
if "bottom.Visible = not jeSuisSpectateur and s.result == nil" not in C:
    e.append("client : la main de cartes reste affichee sur l'ecran de fin")
# Les blocs qui servent a conduire le duel disparaissent avec la partie ; les emotes restent.
for ligne in ('hud.lectureCadre.Visible = enJeu', 'hud.pingLabel.Visible = enJeu',
              'hud.mesCartesTexte.Visible = enJeu'):
    if ligne not in C:
        e.append("client : bloc de duel encore affiche sur l'ecran de fin -> " + ligne)
if "emotes" not in str([b.nom for b in M.fin(1280, 720).values()]):
    e.append("la barre d'emotes n'est pas protegee sur l'ecran de fin")
# Le bandeau de partie (« MORT SUBITE », preavis de fin) restait en travers de l'ecran de fin :
# les branches exigeaient toutes « pas de resultat », mais aucune ne le MASQUAIT a la fin.
if "if s.result then" not in C or "banniere.Visible = false" + chr(10) + chr(9) + "elseif preavis then" not in C:
    e.append("client : le bandeau de partie n'est pas efface quand la partie se termine")
if "Mise.fin(" not in C:
    e.append("client : l'ecran de fin n'utilise pas la mise en page calculee")
for objet in ('poser(restart, Mise.trouver(fins, "finrejouer"))',
              'poser(hud.partageCadre, Mise.trouver(fins, "finpartage"))',
              'poser(hud.bilanCadre, Mise.trouver(fins, "finrecap"))'):
    if objet not in C:
        e.append("client : bloc de fin non pose par la mise en page -> " + objet)

# --- LA RANGEE DE BOUTONS DU HUB RESTE RESPECTEE ------------------------------------------------
for L, H, _ in FORMATS:
    lecture = M.trouver(M.blocs(L, H), "lecture")
    if lecture.y < M.HAUT_BOUTONS:
        e.append(f"({L}x{H}) : la lecture remonte sous les boutons MENU / REGLES / SON")
if "local HAUT_BOUTONS = 64" not in C and "Mise.HAUT_BOUTONS" not in C:
    e.append("client : la hauteur reservee aux boutons n'est plus partagee")

# --- BRANCHEMENT --------------------------------------------------------------------------------
if 'item("ModuleScript", "Mise"' not in B:
    e.append("build : Mise non embarque")
if 'WaitForChild("Mise")' not in C:
    e.append("client : module Mise non requis")
if "Mise.blocs(" not in C:
    e.append("client : la mise en page n'est pas calculee")
if "appliquerMise" not in C:
    e.append("client : aucune application des blocs a l'ecran")
if "ViewportSize" not in zone(C, "local function appliquerMise"):
    e.append("client : la mise en page ne suit pas la taille de l'ecran")
if "GetPropertyChangedSignal(\"ViewportSize\")" not in C:
    e.append("client : un redimensionnement de fenetre ne recalculerait rien")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : aucun bloc n'en recouvre un autre, sur 14 formats nommes et 250 formats balayes")
sys.exit(1 if e else 0)
