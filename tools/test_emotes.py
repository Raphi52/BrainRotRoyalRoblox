# -*- coding: utf-8 -*-
"""EMOTES RAPIDES : liste FERMEE partagee, delai, bulle qui SURVIT au Roi, salut d'ouverture.

Ce banc remplace la version d'origine, qui lisait la liste d'emotes ECRITE EN DUR dans le serveur.
Elle l'etait aussi dans le client : deux sources de verite pour la meme chose, condamnees a
diverger (un bouton que le serveur refuse, ou une emote inatteignable). Les deux lisent desormais
src/shared/Emotes.lua, et c'est LUI qui est execute ici.

Deux defauts de l'audit traites en plus :
 - la bulle mourait avec la tour du Roi, exactement au moment ou l'on veut dire « bien joue » ;
 - le duel commencait sans un mot : aucun salut possible entre deux inconnus.
"""
import re, sys, pathlib
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import zone  # decoupe par CONTENU (voir tools/bancs.py)
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
EM = (ROOT / "src/shared/Emotes.lua").read_text(encoding="utf-8")
S = (ROOT / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (ROOT / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (ROOT / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(EM)
liste = [M.LISTE[i] for i in range(1, len(M.LISTE) + 1)]

# --- LISTE FERMEE, UNE SEULE SOURCE -------------------------------------------------------------
ids = [x.id for x in liste]
if len(set(ids)) != len(ids):
    e.append("deux emotes portent le meme identifiant")
for x in liste:
    if not x.libelle or not x.texte:
        e.append(f"emote sans libelle ou sans texte : {x.id}")
if M.connue("inconnue") or M.connue("") or M.texte(42) is not None:
    e.append("seules les emotes de la liste doivent etre connues (aucun texte libre)")
if M.SALUT not in ids:
    e.append("le salut doit faire partie de la liste")

# --- DELAI (comportement d'origine, conserve) ---------------------------------------------------
d = M.DELAI
for args, att in [((ids[0], None, 10), True), (("inconnue", None, 10), False), ((42, None, 10), False),
                  ((ids[1], 10, 10 + d - 0.5), False), ((ids[1], 10, 10 + d), True)]:
    if M.autorisee(*args) != att:
        e.append(f"autorisee{args} -> {M.autorisee(*args)}, attendu {att}")

# --- LA BULLE SURVIT AU ROI ---------------------------------------------------------------------
if M.ancrePermise(True, False) is not True:
    e.append("ROI DETRUIT : l'emote doit rester possible (c'est le moment du « bien joue »)")
if M.ancrePermise(False, True) is not True:
    e.append("sans ancre mais avec la tour, l'emote doit passer")
if M.ancrePermise(False, False) is not False:
    e.append("sans rien ou l'accrocher, on n'affiche pas")
anc = re.search(r"local function ancreEmote\(camp\).*?\nend\n", S, re.S)
if not anc:
    e.append("serveur : aucune ancre d'emote (la bulle mourrait avec le Roi)")
else:
    if "Transparency = 1" not in anc.group(0):
        e.append("serveur : l'ancre doit etre invisible")
    if "Vector3.new(0, 10, z)" not in anc.group(0):
        e.append("serveur : sans Roi, l'ancre n'a aucune position de repli")
aff = re.search(r"local function afficherEmote.*?\nend\n", S, re.S)
if not aff or "ancreEmote(camp)" not in aff.group(0):
    e.append("serveur : la bulle n'est pas posee sur l'ancre")
if aff and "roi.part" in aff.group(0):
    e.append("serveur : la bulle depend encore de la tour du Roi")
if "ancresEmote = {}" not in zone(S, "local function resetMatch()"):
    e.append("serveur : les ancres de la partie precedente survivraient a la reconstruction de l'arene")

# --- SALUT D'OUVERTURE --------------------------------------------------------------------------
if M.inviteSalut(1, True, False) is None:
    e.append("au debut, face a un humain, le jeu doit inviter a saluer")
if M.inviteSalut(1, False, False) is not None:
    e.append("on ne propose pas de saluer une machine")
if M.inviteSalut(1, True, True) is not None:
    e.append("deja salue : on n'invite plus (ce serait du harcelement)")
if M.inviteSalut(M.FENETRE_SALUT + 1, True, False) is not None:
    e.append("passe la fenetre, plus aucune invitation")
if M.FENETRE_SALUT <= 2 or M.FENETRE_SALUT > 30:
    e.append("la fenetre de salut doit laisser le temps de cliquer, sans s'installer")
if "Emotes.inviteSalut(MATCH_TIME - timeLeft" not in S:
    e.append("serveur : l'invitation n'est pas calculee sur le temps de jeu")
if "saluts[player] = true" not in S:
    e.append("serveur : saluer ne coupe pas l'invitation")

# --- BRANCHEMENT (comportement d'origine, conserve) ---------------------------------------------
if not re.search(r'EmoteEvent\.Name = "Emote"', S):
    e.append("serveur : RemoteEvent Emote absente")
h = re.search(r"EmoteEvent\.OnServerEvent:Connect\(function\(player, id\).*?\nend\)", S, re.S)
if not h or "equipeDe[player]" not in h.group(0) or "emoteAutorisee" not in h.group(0):
    e.append("serveur : le gestionnaire ne verifie pas camp + delai")
if "Emotes.texte(id)" not in S:
    e.append("serveur : le texte affiche ne vient pas de la liste partagee")
if re.search(r"^local EMOTES = \{", S, re.M):
    e.append("serveur : la liste en dur est encore la (deux sources de verite)")
if 'item("ModuleScript", "Emotes"' not in B:
    e.append("build : Emotes non embarque")
if "for _, e in ipairs(Emotes.LISTE) do" not in C:
    e.append("client : les boutons ne viennent pas de la liste partagee")
if "hud.cliquerEmote(e.id)" not in C or "EmoteEvent:FireServer(id)" not in C:
    e.append("client : aucun bouton n'envoie d'emote")
if "emotesBarre.Visible = not s.spectateur" not in C:
    e.append("client : les emotes ne sont pas cachees au spectateur")
if "#Emotes.LISTE + 1" not in C:
    e.append("client : la largeur de la barre est en dur (un ajout ferait sortir le dernier bouton)")
if "s.inviteSalut" not in C or "inviteSalutVue" not in C:
    e.append("client : l'invitation a saluer n'est pas jouee, ou serait repetee")

# DELAI ANNONCE. Defaut mesure le 2026-09-21 : le serveur refusait une emote trop rapprochee EN
# SILENCE — aucun retour, aucun son, aucune bulle. Le joueur voyait un bouton sans effet et
# re-cliquait, en croyant le jeu casse. La regle du delai vivait cote serveur seulement.
if M.resteAvant(None, 100) != 0:
    e.append("aucune emote envoyee : rien a attendre")
if M.resteAvant(100, 100) != M.DELAI:
    e.append("juste apres une emote, il reste le delai entier")
if abs(M.resteAvant(100, 101) - (M.DELAI - 1)) > 1e-9:
    e.append("le reste doit decroitre avec le temps")
if M.resteAvant(100, 100 + M.DELAI) != 0:
    e.append("au bout du delai, l'emote redevient possible")
if M.resteAvant(100, 999) != 0:
    e.append("bien plus tard non plus, rien a attendre")
# Arrondi au SUPERIEUR : annoncer « 0 s » alors que le bouton refuse encore serait pire que rien.
if M.texteAttente(0.2) != "Encore 1 s avant la prochaine emote":
    e.append("le texte d'attente doit arrondir au superieur")
if M.texteAttente(0) != "":
    e.append("aucun texte quand il n'y a rien a attendre")
if "Emotes.autorisee(id, hud.emote.derniere, os.clock())" not in C:
    e.append("client : le bouton n'applique pas la regle partagee avant d'envoyer")
if "Emotes.texteAttente(Emotes.resteAvant(hud.emote.derniere, os.clock()))" not in C:
    e.append("client : le refus n'est pas annonce au joueur")
if "hud.emote.derniere = os.clock()" not in C:
    e.append("client : l'instant de la derniere emote n'est pas garde")
# Le refus doit se VOIR avant le clic, pas seulement apres.
if "function hud.majEmotes()" not in C or "hud.majEmotes()" not in C:
    e.append("client : les boutons ne s'eteignent pas pendant le repos")
if "b.AutoButtonColor = reste <= 0" not in C:
    e.append("client : un bouton eteint reagit encore au survol, il a l'air actif")
# Le serveur reste l'AUTORITE : le client ne fait qu'eviter un aller-retour inutile.
if "Emotes.autorisee(id, derniere, maintenant)" not in S:
    e.append("serveur : il ne verifie plus le delai lui-meme")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : une seule liste d'emotes, une bulle qui survit au Roi, et un duel qui commence par un bonjour")
sys.exit(1 if e else 0)
