# -*- coding: utf-8 -*-
"""VIE DANS LA FILE D'ATTENTE (src/server/Matchmaking.lua + branchement).

Deux manques de l'audit :
 1. l'attente etait MUETTE sur le monde : rien ne disait si d'autres joueurs cherchaient aussi, et
    une file vide ressemble a un jeu mort ;
 2. changer de deck pendant la recherche laissait dans la file une entree PERIMEE — le joueur
    etait apparie sur le niveau d'un deck qu'il n'emmene plus.

1) Les regles PURES sont EXECUTEES (lupa).
2) Le branchement est lu : le serveur compte et met a jour, le hub affiche et garde le deck
   accessible pendant la recherche.
"""
import sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
MM = (R / "src/server/Matchmaking.lua").read_text(encoding="utf-8")
GS = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
HUB = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(MM)
L = lua.eval
liste = L("function(...) local t = {} for i, v in ipairs({...}) do t[i] = v end return t end")
def entree(cle, code=None):
    return L("function(cle, code) return { cle = cle, valeur = { t = 1, tr = 300, nv = 2, code = code } } end")(cle, code)
def valeur(t=10, code=None):
    return L("function(t, code) return { t = t, tr = 111, nv = 1, code = code, adv = { ['9'] = 5 } } end")(t, code)
def profil(tr=900, nv=4):
    return L("function(tr, nv) return { tr = tr, nv = nv, adv = { ['7'] = 42 } } end")(tr, nv)

# --- COMPTER CEUX QUI CHERCHENT -----------------------------------------------------------------
if M.compterLibres(None) != 0 or M.compterLibres(liste()) != 0:
    e.append("file vide : zero joueur en recherche")
if M.compterLibres(liste(entree("1"), entree("2"))) != 2:
    e.append("deux entrees libres = deux joueurs en recherche")
if M.compterLibres(liste(entree("1"), entree("2", "CODE"))) != 1:
    e.append("une entree deja PRISE est un match en formation, pas quelqu'un qui attend")
if M.CACHE_FILE <= 0:
    e.append("sans cache, le hub epuiserait le quota de lectures de MemoryStore")

# --- CHANGER DE DECK SANS PERDRE SA PLACE -------------------------------------------------------
v = valeur(t=10)
n = M.majValeur(v, profil(tr=900, nv=4))
if n is None:
    e.append("une entree libre doit pouvoir etre mise a jour")
else:
    if n.t != 10:
        e.append("LA PLACE DANS LA FILE doit etre conservee (meme horodatage)")
    if n.nv != 4 or n.tr != 900:
        e.append("le nouveau niveau de deck doit remplacer l'ancien")
    if n.adv is None or n.adv["7"] != 42:
        e.append("la memoire des adversaires recents doit suivre")
    if n.code is not None:
        e.append("une entree mise a jour ne doit jamais porter un code de match")
# Une entree DEJA PRISE ne se touche pas : ce serait casser un match en train de se former.
if M.majValeur(valeur(code="ABC"), profil()) is not None:
    e.append("une entree deja prise ne doit PAS etre modifiee (match en formation)")
if M.majValeur(None, profil()) is not None:
    e.append("sans entree, rien a mettre a jour")
# Profil manquant : on n'invente pas de niveau, on vide les champs plutot que de mentir.
vide = M.majValeur(valeur(), None)
if vide is None or vide.nv is not None:
    e.append("sans profil, aucun niveau ne doit etre invente")

# --- BRANCHEMENT SERVEUR ------------------------------------------------------------------------
if "function M.majProfil(player, profil)" not in MM:
    e.append("matchmaking : aucune mise a jour d'entree en cours de file")
bloc = MM.split("function M.majProfil")[1].split("function M.compterFile")[0]
if 'enAttente[player].etat == "attente"' not in bloc:
    e.append("matchmaking : on mettrait a jour l'entree d'un joueur qui n'attend plus")
if "UpdateAsync(tostring(player.UserId)" not in bloc:
    e.append("matchmaking : la mise a jour n'est pas atomique (course avec un autre serveur)")
if "function M.compterFile" not in MM or "cacheFileA" not in MM:
    e.append("matchmaking : le comptage n'est pas mis en cache")
if "Matchmaking.majProfil(player" not in GS:
    e.append("serveur : changer de deck ne met pas l'entree de file a jour")
if "enFile = Matchmaking.actif() and Matchmaking.compterFile() or 0" not in GS:
    e.append("serveur : le nombre de joueurs en recherche n'est pas envoye")
if "fileMiseAJour = enFile" not in GS:
    e.append("serveur : le hub ne sait pas si le nouveau deck part avec le joueur")

# --- BRANCHEMENT HUB ----------------------------------------------------------------------------
if "joueurs en recherche" not in HUB:
    e.append("hub : le nombre de joueurs en recherche n'est pas affiche")
if "tu es seul en recherche" not in HUB:
    e.append("hub : etre seul doit se dire autrement que « 1 joueur »")
if "etat, enFile = r2.etat, r2.enFile or 0" not in HUB:
    e.append("hub : le compte n'est pas lu dans la reponse du serveur")
if "barreOnglets.Visible = true" not in HUB:
    e.append("hub : les onglets (donc le DECK) seraient inaccessibles pendant la recherche")
if "r.fileMiseAJour" not in HUB:
    e.append("hub : rien ne dit au joueur que son nouveau deck part avec lui")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : on sait qui cherche avec soi, et changer de deck ne coute plus sa place")
sys.exit(1 if e else 0)
