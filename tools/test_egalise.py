# -*- coding: utf-8 -*-
"""DUEL A NIVEAUX EGALISES (src/shared/Egalise.lua + branchement).

Le defaut corrige : un duel se joue toujours avec les niveaux de chacun. Entre deux amis dont l'un
joue depuis six mois, l'ecart decide la partie avant le premier coup (+40 % de PV et de degats au
niveau 5) : on ne peut jamais savoir QUI JOUE LE MIEUX.

1) Les regles PURES sont EXECUTEES (lupa) : egalisation des deux camps, prudence du declencheur,
   ecart supprime, exclusion du classement.
2) Le branchement est lu : le mode voyage avec le joueur (donnee de teleportation), s'applique aux
   DEUX camps ET au robot, se voit a l'ecran, et ne verse aucune recompense de classement.
"""
import sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
EG = (R / "src/shared/Egalise.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
MM = (R / "src/server/Matchmaking.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
HUB = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(EG)
L = lua.eval
def ids(*noms):
    t = L("function() return {} end")()
    for i, n in enumerate(noms, 1):
        t[i] = n
    return t
def niveaux(**kv):
    t = L("function() return {} end")()
    for k, v in kv.items():
        t[k] = v
    return t

# --- LE DECLENCHEUR EST PRUDENT -----------------------------------------------------------------
if M.actif(True) is not True:
    e.append("le mode doit s'armer sur un vrai oui")
for valeur in (None, False, 0, 1, "oui", "true"):
    if M.actif(valeur) is not False:
        e.append(f"le mode ne doit PAS s'armer sur {valeur!r} (on n'egalise jamais une partie classee par accident)")

# --- EGALISATION DES DEUX CAMPS -----------------------------------------------------------------
mien = niveaux(a=5, b=4, c=1)
hors = M.niveaux(mien, ids("a", "b", "c"), False)
if hors.a != 5 or hors.c != 1:
    e.append("hors mode, les niveaux du joueur doivent etre rendus TELS QUELS")
dans = M.niveaux(mien, ids("a", "b", "c"), True)
for carte in ("a", "b", "c"):
    if dans[carte] != M.NIVEAU:
        e.append(f"en mode egalise, {carte} devrait etre au niveau {M.NIVEAU}, obtenu {dans[carte]}")
# Le joueur le plus avance est RAMENE, pas seulement les faibles remontes.
if dans.a >= mien.a:
    e.append("une carte de niveau 5 doit REDESCENDRE au niveau de reference")
if dans.c <= mien.c:
    e.append("une carte de niveau 1 doit MONTER au niveau de reference")
# Une carte hors de la liste n'est pas inventee.
if dans.z is not None:
    e.append("aucune carte ne doit apparaitre hors de la liste fournie")
# Un joueur sans niveaux enregistres obtient quand meme le niveau de reference.
vide = M.niveaux(None, ids("a"), True)
if vide.a != M.NIVEAU:
    e.append("un joueur neuf doit lui aussi etre egalise")
if M.NIVEAU < 2:
    e.append("un niveau de reference a 1 allonge les parties (les tours tiennent trop longtemps)")

# --- ECART SUPPRIME -----------------------------------------------------------------------------
moyen = L("""function(niv, liste)
  local total, n = 0, 0
  for _, id in ipairs(liste) do total = total + (niv[id] or 1) n = n + 1 end
  if n == 0 then return 1 end
  return total / n
end""")
ecart = M.ecartSupprime(niveaux(a=5, b=5), niveaux(a=1, b=1), ids("a", "b"), moyen)
if abs(ecart - 4) > 1e-9:
    e.append(f"l'ecart annonce devrait valoir 4, obtenu {ecart}")
if M.ecartSupprime(niveaux(a=3), niveaux(a=3), ids("a"), moyen) != 0:
    e.append("deux camps identiques n'ont aucun ecart a supprimer")
if M.ecartSupprime(None, None, None, None) != 0:
    e.append("sans fonction de moyenne, on rend 0 au lieu de planter")

# --- CE QU'ON AFFICHE, ET LE CLASSEMENT ---------------------------------------------------------
if M.libelle(False) is not None:
    e.append("hors mode, aucun bandeau ne doit s'afficher")
lib = M.libelle(True)
if not lib or "EGALIS" not in lib.upper() or str(M.NIVEAU) not in lib:
    e.append(f"le bandeau doit nommer le mode ET le niveau, obtenu : {lib}")
if M.compteAuClassement(True) is not False:
    e.append("un duel egalise ne doit PAS compter au classement (les trophees mesurent aussi l'inventaire)")
if M.compteAuClassement(False) is not True:
    e.append("un duel normal doit continuer a compter")

# --- BRANCHEMENT --------------------------------------------------------------------------------
if 'item("ModuleScript", "Egalise"' not in B:
    e.append("build : Egalise non embarque")
if 'WaitForChild("Egalise")' not in S:
    e.append("serveur : module Egalise non requis")
if "local function niveauxDe(player)" not in S:
    e.append("serveur : aucun point unique pour les niveaux (un chemin oublierait le mode)")
if S.count("niveauxDe(") < 4:
    e.append("serveur : tous les chemins d'attribution de niveaux ne passent pas par niveauxDe")
if "Economie.niveaux(player)" in S.split("local function niveauxDe")[1].split("local function")[1]:
    e.append("serveur : un chemin lit encore les niveaux du joueur directement")
if "Egalise.actif(modeEgalise) and Egalise.NIVEAU or Economie.niveauRobot" not in S:
    e.append("serveur : le ROBOT garderait son niveau d'origine (camp avantage)")
if "GetJoinData().TeleportData" not in S:
    e.append("serveur : le mode ne peut pas atteindre le serveur reserve")
# (2026-09-21) la decision passe par Duel.compteAuClassement, qui recoit AUSSI le duel entre amis.
if "Duel.compteAuClassement(Egalise.actif(modeEgalise)" not in S:
    e.append("serveur : un duel egalise verserait des trophees")
# (2026-09-21) le libelle egalise passe par Duel.libelleHorsClassement, ou il PRIME.
if "Duel.libelleHorsClassement(Egalise.libelle(Egalise.actif(modeEgalise))" not in S:
    e.append("serveur : le mode n'est pas annonce au client")
if "options:SetTeleportData(donnees)" not in MM:
    e.append("matchmaking : le mode ne voyage pas avec le joueur")
if "egalise = egalise == true }, Prive().DUREE)" not in MM:
    e.append("matchmaking : le code prive ne porte pas le mode (l'invite arriverait en duel normal)")
# (2026-09-21) la donnee porte aussi « prive = true » : on verifie que le MODE y est toujours.
if "teleporter({ player }, entree.acces, { egalise = entree.egalise == true" not in MM:
    e.append("matchmaking : l'invite partirait sans le mode de l'hote")
# Le libelle du mode prime sur le lieu affiche (arene + decor) : on verifie qu'il PRIME, sans
# figer la facon dont le lieu est compose.
if "s.egalise or lieu" not in C and "s.egalise or s.arene" not in C:
    e.append("client : le mode n'est pas visible en partie")
if "boutonEgalise" not in HUB or '"duelPrive", egaliseActif and "egalise" or nil' not in HUB:
    e.append("hub : aucun moyen de creer un duel egalise")

# --- LE MODE NE DOIT PAS SURVIVRE A LA PARTIE -----------------------------------------------------
# Defaut mesure le 2026-09-21 en inventoriant les etats du serveur : `modeEgalise` passait a vrai a
# l'arrivee d'un joueur venu d'un duel prive egalise, et n'etait JAMAIS remis a faux. Une seule
# arrivee egalisait donc TOUTES les parties suivantes du serveur — et comme un duel egalise ne
# compte pas au classement, plus personne n'y gagnait de trophee.
reset = S.split("local function resetMatch()")[1].split("buildArena()")[0]
if "modeEgalise = false" not in reset:
    e.append("serveur : le mode egalise survit a la partie, plus aucun trophee ensuite")
# Il est RECALCULE depuis les joueurs reellement presents : une revanche entre les deux memes
# joueurs reste egalisee, une partie avec quelqu'un d'autre ne l'est pas.
if 'occupant[camp]:GetAttribute("BRR_Egalise")' not in reset:
    e.append("serveur : le mode n'est pas recalcule depuis les joueurs presents")
if 'player:SetAttribute("BRR_Egalise", true)' not in S:
    e.append("serveur : le joueur venu d'un duel egalise n'est pas marque, le mode serait perdu")
# Garde-fou : le mode ne doit pas etre allume par autre chose que la donnee de teleportation.
# Deux allumages seulement, et pas un de plus : le recalcul dans resetMatch, et l'arrivee d'un
# joueur venu d'un duel prive egalise. Tout autre endroit le rendrait a nouveau incontrolable.
if (S.count("modeEgalise = true") - reset.count("modeEgalise = true")) != 1:
    e.append("serveur : le mode egalise est allume ailleurs qu'a l'arrivee du joueur")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : les deux camps au meme niveau, robot compris, et hors classement — c'est dit")
sys.exit(1 if e else 0)
