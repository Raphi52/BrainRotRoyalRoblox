# -*- coding: utf-8 -*-
"""Banc des SPECIALITES (src/shared/Specialite.lua) : anti-air et anti-groupe.

Defaut mesure avant ce module : une unite faisait les memes degats a tout le monde. Un volant se
repoussait avec n'importe quel tireur, un essaim avec n'importe quelle unite de zone — aucune
raison de GARDER une carte pour la menace qu'elle contre.

Ce qu'il verifie :
  1. seules les cartes declarees ont une specialite, et elles existent au catalogue ;
  2. COHERENCE avec le catalogue : un anti-air peut vraiment viser les volants, un anti-groupe
     frappe vraiment en zone — c'est le controle qui empeche une promesse intenable ;
  3. le bonus ne s'applique QU'A la bonne categorie, et jamais aux batiments ;
  4. un essaim volant est contre par les DEUX specialites, chacune de son cote ;
  5. une carte ordinaire ne gagne jamais rien ;
  6. les degats restent entiers et bornes ;
  7. chaque specialite a au moins un contre REELLEMENT disponible dans le catalogue ;
  8. le serveur applique reellement la regle, cible par cible.

Prerequis : python -m pip install lupa
"""
import pathlib
import re
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Specialite.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
CARTES = ROOT / "src" / "shared" / "Cards.lua"
BUILD = ROOT / "build.py"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def catalogue():
    """Lit le catalogue reel : { id : {targets, range, splash, flying, count} }."""
    s = CARTES.read_text(encoding="utf-8")
    out = {}
    for bloc in s.split("\t{")[1:]:
        m = re.search(r'id = "(\w+)"', bloc)
        if not m:
            continue
        tete = bloc[:1400]

        def val(cle, defaut=None):
            g = re.search(cle + r" = ([^,\n]+)", tete)
            if not g:
                return defaut
            v = g.group(1).strip().strip('"')
            if v in ("true", "false"):
                return v == "true"
            try:
                return float(v)
            except ValueError:
                return v
        out[m.group(1)] = dict(targets=val("targets", "any"), range=val("range", 0),
                               splash=val("splash", 0), flying=val("flying", False),
                               count=val("count", 1), sort="sort = " in tete)
    return out


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — toutes les unites frappent pareil" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    S = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    cat = catalogue()

    noms = sorted(S.PROFILS.keys())
    par_categorie = {}
    for n in noms:
        par_categorie.setdefault(S.profil(n).contre, []).append(n)
    print("  specialistes : " + ", ".join("%s (%s)" % (n, S.profil(n).contre) for n in noms))
    cas("les deux specialites existent", {"air", "groupe"}, set(par_categorie.keys()))
    for c, l in par_categorie.items():
        cas("au moins deux cartes contre '%s'" % c, True, len(l) >= 2)

    def cible(flying=False, count=1, batiment=False):
        return lua.table_from(dict(flying=flying, count=count, isBuilding=batiment))

    # 1 + 2 : existence et coherence avec le catalogue reel
    for n in noms:
        p = S.profil(n)
        cas("%s existe au catalogue" % n, True, n in cat)
        cas("%s : multiplicateur borne" % n, True,
            1 < float(p.multiplicateur) <= float(S.MULTIPLICATEUR_MAX))
        if n in cat:
            c = cat[n]
            carte = lua.table_from(dict(targets=c["targets"], range=c["range"], splash=c["splash"]))
            cas("%s tient la promesse de sa specialite" % n, True, S.coherente(n, carte))
            if p.contre == "air":
                cas("%s peut viser autre chose que des batiments" % n, True, c["targets"] != "buildings")
            else:
                cas("%s frappe bien en zone (splash %s)" % (n, c["splash"]), True, float(c["splash"]) > 0)
    cas("une carte sans specialite n'a aucune promesse a tenir", True, S.coherente("Tralalero", None))

    # 2 bis. AUDIT INVERSE : on part cette fois des DESCRIPTIONS, sur tout le catalogue. Une carte
    # dont le texte promet une frappe « en zone » doit avoir des degats de zone ; une carte qui
    # parle de viser le ciel doit pouvoir viser les volants. Le sens direct ne voit pas ce
    # defaut-la : une carte qui promet sans etre declaree n'est dans aucun profil.
    import re as _re

    def promesses_trahies(bloc):
        """Ce que le TEXTE d'une carte promet, confronte a ses chiffres. Rend la liste des
        promesses non tenues (vide = la carte dit vrai)."""
        mi = _re.search(r'id = "(\w+)"', bloc)
        md = _re.search(r'desc = "([^"]*)"', bloc)
        if not mi or not md:
            return []
        ident, desc = mi.group(1), md.group(1).lower()
        if "batiment :" in desc:
            return []
        splash = float((_re.search(r"splash = ([\d.]+)", bloc) or [0, 0])[1])
        vise = (_re.search(r'targets = "(\w+)"', bloc) or [0, "ground"])[1]
        # « en zone » se tient de TROIS facons dans ce jeu, toutes vues dans le serveur :
        #   splash a chaque coup · explosion a la mort (mort = {...}, Statuts.explosionMort)
        #   · rayon d'un sort. Ne compter que `splash` accusait a tort Bomba Salsiccia, dont le
        # texte dit « explose EN MOURANT » et qui porte bien mort = { degats = 260, rayon = 4.5 }.
        explose = _re.search(r"mort = \{[^}]*rayon = ([\d.]+)", bloc)
        sort = "sort = " in bloc[:1400] and _re.search(r"rayon = ([\d.]+)", bloc)
        trahies = []
        if "en zone" in desc and not (splash > 0 or explose or sort):
            trahies.append("%s promet 'en zone' sans aucune zone" % ident)
        if ("anti-air" in desc or "vise le ciel" in desc or "abat les volants" in desc)                 and vise == "ground":
            trahies.append("%s promet le ciel sans viser les volants" % ident)
        return trahies

    source = CARTES.read_text(encoding="utf-8")
    blocs = source.split(chr(9) + "{")[1:]
    menteuses = [m for b in blocs for m in promesses_trahies(b)]
    print("  audit inverse : %d cartes relues contre leur texte" % len(blocs))
    cas("aucune carte ne promet dans son texte ce qu'elle ne fait pas", [], menteuses)
    # LE CONTROLE MORD : deux cartes fabriquees, chacune trahissant une promesse, doivent etre
    # prises — sinon l'audit ci-dessus serait vert parce qu'il ne regarde rien.
    cas("une carte qui promettrait la zone sans l'avoir est prise", 1,
        len(promesses_trahies('id = "FauxZone", desc = "Frappe en zone", hp = 100, dmg = 10,'
                              ' targets = "any", splash = 0,')))
    cas("une carte qui promettrait le ciel sans le viser aussi", 1,
        len(promesses_trahies('id = "FauxCiel", desc = "Tourelle anti-air", hp = 100, dmg = 10,'
                              ' targets = "ground", splash = 2,')))
    cas("et une carte honnete passe", [],
        promesses_trahies('id = "Vraie", desc = "Frappe en zone", targets = "any", splash = 2.5,'))

    # une declaration incoherente DOIT etre refusee par le controle
    faux = lua.table_from(dict(targets="buildings", range=3, splash=0))
    anti_air = par_categorie["air"][0]
    cas("un anti-air qui ne viserait que les batiments est refuse", False, S.coherente(anti_air, faux))
    anti_groupe = par_categorie["groupe"][0]
    cas("un anti-groupe sans degats de zone est refuse", False,
        S.coherente(anti_groupe, lua.table_from(dict(targets="any", range=6, splash=0))))

    mult_air = float(S.profil(anti_air).multiplicateur)
    mult_grp = float(S.profil(anti_groupe).multiplicateur)

    # 3. application ciblee
    cas("l'anti-air majore contre un volant", mult_air, float(S.multiplicateur(anti_air, cible(flying=True))))
    cas("mais pas contre un terrestre", 1.0, float(S.multiplicateur(anti_air, cible())))
    cas("ni contre un essaim terrestre", 1.0, float(S.multiplicateur(anti_air, cible(count=3))))
    cas("l'anti-groupe majore contre un essaim", mult_grp, float(S.multiplicateur(anti_groupe, cible(count=3))))
    cas("mais pas contre une unite seule", 1.0, float(S.multiplicateur(anti_groupe, cible(count=1))))
    cas("un volant seul n'est pas un essaim", 1.0, float(S.multiplicateur(anti_groupe, cible(flying=True))))
    cas("aucun bonus contre un batiment (volant)", 1.0,
        float(S.multiplicateur(anti_air, cible(flying=True, batiment=True))))
    cas("aucun bonus contre un batiment (essaim)", 1.0,
        float(S.multiplicateur(anti_groupe, cible(count=5, batiment=True))))
    cas("cible absente : aucun bonus", 1.0, float(S.multiplicateur(anti_air, None)))

    # 4. essaim volant
    essaim_volant = cible(flying=True, count=3)
    cas("un essaim volant est contre par l'anti-air", mult_air,
        float(S.multiplicateur(anti_air, essaim_volant)))
    cas("et aussi par l'anti-groupe", mult_grp, float(S.multiplicateur(anti_groupe, essaim_volant)))
    cats = S.categories(essaim_volant)
    cas("il porte bien les deux categories", (True, True), (cats.air is True, cats.groupe is True))
    cas("un terrestre seul n'en porte aucune", (None, None),
        (S.categories(cible()).air, S.categories(cible()).groupe))

    # 5. carte ordinaire
    cas("une carte ordinaire ne gagne rien contre un volant", 1.0,
        float(S.multiplicateur("Tralalero", cible(flying=True))))
    cas("ni contre un essaim", 1.0, float(S.multiplicateur("Tralalero", cible(count=3))))
    cas("estSpecialiste : non", False, S.estSpecialiste("Tralalero"))
    cas("estSpecialiste : oui", True, S.estSpecialiste(anti_air))
    cas("identifiant inconnu : aucun bonus", 1.0, float(S.multiplicateur("RienDuTout", cible(flying=True))))

    # 6. degats
    cas("degats majores, en entier", int(round(100 * mult_air)), S.degats(100, mult_air))
    cas("sans bonus, degats inchanges", 100, S.degats(100, 1))
    cas("multiplicateur farfelu plafonne", S.degats(100, float(S.MULTIPLICATEUR_MAX)), S.degats(100, 99))
    cas("un multiplicateur inferieur a 1 n'affaiblit pas", 100, S.degats(100, 0.2))
    cas("zero reste zero", 0, S.degats(0, mult_air))

    # 7. chaque menace du catalogue a bien un contre disponible
    volants = [i for i, c in cat.items() if c["flying"] and not c["sort"]]
    essaims = [i for i, c in cat.items() if float(c["count"]) > 1 and not c["sort"]]
    print("  menaces du catalogue : %d volants, %d cartes en essaim" % (len(volants), len(essaims)))
    cas("le catalogue contient des volants a contrer", True, len(volants) > 0)
    cas("et des essaims", True, len(essaims) > 0)
    gratuits = [n for n in par_categorie["air"] if n in cat and not cat[n].get("prix")]
    cas("au moins un anti-air est accessible sans achat", True, len(gratuits) > 0)

    # 8. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Specialite")' in serveur)
    cas("le serveur calcule le bonus cible par cible", True, "Specialite.multiplicateur(" in serveur)
    # Depuis le plafond commun, le bonus passe par la composition (Frappe), plus par une
    # multiplication directe : c'est la meme regle, appliquee au meme endroit que les autres.
    cas("le serveur applique le bonus aux degats", True,
        "Frappe.composer({ e.bonusDegats or 1, specialite, elan })" in serveur)
    cas("le serveur regarde si la cible vole", True, "flying = target.flying" in serveur)
    cas("le serveur regarde si la cible arrive en nombre", True, "count = target.carte and target.carte.count" in serveur)
    cas("le module est livre dans la place", True, "shared/Specialite.lua" in BUILD.read_text(encoding="utf-8"))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : les specialistes frappent fort la menace qu'ils contrent, et normalement le reste")
    return 0


if __name__ == "__main__":
    sys.exit(main())
