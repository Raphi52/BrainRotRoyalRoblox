# -*- coding: utf-8 -*-
"""Controle du soin visuel de l'ecran de match (HUD) et des unites 3D.

Pourquoi : le banc test_effets.py ne couvre QUE src/shared/Effets.lua. Le HUD de match
(jauge d'elixir, main de cartes, panneau bas) et les unites posees sur l'arene etaient
restes en aplat : fond uni, aucun degrade, aucun contour, cubes sans ombre ni silhouette.
Ce banc lit la source et refuse un retour a l'aplat.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HUD = (ROOT / "src" / "client" / "GameClient.client.lua").read_text(encoding="utf-8")
SRV = (ROOT / "src" / "server" / "GameServer.server.lua").read_text(encoding="utf-8")

echecs = []


def cas(nom, ok, detail=""):
    print(("OK    " if ok else "ROUGE ") + nom + (("  -- " + detail) if (detail and not ok) else ""))
    if not ok:
        echecs.append(nom)


def bloc(src, debut, lignes=14):
    i = src.find(debut)
    if i < 0:
        return ""
    return "\n".join(src[i:].splitlines()[:lignes])


# --- HUD de match -----------------------------------------------------------------------
cas("HUD : fabriques d'habillage (coin/degrade/contour)",
    all(re.search(r"local function %s\(" % f, HUD) for f in ("coinUI", "degradeUI", "contourUI")),
    "il faut trois fabriques reutilisables dans GameClient")

cas("HUD : jauge d'elixir arrondie et cerclee",
    "coinUI(elixirBack" in HUD and "contourUI(elixirBack" in HUD)

cas("HUD : remplissage d'elixir en degrade (lueur, pas un aplat)",
    "degradeUI(elixirFill" in HUD)

cas("HUD : panneau bas en relief (degrade + contour)",
    "degradeUI(bottom" in HUD and "contourUI(bottom" in HUD)

cas("HUD : texte lisible sur tout fond (contour de police)",
    "Enum.ApplyStrokeMode.Contextual" in HUD)

cas("HUD : cartes en main habillees (degrade sur le bouton)",
    HUD.count("degradeUI(") >= 4, "au moins 4 degrades attendus dans le HUD")

cas("HUD : aucun identifiant d'asset externe introduit",
    "rbxassetid" not in HUD)

# --- Unites 3D --------------------------------------------------------------------------
cas("Unites : silhouette cartoon (Highlight au contour du camp)",
    'Instance.new("Highlight")' in SRV and "OutlineColor" in SRV)

cas("Unites : contour seul, pas de teinte pleine",
    "FillTransparency" in SRV)

cas("Unites : ombre portee au sol sous chaque unite",
    "OmbreSol" in SRV)

cas("Unites : les morceaux projettent une ombre",
    re.search(r"piece\.CastShadow\s*=\s*true", SRV) is not None)

cas("Unites : l'ombre au sol ne bloque ni deplacement ni ciblage",
    re.search(r"ombre\.CanCollide\s*=\s*false", SRV) is not None
    and re.search(r"ombre\.CanQuery\s*=\s*false", SRV) is not None)

print()
if echecs:
    print("%d defaut(s) : %s" % (len(echecs), ", ".join(echecs)))
    sys.exit(1)
print("Visuels HUD + unites : tout vert")
