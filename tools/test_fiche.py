# -*- coding: utf-8 -*-
"""Banc des FICHES DE CARTES (src/shared/Fiche.lua), hors Studio.

Defaut corrige le 2026-09-20 : aucun ecran ne disait ce que FAIT une carte. Le champ `desc`
existait depuis le debut du catalogue et n'etait affiche NULLE PART. Un joueur achetait
« Regina Ghiaccio » sans savoir qu'elle ralentit, posait « Scudo Banana » sans savoir qu'elle
porte un bouclier, et voyait un ennemi verdir sans apprendre que c'etait du poison.

Ce qu'il verifie, sur le VRAI catalogue :
  1. toute carte qui porte un effet de jeu (bouclier, poison, ralentissement, soin, explosion,
     batiment, sort, pose libre) a au moins une ligne de fiche — aucune carte a effet muette ;
  2. les CHIFFRES affiches sont ceux du catalogue : la fiche ne peut pas mentir, puisqu'elle est
     calculee depuis les memes champs (on recompte a la main, ici, ce qu'elle annonce) ;
  3. chaque famille d'effet nomme son effet (le mot GEL pour un gel, POISON pour un poison...) ;
  4. une carte ordinaire ne recoit pas de ligne inventee, et son resume retombe sur sa `desc` ;
  5. l'etiquette courte de la main tient en UN mot et distingue les familles ;
  6. la boutique et la main les affichent reellement (sinon le module serait mort-ne).

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Fiche.lua"
CARDS = ROOT / "src" / "shared" / "Cards.lua"
HUB = ROOT / "src" / "client" / "Hub.client.lua"
CLIENT = ROOT / "src" / "client" / "GameClient.client.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def lignes(F, carte):
    return list(F.lignes(carte).values())


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    # math.clamp est une extension Luau (Specialite et Soutien s'en servent pour borner)
    lua.execute("math.clamp = math.clamp or function(x, a, b) return math.max(a, math.min(b, x)) end")
    lua.execute("Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }")
    lua.execute("Vector3 = { new = function(x, y, z) return { x, y, z } end }")
    F = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    cartes = lua.execute(CARDS.read_text(encoding="utf-8"))
    liste = list(cartes["list"].values())
    byId = cartes["byId"]

    # 1. aucune carte a effet ne reste muette
    def a_un_effet(c):
        return (c["sort"] is not None or c["batiment"] is not None or c["soin"] is not None
                or c["mort"] is not None or c["effet"] is not None
                or (c["bouclier"] or 0) > 0 or c["poseLibre"] is not None)

    muettes = sorted(c["id"] for c in liste if a_un_effet(c) and not lignes(F, c))
    cas("aucune carte a effet sans fiche", [], muettes)
    avec = [c for c in liste if lignes(F, c)]
    print("  %d cartes sur %d portent une fiche d'effet" % (len(avec), len(liste)))

    # 2. les CHIFFRES viennent du catalogue
    scudo = byId["ScudoBanana"]
    cas("le bouclier affiche sa vraie valeur", True,
        str(int(scudo["bouclier"])) in " ".join(lignes(F, scudo)))
    regina = byId["ReginaGhiaccio"]
    part = int(round(regina["effet"]["lent"]["part"] * 100))
    cas("le ralentissement affiche son vrai pourcentage", True,
        ("%d %%" % part) in " ".join(lignes(F, regina)))
    serpent = byId["SerpenteVeleno"]
    p = serpent["effet"]["poison"]
    total = int(p["degats"] * (p["duree"] / p["tic"]))
    cas("le poison annonce le total REEL (degats x tics)", True,
        str(total) in " ".join(lignes(F, serpent)))
    pompe = byId["PompaElixir"]
    cas("le collecteur annonce sa vraie periode", True,
        ("%d s" % int(pompe["batiment"]["periode"])) in " ".join(lignes(F, pompe)))
    cas("et sa duree de vie", True,
        ("%d s" % int(pompe["batiment"]["duree"])) in " ".join(lignes(F, pompe)))
    docteur = byId["DottorePizza"]
    cas("le soigneur annonce son montant", True,
        str(int(docteur["soin"]["montant"])) in " ".join(lignes(F, docteur)))
    bombe = byId["BombaSalsiccia"]
    cas("l'explosion annonce ses degats", True,
        str(int(bombe["mort"]["degats"])) in " ".join(lignes(F, bombe)))

    # 3. chaque famille NOMME son effet
    for cid, mot in (("GelatoGlaciale", "GEL"), ("VelenoPizza", "POISON"), ("CuraLimone", "SOIN"),
                     ("FuriaBrainrot", "RAGE"), ("ScudoBanana", "BOUCLIER"),
                     ("ReginaGhiaccio", "RALENTIT"), ("DottorePizza", "SOIGNE"),
                     ("SerpenteVeleno", "EMPOISONNE"), ("TorreCannoli", "BATIMENT")):
        cas("%s nomme son effet (%s)" % (cid, mot), True, mot in " ".join(lignes(F, byId[cid])))

    # 4. une carte ordinaire n'invente rien
    tralalero = byId["Tralalero"]
    cas("une carte sans effet n'a pas de ligne inventee", [], lignes(F, tralalero))
    cas("son resume retombe sur sa description", tralalero["desc"], F.resume(tralalero, 2))

    # 5. etiquette courte : UN mot, et des familles distinctes
    etiquettes = {cid: F.etiquette(byId[cid]) for cid in
                  ("GelatoGlaciale", "ScudoBanana", "DottorePizza", "SerpenteVeleno",
                   "ReginaGhiaccio", "TorreCannoli", "BombaSalsiccia", "MinatoreMozzarella")}
    for cid, e in etiquettes.items():
        cas("%s : etiquette en un mot" % cid, 1, len(e.split()))
    cas("les familles ne se confondent pas", len(etiquettes), len(set(etiquettes.values())))
    cas("une carte ordinaire n'a pas d'etiquette", "", F.etiquette(tralalero))

    # 6. SPECIALITE et SOUTIEN : declares dans leurs propres modules, passes a la fiche par les
    # ecrans. Sans eux, la Ballerina passait pour une petite tireuse quelconque et le Lirili pour
    # une mauvaise carte — alors qu'elle double ses degats contre les volants et qu'il renforce
    # tous les allies autour de lui.
    SP = lua.execute("return (function() " + (ROOT / "src/shared/Specialite.lua").read_text(encoding="utf-8") + " end)()")
    SO = lua.execute("return (function() " + (ROOT / "src/shared/Soutien.lua").read_text(encoding="utf-8") + " end)()")

    DE = lua.execute("return (function() " + (ROOT / "src/shared/Descendance.lua").read_text(encoding="utf-8") + " end)()")
    RE = lua.execute("return (function() " + (ROOT / "src/shared/Recul.lua").read_text(encoding="utf-8") + " end)()")
    noms = lua.eval("(function(t) local n = {} for _, c in ipairs(t) do n[c.id] = c.name end return n end)")(cartes["list"])

    def extras(cid):
        fab = lua.eval("(function(s, o, d, r, n) return { specialite = s, soutien = o, "
                       "descendance = d, recul = r, noms = n } end)")
        return fab(SP.profil(cid), SO.profil(cid), DE.profil(cid), RE.profil(cid), noms)

    # RENDEMENT D'UN SORT. Defaut mesure le 2026-09-20 : `Sorts.degatsParElixir` etait ecrit,
    # commente « sert au banc »... et appele par PERSONNE, pas meme par un banc. C'est pourtant le
    # seul chiffre qui permet de comparer deux sorts de degats : 240 pour 4 elixir et 180 pour 3,
    # ce n'est pas la meme carte, et la fiche ne le disait pas.
    SO_SORTS = lua.execute("return (function() " + (ROOT / "src/shared/Sorts.lua").read_text(encoding="utf-8") + " end)()")
    bombe = byId["PizzaBombarda"] if "PizzaBombarda" in dict(byId) else None
    sortDegats = None
    for c in liste:
        if c["sort"] is not None and c["sort"]["effet"] == "degats":
            sortDegats = c
            break
    cas("le catalogue a bien un sort de degats", True, sortDegats is not None)
    rendement = float(SO_SORTS.degatsParElixir(sortDegats))
    cas("le rendement vaut degats / cout", float(sortDegats["sort"]["degats"]) / float(sortDegats["cost"]), rendement)
    fab = lua.eval("(function(r) return { rendementSort = r } end)")
    avec = list(F.lignes(sortDegats, fab(rendement)).values())
    cas("la fiche l'affiche", True, any("RENDEMENT" in x for x in avec))
    cas("avec le chiffre reel", True, any(("%g" % rendement).replace(".", ",") in x for x in avec))
    # Sans le chiffre, pas de ligne inventee : la fiche ne calcule rien elle-meme.
    cas("sans rendement fourni, aucune ligne de rendement", False,
        any("RENDEMENT" in x for x in lignes(F, sortDegats)))
    # Une carte qui n'est pas un sort de degats n'a pas de rendement (division par zero evitee).
    cas("un sort sans degats ne rend rien", 0.0, float(SO_SORTS.degatsParElixir(byId["GelatoGlaciale"])))

    # RENTABILITE D'UN COLLECTEUR : meme regle que le rendement d'un sort — la fiche AFFICHE une
    # ligne fournie, elle ne calcule rien (le calcul vit dans Batiments, banc test_batiments.py).
    pompe = None
    for c in byId.values():
        if c["batiment"] and c["batiment"]["type"] == "collecteur":
            pompe = c
            break
    cas("le catalogue a bien un collecteur", True, pompe is not None)
    fabR = lua.eval("(function(r) return { rentabilite = r } end)")
    avecR = list(F.lignes(pompe, fabR("REMBOURSEE EN 48 s, puis +1,5 elixir net si elle vit")).values())
    cas("la fiche affiche la rentabilite", True, any("REMBOURSEE EN 48 s" in x for x in avecR))
    # Elle reste SOUS la ligne qui decrit le batiment : on lit d'abord ce que fait la carte.
    cas("juste apres la ligne du batiment", True,
        next(i for i, x in enumerate(avecR) if "REMBOURSEE" in x)
        == next(i for i, x in enumerate(avecR) if x.startswith("BATIMENT :")) + 1)
    cas("sans rentabilite fournie, aucune ligne inventee", False,
        any("REMBOURSEE" in x for x in lignes(F, pompe)))
    cas("une chaine vide n'ajoute pas de ligne vide", False,
        any(x == "" for x in F.lignes(pompe, fabR("")).values()))

    # CHARGE et ASSASSIN. Defaut mesure le 2026-09-21 : trois cartes prennent de l'ELAN (premier
    # coup jusqu'a x2,5 apres une course) et une carte va chercher les TIREURS derriere la ligne.
    # Les deux regles existent, sont testees, et n'etaient sur AUCUNE fiche — alors qu'elles
    # decident de la facon de jouer la carte (poser loin derriere, ou la bloquer en route).
    fabC = lua.eval("(function(d, m) return { charge = { distance = d, multiplicateur = m } } end)")
    avecC = list(F.lignes(byId["Zibra"], fabC(9, 1.8)).values())
    cas("la fiche affiche la charge", True, any(x.startswith("CHARGE :") for x in avecC))
    cas("avec la distance d'elan", True, any("9 studs" in x for x in avecC))
    cas("et le multiplicateur reel", True, any("x1,8" in x for x in avecC))
    # La PARADE doit y etre : une charge qu'on ne sait pas contrer n'est qu'un chiffre.
    # La PARADE doit y etre, sur sa PROPRE ligne : sur une seule ligne, la fin etait coupee par
    # le bord du panneau (capture cap-charge-fiche.png du 2026-09-21).
    cas("elle dit comment la contrer", True, any(x.startswith("PARADE :") for x in avecC))
    cas("et aucune ligne n'est trop longue pour le panneau", True,
        max(len(x) for x in avecC) <= 62)
    cas("sans charge fournie, aucune ligne", False,
        any("CHARGE :" in x for x in lignes(F, byId["Zibra"])))
    # Un multiplicateur de 1 n'est pas une charge : pas de ligne pour rien.
    cas("une charge sans gain n'est pas affichee", False,
        any("CHARGE :" in x for x in F.lignes(byId["Zibra"], fabC(9, 1)).values()))

    fabA = lua.eval("(function() return { assassin = true } end)")
    avecA = list(F.lignes(byId["Cappuccino"], fabA()).values())
    cas("la fiche dit qu'elle est assassin", True, any(x.startswith("ASSASSIN :") for x in avecA))
    cas("et ce que cela change", True, any("tireurs" in x for x in avecA))
    cas("sans le signaler, aucune ligne", False,
        any("ASSASSIN :" in x for x in lignes(F, byId["Cappuccino"])))

    # NOM EN MAIN. Defaut mesure le 2026-09-21 (capture cap-etiquettes.png) : « Zibra Zubra
    # Zibralini » prenait a lui seul TROIS lignes du bouton ; avec l'etiquette et le cout, la
    # derniere ligne sortait de la carte et le cout etait coupe.
    cas("un nom de trois mots est ramene a deux", "Zibra Zubra", F.nomMain("Zibra Zubra Zibralini"))
    # Deux mots tiennent : on ne touche pas a ce qui va deja bien.
    cas("un nom de deux mots reste entier", "Bombardiro Crocodilo", F.nomMain("Bombardiro Crocodilo"))
    cas("un nom d'un mot aussi", "Vacca", F.nomMain("Vacca"))
    cas("un nom vide ne casse rien", "", F.nomMain(None))
    cas("le nom COMPLET reste celui du catalogue", "Zibra Zubra Zibralini", byId["Zibra"]["name"])

    # ETIQUETTE EN MAIN : un seul mot, lisible en pleine partie. CHARGE et ASSASSIN comblent un
    # vide — les deux cartes n'en portaient AUCUNE — sans jamais remplacer une etiquette existante.
    cas("sans extras, Cocofanto n'a aucune etiquette", "", F.etiquette(byId["Cocofanto"], None))
    cas("avec sa charge, elle porte CHARGE", "CHARGE", F.etiquette(byId["Cocofanto"], fabC(14, 2.5)))
    cas("une charge sans gain n'etiquette rien", "", F.etiquette(byId["Cocofanto"], fabC(14, 1)))
    cas("l'assassin porte ASSASSIN", "ASSASSIN", F.etiquette(byId["Cappuccino"], fabA()))
    # LE PIEGE : ces deux mots ne doivent PAS voler la place d'une etiquette deja affichee, sinon
    # le joueur perdrait une lecture qu'il a apprise.
    fabCS = lua.eval("(function(d, m) return { charge = { distance = d, multiplicateur = m }, specialite = { contre = \"air\", multiplicateur = 2 } } end)")
    cas("une carte anti-air garde son etiquette", "ANTI-AIR", F.etiquette(byId["Cocofanto"], fabCS(14, 2.5)))
    # Un batiment reste un BATIMENT, meme si on lui passait une charge par erreur.
    cas("un batiment garde la sienne", "BATIMENT", F.etiquette(byId["TorreCannoli"], fabC(9, 2)))

    # NIVEAUX. Defaut mesure le 2026-09-21, en deux temps :
    #  1. la fiche affichait TOUJOURS les chiffres du niveau 1 — une carte montee au niveau 4
    #     montrait les memes PV qu'une carte neuve, alors que le serveur applique bien le niveau ;
    #  2. le bouton disait « AMELIORER 50 » sans dire ce qu'on achetait.
    tral = byId["Tralalero"]
    cas("sans niveau, les chiffres du catalogue", True, ("PV %d" % tral["hp"]) in F.stats(tral))
    cas("au niveau 4 (+30 %%), les PV augmentes", True,
        ("PV %d" % int(tral["hp"] * 1.3)) in F.stats(tral, 1.3))
    cas("et les degats aussi", True, ("Degats %d" % int(tral["dmg"] * 1.3)) in F.stats(tral, 1.3))
    gain = F.gainNiveau(tral, 1, 0.10, 5)
    cas("le gain nomme le niveau suivant", True, gain.startswith("NIVEAU 2 :"))
    cas("avec les PV avant et apres", True, ("PV %d -> %d" % (tral["hp"], int(tral["hp"] * 1.1))) in gain)
    cas("et les degats avant et apres", True, ("degats %d -> %d" % (tral["dmg"], int(tral["dmg"] * 1.1))) in gain)
    # Du niveau 3 au 4, l'AVANT est deja augmente : sinon le gain affiche serait faux.
    cas("l'avant tient compte du niveau deja atteint", True,
        ("PV %d -> %d" % (int(tral["hp"] * 1.2), int(tral["hp"] * 1.3))) in F.gainNiveau(tral, 3, 0.10, 5))
    cas("au niveau max, on le dit", "NIVEAU MAX atteint", F.gainNiveau(tral, 5, 0.10, 5))
    # SORTS : depuis le 2026-09-21 le niveau s'applique aussi a leurs degats (il ne s'y appliquait
    # pas : ameliorer Pizza Bombarda ne rapportait rien). La fiche annonce donc le vrai gain, et
    # le banc verifie que le serveur applique ce que la fiche promet.
    pizza = byId["PizzaBombarda"]
    d = pizza["sort"]["degats"]
    gPizza = F.gainNiveau(pizza, 1, 0.10, 5)
    cas("un sort de degats annonce son gain", True,
        ("degats %d -> %d" % (d, int(d * 1.1 + 0.5))) in gPizza)
    cas("et ne dit plus qu'il n'augmente pas", False, "n'augmente pas" in gPizza)
    cas("ses statistiques suivent le niveau", True, ("Degats %d" % int(d * 1.3 + 0.5)) in F.stats(pizza, 1.3))
    # ET SES LIGNES D'EFFET AUSSI : l'en-tete disait « Degats 408 » (niveau 3) et la ligne juste
    # dessous « DEGATS : 340 » (niveau 1) — deux chiffres pour la meme chose sur la meme fiche
    # (capture cap-fiche-sort-niveau.png du 2026-09-21).
    fabM = lua.eval("(function(m) return { mult = m } end)")
    lignesNiv = list(F.lignes(pizza, fabM(1.2)).values())
    cas("la ligne DEGATS suit le niveau", True,
        any(("DEGATS : %d" % int(d * 1.2 + 0.5)) in x for x in lignesNiv))
    cas("et ne garde plus le chiffre du niveau 1", False,
        any(("DEGATS : %d " % d) in x for x in lignesNiv))
    hubT = (ROOT / "src" / "client" / "Hub.client.lua").read_text(encoding="utf-8")
    cas("le rendement affiche suit aussi le niveau", True,
        "ex.rendementSort = ex.rendementSort * ex.mult" in hubT)
    serveurTxt = (ROOT / "src" / "server" / "GameServer.server.lua").read_text(encoding="utf-8")
    cas("le serveur applique le niveau aux degats de sort", True,
        "Sorts.degats(sort, cible.isBuilding, multNiveau(team, card.id, true))" in serveurTxt)
    cas("aux deux endroits ou un sort blesse", 2,
        serveurTxt.count("Sorts.degats(sort, cible.isBuilding, multNiveau(team, card.id, true))"))
    cas("et au poison aussi", True,
        "(sort.parTic or 0) * multNiveau(team, card.id, true)" in serveurTxt)
    # Un sort sans degats (soin, rage) n'annonce aucun gain de degats.
    cas("un sort sans degats n'invente pas de gain", "", F.gainNiveau(byId["FuriaBrainrot"], 1, 0.10, 5))
    hubTxt = (ROOT / "src" / "client" / "Hub.client.lua").read_text(encoding="utf-8")
    cas("la fiche affiche les chiffres au niveau du joueur", True,
        "detailStats.Text = Fiche.stats(card, 1 + bonus * (niv - 1))" in hubTxt)
    cas("et le gain, seulement pour une carte possedee", True,
        "if vue and vue.cartes and vue.cartes[card.id] then" in hubTxt)
    cas("le bonus vient du serveur", True,
        "bonusParNiveau = Economie.BONUS_PAR_NIVEAU," in (ROOT / "src" / "server" / "Economie.lua").read_text(encoding="utf-8"))

    cas("sans extras, la fiche ignore la specialite", [], lignes(F, byId["Ballerina"]))
    balle = list(F.lignes(byId["Ballerina"], extras("Ballerina")).values())
    cas("ANTI-AIR nomme et chiffre", True,
        "ANTI-AIR" in " ".join(balle) and ("x%g" % SP.profil("Ballerina")["multiplicateur"]) in " ".join(balle))
    tung = list(F.lignes(byId["TungSahur"], extras("TungSahur")).values())
    cas("ANTI-ESSAIM nomme", True, "ANTI-ESSAIM" in " ".join(tung))
    lirili = list(F.lignes(byId["Lirili"], extras("Lirili")).values())
    gain = int(round((SO.profil("Lirili")["degats"] - 1) * 100))
    cas("le soutien annonce son vrai gain", True,
        "SOUTIEN" in " ".join(lirili) and ("+%d %%" % gain) in " ".join(lirili))
    cas("et son vrai rayon", True, ("%g studs" % SO.profil("Lirili")["rayon"]) in " ".join(lirili))
    spag = list(F.lignes(byId["Spaghettino"], extras("Spaghettino")).values())
    cas("un soutien de cadence parle de cadence", True, "cadence" in " ".join(spag))
    sout = [x for x in spag if x.startswith("SOUTIEN")]
    cas("la ligne SOUTIEN tient dans une tuile (<= 60 caracteres, unite comprise)", True,
        bool(sout) and len(sout[0]) <= 60 and "studs)" in sout[0])
    cas("etiquette ANTI-AIR", "ANTI-AIR", F.etiquette(byId["Ballerina"], extras("Ballerina")))
    cas("etiquette SOUTIEN", "SOUTIEN", F.etiquette(byId["Lirili"], extras("Lirili")))
    cas("une carte ordinaire reste sans etiquette", "", F.etiquette(tralalero, extras("Tralalero")))
    # Toute carte declaree specialiste ou soutien doit apparaitre dans une fiche : sinon la regle
    # existe dans le moteur mais reste invisible, exactement le defaut qu'on vient de corriger.
    muettes = []
    for cid in list(SP.PROFILS.keys()) + list(SO.PROFILS.keys()):
        if not list(F.lignes(byId[cid], extras(cid)).values()):
            muettes.append(cid)
    cas("aucune carte a regle de combat sans fiche", [], sorted(muettes))

    # 7. FICHE COMPLETE (ecran de detail) : statistiques brutes + TOUTES les lignes.
    stats = F.stats(byId["ScudoBanana"])
    for morceau in ("PV", "Degats", "Portee", "Vitesse"):
        cas("les stats citent %s" % morceau, True, morceau in stats)
    cas("les stats donnent les vrais PV", True, str(int(byId["ScudoBanana"]["hp"])) in stats)
    cas("un sort n'a pas de statistiques d'unite", True, "PV" not in F.stats(byId["GelatoGlaciale"]))
    cas("un sort de degats se compare par elixir", True, "par elixir" in F.stats(byId["PizzaBombarda"]))
    # Le resume de tuile CACHE des lignes ; la fiche complete ne doit en cacher aucune.
    bombardiro = byId["Bombardiro"]
    toutes = lignes(F, bombardiro)
    cas("la tuile annonce ce qu'elle cache", True, "(+" in F.resume(bombardiro, 2))
    cas("la fiche complete montre plus de lignes que la tuile", True, len(toutes) > 2)

    # 7. les ecrans l'affichent vraiment
    hub = HUB.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    cas("la boutique charge le module", True, 'WaitForChild("Fiche")' in hub)
    cas("la tuile montre ce que fait la carte", True, "Fiche.resume(" in hub)
    for ecran, nom in ((hub, "boutique"), (client, "main")):
        cas("la %s lit la specialite et le soutien" % nom, True,
            "Specialite.profil(" in ecran and "Soutien.profil(" in ecran)
    cas("la main charge le module", True, 'WaitForChild("Fiche")' in client)
    cas("la carte en main porte son etiquette", True, "Fiche.etiquette(" in client)
    cas("la boutique a un ecran de detail", True, "ouvrirDetail(" in hub and "Fiche.stats(" in hub)
    # TOUTES les lignes, avec les extras de la carte — enrichis du niveau du joueur depuis le
    # 2026-09-21 (`ex.mult`), d'ou l'appel en deux temps.
    cas("il montre TOUTES les lignes", True,
        "local ex = extrasDe(card.id)" in hub and "Fiche.lignes(card, ex)" in hub)
    cas("il s'ouvre au clic sur la tuile", True, "zoneDetail.MouseButton1Click" in hub)
    cas("et il se ferme", True, "detailFermer.MouseButton1Click" in hub)
    # L'ecran DECK est celui ou l'on CHOISIT ses cartes : c'est la que la fiche manquait le plus.
    cas("l'ecran DECK ouvre la fiche", True, "infoDeck.MouseButton1Click" in hub)
    # Le clic sur la TUILE du deck doit rester la SELECTION : la fiche passe par son propre bouton,
    # sinon on casserait le geste principal de l'ecran.
    deck = hub.split("-- DECK ---")[1]
    cas("le clic sur la tuile reste la selection", True, "basculer(card.id)" in deck)
    cas("la fiche du deck a son propre bouton", True, 'bouton(tuile, "?"' in deck)
    # EN PARTIE : la fiche doit s'ouvrir SANS abimer les deux gestes du jeu — choisir une carte
    # (clic gauche) et la poser (clic dans l'arene).
    cas("la main de partie ouvre une fiche", True, "ouvrirFiche(" in client)
    cas("elle montre toutes les lignes et les stats", True,
        "Fiche.lignes(card, extrasDe(card.id))" in client and "Fiche.stats(card)" in client)
    cas("elle s'ouvre au clic DROIT", True, "b.MouseButton2Click:Connect" in client)
    cas("et a l'appui long", True, "FICHE_APPUI_LONG" in client)
    cas("le clic gauche reste la selection", True, "selected = i" in client)
    cas("l'appui long n'entraine pas de selection en plus", True, "ignorerClic[i]" in client)
    cas("elle se ferme", True, "ficheFermer.MouseButton1Click" in client)
    # HAUTEUR AJUSTEE : une carte a un effet ne doit plus ouvrir un grand vide, une carte a cinq
    # lignes ne doit plus etre tronquee.
    h1 = F.hauteurPanneau(1)
    h3 = F.hauteurPanneau(3)
    h9 = F.hauteurPanneau(9)
    cas("plus de lignes, plus de hauteur", True, h3 > h1)
    cas("trois lignes de plus = trois hauteurs de ligne", 2 * float(F.PANNEAU_LIGNE), h3 - h1)
    # 0 ligne compte comme 1 (on affiche alors la description) : la hauteur reste au-dessus du
    # plancher, elle n'y est pas ramenee — c'est le plancher qui garantit un panneau lisible.
    cas("jamais plus petit que la borne basse", True, F.hauteurPanneau(0) >= float(F.PANNEAU_MIN))
    cas("une carte a effet unique reste compacte", True, h1 < 220)
    cas("jamais plus haut que la borne haute", float(F.PANNEAU_MAX), F.hauteurPanneau(50))
    cas("neuf lignes tiennent encore sans etre bornees", True, h9 < float(F.PANNEAU_MAX))
    cas("la zone de lignes tient entre l'entete et le bouton", True,
        F.hauteurListe(3) == h3 - float(F.PANNEAU_ENTETE) - float(F.PANNEAU_PIED))
    cas("une seule ligne laisse la place a cette ligne", True, F.hauteurListe(1) >= float(F.PANNEAU_LIGNE))
    cas("le panneau de partie applique la regle", True,
        "Fiche.hauteurPanneau(#lignes)" in client and "Fiche.hauteurListe(#lignes)" in client)
    # LE HUB SUIT LA MEME REGLE, avec son en-tete plus haut (il montre aussi la rarete). Deux
    # regles separees finiraient par diverger et un seul des deux ecrans serait corrige.
    cas("le hub applique la meme regle", True,
        "Fiche.hauteurPanneau(#lignes, ENTETE_FICHE_HUB)" in hub
        and "Fiche.hauteurListe(#lignes, ENTETE_FICHE_HUB)" in hub)
    cas("le panneau du hub n'est plus dimensionne en part d'ecran", False,
        "detail.Size = UDim2.new(0.62, 0, 0.66, 0)" in hub)
    # Un en-tete plus haut donne un panneau plus haut, a nombre de lignes egal.
    cas("un en-tete plus haut donne un panneau plus haut", True,
        F.hauteurPanneau(3, 146) > F.hauteurPanneau(3))
    cas("la zone de lignes reste la meme a nombre de lignes egal",
        F.hauteurListe(3), F.hauteurListe(3, 146))
    cas("les bornes valent aussi avec un autre en-tete", float(F.PANNEAU_MAX), F.hauteurPanneau(50, 146))
    # MARGE SOUS LA DERNIERE LIGNE : elle etait un reste de soustraction (8 px dans le hub, 12 en
    # partie). Elle est maintenant NOMMEE, et c'est elle qui compose le pied du panneau.
    cas("le pied se decompose en marge + bouton + bas",
        float(F.PANNEAU_MARGE) + float(F.PANNEAU_BOUTON) + float(F.PANNEAU_BAS), float(F.PANNEAU_PIED))
    cas("la marge laisse vraiment respirer", True, float(F.PANNEAU_MARGE) >= 20)
    # L'espace REEL entre la fin des lignes et le haut du bouton = pied - (bouton + bas).
    espace = float(F.PANNEAU_PIED) - (float(F.PANNEAU_BOUTON) + float(F.PANNEAU_BAS))
    cas("l'espace reel sous la derniere ligne vaut la marge", float(F.PANNEAU_MARGE), espace)
    # Les DEUX ecrans placent leur bouton avec ces constantes : ils ne peuvent plus diverger.
    for ecran, nom in ((client, "partie"), (hub, "hub")):
        cas("%s : le bouton est place par le module" % nom, True,
            "Fiche.PANNEAU_BOUTON" in ecran and "Fiche.PANNEAU_BAS" in ecran)
    # Meme a six lignes (aucune carte n'y est encore), la fiche reste dans les bornes.
    cas("six lignes tiennent encore", True, F.hauteurPanneau(6, 146) < float(F.PANNEAU_MAX))

    # 8. DESCENDANCE et RECUL : deux regles de combat de plus, declarees par identifiant dans leurs
    # propres modules. Sans fiche, un joueur ne pouvait pas savoir qu'abattre un Nuclearo lui en
    # remet trois sur les bras, ni qu'un Cocofanto PROJETTE ce qu'il frappe.
    nucl = list(F.lignes(byId["Nuclearo"], extras("Nuclearo")).values())
    profil_de = DE.profil("Nuclearo")
    cas("la descendance est nommee et chiffree", True,
        "LAISSE" in " ".join(nucl) and str(int(profil_de["nombre"])) in " ".join(nucl))
    cas("elle nomme la FILLE, pas son identifiant", True,
        byId[profil_de["fille"]]["name"] in " ".join(nucl))
    coco = list(F.lignes(byId["Cocofanto"], extras("Cocofanto")).values())
    # Le jeu ecrit ses decimales a la FRANCAISE (3,5 et non 3.5) : c'est la convention du module.
    distance_fr = ("%g" % RE.profil("Cocofanto")["distance"]).replace(".", ",")
    cas("le recul est nomme et chiffre", True,
        "REPOUSSE" in " ".join(coco) and (distance_fr + " studs") in " ".join(coco))
    cas("sans extras, ces regles n'apparaissent pas", [], lignes(F, byId["Cocofanto"]))
    # Aucune carte declaree dans ces modules ne doit rester muette.
    muettes2 = []
    for cid in list(DE.PROFILS.keys()) + list(RE.PROFILS.keys()):
        if not list(F.lignes(byId[cid], extras(cid)).values()):
            muettes2.append(cid)
    cas("aucune carte a descendance ou recul sans fiche", [], sorted(muettes2))
    for ecran, nom in ((hub, "boutique"), (client, "main")):
        cas("la %s lit la descendance et le recul" % nom, True,
            "Descendance.profil(" in ecran and "Recul.profil(" in ecran)
    # Le nombre de lignes VIENT du catalogue : la carte la plus fournie doit tenir sans troncature.
    maxi = max(len(lignes(F, c)) for c in liste)
    print("  carte la plus fournie : %d lignes -> panneau de %d px" % (maxi, F.hauteurPanneau(maxi)))
    cas("la carte la plus fournie tient sans etre bornee", True, F.hauteurPanneau(maxi) < float(F.PANNEAU_MAX))
    # La pose ignore ce qui est deja traite par l'interface : le panneau ouvert ne peut donc pas
    # faire poser une carte par megarde quand on le referme.
    cas("la pose ignore les clics pris par l'interface", True,
        "InputBegan:Connect(function(input, processed)" in client and "if processed then" in client)

    # LE BRANCHEMENT : les deux ecrans passent le rendement a la fiche (sinon la regle reste morte).
    hub = HUB.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    for nom, txt in (("le hub", hub), ("l'ecran de jeu", client)):
        cas("%s charge le module des sorts" % nom, True, 'WaitForChild("Sorts")' in txt)
        cas("%s passe le rendement a la fiche" % nom, True,
            "rendementSort = Cards.byId[id] and Sorts.degatsParElixir(Cards.byId[id])" in txt)
        cas("%s passe aussi la rentabilite du collecteur" % nom, True,
            "rentabilite = Cards.byId[id] and Batiments.texteRentabilite(Cards.byId[id])" in txt)
        # Les profils viennent des modules qui APPLIQUENT la regle, jamais d'une copie.
        cas("%s passe la charge a la fiche" % nom, True,
            'WaitForChild("Charge")).profil(id)' in txt)
        cas("%s passe l'assassin a la fiche" % nom, True,
            'WaitForChild("Assassin")).estAssassin(id)' in txt)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : chaque carte a effet dit ce qu'elle fait, avec les chiffres du catalogue")
    return 0


def _amelioration():
    from lupa import LuaRuntime
    L = LuaRuntime()
    NL = chr(10)
    src = pathlib.Path("src/shared/Fiche.lua").read_text(encoding="utf-8")
    a = src.index("function Fiche.texteAmelioration")
    b = src.index(NL + "end" + NL, a) + 5
    t = L.execute("local Fiche = {}" + NL + src[a:b] + NL + "return Fiche.texteAmelioration")
    assert t(0, 2, 100, 50) == "IL MANQUE 2 EXEMPLAIRES", t(0, 2, 100, 50)
    assert t(1, 2, 100, 50) == "IL MANQUE 1 EXEMPLAIRE"
    assert t(2, 2, 20, 50) == "IL MANQUE 30 PIECES"
    assert t(2, 2, 50, 50) == "AMELIORER 50"
    assert ".texteAmelioration(ex, besoin, v.pieces, cout)" in pathlib.Path("src/client/Hub.client.lua").read_text(encoding="utf-8")
    a = src.index("function Fiche.texteExemplaires"); b = src.index(NL + "end" + NL, a) + 5
    e = L.execute("local Fiche = {}" + NL + src[a:b] + NL + "return Fiche.texteExemplaires")
    assert e(0, 2) == "0/2 exemplaires - dans les coffres", e(0, 2)
    assert e(2, 2) == "2/2 exemplaires"
    a = src.index("function Fiche.texteAchat"); b = src.index(NL + "end" + NL, a) + 5
    ac = L.execute("local Fiche = {}" + NL + src[a:b] + NL + "return Fiche.texteAchat")
    assert ac(100, 1100) == "IL MANQUE 1000 PIECES", ac(100, 1100)
    assert ac(700, 700) == "ACHETER"
    assert ".texteAchat(v.pieces, card.prix)" in pathlib.Path("src/client/Hub.client.lua").read_text(encoding="utf-8")
    print("VERT : le bouton AMELIORER dit ce qui manque, au lieu de promettre un clic refuse")

_amelioration()
sys.exit(main())
