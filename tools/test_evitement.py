# -*- coding: utf-8 -*-
"""EVITEMENT DU DUEL REPETE (src/server/Matchmaking.lua + memoire du profil).

Le defaut corrige : la file pouvait rendre trois fois de suite le MEME adversaire. Le jeu parait
vide, et quand on vient de perdre, on se croit poursuivi.

La regle tient en une phrase : on evite un adversaire recent TANT QU'UN AUTRE EST DISPONIBLE ;
s'il est le seul, on joue quand meme — un visage connu vaut mieux que le robot.

1) Les regles PURES sont EXECUTEES (lupa).
2) Le branchement est lu : la memoire vit dans le PROFIL (le joueur change de serveur entre deux
   parties), elle est elaguee, recopiee dans l'entree de file, et notee quand le duel se forme.
"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import zone  # decoupe par CONTENU (voir tools/bancs.py)
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
MM = (R / "src/server/Matchmaking.lua").read_text(encoding="utf-8")
ECO = (R / "src/server/Economie.lua").read_text(encoding="utf-8")
GS = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(MM)
L = lua.eval
liste = L("function(...) local t = {} for i, v in ipairs({...}) do t[i] = v end return t end")

def entree(cle, t, tr=None, nv=None, adv=None, code=None):
    f = L("""function(cle, t, tr, nv, code)
      return { cle = cle, valeur = { t = t, tr = tr, nv = nv, code = code, adv = {} } } end""")
    ent = f(cle, t, tr, nv, code)
    for k, v in (adv or {}).items():
        ent.valeur.adv[k] = v
    return ent

# --- MEMOIRE D'UN ADVERSAIRE --------------------------------------------------------------------
v = entree("1", 0, 300, 2, {"7": 1000}).valeur
if M.dejaAffronte(v, "7", 1000) is not True:
    e.append("un adversaire tout juste affronte doit etre reconnu")
if M.dejaAffronte(v, "7", 1000 + M.EVITEMENT) is not True:
    e.append("l'evitement doit tenir jusqu'a sa fenetre complete")
if M.dejaAffronte(v, "7", 1000 + M.EVITEMENT + 1) is not False:
    e.append("passe la fenetre, l'adversaire redevient appariable")
if M.dejaAffronte(v, "8", 1000) is not False:
    e.append("un inconnu ne doit pas etre evite")
if M.dejaAffronte(v, None, 1000) is not False:
    e.append("sans cle, aucune memoire")
if M.dejaAffronte(entree("1", 0).valeur, "7", 1000) is not False:
    e.append("une entree sans memoire ne doit rien evincer")
if M.EVITEMENT < 120:
    e.append("une fenetre trop courte ne changerait rien au ressenti")

# --- CHOIX : L'AUTRE D'ABORD --------------------------------------------------------------------
# Les entrees datent de quelques secondes (t proche de MAINTENANT) : sans cela l'attente simulee
# depasserait le seuil du robot et TOUTES les tolerances s'ouvriraient, ce qui ne testerait rien.
MAINTENANT = 1000
ch = M.choisirAdversaire
# « 2 » est plus proche en trophees, mais on vient de l'affronter : « 3 » doit passer devant.
choix = ch(liste(entree("1", 995, 300, 2, {"2": 998}), entree("2", 996, 305, 2), entree("3", 997, 360, 2)), "1", MAINTENANT)
if choix != "3":
    e.append(f"un adversaire tout juste affronte doit ceder la place a un autre, obtenu {choix}")
# Mais s'il est le SEUL disponible, on joue avec lui plutot que rien.
choix = ch(liste(entree("1", 995, 300, 2, {"2": 998}), entree("2", 996, 305, 2)), "1", MAINTENANT)
if choix != "2":
    e.append("seul candidat : le duel doit se former quand meme (mieux qu'un robot)")
# L'evitement vaut DANS LES DEUX SENS : il suffit que l'autre s'en souvienne.
choix = ch(liste(entree("1", 995, 300, 2), entree("2", 996, 305, 2, {"1": 998}), entree("3", 997, 360, 2)), "1", MAINTENANT)
if choix != "3":
    e.append(f"la memoire de l'ADVERSAIRE doit compter aussi, obtenu {choix}")
# Une fois la fenetre passee, il redevient le meilleur choix (le plus proche en trophees).
choix = ch(liste(entree("1", 995, 300, 2, {"2": 998 - M.EVITEMENT - 10}), entree("2", 996, 305, 2), entree("3", 997, 360, 2)), "1", MAINTENANT)
if choix != "2":
    e.append("apres la fenetre, le plus proche en trophees doit reprendre sa place")
# L'evitement ne passe JAMAIS devant la compatibilite : un duel injouable reste refuse.
choix = ch(liste(entree("1", 995, 300, 1, {"2": 998}), entree("2", 996, 305, 1), entree("3", 997, 330, 5)), "1", MAINTENANT)
if choix != "2":
    e.append(f"un duel injouable ne doit pas etre prefere a un adversaire recent, obtenu {choix}")

# --- BRANCHEMENT : LA MEMOIRE EST DURABLE -------------------------------------------------------
if "function Economie.noterAdversaire" not in ECO or "function Economie.adversairesRecents" not in ECO:
    e.append("economie : aucune memoire d'adversaires")
bloc = ECO.split("function Economie.noterAdversaire")[1].split("function Economie.adversairesRecents")[0]
if "p.adversaires[tostring(autreId)] = maintenant" not in bloc:
    e.append("economie : l'adversaire n'est pas retenu")
if "Economie.MEMOIRE_ADVERSAIRES" not in bloc:
    e.append("economie : la table des adversaires n'est jamais elaguee (elle gonflerait sans fin)")
if "Economie.marquerSale(player)" not in bloc:
    e.append("economie : la memoire ne serait pas sauvegardee, donc perdue au changement de serveur")
if "adversaires = {}" not in ECO:
    e.append("economie : un profil neuf n'a pas de table d'adversaires")
if "adv = Economie.adversairesRecents(p)" not in GS:
    e.append("serveur : la file ne recoit pas les adversaires recents")
if "adv = carteJoueur.adv" not in MM:
    e.append("matchmaking : l'entree de file ne porte pas la memoire")
if "Economie.noterAdversaire(player, autre.UserId)" not in GS:
    e.append("serveur : l'adversaire n'est jamais note quand le duel se forme")
# L'etat part plusieurs fois par seconde : la notation doit etre GARDEE par une comparaison avec
# l'adversaire deja retenu, sinon on ecrit le profil en boucle. Le 2026-09-21, la comparaison est
# passee de l'objet joueur (`~= autre`) a son identifiant — on retenait l'objet, ce qui empechait
# Roblox de liberer les joueurs partis. On verifie donc le FAIT : une garde existe, et elle
# compare les identifiants.
_zone = zone(GS, "local function sendState(player)", "-- SPECTATEUR : aucun camp")
if "Economie.noterAdversaire(player, autre.UserId)" not in _zone:
    e.append("serveur : l'adversaire n'est pas note la ou le duel se forme")
if "vu.UserId ~= autre.UserId" not in _zone:
    e.append("serveur : l'adversaire serait re-note dix fois par seconde (ecriture de profil inutile)")
if _zone.index("vu.UserId ~= autre.UserId") > _zone.index("Economie.noterAdversaire"):
    e.append("serveur : la notation a lieu AVANT la comparaison, donc a chaque etat")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : on ne retombe pas sur la meme personne tant qu'un autre adversaire existe")
sys.exit(1 if e else 0)
