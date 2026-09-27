# -*- coding: utf-8 -*-
"""Images de la FICHE de l'experience : icone 512x512 et miniature 1920x1080 (formats demandes par
Roblox, voir README « Mettre le jeu en ligne »), composees a partir de captures DU MOTEUR.

Captures d'entree (tools/studio-capture-moteur.ps1, bureau cache, dossier captures/ ignore par git) :
  captures/fiche-partie.png     (build.py --autotest --partie)
  captures/boutique-offres.png  (build.py --autotest --boutique --vip-non-possede)
  captures/pass-premium.png     (build.py --autotest --hub --pass-points=3)
Sortie : tools/fiche/icone-512.png et tools/fiche/miniature-1920x1080.png (suivies par git : ce sont
les images publiees de la fiche).
Usage : python tools/fiche_images.py
"""
import pathlib
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
CAP = ROOT / "captures"
SORTIE = ROOT / "tools" / "fiche"
POLICE = r"C:\Windows\Fonts\seguibl.ttf"
OR = (255, 205, 60)
NUIT = (14, 16, 34)


def fond(taille):
    """Degrade nuit -> violet, comme le bandeau du jeu."""
    w, h = taille
    im = Image.new("RGB", taille, NUIT)
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=(int(14 + 40 * t), int(16 + 10 * t), int(34 + 70 * t)))
    return im


def titre(d, texte, centre_x, y, taille, contour=8):
    f = ImageFont.truetype(POLICE, taille)
    l = d.textlength(texte, font=f)
    d.text((centre_x - l / 2, y), texte, font=f, fill=OR, stroke_width=contour, stroke_fill=(10, 12, 20))


def panneau(capture, hauteur, rayon=28):
    im = Image.open(capture).convert("RGB")
    k = hauteur / im.height
    im = im.resize((int(im.width * k), hauteur), Image.LANCZOS)
    masque = Image.new("L", im.size, 0)
    ImageDraw.Draw(masque).rounded_rectangle([0, 0, im.width - 1, im.height - 1], rayon, fill=255)
    return im, masque


def miniature():
    im = fond((1920, 1080))
    d = ImageDraw.Draw(im)
    titre(d, "BRAINROT ROYALE", 960, 18, 118)
    sous = ImageFont.truetype(POLICE, 44)
    s = "Duels de cartes Italian Brainrot  -  deck de 8, tours, arenes"
    d.text((960 - d.textlength(s, font=sous) / 2, 158), s, font=sous, fill=(235, 235, 245),
           stroke_width=4, stroke_fill=(10, 12, 20))
    captures = [CAP / "boutique-offres.png", CAP / "fiche-partie.png", CAP / "pass-premium.png"]
    hauteurs = [800, 850, 800]
    panneaux = [panneau(c, h) for c, h in zip(captures, hauteurs)]
    largeur = sum(p[0].width for p in panneaux) + 2 * 60
    x = (1920 - largeur) // 2
    for (p, m), h in zip(panneaux, hauteurs):
        y = 1080 - h - 20
        ombre = Image.new("RGBA", (p.width + 40, p.height + 40), (0, 0, 0, 0))
        ImageDraw.Draw(ombre).rounded_rectangle([20, 20, p.width + 19, p.height + 19], 28, fill=(0, 0, 0, 170))
        ombre = ombre.filter(ImageFilter.GaussianBlur(12))
        im.paste(ombre, (x - 20, y - 12), ombre)
        cadre = Image.new("RGB", (p.width + 12, p.height + 12), OR)
        cm = Image.new("L", cadre.size, 0)
        ImageDraw.Draw(cm).rounded_rectangle([0, 0, cadre.width - 1, cadre.height - 1], 32, fill=255)
        im.paste(cadre, (x - 6, y - 6), cm)
        im.paste(p, (x, y), m)
        x += p.width + 60
    return im


def carte(couleur, lettre, angle):
    c = Image.new("RGBA", (170, 230), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.rounded_rectangle([4, 4, 165, 225], 22, fill=(10, 12, 20, 255))
    d.rounded_rectangle([12, 12, 157, 217], 16, fill=couleur + (255,))
    f = ImageFont.truetype(POLICE, 110)
    l = d.textlength(lettre, font=f)
    d.text((85 - l / 2, 48), lettre, font=f, fill=(255, 255, 255), stroke_width=6, stroke_fill=(10, 12, 20))
    return c.rotate(angle, resample=Image.BICUBIC, expand=True)


def icone():
    """Graphisme NET plutot qu'une capture : a 512 px, un personnage recadre dans une capture
    portrait de 592 px sortait flou et avec le texte de sa carte (essai du 2026-09-27)."""
    im = fond((512, 512)).convert("RGBA")
    d = ImageDraw.Draw(im)
    gauche = carte((70, 150, 255), "B", 14)
    droite = carte((235, 70, 90), "R", -14)
    im.alpha_composite(gauche, (70, 95))
    im.alpha_composite(droite, (212, 95))
    # couronne doree posee sur les deux cartes
    pts = [(146, 150), (166, 70), (206, 120), (256, 50), (306, 120), (346, 70), (366, 150)]
    d.polygon(pts, fill=OR, outline=(10, 12, 20))
    d.line(pts + [pts[0]], fill=(10, 12, 20), width=8, joint="curve")
    d.rounded_rectangle([140, 146, 372, 178], 8, fill=OR, outline=(10, 12, 20), width=6)
    for x in (166, 256, 346):
        d.ellipse([x - 12, 58 if x != 256 else 38, x + 12, 82 if x != 256 else 62], fill=(255, 245, 200), outline=(10, 12, 20), width=4)
    titre(d, "BRAINROT", 256, 318, 88, contour=8)
    titre(d, "ROYALE", 256, 404, 88, contour=8)
    return im.convert("RGB")


def main():
    manquantes = [c for c in ("fiche-partie.png", "boutique-offres.png", "pass-premium.png") if not (CAP / c).exists()]
    if manquantes:
        print("REFUS : captures absentes :", manquantes)
        return 2
    SORTIE.mkdir(parents=True, exist_ok=True)
    m = miniature()
    i = icone()
    m.save(SORTIE / "miniature-1920x1080.png")
    i.save(SORTIE / "icone-512.png")
    print("OK :", m.size, i.size, "->", SORTIE)
    return 0


if __name__ == "__main__":
    sys.exit(main())
