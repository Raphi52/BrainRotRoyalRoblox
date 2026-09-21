# -*- coding: utf-8 -*-
"""REGARDER UN DUEL (src/shared/Spectateur.lua + branchement).

Trois manques de l'audit : le spectateur ne pouvait SUIVRE personne, ne voyait AUCUNE main (rien a
anticiper, rien a commenter), et son pronostic disparaissait sans jamais dire s'il avait eu raison.

Le point DELICAT : montrer une main en DIRECT ouvre un canal de triche (un complice dicte les
cartes a l'adversaire). Ce banc verifie donc, en priorite, que la main montree est RETARDEE.

1) Les regles PURES sont EXECUTEES (lupa).
2) Le branchement est lu : le serveur photographie les mains, n'envoie que l'instantane perime,
   expose le changement de camp, et le client dit le retard a l'ecran.
"""
import re, sys, pathlib
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import zone  # decoupe par CONTENU (voir tools/bancs.py)
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
SP = (R / "src/shared/Spectateur.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
ECO = (R / "src/server/Economie.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(SP)
def main(ids):
    t = lua.eval("function() return {} end")()
    for i, v in enumerate(ids, 1):
        t[i] = v
    return t
def py(t):
    return [t[i] for i in range(1, len(t) + 1)] if t is not None else None

# --- CAMP SUIVI ---------------------------------------------------------------------------------
if M.campSuivant(1) != 2 or M.campSuivant(2) != 1:
    e.append("le bouton doit faire basculer d'un camp a l'autre")
if M.campSuivant(1, 1) != 1 or M.campSuivant(2, 1) != 1:
    e.append("un camp demande explicitement doit etre respecte")
if M.campSuivant(1, 99) != 2:
    e.append("une demande absurde retombe sur la bascule, sans planter")
if M.nomCamp(1) == M.nomCamp(2):
    e.append("les deux camps doivent porter des noms distincts")
if M.libelleSuivi(1) != "Suivre " + M.nomCamp(2):
    e.append("le bouton doit annoncer ce qu'on verra au PROCHAIN clic, pas l'etat courant")

# --- HISTORIQUE DES MAINS -----------------------------------------------------------------------
h = M.ajouter(None, main(["A", "B"]), 0)
h = M.ajouter(h, main(["C", "D"]), 1)
h = M.ajouter(h, main(["E", "F"]), 2)
if len(py(h)) != 3:
    e.append("chaque photo doit etre gardee")
# La copie doit etre INDEPENDANTE : sinon la main du joueur, modifiee ensuite, remonterait le temps.
vivante = main(["X", "Y"])
h2 = M.ajouter(None, vivante, 0)
vivante[1] = "MODIFIE"
if py(h2)[0].main[1] != "X":
    e.append("l'historique doit garder une COPIE : sinon le passe change avec le present")
# La memoire ne grossit pas indefiniment.
h3 = None
for t in range(0, 60):
    h3 = M.ajouter(h3, main(["A"]), t)
if len(py(h3)) > M.MEMOIRE + 1:
    e.append(f"l'historique doit rester borne, obtenu {len(py(h3))} entrees")

# --- LE COEUR : LA MAIN EST RETARDEE ------------------------------------------------------------
hist = None
for t, m in ((0, ["A"]), (1, ["B"]), (2, ["C"]), (3, ["D"]), (4, ["E"])):
    hist = M.ajouter(hist, main(m), t)
vu = M.instantane(hist, 4)
if vu is None or py(vu)[0] != "B":
    e.append(f"a t=4 avec {M.RETARD} s de retard, on doit voir la main de t=1, obtenu {py(vu)}")
if py(M.instantane(hist, 4))[0] == "E":
    e.append("LA MAIN EN DIRECT EST MONTREE : canal de triche ouvert")
if M.instantane(hist, 2) is not None and py(M.instantane(hist, 2))[0] != "A":
    e.append("au debut, on ne montre que ce qui a deja RETARD secondes")
if M.instantane(hist, 1) is not None:
    e.append("avant le premier delai ecoule, on ne montre RIEN plutot que le present")
if M.instantane(None, 10) is not None:
    e.append("sans historique, aucune main")
if M.RETARD < 2:
    e.append("un retard de moins de 2 s ne protege de rien")

# --- RESULTAT DU PRONOSTIC ----------------------------------------------------------------------
if "pas parie" not in M.resultatPronostic(None, 1, 15):
    e.append("sans pari, il faut le dire plutot que d'afficher un vide")
g = M.resultatPronostic(1, 1, 15)
if "gagne" not in g.lower() or "15" not in g:
    e.append(f"un pari juste doit annoncer le gain, obtenu : {g}")
if "perdu" not in M.resultatPronostic(1, 2, 15).lower():
    e.append("un pari rate doit etre dit")
if "galite" not in M.resultatPronostic(1, 0, 15):
    e.append("une egalite ne fait gagner aucun pari, et doit l'expliquer")
# Ce controle exigeait auparavant que « vainqueur inconnu » (nil) se comporte comme une EGALITE.
# C'etait faux : une egalite est une partie jouee jusqu'au bout ou personne n'a gagne, tandis que
# nil signifie « pas encore finie » ou « annulee ». Annoncer « Egalite » dans ce cas ment au
# spectateur. Verifie le 2026-09-21 : un seul appelant existe (GameServer), et il est garde par
# `result and ...`, donc vainqueur y vaut toujours 0, 1 ou 2 — personne ne dependait de l'ancien
# comportement. La distinction est desormais controlee juste en dessous.
if M.resultatPronostic(1, 0, 15) is None:
    e.append("une vraie egalite doit toujours produire un texte")

# --- BRANCHEMENT SERVEUR ------------------------------------------------------------------------
if 'WaitForChild("Spectateur")' not in S:
    e.append("serveur : module Spectateur non requis")
if 'item("ModuleScript", "Spectateur"' not in B:
    e.append("build : Spectateur non embarque")
if "Spectateur.ajouter(historiqueMains[camp], teams[camp].hand, horloge)" not in S:
    e.append("serveur : les mains ne sont pas photographiees")
if "mainSuivie = Spectateur.instantane(historiqueMains[vu], horloge)" not in S:
    e.append("serveur : la main envoyee n'est pas l'instantane RETARDE")
if re.search(r"mainSuivie = teams\[\w+\]\.hand", S):
    e.append("serveur : la main EN DIRECT partirait vers le spectateur (triche)")
if 'action == "suivre"' not in S or "Spectateur.campSuivant(suivi[player] or 1" not in S:
    e.append("serveur : impossible de changer de camp suivi")
if "if equipeDe[player] == nil then" not in zone(S, 'action == "suivre"', 'elseif action =='):
    e.append("serveur : un JOUEUR pourrait se servir du suivi pour voir la main d'en face")
if "Spectateur.resultatPronostic(pronostics[player], vainqueur" not in S:
    e.append("serveur : le resultat du pari n'est pas annonce")
if "Economie.montantPronostic()" not in S or "function Economie.montantPronostic" not in ECO:
    e.append("serveur : le gain annonce n'est pas celui de l'economie (il serait invente)")
# Fenetre elargie le 2026-09-21 : l'assertion cherchait la remise a zero dans les 600
# premiers caracteres de resetMatch. Ajouter un commentaire ou une ligne en tete de la
# fonction faisait donc echouer un banc alors que le code etait juste — une assertion qui
# depend de la POSITION du code, pas de son contenu. On lit maintenant le corps entier.
if "historiqueMains = { {}, {} }" not in S.split("local function resetMatch")[1].split(chr(10) + "end")[0]:
    e.append("serveur : les mains de la partie precedente fuiteraient dans la suivante")
if "suivi[player] = nil" not in S:
    e.append("serveur : le camp suivi n'est pas oublie au depart du spectateur")

# --- RECAPITULATIF VU DU SPECTATEUR -------------------------------------------------------------
# Il regardait la partie sans jamais savoir POURQUOI elle s'etait jouee ainsi : les chiffres de fin
# ne partaient qu'aux joueurs.
for champ in ("bilanCamp1 = result and Bilan.vue(teams[1].bilan)",
              "bilanCamp2 = result and Bilan.vue(teams[2].bilan)"):
    if champ not in S:
        e.append("serveur : le spectateur ne recoit pas le recapitulatif -> " + champ)
if "nomCamp1 = Adversaire.nom(" not in S or "nomCamp2 = Adversaire.nom(" not in S:
    e.append("serveur : les colonnes du recapitulatif ne sont pas nommees (robot compris)")
bloc_spect = S.split("if camp == nil then")[1].split("return")[0]
if "bilanMoi" in bloc_spect:
    e.append("serveur : le spectateur recevrait un bilan « toi » qui ne le concerne pas")
if "moi, lui = s.bilanCamp1, s.bilanCamp2" not in C:
    e.append("client : le spectateur n'affiche pas le recapitulatif des deux camps")
if "titreGauche = s.nomCamp1" not in C:
    e.append("client : les colonnes du spectateur ne portent pas les noms des camps")
if "s.spectateur and (s.pronosticResultat" not in C:
    e.append("client : le conseil personnel serait montre au spectateur a la place de son pari")

# --- BRANCHEMENT CLIENT -------------------------------------------------------------------------
if "suiviBouton" not in C or 'InvokeServer("suivre")' not in C:
    e.append("client : aucun bouton pour suivre un joueur")
if "mainSuivieTexte" not in C or "s.mainSuivie" not in C:
    e.append("client : la main suivie n'est pas affichee")
if "il y a " not in C or "s.retardMain" not in C:
    e.append("client : le RETARD n'est pas dit au spectateur (il croirait voir le present)")
if "suiviBouton.Visible = s.spectateur == true and not s.result" not in C:
    e.append("client : le bouton de suivi s'afficherait pour un joueur ou apres la fin")
if "gainLabel.Text = s.pronosticResultat" not in C:
    e.append("client : le resultat du pari n'apparait pas sur l'ecran de fin")

# REFUS DE POSE. Defaut mesure le 2026-09-21 : un spectateur qui clique dans l'arene n'obtenait
# RIEN — ni son, ni message — et le serveur jetait meme sa demande sans un mot. Il ne peut pas
# deviner s'il a mal clique, si le jeu rame, ou s'il n'a pas le droit.
if "regardes" not in M.REFUS_POSE or "poser" not in M.REFUS_POSE:
    e.append("le refus doit dire qu'il REGARDE et qu'il ne peut pas poser")
# On lui rappelle ce qu'il PEUT faire, tant que la partie n'est pas finie.
if "parier" not in M.texteRefusPose(True):
    e.append("le refus doit proposer le pari quand il est encore possible")
if M.texteRefusPose(False) != M.REFUS_POSE:
    e.append("apres la fin, on ne propose plus un pari qui n'existe plus")
if M.texteRefusPose(True).startswith(M.REFUS_POSE) is False:
    e.append("les deux formes doivent dire la meme chose d'abord")
if "if hud.spectateur then" not in C or "Spectateur.texteRefusPose(hud.pariPossible == true)" not in C:
    e.append("client : le clic d'un spectateur ne dit toujours rien")
elif C.index("if hud.spectateur then") > C.index('return "aucune carte selectionnee"'):
    # Le test doit passer AVANT « aucune carte selectionnee », sinon le clic sort en silence.
    e.append("client : le cas spectateur est teste trop tard, le clic sort en silence")
if "hud.spectateur = s.spectateur == true" not in C:
    e.append("client : l'etat spectateur n'est pas garde pour le clic d'arene")
if "RefusEvent:FireClient(player, Spectateur.REFUS_POSE)" not in S:
    e.append("serveur : la demande d'un spectateur est encore jetee sans reponse")

# --- LES PARIS FERMENT AVANT QUE L'ISSUE SOIT EVIDENTE --------------------------------------------
# Defaut mesure le 2026-09-21 : le serveur refusait bien un pari APRES la fin, mais rien n'empechait
# de parier a la derniere seconde — 2-0 a dix secondes du terme, ou une tour du Roi a 1 % de vie. Le
# spectateur encaissait alors des pieces a tous les coups. Un pronostic qui ne risque rien n'en est
# pas un.
DUREE = 180
if M.parisOuverts(DUREE, DUREE, 0, 0) is not True:
    e.append("au coup d'envoi, les paris doivent etre ouverts")
# Fermeture par le TEMPS : passe le premier tiers, on a deja vu le debut du duel.
limite = DUREE * (1 - M.PART_PARIS)
if M.parisOuverts(limite, DUREE, 0, 0) is not True:
    e.append("les paris doivent rester ouverts jusqu'a la limite exacte")
if M.parisOuverts(limite - 1, DUREE, 0, 0) is not False:
    e.append("passe le premier tiers, les paris doivent etre fermes")
if M.parisOuverts(5, DUREE, 0, 0) is not False:
    e.append("parier a dix secondes de la fin doit etre refuse")
# Fermeture par la PREMIERE COURONNE : des qu'une tour tombe, la partie a penche, et cela se voit.
if M.parisOuverts(DUREE, DUREE, 1, 0) is not False:
    e.append("une tour tombee ferme les paris, meme au tout debut")
if M.parisOuverts(DUREE, DUREE, 0, 2) is not False:
    e.append("peu importe QUEL camp mene : l'issue penche, les paris ferment")
# Donnees aberrantes : on ferme plutot que d'ouvrir a tort.
for duree in (0, None, -10):
    if M.parisOuverts(DUREE, duree, 0, 0) is not False:
        e.append("une duree de match invalide (%r) ne doit pas ouvrir les paris" % (duree,))
if "fermes" not in M.texteParisFermes().lower():
    e.append("le message doit dire que les paris sont fermes : %r" % M.texteParisFermes())

# Branchement : le refus vit cote SERVEUR (le client n'est pas cru), et le bouton suit.
if "ouverts == true" not in S:
    e.append("serveur : la regle d'ouverture n'entre pas dans la decision")
if "Spectateur.parisOuverts(timeLeft, MATCH_TIME, crowns(1), crowns(2))" not in S:
    e.append("serveur : les paris ne ferment jamais, on pariera sur une issue connue")
bloc_prono = zone(S, "PronosticEvent.OnServerEvent")
if "parisOuverts" not in bloc_prono:
    e.append("serveur : le garde-fou n'est pas sur le chemin du pari")
if "parisOuverts = Spectateur.parisOuverts(" not in S:
    e.append("serveur : le client ne sait pas si les paris sont ouverts")
if "s.parisOuverts ~= false" not in C:
    e.append("client : le bouton de pari resterait affiche, pour un clic sans effet")
if "hud.parisFermesVu" not in C:
    e.append("client : le message de fermeture se repeterait a chaque etat, ou manquerait")

# --- PARTIE ANNULEE SANS VAINQUEUR ----------------------------------------------------------------
# Les deux joueurs sautent : la partie est annulee et repart a neuf (Reprise.partieAbandonnee).
# Verifie le 2026-09-21 : resetMatch effaçait les pronostics SANS passer par l'ecran de fin, donc
# le pari du spectateur s'evaporait sans un mot — la partie disparaissait de son ecran.
annule = M.resultatPronostic(1, None, 15, True)
if annule != M.ANNULEE:
    e.append("une partie annulee doit etre annoncee au spectateur : %r" % annule)
if "annulee" not in annule.lower():
    e.append("le message doit dire que la partie est annulee : %r" % annule)
# Meme sans avoir parie, il doit savoir pourquoi la partie a disparu.
if M.resultatPronostic(None, None, 15, True) != M.ANNULEE:
    e.append("sans pari, l'annulation doit quand meme etre expliquee")
# L'annulation prime sur tout le reste : c'est le fait le plus important de l'instant.
if M.resultatPronostic(1, 1, 15, True) != M.ANNULEE:
    e.append("l'annulation doit primer sur un resultat de pari")

# LE TEXTE MENTAIT : « vainqueur inconnu » rendait « Egalite », exactement comme un vrai match nul
# ou les deux joueurs sont alles au bout. Ce n'est pas la meme chose.
if M.resultatPronostic(1, 0, 15) != "Egalite : aucun pari ne gagne.":
    e.append("une VRAIE egalite doit rester annoncee comme telle")
if M.resultatPronostic(1, None, 15) is not None:
    e.append("une partie non terminee ne doit rien annoncer, surtout pas une egalite")
# Les deux cas ne doivent plus se confondre.
if M.resultatPronostic(1, 0, 15) == M.resultatPronostic(1, None, 15):
    e.append("egalite et partie non terminee rendent encore la meme chose")

# Branchement : l'annulation est marquee cote serveur et envoyee au spectateur.
if 'ReplicatedStorage:SetAttribute("BRR_AnnuleeA", os.clock())' not in S:
    e.append("serveur : l'annulation n'est pas marquee, le spectateur ne saura rien")
if "local function annuleeRecente()" not in S:
    e.append("serveur : rien ne permet de savoir qu'une partie vient d'etre annulee")
if "annuleeRecente() and Spectateur.texteAnnulee()" not in S:
    e.append("serveur : l'annulation n'est pas annoncee au spectateur")
# La marque est posee AVANT resetMatch : apres, les tables de partie sont deja vides.
bloc_annule = zone(S, "les deux joueurs ont saute", "-- Le bot ne remplace")
# On verifie la PRESENCE avant de comparer les positions : sinon ce controle plante avec une trace
# Python illisible au lieu de nommer le defaut (mesure le 2026-09-21 en le cassant volontairement).
if "SetAttribute" not in bloc_annule or "resetMatch()" not in bloc_annule:
    e.append("serveur : l'annulation n'est pas marquee juste avant la remise a neuf")
elif bloc_annule.index("SetAttribute") > bloc_annule.index("resetMatch()"):
    e.append("serveur : l'annulation est marquee apres la remise a neuf, trop tard")

# --- QUAND LES JOUEURS RELANCENT UNE PARTIE -------------------------------------------------------
# Verifie le 2026-09-21 : le spectateur n'a rien valide, mais tout ce qui le concerne doit repartir
# a neuf. resetMatch remet bien a zero les pronostics, l'historique des mains suivies et les bilans.
reset = S.split("local function resetMatch()")[1].split("buildArena()")[0]
for etat, pourquoi in (
        ("pronostics = {}", "il ne pourrait plus parier sur la nouvelle partie"),
        ("historiqueMains = { {}, {} }", "il verrait les cartes de la partie PRECEDENTE"),
        ("result = nil", "l'ecran de fin resterait affiche"),
        ("vainqueur = nil", "le resultat de son pronostic resterait celui d'avant")):
    if etat not in reset:
        e.append("relance : %s n'est pas remis a zero — %s" % (etat, pourquoi))

# GARDE-FOU GENERAL. Douze chemins menent a resetMatch (revanche, expiration d'une coupure, double
# deconnexion, fin de tutoriel, demarrage). Un etat de partie vide ailleurs QUE dans resetMatch
# survit donc aux onze autres : c'est exactement ce qui etait arrive a `revancheEtat`, dont un
# refus se rejouait sur la partie suivante.
for etat in ("revanche", "revancheEtat", "recompenses", "reprises", "humainAbsent", "signalements"):
    if (etat + " = {}") not in reset:
        e.append("relance : « %s » n'est pas remis a zero dans resetMatch, il survivrait a la partie" % etat)

# --- LES PHOTOS DE PROFIL VUES PAR LE SPECTATEUR --------------------------------------------------
# Il n'a pas de camp : il voyait SA PROPRE photo face a un rouage de robot, ce qui ne voulait rien
# dire pour lui.
for champ in ("userIdCamp1", "userIdCamp2", "camp1EstRobot", "camp2EstRobot"):
    if champ not in S:
        e.append("serveur : le spectateur ne recoit pas « %s », il ne peut pas voir les deux joueurs" % champ)
if "gaucheId, gaucheNom, gaucheRobot = s.userIdCamp1, s.nomCamp1, s.camp1EstRobot" not in C:
    e.append("client : le spectateur verrait encore sa propre photo au lieu du camp 1")
if "droiteId, droiteNom, droiteRobot = s.userIdCamp2, s.nomCamp2, s.camp2EstRobot" not in C:
    e.append("client : le spectateur ne voit pas le camp 2")
# Le joueur, lui, garde sa lecture « moi / en face ».
if "gaucheId, gaucheNom, gaucheRobot = player.UserId, player.DisplayName, false" not in C:
    e.append("client : le joueur ne verrait plus sa propre photo")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : le spectateur suit, comprend, et apprend s'il avait raison — sans pouvoir souffler les cartes")
sys.exit(1 if e else 0)
