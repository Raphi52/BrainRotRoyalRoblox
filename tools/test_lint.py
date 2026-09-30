# -*- coding: utf-8 -*-
"""ANALYSE STATIQUE de src/ par selene : aucune variable lue ou ecrite sans avoir ete declaree.

Le defaut garde (mesure du 2026-09-30) : en Lua, une fonction ne voit une variable `local` que si
elle est declaree AVANT elle dans le fichier. Declaree plus bas, le meme nom designe une GLOBALE,
qui vaut `nil` : aucune erreur au chargement, le plantage n'arrive qu'au moment ou le code tourne.
Cinq cas reels ont ete trouves d'un coup, que les 129 autres bancs laissaient passer :

  - GameClient : l'annonce « voie ouverte » (chute d'une tour de cote) appelait `annoncer`, declaree
    700 lignes plus bas : elle plantait au lieu de s'afficher ;
  - Hub : « SI PERSONNE : ROBOT » et « REVOIR LE TUTORIEL » ecrivaient dans `message`, declare plus
    bas : le premier plantait sans rien expliquer, le second armait le tutoriel sans le dire ;
  - GameServer : `majNiveauxRobot` lisait `modeEgalise` declare 300 lignes plus bas : en duel a
    niveaux egalises, le robot n'etait JAMAIS egalise, contrairement a ce que le code promettait ;
  - GameServer : `resetMatch` vidait une globale `ancresEmote` au lieu de la vraie table.

Le banc echoue sur toute ERREUR selene (les avertissements de style sont tolerees, voir
selene.toml). Il verifie d'abord qu'il SAIT encore voir le defaut, sur un extrait fabrique : un
reglage qui laisserait tout passer rendrait un faux vert.

Prerequis : selene (installe par rokit : `rokit install` a la racine, voir rokit.toml).
"""
import glob
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parent.parent


def trouver_selene():
    # Le binaire REEL d'abord : le raccourci de rokit exige un rokit.toml dans le dossier courant.
    motif = os.path.join(os.path.expanduser("~"), ".rokit", "tool-storage", "kampfkarren", "selene",
                         "*", "selene*")
    reels = sorted(glob.glob(motif))
    if reels:
        return reels[-1]
    return shutil.which("selene")


def lancer(selene, fichiers):
    p = subprocess.run([selene, "--display-style", "quiet", "--allow-warnings", "--no-summary"]
                       + [str(f) for f in fichiers], cwd=str(RACINE), capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    erreurs = [l for l in (p.stdout + p.stderr).splitlines() if "error[" in l]
    return p.returncode, erreurs, p.stdout + p.stderr


def main():
    selene = trouver_selene()
    if not selene:
        print("ROUGE : selene introuvable. Installer : `rokit install` a la racine du depot.")
        return 1
    if not (RACINE / "roblox.yml").exists():
        g = subprocess.run([selene, "generate-roblox-std"], cwd=str(RACINE), capture_output=True,
                           text=True, encoding="utf-8", errors="replace")
        if g.returncode != 0 or not (RACINE / "roblox.yml").exists():
            print("ROUGE : bibliotheque Roblox de selene non generee :", (g.stderr or g.stdout)[-300:])
            return 1

    # 1) LE BANC VOIT-IL ENCORE LE DEFAUT ? Meme forme que les cas reels : lecture d'une locale
    #    declaree apres la fonction qui l'utilise, et ecriture vers une locale declaree plus bas.
    temoin = pathlib.Path(tempfile.mkdtemp()) / "temoin.lua"
    temoin.write_text(
        "local function a()\n\treturn message.Text\nend\n"
        "local function b()\n\tancres = {}\nend\n"
        "local message = { Text = '' }\nlocal ancres = {}\nreturn { a = a, b = b, m = message, n = ancres }\n",
        encoding="utf-8")
    code, erreurs, brut = lancer(selene, [temoin])
    vus = " ".join(erreurs)
    if code == 0 or "undefined_variable" not in vus or "unscoped_variables" not in vus:
        print("ROUGE : le banc ne detecte plus une variable lue ou ecrite avant sa declaration")
        print(brut[-600:])
        return 1

    # 2) LE CODE DU JEU
    code, erreurs, brut = lancer(selene, [RACINE / "src"])
    if code != 0 or erreurs:
        for e in erreurs:
            print(e)
        if not erreurs:
            print(brut[-600:])
        print("ROUGE : %d erreur(s) d'analyse statique dans src/" % len(erreurs))
        return 1
    print("VERT : aucune variable de src/ n'est lue ni ecrite avant sa declaration (selene)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
