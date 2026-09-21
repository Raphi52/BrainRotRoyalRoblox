# -*- coding: utf-8 -*-
"""LIGUES COMPETITIVES (src/shared/Ligues.lua + branchements hub / fin de partie / saison)."""
import sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
e = []
lua = LuaRuntime()
M = lua.execute((R / "src/shared/Ligues.lua").read_text(encoding="utf-8"))
H = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
E = (R / "src/server/Economie.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
SA = (R / "src/shared/Saison.lua").read_text(encoding="utf-8")

n = len(M.LISTE)
if n < 6:
    e.append(f"au moins 6 ligues attendues, {n}")
seuils = [M.LISTE[i].seuil for i in range(1, n + 1)]
if seuils != sorted(seuils) or len(set(seuils)) != n:
    e.append("seuils non strictement croissants")
import re
plancher = int(re.search(r"Saison.PLANCHER\s*=\s*(\d+)", SA).group(1))
if seuils[0] != plancher:
    e.append(f"la 1re ligue doit commencer au plancher de saison ({plancher}), pas {seuils[0]}")
if M.index(plancher - 1) != 0 or M.index(plancher) != 1 or M.index(99999) != n:
    e.append("index faux aux bornes")
if M.actuelle(1500).nom != "Or" or M.actuelle(1499).nom != "Argent":
    e.append("palier Or mal place")
if len({M.LISTE[i].lettre for i in range(1, n + 1)}) != n:
    e.append("deux ligues partagent la meme lettre de badge")
if "1640 / 2200" not in M.texte(1640):
    e.append("texte du hub : " + M.texte(1640))
if "600" not in M.texte(100):
    e.append("sous le plancher, le hub doit dire a combien commencent les ligues")
if "sommet" not in M.texte(99999):
    e.append("derniere ligue : pas de palier suivant affiche")
if M.changement(1490, 1510) != "PROMOTION : Ligue Or !":
    e.append("promotion : " + str(M.changement(1490, 1510)))
if not str(M.changement(1010, 990)).startswith("Relegation"):
    e.append("relegation non dite")
if M.changement(1200, 1230) is not None:
    e.append("pas de ligne si la ligue ne change pas")
if M.ligneSaison(1800, 1200) != "Ligue : Or  ->  Argent":
    e.append("bilan de saison : " + M.ligneSaison(1800, 1200))
# branchements
if 'item("ModuleScript", "Ligues"' not in B:
    e.append("build : Ligues non embarque")
if "Ligues.changement(" not in E:
    e.append("fin de partie : promotion/relegation non ajoutee aux lignes de l'ecran de fin")
if "Ligues.texte(" not in H or "BadgeLigue" not in H:
    e.append("hub : ni badge ni texte de ligue")
if "Ligues.ligneSaison(" not in H:
    e.append("bilan de saison : la ligue n'y figure pas")
for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : 8 ligues du plancher de saison a Legende, badge au hub, promotion en fin de partie, ligue dans le bilan de saison")
sys.exit(1 if e else 0)
