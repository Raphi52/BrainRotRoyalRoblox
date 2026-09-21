# -*- coding: utf-8 -*-
"""QUITTER SES DUELS EN SERIE (src/shared/Abandon.lua).

Le defaut corrige : rien ne decourageait l'abandon. Mene d'une couronne, on partait sans rien
perdre et on relancait une partie dans la seconde ; en face, on gagnait un duel creux. C'est la
plainte la plus banale du PvP, et elle n'avait aucune reponse dans le jeu.

CE QUI EST VOLONTAIREMENT EPARGNE : le PREMIER depart. Une coupure de reseau, un appel, une
urgence ressemblent exactement a un abandon vu du serveur. C'est la REPETITION qu'on sanctionne.

1) Regles PURES executees (lupa) : ce qui compte comme fuite, l'attente qui monte puis plafonne,
   l'oubli au bout de 30 minutes, le pardon d'une partie jouee jusqu'au bout, le message.
2) Branchement lu : module embarque, abandons gardes dans le PROFIL persistant (sinon changer de
   serveur effacerait l'ardoise), file refusee pendant l'attente, et le hub qui le DIT.
"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import zone  # decoupe par CONTENU (voir tools/bancs.py)
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
AB = (R / "src/shared/Abandon.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
E = (R / "src/server/Economie.lua").read_text(encoding="utf-8")
H = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(AB)
T = lua.table_from

# --- CE QUI COMPTE COMME UNE FUITE ---------------------------------------------------------------
if M.compteCommeFuite(True, True, True) is not True:
    e.append("partir volontairement d'un duel en cours contre un humain doit compter")
# Une COUPURE n'est pas un choix : elle est traitee par la reprise, pas par la sanction.
if M.compteCommeFuite(False, True, True) is not False:
    e.append("une coupure reseau ne doit jamais compter comme un abandon")
# Partir d'une partie contre le ROBOT ne lese personne.
if M.compteCommeFuite(True, True, False) is not False:
    e.append("quitter une partie contre le robot ne doit rien couter")
# Quitter une partie DEJA finie (ecran de fin) n'est pas un abandon.
if M.compteCommeFuite(True, False, True) is not False:
    e.append("partir apres la fin de la partie ne doit rien couter")

# --- LE PREMIER DEPART EST GRATUIT ---------------------------------------------------------------
if M.attente(1) != 0:
    e.append("le premier abandon doit rester gratuit (une coupure lui ressemble exactement)")
if M.attente(0) != 0:
    e.append("sans abandon, aucune attente")
# Ensuite cela monte...
if not (M.attente(2) > 0 and M.attente(3) > M.attente(2)):
    e.append("la sanction ne monte pas avec la repetition")
# ... puis PLAFONNE : au-dela on ne corrige plus un comportement, on chasse le joueur.
plafond = M.attente(4)
for n in (5, 12, 100):
    if M.attente(n) != plafond:
        e.append("l'attente doit plafonner : %s abandons donnent %s" % (n, M.attente(n)))
if plafond > 600:
    e.append("le plafond de %s s est une exclusion, pas une correction" % plafond)

# --- LE TEMPS QUI PASSE EFFACE ------------------------------------------------------------------
maintenant = 100000
liste = T([maintenant - 10, maintenant - 20])
if M.compte(liste, maintenant) != 2:
    e.append("les abandons recents doivent etre comptes")
vieux = T([maintenant - M.FENETRE - 1, maintenant - 5])
if M.compte(vieux, maintenant) != 1:
    e.append("un abandon vieux de plus de %s s doit etre oublie" % M.FENETRE)
# La liste ne doit pas grossir indefiniment.
if M.compte(T([maintenant - 9999] * 50), maintenant) != 0:
    e.append("les vieux abandons doivent etre purges, pas accumules")

# --- L'ATTENTE COURT DEPUIS LE DERNIER DEPART ----------------------------------------------------
apres_un = M.noter(T([]), maintenant)
if M.reste(apres_un, maintenant) != 0 or M.autorise(apres_un, maintenant) is not True:
    e.append("apres UN abandon, le joueur doit pouvoir rejouer tout de suite")
apres_deux = M.noter(apres_un, maintenant)
reste = M.reste(apres_deux, maintenant)
if reste <= 0:
    e.append("apres DEUX abandons, une attente doit s'appliquer")
if M.autorise(apres_deux, maintenant) is not False:
    e.append("la recherche doit etre refusee pendant l'attente")
# Elle s'ecoule vraiment, et se termine.
if M.reste(apres_deux, maintenant + reste) != 0:
    e.append("l'attente ne se termine jamais")
if M.autorise(apres_deux, maintenant + reste) is not True:
    e.append("une fois l'attente ecoulee, la recherche doit repartir")
# Un nouvel abandon pendant l'attente la rallonge (elle repart du dernier depart).
apres_trois = M.noter(apres_deux, maintenant + 5)
if M.reste(apres_trois, maintenant + 5) <= reste:
    e.append("un abandon de plus doit rallonger l'attente, pas la raccourcir")

# --- LE PARDON : une partie jouee jusqu'au bout efface le plus ancien -----------------------------
pardonne = M.pardonner(apres_deux, maintenant)
if M.compte(pardonne, maintenant) != 1:
    e.append("une partie menee a son terme doit effacer un abandon")
if M.autorise(pardonne, maintenant) is not True:
    e.append("apres pardon, le joueur redevenu correct doit pouvoir rejouer")
# Pardonner sans rien a pardonner ne doit pas casser.
if M.compte(M.pardonner(T([]), maintenant), maintenant) != 0:
    e.append("pardonner une ardoise vide doit rester sans effet")

# --- LE MESSAGE ----------------------------------------------------------------------------------
if M.texte(0) is not None or M.texte(-5) is not None:
    e.append("sans attente, aucun message ne doit s'afficher")
court, long_ = M.texte(30), M.texte(125)
for t in (court, long_):
    if not t or "quitte" not in t:
        e.append("le message doit DIRE pourquoi la recherche est refusee : %r" % t)
if court and "30 s" not in court:
    e.append("sous une minute, le message doit donner les secondes : %r" % court)
if long_ and "2:05" not in long_:
    e.append("au-dela d'une minute, le message doit donner minutes et secondes : %r" % long_)

# --- BRANCHEMENT ----------------------------------------------------------------------------------
if 'source=src("shared/Abandon.lua")' not in B:
    e.append("Abandon.lua n'est pas embarque dans la place")
# Dans le PROFIL, pas en memoire du serveur : sinon il suffirait de changer de serveur.
if "abandons = {}" not in E:
    e.append("les abandons ne sont pas gardes dans le profil persistant")
if "Abandon.noter(pr.abandons" not in E:
    e.append("un abandon n'est pas enregistre durablement")
if "Economie.marquerSale(player)" not in zone(E, "function Economie.noterAbandon"):
    e.append("un abandon enregistre ne serait pas sauvegarde")
if "Economie.fuiteCompte(volontaire == true, result == nil" not in S:
    e.append("le serveur ne distingue pas une fuite d'une coupure")
if "Economie.noterAbandon(player)" not in S:
    e.append("le serveur n'enregistre jamais les abandons")
if "Economie.pardonnerAbandon(joueur)" not in S:
    e.append("aucune partie jouee jusqu'au bout ne pardonne : la sanction ne ferait que s'empiler")
# La file refuse pendant l'attente, et le refus porte le temps restant.
bloc = zone(S, 'elseif action == "jouer" then', 'elseif action == "suivre"')
if "Economie.attenteAbandon(player)" not in bloc or "ok = false" not in bloc:
    e.append("la recherche n'est pas refusee pendant l'attente")
if "attenteAbandon = resteFuite" not in bloc:
    e.append("le refus ne dit pas combien de temps il reste")
if "r.attenteAbandon" not in H:
    e.append("le hub ignore le refus : le bouton JOUER paraitrait casse")

if e:
    print("ROUGE : quitteur en serie")
    for m in e:
        print("  - " + m)
    sys.exit(1)
print("VERT : quitteur en serie (premier depart gratuit, attente croissante puis plafonnee, pardon)")
print("  1 abandon : %s s  -  2 : %s s  -  3 : %s s  -  10 : %s s"
      % (M.attente(1), M.attente(2), M.attente(3), M.attente(10)))
