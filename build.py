"""Genere BrainRotRoyale.rbxlx (ouvrable directement dans Roblox Studio) depuis src/."""
import json
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).parent
ref = 0
AUTOTEST = "--autotest" in sys.argv
JOUEURS = 3 if "--trois-joueurs" in sys.argv else (2 if "--deux-joueurs" in sys.argv else 1)
COURT = AUTOTEST and "--court" in sys.argv  # partie de 40 s, pour verifier la fin de partie
PARTIE = AUTOTEST and "--partie" in sys.argv  # capture d'une partie normale : ni rangee de test ni trio immobile
GROSPLAN = AUTOTEST and "--grosplan" in sys.argv  # camera face a la rangee de test
GALERIE = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--galerie=")), "") if AUTOTEST else ""
MELEE = AUTOTEST and "--melee" in sys.argv  # robots en rafale : capture d'une melee (implique --partie)
PARTIE = PARTIE or MELEE
HUB = AUTOTEST and "--hub" in sys.argv  # copie de test avec l'accueil ouvert
BOUTIQUE = AUTOTEST and "--boutique" in sys.argv  # accueil + boutique ouverte, pour la capture
COFFRES = AUTOTEST and "--coffres" in sys.argv  # accueil avec des coffres dans chaque etat
DECK = AUTOTEST and "--deck" in sys.argv  # accueil + ecran DECK ouvert, pour la capture
NIVEAUX = AUTOTEST and "--niveaux" in sys.argv  # boutique ouverte avec des niveaux varies
BOUTIQUE = BOUTIQUE or NIVEAUX
HUB = HUB or BOUTIQUE or COFFRES or DECK
ECOTEST = AUTOTEST and "--ecotest" in sys.argv  # scenario de test de l'economie
SIM = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--sim=")), "") if AUTOTEST else ""  # simulation d'equilibre
RUN = AUTOTEST and "--run" in sys.argv      # partie entiere bot contre bot, sans joueur


def item(cls, name, children="", source=None, extra=""):
    global ref
    ref += 1
    props = f'<string name="Name">{escape(name)}</string>' + extra
    if source is not None:
        if "]]>" in source:
            raise ValueError(f"{name}: ']]>' interdit dans un script")
        props += f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>'
    return f'<Item class="{cls}" referent="RBX{ref}"><Properties>{props}</Properties>{children}</Item>'


def src(p):
    return (ROOT / "src" / p).read_text(encoding="utf-8")


# MODELES DE LA BOUTIQUE (2026-09-14). Un jeu en ligne ne peut pas charger a la volee le modele
# d'un autre auteur (InsertService refuse) : sa GEOMETRIE est donc ecrite dans la place.
# tools/boutique/modeles.json vient de tools/BRR_Modeles_export.lua (Studio, connecte) et ne porte
# AUCUN script : seules les pieces, maillages et textures sont reconstruits ici.
MATERIAUX = {"Plastic": 256, "SmoothPlastic": 272}
ALPHA = {"Overlay": 0, "Transparency": 1, "TintMask": 2}
FACES = {"Right": 0, "Top": 1, "Back": 2, "Left": 3, "Bottom": 4, "Front": 5}
MESHTYPES = {"Head": 0, "Torso": 1, "Wedge": 2, "Sphere": 3, "Cylinder": 4, "FileMesh": 5, "Brick": 6}


def _v3(name, v):
    return f'<Vector3 name="{name}"><X>{v[0]}</X><Y>{v[1]}</Y><Z>{v[2]}</Z></Vector3>'


def _content(name, url):
    return f'<Content name="{name}">' + (f"<url>{escape(url)}</url>" if url else "<null></null>") + "</Content>"


def _piece(p):
    c = p["CFrame"]
    rgb = [max(0, min(255, round(x * 255))) for x in p["Color"]]
    props = (
        _v3("size", p["Size"])
        + '<CoordinateFrame name="CFrame">' + "".join(
            f"<{k}>{c[i]}</{k}>" for i, k in enumerate(
                ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]))
        + "</CoordinateFrame>"
        + f'<Color3uint8 name="Color3uint8">{0xFF000000 | rgb[0] << 16 | rgb[1] << 8 | rgb[2]}</Color3uint8>'
        + f'<token name="Material">{MATERIAUX.get(p.get("Material"), 256)}</token>'
        + f'<float name="Transparency">{p.get("Transparency", 0)}</float>'
        + '<bool name="Anchored">true</bool><bool name="CanCollide">false</bool>'
        + '<bool name="CanQuery">false</bool><bool name="CanTouch">false</bool>'
    )
    if p["ClassName"] == "MeshPart":
        props += _content("MeshId", p.get("MeshId")) + _content("TextureID", p.get("TextureID"))
        # InitialSize = taille d'origine du maillage (MeshSize). Sans elle, Studio prend une valeur
        # par defaut et deforme la piece : gobelet geant, katanas etires (capture 2026-09-14).
        if p.get("MeshSize"):
            props += _v3("InitialSize", p["MeshSize"])
    elif p.get("Shape") == "Block":
        props += '<token name="shape">1</token>'
    enfants = ""
    for e in p["enfants"]:
        if e["ClassName"] == "SurfaceAppearance":
            enfants += item("SurfaceAppearance", "SurfaceAppearance", extra="".join(
                _content(k, e.get(k)) for k in ("ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap"))
                + f'<token name="AlphaMode">{ALPHA.get(e.get("AlphaMode"), 0)}</token>')
        elif e["ClassName"] == "SpecialMesh":
            enfants += item("SpecialMesh", "Mesh", extra=_content("MeshId", e.get("MeshId"))
                            + _content("TextureId", e.get("TextureId"))
                            + f'<token name="MeshType">{MESHTYPES.get(e.get("MeshType"), 6)}</token>'
                            + _v3("Scale", e["Scale"]) + _v3("Offset", e["Offset"]))
        elif e["ClassName"] == "Decal" and e.get("Texture"):
            enfants += item("Decal", "Decal", extra=_content("Texture", e["Texture"])
                            + f'<token name="Face">{FACES.get(e.get("Face"), 5)}</token>')
    return item(p["ClassName"], "Piece", enfants, extra=props)


def modeles():
    fichier = ROOT / "tools" / "boutique" / "modeles.json"
    if not fichier.exists():
        return ""
    data = json.loads(fichier.read_text(encoding="utf-8"))
    return item("Folder", "Modeles", "".join(
        item("Model", perso, "".join(_piece(p) for p in m["pieces"] if p.get("Transparency", 0) < 1))
        for perso, m in data.items()))


place = "".join([
    item("Workspace", "Workspace"),
    # Moteur de rendu ECRIT ICI, pas dans un script : le jeu n'a pas le droit d'ecrire
    # Lighting.Technology (erreur « lacking capability RobloxScript » mesuree le 2026-09-14).
    # Future = ombres douces et lumiere realiste.
    item("Lighting", "Lighting", extra='<token name="Technology">4</token>'),
    item("ReplicatedStorage", "ReplicatedStorage",
         item("Folder", "Shared", item("ModuleScript", "Cards", source=src("shared/Cards.lua"))
              + item("ModuleScript", "Sons", source=src("shared/Sons.lua"))
              # Effets.lua est requis par GameServer : sans lui, le serveur reste bloque sur
              # WaitForChild("Effets") et AUCUN remote n'est cree (mesure Studio 2026-09-16).
              + item("ModuleScript", "Effets", source=src("shared/Effets.lua")))
         + modeles()
         + (item("BoolValue", "BRR_AUTOTEST") if AUTOTEST else "")
         # Nombre de joueurs du test automatique : lu par le plugin tools/BRR_AutoRun.lua.
         + (item("IntValue", "BRR_JOUEURS", extra=f'<int name="Value">{JOUEURS}</int>') if AUTOTEST else "")
         + (item("BoolValue", "BRR_COURT") if COURT else "")
         + (item("BoolValue", "BRR_RUN") if RUN else "")
         + (item("BoolValue", "BRR_PARTIE") if PARTIE else "")
         + (item("BoolValue", "BRR_GROSPLAN") if GROSPLAN else "")
         + (item("BoolValue", "BRR_MELEE") if MELEE else "")
         + (item("BoolValue", "BRR_HUB") if HUB else "")
         + (item("BoolValue", "BRR_ECOTEST") if ECOTEST else "")
         + (item("BoolValue", "BRR_BOUTIQUE") if BOUTIQUE else "")
         + (item("BoolValue", "BRR_COFFRES") if COFFRES else "")
         + (item("BoolValue", "BRR_DECK") if DECK else "")
         + (item("BoolValue", "BRR_NIVEAUX") if NIVEAUX else "")
         + (item("StringValue", "BRR_SIM", extra=f'<string name="Value">{escape(SIM)}</string>') if SIM else "")
         + (item("StringValue", "BRR_GALERIE", extra=f'<string name="Value">{escape(GALERIE)}</string>') if GALERIE else "")),
    item("ServerStorage", "ServerStorage", item("BoolValue", "BRR_AUTOTEST") if AUTOTEST else ""),
    item("ServerScriptService", "ServerScriptService",
         item("Script", "GameServer", source=src("server/GameServer.server.lua"))
         + item("ModuleScript", "Economie", source=src("server/Economie.lua"))),
    item("StarterPlayer", "StarterPlayer",
         item("StarterPlayerScripts", "StarterPlayerScripts",
              item("LocalScript", "GameClient", source=src("client/GameClient.client.lua"))
              + item("LocalScript", "Hub", source=src("client/Hub.client.lua"))
              # ESSAI 2026-09-14 : capture produite par le moteur (copie de test seulement).
              + (item("LocalScript", "BRR_Capture",
                      source=(ROOT / "tools" / "BRR_Capture.client.lua").read_text(encoding="utf-8"))
                 if AUTOTEST else ""))),
])

out = ROOT / ("BrainRotRoyale.autotest.rbxlx" if AUTOTEST else "BrainRotRoyale.rbxlx")
out.write_text(
    '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
    'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
    + place + "</roblox>",
    encoding="utf-8",
)
print(f"OK -> {out}")
