# -*- coding: utf-8 -*-
"""PHOTO DE PROFIL DES DEUX JOUEURS (src/shared/Profil.lua).

Le defaut corrige : en duel, l'adversaire n'etait qu'un NOM. Rien ne donnait le sentiment
d'affronter quelqu'un.

CE QUI N'EST PAS PROMIS : que la photo arrive. La recuperer est un appel RESEAU qui peut etre
lent, echouer, ou ne rien rendre hors ligne — c'est le cas dans Studio. Le banc verifie donc
SURTOUT ce cas-la : il doit toujours rester quelque chose a l'ecran.

1) Regles PURES executees (lupa) : quoi demander, quoi afficher sans photo, pastille stable et
   neutre, robot traite a part, taille et seuil d'affichage.
2) Branchement lu : module embarque, identifiant de compte envoye par le serveur, client qui
   demande la photo sans bloquer et retombe sur la pastille.
"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import zone  # decoupe par CONTENU (voir tools/bancs.py)
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
PR = (R / "src/shared/Profil.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(PR)

# --- QUOI DEMANDER -------------------------------------------------------------------------------
if M.demande(12345, False).type != "joueur" or M.demande(12345, False).userId != 12345:
    e.append("un joueur avec un compte doit donner lieu a une demande de photo")
# LE ROBOT N'A PAS DE COMPTE : lui chercher une photo, ou lui inventer un identifiant d'image,
# serait inventer un contrat externe.
if M.demande(12345, True).type != "robot":
    e.append("le robot ne doit jamais declencher de demande de photo")
for absent in (None, 0, -5, "abc"):
    if M.demande(absent, False).type != "aucun":
        e.append("un identifiant absent ou invalide (%r) doit etre traite comme tel" % (absent,))

# --- LE CAS QUI COMPTE : PAS DE PHOTO ------------------------------------------------------------
# Un carre vide ressemble a un bug, un carre gris ne dit pas qui c'est : il faut l'initiale.
for image in (None, "", 42, False):
    vue = M.vue("Zoe", False, image)
    if vue.texte != "Z":
        e.append("sans photo (%r), la pastille doit porter l'initiale, pas %r" % (image, vue.texte))
    if vue.image is not None:
        e.append("sans photo (%r), aucune image ne doit etre posee" % (image,))
# Avec une photo, l'initiale s'efface — sinon la lettre resterait par-dessus le visage.
vue = M.vue("Zoe", False, "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150")
if not vue.image or vue.texte != "":
    e.append("avec une photo, l'image doit etre posee et l'initiale effacee")

# --- INITIALES : aucun nom ne doit produire une pastille vide -------------------------------------
for nom, attendu in (("zoe", "Z"), ("Zoe", "Z"), ("_alex", "A"), ("42Tom", "T"),
                     ("123", "1"), ("", "?"), (None, "?"), ("   ", "?")):
    if M.initiale(nom) != attendu:
        e.append("initiale de %r : %r au lieu de %r" % (nom, M.initiale(nom), attendu))

# --- COULEUR DE REPLI : stable, et NEUTRE ---------------------------------------------------------
if [M.couleurRepli("Zoe")[i] for i in (1, 2, 3)] != [M.couleurRepli("Zoe")[i] for i in (1, 2, 3)]:
    e.append("la couleur de pastille doit etre stable pour un meme joueur")
vues = {tuple(M.couleurRepli(n)[i] for i in (1, 2, 3))
        for n in ("Zoe", "Alex", "Tom", "Lea", "Max", "Nina", "Paul", "Eva")}
if len(vues) < 3:
    e.append("les pastilles de repli se ressemblent toutes : %r" % (vues,))
# Surtout pas bleu ni rouge franc : ces deux couleurs disent deja le CAMP ailleurs a l'ecran.
for c in vues:
    r, v, b = c
    if (b > r + 60 and b > 150) or (r > b + 60 and r > 150):
        e.append("une pastille de repli imite une couleur de camp : %r" % (c,))

# --- LE ROBOT NE DOIT PAS PASSER POUR UN HUMAIN ---------------------------------------------------
rob = M.replis("Robot (debutant)", True)
hum = M.replis("Robert", False)
if rob.texte == M.initiale("Robot (debutant)"):
    e.append("le robot porte une initiale comme un joueur : on le prendrait pour un humain")
if rob.texte == hum.texte:
    e.append("robot et joueur affichent le meme signe")
if [rob.couleur[i] for i in (1, 2, 3)] != [M.COULEUR_ROBOT[i] for i in (1, 2, 3)]:
    e.append("la pastille du robot doit avoir sa propre couleur, pas une couleur tiree du nom")

# --- TAILLE ET SEUIL D'AFFICHAGE ------------------------------------------------------------------
if M.taille(26) <= 0 or M.taille(26) < M.TAILLE_MIN:
    e.append("la pastille descend sous sa taille minimale")
if not (M.taille(34) > M.taille(20)):
    e.append("la pastille doit suivre la hauteur de la ligne de score")
if M.taille(9999) > 44:
    e.append("la pastille doit rester bornee, sinon elle mange la ligne de score")
for mauvais in (None, -10, "grand"):
    if M.taille(mauvais) < M.TAILLE_MIN:
        e.append("une hauteur aberrante (%r) produit une pastille minuscule" % (mauvais,))
# Sur un ecran serre, les pastilles cedent : la ligne de score ne se laisse jamais recouvrir.
if M.affichables(200, 26) is not False:
    e.append("sur une bande centrale etroite, les pastilles doivent s'effacer")
if M.affichables(460, 26) is not True:
    e.append("sur un ecran normal, les pastilles doivent s'afficher")

# --- BRANCHEMENT ----------------------------------------------------------------------------------
if 'source=src("shared/Profil.lua")' not in B:
    e.append("Profil.lua n'est pas embarque dans la place : le client attendrait le module a l'infini")
if "userIdAdversaire = occupant[3 - monCamp]" not in S:
    e.append("le serveur n'envoie pas l'identifiant de compte de l'adversaire")
if "adversaireEstRobot" not in S:
    e.append("le serveur ne dit pas si l'adversaire est un robot")
if "GetUserThumbnailAsync" not in C:
    e.append("le client ne demande jamais la photo")
# L'appel reseau ne doit bloquer NI l'affichage NI la partie.
bloc = zone(C, "local function chargerPhoto")
if "task.spawn" not in bloc or "pcall" not in bloc:
    e.append("le client bloquerait sur l'appel reseau, ou planterait si la photo echoue")
if "hud.photosVues[userId] ~= nil" not in C:
    e.append("le client redemanderait la meme photo en boucle")
if "Profil.vue(nom, estRobot, image)" not in C:
    e.append("le client n'utilise pas la regle d'affichage : le repli ne serait pas garanti")
# Le client lit les deux cotes par la MEME mecanique : « moi / en face » pour un joueur, « camp 1 /
# camp 2 » pour un spectateur (qui n'a pas de camp). On verifie le fait, pas la forme de l'appel.
if "droiteId, droiteNom, droiteRobot = s.userIdAdversaire, s.nomAdversaire, s.adversaireEstRobot" not in C:
    e.append("le client ne distingue pas un joueur d'un robot en face")
if "Profil.demande(droiteId, droiteRobot)" not in C:
    e.append("le cote adverse ne passe pas par la regle")
# DUEL HUMAIN CONTRE HUMAIN : les deux pastilles doivent viser des comptes DIFFERENTS. Si les
# deux demandaient la meme photo, on verrait son propre visage des deux cotes.
corps = zone(C, "local function majProfils")
if "gaucheId, gaucheNom, gaucheRobot = player.UserId, player.DisplayName, false" not in corps:
    e.append("le client ne charge pas SA propre photo depuis son compte")
if "chargerPhoto(demandeMoi.userId" not in corps:
    e.append("la pastille de gauche ne demande aucune photo")
if "chargerPhoto(demande.userId" not in corps:
    e.append("le client ne charge pas la photo de l'adversaire depuis SON compte a lui")
if corps.count("chargerPhoto(") < 2:
    e.append("une seule photo est demandee : les deux joueurs auraient le meme visage")
if "poserProfil(hud.profilMoi" not in corps or "poserProfil(hud.profilLui" not in corps:
    e.append("les deux pastilles ne sont pas alimentees separement")
if "majProfils(s)" not in C:
    e.append("les pastilles ne sont jamais mises a jour")
if "Profil.affichables(" not in C:
    e.append("les pastilles s'afficheraient meme sans place pour elles")
# Elles sont ENFANTS du score : elles suivent la mise en page calculee, sans offset a la main.
if "cadre.Parent = crownsLabel" not in C:
    e.append("les pastilles ne suivent pas la place calculee pour la ligne de score")

if e:
    print("ROUGE : photo de profil des deux joueurs")
    for m in e:
        print("  - " + m)
    sys.exit(1)
print("VERT : photos de profil (repli garanti sans reseau, robot distinct, place calculee)")
