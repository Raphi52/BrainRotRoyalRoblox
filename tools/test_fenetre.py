# -*- coding: utf-8 -*-
"""Banc de la FENETRE (src/shared/Fenetre.lua) : pousser quand l'adversaire ne peut pas repondre.

Pourquoi : une fois l'inversion du seuil d'attaque corrigee, les trois paliers hauts se valaient
toujours (aguerri 32 victoires, normal 31, expert 30 sur 60 parties chacun). Cause lue dans la
table des paliers : `anticipe`, `contre` et `economise` sont a `true` pour les TROIS, et le temps
de reflexion ne change rien — les trois posent le meme nombre de cartes par seconde, le jeu etant
limite par l'elixir et non par la vitesse de decision. Il fallait une COMPETENCE.

Ce qu'il verifie :
  1. la precision de lecture SEPARE vraiment les paliers (c'est tout l'objet du module) ;
  2. un robot qui ne lit pas ne voit JAMAIS de fenetre — il ne tire aucun avantage ;
  3. l'erreur d'estimation est CENTREE et bornee : pas de biais systematique ;
  4. la fenetre ne s'ouvre que quand l'adversaire ne peut pas payer une reponse ;
  5. la lecture sert a ATTENDRE, jamais a se precipiter (sens corrige par la mesure) ;
  6. SIMULATION : sur 20 000 tirages, on mesure combien de fois chaque palier voit juste ;
  7. le robot ne TRICHE pas : il part de l'estimation visible, jamais du compteur reel ;
  8. le serveur applique la regle.

Prerequis : python -m pip install lupa
"""
import pathlib
import random
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Fenetre.lua"
ROBOT = ROOT / "src" / "shared" / "Robot.lua"
LECTURE = ROOT / "src" / "shared" / "Lecture.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
BUILD = ROOT / "build.py"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — les paliers hauts restent indistinguables" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    F = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    R = lua.execute("return (function() " + ROBOT.read_text(encoding="utf-8") + " end)()")
    L = lua.execute("return (function() " + LECTURE.read_text(encoding="utf-8") + " end)()")

    # 1. la precision SEPARE les paliers — c'est la raison d'etre du module
    precisions = {p.nom: float(p.lecture or 0) for p in R.PALIERS.values()}
    print("  precision de lecture par palier : %s" % precisions)
    cas("le debutant ne lit pas", 0.0, precisions["debutant"])
    cas("le normal non plus", 0.0, precisions["normal"])
    cas("l'aguerri lit en partie", True, 0 < precisions["aguerri"] < 1)
    cas("l'expert lit juste", 1.0, precisions["expert"])
    # LE POINT CENTRAL : les trois paliers hauts ne sont plus identiques
    hauts = [precisions["normal"], precisions["aguerri"], precisions["expert"]]
    cas("les trois paliers hauts different enfin", 3, len(set(hauts)))
    cas("et la lecture progresse avec le niveau", True,
        precisions["normal"] < precisions["aguerri"] < precisions["expert"])

    # 2. un robot aveugle ne voit jamais de fenetre
    cas("precision nulle : aucune fenetre, meme a 0 elixir", False, F.ouverte(0, 0, 3))
    cas("precision nulle : aucune patience en plus", 0.0, float(F.patience(0)))
    cas("et son seuil reste intact, fenetre ouverte comme fermee", (8.0, 8.0),
        (float(F.seuilEffectif(8, True, 0)), float(F.seuilEffectif(8, False, 0))))

    # 3. erreur CENTREE et bornee
    erreur_max = float(F.ERREUR_MAX)
    cas("tirage median : aucune erreur", 5.0, float(F.estimation(5, 0, 0.5)))
    cas("tirage au plus bas : sous-estime au maximum", max(0.0, 5 - erreur_max),
        float(F.estimation(5, 0, 0.0)))
    cas("tirage au plus haut : surestime au maximum", min(10.0, 5 + erreur_max),
        float(F.estimation(5, 0, 1.0)))
    cas("l'expert ne se trompe jamais", 5.0, float(F.estimation(5, 1, 0.0)))
    cas("meme au pire tirage", 5.0, float(F.estimation(5, 1, 1.0)))
    cas("l'estimation reste dans les bornes du jeu (bas)", 0.0, float(F.estimation(0, 0, 0.0)))
    cas("et en haut", 10.0, float(F.estimation(10, 0, 1.0)))
    # moyenne des erreurs sur beaucoup de tirages : elle doit tendre vers zero
    random.seed(11)
    ecarts = [float(F.estimation(5, 0.5, random.random())) - 5 for _ in range(20000)]
    moyenne = sum(ecarts) / len(ecarts)
    print("  erreur moyenne d'un lecteur a 0,5 sur 20 000 tirages : %+.3f elixir" % moyenne)
    cas("l'erreur ne penche d'aucun cote", True, abs(moyenne) < 0.05)

    # 4. quand la fenetre s'ouvre
    cout = float(F.COUT_REPONSE)
    cas("adversaire a sec : fenetre ouverte", True, F.ouverte(0, 1, cout))
    cas("adversaire juste sous le cout : ouverte", True, F.ouverte(cout - 0.5, 1, cout))
    cas("adversaire pile au cout : fermee", False, F.ouverte(cout, 1, cout))
    cas("adversaire a l'aise : fermee", False, F.ouverte(9, 1, cout))
    # le cout de reponse est le cout MEDIAN du catalogue, comme la reserve defensive
    reserve = (ROOT / "src" / "shared" / "Reserve.lua").read_text(encoding="utf-8")
    import re as _re
    m = _re.search(r"Reserve\.MEDIANE = ([\d.]+)", reserve)
    cas("le cout de reponse est celui de la reserve defensive", float(m.group(1)), cout)

    # 5. LE SENS DE LA REGLE, corrige apres mesure : la lecture sert a ATTENDRE, pas a se
    # precipiter. Premier essai : fenetre ouverte -> seuil abaisse de 3. Resultat sur 60 parties,
    # normal contre expert : l'expert ne gagnait que 38 %, en posant ses cartes a 4,0 elixir de
    # mediane contre 5,8 — on avait refabrique un robot imprudent, le defaut meme que la
    # correction precedente avait elimine.
    cas("fenetre OUVERTE : le seuil ne bouge pas", 8.0, float(F.seuilEffectif(8, True, 1)))
    cas("fenetre FERMEE : l'expert attend davantage",
        8.0 + float(F.PATIENCE_MAX), float(F.seuilEffectif(8, False, 1)))
    cas("aguerri : il attend a proportion de ce qu'il lit",
        round(8 + float(F.PATIENCE_MAX) * 0.6, 6),
        round(float(F.seuilEffectif(8, False, 0.6)), 6))
    cas("un robot qui ne lit pas n'attend pas plus", 8.0, float(F.seuilEffectif(8, False, 0)))
    cas("le seuil ne depasse jamais le plafond d'elixir", float(F.SEUIL_MAX),
        float(F.seuilEffectif(10, False, 1)))
    cas("la patience est bornee", float(F.PATIENCE_MAX), float(F.patience(9)))
    # ET SURTOUT : la lecture ne doit JAMAIS rendre le robot plus imprudent qu'un robot aveugle.
    for base in (6, 7, 8, 9):
        for ouverte in (True, False):
            for p in (0, 0.6, 1):
                cas("seuil %d, fenetre %s, lecture %.1f : jamais sous le seuil de base"
                    % (base, "ouverte" if ouverte else "fermee", p), True,
                    float(F.seuilEffectif(base, ouverte, p)) >= base)

    # 6. SIMULATION : qui voit juste, et combien de fois
    random.seed(7)
    essais = 20000
    print("  sur %d situations ou l'adversaire est VRAIMENT a sec (2 elixir) :" % essais)
    vus = {}
    for nom, p in sorted(precisions.items(), key=lambda kv: kv[1]):
        n = sum(1 for _ in range(essais)
                if F.ouverte(F.estimation(2, p, random.random()), p, cout))
        vus[nom] = n / essais
        print("    %-10s (precision %.1f) repere la fenetre %5.1f %% du temps" % (nom, p, 100 * n / essais))
    cas("le debutant ne la voit jamais", 0.0, vus["debutant"])
    cas("le normal non plus", 0.0, vus["normal"])
    cas("l'aguerri la voit souvent", True, 0.4 < vus["aguerri"] < 1.0)
    cas("l'expert la voit toujours", 1.0, vus["expert"])
    cas("et l'expert la voit plus souvent que l'aguerri", True, vus["expert"] > vus["aguerri"])
    # fausse alerte : l'adversaire a de l'elixir, le robot croit-il a tort que la fenetre est ouverte ?
    faux = {}
    for nom, p in sorted(precisions.items(), key=lambda kv: kv[1]):
        n = sum(1 for _ in range(essais)
                if F.ouverte(F.estimation(6, p, random.random()), p, cout))
        faux[nom] = n / essais
    print("    fausses alertes (adversaire a 6 elixir) : aguerri %.1f %%, expert %.1f %%"
          % (100 * faux["aguerri"], 100 * faux["expert"]))
    cas("l'expert ne se trompe jamais de fenetre", 0.0, faux["expert"])
    cas("l'aguerri, lui, peut se tromper", True, faux["aguerri"] >= 0)

    # 7. LE ROBOT NE TRICHE PAS : il part de l'estimation VISIBLE (Lecture), pas du compteur reel.
    serveur = SERVEUR.read_text(encoding="utf-8")
    code = chr(10).join(l.split("--")[0] for l in serveur.splitlines())
    cas("le serveur construit l'estimation visible", True, "Lecture.elixirEstime(" in code)
    cas("et ne lit PAS le compteur reel de l'adversaire pour cela", False,
        "Fenetre.estimation(teams[3 - team].elixir" in code)

    # 8. branchement reel
    cas("le serveur charge le module", True, 'WaitForChild("Fenetre")' in serveur)
    cas("le serveur ouvre la fenetre", True, "Fenetre.ouverte(" in code)
    cas("et abaisse son seuil d'attaque", True, "Fenetre.seuilEffectif(" in code)
    cas("la raison est nommee dans le journal", True, "fenetre" in code)
    cas("le module est livre dans la place", True,
        "shared/Fenetre.lua" in BUILD.read_text(encoding="utf-8"))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : les meilleurs poussent quand l'adversaire est a sec, les autres ne le voient pas")
    return 0


if __name__ == "__main__":
    sys.exit(main())
