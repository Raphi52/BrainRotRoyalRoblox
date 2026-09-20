# -*- coding: utf-8 -*-
"""Banc de SYNTAXE : tout le Lua de src/ doit COMPILER, sans lancer Studio.

Pourquoi il existe, mesure du 2026-09-20 : une edition automatique a insere un vrai saut de ligne
au milieu d'une chaine Lua (`"Suivante\\n"` devenu deux lignes). Le fichier restait « plausible »
a la lecture, aucun autre banc ne le chargeait, et le defaut ne serait apparu qu'au lancement de
Studio — plusieurs minutes plus tard, sous la forme d'un script client qui ne demarre pas.

Ce banc compile chaque fichier (sans l'executer) avec l'interpreteur Lua de lupa. Les quelques
constructions propres a Luau que Lua 5.4 ne connait pas sont traduites avant compilation :
  - `a += b` / `a -= b` (compound assignment) ;
  - les annotations de type `local x: number` ;
  - le mot-cle `continue`, remplace par une instruction vide (seule la FORME est jugee ici).
Si une VRAIE erreur de syntaxe existe, elle sort ici avec son numero de ligne.

Prerequis : python -m pip install lupa
"""
import pathlib
import re
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOSSIERS = ("src",)

ECHECS = []


def luau_vers_lua(code):
    code = re.sub(r"([\w\.\[\]]+)\s*\+=\s*", r"\g<1> = \g<1> + ", code)
    code = re.sub(r"([\w\.\[\]]+)\s*-=\s*", r"\g<1> = \g<1> - ", code)
    code = re.sub(r"([\w\.\[\]]+)\s*\*=\s*", r"\g<1> = \g<1> * ", code)
    # `continue` est un mot-cle LUAU que Lua 5.4 ne connait pas. Pour une verification de SYNTAXE,
    # on le remplace par une instruction vide : le sens ne compte pas ici, seule la forme.
    code = re.sub(r"(?m)^(\s*)continue\s*$", r"\g<1>do end", code)
    return code


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    # `load` rend deux valeurs ; lupa ne les deballe que si on les met dans une TABLE.
    compiler = lua.eval("function(src, nom) local f, e = load(src, nom) return { ok = f ~= nil, err = e } end")
    fichiers = []
    for d in DOSSIERS:
        for f in sorted((ROOT / d).rglob("*.lua")):
            if ".bak" in f.name:
                continue  # sauvegardes horodatees : hors jeu
            fichiers.append(f)
    if not fichiers:
        print("ROUGE : aucun fichier Lua trouve dans src/")
        return 1
    for f in fichiers:
        code = luau_vers_lua(f.read_text(encoding="utf-8"))
        res = compiler(code, "@" + f.name)
        rel = f.relative_to(ROOT).as_posix()
        if not res.ok:
            print("  ROUGE " + rel + " : " + str(res.err))
            ECHECS.append(rel)
        else:
            print("  OK    " + rel + " (%d lignes)" % len(code.splitlines()))

    # Piege precis deja rencontre : un saut de ligne REEL dans une chaine entre guillemets.
    for f in fichiers:
        for n, ligne in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if ligne.count('"') % 2 == 1 and not ligne.lstrip().startswith("--") and "[[" not in ligne:
                rel = f.relative_to(ROOT).as_posix()
                print("  ROUGE %s:%d : guillemet non ferme sur la ligne" % (rel, n))
                ECHECS.append(rel + ":" + str(n))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : les %d fichiers Lua de src/ compilent tous" % len(fichiers))
    return 0


if __name__ == "__main__":
    sys.exit(main())
