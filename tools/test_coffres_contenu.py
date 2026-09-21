# -*- coding: utf-8 -*-
"""Banc du CONTENU DES COFFRES (src/shared/Coffres.lua + la rangee de coffres).

Defaut corrige le 2026-09-21 : la rangee affichait « Coffre en bois / DEMARRER » puis un compte a
rebours. Nulle part le joueur ne voyait ce que le coffre contient — ni les pieces, ni les
exemplaires, ni la chance d'y trouver une carte encore verrouillee. Or il doit CHOISIR : une seule
ouverture tourne a la fois, et les durees vont de 15 minutes a 3 heures. Il decidait a l'aveugle
quel coffre lancer avant d'aller dormir.

Ce qu'il verifie :
  1. la mise en mots (duree, fourchette de pieces, chance de carte) ;
  2. les cas ou l'on se TAIT plutot que d'afficher un chiffre inutile ;
  3. les chiffres viennent du serveur, jamais recopies dans l'ecran ;
  4. la rangee de coffres l'affiche vraiment, et l'efface sur un emplacement vide.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Coffres.lua"
ECO = ROOT / "src" / "server" / "Economie.lua"
HUB = ROOT / "src" / "client" / "Hub.client.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    K = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    eco = ECO.read_text(encoding="utf-8")
    hub = HUB.read_text(encoding="utf-8")
    tbl = lua.table_from

    # 1. DUREES : les heures d'abord, c'est ce qui decide si on lance ce coffre maintenant.
    cas("un quart d'heure", "15 min", K.duree(15 * 60))
    cas("une heure pile", "1 h", K.duree(3600))
    cas("trois heures", "3 h", K.duree(3 * 3600))
    cas("une heure et demie", "1 h 30", K.duree(90 * 60))
    cas("zero ne casse rien", "0 min", K.duree(0))

    # 2. PIECES
    cas("une fourchette", "20-40", K.pieces(tbl([20, 40])))
    # Une fourchette plate se dit d'un seul chiffre : « 20-20 » ferait croire a un choix.
    cas("une fourchette plate", "20", K.pieces(tbl([20, 20])))
    cas("sans bornes, zero", "0", K.pieces(None))

    # 3. CHANCE DE CARTE : « 100 % » se lit comme un chiffre parmi d'autres, alors que c'est LA
    # raison d'ouvrir un coffre d'or. On le dit en toutes lettres.
    # Libelle COURT : la tuile fait un huitieme d'ecran et le texte long y etait coupe en plein
    # milieu (capture cap-coffres2.png du 2026-09-21).
    cas("une chance sur dix", "10 % carte", K.chance(0.10))
    cas("une chance certaine se dit autrement", "carte garantie", K.chance(1.0))
    # Aucune chance : on se tait plutot que d'ecrire « 0 % ».
    cas("aucune chance : aucune mention", None, K.chance(0))

    # 4. LA LIGNE
    bois = lua.eval("(function(p) return { pieces = p, exemplaires = 3, chanceCarte = 0.1,"
                    " duree = 900 } end)")(tbl([20, 40]))
    ligne = K.ligne(bois)
    for bout in ("20-40 pieces", "3 ex.", "10 % carte"):
        cas("la ligne porte %s" % bout, True, bout in ligne)
    cas("sans info, aucune ligne", "", K.ligne(None))
    # Un coffre sans exemplaires ne doit pas afficher « 0 exemplaires ».
    sans = lua.eval("(function(p) return { pieces = p, exemplaires = 0, chanceCarte = 0 } end)")(tbl([5, 5]))
    cas("aucun exemplaire : rien a ce sujet", False, "ex." in K.ligne(sans))
    # La ligne doit tenir dans une tuile etroite : au-dela, elle est coupee a l'ecran.
    cas("la ligne reste courte", True, len(ligne) <= 34)

    # 5. LES CHIFFRES VIENNENT DU SERVEUR ---------------------------------------------------------
    cas("la vue du profil porte le contenu des coffres", True, "coffresInfos = (function()" in eco)
    cas("tire des reglages reels", True,
        "local c = Economie.COFFRES[t]" in eco and "Economie.EXEMPLAIRES_COFFRE[t]" in eco)
    cas("pour chaque type de coffre", True, "for _, t in ipairs(Economie.ORDRE_COFFRES)" in eco)

    # 6. L'ECRAN L'AFFICHE -------------------------------------------------------------------------
    cas("le hub charge le module", True, 'WaitForChild("Coffres")' in hub)
    cas("la ligne vient du module", True, "Coffres.ligne(info)" in hub)
    cas("la duree d'attente aussi", True, "Coffres.duree(info.duree)" in hub)
    cas("les chiffres viennent de la vue", True, "vue.coffresInfos and vue.coffresInfos[c.type]" in hub)
    # Un emplacement VIDE ne doit pas garder le detail du coffre precedent.
    cas("un emplacement vide efface le detail", True, 'e.detail.Text = ""' in hub)
    # Le texte se pose SUR le dessin du coffre : sans bandeau derriere lui, la bande doree et la
    # serrure le coupaient en deux (captures cap-coffres2/3/4.png du 2026-09-21).
    cas("le detail a un fond qui le detache du coffre", True,
        "detail.BackgroundColor3 = Color3.fromRGB(14, 16, 28)" in hub and "detail.ZIndex = 6" in hub)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : chaque coffre dit ce qu'il contient et combien de temps il fait attendre")
    return 0



# --- EMPLACEMENTS PLEINS : victoire sans coffre annoncee (fin de partie + accueil) ---
def _pleins():
    import lupa, pathlib
    L = lupa.LuaRuntime()
    C = L.execute(pathlib.Path("src/shared/Coffres.lua").read_text(encoding="utf-8"))
    assert C.plein(4, 4) and not C.plein(3, 4)
    assert C.alertePlein(3, 4) == "" and "pleins" in C.alertePlein(4, 4)
    assert "pleins" in C.textePerdu()
    eco = pathlib.Path("src/server/Economie.lua").read_text(encoding="utf-8")
    assert "coffrePerdu = coffrePerdu" in eco
    assert "g.coffrePerdu" in pathlib.Path("src/client/GameClient.client.lua").read_text(encoding="utf-8")
    assert "Coffres.alertePlein" in pathlib.Path("src/client/Hub.client.lua").read_text(encoding="utf-8")
    print("VERT : coffre perdu annonce en fin de partie et a l'accueil")

def _file():
    import lupa, pathlib
    L = lupa.LuaRuntime(); C = L.execute(pathlib.Path("src/shared/Coffres.lua").read_text(encoding="utf-8"))
    t = L.eval("{ {fin=0}, {fin=200} }")
    assert C.unEnCours(t, 100) and not C.unEnCours(t, 300)
    assert C.etatAttente(True) == "EN FILE" and C.etatAttente(False) == "DEMARRER"
    assert "Coffres.etatAttente" in pathlib.Path("src/client/Hub.client.lua").read_text(encoding="utf-8")
    print("VERT : un coffre en attente dit EN FILE quand un autre s'ouvre deja")

def _gemmes():
    import lupa, pathlib
    L = lupa.LuaRuntime(); C = L.execute(pathlib.Path("src/shared/Coffres.lua").read_text(encoding="utf-8"))
    for reste, att in ((0, 0), (1, 1), (600, 1), (601, 2), (47*60, 5), (3*3600, 18)):
        assert C.coutGemmes(reste) == att, (reste, C.coutGemmes(reste))
    assert C.texteEnCours(47*60) == "47:00  |  5 gemmes", C.texteEnCours(47*60)
    eco = pathlib.Path("src/server/Economie.lua").read_text(encoding="utf-8")
    assert "function Economie.accelererCoffre" in eco and "p.gemmes -= cout" in eco
    assert '"accelererCoffre"' in pathlib.Path("src/server/GameServer.server.lua").read_text(encoding="utf-8")
    assert '"accelererCoffre"' in pathlib.Path("src/client/Hub.client.lua").read_text(encoding="utf-8")
    print("VERT : les gemmes ouvrent un coffre en cours, 1 gemme par 10 min restantes")

def _confirmer():
    import lupa, pathlib
    L = lupa.LuaRuntime(); C = L.execute(pathlib.Path("src/shared/Coffres.lua").read_text(encoding="utf-8"))
    a = L.eval("{ index = 2, jusqua = 104 }")
    assert C.doitConfirmer(None, 2, 100)          # 1er clic : on demande
    assert not C.doitConfirmer(a, 2, 103)         # 2e clic a temps sur le meme coffre : achat
    assert C.doitConfirmer(a, 3, 103)             # autre coffre : on redemande
    assert C.doitConfirmer(a, 2, 105)             # trop tard : on redemande
    assert C.texteConfirmer(47*60) == "CONFIRMER : 5 gemmes"
    hub = pathlib.Path("src/client/Hub.client.lua").read_text(encoding="utf-8")
    i = hub.index('action = "accelererCoffre"'); j = hub.index("Boutique:InvokeServer(action, i)")
    assert "doitConfirmer" in hub[i:j] and "return" in hub[i:j], "le 1er clic doit s'arreter avant le serveur"
    print("VERT : les gemmes ne partent qu'au 2e clic sur le meme coffre, dans les 4 s")

def _aide():
    import lupa, pathlib
    L = lupa.LuaRuntime(); C = L.execute(pathlib.Path("src/shared/Coffres.lua").read_text(encoding="utf-8"))
    txt = C.texteGemmes(0, 2)
    assert "0 gemmes" in txt and "1 par 10 min" in txt and "2 par quete" in txt, txt
    hub = pathlib.Path("src/client/Hub.client.lua").read_text(encoding="utf-8")
    assert ".texteGemmes(" in hub and "Quetes\")).GEMMES" in hub.replace('"', '\"') or "GEMMES)" in hub
    assert "bulle.Visible = not bulle.Visible" in hub
    print("VERT : le jeton de gemmes explique a quoi elles servent et comment en gagner")

def _utiles():
    import lupa, pathlib
    L = lupa.LuaRuntime(); C = L.execute(pathlib.Path("src/shared/Coffres.lua").read_text(encoding="utf-8"))
    u = list(C.cartesUtiles(L.eval("{ 'a', 'b', 'c' }"), L.eval("{ a = 5, b = 4 }"), 5).values())
    assert u == ["b", "c"], u
    assert len(C.cartesUtiles(L.eval("{ 'a' }"), L.eval("{ a = 5 }"), 5)) == 0
    eco = pathlib.Path("src/server/Economie.lua").read_text(encoding="utf-8")
    assert "Coffres.cartesUtiles(Economie.deck(player), p.niveaux, Economie.NIVEAU_MAX)" in eco
    assert "gain.exemplaires * Coffres.PIECES_PAR_EXEMPLAIRE" in eco
    print("VERT : les exemplaires d'un coffre ne tombent plus sur une carte deja au maximum")

_utiles()
_aide()
_pleins()
_file()
_gemmes()
_confirmer()
sys.exit(main())
