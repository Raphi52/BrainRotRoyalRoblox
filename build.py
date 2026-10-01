"""Genere BrainRotRoyale.rbxlx (ouvrable directement dans Roblox Studio) depuis src/."""
import json
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).parent
ref = 0
AUTOTEST = "--autotest" in sys.argv
JOUEURS = 3 if "--trois-joueurs" in sys.argv else (2 if "--deux-joueurs" in sys.argv else 1)
COURT = AUTOTEST and "--court" in sys.argv  # partie de 40 s, pour verifier la fin de partie
PARTIE = AUTOTEST and "--partie" in sys.argv  # capture d'une partie normale : ni rangee de test ni trio immobile
GROSPLAN = AUTOTEST and "--grosplan" in sys.argv  # camera face a la rangee de test
GALERIE = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--galerie=")), "") if AUTOTEST else ""
MELEE = AUTOTEST and "--melee" in sys.argv  # robots en rafale : capture d'une melee (implique --partie)
PARTIE = PARTIE or MELEE
HUB = AUTOTEST and "--hub" in sys.argv  # copie de test avec l'accueil ouvert
BOUTIQUE = AUTOTEST and "--boutique" in sys.argv  # accueil + boutique ouverte, pour la capture
# --champion (Roi Tralalero) ou --champion=Id : champion pose, ENNEMIS colles a lui, capacite activee
CHAMPION = next((a.split("=", 1)[1] if "=" in a else "RoiTralalero" for a in sys.argv
                 if a == "--champion" or a.startswith("--champion=")), "") if AUTOTEST else ""
COSMETIQUES = AUTOTEST and "--cosmetiques" in sys.argv  # gemmes offertes + ecran cosmetiques ouvert
SKIN = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--skin=")), "") if AUTOTEST else ""  # skin possede et equipe
PASS_PREMIUM = AUTOTEST and "--pass-premium" in sys.argv  # piste premium ouverte sans achat
VIP_NON_POSSEDE = AUTOTEST and "--vip-non-possede" in sys.argv  # le createur possede le VIP : l'offre serait masquee
PASS_POINTS = next((int(a.split("=", 1)[1]) for a in sys.argv if a.startswith("--pass-points=")), 0) if AUTOTEST else 0
OUVERTURE = AUTOTEST and "--ouverture" in sys.argv  # coffre pret ouvert tout seul : scene d'ouverture
COFFRES = AUTOTEST and ("--coffres" in sys.argv or OUVERTURE)  # accueil avec des coffres dans chaque etat
DECK = AUTOTEST and "--deck" in sys.argv  # accueil + ecran DECK ouvert, pour la capture
NIVEAUX = AUTOTEST and "--niveaux" in sys.argv  # boutique ouverte avec des niveaux varies
BOUTIQUE = BOUTIQUE or NIVEAUX
DECK_MAX = AUTOTEST and "--deck-max" in sys.argv  # deck entier au niveau maximum
DECK_LEGENDAIRE = AUTOTEST and "--deck-legendaire" in sys.argv  # 2 legendaires possedees et dans le deck
LISTE_BAS = AUTOTEST and "--liste-bas" in sys.argv  # listes defilantes descendues tout en bas
DECK_SORTIE = AUTOTEST and "--deck-sortie" in sys.argv  # deck change puis ecran quitte
DECK_MODIFIE = AUTOTEST and ("--deck-modifie" in sys.argv or DECK_SORTIE)  # deck change sans enregistrer
AIDE_GEMMES = AUTOTEST and "--aide-gemmes" in sys.argv  # bulle d'aide des gemmes ouverte
HUB = HUB or BOUTIQUE or COFFRES or DECK or AIDE_GEMMES
TUTO = AUTOTEST and "--tuto" in sys.argv  # force le tutoriel dans la copie de test, pour la capture
ONGLET = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--onglet=")), "") if AUTOTEST else ""  # onglet du hub a ouvrir pour la capture
HUB = HUB or bool(ONGLET)
APERCU = AUTOTEST and "--apercu" in sys.argv  # fige la visee pour capturer l'apercu de pose
# --apercu=sort : arme une carte de SORT si la main en contient une, pour voir le LISERE de la
# zone totale (un sort vise toute l'arene) plutot que la dalle d'une moitie.
APERCU_SORT = AUTOTEST and "--apercu=sort" in sys.argv
APERCU_PORTEE = AUTOTEST and "--apercu=portee" in sys.argv  # arme un TIREUR, pour voir le cercle de portee
APERCU = APERCU or APERCU_SORT or APERCU_PORTEE
ROBOT = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--robot=")), "") if AUTOTEST else ""  # force un palier de difficulte
PARTIE = PARTIE or APERCU
ECOTEST = AUTOTEST and "--ecotest" in sys.argv  # scenario de test de l'economie
EFFETS = AUTOTEST and "--effets" in sys.argv  # scenario en moteur : batiment, gel, tir qui vole
BOUCLIERS = AUTOTEST and "--boucliers" in sys.argv  # galerie : le meme bouclier a trois etats d'usure
DETAIL = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--detail=")), "") if AUTOTEST else ""  # fiche complete ouverte sur cette carte
REGLES_BAS = AUTOTEST and "--regles-bas" in sys.argv  # manuel deroule en bas, pour photographier les dernieres sections
REGLES = AUTOTEST and ("--regles" in sys.argv or REGLES_BAS)  # ecran des regles ouvert, pour la capture
REGLES_TUTO = AUTOTEST and "--regles-tuto" in sys.argv  # fin du tutoriel : les regles s'ouvrent
REGLES_PARTIE = AUTOTEST and "--regles-partie" in sys.argv  # regles ouvertes EN PLEINE PARTIE (bouton a cote de MENU)
JOURNAL = AUTOTEST and "--journal" in sys.argv  # ecran des dernieres parties ouvert, pour la capture
AMIS = AUTOTEST and "--amis" in sys.argv  # panneau « DUEL ENTRE AMIS » ouvert, pour la capture
SON = AUTOTEST and "--son" in sys.argv  # ecran des reglages sonores ouvert, pour la capture
MAIN_TAGS = AUTOTEST and "--main-etiquettes" in sys.argv  # main des cartes a CHARGE / ASSASSIN, pour la capture
MAIN_COUT = AUTOTEST and "--main-cout" in sys.argv  # main de couts varies + elixir bas, pour la capture
TOURS_ABIMEES = AUTOTEST and "--tours-abimees" in sys.argv  # tours a 75/40/18 %, pour montrer les seuils
BATIMENT = AUTOTEST and "--batiment" in sys.argv  # deux batiments poses : compte a rebours plein et en alerte
CHARGE = AUTOTEST and "--charge" in sys.argv  # deux unites a charge : elan en cours et charge lancee
COURONNE = AUTOTEST and "--couronne" in sys.argv  # abat une tour adverse : message de couronne
TROPHEES = next((int(a.split("=", 1)[1]) for a in sys.argv if a.startswith("--trophees=")), 0) if AUTOTEST else 0
PIECES = int(next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--pieces=")), "0")) if AUTOTEST else 0  # solde pose pour la capture
SPECTATEUR = AUTOTEST and "--spectateur" in sys.argv  # le joueur reste spectateur, pour photographier son refus de pose
SORT_SANS_NIVEAU = AUTOTEST and "--sort-sans-niveau" in sys.argv  # ANCIENNE regle des sorts, pour mesurer l'effet du changement
SORT_NIVEAU = AUTOTEST and "--sort-niveau" in sys.argv  # mesure des degats d'un sort ameliore
DEPLOIEMENT = AUTOTEST and "--deploiement" in sys.argv  # anneaux de deploiement a plusieurs stades
GARDE_MOI = AUTOTEST and "--garde-moi" in sys.argv  # MES deux tours tombees : bandeau or
GARDE = AUTOTEST and "--garde" in sys.argv  # derniere garde engagee, pour la capture
EMOTE_REPOS = AUTOTEST and "--emote-repos" in sys.argv  # deux emotes rapprochees, pour photographier le refus
QUETE_PRETE = AUTOTEST and "--quete-prete" in sys.argv  # une quete du jour finie non reclamee, pour la capture
QUETE = AUTOTEST and "--quete-finie" in sys.argv  # quete du jour terminee en partie, pour la capture
CLICS = next((int(a.split("=")[1]) for a in sys.argv if a.startswith("--clics=")), 0) if AUTOTEST else 0  # clics simules sur le coffre en cours
GEMMES = AUTOTEST and "--gemmes" in sys.argv  # coffre en cours ouvert contre des gemmes
PLEINS = AUTOTEST and "--pleins" in sys.argv  # victoire avec 4 coffres deja en attente
MONTEE = AUTOTEST and "--montee" in sys.argv  # victoire qui franchit un palier d'arene, pour la capture
FIN_SAISON = AUTOTEST and "--fin-saison" in sys.argv  # bilan de fin de saison affiche, pour la capture
PARTIE = PARTIE or BATIMENT or CHARGE or COURONNE  # arene normale (pas la rangee de test)
CAP_DELAI = next((int(a.split("=", 1)[1]) for a in sys.argv if a.startswith("--capture-delai=")), 0) if AUTOTEST else 0
# La fiche complete s'ouvre DANS la boutique : il faut donc aussi forcer l'accueil, sinon la
# copie de test demarre un match (HUB est calcule plus haut, avant que DETAIL existe).
# --detail seul ouvre la BOUTIQUE ; avec --deck, la fiche s'ouvre par-dessus l'ecran DECK.
BOUTIQUE = BOUTIQUE or (bool(DETAIL) and not DECK and not PARTIE)
HUB = HUB or BOUTIQUE or DECK or REGLES or REGLES_TUTO or JOURNAL or bool(TROPHEES) or FIN_SAISON  # l'ecran des regles vit dans l'accueil
SIM = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--sim=")), "") if AUTOTEST else ""  # simulation d'equilibre
DECOR = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--decor=")), "") if AUTOTEST else ""  # force un decor d'arene
ECRAN = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--ecran=")), "") if AUTOTEST else ""  # force un format d'ecran (mise en page compacte)
DUEL = AUTOTEST and "--duel" in sys.argv  # duel humain force : coup d'envoi commun + forfait, en moteur
RUN = AUTOTEST and "--run" in sys.argv      # partie entiere bot contre bot, sans joueur


def item(cls, name, children="", source=None, extra=""):
    global ref
    ref += 1
    props = f'<string name="Name">{escape(name)}</string>' + extra
    if source is not None:
        if "]]>" in source:
            raise ValueError(f"{name}: ']]>' interdit dans un script")
        props += f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>'
    return f'<Item class="{cls}" referent="RBX{ref}"><Properties>{props}</Properties>{children}</Item>'


def src(p):
    return (ROOT / "src" / p).read_text(encoding="utf-8")


# MODELES DE LA BOUTIQUE (2026-09-14). Un jeu en ligne ne peut pas charger a la volee le modele
# d'un autre auteur (InsertService refuse) : sa GEOMETRIE est donc ecrite dans la place.
# tools/boutique/modeles.json vient de tools/BRR_Modeles_export.lua (Studio, connecte) et ne porte
# AUCUN script : seules les pieces, maillages et textures sont reconstruits ici.
MATERIAUX = {"Plastic": 256, "SmoothPlastic": 272}
ALPHA = {"Overlay": 0, "Transparency": 1, "TintMask": 2}
FACES = {"Right": 0, "Top": 1, "Back": 2, "Left": 3, "Bottom": 4, "Front": 5}
MESHTYPES = {"Head": 0, "Torso": 1, "Wedge": 2, "Sphere": 3, "Cylinder": 4, "FileMesh": 5, "Brick": 6}


def _v3(name, v):
    return f'<Vector3 name="{name}"><X>{v[0]}</X><Y>{v[1]}</Y><Z>{v[2]}</Z></Vector3>'


def _content(name, url):
    return f'<Content name="{name}">' + (f"<url>{escape(url)}</url>" if url else "<null></null>") + "</Content>"


def _piece(p):
    c = p["CFrame"]
    rgb = [max(0, min(255, round(x * 255))) for x in p["Color"]]
    props = (
        _v3("size", p["Size"])
        + '<CoordinateFrame name="CFrame">' + "".join(
            f"<{k}>{c[i]}</{k}>" for i, k in enumerate(
                ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]))
        + "</CoordinateFrame>"
        + f'<Color3uint8 name="Color3uint8">{0xFF000000 | rgb[0] << 16 | rgb[1] << 8 | rgb[2]}</Color3uint8>'
        + f'<token name="Material">{MATERIAUX.get(p.get("Material"), 256)}</token>'
        + f'<float name="Transparency">{p.get("Transparency", 0)}</float>'
        + '<bool name="Anchored">true</bool><bool name="CanCollide">false</bool>'
        + '<bool name="CanQuery">false</bool><bool name="CanTouch">false</bool>'
    )
    if p["ClassName"] == "MeshPart":
        props += _content("MeshId", p.get("MeshId")) + _content("TextureID", p.get("TextureID"))
        # InitialSize = taille d'origine du maillage (MeshSize). Sans elle, Studio prend une valeur
        # par defaut et deforme la piece : gobelet geant, katanas etires (capture 2026-09-14).
        if p.get("MeshSize"):
            props += _v3("InitialSize", p["MeshSize"])
    elif p.get("Shape") == "Block":
        props += '<token name="shape">1</token>'
    enfants = ""
    for e in p["enfants"]:
        if e["ClassName"] == "SurfaceAppearance":
            enfants += item("SurfaceAppearance", "SurfaceAppearance", extra="".join(
                _content(k, e.get(k)) for k in ("ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap"))
                + f'<token name="AlphaMode">{ALPHA.get(e.get("AlphaMode"), 0)}</token>')
        elif e["ClassName"] == "SpecialMesh":
            enfants += item("SpecialMesh", "Mesh", extra=_content("MeshId", e.get("MeshId"))
                            + _content("TextureId", e.get("TextureId"))
                            + f'<token name="MeshType">{MESHTYPES.get(e.get("MeshType"), 6)}</token>'
                            + _v3("Scale", e["Scale"]) + _v3("Offset", e["Offset"]))
        elif e["ClassName"] == "Decal" and e.get("Texture"):
            enfants += item("Decal", "Decal", extra=_content("Texture", e["Texture"])
                            + f'<token name="Face">{FACES.get(e.get("Face"), 5)}</token>')
    return item(p["ClassName"], "Piece", enfants, extra=props)


def modeles():
    fichier = ROOT / "tools" / "boutique" / "modeles.json"
    if not fichier.exists():
        return ""
    data = json.loads(fichier.read_text(encoding="utf-8"))
    return item("Folder", "Modeles", "".join(
        item("Model", perso, "".join(_piece(p) for p in m["pieces"] if p.get("Transparency", 0) < 1))
        for perso, m in data.items()))


place = "".join([
    item("Workspace", "Workspace"),
    # Moteur de rendu ECRIT ICI, pas dans un script : le jeu n'a pas le droit d'ecrire
    # Lighting.Technology (erreur « lacking capability RobloxScript » mesuree le 2026-09-14).
    # Future = ombres douces et lumiere realiste.
    item("Lighting", "Lighting", extra='<token name="Technology">4</token>'),
    item("ReplicatedStorage", "ReplicatedStorage",
         item("Folder", "Shared", item("ModuleScript", "Cards", source=src("shared/Cards.lua"))
              + item("ModuleScript", "Sons", source=src("shared/Sons.lua"))
              # Effets.lua est requis par GameServer : sans lui, le serveur reste bloque sur
              # WaitForChild("Effets") et AUCUN remote n'est cree (mesure Studio 2026-09-16).
              + item("ModuleScript", "Effets", source=src("shared/Effets.lua"))
              # Regles.lua : double elixir, prolongation, zone de pose (fonctions pures).
              + item("ModuleScript", "Regles", source=src("shared/Regles.lua"))
              # Sorts.lua : zone visee, cibles, degats et rage (fonctions pures).
              + item("ModuleScript", "Sorts", source=src("shared/Sorts.lua"))
              # Tutoriel.lua : scenario de la premiere partie (fonctions pures).
              + item("ModuleScript", "Tutoriel", source=src("shared/Tutoriel.lua"))
              # Apercu.lua : disque de visee et fantome de l'unite. SANS lui, le client reste
              # bloque sur WaitForChild("Apercu") et AUCUNE carte ne peut etre jouee.
              + item("ModuleScript", "Apercu", source=src("shared/Apercu.lua"))
              # Foule.lua : separation des unites (elles ne se traversent plus).
              + item("ModuleScript", "Foule", source=src("shared/Foule.lua"))
              # Cible.lua : menace et persistance du ciblage.
              + item("ModuleScript", "Cible", source=src("shared/Cible.lua"))
              # Robot.lua : profil de difficulte selon les trophees du joueur.
              + item("ModuleScript", "Robot", source=src("shared/Robot.lua"))
              # Charge.lua : unites qui prennent de l'elan et frappent plus fort.
              + item("ModuleScript", "Charge", source=src("shared/Charge.lua"))
              # Descendance.lua : les grosses cartes laissent des petites unites en mourant.
              + item("ModuleScript", "Descendance", source=src("shared/Descendance.lua"))
              # Soutien.lua : auras qui renforcent les allies proches.
              + item("ModuleScript", "Soutien", source=src("shared/Soutien.lua"))
              # Terrain.lua : avantage defensif au pied de ses propres tours.
              + item("ModuleScript", "Terrain", source=src("shared/Terrain.lua"))
              # Specialite.lua : anti-air et anti-groupe.
              + item("ModuleScript", "Specialite", source=src("shared/Specialite.lua"))
              # Recul.lua : unites qui projettent leur cible a l'impact.
              + item("ModuleScript", "Recul", source=src("shared/Recul.lua"))
              # Visee.lua : les tireurs visent devant une cible en mouvement.
              + item("ModuleScript", "Visee", source=src("shared/Visee.lua"))
              # Frappe.lua : plafond commun des bonus de degats.
              + item("ModuleScript", "Frappe", source=src("shared/Frappe.lua"))
              # Assassin.lua : chasse prioritaire des tireurs.
              + item("ModuleScript", "Assassin", source=src("shared/Assassin.lua"))
              # Reponse.lua : le robot choisit sa carte CONTRE ce qui arrive.
              + item("ModuleScript", "Reponse", source=src("shared/Reponse.lua"))
              # Emplacement.lua : ou le robot pose un batiment.
              + item("ModuleScript", "Emplacement", source=src("shared/Emplacement.lua"))
              # Voie.lua : choix du cote attaque/defendu, egalites departagees.
              + item("ModuleScript", "Voie", source=src("shared/Voie.lua"))
              # Traversee.lua : franchir la riviere sans se figer a l'entree du pont.
              + item("ModuleScript", "Traversee", source=src("shared/Traversee.lua"))
              # Deploiement.lua : temps d'arrivee avant d'agir.
              + item("ModuleScript", "Deploiement", source=src("shared/Deploiement.lua"))
              + item("ModuleScript", "Garde", source=src("shared/Garde.lua"))
              + item("ModuleScript", "Reserve", source=src("shared/Reserve.lua"))
              + item("ModuleScript", "Fenetre", source=src("shared/Fenetre.lua"))
              + item("ModuleScript", "Defense", source=src("shared/Defense.lua"))
              # Modules requis par GameServer et jamais livres : SANS eux, le serveur reste bloque
              # sur WaitForChild("Statuts") et AUCUNE partie ne demarre (mesure moteur 14:48).
              + item("ModuleScript", "Statuts", source=src("shared/Statuts.lua"))
              + item("ModuleScript", "Batiments", source=src("shared/Batiments.lua"))
              + item("ModuleScript", "Projectiles", source=src("shared/Projectiles.lua"))
              + item("ModuleScript", "Cycle", source=src("shared/Cycle.lua"))
              + item("ModuleScript", "Arenes", source=src("shared/Arenes.lua"))
              # FICHES : ce que fait une carte, deduit de ses donnees (affiche en boutique et en main).
              + item("ModuleScript", "Fiche", source=src("shared/Fiche.lua"))
              # MANUEL : les regles communes a toutes les cartes, affichees dans le hub.
              + item("ModuleScript", "Manuel", source=src("shared/Manuel.lua"))
              # Journal.lua : les dernieres parties du joueur (issue, trophees, adversaire).
              + item("ModuleScript", "Journal", source=src("shared/Journal.lua"))
              + item("ModuleScript", "Quetes", source=src("shared/Quetes.lua"))
              + item("ModuleScript", "Rappel", source=src("shared/Rappel.lua"))
              + item("ModuleScript", "Collection", source=src("shared/Collection.lua"))
              + item("ModuleScript", "Reperes", source=src("shared/Reperes.lua"))
              + item("ModuleScript", "Coffres", source=src("shared/Coffres.lua"))
              # Champions.lua : capacites activables des champions (regles, recharge, deck).
              + item("ModuleScript", "Champions", source=src("shared/Champions.lua"))
              # Cosmetiques.lua : skins de tours et emotes premium (apparence seulement).
              + item("ModuleScript", "Cosmetiques", source=src("shared/Cosmetiques.lua"))
              # PassSaison.lua : pass de saison gratuit + premium (paliers, recompenses, remise a zero).
              + item("ModuleScript", "PassSaison", source=src("shared/PassSaison.lua"))
              # Ligues.lua : ligues competitives (paliers, badge, promotion, bilan de saison).
              + item("ModuleScript", "Ligues", source=src("shared/Ligues.lua"))
              # Ouverture.lua : ouverture de coffre mise en scene (quoi reveler, quand).
              + item("ModuleScript", "Ouverture", source=src("shared/Ouverture.lua"))
              + item("ModuleScript", "Arrondi", source=src("shared/Arrondi.lua"))
              + item("ModuleScript", "Progression", source=src("shared/Progression.lua"))
              # Cout.lua : ce qui manque pour poser une carte (chiffre, jauge, etat).
              + item("ModuleScript", "Cout", source=src("shared/Cout.lua"))
              # Lecture.lua : elixir adverse estime, cartes vues, alerte de tour. Requis par
              # GameServer ET par le client de match : sans lui, les deux restent bloques.
              + item("ModuleScript", "Lecture", source=src("shared/Lecture.lua"))
              # Bilan.lua : recapitulatif de fin de match (elixir gaspille, degats, cartes jouees).
              + item("ModuleScript", "Bilan", source=src("shared/Bilan.lua"))
              # Partage.lua : resume copiable + code compact d'une fin de partie (pas un replay).
              + item("ModuleScript", "Partage", source=src("shared/Partage.lua"))
              # Profil.lua : photo de profil des deux joueurs, et son repli quand elle n'arrive pas.
              + item("ModuleScript", "Profil", source=src("shared/Profil.lua"))
              # Abandon.lua : sanction du quitteur en serie (le premier depart reste gratuit).
              + item("ModuleScript", "Abandon", source=src("shared/Abandon.lua"))
              # Inactif.lua : l'adversaire qui reste plante sans jouer une seule carte.
              + item("ModuleScript", "Inactif", source=src("shared/Inactif.lua"))
              # MiseMenu.lua : positions du menu d'accueil en donnees, verifiees par tools/test_menu.py.
              + item("ModuleScript", "MiseMenu", source=src("shared/MiseMenu.lua"))
              # Habillage.lua : icones d'onglets, levre des boutons, JOUER vivant, soldes qui
              # defilent (tools/test_habillage.py). Requis par Hub : sans lui, le menu attend.
              + item("ModuleScript", "Habillage", source=src("shared/Habillage.lua"))
              # Portrait.lua : cadrage du personnage 3D dans les cartes du menu (modele du jeu, pas du catalogue).
              + item("ModuleScript", "Portrait", source=src("shared/Portrait.lua"))
              # Figurine.lua : rendu 3D d'une carte (modele, silhouette ou embleme), partage par le menu et la partie.
              + item("ModuleScript", "Figurine", source=src("shared/Figurine.lua"))
              # Camps.lua : couleurs RELATIVES au joueur (les miennes bleues, celles d'en face rouges).
              + item("ModuleScript", "Camps", source=src("shared/Camps.lua"))
              # Prive.lua : code de duel prive. Requis par Matchmaking : sans lui, le serveur
              # reste bloque sur WaitForChild("Prive") et aucune partie ne demarre.
              + item("ModuleScript", "Prive", source=src("shared/Prive.lua"))
              # Reprise.lua : delai de grace apres une coupure reseau (le camp attend son joueur).
              + item("ModuleScript", "Reprise", source=src("shared/Reprise.lua"))
              # Signalement.lua : liste fermee de motifs pour signaler un adversaire penible.
              + item("ModuleScript", "Signalement", source=src("shared/Signalement.lua"))
              # Saison.lua : saisons de classement (remise a zero partielle, recompense, rang).
              + item("ModuleScript", "Saison", source=src("shared/Saison.lua"))
              # Reseau.lua : latence mesuree et avertissement de connexion instable.
              + item("ModuleScript", "Reseau", source=src("shared/Reseau.lua"))
              # Spectateur.lua : suivre un camp, main retardee, resultat du pari.
              + item("ModuleScript", "Spectateur", source=src("shared/Spectateur.lua"))
              # Egalise.lua : duel a niveaux egalises (les deux camps au meme niveau de cartes).
              + item("ModuleScript", "Egalise", source=src("shared/Egalise.lua"))
              # Adversaire.lua : dire clairement si l'on affronte un humain ou le robot.
              + item("ModuleScript", "Adversaire", source=src("shared/Adversaire.lua"))
              # Couronnes.lua : annonce distincte pour la couronne prise et la tour perdue.
              + item("ModuleScript", "Couronnes", source=src("shared/Couronnes.lua"))
              # Geste.lua : glisser-deposer et annulation de la carte armee.
              + item("ModuleScript", "Geste", source=src("shared/Geste.lua"))
              # Zone.lua : surlignage de la zone de pose (et de la voie ouverte par une tour tombee).
              + item("ModuleScript", "Zone", source=src("shared/Zone.lua"))
              # Mise.lua : mise en page du duel calculee selon la taille de l'ecran.
              + item("ModuleScript", "Mise", source=src("shared/Mise.lua"))
              # Emotes.lua : liste FERMEE partagee serveur/client, delai, salut d'ouverture.
              + item("ModuleScript", "Emotes", source=src("shared/Emotes.lua"))
              # Decor.lua : habillage variable de l'arene (apparence SEULE, jamais la geometrie).
              + item("ModuleScript", "Decor", source=src("shared/Decor.lua"))
              # Maquette.lua : l'ile autour du terrain (damier, falaises, mer, vegetation), en decor SEUL.
              + item("ModuleScript", "Maquette", source=src("shared/Maquette.lua"))
              # Duel.lua : coup d'envoi commun, forfait et revanche a deux. Requis par GameServer :
              # sans lui, WaitForChild("Duel") bloque le serveur et aucune partie ne demarre.
              + item("ModuleScript", "Duel", source=src("shared/Duel.lua")))
         + modeles()
         + (item("BoolValue", "BRR_AUTOTEST") if AUTOTEST else "")
         # Nombre de joueurs du test automatique : lu par le plugin tools/BRR_AutoRun.lua.
         + (item("IntValue", "BRR_JOUEURS", extra=f'<int name="Value">{JOUEURS}</int>') if AUTOTEST else "")
         + (item("BoolValue", "BRR_COURT") if COURT else "")
         # BRR_DUEL : Studio ne peut PAS etre un serveur reserve (PrivateServerId vide), donc le
         # coup d'envoi commun et le forfait ne s'y declenchaient jamais. Ce drapeau les arme pour
         # la copie de test, sans rien changer au jeu livre.
         + (item("BoolValue", "BRR_DUEL") if DUEL else "")
         # BRR_DECOR : force un decor d'arene (capture d'un theme precis, et comparaison de la
         # geometrie d'un theme a l'autre). Sans lui, le theme est tire au hasard par partie.
         + (item("StringValue", "BRR_DECOR", extra=f'<string name="Value">{DECOR}</string>') if DECOR else "")
         # BRR_ECRAN : force le FORMAT pris en compte par la mise en page (la fenetre du bureau
         # cache, elle, n'est pas redimensionnable : voir tools/studio-capture-moteur.ps1).
         + (item("StringValue", "BRR_ECRAN", extra=f'<string name="Value">{ECRAN}</string>') if ECRAN else "")
         + (item("BoolValue", "BRR_RUN") if RUN else "")
         + (item("BoolValue", "BRR_PARTIE") if PARTIE else "")
         + (item("BoolValue", "BRR_GROSPLAN") if GROSPLAN else "")
         + (item("BoolValue", "BRR_MELEE") if MELEE else "")
         # Capture de l'apercu : la visee est figee au centre de la moitie du joueur, sinon
         # la souris d'une session sans utilisateur ne pointe jamais l'arene.
         # BRR_APERCU : BoolValue d'origine, ou StringValue « sort » pour armer une carte de sort.
         + (item("StringValue", "BRR_APERCU", extra='<string name="Value">sort</string>') if APERCU_SORT
            else (item("StringValue", "BRR_APERCU", extra='<string name="Value">portee</string>') if APERCU_PORTEE
            else (item("BoolValue", "BRR_APERCU") if APERCU else "")))
         # Palier de difficulte force (copie de test) : voir Robot.profilNomme.
         + (item("StringValue", "BRR_ROBOT", extra=f'<string name="Value">{escape(ROBOT)}</string>') if ROBOT else "")
         + (item("BoolValue", "BRR_HUB") if HUB else "")
         + (item("BoolValue", "BRR_TUTO") if TUTO else "")
         + (item("BoolValue", "BRR_ECOTEST") if ECOTEST else "")
         + (item("BoolValue", "BRR_EFFETS") if EFFETS else "")
         + (item("BoolValue", "BRR_BOUCLIERS") if BOUCLIERS else "")
         + (item("StringValue", "BRR_DETAIL", extra=f'<string name="Value">{escape(DETAIL)}</string>') if DETAIL else "")
         + (item("BoolValue", "BRR_REGLES") if REGLES else "")
         + (item("BoolValue", "BRR_REGLES_BAS") if REGLES_BAS else "")
         + (item("BoolValue", "BRR_REGLES_TUTO") if REGLES_TUTO else "")
         + (item("BoolValue", "BRR_REGLES_PARTIE") if REGLES_PARTIE else "")
         + (item("BoolValue", "BRR_JOURNAL") if JOURNAL else "")
         + (item("BoolValue", "BRR_AMIS") if AMIS else "")
         + (item("BoolValue", "BRR_SON") if SON else "")
         + (item("BoolValue", "BRR_MAIN_COUT") if MAIN_COUT else "")
         + (item("BoolValue", "BRR_MAIN_TAGS") if MAIN_TAGS else "")
         + (item("BoolValue", "BRR_TOURS_ABIMEES") if TOURS_ABIMEES else "")
         + (item("BoolValue", "BRR_BATIMENT") if BATIMENT else "")
         + (item("BoolValue", "BRR_CHARGE") if CHARGE else "")
         + (item("BoolValue", "BRR_COURONNE") if COURONNE else "")
         # PHOTO PRISE PAR LE JEU (attribut BRR_PHOTO, voir tools/BRR_Capture.client.lua) : ces modes
         # declenchent eux-memes leur photo ; --photo-jeu l'impose a tout autre mode qui pose BRR_PHOTO.
         + (item("BoolValue", "BRR_PHOTO_JEU") if (COURONNE or CHAMPION or OUVERTURE or "--photo-jeu" in sys.argv) else "")
         + (item("IntValue", "BRR_TROPHEES", extra=f'<int name="Value">{TROPHEES}</int>') if TROPHEES else "")
         + (item("BoolValue", "BRR_QUETE") if QUETE else "")
         + (item("BoolValue", "BRR_QUETE_PRETE") if QUETE_PRETE else "")
         + (item("BoolValue", "BRR_EMOTE_REPOS") if EMOTE_REPOS else "")
         + (item("BoolValue", "BRR_GARDE") if GARDE else "")
         + (item("BoolValue", "BRR_GARDE_MOI") if GARDE_MOI else "")
         + (item("BoolValue", "BRR_DEPLOIEMENT") if DEPLOIEMENT else "")
         + (item("BoolValue", "BRR_SORT_NIVEAU") if SORT_NIVEAU else "")
         + (item("BoolValue", "BRR_SORT_SANS_NIVEAU") if SORT_SANS_NIVEAU else "")
         + (item("BoolValue", "BRR_SPECTATEUR") if SPECTATEUR else "")
         + (item("IntValue", "BRR_PIECES", extra=f'<int name="Value">{PIECES}</int>') if PIECES else "")
         + (item("BoolValue", "BRR_MONTEE") if MONTEE else "")
         + (item("BoolValue", "BRR_PLEINS") if PLEINS else "")
         + (item("BoolValue", "BRR_GEMMES") if GEMMES else "")
         + (item("BoolValue", "BRR_DECK_MODIFIE") if DECK_MODIFIE else "")
         + (item("BoolValue", "BRR_DECK_SORTIE") if DECK_SORTIE else "")
         + (item("BoolValue", "BRR_LISTE_BAS") if LISTE_BAS else "")
         + (item("BoolValue", "BRR_DECK_MAX") if DECK_MAX else "")
         + (item("BoolValue", "BRR_DECK_LEGENDAIRE") if DECK_LEGENDAIRE else "")
         + (item("BoolValue", "BRR_AIDE_GEMMES") if AIDE_GEMMES else "")
         + (item("IntValue", "BRR_CLICS", extra=f'<int name="Value">{CLICS}</int>') if CLICS else "")
         + (item("BoolValue", "BRR_FIN_SAISON") if FIN_SAISON else "")
         + (item("IntValue", "BRR_CAP_DELAI", extra=f'<int name="Value">{CAP_DELAI}</int>') if CAP_DELAI else "")
         + (item("BoolValue", "BRR_BOUTIQUE") if BOUTIQUE else "")
         + (item("BoolValue", "BRR_COFFRES") if COFFRES else "")
         + (item("BoolValue", "BRR_OUVERTURE") if OUVERTURE else "")
         + (item("BoolValue", "BRR_PASS_PREMIUM") if PASS_PREMIUM else "")
         + (item("BoolValue", "BRR_VIP_NON_POSSEDE") if VIP_NON_POSSEDE else "")
         + (item("BoolValue", "BRR_COSMETIQUES") if COSMETIQUES else "")
         + (item("StringValue", "BRR_CHAMPION", extra=f'<string name="Value">{CHAMPION}</string>') if CHAMPION else "")
         + (item("StringValue", "BRR_SKIN", extra=f'<string name="Value">{SKIN}</string>') if SKIN else "")
         + (item("IntValue", "BRR_PASS_POINTS", extra=f'<int name="Value">{PASS_POINTS}</int>') if PASS_POINTS else "")
         + (item("BoolValue", "BRR_DECK") if DECK else "")
         + (item("BoolValue", "BRR_NIVEAUX") if NIVEAUX else "")
         + (item("StringValue", "BRR_ONGLET", extra=f'<string name="Value">{escape(ONGLET)}</string>') if ONGLET else "")
         + (item("StringValue", "BRR_SIM", extra=f'<string name="Value">{escape(SIM)}</string>') if SIM else "")
         + (item("StringValue", "BRR_GALERIE", extra=f'<string name="Value">{escape(GALERIE)}</string>') if GALERIE else "")),
    item("ServerStorage", "ServerStorage", item("BoolValue", "BRR_AUTOTEST") if AUTOTEST else ""),
    item("ServerScriptService", "ServerScriptService",
         item("Script", "GameServer", source=src("server/GameServer.server.lua"))
         + item("ModuleScript", "Economie", source=src("server/Economie.lua"))
         + item("ModuleScript", "Matchmaking", source=src("server/Matchmaking.lua"))),
    item("StarterPlayer", "StarterPlayer",
         item("StarterPlayerScripts", "StarterPlayerScripts",
              item("LocalScript", "GameClient", source=src("client/GameClient.client.lua"))
              + item("LocalScript", "Hub", source=src("client/Hub.client.lua"))
              # ESSAI 2026-09-14 : capture produite par le moteur (copie de test seulement).
              + (item("LocalScript", "BRR_Capture",
                      source=(ROOT / "tools" / "BRR_Capture.client.lua").read_text(encoding="utf-8"))
                 if AUTOTEST else ""))),
])

out = ROOT / ("BrainRotRoyale.autotest.rbxlx" if AUTOTEST else "BrainRotRoyale.rbxlx")
out.write_text(
    '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
    'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
    + place + "</roblox>",
    encoding="utf-8",
)
print(f"OK -> {out}")
