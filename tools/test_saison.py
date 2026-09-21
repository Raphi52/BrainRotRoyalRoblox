# -*- coding: utf-8 -*-
"""SAISONS DE CLASSEMENT (src/shared/Saison.lua + branchement).

Le defaut corrige : les trophees montaient sans fin et ne redescendaient jamais. Le haut du
classement devenait inatteignable pour un nouveau, et les anciens n'avaient plus rien a gagner.

1) Les regles PURES sont EXECUTEES (lupa) : numerotation des saisons, temps restant, remise a zero
   PARTIELLE, recompense sur le SOMMET atteint, rang mondial.
2) Le branchement est lu : la bascule se fait a la connexion, le sommet suit chaque partie, la vue
   du hub et l'etat du duel portent le rang et le temps restant, le client les affiche.
"""
import re, sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
SA = (R / "src/shared/Saison.lua").read_text(encoding="utf-8")
ECO = (R / "src/server/Economie.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(SA)
EPOQUE, DUREE = M.EPOQUE, M.duree()
PLANCHER = M.PLANCHER

# --- NUMEROTATION ET TEMPS RESTANT --------------------------------------------------------------
if M.numero(EPOQUE) != 1:
    e.append("la premiere saison doit porter le numero 1")
if M.numero(EPOQUE + DUREE - 1) != 1 or M.numero(EPOQUE + DUREE) != 2:
    e.append("la saison doit changer exactement a sa duree")
if M.debut(3) != EPOQUE + 2 * DUREE or M.fin(3) != M.debut(4):
    e.append("debut et fin de saison doivent s'enchainer sans trou")
if M.resteSecondes(EPOQUE) != DUREE:
    e.append("au premier instant, tout le temps de la saison doit rester")
if M.resteSecondes(EPOQUE + DUREE) != DUREE:
    e.append("juste apres une bascule, la nouvelle saison repart entiere")
t = M.texteReste(EPOQUE)
if "Saison 1" not in t or " j " not in t:
    e.append(f"le temps restant doit se lire en jours au debut : {t}")
t = M.texteReste(EPOQUE + DUREE - 3600 * 3 - 720)
if " h " not in t or " j " in t:
    e.append(f"le dernier jour, il doit se lire en heures et minutes : {t}")

# --- REMISE A ZERO PARTIELLE --------------------------------------------------------------------
if M.apresRemiseAZero(0) != 0 or M.apresRemiseAZero(PLANCHER) != PLANCHER:
    e.append("sous le plancher, une saison ne doit RIEN retirer (un debutant ne recule jamais)")
if M.apresRemiseAZero(PLANCHER - 50) != PLANCHER - 50:
    e.append("un joueur sous le plancher garde exactement ses trophees")
attendu = PLANCHER + int((3000 - PLANCHER) * M.PART_CONSERVEE + 0.5)
if M.apresRemiseAZero(3000) != attendu:
    e.append(f"remise a zero partielle attendue {attendu}, obtenue {M.apresRemiseAZero(3000)}")
if M.apresRemiseAZero(3000) <= PLANCHER:
    e.append("un joueur au sommet ne doit pas retomber au plancher (tout remettre a zero le punit)")
if M.apresRemiseAZero(3000) >= 3000:
    e.append("la saison doit VRAIMENT faire redescendre, sinon le classement reste fige")

# --- RECOMPENSE SUR LE SOMMET -------------------------------------------------------------------
if M.recompense(0) != 0 or M.recompense(PLANCHER) != 0:
    e.append("sous le plancher, aucune recompense (la saison n'est pas un revenu automatique)")
if M.recompense(PLANCHER + 100) != M.PIECES_PAR_PALIER:
    e.append("un palier de 100 trophees doit payer un palier de pieces")
if M.recompense(PLANCHER + 1050) != 10 * M.PIECES_PAR_PALIER:
    e.append("la recompense doit suivre les paliers atteints")
if M.recompense(2000) <= M.recompense(1000):
    e.append("monter plus haut doit payer plus")

# --- BASCULE ------------------------------------------------------------------------------------
if M.doitTourner(None, EPOQUE + 5 * DUREE) is not False:
    e.append("un profil anterieur aux saisons ne doit RIEN perdre a sa premiere connexion")
if M.doitTourner(1, EPOQUE + 10) is not False:
    e.append("dans la meme saison, rien ne tourne")
if M.doitTourner(1, EPOQUE + DUREE + 10) is not True:
    e.append("a la saison suivante, la bascule doit se declencher")
if M.doitTourner(3, EPOQUE + DUREE) is not False:
    e.append("un profil en avance (horloge douteuse) ne doit pas tourner a l'envers")

# --- RANG ---------------------------------------------------------------------------------------
classement = lua.eval("""function()
  return { { rang = 1, nom = "Alice", trophees = 3000 }, { rang = 2, nom = "Bob", trophees = 2500 } }
end""")()
if M.rang(classement, "Bob") != 2:
    e.append("le rang doit etre lu dans le classement")
if M.rang(classement, "Carole") is not None:
    e.append("hors du tableau, on n'invente AUCUNE position")
if M.rang(None, "Bob") is not None:
    e.append("sans classement, aucun rang")
if M.texteRang(1, 3000) != "1er mondial":
    e.append("le premier doit se lire « 1er mondial »")
if M.texteRang(4, 900) != "4e mondial":
    e.append("les autres rangs se lisent « Ne mondial »")
if "trophees" not in M.texteRang(None, 240):
    e.append("hors du tableau, on affiche les trophees plutot que rien")

# --- BRANCHEMENT ECONOMIE -----------------------------------------------------------------------
if 'WaitForChild("Saison")' not in ECO:
    e.append("economie : module Saison non requis")
if 'item("ModuleScript", "Saison"' not in B:
    e.append("build : Saison non embarque")
if "function Economie.tournerSaison" not in ECO:
    e.append("economie : aucune bascule de saison")
if "Economie.tournerSaison(player, p)" not in ECO:
    e.append("economie : la bascule n'est pas faite a la connexion")
bloc = ECO.split("function Economie.tournerSaison")[1].split("-- Sauvegarde active")[0]
for attendu, quoi in (("Saison.recompense(sommet)", "la recompense n'est pas versee"),
                      ("Saison.apresRemiseAZero(avant)", "les trophees ne sont pas ramenes"),
                      ("p.saison = Saison.numero(maintenant)", "le profil ne retient pas la nouvelle saison"),
                      ("math.max(p.tropheesMax or 0, p.trophees or 0)", "le sommet n'est pas pris en compte")):
    if attendu not in bloc:
        e.append("economie : " + quoi)
if "p.saison == nil then" not in bloc:
    e.append("economie : un profil d'avant les saisons serait remis a zero par surprise")
if "Economie.suivreSommet(p)" not in ECO:
    e.append("economie : le sommet de saison ne suit pas les parties")
if "saison = p.saison" not in ECO or "saisonReste = Saison.texteReste" not in ECO:
    e.append("economie : la vue du hub ne porte pas la saison")

# --- BRANCHEMENT DUEL ---------------------------------------------------------------------------
# --- LE RANG SE CHERCHE PAR IDENTIFIANT, PAS PAR NOM ----------------------------------------------
# Defaut mesure le 2026-09-21 : le rang etait retrouve par NOM D'AFFICHAGE. Or sur Roblox il n'est
# PAS unique (seul le Name l'est) : deux joueurs homonymes recevaient le meme rang mondial, et l'un
# lisait donc le classement de l'autre — dans un jeu ou le rang est justement l'enjeu.
def classement_id():
    return lua.eval("""function()
      return { { rang = 1, id = 11, nom = "Alice", trophees = 3000 },
               { rang = 2, id = 22, nom = "Alice", trophees = 2500 } } end""")()

cl = classement_id()
# Deux « Alice » : seul l'identifiant peut les distinguer.
if M.rang(cl, "Alice", 22) != 2:
    e.append("le rang doit suivre l'IDENTIFIANT, pas le nom (deux homonymes existent)")
if M.rang(cl, "Alice", 11) != 1:
    e.append("chaque homonyme doit recevoir SON rang")
if M.rang(cl, "Alice", 99) is not None:
    e.append("un joueur hors du tableau ne doit pas heriter du rang d'un homonyme")
# Repli : une entree ancienne sans identifiant reste lisible par le nom.
vieux = lua.eval('function() return { { rang = 3, nom = "Bob", trophees = 100 } } end')()
if M.rang(vieux, "Bob", 42) != 3:
    e.append("sans identifiant dans le classement, le nom doit encore servir de repli")

# Le classement doit PORTER l'identifiant : il etait calcule puis jete.
if "id = uid," not in ECO:
    e.append("economie : le classement ne porte pas l'identifiant, le rang restera ambigu")
# Et le serveur doit le passer.
if "Saison.rang(Economie.classement(), player.DisplayName, player.UserId)" not in S:
    e.append("serveur : l'identifiant du joueur n'est pas utilise pour chercher son rang")

if "Saison.texteRang(Saison.rang(Economie.classement()" not in S:
    e.append("serveur : le rang n'est pas envoye pendant le duel")
if "saisonReste = Saison.texteReste(os.time())" not in S:
    e.append("serveur : le temps restant de saison n'est pas envoye au duel")
if "saisonLabel" not in C:
    e.append("client : aucun affichage du rang en partie")
if not re.search(r"saisonLabel\.Text = \(not s\.spectateur and s\.rang\)", C):
    e.append("client : le spectateur verrait un rang qui n'est pas le sien")

# --- LA SAISON SE VOIT AU MENU ------------------------------------------------------------------
# Defaut mesure le 2026-09-20 : le numero de saison, le temps restant ET le sommet atteint etaient
# calcules, envoyes au menu (Economie.vue)... et affiches NULLE PART. Or c'est le SOMMET, pas le
# solde du moment, qui decide la recompense de fin de saison : le joueur ne savait ni qu'une saison
# tournait, ni quand elle finit, ni ce qu'il avait deja verrouille. Il decouvrait la remise a zero.
ligne = M.texteSaison(45, M.texteReste(0), 700)
for bout in ("Saison ", "sommet 700"):
    if bout not in ligne:
        e.append("la ligne de saison ne porte pas " + bout)
# `texteReste` porte DEJA le numero : le prefixer donnait « Saison 45 - Saison 45 : 2 j 02 h »
# (vu a l'ecran le 2026-09-20).
if ligne.count("Saison") != 1:
    e.append("le numero de saison est repete : " + ligne)
# Elle annonce ce que le sommet RAPPORTE, avec la meme regle que le versement.
gain = M.recompense(700)
if gain > 0 and (str(int(gain)) + " pieces") not in ligne:
    e.append("la ligne n'annonce pas la recompense du sommet (%s)" % gain)
if M.recompense(50) != 0 or "pieces" in M.texteSaison(45, "", 50):
    e.append("un sommet sous le plancher ne doit rien promettre")
# Sans temps restant (profil ancien), la ligne reste lisible.
if "Saison 45" not in M.texteSaison(45, None, 0):
    e.append("la ligne doit tenir meme sans temps restant")

H = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
if 'WaitForChild("Saison")' not in H:
    e.append("hub : le module de saison n'est pas charge")
if "montee.saison.Text = Saison.texteSaison(v.saison, v.saisonReste, v.tropheesMax)" not in H:
    e.append("hub : la ligne de saison n'est pas affichee au menu")
E = (R / "src/server/Economie.lua").read_text(encoding="utf-8")
if "tropheesMax = math.max(p.tropheesMax or 0, p.trophees or 0)" not in E:
    e.append("economie : le sommet n'est pas envoye au menu")

# --- BILAN DE FIN DE SAISON, ANNONCE AU JOUEUR --------------------------------------------------
# Defaut mesure le 2026-09-20 : la bascule a lieu au CHARGEMENT du profil. Les trophees sont
# ramenes vers le plancher et des pieces sont versees... en silence. Le joueur rouvrait le jeu avec
# des centaines de trophees en moins sans un mot : la punition se voyait, la recompense non.
bilan = lua.eval("(function(s, so, pi, av, ap) return { saison = s, sommet = so, pieces = pi, "
                 "avant = av, apres = ap } end)")(44, 940, M.recompense(940), 940,
                                                  M.apresRemiseAZero(940))
lignes = list(M.lignesBilan(bilan).values())
if len(lignes) != 4:
    e.append("le bilan doit tenir en quatre lignes, obtenu %d" % len(lignes))
tout = " | ".join(lignes)
for bout in ("Saison 44", "940", str(int(M.recompense(940))) + " pieces", str(int(M.apresRemiseAZero(940)))):
    if bout not in tout:
        e.append("le bilan ne porte pas " + bout)
# Sous le plancher, la saison ne recompense pas : le DIRE evite de croire a un oubli.
petit = lua.eval("(function(s, so, pi, av, ap) return { saison = s, sommet = so, pieces = pi, "
                 "avant = av, apres = ap } end)")(44, 100, 0, 100, M.apresRemiseAZero(100))
if "aucune" not in " ".join(list(M.lignesBilan(petit).values())):
    e.append("un sommet sous le plancher doit dire qu'il n'y a pas de recompense")
if len(list(M.lignesBilan(None).values())) != 0:
    e.append("sans bilan, aucune ligne")

# Le serveur le GARDE, l'ecran le montre, puis il est OUBLIE (sinon il revient a chaque ouverture).
E2 = (R / "src/server/Economie.lua").read_text(encoding="utf-8")
if "p.bilanSaison = { saison = Saison.numero(maintenant) - 1" not in E2:
    e.append("economie : le bilan de saison n'est pas garde au moment de la bascule")
if "bilanSaison = p.bilanSaison," not in E2:
    e.append("economie : le bilan n'est pas envoye au menu")
if "function Economie.oublierBilanSaison(player)" not in E2:
    e.append("economie : rien ne permet d'oublier le bilan une fois montre")
S2 = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
if 'elseif action == "saisonVue" then' not in S2:
    e.append("serveur : l'ecran ne peut pas signaler qu'il a montre le bilan")
H2 = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
if "Saison.lignesBilan(v.bilanSaison)" not in H2:
    e.append("hub : le bilan n'est pas affiche")
if 'Boutique:InvokeServer("saisonVue")' not in H2:
    e.append("hub : le bilan ne serait jamais oublie, il reviendrait a chaque ouverture")
if "not finSaison.montre" not in H2:
    e.append("hub : le panneau se rouvrirait a chaque rafraichissement du profil")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : la saison redistribue les cartes sans punir personne, et le rang se voit en duel")
sys.exit(1 if e else 0)
