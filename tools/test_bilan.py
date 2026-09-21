# -*- coding: utf-8 -*-
"""RECAPITULATIF DE FIN DE MATCH (src/shared/Bilan.lua).

Le defaut corrige : l'ecran de fin ne disait qu'un mot. Un joueur qui perdait ne savait pas
pourquoi, et un joueur qui gagnait n'apprenait rien.

1) Les regles PURES sont EXECUTEES (lupa) : gaspillage d'elixir, degats aux tours, cout moyen,
   et la phrase de conseil (une seule, la plus utile).
2) Le branchement est lu : le serveur compte, envoie le bilan des DEUX camps a la fin, le client
   l'affiche, et build.py embarque le module.
"""
import re, sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
BL = (R / "src/shared/Bilan.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(BL)

# --- ETAT NEUF ----------------------------------------------------------------------------------
b = M.neuf()
if not (b.gaspille == 0 and b.depense == 0 and b.cartes == 0 and b.degatsTours == 0):
    e.append("un bilan neuf doit partir de zero")

# --- GASPILLAGE ---------------------------------------------------------------------------------
M.gaspiller(b, 0.5, 0.5)
if b.gaspille != 0:
    e.append("un elixir entierement recu n'est pas gaspille")
M.gaspiller(b, 0.5, 0.0)   # jauge pleine : tout est perdu
M.gaspiller(b, 0.5, 0.2)   # jauge presque pleine : 0.3 perdu
if abs(b.gaspille - 0.8) > 1e-9:
    e.append(f"gaspillage attendu 0.8, obtenu {b.gaspille}")
M.gaspiller(b, 0.1, 0.4)   # cas impossible (plus recu que donne) : ne doit rien retirer
if abs(b.gaspille - 0.8) > 1e-9:
    e.append("le gaspillage ne doit jamais diminuer")

# --- CARTES ET COUT MOYEN -----------------------------------------------------------------------
c = M.neuf()
if M.coutMoyen(c) != 0:
    e.append("sans carte jouee, le cout moyen doit valoir 0 (et non une division par zero)")
M.jouer(c, 3); M.jouer(c, 5); M.jouer(c, 4)
if c.cartes != 3 or c.depense != 12:
    e.append(f"cartes/depense attendus 3/12, obtenus {c.cartes}/{c.depense}")
if abs(M.coutMoyen(c) - 4) > 1e-9:
    e.append("cout moyen attendu 4")

# --- DEGATS AUX TOURS ---------------------------------------------------------------------------
d = M.neuf()
M.degatsTour(d, 250); M.degatsTour(d, 0); M.degatsTour(d, -50)
if d.degatsTours != 250:
    e.append(f"seuls les degats positifs comptent, obtenu {d.degatsTours}")

# --- VUE ENVOYEE AU CLIENT ----------------------------------------------------------------------
v = M.vue(c)
if v.cartes != 3 or v.depense != 12 or v.coutMoyen != 4.0:
    e.append("la vue doit porter des nombres deja arrondis")
g = M.neuf(); M.gaspiller(g, 7.46, 0)
if M.vue(g).gaspille != 7:
    e.append("le gaspillage affiche doit etre arrondi au plus proche")
if M.vue(None) is not None:
    e.append("aucun bilan : aucune vue")

# --- LE CONSEIL : UN SEUL, LE PLUS UTILE --------------------------------------------------------
gros = M.neuf(); M.gaspiller(gros, 20, 0); M.jouer(gros, 3)
autre = M.neuf(); M.jouer(autre, 3); M.degatsTour(autre, 500)
msg = M.conseil(gros, autre)
if "20 elixir" not in msg or "deborder" not in msg:
    e.append(f"un gros gaspillage doit primer sur tout le reste, obtenu : {msg}")
passif = M.neuf(); M.jouer(passif, 3)
msg = M.conseil(passif, autre)
if "Aucun degat" not in msg:
    e.append(f"n'avoir jamais touche ses tours doit etre dit, obtenu : {msg}")
lourd = M.neuf(); M.jouer(lourd, 6); M.degatsTour(lourd, 10)
leger = M.neuf(); M.jouer(leger, 2); M.degatsTour(leger, 10)
msg = M.conseil(lourd, leger)
if "vitesse" not in msg:
    e.append(f"un deck bien plus lourd doit etre signale, obtenu : {msg}")
moyen = M.neuf(); M.gaspiller(moyen, 7, 0); M.jouer(moyen, 3); M.degatsTour(moyen, 10)
msg = M.conseil(moyen, leger)
if "7 elixir gaspille" not in msg:
    e.append(f"un gaspillage notable doit etre rappele, obtenu : {msg}")
propre = M.neuf(); M.jouer(propre, 3); M.degatsTour(propre, 800)
msg = M.conseil(propre, leger)
if "Bonne gestion" not in msg:
    e.append(f"une partie bien geree doit etre saluee, obtenu : {msg}")
vide = M.neuf(); M.degatsTour(vide, 5200)
msg = M.conseil(vide, M.neuf())
if "Bonne gestion" in msg or "trop courte" not in msg:
    e.append(f"0 carte jouee : aucun compliment sur un bilan vide, obtenu : {msg}")
if M.texteCout(M.vue(vide)) != "    -":
    e.append("0 carte jouee : le cout moyen s'ecrit « - », pas 0.0")
if M.texteCout(M.vue(propre)) != "  3.0":
    e.append(f"cout moyen normal sur 5 caracteres, obtenu : {M.texteCout(M.vue(propre))!r}")
if M.conseil(None, None) is not None:
    e.append("sans bilan, aucun conseil")

# --- GASPILLAGE DIT PENDANT LA PARTIE -----------------------------------------------------------
# Le bilan de fin arrive trop tard pour corriger la faute : elle se dit quand la jauge deborde.
if M.alerteGaspillage(5, False) is not None:
    e.append("hors debordement, on ne doit RIEN dire (rappeler un gaspillage passe ne corrige rien)")
if M.alerteGaspillage(0, True) is None:
    e.append("jauge pleine sans perte encore comptee : il faut quand meme inviter a jouer")
sans_perte = M.alerteGaspillage(0, True)
if "PLEINE" not in sans_perte or "elixir perdu" in sans_perte:
    e.append(f"sans perte, on invite a jouer sans accuser : {sans_perte}")
un = M.alerteGaspillage(1, True)
if "1 elixir perdu" not in un or "perdus" in un:
    e.append(f"au singulier, pas de « s » parasite : {un}")
trois = M.alerteGaspillage(3.4, True)
if "3 elixir perdus" not in trois:
    e.append(f"la perte s'arrondit et se met au pluriel : {trois}")
if M.alerteGaspillage(2.6, True) == M.alerteGaspillage(2.4, True):
    e.append("l'arrondi doit etre au plus proche, pas tronque")
if M.niveauGaspillage(0) != "leger" or M.niveauGaspillage(M.SEUIL_ROUGE) != "grave":
    e.append("la gravite doit basculer au seuil (un accident n'est pas une habitude)")
if M.niveauGaspillage(None) != "leger":
    e.append("sans mesure, on ne dramatise pas")

# --- BRANCHEMENT SERVEUR ------------------------------------------------------------------------
if 'WaitForChild("Bilan")' not in S:
    e.append("serveur : module Bilan non requis")
if 'item("ModuleScript", "Bilan"' not in B:
    e.append("build : Bilan non embarque (serveur et client resteraient bloques)")
if "bilan = Bilan.neuf()" not in S:
    e.append("serveur : aucun bilan ouvert au debut de partie")
if "Bilan.gaspiller(t.bilan, gain, t.elixir - avant)" not in S:
    e.append("serveur : l'elixir qui deborde n'est pas compte")
if "Bilan.jouer(t.bilan, card.cost)" not in S:
    e.append("serveur : les cartes jouees ne sont pas comptees")
if "Bilan.degatsTour(auteur.bilan" not in S:
    e.append("serveur : les degats sur les tours ne sont pas attribues")
if not re.search(r"local auteur = teams\[3 - target\.team\]", S):
    e.append("serveur : les degats d'une tour seraient portes au mauvais camp")
for champ in ("bilanMoi = result and Bilan.vue(teams[monCamp].bilan)",
              "bilanLui = result and Bilan.vue(teams[3 - monCamp].bilan)",
              "conseil = result and Bilan.conseil(teams[monCamp].bilan"):
    if champ not in S:
        e.append("serveur : champ manquant dans l'etat de fin -> " + champ)

# --- BRANCHEMENT CLIENT -------------------------------------------------------------------------
if "gaspilleEnCours = teams[monCamp].bilan" not in S:
    e.append("serveur : le gaspillage en cours n'est pas envoye (le joueur ne l'apprendrait qu'a la fin)")
if "Bilan.alerteGaspillage(s.gaspilleEnCours, plein)" not in C:
    e.append("client : le gaspillage n'est pas dit au moment du debordement")
if "gaspilleLabel.Visible = texte ~= nil and not s.result" not in C:
    e.append("client : l'avertissement resterait affiche apres la fin de partie")
if "Bilan.niveauGaspillage(s.gaspilleEnCours)" not in C:
    e.append("client : la couleur ne suit pas la gravite")
if "majBilan(s)" not in C:
    e.append("client : le recapitulatif n'est jamais mis a jour")
for mot in ("Cartes jouees", "Elixir GASPILLE", "Degats sur ses tours", "Cout moyen"):
    if mot not in C:
        e.append("client : ligne absente du recapitulatif -> " + mot)
if "s.conseil" not in C:
    e.append("client : la phrase de conseil n'est pas affichee")
if not re.search(r"bilanCadre\.Visible = s\.result ~= nil", C):
    e.append("client : le recapitulatif s'afficherait hors de l'ecran de fin")
if "restart.Position = UDim2.new(0.5, -110, 0.55, 0)" in C:
    e.append("client : le bouton Rejouer recouvre le recapitulatif")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : le recapitulatif compte, explique, et tient dans l'ecran de fin")
sys.exit(1 if e else 0)
