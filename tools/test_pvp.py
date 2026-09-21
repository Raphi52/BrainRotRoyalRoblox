# -*- coding: utf-8 -*-
"""EXPERIENCE PvP : coup d'envoi commun, forfait, revanche a deux, et leur branchement.

1) Les regles PURES de src/shared/Duel.lua sont EXECUTEES (lupa).
2) Le branchement est lu dans le serveur, le client de match et le hub : gel de la simulation,
   forfait a la sortie, motif de refus renvoye au joueur, couleurs de camp, file d'attente annulable.
"""
import re, pathlib
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import zone  # decoupe par CONTENU (voir tools/bancs.py)
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
D = (R / "src/shared/Duel.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
H = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
Duel = lua.execute(D)

def att(*a):
    r = lua.eval("function(m, ...) return { m.attente(...) } end")(Duel, *a)
    return (r[1], r[2] if len(r) > 1 else None, r[3] if len(r) > 2 else None)

# --- COUP D'ENVOI -------------------------------------------------------------------------------
if att(False, 1, 0, None)[0] is not False:
    e.append("serveur hub : rien ne doit etre gele")
g, phase, sec = att(True, 1, 0, None)
if not (g is True and phase == "adversaire" and sec == 30):
    e.append(f"duel seul : attente attendue, obtenu {g} {phase} {sec}")
g, phase, sec = att(True, 2, 5, 0)
if not (g is True and phase == "depart" and sec == 3):
    e.append(f"deux joueurs : compte a rebours attendu, obtenu {g} {phase} {sec}")
if att(True, 2, 5, 3)[0] is not False:
    e.append("compte a rebours ecoule : la partie doit demarrer")
if att(True, 1, 30, None)[0] is not False:
    e.append("personne apres le plafond : on joue quand meme")
if att(True, 2, 100, 1)[1] != "depart":
    e.append("l'arrivee tardive du second doit quand meme donner un compte a rebours")

# --- FORFAIT ------------------------------------------------------------------------------------
if Duel.forfait(False, 1, True) is not True:
    e.append("partir en duel humain doit donner la victoire a l'autre")
if Duel.forfait(False, 1, False) is not False:
    e.append("partir contre le robot ne doit rien declencher")
if Duel.forfait(True, 1, True) is not False:
    e.append("partir apres la fin ne rejoue pas le resultat")

# --- REVANCHE -----------------------------------------------------------------------------------
if Duel.revanchePrete(False, True, False) is not True:
    e.append("contre le robot, un seul clic relance")
if Duel.revanchePrete(True, True, False) is not False:
    e.append("contre un humain, un seul clic ne doit PAS relancer")
if Duel.revanchePrete(True, True, True) is not True:
    e.append("contre un humain, les deux clics relancent")
if Duel.revanchePrete(True, False, True) is not False:
    e.append("sans mon clic, rien ne relance")

# --- BRANCHEMENT SERVEUR ------------------------------------------------------------------------
if 'require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Duel"))' not in S:
    e.append("serveur : module Duel non requis")
if 'item("ModuleScript", "Duel"' not in B:
    e.append("build : Duel non embarque dans la place (le serveur resterait bloque)")
if not re.search(r"geleDepart = \(etatDepart\(\)\) == true", S):
    e.append("serveur : la simulation ne lit pas l'etat de depart")
if not re.search(r"if geleDepart then\s*\n(?:.*\n)*?\s*return\s*\n\s*end", S):
    e.append("serveur : le gel ne coupe pas le tour de simulation")
if "if geleDepart then\n\t\treturn false" not in S:
    e.append("serveur : une carte pourrait etre posee avant le coup d'envoi")
if not re.search(r"local ok, motif = tryPlay\(camp", S) or "RefusEvent:FireClient(player, motif" not in S:
    e.append("serveur : un refus de pose reste silencieux")
if "Duel.forfait(" not in S or "endMatch(3 - camp)" not in S:
    e.append("serveur : l'abandon ne donne pas la partie a l'adversaire")
if "Duel.revanchePrete(" not in S:
    e.append("serveur : la revanche ne demande pas les deux joueurs")
if not re.search(r"local duelHumain = .*occupant\[3 - camp\] ~= nil or Matchmaking\.estServeurDeMatch", S):
    e.append("serveur : le tutoriel peut encore fausser un duel humain")
if "not duelHumain and (forcerTuto" not in S:
    e.append("serveur : le tutoriel n'est pas ecarte du duel humain")
if "local duelNeuf" not in S or "resetMatch()" not in S:
    e.append("serveur : le second joueur entre dans une partie deja commencee")
# L'appel porte desormais un argument de plus (le nom de l'adversaire, pour le journal) : on
# verifie que le GAIN est garde pour l'ecran de fin, pas la forme exacte de l'appel.
if "recompenses[joueur] = Economie.recompenser(joueur, issue, contreHumain" not in S:
    e.append("serveur : le gain de fin de partie n'est pas garde pour l'ecran de fin")
if "gain = recompenses[player]" not in S:
    e.append("serveur : le gain n'est pas envoye au client")
if "dernieresPoses[player] = maintenant" not in S:
    e.append("serveur : aucune cadence maximale sur la pose de carte")

# --- SCENARIO EN MOTEUR (le seul endroit ou le coup d'envoi se voit VRAIMENT tourner) ----------
if "BRR_DUEL" not in S or "estDuelReserve" not in S:
    e.append("serveur : le coup d'envoi n'est pas exercable en Studio (aucun crochet de duel)")
if '[DUEL] %s : %s' not in S:
    e.append("serveur : aucun scenario de duel en moteur")
if '--duel' not in B or 'item("BoolValue", "BRR_DUEL")' not in B:
    e.append("build : option --duel absente, le scenario de duel ne peut pas etre embarque")

# --- BRANCHEMENT CLIENT DE MATCH ----------------------------------------------------------------
if "RefusEvent.OnClientEvent" not in C:
    e.append("client : le motif de refus n'est pas affiche")
# La fonction a ete declaree en avant (`local poseClientPermise` puis `function ...`) pour tenir
# sous le plafond de variables locales de Lua : on verifie le FAIT, pas la forme de declaration.
if "poseClientPermise" not in C or "card.poseLibre" not in C:
    e.append("client : la regle de pose ne connait pas les cartes qui se posent partout")
if "Batiments.posePermise(monCamp" not in C:
    e.append("client : la visee ne connait pas la regle des batiments")
if re.search(r"math\.abs\(hit\.Position\.X\) > 27", C):
    e.append("client : bords de l'arene encore ecrits en dur")
if '"Bleu gagne", Color3.fromRGB(60, 110, 210)' not in C:
    e.append("client : le pronostic annonce toujours la mauvaise couleur de camp")
# Le spectateur doit voir le camp 1 nomme « Bleu » (teamColor du serveur). Le chiffre est passe
# en jauge de couronnes : on verifie le NOM et la source, pas la mise en forme du score.
if not ('"Bleu " .. Couronnes.jauge(s.crownsCamp1' in C or '"Bleu " .. (s.crownsCamp1 or 0)' in C):
    e.append("client : le score du spectateur nomme le mauvais camp")
if "majAttente(s)" not in C or "On attend l'adversaire" not in C:
    e.append("client : aucun coup d'envoi affiche")
if "s.serveurDeMatch ~= true" not in C:
    e.append("client : Rejouer reste propose la ou le serveur renvoie au hub")
# Le libelle du bouton vient desormais de la regle pure (Duel.texteBouton) : les quatre
# situations sont traitees au meme endroit. Ecrit a la main dans le client, le cas « l'autre est
# parti pendant que j'attendais » avait ete oublie.
if "En attente de l'adversaire..." not in D:
    e.append("regle : la revanche ne dit pas qu'on attend l'autre joueur")
if "Duel.texteBouton(s.adversaireHumain, s.revancheMoi, s.revancheLui," not in C:
    e.append("client : le libelle du bouton n'est pas celui de la regle")

# --- REVANCHE DEMANDEE, PUIS L'AUTRE S'EN VA -----------------------------------------------------
# Mesure le 2026-09-21 : le bouton repassait tout seul de « En attente de l'adversaire... » a
# « Rejouer », sans un mot — on croyait que son clic n'avait pas marche, et le clic suivant
# relancait une partie CONTRE LE ROBOT alors qu'on voulait sa revanche contre LUI.
if Duel.revanchePerdue(True, False) is not True:
    e.append("une revanche demandee sans personne en face doit etre signalee comme perdue")
if Duel.revanchePerdue(True, True) is not False:
    e.append("tant que l'adversaire est la, la revanche n'est pas perdue")
if Duel.revanchePerdue(False, False) is not False:
    e.append("sans demande de revanche, il n'y a rien a perdre")
# Le bouton ne doit PAS mentir : il ne rejoue pas le meme duel.
perdu = Duel.texteBouton(False, True, False)
if perdu == "Rejouer" or "robot" not in perdu.lower():
    e.append("le bouton doit dire que la prochaine partie sera contre le robot : %r" % perdu)
# Les autres situations restent intactes.
for args, attendu in ((("humain", False, False), "Revanche"),
                      (("humain", True, False), "En attente de l'adversaire..."),
                      (("humain", True, True), "C'est reparti !")):
    got = Duel.texteBouton(True, args[1], args[2])
    if got != attendu:
        e.append("libelle du bouton %r : %r au lieu de %r" % (args, got, attendu))
if Duel.texteBouton(False, False, False) != "Rejouer":
    e.append("contre le robot, sans demande, le bouton doit rester « Rejouer »")
# --- UNE PARTIE NE DOIT PAS DEMARRER SUR LA VALIDATION D'UN SEUL --------------------------------
# A deux joueurs PRESENTS, la regle exigeait deja les deux clics (plus haut dans ce banc). Le trou
# etait ailleurs, trouve le 2026-09-21 en suivant le chemin de relance : il regardait « y a-t-il
# quelqu'un en face MAINTENANT ». Or un joueur DECONNECTE a son camp reserve 45 s mais n'est plus
# occupant. Le clic de celui qui restait relancait donc une partie neuve, ce qui effacait la partie
# ET la reservation de l'absent — lequel ne pouvait rien valider, puisqu'il etait deconnecte.
if Duel.peutRelancer(True) is not False:
    e.append("relancer doit etre refuse tant que l'adversaire coupe peut revenir")
if Duel.peutRelancer(False) is not True:
    e.append("sans reprise en cours, la relance doit rester possible")
if Duel.peutRelancer(None) is not True:
    e.append("aucune reprise ouverte : la relance reste possible")
if "deconnecte" not in Duel.texteRelanceBloquee():
    e.append("le message doit dire que l'adversaire est deconnecte : %r" % Duel.texteRelanceBloquee())
# Le refus vit cote SERVEUR : cacher le bouton ne protege de rien, n'importe quel client peut
# envoyer l'evenement.
if "Duel.peutRelancer(reprises[3 - camp] ~= nil)" not in S:
    e.append("serveur : un clic effacerait encore la partie reservee a un joueur coupe")
bloc_relance = zone(S, "RestartEvent.OnServerEvent")
if "Duel.peutRelancer" not in bloc_relance:
    e.append("serveur : le garde-fou n'est pas sur le chemin de relance")
if bloc_relance.index("Duel.peutRelancer") > bloc_relance.index("revanche[player] = true"):
    e.append("serveur : la demande serait enregistree avant d'etre refusee")
if "relanceBloquee = (result ~= nil and reprises[3 - monCamp] ~= nil)" not in S:
    e.append("serveur : le joueur ne saurait pas pourquoi son clic ne fait rien")
if "s.relanceBloquee" not in C or "Duel.texteRelanceBloquee()" not in C:
    e.append("client : le bouton semblerait casse, sans explication")

# --- REFUSER, ET NE PAS ATTENDRE INDEFINIMENT -----------------------------------------------------
# Mesure le 2026-09-21 : celui qui demandait restait sur « En attente de l'adversaire... » SANS
# AUCUNE LIMITE, et l'autre n'avait aucun moyen de dire non — il ne pouvait que partir. Vu du
# demandeur, « il reflechit » et « il ne veut pas » se ressemblaient donc exactement.
if not (5 <= Duel.DELAI_REVANCHE <= 60):
    e.append("le delai de revanche (%s s) doit laisser lire l'ecran de fin sans bloquer quelqu'un"
             % Duel.DELAI_REVANCHE)
# Le compte a rebours s'ecoule et se termine.
if Duel.resteRevanche(100, 100) != Duel.DELAI_REVANCHE:
    e.append("a l'instant de la demande, tout le delai doit rester")
if Duel.resteRevanche(100, 100 + Duel.DELAI_REVANCHE / 2) >= Duel.DELAI_REVANCHE:
    e.append("le compte a rebours de revanche ne s'ecoule pas")
if Duel.resteRevanche(100, 100 + Duel.DELAI_REVANCHE + 5) != 0:
    e.append("le temps restant ne descend jamais sous zero")
if Duel.resteRevanche(None, 100) is not None:
    e.append("sans demande, il n'y a aucun compte a rebours")
if Duel.revancheExpiree(100, 100 + Duel.DELAI_REVANCHE - 1) is not False:
    e.append("la demande expire avant son delai")
if Duel.revancheExpiree(100, 100 + Duel.DELAI_REVANCHE) is not True:
    e.append("la demande n'expire jamais : l'attente serait sans fin")
if Duel.revancheExpiree(None, 100) is not False:
    e.append("sans demande, rien ne peut expirer")
# Le compte a rebours se VOIT sur le bouton : une attente bornee qui ne se montre pas ne rassure
# personne.
attente = Duel.texteBouton(True, True, False, False, 12)
if "12" not in attente:
    e.append("le bouton doit montrer le temps restant : %r" % attente)
if Duel.texteBouton(True, True, False, False, None) != "En attente de l'adversaire...":
    e.append("sans compte a rebours connu, le libelle d'attente doit rester lisible")
# UN REFUS se distingue d'une attente : ce n'est pas la meme chose pour celui qui regarde.
refuse = Duel.texteBouton(True, True, False, True, 12)
if refuse == attente or "robot" not in refuse.lower():
    e.append("un refus doit se distinguer d'une attente : %r contre %r" % (refuse, attente))
if Duel.texteRefus() == Duel.texteRevanchePerdue():
    e.append("« il ne veut pas » et « il est parti » ne doivent pas se dire pareil")
if "veut pas" not in Duel.texteRefus():
    e.append("le message de refus doit dire que l'adversaire ne veut pas : %r" % Duel.texteRefus())

# Branchement du refus et de l'expiration.
if "function(player, reponse)" not in S:
    e.append("serveur : aucune reponse « non » ne peut etre envoyee")
if 'if reponse == "non" then' not in S or "revancheEtat[player] = { refus = true }" not in S:
    e.append("serveur : le refus n'est pas enregistre")
if "revancheEtat[player] = { t = os.clock() }" not in S:
    e.append("serveur : l'instant de la demande n'est pas retenu, l'attente serait sans limite")
if "Duel.revancheExpiree(revancheEtat[player].t, os.clock())" not in S:
    e.append("serveur : une demande sans reponse n'expire jamais")
if "revancheRefusee = (result ~= nil and occupant[3 - monCamp] ~= nil" not in S:
    e.append("serveur : le refus d'en face n'est jamais annonce")
if "Duel.resteRevanche(revancheEtat[player].t, os.clock())" not in S:
    e.append("serveur : le compte a rebours n'est pas envoye au client")
if "revancheEtat = {}" not in S:
    e.append("serveur : les demandes ne sont pas remises a zero a la partie suivante")
if 'RestartEvent:FireServer("non")' not in C:
    e.append("client : aucun bouton pour refuser la revanche")
if "hud.boutonRefus.Visible = s.adversaireHumain == true" not in C:
    e.append("client : le bouton de refus s'afficherait hors duel humain")
if "s.revancheRefusee and Duel.texteRefus()" not in C:
    e.append("client : le refus n'est pas explique au joueur qui attendait")

# Le message qui explique, et le branchement qui le porte.
if "parti" not in Duel.texteRevanchePerdue():
    e.append("le message doit dire que l'adversaire est parti")
if "revanchePerdue = result ~= nil and (" not in S or "Duel.revanchePerdue(revanche[player] == true," not in S:
    e.append("serveur : la revanche perdue n'est jamais signalee au joueur")
if "s.revancheRefusee) and not hud.revanchePerdueVue" not in C:
    e.append("client : le message se repeterait a chaque etat, ou ne s'afficherait pas")
if "hud.revanchePerdueVue = nil" not in C:
    e.append("client : l'annonce ne pourrait plus se refaire a la partie suivante")
if "gainLabel" not in C:
    e.append("client : l'ecran de fin ne montre pas ce que la partie a rapporte")
if "emotesCoupees" not in C:
    e.append("client : impossible de couper les emotes de l'adversaire")

# --- BRANCHEMENT HUB ----------------------------------------------------------------------------
if "boutonAnnuler" not in H:
    e.append("hub : la recherche d'adversaire ne peut pas etre annulee")
if "if rechercheEnCours then" not in H:
    e.append("hub : un second appui sur JOUER ouvre une deuxieme attente")
# L'attente doit montrer le TEMPS : temps ecoule, ou compte a rebours avant le robot
# (Adversaire.attente). On verifie le FAIT, pas la phrase exacte.
if not ("%d s" in H and ("Recherche" in H or "Adversaire.attente" in H)):
    e.append("hub : l'attente ne montre pas le temps")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : coup d'envoi commun, forfait, revanche a deux, refus explique")
