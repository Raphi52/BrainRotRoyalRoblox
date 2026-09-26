# -*- coding: utf-8 -*-
"""Banc hors ligne de tools/publier_place.py, contre un FAUX serveur Open Cloud local.

Ce qu'il fige, sans cle reelle ni reseau :
  1. la requete respecte la documentation Roblox (POST, chemin universe/place, versionType=Published,
     en-tete x-api-key, Content-Type application/xml pour un .rbxlx, corps = le fichier tel quel) ;
  2. une reponse {"versionNumber": N} donne le code 0 et annonce la version ;
  3. une cle refusee (401) donne un code non nul ;
  4. sans cle, AUCUNE requete ne part et le message nomme la variable ;
  5. la cle n'apparait JAMAIS dans ce qui est affiche.
"""
import contextlib
import io
import json
import os
import pathlib
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import publier_place as P  # noqa: E402

CLE = "cle-de-test-ne-pas-afficher-123"
RECU = []
REPONSE = {"code": 200, "corps": {"versionNumber": 42}}
ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print("  %s  %s : attendu %r, obtenu %r" % ("OK  " if ok else "RATE", nom, attendu, obtenu))
    if not ok:
        ECHECS.append(nom)


class Faux(BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        RECU.append({"chemin": self.path, "cle": self.headers.get("x-api-key"),
                     "type": self.headers.get("Content-Type"), "corps": self.rfile.read(n)})
        corps = json.dumps(REPONSE["corps"]).encode()
        self.send_response(REPONSE["code"])
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(corps)))
        self.end_headers()
        self.wfile.write(corps)

    def log_message(self, *_a):
        pass


def lancer(argv, cle):
    ancien = os.environ.get(P.VARIABLE)
    if cle is None:
        os.environ.pop(P.VARIABLE, None)
    else:
        os.environ[P.VARIABLE] = cle
    lire = P.lire_cle
    if cle is None:
        P.lire_cle = lambda: None  # ne pas relire la vraie cle de l'utilisateur dans le registre
    sortie = io.StringIO()
    try:
        with contextlib.redirect_stdout(sortie):
            code = P.main(argv)
    finally:
        P.lire_cle = lire
        if ancien is None:
            os.environ.pop(P.VARIABLE, None)
        else:
            os.environ[P.VARIABLE] = ancien
    return code, sortie.getvalue()


def main():
    serveur = HTTPServer(("127.0.0.1", 0), Faux)
    threading.Thread(target=serveur.serve_forever, daemon=True).start()
    base = "http://127.0.0.1:%d" % serveur.server_port
    with tempfile.TemporaryDirectory() as d:
        fichier = pathlib.Path(d) / "place.rbxlx"
        fichier.write_bytes(b"<roblox>place de test</roblox>")
        argv = ["--sans-build", "--fichier", str(fichier), "--base-url", base]

        print("\n-- 1 et 2. publication acceptee")
        code, sortie = lancer(argv, CLE)
        cas("code de sortie", 0, code)
        cas("une seule requete", 1, len(RECU))
        r = RECU[-1] if RECU else {}
        cas("chemin", "/universes/v1/%d/places/%d/versions?versionType=Published" % (P.UNIVERSE_ID, P.PLACE_ID), r.get("chemin"))
        cas("en-tete x-api-key", CLE, r.get("cle"))
        cas("Content-Type d'un .rbxlx", "application/xml", r.get("type"))
        cas("corps = fichier tel quel", fichier.read_bytes(), r.get("corps"))
        cas("version annoncee", True, "version 42" in sortie)
        cas("cle jamais affichee", False, CLE in sortie)

        print("\n-- 3. cle refusee")
        REPONSE.update(code=401, corps={"errors": [{"message": "Invalid API Key"}]})
        code, sortie = lancer(argv, CLE)
        cas("code de sortie non nul", 1, code)
        cas("cle jamais affichee", False, CLE in sortie)

        print("\n-- 4. sans cle : aucune requete")
        avant = len(RECU)
        code, sortie = lancer(argv, None)
        cas("code de sortie", 2, code)
        cas("aucune requete envoyee", avant, len(RECU))
        cas("le message nomme la variable", True, P.VARIABLE in sortie)
    serveur.shutdown()

    print()
    if ECHECS:
        print("ROUGE : %d cas en echec -> %s" % (len(ECHECS), ", ".join(ECHECS)))
        return 1
    print("VERT : publication Open Cloud conforme")
    return 0


if __name__ == "__main__":
    sys.exit(main())
