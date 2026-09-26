# -*- coding: utf-8 -*-
"""PUBLIER la place sans Roblox Studio, par l'API Open Cloud « Place Publishing ».

Pourquoi (2026-09-26) : la publication passait par l'interface de Studio. Elle echouait des que la
fenetre Bureau a distance etait reduite ou qu'un autre travail occupait Studio (Studio n'accepte
qu'une instance) : trois tentatives perdues. L'API ne depend ni de l'ecran ni de Studio.

Usage : python tools/publier_place.py            # reconstruit la place puis la publie
        python tools/publier_place.py --sans-build
Source de l'API : https://create.roblox.com/docs/cloud/guides/usage-place-publishing
  POST https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Published
  en-tete x-api-key ; Content-Type application/xml pour un .rbxlx ; reponse {"versionNumber": N}

CLE : variable d'environnement ROBLOX_API_KEY (droit « universe-places », ecriture, sur
l'experience). Elle n'est JAMAIS affichee ni ecrite. Si le processus ne la voit pas (cle posee par
`setx` apres son lancement), elle est relue dans les variables UTILISATEUR de Windows.
"""
import argparse
import json
import os
import pathlib
import subprocess
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
# Experience « Brainrot Royale » publiee le 2026-09-26 (voir README, « Etat de la publication »).
UNIVERSE_ID = 10768149063
PLACE_ID = 126168119650545
BASE_URL = "https://apis.roblox.com"
VARIABLE = "ROBLOX_API_KEY"


def lire_cle():
    cle = os.environ.get(VARIABLE)
    if cle:
        return cle.strip()
    if sys.platform == "win32":
        try:
            import winreg
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as k:
                return str(winreg.QueryValueEx(k, VARIABLE)[0]).strip() or None
        except OSError:
            return None
    return None


def publier(fichier, cle, universe_id=UNIVERSE_ID, place_id=PLACE_ID, base_url=BASE_URL, delai=120):
    """Envoie le fichier. Rend (code_http, corps_json_ou_texte)."""
    url = "%s/universes/v1/%d/places/%d/versions?versionType=Published" % (base_url, universe_id, place_id)
    type_contenu = "application/xml" if fichier.suffix.lower() == ".rbxlx" else "application/octet-stream"
    requete = urllib.request.Request(url, data=fichier.read_bytes(), method="POST",
                                     headers={"x-api-key": cle, "Content-Type": type_contenu})
    try:
        with urllib.request.urlopen(requete, timeout=delai) as r:
            corps = r.read().decode("utf-8", "replace")
            code = r.status
    except urllib.error.HTTPError as e:
        corps = e.read().decode("utf-8", "replace")
        code = e.code
    try:
        return code, json.loads(corps)
    except ValueError:
        return code, corps


def main(argv=None):
    a = argparse.ArgumentParser(description="Publie la place Brainrot Royale par Open Cloud.")
    a.add_argument("--fichier", default=str(ROOT / "BrainRotRoyale.rbxlx"))
    a.add_argument("--sans-build", action="store_true", help="ne pas reconstruire la place avant l'envoi")
    a.add_argument("--universe", type=int, default=UNIVERSE_ID)
    a.add_argument("--place", type=int, default=PLACE_ID)
    a.add_argument("--base-url", default=BASE_URL, help="pour les tests : un faux serveur local")
    o = a.parse_args(argv)

    cle = lire_cle()
    if not cle:
        print("REFUS : la variable %s est absente. Cree une cle Open Cloud (droit universe-places, "
              "ecriture, sur l'experience) puis pose-la avec : setx %s <ta cle>" % (VARIABLE, VARIABLE))
        return 2
    if not o.sans_build:
        r = subprocess.run([sys.executable, str(ROOT / "build.py")], cwd=ROOT)
        if r.returncode != 0:
            print("REFUS : build.py a echoue (code %d), rien n'est publie." % r.returncode)
            return 3
    fichier = pathlib.Path(o.fichier)
    if not fichier.is_file():
        print("REFUS : fichier introuvable : %s" % fichier)
        return 3
    code, corps = publier(fichier, cle, o.universe, o.place, o.base_url)
    if code == 200 and isinstance(corps, dict) and "versionNumber" in corps:
        print("PUBLIE : place %d, version %s (%d octets envoyes)" % (o.place, corps["versionNumber"], fichier.stat().st_size))
        return 0
    # Le corps d'erreur de Roblox ne contient pas la cle ; on le montre pour diagnostiquer.
    print("ECHEC : HTTP %d : %s" % (code, str(corps)[:500]))
    if code in (401, 403):
        print("        verifie le droit « universe-places » (ecriture) de la cle sur l'experience %d, "
              "et sa restriction d'adresse IP." % o.universe)
    return 1


if __name__ == "__main__":
    sys.exit(main())
