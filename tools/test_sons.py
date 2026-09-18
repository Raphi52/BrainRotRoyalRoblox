# -*- coding: utf-8 -*-
"""Banc hors Studio pour src/shared/Sons.lua (lupa = vrai interpreteur Lua).

Ce qu'il verifie :
 1. chaque evenement de jeu produit REELLEMENT un Sound joue, avec un SoundId non vide ;
 2. aucun son ne depend d'un identifiant de la bibliotheque (rbxassetid://) -- uniquement des
    fichiers livres avec le client (rbxasset://sounds/...), et ces fichiers EXISTENT sur disque ;
 3. les sons sont BRANCHES : le client appelle bien Sons.jouer pour chaque evenement attendu.

Prerequis : python -m pip install lupa
"""
# fix-ok: cause mesuree = lupa expose Lua 5.4 sans aucune API Roblox ; on double Instance/
# SoundService/Debris pour ENREGISTRER ce qui est cree au lieu de le jouer.
import sys
import glob
import os
import pathlib
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Sons.lua"
CLIENT = ROOT / "src" / "client" / "GameClient.client.lua"
HUB = ROOT / "src" / "client" / "Hub.client.lua"

PRELUDE = r"""
CREES = 0
JOUES = 0
DERNIER = nil
DEBRIS = 0
local SoundService = { ClassName = "SoundService" }
local Debris = { AddItem = function(_, _i, _t) DEBRIS = DEBRIS + 1 end }
local services = { SoundService = SoundService, Debris = Debris }
game = { GetService = function(_, n) return services[n] end }
Instance = { new = function(cls)
  CREES = CREES + 1
  local o = { ClassName = cls }
  o.Play = function(self) JOUES = JOUES + 1; DERNIER = self end
  o.Stop = function(self) self.arrete = true end
  o.Destroy = function(self) self.detruit = true end
  return o
end }
"""

ATTENDUS = ["selection", "pose", "mort", "tourDetruite",
            "victoire", "defaite", "clic", "coffre", "refus",
            "tir", "coupMelee", "explosion"]


def main():
    if not SRC.exists():
        print("ROUGE : %s absent -- le jeu est muet" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(PRELUDE)
    Sons = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    g = lua.globals()

    echecs = []
    manquants = [n for n in ATTENDUS if Sons.banque[n] is None]
    if manquants:
        print("ROUGE : sons manquants -> %s" % ", ".join(manquants))
        return 1

    # 1. chaque evenement joue reellement un Sound
    dossiers = glob.glob(r"C:\Program Files (x86)\Roblox\Versions\*\content\sounds")
    for nom in ATTENDUS:
        avant = int(g.JOUES)
        s = Sons.jouer(nom)
        if int(g.JOUES) != avant + 1 or s is None:
            echecs.append("Sons.jouer('%s') n'a joue aucun son" % nom)
            continue
        if s.ClassName != "Sound":
            echecs.append("%s : instance %s au lieu de Sound" % (nom, s.ClassName))
        sid = s.SoundId or ""
        if not sid.startswith("rbxasset://sounds/"):
            echecs.append("%s : SoundId non portable (%s)" % (nom, sid))
        elif dossiers:
            fichier = sid.split("/")[-1]
            if not any(os.path.exists(os.path.join(d, fichier)) for d in dossiers):
                echecs.append("%s : fichier %s absent du client Roblox installe" % (nom, fichier))
        if not s.Volume or s.Volume <= 0:
            echecs.append("%s : volume nul" % nom)
    if int(g.DEBRIS) < len(ATTENDUS):
        echecs.append("nettoyage Debris incomplet (%d)" % int(g.DEBRIS))
    if "rbxassetid" in SRC.read_text(encoding="utf-8"):
        echecs.append("le module depend d'un identifiant de bibliotheque : non portable")

    # 2. un nom inconnu ne casse rien
    if Sons.jouer("inconnu") is not None:
        echecs.append("un nom inconnu devrait rendre nil sans rien jouer")

    # 3. branchement reel cote client
    client = CLIENT.read_text(encoding="utf-8")
    hub = HUB.read_text(encoding="utf-8")
    for f, texte in (("GameClient", client), ("Hub", hub)):
        if 'WaitForChild("Sons")' not in texte:
            echecs.append("%s ne charge pas le module Sons" % f)
    attendu_client = ["selection", "pose", "mort", "tourDetruite", "victoire", "defaite"]
    attendu_hub = ["clic", "coffre", "refus"]
    for n in attendu_client:
        if ('Sons.jouer("%s"' % n) not in client:
            echecs.append("GameClient ne joue jamais le son '%s'" % n)
    for n in attendu_hub:
        if ('Sons.jouer("%s"' % n) not in hub:
            echecs.append("Hub ne joue jamais le son '%s'" % n)
    # 5. combat : cadence limitee a 6 sons par seconde
    if Sons.limiteur is None:
        echecs.append("Sons.limiteur absent : une melee saturerait le son")
    else:
        lim = Sons.limiteur(6)
        rafale = sum(1 for i in range(100) if lim(10.0 + i * 0.01))  # 100 demandes en 1 s
        if rafale > 12 or rafale < 6:
            echecs.append("limiteur : %d sons en 1 s (attendu 6 a 12 : 6 d'avance + 6/s)" % rafale)
        lim2 = Sons.limiteur(6)
        long = sum(1 for i in range(1000) if lim2(i * 0.01))  # 10 s de demandes continues
        if long > 6 * 10 + 6:
            echecs.append("limiteur : %d sons en 10 s, plus de 6/s" % long)
    for n in ("tir", "coupMelee", "explosion"):
        if ('Sons.jouer("%s"' % n) not in client:
            echecs.append("GameClient ne joue jamais le son de combat '%s'" % n)
    serveur = (ROOT / "src" / "server" / "GameServer.server.lua").read_text(encoding="utf-8")
    if "combat = combat" not in serveur:
        echecs.append("le serveur n'envoie pas les compteurs de combat dans l'etat")
    # 6. ambiance bouclee, dans un groupe de volume, une seule a la fois, tension sous 60 s
    if Sons.boucle is None:
        echecs.append("Sons.boucle absent : aucun fond sonore")
    else:
        h = Sons.boucle("hub")
        c = Sons.boucle("combat")
        if h is None or c is None or not c.Looped or c.SoundGroup is None:
            echecs.append("boucle : son non boucle ou hors groupe de volume")
        elif not h.arrete:
            echecs.append("boucle : l'ambiance du hub continue sous le combat")
        elif not str(c.SoundId).startswith("rbxasset://sounds/"):
            echecs.append("boucle : SoundId non portable")
        if Sons.tension(90) != 1 or not (1.25 < Sons.tension(5) <= 1.3):
            echecs.append("tension : pas de montee sous 60 s")
        if 'Sons.boucle("hub")' not in hub or 'Sons.boucle("combat")' not in hub:
            echecs.append("Hub ne lance pas les ambiances")
        if "Sons.tension(" not in client:
            echecs.append("GameClient n'applique pas la tension")
    # 7. secousse proportionnelle : tour > mort > zone
    if "secouer(SECOUSSE.mort)" not in client or "secouer(SECOUSSE.zone)" not in client:
        echecs.append("secousse : ni mort d'unite ni impact de zone ne secouent la camera")
    import re
    m = re.search(r"SECOUSSE = \{ tour = ([\d.]+), mort = ([\d.]+), zone = ([\d.]+) \}", client)
    if not m or not (float(m.group(1)) > float(m.group(2)) > float(m.group(3))):
        echecs.append("secousse : amplitudes non ordonnees tour > mort > zone")
    # 4. le module doit etre EMBARQUE dans la place, sinon require() echoue en jeu
    if 'shared/Sons.lua' not in (ROOT / "build.py").read_text(encoding="utf-8"):
        echecs.append("build.py n'embarque pas Sons.lua dans la place")

    print("sons crees :", int(g.CREES), "| joues :", int(g.JOUES), "| nettoyages :", int(g.DEBRIS))
    if echecs:
        for e in echecs:
            print("ROUGE :", e)
        return 1
    print("VERT : %d evenements sonores joues, tous depuis des fichiers livres avec Roblox." % len(ATTENDUS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
