# -*- coding: utf-8 -*-
"""Le tutoriel est-il reellement BRANCHE, et pas seulement ecrit ?

`src/shared/Tutoriel.lua` etait complet et couvert par test_tutoriel.py, mais AUCUN code ne
l'appelait : un joueur neuf n'a jamais vu le tutoriel. Ce test fige le cablage lui-meme.

1. LOGIQUE (executee avec lupa) : Tutoriel.obligatoire dit oui a un profil neuf, non des la
   premiere partie jouee.
2. CABLAGE (lu dans les sources) : le serveur importe le module, lance le tutoriel a l'entree en
   partie, refuse les cartes hors etape, fait taire le robot, marque le profil a la fin, ne le
   marque PAS sur un abandon ; le profil persiste le marqueur avec sa retro-compatibilite ; le
   menu porte le bouton de relance et l'action est acceptee par le serveur.
"""
import re, sys, pathlib
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
TUTO = (ROOT / "src/shared/Tutoriel.lua").read_text(encoding="utf-8")
SRV = (ROOT / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
ECO = (ROOT / "src/server/Economie.lua").read_text(encoding="utf-8")
HUB = (ROOT / "src/client/Hub.client.lua").read_text(encoding="utf-8")
CLI = (ROOT / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
e = []

# 1. logique du module
lua = LuaRuntime()
mod = lua.execute(TUTO)
cas = [
    ("profil neuf", {"parties": 0}, True),
    ("une partie jouee", {"parties": 1}, False),
    ("joueur chevronne", {"parties": 250}, False),
]
for nom, profil, attendu in cas:
    obtenu = mod.obligatoire(lua.table_from(profil))
    print("  %s  tutoriel obligatoire pour %s : attendu %s, obtenu %s"
          % ("OK   " if obtenu == attendu else "RATE ", nom, attendu, obtenu))
    if obtenu != attendu:
        e.append("Tutoriel.obligatoire(%s) rend %s" % (nom, obtenu))
if mod.obligatoire(None) is not False:
    e.append("Tutoriel.obligatoire(nil) doit rendre false, pas une erreur")

# 2. cablage reel
attendus = [
    (SRV, r'require\(.*"Tutoriel"\)', "serveur : le module Tutoriel n'est pas importe"),
    (SRV, r"Tutoriel\.obligatoire\(", "serveur : le tutoriel n'est jamais declenche pour un profil neuf"),
    (SRV, r"Tutoriel\.carteJouable\(", "serveur : les cartes hors etape ne sont pas refusees"),
    (SRV, r"Tutoriel\.ROBOT_SILENCE", "serveur : le robot n'est pas fait taire au debut du tutoriel"),
    (SRV, r"Tutoriel\.suivante\(", "serveur : les etapes du tutoriel n'avancent jamais"),
    (SRV, r"Economie\.marquerTutoriel\(", "serveur : le tutoriel n'est jamais marque comme fait"),
    (SRV, r'action == "tutoriel"', "serveur : l'action de relance du menu n'est pas acceptee"),
    (ECO, r"function Economie\.marquerTutoriel", "economie : pas de marquage persiste"),
    (ECO, r"p\.tutoFait = p\.tutoFait or false", "economie : les anciens profils ne sont pas migres"),
    (HUB, r"REVOIR LE TUTORIEL", "menu : pas de bouton de relance"),
    (HUB, r'InvokeServer\("tutoriel"\)', "menu : le bouton n'appelle pas le serveur"),
    (SRV, r"tuto = \(tuto\.actif", "serveur : l'etape du tutoriel n'est pas envoyee au client"),
    (CLI, r"appliquerTuto\(s\.tuto\)", "client : l'etape recue n'est jamais mise en scene"),
    (CLI, r'montrer == "camera_suit"', "client : la camera ne se rapproche pas a l'etape prevue"),
    (CLI, r'tutoMontrer == "jauge"', "client : la jauge d'elixir ne pulse pas quand l'elixir manque"),
    (CLI, r"tutoDoigt", "client : pas de doigt pose sur la zone a toucher"),
    (CLI, r"horsEtape", "client : les cartes hors etape ne sont pas grisees"),
]
for source, motif, message in attendus:
    if not re.search(motif, source):
        e.append(message)

# un abandon ne doit pas valider le tutoriel : la remise a zero vit dans `quitter`
# Decoupe par LIGNES plutot que par expression reguliere : un motif « corps de fonction » lance
# sur un fichier de 2700 lignes partait en explosion combinatoire (test bloque plus de 3 min).
lignes = SRV.splitlines()
# `quitter` porte desormais un second argument (depart volontaire ou coupure reseau) : on repere la
# fonction sur son NOM, pas sur sa signature exacte.
debut = next((k for k, l in enumerate(lignes) if l.startswith("local function quitter(player")), None)
corps = ""
if debut is not None:
    fin = next((k for k in range(debut + 1, len(lignes)) if lignes[k] == "end"), debut)
    corps = chr(10).join(lignes[debut:fin])
if "tuto.actif = false" not in corps:
    e.append("serveur : quitter() ne coupe pas le tutoriel en cours (il serait compte comme fait)")

# FINS D'ETAPE PAR L'ACTION, pas par le chronometre : `tourTombee` et `volantAbattu` doivent
# etre constatees la ou passent toutes les morts (damage), et remises a zero a chaque etape.
for motif, message in [
    (r'fin == "tourTombee"', "serveur : la chute d'une tour ne termine jamais son etape"),
    (r'fin == "volantAbattu"', "serveur : abattre un volant ne termine jamais son etape"),
    (r"target\.isBuilding == true and target\.carte == nil",
     "serveur : une tour n'est pas distinguee d'un batiment pose par une carte"),
    (r"target\.flying == true", "serveur : le vol de la cible n'est pas lu sur l'entite"),
    (r"tuto\.conditionFaite = false", "serveur : la condition n'est pas remise a zero entre deux etapes"),
    (r"or tuto\.conditionFaite", "serveur : la condition constatee ne fait pas avancer l'etape"),
]:
    if not re.search(motif, SRV):
        e.append(message)

# la detection doit vivre DANS la fonction de degats : ailleurs, la mort n'est pas visible
deb = next((k for k, l in enumerate(lignes) if l.startswith("local function damage(")), None)
if deb is None:
    e.append("serveur : fonction damage() introuvable")
else:
    f = next((k for k in range(deb + 1, len(lignes)) if lignes[k] == "end"), deb)
    if 'fin == "tourTombee"' not in chr(10).join(lignes[deb:f]):
        e.append("serveur : la detection de fin d'etape n'est pas dans damage()")

if e:
    print("\n".join("ROUGE " + x for x in e))
    print("%d echec(s)" % len(e))
    sys.exit(1)
print("VERT : tutoriel branche du profil neuf jusqu'au bouton de relance du menu")
