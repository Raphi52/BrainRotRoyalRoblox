# -*- coding: utf-8 -*-
"""APPARIEMENT PAR NIVEAU DE JEU (src/server/Matchmaking.lua).

Le defaut corrige : la file etait « premier arrive, premier servi ». Un joueur a 3000 trophees
avec un deck de niveau 5 pouvait tomber sur un debutant a 0 trophee au niveau 1 (+40 % de PV et de
degats sur chaque carte en face) : la partie etait jouee d'avance pour les DEUX.

1) Les regles PURES sont EXECUTEES (lupa) : ecart tolere, elargissement par l'attente, choix du
   meilleur adversaire, filet de securite du robot.
2) Le branchement est lu : la file ECRIT trophees et niveau, JOUER les fournit, le tour d'appariement
   passe l'heure courante.
"""
import re, sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
MM = (R / "src/server/Matchmaking.lua").read_text(encoding="utf-8")
GS = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(MM)
L = lua.eval
liste = L("function(...) local t = {} for i, v in ipairs({...}) do t[i] = v end return t end")

def entree(cle, t, tr=None, nv=None, code=None):
    return L("function(cle, t, tr, nv, code) return { cle = cle, valeur = { t = t, tr = tr, nv = nv, code = code } } end")(cle, t, tr, nv, code)

def val(tr=None, nv=None, t=0):
    return L("function(t, tr, nv) return { t = t, tr = tr, nv = nv } end")(t, tr, nv)

# --- ECARTS TOLERES -----------------------------------------------------------------------------
if M.ecartTropheesTolere(0) != 150:
    e.append(f"ecart de depart attendu 150, obtenu {M.ecartTropheesTolere(0)}")
if M.ecartTropheesTolere(5) != 150 + 5 * 40:
    e.append("l'ecart ne s'elargit pas avec l'attente")
if M.ecartTropheesTolere(20) != float("inf"):
    e.append("au seuil du robot, l'ecart doit s'ouvrir completement (un humain vaut mieux qu'une machine)")
if M.ecartNiveauTolere(0) != 1 or M.ecartNiveauTolere(12) != 2 or M.ecartNiveauTolere(20) != float("inf"):
    e.append("la tolerance de niveau ne suit pas l'attente")

# --- COMPATIBILITE ------------------------------------------------------------------------------
if M.compatible(val(300, 3), val(400, 3), 0, 0) is not True:
    e.append("100 trophees d'ecart au meme niveau doit passer")
if M.compatible(val(0, 1), val(3000, 5), 0, 0) is not False:
    e.append("debutant contre expert : l'appariement doit etre REFUSE")
if M.compatible(val(300, 1), val(320, 3), 0, 0) is not False:
    e.append("2 niveaux d'ecart doivent etre refuses au depart")
if M.compatible(val(300, 1), val(320, 3), 13, 0) is not True:
    e.append("apres 12 s d'attente, 2 niveaux d'ecart doivent passer")
if M.compatible(val(300, 1), val(320, 5), 13, 0) is not False:
    e.append("4 niveaux d'ecart ne doivent jamais passer avant le seuil du robot")
if M.compatible(val(0, 1), val(3000, 5), 25, 0) is not True:
    e.append("au seuil du robot, tout humain vaut mieux que rien")
# L'attente la PLUS LONGUE des deux profite aux deux.
if M.compatible(val(0, 1), val(600, 1), 0, 12) is not True:
    e.append("l'attente de l'autre doit elargir aussi")
# Donnee manquante : on n'exclut jamais quelqu'un faute d'information.
if M.compatible(val(None, None), val(3000, 5), 0, 0) is not True:
    e.append("une entree sans trophees doit rester appariable")

# --- CHOIX DE L'ADVERSAIRE ----------------------------------------------------------------------
ch = M.choisirAdversaire
# Le plus ancien mene toujours la paire (regle anti double reservation, inchangee).
if ch(liste(entree("1", 10, 300, 2), entree("2", 11, 320, 2)), "2", 11) is not None:
    e.append("le second ne doit pas mener la paire")
# A trois candidats, on prend le plus PROCHE en trophees, pas le premier de la file.
choix = ch(liste(entree("1", 10, 300, 2), entree("2", 11, 1200, 2), entree("3", 12, 330, 2)), "1", 12)
if choix != "3":
    e.append(f"l'adversaire le plus proche en trophees doit etre choisi, obtenu {choix}")
# Aucun candidat compatible : on n'apparie pas (la file elargira toute seule).
if ch(liste(entree("1", 10, 0, 1), entree("2", 11, 3000, 5)), "1", 11) is not None:
    e.append("un duel injouable ne doit PAS etre forme")
# Mais apres l'attente, il se forme plutot que de donner le robot.
if ch(liste(entree("1", 0, 0, 1), entree("2", 1, 3000, 5)), "1", 25) != "2":
    e.append("apres une longue attente, le duel doit se former quand meme")
# Sans horodatage, l'ancien comportement reste (compatibilite).
if ch(liste(entree("1", 10), entree("2", 11)), "1") != "2":
    e.append("sans heure fournie, l'appariement d'origine doit encore marcher")
# Une entree deja prise reste ignoree.
if ch(liste(entree("0", 5, 300, 2, "X"), entree("1", 10, 300, 2), entree("2", 11, 310, 2)), "1", 11) != "2":
    e.append("une entree deja prise doit etre ignoree")

# --- BRANCHEMENT --------------------------------------------------------------------------------
# L'entree de file porte le niveau de jeu. Elle porte AUSSI, depuis l'evitement du duel repete,
# la liste des adversaires recents : on verifie les CHAMPS, pas la mise en page de l'appel.
_file = MM.split("etat.entree = {")
_bloc = _file[1][:200] if len(_file) > 1 else ""
if "SetAsync(tostring(player.UserId), etat.entree" not in MM:
    _bloc = ""
if not ("tr = carteJoueur.tr" in _bloc and "nv = carteJoueur.nv" in _bloc):
    e.append("la file n'ecrit pas le niveau de jeu du joueur")
if "M.choisirAdversaire(entrees, moi, os.time())" not in MM:
    e.append("le tour d'appariement ne passe pas l'heure courante (aucun elargissement possible)")
# La signature porte aussi le choix « attendre un humain » : on verifie que le PROFIL y est.
if "function M.entrer(player, robot, profil" not in MM:
    e.append("la file n'accepte pas le profil de niveau de jeu")
if not re.search(r"Matchmaking\.entrer\(player, rejoindre, function\(p\)", GS):
    e.append("JOUER ne fournit pas le profil de niveau de jeu")
if "Economie.tropheesDe(p)" not in GS or "Economie.niveauMoyen(Economie.niveaux(p)" not in GS:
    e.append("le profil envoye a la file n'est pas construit depuis l'economie")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : la file apparie par trophees et par niveau, et s'elargit plutot que de laisser seul")
sys.exit(1 if e else 0)
