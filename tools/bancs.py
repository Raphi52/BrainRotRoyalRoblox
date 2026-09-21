# -*- coding: utf-8 -*-
"""Outils communs aux bancs : DECOUPER UNE ZONE DE CODE PAR SON CONTENU.

Le defaut corrige (mesure le 2026-09-21) : dix bancs sur cent delimitaient la zone de code a
inspecter par un NOMBRE DE CARACTERES — `S.split("local function resetMatch")[1][:600]`. Ajouter un
commentaire dans la fonction repoussait alors la ligne cherchee hors de la fenetre, et le banc
passait au ROUGE alors que le code etait juste.

C'est le pire defaut possible pour un banc : il ne se trompe pas en laissant passer une erreur, il
se trompe en ACCUSANT du code correct. On perd le diagnostic, on doute des cent autres, et la
tentation devient d'elargir la fenetre — ce qui ne fait que reculer le probleme.

Ici, la zone est delimitee par ce qu'elle CONTIENT : la fin d'une fonction Lua (son `end` a la
meme indentation que son entete), ou un marqueur de fin donne explicitement.
"""
import re


def _ligne_de(source, marqueur):
    i = source.find(marqueur)
    if i < 0:
        raise AssertionError("marqueur introuvable dans la source : %r" % marqueur)
    debut_ligne = source.rfind("\n", 0, i) + 1
    return i, debut_ligne


def corps_fonction(source, entete):
    """Corps d'une fonction Lua, de son entete jusqu'au `end` de MEME indentation.

    Marche pour `local function X(`, `function M.X(`, et pour un `X:Connect(function(...)`
    (qui se ferme alors par `end)`), parce qu'on ne regarde que l'indentation.
    """
    i, debut_ligne = _ligne_de(source, entete)
    indent = source[debut_ligne:i]
    if indent.strip():  # le marqueur n'est pas en tete de ligne : on prend l'indentation reelle
        indent = re.match(r"[\t ]*", source[debut_ligne:]).group(0)
    fin_motif = re.compile(r"^%send\)?\s*$" % re.escape(indent), re.M)
    m = fin_motif.search(source, i)
    return source[i:m.end()] if m else source[i:]


def bloc_entre(source, debut, fin):
    """Zone entre deux marqueurs de CONTENU. `fin` doit etre une ligne stable du code."""
    i, _ = _ligne_de(source, debut)
    j = source.find(fin, i + len(debut))
    return source[i:j] if j > 0 else source[i:]


def zone(source, debut, fin=None):
    """Raccourci : `bloc_entre` si une fin est donnee, sinon le corps de la fonction."""
    return bloc_entre(source, debut, fin) if fin else corps_fonction(source, debut)
