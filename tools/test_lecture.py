# -*- coding: utf-8 -*-
"""LIRE LE DUEL (src/shared/Lecture.lua) : elixir adverse estime, cartes deja vues, alerte de tour.

Trois manques de l'audit PvP : on ne savait pas si l'adversaire pouvait encore repondre, on ne
gardait aucune trace de ce qu'il avait pose, et une tour tombait pendant qu'on regardait l'autre voie.

1) Les regles PURES sont EXECUTEES (lupa).
2) Le branchement est lu : le serveur compte la depense VUE et les coups recents, envoie les trois
   informations, le client les affiche, et build.py embarque le module.
"""
import re, sys, pathlib
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import zone  # decoupe par CONTENU (voir tools/bancs.py)
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
LE = (R / "src/shared/Lecture.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(LE)
L = lua.eval
def tbl(items):
    t = L("function() return {} end")()
    for i, v in enumerate(items, 1):
        t[i] = v
    return t
def carte(id, t):
    return L("function(id, t) return { id = id, t = t } end")(id, t)
def tour(vivante, pv, pvMax, recents, x, roi=False):
    return L("function(v, pv, m, d, x, r) return { vivante = v, pv = pv, pvMax = m, degatsRecents = d, x = x, roi = r } end")(vivante, pv, pvMax, recents, x, roi)
def coup(t, montant):
    return L("function(t, m) return { t = t, montant = m } end")(t, montant)

# --- ELIXIR ESTIME ------------------------------------------------------------------------------
if M.elixirEstime(5, 0, 0) != 5:
    e.append("au coup d'envoi, l'estimation doit valoir l'elixir de depart")
if M.elixirEstime(5, 2.8, 3) != 4:
    e.append("l'estimation doit retirer ce qu'on l'a VU depenser")
if M.elixirEstime(5, 0, 9) != 0:
    e.append("l'estimation ne descend jamais sous zero")
if M.elixirEstime(5, 50, 0) != 10:
    e.append("l'estimation ne depasse jamais le plafond du jeu")
if M.elixirEstime(5, 1.9, 0) != 6:
    e.append("l'estimation s'arrondit VERS LE BAS (on ne promet que le certain)")
if M.peutRepondre(4, 4) is not True or M.peutRepondre(3, 4) is not False:
    e.append("peutRepondre ne compare pas l'estimation au cout")

# --- CARTES DEJA VUES ---------------------------------------------------------------------------
jouees = tbl([carte("A", 1), carte("B", 2), carte("C", 3), carte("D", 4), carte("E", 5)])
d = M.dernieresCartes(jouees)
if len(d) != 4 or d[1].id != "E" or d[4].id != "B":
    e.append("les dernieres cartes doivent sortir en commencant par la plus recente")
if len(M.dernieresCartes(tbl([]))) != 0:
    e.append("aucune carte posee : la liste doit etre vide")
if M.dejaVue(tbl([carte("A", 1), carte("A", 9), carte("B", 2)]), "A") != 2:
    e.append("dejaVue doit compter les passages d'une carte")
if M.dejaVue(jouees, "Z") != 0:
    e.append("une carte jamais vue doit compter zero")

# --- ALERTE DE TOUR -----------------------------------------------------------------------------
if M.alerteTour(True, 1000, 1000, 0) is not None:
    e.append("une tour intacte et tranquille ne doit rien declencher")
if M.alerteTour(True, 400, 1000, 0) != "attention":
    e.append("une tour a moitie entamee doit passer en attention")
if M.alerteTour(True, 200, 1000, 0) != "critique":
    e.append("une tour au quart de vie doit passer en critique")
if M.alerteTour(True, 900, 1000, 150) != "critique":
    e.append("une tour pleine qui encaisse 15 % en 3 s doit passer en critique")
if M.alerteTour(True, 900, 1000, 20) != "attention":
    e.append("une tour pleine qui prend des coups doit au moins signaler")
if M.alerteTour(False, 0, 1000, 999) is not None:
    e.append("une tour deja tombee ne doit plus alerter")
# La PIRE alerte gagne, et elle nomme le cote a regarder.
niveau, cote = M.alerteCamp(tbl([tour(True, 900, 1000, 0, -17), tour(True, 200, 1000, 0, 17), tour(True, 5000, 5000, 0, 0, True)]))
if niveau != "critique" or cote != "droite":
    e.append(f"l'alerte doit nommer la tour la plus en danger, obtenu {niveau}/{cote}")
niveau, cote = M.alerteCamp(tbl([tour(True, 400, 1000, 0, -17)]))
if niveau != "attention" or cote != "gauche":
    e.append("le cote gauche doit etre nomme")
niveau, cote = M.alerteCamp(tbl([tour(True, 1000, 5000, 0, 0, True)]))
if cote != "roi":
    e.append("la tour du Roi doit etre nommee comme telle")
if M.alerteCamp(tbl([tour(True, 1000, 1000, 0, -17)])) is not None:
    e.append("aucun danger : aucune alerte")
if "VA TOMBER" not in M.texteAlerte("critique", "gauche") or "GAUCHE" not in M.texteAlerte("critique", "gauche"):
    e.append("le texte d'alerte doit dire l'urgence ET le cote")
if M.texteAlerte(None, "gauche") is not None:
    e.append("sans niveau, aucun texte")

# --- DEGATS RECENTS : la liste ne grossit jamais ------------------------------------------------
total, restants = M.degatsRecents(tbl([coup(0, 100), coup(9, 50), coup(10, 25)]), 10, 3)
if total != 75:
    e.append(f"seuls les coups de la fenetre comptent, obtenu {total}")
if len(restants) != 2:
    e.append("les coups trop vieux doivent etre jetes de la liste")

# --- BRANCHEMENT SERVEUR ------------------------------------------------------------------------
if 'WaitForChild("Lecture")' not in S:
    e.append("serveur : module Lecture non requis")
if 'item("ModuleScript", "Lecture"' not in B:
    e.append("build : Lecture non embarque (serveur ET client resteraient bloques)")
if "t.depenseVue = (t.depenseVue or 0) + card.cost" not in S:
    e.append("serveur : la depense VUE n'est pas comptee")
if 'table.insert(t.jouees, { id = card.id, t = horloge })' not in S:
    e.append("serveur : les cartes posees ne sont pas memorisees")
if "t.regenCumulee = (t.regenCumulee or 0) + (t.elixir - avant)" not in S:
    e.append("serveur : la regeneration vue n'est pas cumulee (l'estimation derive)")
if "table.insert(target.coups, { t = horloge, montant = amount })" not in S:
    e.append("serveur : les coups recents sur les tours ne sont pas comptes")
if "tw.coups = restants" not in S:
    e.append("serveur : la liste des coups n'est jamais nettoyee (elle grossirait sans fin)")
# SON PROPRE CYCLE : le joueur voyait ce que l'adversaire avait pose, mais pas ce qu'il avait joue
# lui-meme — alors que compter SON cycle est ce qui decide de la prochaine poussee.
if "mesCartes = lectureCartes(monCamp)" not in S:
    e.append("serveur : l'historique de SES propres cartes n'est pas envoye")
if "hud.mesCartesTexte" not in C or "Tu as pose" not in C:
    e.append("client : ses propres cartes jouees ne sont pas affichees")
if "s.mesCartes" not in C:
    e.append("client : la liste affichee ne vient pas du serveur")
if "hud.mesCartesTexte.Visible = false" not in C:
    e.append("client : un spectateur verrait un « tu as pose » qui ne le concerne pas")
# Les deux listes doivent rester DISTINCTES : meme fonction, deux camps.
# On compte les LITTERAUX affiches, pas les mentions en commentaire.
if C.count('("Tu as pose :') != 1 or C.count('("Il a pose :') != 1:
    e.append("client : les deux historiques se confondent")

for champ in ("elixirAdverse = lectureElixir(3 - monCamp)", "cartesAdverses = lectureCartes(3 - monCamp)", "alerte = lectureAlerte(monCamp)"):
    if champ not in S:
        e.append("serveur : champ manquant dans l'etat -> " + champ)
if re.search(r"elixirAdverse = t\.elixir", S):
    e.append("serveur : l'elixir adverse serait LU dans son compteur au lieu d'etre estime")

# --- BRANCHEMENT CLIENT -------------------------------------------------------------------------
if "majLecture(s)" not in C:
    e.append("client : la lecture du duel n'est jamais mise a jour")
if "Adversaire : ~" not in C:
    e.append("client : l'elixir adverse n'est pas affiche comme une ESTIMATION")
if "Il a pose" not in C:
    e.append("client : les cartes deja posees ne sont pas affichees")
if "alerteLabel" not in C or "a.texte" not in C:
    e.append("client : aucune alerte de tour a l'ecran")
if "s.spectateur then" not in zone(C, "local function majLecture"):
    e.append("client : le spectateur verrait une lecture qui ne le concerne pas")

# --- PLACE A L'ECRAN : LE PANNEAU NE DOIT PAS PASSER SOUS LES BOUTONS ----------------------------
# Defaut mesure le 2026-09-20 (capture cap-regles-partie.png) : le cadre etait pose en (12, 12),
# exactement la ou le hub dessine MENU et REGLES. L'elixir estime, sa jauge et la premiere ligne de
# « Il a pose : » etaient caches DERRIERE les boutons. Les deux ecrans vivent dans des fichiers
# differents : c'est donc ici, et nulle part ailleurs, que la comparaison peut se faire.
H = (pathlib.Path(__file__).resolve().parent.parent / "src" / "client" / "Hub.client.lua").read_text(encoding="utf-8")
boutons = re.findall(r'bouton\(gui, "(?:MENU|REGLES)", UDim2\.new\(0, \d+, 0, (\d+)\), UDim2\.new\(0, \d+, 0, (\d+)\)', H)
if len(boutons) < 2:
    e.append("hub : la rangee MENU / REGLES n'a pas ete retrouvee (regle de placement aveugle)")
else:
    bas = max(int(h) + int(y) for h, y in boutons)
    m = re.search(r"local HAUT_BOUTONS = (\d+)", C)
    haut = int(m.group(1)) if m else -1
    if haut < bas:
        e.append("client : la lecture du duel (y=%s) passe sous la rangee de boutons (bas=%s)" % (haut, bas))
    if "lectureCadre.Position = UDim2.new(0, 12, 0, HAUT_BOUTONS)" not in C:
        e.append("client : le cadre de lecture n'utilise pas cette hauteur")
    if "UDim2.new(0, 12, 0, HAUT_BOUTONS + 100)" not in C:
        e.append("client : le ping ne suit pas le cadre (il se poserait par-dessus)")

# --- SANTE DES TOURS, LISIBLE -------------------------------------------------------------------
# Defaut mesure le 2026-09-20 : la barre au-dessus d'une tour etait une bande unie qui raccourcit.
# Rien n'y marquait la MOITIE ni le QUART — les seuils qui declenchent les alertes du jeu — et
# aucun chiffre ne disait ou en etait la tour.
seuils = list(M.SEUILS_AFFICHES.values())
if seuils != [M.SEUIL_BAS, M.SEUIL_CRITIQUE]:
    e.append("les traits affiches ne sont pas les seuils REELS de l'alerte : " + repr(seuils))
if M.niveauVie(100, 100) != "sain" or M.niveauVie(60, 100) != "sain":
    e.append("une tour au-dessus de la moitie doit etre saine")
if M.niveauVie(50, 100) != "bas" or M.niveauVie(30, 100) != "bas":
    e.append("a la moitie et en dessous, le niveau doit passer a bas")
if M.niveauVie(25, 100) != "critique" or M.niveauVie(0, 100) != "critique":
    e.append("au quart et en dessous, le niveau doit etre critique")
# Les bornes sont INCLUSIVES, comme dans alerteTour : sinon la barre dirait « sain » a l'instant
# meme ou l'alerte se declenche.
if M.alerteTour(True, 50, 100, 0) is None:
    e.append("incoherence : l'alerte se declenche a la moitie mais la barre ne le montrerait pas")
if M.texteVie(52, 100) != "52 %" or M.texteVie(0, 100) != "0 %" or M.texteVie(100, 100) != "100 %":
    e.append("la part de vie affichee est fausse : " + M.texteVie(52, 100))
if M.texteVie(-10, 100) != "0 %" or M.texteVie(150, 100) != "100 %":
    e.append("la part de vie doit rester entre 0 et 100 %")
if M.texteVie(1, 0) != "0 %":
    e.append("un maximum nul ne doit pas faire de division par zero")
# Trois couleurs distinctes, sinon deux etats se liraient pareil.
couleurs = {tuple(M.teinteVie(n).values()) for n in ("sain", "bas", "critique")}
if len(couleurs) != 3:
    e.append("les trois niveaux de vie doivent se distinguer a l'oeil")
if tuple(M.teinteVie("critique").values())[0] <= tuple(M.teinteVie("critique").values())[1]:
    e.append("le niveau critique doit etre rouge (plus de rouge que de vert)")

# --- BRANCHEMENT : LA BARRE DES TOURS S'EN SERT -------------------------------------------------
if "for _, seuil in ipairs(Lecture.SEUILS_AFFICHES) do" not in S:
    e.append("serveur : les traits de seuil ne sont pas traces sur la barre")
if "Lecture.texteVie(e.hp, e.maxHp)" not in S:
    e.append("serveur : la part de vie n'est pas affichee sur la tour")
if "Lecture.teinteVie(Lecture.niveauVie(e.hp, e.maxHp))" not in S:
    e.append("serveur : le chiffre ne change pas de couleur avec le niveau")
# UN SEUL endroit met la barre a jour : sinon une tour soignee garderait son chiffre rouge.
if S.count("e.fill.Size = UDim2.new(part, 0, 1, 0)") != 1:
    e.append("serveur : la mise a jour de barre n'est pas centralisee dans majBarre")
for appel in ("majBarre(target)", "majBarre(cible)", "majBarre(a)", "majBarre(e)"):
    if appel not in S:
        e.append("serveur : un endroit qui change les points de vie ne rafraichit pas la barre -> " + appel)
# JAUGE EN GEOMETRIE : l'etiquette flottante n'est PAS rendue par CaptureService, donc la barre
# au-dessus de la tour n'est verifiable sur aucune capture. La meme information est posee en parts
# neon devant la tour (rail, remplissage, encoches aux seuils).
if "RemplissageVie" not in S or "RailVie" not in S:
    e.append("serveur : la jauge de vie en geometrie manque (invisible sur capture sans elle)")
if 'orner({ Name = "SeuilVie"' not in S:
    e.append("serveur : les encoches de seuil ne sont pas posees sur la jauge")
if "e.jaugeVie.Color = Color3.fromRGB(c[1], c[2], c[3])" not in S:
    e.append("serveur : la jauge en geometrie ne change pas de couleur avec le niveau")
if "e.jaugeVie.Size = Vector3.new(L, 0.9, 0.7)" not in S:
    e.append("serveur : la jauge en geometrie ne se vide pas")

# Les unites n'ont pas de seuils : quarante barres marquees seraient du bruit.
if "if tour then" not in S:
    e.append("serveur : les seuils seraient traces sur toutes les unites, pas seulement les tours")

# DEJA VUE. Defaut mesure le 2026-09-21 : les quatre dernieres cartes adverses se lisaient toutes
# pareil, alors qu'une carte vue DEUX fois dit que son deck tourne et qu'elle revient vite. Le
# compte existait (Lecture.dejaVue) et n'etait affiche nulle part : personne ne l'appelait.
if M.marqueVue(1) != "":
    e.append("une carte vue une seule fois ne doit porter aucune marque")
if M.marqueVue(0) != "" or M.marqueVue(None) != "":
    e.append("aucune marque quand le compte est absent ou nul")
if M.marqueVue(2) != " x2":
    e.append("une carte vue deux fois doit porter x2")
if M.marqueVue(5) != " x5":
    e.append("la marque doit porter le vrai compte")
# Le compte porte sur TOUT l'historique, sinon « il la rejoue » et « je l'ai vue une fois » se
# confondraient dans les quatre dernieres lignes.
if "Lecture.dejaVue(t.jouees, c.id)" not in S:
    e.append("serveur : le compte des passages ne vient pas de l'historique complet")
if "passagesAdverses = lecturePassages(3 - monCamp)" not in S:
    e.append("serveur : les passages adverses ne partent pas dans l'etat")
if "mesPassages = lecturePassages(monCamp)" not in S:
    e.append("serveur : mes propres passages ne partent pas dans l'etat")
if "Lecture.marqueVue((s.passagesAdverses or {})[i])" not in C:
    e.append("client : la marque n'est pas affichee a cote de la carte adverse")
if "Lecture.marqueVue((s.mesPassages or {})[i])" not in C:
    e.append("client : la marque manque sur mes propres cartes posees")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : elixir adverse estime, cartes vues et alerte de tour, tous branches")
sys.exit(1 if e else 0)
