# -*- coding: utf-8 -*-
"""Banc du MANUEL (src/shared/Manuel.lua + l'ecran des regles du hub), hors Studio.

Defaut corrige le 2026-09-20 : quatre mecaniques decident des parties et n'etaient expliquees
NULLE PART — l'elixir double dans le dernier tiers, la prolongation, la zone de pose qui s'ouvre
quand une tour tombe, et l'avantage de terrain. Un joueur pouvait faire cent parties sans en
apprendre une seule. Elles ne tiennent pas sur une fiche de carte : elles y seraient repetees a
l'identique sur les 40 cartes.

Ce qu'il verifie :
  1. chaque section a un titre et un texte, et aucune n'est vide ;
  2. les CHIFFRES sont ceux du jeu : on relit les constantes dans Regles.lua et Terrain.lua et on
     verifie qu'elles apparaissent bien dans les textes — le manuel ne peut donc pas mentir ;
  3. les quatre mecaniques annoncees sont bien couvertes ;
  4. la duree affichee par le hub est celle du SERVEUR (deux sources, un seul chiffre) ;
  5. le hub construit vraiment cet ecran, et il s'ouvre et se ferme.

Prerequis : python -m pip install lupa
"""
import pathlib
import re
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Manuel.lua"
REGLES = ROOT / "src" / "shared" / "Regles.lua"
TERRAIN = ROOT / "src" / "shared" / "Terrain.lua"
HUB = ROOT / "src" / "client" / "Hub.client.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("math.clamp = math.clamp or function(x, a, b) return math.max(a, math.min(b, x)) end")
    M = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    R = lua.execute("return (function() " + REGLES.read_text(encoding="utf-8") + " end)()")
    T = lua.execute("return (function() " + TERRAIN.read_text(encoding="utf-8") + " end)()")
    hub = HUB.read_text(encoding="utf-8")
    serveur = SERVEUR.read_text(encoding="utf-8")

    # 4. UNE SEULE duree de partie : celle du serveur. Le hub n'a pas acces a MATCH_TIME, il la
    # recopie — c'est ici, et nulle part ailleurs, qu'on verifie qu'elle n'a pas derive.
    duree_serveur = int(re.search(r"BRR_COURT\"\) and \d+ or (\d+)", serveur).group(1))
    duree_hub = int(re.search(r"DUREE_MATCH_AFFICHEE = (\d+)", hub).group(1))
    cas("le hub affiche la duree REELLE du serveur", duree_serveur, duree_hub)

    # Les VRAIES valeurs des modules, y compris celles des sections conditionnelles : sans elles,
    # le banc jugeait un manuel amputé de ses dernieres sections (mesure du 2026-09-21).
    DEP = lua.execute("return (function() "
                      + (ROOT / "src" / "shared" / "Deploiement.lua").read_text(encoding="utf-8") + " end)()")
    STA = lua.execute("return (function() "
                      + (ROOT / "src" / "shared" / "Statuts.lua").read_text(encoding="utf-8") + " end)()")
    GAR = lua.execute("return (function() "
                      + (ROOT / "src" / "shared" / "Garde.lua").read_text(encoding="utf-8") + " end)()")
    valeurs = lua.eval(
        "(function(d, dp, md, mp, pp, tr, tred, dep, inv, gf) return { dureeMatch = d, doublePart = dp, "
        "multDouble = md, multProlongation = mp, prolongationPart = pp, terrainRayon = tr, "
        "terrainReduction = tred, elixirMax = 10, deploiement = dep, invulnPose = inv, "
        "gardeFacteur = gf } end)")(
        duree_serveur, R.DOUBLE_ELIXIR_PART, R.MULT_DOUBLE, R.MULT_PROLONGATION,
        R.PROLONGATION_PART, T.RAYON, T.REDUCTION, DEP.DUREE, STA.INVULN_POSE, GAR.FACTEUR)

    sections = list(M.sections(valeurs).values())
    print("  %d sections : %s" % (len(sections), ", ".join(s["titre"] for s in sections)))

    # 1. rien de vide
    vides = [s["titre"] for s in sections if not s["texte"] or len(s["texte"]) < 30]
    cas("aucune section vide ou bavarde a vide", [], vides)
    sans_titre = [i for i, s in enumerate(sections) if not s["titre"]]
    cas("chaque section a un titre", [], sans_titre)

    tout = " ".join(s["titre"] + " " + s["texte"] for s in sections)

    # 3. les mecaniques annoncees
    for mot in ("ELIXIR DOUBLE", "ZONE DE POSE", "TERRAIN", "PROLONGATION", "LIRE L'ADVERSAIRE"):
        cas("le manuel couvre %s" % mot, True, mot in tout)

    # 2. les chiffres viennent des modules
    cas("le terrain annonce sa vraie reduction", True,
        ("%d %%" % round(T.REDUCTION * 100)) in tout)
    cas("et son vrai rayon", True, ("%d studs" % T.RAYON) in tout)
    cas("l'elixir double annonce son vrai multiplicateur", True,
        str(int(R.MULT_DOUBLE)) + " fois plus vite" in tout)
    cas("la prolongation annonce le sien", True,
        str(int(R.MULT_PROLONGATION)) + " fois plus rapide" in tout)
    # L'instant du double elixir se DEDUIT : duree x (1 - part). A 180 s et un tiers, c'est 2 min.
    instant = duree_serveur * (1 - R.DOUBLE_ELIXIR_PART)
    cas("l'instant du double elixir est celui de la regle", True, M.duree(instant) in tout)
    cas("la duree de la prolongation vient de la regle", True,
        M.duree(duree_serveur * R.PROLONGATION_PART) in tout)
    cas("la duree d'une partie est affichee en minutes", True, M.duree(duree_serveur) in tout)

    # LIRE L'ADVERSAIRE : le panneau du jeu donne un chiffre d'elixir. Un joueur qui le croit EXACT
    # pousse au mauvais moment, perd, et accuse le jeu. Le manuel doit dire que c'est une estimation
    # construite sur du visible, et annoncer le vrai nombre de cartes gardees a l'ecran.
    L = lua.execute("return (function() " + (ROOT / "src/shared/Lecture.lua").read_text(encoding="utf-8") + " end)()")
    cas("le manuel dit que l'elixir adverse est une ESTIMATION", True, "ESTIMATION" in tout)
    cas("il dit d'ou elle vient (ce qu'on a VU poser)", True, "VU poser" in tout)
    cas("il annonce le vrai nombre de cartes gardees a l'ecran", True,
        ("%d dernieres cartes" % int(L.CARTES_VUES)) in tout)
    cas("le hub lit ce nombre dans le module, il ne le recopie pas", True,
        "cartesVues = Lecture.CARTES_VUES" in hub)
    # Une section de plus de deux lignes etait rognee par une hauteur de bloc fixe.
    cas("les blocs du manuel grandissent avec leur texte", True,
        "bloc.AutomaticSize = Enum.AutomaticSize.Y" in hub)

    # Lecture humaine : des minutes, pas des secondes brutes.
    cas("180 s se lit 3 min 00", "3 min 00", M.duree(180))
    cas("90 s se lit 1 min 30", "1 min 30", M.duree(90))
    cas("moins d'une minute reste en secondes", "45 s", M.duree(45))

    # 5. l'ecran existe vraiment dans le hub
    cas("le hub charge le manuel", True, 'WaitForChild("Manuel")' in hub)
    cas("il construit ses sections", True, "Manuel.sections(valeursDuJeu())" in hub)
    cas("les valeurs viennent des modules, pas de textes ecrits a la main", True,
        "Terrain.REDUCTION" in hub and "Regles.DOUBLE_ELIXIR_PART" in hub)
    cas("un bouton ouvre l'ecran", True, "boutonRegles.MouseButton1Click" in hub)
    cas("et il se ferme", True, "reglesFermer.MouseButton1Click" in hub)
    cas("la liste defile (le manuel grandira)", True, "ScrollingFrame" in hub)
    # La liste doit s'ARRETER au-dessus du bouton : sinon la derniere section passe dessous et
    # devient illisible (c'est ce que montrait la premiere capture).
    cas("la liste s'arrete au-dessus du bouton", True,
        "1, -(64 + Fiche.PANNEAU_PIED)" in hub)

    # 6. FIN DU TUTORIEL : c'est le seul moment ou un joueur neuf est disponible pour lire des
    # regles. Plus tard, il enchaine les parties et n'ouvrira jamais cet ecran de lui-meme.
    cas("le hub surveille la fin du tutoriel", True, "verifierFinTutoriel(v)" in hub)
    cas("il lit l'etat REEL du profil", True, "v.tutoFait == true" in hub)
    # TRANSITION seulement : un joueur qui a deja fait son tutoriel ne doit pas se faire ouvrir un
    # panneau a chaque retour au menu.
    cas("declenchement sur la transition, pas sur l'etat", True,
        "tutoFaitPrecedent == false and fait" in hub)
    cas("et une seule fois par session", True, "reglesMontreesApresTuto" in hub)
    # Le tutoriel n'est impose qu'au joueur NEUF : c'est le serveur qui le dit (Economie.tutoFait),
    # le hub ne fait que lire. Sans ce champ dans la vue, la regle serait aveugle.
    eco = (ROOT / "src" / "server" / "Economie.lua").read_text(encoding="utf-8")
    cas("la vue du serveur porte bien l'etat du tutoriel", True, "tutoFait = p.tutoFait == true" in eco)

    # 7. PENDANT LA PARTIE : le manuel ne servait qu'a froid, au menu. La question se pose en
    # plein match (« pourquoi l'elixir va deux fois plus vite ? »), et pour lire les regles il
    # fallait QUITTER la partie — donc l'abandonner.
    cas("un bouton REGLES existe a cote de MENU", True,
        'local boutonAide = bouton(gui, "REGLES"' in hub)
    cas("il n'apparait QUE pendant la partie, avec le bouton MENU", True,
        'boutonMenu:GetPropertyChangedSignal("Visible")' in hub
        and "boutonAide.Visible = boutonMenu.Visible" in hub)
    cas("il ouvre le MEME panneau, il n'en recree pas un", True,
        "boutonAide.MouseButton1Click" in hub and hub.count("function ouvrirRegles") == 1)
    # Le panneau n'est PAS un enfant de l'accueil : sinon il disparaitrait avec lui pendant le match.
    cas("le panneau vit hors de l'accueil", True, "reglesEcran.Parent = gui" in hub)
    # Lire les regles ne doit pas poser une carte : le client ignore les gestes deja traites par
    # l'interface. Sans cette garde, ouvrir le panneau aurait coute une carte et son elixir.
    client = (ROOT / "src" / "client" / "GameClient.client.lua").read_text(encoding="utf-8")
    cas("un clic sur l'interface ne pose aucune carte", True,
        "function(input, processed)" in client and "if processed then" in client)

    # COURONNES. Defaut mesure le 2026-09-21 : seules les TROIS tours de depart donnent une
    # couronne (le serveur ne compte que `teams[camp].towers`), et rien ne le disait au joueur.
    # Abattre la tour de defense posee par l'adversaire ne change pas le score : sans explication,
    # cela passe pour un bug. La reponse vient de Batiments.donneCouronne, pas d'un texte en dur.
    sections = [dict(x) for x in M.sections(valeurs).values()]
    couronnes = next((x for x in sections if x["titre"] == "COURONNES"), None)
    cas("le manuel a une section COURONNES", True, couronnes is not None)
    cas("elle dit combien de tours en donnent", True, "TROIS tours" in couronnes["texte"])
    cas("et que les batiments poses n'en donnent pas", True, "AUCUNE" in couronnes["texte"])
    cas("elle arrive AVANT la fin de partie", True,
        [x["titre"] for x in sections].index("COURONNES")
        < [x["titre"] for x in sections].index("FIN DE PARTIE"))
    # LE TEXTE SUIT LA REGLE : si un jour un batiment donnait une couronne, le manuel le dirait au
    # lieu de mentir. C'est ce qui distingue une regle branchee d'une phrase recopiee.
    vBis = lua.eval("(function(v) local c = {} for k, x in pairs(v) do c[k] = x end c.batimentCouronne = true return c end)")(valeurs)
    autre = next(x for x in [dict(y) for y in M.sections(vBis).values()] if x["titre"] == "COURONNES")
    cas("le texte change si la regle change", True, "en comptent aussi" in autre["texte"])
    cas("et ne garde pas l'ancienne phrase", False, "AUCUNE" in autre["texte"])
    # L'ECRAN passe la vraie valeur : sans cela, le manuel retomberait sur un defaut arbitraire.
    cas("le hub lit la regle dans Batiments", True,
        'WaitForChild("Batiments")).donneCouronne()' in hub)
    # Et le SERVEUR ne compte bien que les tours de depart (la phrase doit rester vraie).
    cas("le serveur ne compte que les tours", True,
        "for _, t in ipairs(teams[3 - team].towers) do" in serveur)

    # LA POSE. Deux regles existent depuis longtemps, toutes deux invisibles et jamais expliquees :
    # l'unite posee met un temps a etre operationnelle, et elle est brievement intouchable en
    # arrivant. Le joueur les subit sans les comprendre (« mon sort pile dessus n'a rien fait »).
    pose = next((x for x in sections if x["titre"] == "LA POSE"), None)
    cas("le manuel a une section LA POSE", True, pose is not None)
    cas("elle donne le delai avant d'agir", True, "0,45 s" in pose["texte"])
    cas("et la duree d'invulnerabilite", True, "0,35 s" in pose["texte"])
    # Les deux chiffres viennent des modules : recopies, ils mentiraient au premier reglage change.
    cas("le delai colle au module", True, str(DEP.DUREE).replace(".", ",") in pose["texte"])
    cas("l'invulnerabilite aussi", True, str(STA.INVULN_POSE).replace(".", ",") in pose["texte"])
    # PIEGE MESURE le 2026-09-21 : arrondi a UNE decimale, 0,45 devenait « 0,5 » et 0,35 devenait
    # « 0,3 » — le manuel annoncait deux chiffres faux, l'un trop haut, l'autre trop bas.
    cas("aucun arrondi trompeur", False, "0,5 s" in pose["texte"] or "0,3 s" in pose["texte"])
    cas("le hub lit les deux dans les modules", True,
        ':WaitForChild("Deploiement")).DUREE' in hub and ':WaitForChild("Statuts")).INVULN_POSE' in hub)
    # Sans valeurs fournies, la section n'existe pas : le manuel n'invente aucun chiffre.
    cas("aucune section LA POSE sans les chiffres", True,
        all(x["titre"] != "LA POSE" for x in [dict(y) for y in M.sections(lua.eval("(function() return { dureeMatch = 180 } end)")()).values()]))

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : le manuel explique les regles communes, avec les chiffres reels du jeu")
    return 0


sys.exit(main())
