# -*- coding: utf-8 -*-
"""SIGNALER UN JOUEUR (src/shared/Signalement.lua + branchement).

Le defaut corrige : aucun recours contre un adversaire penible. Le seul geste possible etait de
quitter la partie — ce qui coutait la victoire.

1) Les regles PURES sont EXECUTEES (lupa) : liste FERMEE de motifs, refus argumentes, un seul
   signalement par adversaire et par partie, ligne de trace stable.
2) Le branchement est lu : le serveur choisit la cible LUI-MEME, trace, dedoublonne et remet a zero
   a chaque partie ; le client n'envoie qu'un identifiant de motif et affiche la REPONSE du serveur.
"""
import re, sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
SG = (R / "src/shared/Signalement.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(SG)

# --- LISTE FERMEE -------------------------------------------------------------------------------
motifs = [M.MOTIFS[i] for i in range(1, len(M.MOTIFS) + 1)]
ids = [m.id for m in motifs]
if len(ids) < 3:
    e.append("trop peu de motifs : le joueur ne trouvera pas le sien et renoncera")
if len(set(ids)) != len(ids):
    e.append("deux motifs portent le meme identifiant")
for m in motifs:
    if not m.libelle or len(m.libelle) < 4:
        e.append(f"motif sans libelle lisible : {m.id}")
    if M.libelle(m.id) != m.libelle:
        e.append(f"libelle introuvable pour {m.id}")
if M.motifConnu("texte libre") is not False or M.motifConnu("") is not False:
    e.append("seuls les motifs de la liste doivent etre connus (aucun texte libre)")
if M.libelle("inconnu") is not None:
    e.append("un motif inconnu ne doit avoir aucun libelle")

# --- CE QUI EST ACCEPTE, ET CE QUI EST REFUSE ---------------------------------------------------
def acc(motif, cible, moi, deja=False):
    r = lua.eval("function(m, a, b, c, d) return { m.accepte(a, b, c, d) } end")(M, motif, cible, moi, deja)
    return (r[1], r[2] if len(r) > 1 else None)

ok, motif = acc(ids[0], 77, 42)
if ok is not True:
    e.append(f"un signalement normal doit passer, refus : {motif}")
ok, motif = acc("blabla", 77, 42)
if ok is not False or "Motif" not in motif:
    e.append("un motif hors liste doit etre refuse, avec sa raison")
ok, motif = acc(ids[0], None, 42)
if ok is not False or "robot" not in motif:
    e.append("sans adversaire humain, le refus doit le DIRE (on joue contre le robot)")
ok, motif = acc(ids[0], 42, 42)
if ok is not False or "soi-meme" not in motif:
    e.append("on ne doit pas pouvoir se signaler soi-meme")
ok, motif = acc(ids[0], "42", 42)
if ok is not False:
    e.append("l'identifiant doit etre compare en texte (il arrive parfois en nombre)")
ok, motif = acc(ids[0], 77, 42, True)
if ok is not False or "Deja" not in motif:
    e.append("un second signalement de la MEME cible doit etre refuse (le bouton n'est pas une arme)")
# Chaque refus doit avoir sa propre phrase, sinon le joueur ne sait pas quoi corriger.
refus = {acc("blabla", 77, 42)[1], acc(ids[0], None, 42)[1], acc(ids[0], 42, 42)[1], acc(ids[0], 77, 42, True)[1]}
if len(refus) != 4:
    e.append("deux refus differents partagent la meme phrase")

# --- CE QU'ON REPOND AU JOUEUR ------------------------------------------------------------------
conf = M.confirmation(ids[0])
if "enregistre" not in conf.lower():
    e.append("la confirmation doit dire que c'est ENREGISTRE")
for mot in ("banni", "sanction", "puni", "exclu"):
    if mot in conf.lower():
        e.append(f"la confirmation promet une sanction qu'on ne tient pas : « {mot} »")
if M.confirmation("inconnu") != "Motif inconnu.":
    e.append("un motif inconnu ne doit pas produire de fausse confirmation")

# --- TRACE --------------------------------------------------------------------------------------
ligne = M.ligne(42, 77, ids[0], 1758300000.9, 1)
for bout in ("[SIGNALEMENT]", "auteur=42", "cible=77", "motif=" + ids[0], "camp=1", "t=1758300000"):
    if bout not in ligne:
        e.append(f"la ligne de trace ne porte pas « {bout} » : {ligne}")
if M.cle(42, 77) == M.cle(77, 42):
    e.append("la cle de dedoublonnage doit distinguer le sens (auteur -> cible)")

# --- BRANCHEMENT SERVEUR ------------------------------------------------------------------------
if 'WaitForChild("Signalement")' not in S:
    e.append("serveur : module Signalement non requis")
if 'item("ModuleScript", "Signalement"' not in B:
    e.append("build : Signalement non embarque (serveur et client resteraient bloques)")
if 'action == "signaler"' not in S:
    e.append("serveur : aucune action de signalement")
bloc = S.split('action == "signaler"')[1].split("elseif action ==")[0]
if "occupant[3 - camp]) or dernierAdversaire[player]" not in bloc:
    e.append("serveur : la cible n'est pas choisie par le SERVEUR (le client pourrait viser n'importe qui)")
if "Signalement.accepte(arg, idCible, player.UserId" not in bloc:
    e.append("serveur : la regle d'acceptation n'est pas appliquee")
if "print(Signalement.ligne(" not in bloc:
    e.append("serveur : aucun signalement n'est trace")
if "signalements[cle] = true" not in bloc:
    e.append("serveur : rien n'empeche de signaler dix fois de suite")
# Fenetre elargie le 2026-09-21 : l'assertion cherchait la remise a zero dans les 600
# premiers caracteres de resetMatch. Ajouter un commentaire ou une ligne en tete de la
# fonction faisait donc echouer un banc alors que le code etait juste — une assertion qui
# depend de la POSITION du code, pas de son contenu. On lit maintenant le corps entier.
if "signalements = {}" not in S.split("local function resetMatch")[1].split(chr(10) + "end")[0]:
    e.append("serveur : les signalements ne sont pas remis a zero a la partie suivante")
# Le dernier adversaire est memorise pour qu'on puisse encore le signaler APRES la partie. La
# forme de l'affectation a change (l'adversaire est aussi note pour l'evitement du duel repete) :
# on verifie le FAIT.
# Mise a jour le 2026-09-21 : on retient desormais son IDENTIFIANT et non l'objet joueur (voir plus
# bas, la fuite memoire). Le FAIT verifie reste le meme : l'adversaire du moment est memorise pour
# pouvoir etre signale apres son depart.
if not ("local autre = occupant[3 - monCampCourant]" in S
        and "dernierAdversaire[player] = { UserId = autre.UserId" in S):
    e.append("serveur : impossible de signaler apres la partie (l'adversaire est deja parti)")
if "signalable = (occupant[3 - monCamp] ~= nil) or (dernierAdversaire[player] ~= nil)" not in S:
    e.append("serveur : le client ne sait pas s'il y a quelqu'un a signaler")

# --- BRANCHEMENT CLIENT -------------------------------------------------------------------------
if "signalerBouton" not in C or "signalerPanneau" not in C:
    e.append("client : aucun bouton ni liste de signalement")
if "Signalement.MOTIFS" not in C:
    e.append("client : la liste des motifs n'est pas celle du module (elle pourrait diverger)")
if 'InvokeServer("signaler", m.id)' not in C:
    e.append("client : le motif n'est pas envoye au serveur")
# Chaque appel doit porter UN identifiant de motif, et rien d'autre : un texte libre partirait
# vers le serveur et deviendrait un canal d'insultes de plus.
for suite in re.findall(r'InvokeServer\("signaler",([^)]*)\)', C):
    if suite.strip() != "m.id":
        e.append(f"client : autre chose qu'un identifiant de motif part vers le serveur ->{suite}")
# La RemoteFunction doit etre declaree APRES `remotes` : declaree avant, elle indexait une valeur
# vide et tout l'ecran de match tombait en erreur des le chargement (defaut rencontre ici meme).
if "local BoutiqueFn" in C and C.index("local remotes =") > C.index("local BoutiqueFn"):
    e.append("client : BoutiqueFn declaree avant `remotes` — l'ecran de match ne se chargerait pas")
if "annoncer(tostring(r.message" not in C:
    e.append("client : la REPONSE du serveur n'est pas affichee (on inventerait le retour)")
if "signalerBouton.Visible = s.signalable == true and not s.spectateur" not in C:
    e.append("client : le bouton s'afficherait face au robot ou pour un spectateur")

# --- LE DERNIER ADVERSAIRE NE DOIT PAS FUIR EN MEMOIRE --------------------------------------------
# Il faut le retenir APRES son depart (c'est tout l'interet : pouvoir signaler quelqu'un qui vient
# de quitter). Mais le serveur gardait l'OBJET joueur, et ne retirait jamais aucune entree : sur un
# serveur qui tourne des heures, la table accumulait tous les adversaires croises depuis le
# demarrage, et empechait Roblox de liberer les joueurs partis (mesure le 2026-09-21).
if "dernierAdversaire[player] = autre" in S:
    e.append("serveur : l'objet joueur est encore retenu, les joueurs partis ne seront jamais liberes")
if "dernierAdversaire[player] = { UserId = autre.UserId" not in S:
    e.append("serveur : le dernier adversaire n'est pas retenu par son identifiant")
# L'entree de celui qui PART disparait ; sa presence comme CIBLE, elle, doit survivre.
if "dernierAdversaire[player] = nil" not in S:
    e.append("serveur : l'entree du joueur qui part n'est jamais retiree")
# La cible reste signalable apres son depart : c'est la raison d'etre de cette table.
if "or dernierAdversaire[player]" not in S:
    e.append("serveur : on ne pourrait plus signaler un adversaire qui vient de partir")
# Le signalement n'a besoin que de l'identifiant : verifions qu'il le lit bien ainsi.
if "cible and cible.UserId or nil" not in S:
    e.append("serveur : la cible du signalement n'est pas identifiee par son UserId")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : un recours existe, borne, trace, et honnete sur ce qu'il promet")
sys.exit(1 if e else 0)
