# -*- coding: utf-8 -*-
"""L'ADVERSAIRE QUI NE JOUE PAS (src/shared/Inactif.lua).

Le defaut corrige : un joueur pouvait rester plante sans poser une seule carte. En face, on
attendait le chrono ENTIER — trois minutes — pour une victoire vide, sans duel. C'est le pendant
du quitteur (Abandon.lua) : partir etait sanctionne, mais RESTER sans jouer ne l'etait pas, ce
qui en faisait la faille evidente.

CE QU'ON REFUSE DE FAIRE : accuser quelqu'un qui n'a pas de quoi jouer. Le compteur ne tourne que
quand poser etait POSSIBLE, et jamais pendant les premieres secondes ou attendre son elixir est
la bonne decision.

1) Regles PURES executees (lupa) : ce qui declenche le compteur, la grace de debut, le preavis,
   l'arret de la partie, les deux messages opposes.
2) Branchement lu : module embarque, pose horodatee sur l'horloge de JEU, surveillance des seuls
   joueurs humains, fin de partie au profit de l'actif, inactivite comptee comme un abandon.
"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import zone  # decoupe par CONTENU (voir tools/bancs.py)
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
IN = (R / "src/shared/Inactif.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(IN)

APRES_GRACE = M.GRACE + 1

# --- LE COMPTEUR NE TOURNE QUE SI JOUER ETAIT POSSIBLE --------------------------------------------
# LE COEUR DE LA JUSTESSE : sans cette condition, on sanctionnerait une jauge vide, c'est-a-dire
# le jeu lui-meme.
if M.compteur(1, 3) is not False:
    e.append("un joueur sans assez d'elixir ne doit pas etre compte comme inactif")
if M.compteur(3, 3) is not True:
    e.append("des qu'il peut poser sa carte la moins chere, le compteur doit tourner")
if M.compteur(9, 2) is not True:
    e.append("jauge pleine et cartes jouables : le compteur doit tourner")

# --- LA GRACE DE DEBUT ----------------------------------------------------------------------------
# En debut de partie, attendre son elixir est la BONNE decision : on ne surveille rien.
if M.surveille(0) is not False or M.surveille(M.GRACE - 1) is not False:
    e.append("les premieres secondes ne doivent declencher aucune surveillance")
if M.surveille(M.GRACE) is not True:
    e.append("passe la grace, la surveillance doit commencer")
if M.suspect(999, 5) is not False:
    e.append("meme un long silence ne compte pas avant la fin de la grace")

# --- SILENCE : depuis la derniere pose, ou depuis le DEBUT si rien n'a jamais ete joue ------------
if M.silence(100, 130, 0) != 30:
    e.append("le silence doit se compter depuis la derniere carte posee")
# Un joueur qui n'a JAMAIS rien pose ne doit pas passer pour eternellement actif.
if M.silence(None, 70, 0) != 70:
    e.append("sans aucune pose, le silence se compte depuis le debut de la partie")
if M.silence(200, 100, 0) != 0:
    e.append("un silence negatif ne doit jamais sortir d'ici")

# --- PREAVIS PUIS ARRET ---------------------------------------------------------------------------
if M.suspect(M.SEUIL - 1, APRES_GRACE) is not False:
    e.append("sous le seuil, personne n'est suspect")
if M.suspect(M.SEUIL, APRES_GRACE) is not True:
    e.append("au seuil, l'inactivite doit etre reconnue")
# On ne brandit pas un compte a rebours a quelqu'un qui joue normalement.
if M.resteAvantFin(M.SEUIL - 1, APRES_GRACE) is not None:
    e.append("aucun compte a rebours ne doit s'afficher avant le seuil")
reste = M.resteAvantFin(M.SEUIL, APRES_GRACE)
if reste != M.DELAI_FIN:
    e.append("au seuil, le preavis doit valoir %s s, obtenu %r" % (M.DELAI_FIN, reste))
# Le preavis s'ecoule, puis la partie s'arrete.
if M.resteAvantFin(M.SEUIL + M.DELAI_FIN // 2, APRES_GRACE) >= reste:
    e.append("le preavis ne s'ecoule pas")
if M.doitFinir(M.SEUIL + M.DELAI_FIN - 1, APRES_GRACE) is not False:
    e.append("la partie s'arrete avant la fin du preavis")
if M.doitFinir(M.SEUIL + M.DELAI_FIN, APRES_GRACE) is not True:
    e.append("la partie ne s'arrete jamais, meme apres le preavis")
# Et JAMAIS pendant la grace, quel que soit le silence.
if M.doitFinir(9999, 0) is not False:
    e.append("une partie ne doit pas s'arreter pendant les premieres secondes")
# Le preavis laisse un vrai temps de reaction.
if M.DELAI_FIN < 10:
    e.append("un preavis de %s s ne laisse pas le temps de reagir" % M.DELAI_FIN)

# --- LES DEUX MESSAGES, OPPOSES -------------------------------------------------------------------
if M.avertissement(None) is not None:
    e.append("sans preavis en cours, aucun avertissement")
av = M.avertissement(12)
if not av or "12" not in av:
    e.append("l'avertissement doit donner le temps restant : %r" % av)
if "Joue" not in av:
    e.append("l'avertissement doit dire QUOI FAIRE, pas seulement annoncer la fin : %r" % av)
# Cote victime : elle attendait sans comprendre.
if M.texteAttente(M.SEUIL - 1, APRES_GRACE) is not None:
    e.append("rien ne doit etre dit tant que l'adversaire joue normalement")
att = M.texteAttente(60, APRES_GRACE)
if not att or "60" not in att:
    e.append("la victime doit savoir depuis combien de temps l'autre ne joue plus : %r" % att)
if av == att:
    e.append("l'inactif et sa victime recevraient le meme message")

# --- L'INACTIVITE VAUT UN ABANDON -----------------------------------------------------------------
# Sinon il suffirait de ne rien faire pour contourner la sanction du quitteur.
if M.vautAbandon(True) is not True:
    e.append("rester plante face a un humain doit compter comme un abandon")
if M.vautAbandon(False) is not False:
    e.append("l'inactivite face au robot ne lese personne")

# --- LE PIEGE DE L'HORLOGE CUMULEE (defaut mesure le 2026-09-21) ---------------------------------
# `horloge`, cote serveur, est MONOTONE : elle compte depuis le demarrage du serveur et ne se remet
# jamais a zero (elle date aussi les poses, les statuts, les projectiles). Le serveur comparait le
# silence a 0, c'est-a-dire au demarrage du SERVEUR et non au debut de la PARTIE. Des la deuxieme
# partie, le silence valait donc deja des centaines de secondes : la partie s'arretait pour
# « inactivite » au bout de 21 s, alors que les deux joueurs jouaient.
HORLOGE_2E_PARTIE = 200.0
faux = M.silence(None, HORLOGE_2E_PARTIE, 0)
if M.doitFinir(faux, APRES_GRACE) is not True:
    e.append("le banc ne reproduit plus le defaut d'origine : verifier ce controle")
juste = M.silence(None, HORLOGE_2E_PARTIE, HORLOGE_2E_PARTIE)
if juste != 0:
    e.append("au debut d'une partie, le silence doit valoir zero, obtenu %r" % juste)
if M.doitFinir(juste, APRES_GRACE) is not False:
    e.append("une partie fraiche ne doit jamais s'arreter pour inactivite")
# Le serveur doit passer le DEBUT DE PARTIE, jamais 0.
if "Inactif.silence(t.dernierePose, horloge, 0)" in S:
    e.append("serveur : le silence est compte depuis le demarrage du serveur, pas depuis la partie")
if "Inactif.silence(t.dernierePose, horloge, t.debutJeu or horloge)" not in S:
    e.append("serveur : le debut de partie n'est pas la reference du silence")
if "debutJeu = horloge," not in S:
    e.append("serveur : chaque partie ne retient pas son instant de depart")

# --- BRANCHEMENT ------------------------------------------------------------------------------------
if 'source=src("shared/Inactif.lua")' not in B:
    e.append("Inactif.lua n'est pas embarque dans la place")
if 'WaitForChild("Inactif")' not in S:
    e.append("le serveur ne charge pas Inactif")
# La pose est horodatee sur l'horloge de JEU : le gel du coup d'envoi ne doit pas compter.
if "t.dernierePose = horloge" not in S:
    e.append("la pose n'est pas horodatee, ou l'est sur une horloge qui tourne pendant le gel")
if "Inactif.compteur(t.elixir, coutMin)" not in S:
    e.append("le serveur compte l'inactivite sans verifier que le joueur POUVAIT jouer")
if "c.cost < coutMin" not in S:
    e.append("le serveur ne calcule pas le cout de la carte la moins chere de la main")
bloc = zone(S, "ADVERSAIRE PLANTE", "-- TUTORIEL")
# Le ROBOT ne doit pas etre surveille : il joue toujours, et il n'a pas de compte a sanctionner.
if "local joueur = occupant[team]" not in bloc or "if joueur and t then" not in bloc:
    e.append("le serveur surveillerait aussi le robot")
if "endMatch(3 - team)" not in bloc:
    e.append("la partie ne s'arrete pas au profit de celui qui joue")
if "Economie.noterAbandon(joueur)" not in bloc:
    e.append("l'inactivite ne compte pas comme un abandon : la sanction du quitteur se contourne")
if "Inactif.vautAbandon(occupant[3 - team] ~= nil)" not in bloc:
    e.append("l'inactivite face au robot serait sanctionnee comme face a un humain")
# Les deux messages partent bien dans l'etat, et le client les affiche.
if "avertissementInactif = Inactif.avertissement(" not in S:
    e.append("l'inactif ne recoit aucun preavis")
if "adversaireInactif = occupant[3 - monCamp] ~= nil" not in S:
    e.append("celui qui joue n'apprend jamais que l'autre est plante")
if "s.avertissementInactif or s.adversaireInactif" not in C:
    e.append("le client n'affiche pas l'inactivite")
if "s.avertissementInactif and Color3" not in C:
    e.append("les deux messages s'afficheraient de la meme facon")

if e:
    print("ROUGE : adversaire inactif")
    for m in e:
        print("  - " + m)
    sys.exit(1)
print("VERT : adversaire inactif (compteur seulement si jouer etait possible, preavis, arret)")
print("  grace %s s  -  seuil %s s  -  preavis %s s avant l'arret"
      % (M.GRACE, M.SEUIL, M.DELAI_FIN))
