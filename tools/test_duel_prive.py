# -*- coding: utf-8 -*-
"""DUEL PRIVE ENTRE AMIS (src/shared/Prive.lua + branchement).

Le defaut corrige : on ne pouvait affronter QUE l'inconnu tire par la file d'attente. Jouer contre
un ami assis a cote de soi etait impossible.

1) Les regles PURES sont EXECUTEES (lupa) : fabrication du code, lecture TOLERANTE d'une saisie
   humaine, validite, expiration, motifs en clair.
2) Le branchement est lu : Matchmaking reserve l'arene et teleporte les deux joueurs, le serveur
   expose les deux actions, le hub les appelle, et build.py embarque le module.
"""
import re, sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
PR = (R / "src/shared/Prive.lua").read_text(encoding="utf-8")
MM = (R / "src/server/Matchmaking.lua").read_text(encoding="utf-8")
GS = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
HUB = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(PR)
ALPHABET = M.ALPHABET
LON = M.LONGUEUR

# --- L'ALPHABET EVITE LES SIGNES QU'ON CONFOND --------------------------------------------------
for signe in "ILOU":
    if signe in ALPHABET:
        e.append(f"l'alphabet ne doit pas contenir « {signe} » (confondu a l'oral comme a l'ecrit)")
if len(set(ALPHABET)) != len(ALPHABET):
    e.append("l'alphabet contient un doublon")

# --- FABRICATION : aucun hasard dans le module --------------------------------------------------
code = M.code(lua.eval("function(n) return 1 end"))
if code != ALPHABET[0] * LON:
    e.append(f"le code doit venir du tirage FOURNI, obtenu {code}")
suite = lua.eval("function() local i = 0 return function(n) i = i + 1 return ((i - 1) % n) + 1 end end")()
c2 = M.code(suite)
if len(c2) != LON:
    e.append(f"longueur de code attendue {LON}, obtenue {len(c2)}")
if not M.valide(c2):
    e.append(f"un code fabrique doit etre valide, obtenu {c2}")
# un tirage hors bornes ne doit jamais casser la fabrication
if len(M.code(lua.eval("function(n) return n + 99 end"))) != LON:
    e.append("un tirage hors bornes doit etre ramene dans l'alphabet")

# --- LECTURE TOLERANTE D'UNE SAISIE HUMAINE -----------------------------------------------------
cas = [
    ("k7r4m", "K7R4M", "minuscules"),
    ("K7R-4M", "K7R4M", "tiret de lecture"),
    ("  K7R 4M  ", "K7R4M", "espaces"),
    ("k7r4m!!", "K7R4M", "ponctuation"),
    ("O2LI9", "021 19"[:0] + "02119", "confusions O/L/I"),
    ("UUUUU", "VVVVV", "U lu comme V"),
    ("K7R4MZZZ", "K7R4M", "saisie trop longue coupee"),
]
for saisie, attendu, quoi in cas:
    obtenu = M.normaliser(saisie)
    if obtenu != attendu:
        e.append(f"normalisation ({quoi}) : « {saisie} » -> « {obtenu} », attendu « {attendu} »")
if M.normaliser(None) != "" or M.normaliser(42) != "":
    e.append("une saisie qui n'est pas du texte doit rendre une chaine vide")

# --- VALIDITE -----------------------------------------------------------------------------------
if M.valide("K7R4") is not False or M.valide("K7R4MM") is not False:
    e.append("un code de mauvaise longueur doit etre refuse")
if M.valide("K7R4I") is not False:
    e.append("un signe hors alphabet doit etre refuse")
if M.valide(None) is not False or M.valide(12345) is not False:
    e.append("une valeur qui n'est pas du texte doit etre refusee")
if M.valide("K7R4M") is not True:
    e.append("un code correct doit etre accepte")

# --- AFFICHAGE ----------------------------------------------------------------------------------
if M.joli("K7R4M") != "K7R-4M":
    e.append("le code affiche doit etre groupe pour se lire a voix haute")
if M.joli("bof") != "bof":
    e.append("un code invalide est rendu tel quel, sans faux groupage")

# --- EXPIRATION ---------------------------------------------------------------------------------
if M.expire(1000, 1000 + M.DUREE, None) is not False:
    e.append("un code doit rester valable jusqu'a sa duree exacte")
if M.expire(1000, 1000 + M.DUREE + 1, None) is not True:
    e.append("passe sa duree, un code doit expirer")

# --- MOTIFS EN CLAIR ----------------------------------------------------------------------------
motifs = {cas: M.motif(cas) for cas in ("invalide", "inconnu", "expire", "studio", "soi", "autre")}
if len(set(motifs.values())) != len(motifs):
    e.append("chaque refus doit avoir son propre motif (sinon le joueur ne sait pas quoi corriger)")
for cas, texte in motifs.items():
    if not texte or len(texte) < 10:
        e.append(f"motif trop pauvre pour « {cas} » : {texte}")

# --- BRANCHEMENT MATCHMAKING --------------------------------------------------------------------
if "function M.creerPrive(player" not in MM or "function M.rejoindrePrive(player" not in MM:
    e.append("Matchmaking : creation ou entree dans un duel prive absente")
if "ReserveServer" not in MM.split("function M.creerPrive")[1].split("function M.rejoindrePrive")[0]:
    e.append("Matchmaking : le duel prive ne reserve pas d'arene")
# Les deux joueurs partent vers l'arene reservee. L'appel porte desormais un 3e argument (le mode
# a niveaux egalises, transporte avec le joueur) : on verifie le FAIT, pas la forme de l'appel.
for attendu in ("teleporter({ player }, acces", "teleporter({ player }, entree.acces"):
    if attendu not in MM:
        e.append("Matchmaking : un des deux joueurs n'est pas envoye dans l'arene -> " + attendu)
if "SetAsync(code," not in MM or "GetAsync(code)" not in MM:
    e.append("Matchmaking : le code n'est pas partage entre les serveurs")
if "entree.hote == tostring(player.UserId)" not in MM:
    e.append("Matchmaking : on pourrait rejoindre son PROPRE code")
if 'Prive().expire(entree.t' not in MM:
    e.append("Matchmaking : un code perime enverrait vers une arene disparue")
if "local function Prive()" not in MM:
    e.append("Matchmaking : le module Prive doit etre charge A L'USAGE (ce fichier tourne hors Roblox au banc)")
if re.search(r'^local Prive = require', MM, re.M):
    e.append("Matchmaking : un require en tete casse l'execution du banc")

# --- BRANCHEMENT SERVEUR ET HUB -----------------------------------------------------------------
if 'action == "duelPrive"' not in GS or 'action == "rejoindreCode"' not in GS:
    e.append("serveur : les deux actions du duel prive ne sont pas exposees")
if "Matchmaking.creerPrive(player" not in GS or "Matchmaking.rejoindrePrive(player, arg)" not in GS:
    e.append("serveur : les actions ne descendent pas jusqu'au matchmaking")
if 'item("ModuleScript", "Prive"' not in B:
    e.append("build : Prive non embarque (le serveur resterait bloque au demarrage)")
if 'InvokeServer("duelPrive"' not in HUB or 'InvokeServer("rejoindreCode"' not in HUB:
    e.append("hub : aucun bouton ne cree ni ne rejoint un duel prive")
if "Prive.joli(r.code)" not in HUB:
    e.append("hub : le code n'est pas affiche de facon lisible")
if "Prive.normaliser(champCode.Text)" not in HUB:
    e.append("hub : la saisie de l'ami n'est pas nettoyee avant l'envoi")

# --- UN DUEL ENTRE AMIS NE COMPTE PAS AU CLASSEMENT ------------------------------------------------
# Defaut mesure le 2026-09-21 : la donnee transportee vers le serveur d'un duel prive ne portait QUE
# le mode « egalise ». Un duel prive ordinaire etait donc indiscernable d'une partie classee, et
# rapportait des trophees. La faille rejouee pas a pas :
#   1. A et B creent un duel prive ;  2. B abandonne aussitot ;  3. A empoche les trophees ;
#   4. on inverse les roles, et on recommence — sans jamais affronter un inconnu.
from lupa import LuaRuntime as _L
_D = _L().execute((R / "src/shared/Duel.lua").read_text(encoding="utf-8"))
if _D.compteAuClassement(False, True) is not False:
    e.append("un duel entre amis compte encore au classement : l'echange de victoires reste possible")
if _D.compteAuClassement(True, False) is not False:
    e.append("un duel egalise doit rester hors classement")
if _D.compteAuClassement(False, False) is not True:
    e.append("une partie ordinaire de la file doit compter au classement")
# Le joueur doit le SAVOIR avant de jouer, pas le decouvrir avec zero trophee a la fin.
if _D.libelleHorsClassement(None, True) != _D.LIBELLE_AMICAL or "classement" not in _D.LIBELLE_AMICAL:
    e.append("le duel entre amis n'est pas annonce comme hors classement")
if _D.libelleHorsClassement("EGALISE", True) != "EGALISE":
    e.append("le libelle du mode egalise doit primer (il dit aussi que ca ne compte pas)")
if _D.libelleHorsClassement(None, False) is not None:
    e.append("une partie classee ne doit afficher aucun avertissement")

# Branchement : l'information VOYAGE avec les deux joueurs, et le serveur la lit.
if MM.count("prive = true") < 2:
    e.append("matchmaking : le createur ET l'invite doivent arriver marques « duel entre amis »")
if 'player:SetAttribute("BRR_Prive", true)' not in GS:
    e.append("serveur : le joueur venu d'un duel prive n'est pas reconnu comme tel")
if "Duel.compteAuClassement(Egalise.actif(modeEgalise), entreAmis)" not in GS:
    e.append("serveur : la fin de partie ne tient pas compte du duel entre amis")
_fin = GS.split("local entreAmis = false")[1] if "local entreAmis = false" in GS else ""
if not _fin or _fin.index('j:GetAttribute("BRR_Prive")') > _fin.index("Duel.compteAuClassement("):
    e.append("serveur : le caractere amical n'est pas etabli AVANT de distribuer les recompenses")
if "Duel.libelleHorsClassement(" not in GS:
    e.append("serveur : les joueurs ne sont pas prevenus que le duel ne compte pas")
# Quitter une partie amicale n'est pas fuir un adversaire classe : aucune sanction d'abandon.
if GS.count('GetAttribute("BRR_Prive")') < 4:
    e.append("serveur : quitter ou rester inactif dans un duel entre amis serait sanctionne comme un abandon")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : un code partageable ouvre une arene privee, et toute saisie humaine y arrive")
sys.exit(1 if e else 0)
