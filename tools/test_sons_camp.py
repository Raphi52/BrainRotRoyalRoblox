# -*- coding: utf-8 -*-
"""LE SON DIT A QUI C'EST (src/shared/Camps.lua + Sons.lua + branchement).

Le defaut corrige : une unite qui meurt sonnait EXACTEMENT pareil qu'elle soit a moi ou a
l'adversaire. En melee, l'oreille n'apprenait rien — on ne savait plus qui etait en train de perdre.

1) Les regles PURES sont EXECUTEES (lupa) : volume et hauteur selon le camp, neutralite du
   spectateur, et la banque de sons qui accepte une hauteur relative.
2) Le branchement est lu : le serveur compte le combat PAR CAMP, le client lit le camp de l'unite
   morte et ne secoue la camera que pour SES pertes.
"""
import sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
CA = (R / "src/shared/Camps.lua").read_text(encoding="utf-8")
SO = (R / "src/shared/Sons.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(CA)

# --- CE QUI M'ARRIVE SONNE AUTREMENT ------------------------------------------------------------
if M.volumeSon(1, 1) <= M.volumeSon(2, 1):
    e.append("ses propres unites doivent s'entendre PLUS que celles d'en face")
if M.vitesseSon(1, 1) >= M.vitesseSon(2, 1):
    e.append("ses propres unites doivent sonner plus GRAVE que celles d'en face")
# Le camp 2 doit vivre exactement la meme chose de son point de vue.
if M.volumeSon(2, 2) != M.volumeSon(1, 1) or M.vitesseSon(2, 2) != M.vitesseSon(1, 1):
    e.append("le joueur du camp 2 doit entendre SES unites comme le camp 1 entend les siennes")
if M.volumeSon(1, 2) != M.volumeSon(2, 1) or M.vitesseSon(1, 2) != M.vitesseSon(2, 1):
    e.append("l'adversaire doit sonner pareil des deux cotes")
# Spectateur : aucun camp n'est « le sien », on ne favorise personne.
for vu in (0, None):
    if M.volumeSon(1, vu) != 1 or M.vitesseSon(1, vu) != 1 or M.volumeSon(2, vu) != 1:
        e.append("le spectateur ne doit entendre aucun camp favorise")
# Les ecarts doivent etre AUDIBLES sans etre ridicules.
if not (0.5 <= M.VOLUME_ENNEMI <= 0.9):
    e.append("l'ecart de volume doit rester audible sans rendre l'adversaire muet")
if not (0.75 <= M.VITESSE_AMI < 1 < M.VITESSE_ENNEMI <= 1.35):
    e.append("les hauteurs doivent encadrer la normale, sans caricature")

# --- LA BANQUE DE SONS ACCEPTE UNE HAUTEUR ------------------------------------------------------
if "function Sons.jouer(nom, volumeRelatif, vitesseRelative)" not in SO:
    e.append("Sons.jouer n'accepte pas de hauteur relative")
if "e[3] * (vitesseRelative or 1)" not in SO:
    e.append("la hauteur relative n'est pas appliquee")
if "e[2] * (volumeRelatif or 1)" not in SO:
    e.append("le volume relatif a ete perdu au passage")

# --- BRANCHEMENT SERVEUR ------------------------------------------------------------------------
if "local combatCamp" not in S:
    e.append("serveur : le combat n'est pas compte par camp")
for champ in ("combatMoi = combatCamp[monCamp]", "combatLui = combatCamp[3 - monCamp]"):
    if champ not in S:
        e.append("serveur : champ manquant -> " + champ)
if "combat = combat," not in S:
    e.append("serveur : le total a disparu (ce qui le lit ailleurs casserait)")
if "mien.zones = mien.zones + 1" not in S or "mien.tirs = mien.tirs + 1" not in S:
    e.append("serveur : les compteurs par camp ne sont pas alimentes")

# --- BRANCHEMENT CLIENT -------------------------------------------------------------------------
if 'enfant:GetAttribute("Camp")' not in C:
    e.append("client : le camp de l'unite morte n'est pas lu")
if "Camps.volumeSon(camp, vu), Camps.vitesseSon(camp, vu)" not in C:
    e.append("client : la mort sonne pareil pour les deux camps")
if "Camps.estAmi(camp, vu) ~= false" not in C:
    e.append("client : la camera tremblerait aussi pour les pertes de l'adversaire")
if "combatPrecMoi" not in C or "combatPrecLui" not in C:
    e.append("client : un seul compteur pour les deux camps (impossible de les distinguer)")
if 'Sons.jouer("explosion", vol, vit)' not in C:
    e.append("client : les sons de combat ne portent pas la couleur du camp")
if "local campEnFace = (vuSon == 0) and 0 or (3 - vuSon)" not in C:
    e.append("client : le piege Lua du zero (0 est VRAI) donnerait un camp inexistant au spectateur")
if 'Sons.jouer("explosion")' in C:
    e.append("client : un appel sans camp subsiste (son indifferencie)")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : ce qui m'arrive et ce qui arrive en face ne sonnent plus pareil")
sys.exit(1 if e else 0)
