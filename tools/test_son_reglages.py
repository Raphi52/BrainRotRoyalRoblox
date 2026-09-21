# -*- coding: utf-8 -*-
"""Banc des REGLAGES SONORES (src/shared/Sons.lua + profil + ecrans).

Defaut corrige le 2026-09-20 : le jeu jouait musique et bruitages sans qu'AUCUN ecran ne permette
de les couper. Un joueur qui ecoute autre chose, ou qui joue a cote de quelqu'un, n'avait qu'une
solution : couper le son de tout son appareil. Et Roblox n'offrant aucun stockage local, un
reglage garde chez le client serait reperdu a chaque partie : il devait aller dans le profil.

Ce qu'il verifie, en EXECUTANT le module dans un faux Roblox :
  1. couper les bruitages ne cree plus aucun son (et non un son a volume zero, qui reste charge) ;
  2. couper la musique met le GROUPE d'ambiance a zero — y compris une boucle lancee APRES ;
  3. les deux reglages sont independants, et `nil` veut dire « ne change pas celui-la » ;
  4. le libelle affiche vient du module (les deux ecrans ne peuvent pas diverger) ;
  5. le serveur garde le reglage dans le profil et le rend dans la vue ;
  6. les ecrans du menu ET de la partie l'ouvrent, et le client applique le profil a l'arrivee.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Sons.lua"
ECO = ROOT / "src" / "server" / "Economie.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
HUB = ROOT / "src" / "client" / "Hub.client.lua"

ECHECS = []

# Faux Roblox : on garde la trace des objets crees, c'est ce qui permet de dire « aucun son cree »
# plutot que « la fonction a rendu nil ».
PRELUDE = """
CREES = {}
local function objet(cls)
  local o = { ClassName = cls, Volume = 0, PlaybackSpeed = 1, Name = "" }
  o.Play = function() o.joue = true end
  o.Stop = function() o.joue = false end
  o.Destroy = function() o.detruit = true end
  table.insert(CREES, o)
  return o
end
Instance = { new = objet }
local services = {
  SoundService = { nom = "SoundService" },
  Debris = { AddItem = function() end },
}
game = { GetService = function(_, n) return services[n] end }
"""


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(PRELUDE)
    S = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    crees = lua.globals().CREES

    def nb():
        return len(list(crees.values()))

    # 0. tout est allume par defaut : le jeu doit sonner sans rien regler.
    cas("la musique est allumee par defaut", True, S.reglages.musique)
    cas("les bruitages aussi", True, S.reglages.bruitages)

    # 1. bruitages coupes : AUCUN objet son cree
    avant = nb()
    cas("un bruitage se joue normalement", True, S.jouer("clic") is not None)
    cas("et il a bien cree un son", True, nb() > avant)
    S.regler(None, False)
    avant = nb()
    cas("bruitages coupes : rien n'est joue", None, S.jouer("clic"))
    cas("et AUCUN son n'est cree", avant, nb())
    # `nil` ne touche pas l'autre reglage : sans cela, couper les bruitages couperait la musique.
    cas("la musique n'a pas ete touchee", True, S.reglages.musique)
    S.regler(None, True)
    cas("on peut les rallumer", True, S.jouer("clic") is not None)

    # 2. musique coupee : le GROUPE tombe a zero
    boucle = S.boucle("hub")
    cas("une ambiance se lance", True, boucle is not None)
    groupe = boucle.SoundGroup
    cas("elle passe par le groupe de volume", True, groupe is not None)
    cas("groupe a plein volume tant que la musique est allumee", 1, groupe.Volume)
    S.regler(False, None)
    cas("musique coupee : le groupe tombe a zero", 0, groupe.Volume)
    cas("les bruitages restent allumes", True, S.reglages.bruitages)
    # Une ambiance lancee APRES la coupure ne doit pas la rallumer : c'est le piege evident.
    b2 = S.boucle("combat")
    cas("une ambiance lancee apres la coupure reste muette", 0, b2.SoundGroup.Volume)
    S.regler(True, None)
    cas("rallumer la musique remet le groupe", 1, b2.SoundGroup.Volume)

    # 3. libelles : ecrits par le module, donc identiques dans les deux ecrans
    cas("libelle musique allumee", "MUSIQUE : OUI", S.libelle("musique"))
    # CAS ASYMETRIQUE, celui qui a echappe au banc et que la photo a montre : musique coupee,
    # bruitages allumes. Une ecriture « a and b or c » retombe sur c et affiche « OUI » a tort.
    S.regler(False, True)
    cas("musique coupee et bruitages allumes : le libelle ne se trompe pas",
        ["MUSIQUE : NON", "BRUITAGES : OUI"], [S.libelle("musique"), S.libelle("bruitages")])
    S.regler(True, False)
    cas("et dans l'autre sens", ["MUSIQUE : OUI", "BRUITAGES : NON"],
        [S.libelle("musique"), S.libelle("bruitages")])
    S.regler(True, True)
    S.regler(False, False)
    cas("libelle musique coupee", "MUSIQUE : NON", S.libelle("musique"))
    cas("libelle bruitages coupes", "BRUITAGES : NON", S.libelle("bruitages"))
    S.regler(True, True)
    cas("libelle bruitages allumes", "BRUITAGES : OUI", S.libelle("bruitages"))

    # 4. LE SERVEUR LE GARDE ----------------------------------------------------------------------
    eco = ECO.read_text(encoding="utf-8")
    serveur = SERVEUR.read_text(encoding="utf-8")
    hub = HUB.read_text(encoding="utf-8")
    cas("un profil neuf a le son allume", True, "son = { musique = true, bruitages = true } }" in eco)
    cas("un ancien profil en recoit un", True,
        "p.son = p.son or { musique = true, bruitages = true }" in eco)
    cas("le serveur sait le regler", True, "function Economie.reglerSon(player, musique, bruitages)" in eco)
    # Sans marquerSale, le reglage vivrait en memoire et serait perdu au changement de serveur.
    bloc = eco.split("function Economie.reglerSon")[1].split("\nend")[0]
    cas("et il le fait sauvegarder", True, "Economie.marquerSale(player)" in bloc)
    cas("la vue du profil le porte", True, "son = p.son or { musique = true, bruitages = true }," in eco)
    cas("une action du menu l'ecrit", True, 'elseif action == "son" then' in serveur)
    cas("elle lit les deux champs", True,
        "Economie.reglerSon(player, reglage.musique, reglage.bruitages)" in serveur)

    # 5. LES ECRANS ------------------------------------------------------------------------------
    cas("un bouton SON au menu", True, 'local boutonSon = bouton(accueil, "SON"' in hub)
    cas("un bouton SON en partie", True, 'local boutonSonJeu = bouton(gui, "SON"' in hub)
    cas("il n'apparait qu'en partie, avec le bouton MENU", True,
        "boutonSonJeu.Visible = boutonMenu.Visible" in hub)
    cas("les deux ouvrent le MEME panneau", True, hub.count("function ouvrirSon") == 1)
    cas("les libelles viennent du module", True,
        'Sons.libelle("musique")' in hub and 'Sons.libelle("bruitages")' in hub)
    cas("le changement s'applique tout de suite chez le client", True, "Sons.regler(m, b)" in hub)
    cas("puis part au serveur pour etre garde", True, 'Boutique:InvokeServer("son", {' in hub)
    cas("et le profil est applique a l'arrivee", True,
        "Sons.regler(v.son.musique, v.son.bruitages)" in hub)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : musique et bruitages se coupent separement, au menu comme en partie, et ca se garde")
    return 0


sys.exit(main())
