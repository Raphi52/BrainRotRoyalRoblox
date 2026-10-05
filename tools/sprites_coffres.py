# -*- coding: utf-8 -*-
"""SPRITES DES COFFRES et des icones de monnaie, generes ICI, sans aucune ressource externe.

Pourquoi (2026-10-05) : les coffres du hub etaient des cadres empiles (corps, couvercle, bande,
serrure) et l'utilisateur les a juges « immondes ». Habillage.lua avait choisi « aucun asset a
televerser » ; ce choix est revise pour les coffres : de vraies images, style jeu mobile (contour
epais, relief par degrade, reflets), dessinees par ce script — donc reproductibles et sans licence
tierce. Rendu en 4x puis reduit (anticrenelage).

Sortie : tools/sprites/<nom>.png (256x256, fond transparent, suivies par git) :
  coffre-bois, coffre-argent, coffre-or, coffre-vide (silhouette d'emplacement libre), piece, gemme.
Usage : python tools/sprites_coffres.py
"""
import pathlib
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SORTIE = ROOT / "tools" / "sprites"
TAILLE = 256
K = 4  # sur-echantillonnage
N = TAILLE * K
ENCRE = (22, 16, 30, 255)

# Teintes par type : (clair, moyen, sombre) du bois/metal, puis (clair, moyen, sombre) des ferrures.
TYPES = {
    "bois": {"corps": ((214, 150, 88), (160, 102, 54), (98, 58, 30)),
             "fer": ((236, 236, 246), (160, 166, 186), (88, 92, 114)), "planches": True},
    "argent": {"corps": ((232, 240, 252), (156, 170, 196), (84, 96, 126)),
               "fer": ((255, 238, 150), (236, 180, 52), (150, 96, 20)), "planches": False},
    "or": {"corps": ((255, 236, 128), (240, 176, 40), (156, 92, 14)),
           "fer": ((210, 236, 255), (110, 160, 235), (44, 70, 150)), "planches": False},
    "vide": {"corps": ((112, 120, 158), (82, 89, 124), (58, 63, 92)),
             "fer": ((132, 140, 176), (100, 108, 144), (70, 76, 108)), "planches": False},
}


def s(v):
    return int(round(v * K))


def masque(dessin):
    m = Image.new("L", (N, N), 0)
    dessin(ImageDraw.Draw(m))
    return m


def degrade_v(couleurs, haut, bas):
    """Degrade vertical clair -> moyen -> sombre entre les ordonnees haut et bas (pixels 4x)."""
    clair, moyen, sombre = couleurs
    im = Image.new("RGBA", (N, N))
    d = ImageDraw.Draw(im)
    for y in range(N):
        t = min(1, max(0, (y - haut) / max(1, bas - haut)))
        a, b, u = (clair, moyen, t / 0.45) if t < 0.45 else (moyen, sombre, (t - 0.45) / 0.55)
        d.line([(0, y), (N, y)], fill=tuple(int(a[i] + (b[i] - a[i]) * u) for i in range(3)) + (255,))
    return im


def peindre(base, remplissage, m):
    # Le masque devient l'ALPHA du calque. Image.composite melangeait la couleur avec du NOIR
    # transparent : tout bord adouci (reflet, ombre, anticrenelage) virait au gris sale.
    calque = remplissage.copy()
    calque.putalpha(ImageChops.multiply(remplissage.getchannel("A"), m))
    base.alpha_composite(calque)


def contour(base, m, epaisseur):
    """Trait d'encre AUTOUR du masque (dilatation), peint sous ce qui suivra."""
    gros = m.filter(ImageFilter.MaxFilter(epaisseur * 2 + 1)) if epaisseur else m
    peindre(base, Image.new("RGBA", (N, N), ENCRE), gros)


def eclat(base, boite, alpha=190):
    """Reflet brillant : pastille blanche NETTE (floutee, elle faisait une tache grise)."""
    m = masque(lambda d: d.rounded_rectangle([s(v) for v in boite], K * 99, fill=alpha)).filter(ImageFilter.GaussianBlur(K * 0.7))
    peindre(base, Image.new("RGBA", (N, N), (255, 255, 255, 255)), m)


def coffre(nom):
    t = TYPES[nom]
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    # ombre portee au sol
    ombre = masque(lambda d: d.ellipse([s(38), s(212), s(218), s(244)], fill=110)).filter(ImageFilter.GaussianBlur(s(4)))
    peindre(im, Image.new("RGBA", (N, N), (0, 0, 0, 255)), ombre)

    corps = masque(lambda d: d.rounded_rectangle([s(40), s(118), s(216), s(226)], s(14), fill=255))
    couv = masque(lambda d: (d.rounded_rectangle([s(32), s(70), s(224), s(132)], s(18), fill=255),
                             d.ellipse([s(32), s(34), s(224), s(118)], fill=255)))
    # le couvercle ne garde que le bas de l'ellipse au-dessus de 70 : on coupe tout au-dessus de 34
    silhouette = ImageChops.lighter(corps, couv)
    contour(im, silhouette, s(7))

    # CORPS
    peindre(im, degrade_v(t["corps"], s(118), s(226)), corps)
    if t["planches"]:
        for y in (152, 188):
            peindre(im, Image.new("RGBA", (N, N), t["corps"][2] + (255,)),
                    masque(lambda d, y=y: d.rectangle([s(40), s(y), s(216), s(y + 3)], fill=255)))
    # ombre du couvercle sur le haut du corps
    peindre(im, Image.new("RGBA", (N, N), (0, 0, 0, 255)),
            masque(lambda d: d.rectangle([s(40), s(130), s(216), s(142)], fill=70)).filter(ImageFilter.GaussianBlur(s(3))))
    # COUVERCLE (au-dessus du corps, deborde des deux cotes)
    contour(im, couv, s(4))
    peindre(im, degrade_v(t["corps"], s(36), s(132)), couv)
    if t["planches"]:
        for y in (78, 104):
            peindre(im, Image.new("RGBA", (N, N), t["corps"][2] + (255,)),
                    ImageChops.multiply(couv, masque(lambda d, y=y: d.rectangle([s(32), s(y), s(224), s(y + 3)], fill=255))))
    eclat(im, (68, 50, 104, 60))
    eclat(im, (110, 48, 118, 56))
    # REBORD du couvercle : bande sombre + trait d'encre, c'est elle qui separe couvercle et corps
    rebord = ImageChops.multiply(couv, masque(lambda d: d.rectangle([s(32), s(120), s(224), s(132)], fill=255)))
    peindre(im, Image.new("RGBA", (N, N), t["corps"][2] + (255,)), rebord)
    peindre(im, Image.new("RGBA", (N, N), ENCRE), masque(lambda d: d.rectangle([s(36), s(131), s(220), s(135)], fill=255)))

    # FERRURES : coins du corps, bande centrale, serrure
    fer = degrade_v(t["fer"], s(40), s(226))
    for x0, x1 in ((24, 62), (194, 232)):
        m = ImageChops.multiply(silhouette, masque(lambda d, x0=x0, x1=x1: d.rectangle([s(x0), s(30), s(x1), s(230)], fill=255)))
        contour(im, m, s(3))
        peindre(im, fer, m)
    bande = ImageChops.multiply(silhouette, masque(lambda d: d.rectangle([s(112), s(30), s(144), s(230)], fill=255)))
    contour(im, bande, s(3))
    peindre(im, fer, bande)
    eclat(im, (117, 140, 121, 206), 150)
    # rivets
    for x, y in ((50, 200), (206, 200), (50, 92), (206, 92)):
        r = masque(lambda d, x=x, y=y: d.ellipse([s(x - 4), s(y - 4), s(x + 4), s(y + 4)], fill=255))
        contour(im, r, s(2))
        peindre(im, Image.new("RGBA", (N, N), t["fer"][0] + (255,)), r)
    # serrure : plaque arrondie + trou de cle
    plaque = masque(lambda d: d.rounded_rectangle([s(104), s(112), s(152), s(166)], s(10), fill=255))
    contour(im, plaque, s(4))
    peindre(im, degrade_v(t["fer"], s(112), s(166)), plaque)
    trou = masque(lambda d: (d.ellipse([s(122), s(124), s(134), s(136)], fill=255),
                             d.polygon([(s(124), s(132)), (s(132), s(132)), (s(135), s(154)), (s(121), s(154))], fill=255)))
    peindre(im, Image.new("RGBA", (N, N), ENCRE), trou)
    eclat(im, (110, 116, 128, 121), 200)
    if nom == "vide":
        im.putalpha(im.getchannel("A").point(lambda a: int(a * 0.55)))
    return im.resize((TAILLE, TAILLE), Image.LANCZOS)


def piece():
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    disque = masque(lambda d: d.ellipse([s(28), s(28), s(228), s(228)], fill=255))
    contour(im, disque, s(8))
    peindre(im, degrade_v(((255, 240, 140), (246, 186, 40), (170, 104, 12)), s(28), s(228)), disque)
    interieur = masque(lambda d: d.ellipse([s(58), s(58), s(198), s(198)], fill=255))
    peindre(im, degrade_v(((196, 124, 14), (236, 170, 32), (255, 226, 110)), s(58), s(198)), interieur)
    etoile = masque(lambda d: d.polygon([(s(128), s(78)), (s(142), s(114)), (s(180), s(116)), (s(150), s(140)),
                                          (s(160), s(178)), (s(128), s(156)), (s(96), s(178)), (s(106), s(140)),
                                          (s(76), s(116)), (s(114), s(114))], fill=255))
    contour(im, etoile, s(3))
    peindre(im, degrade_v(((255, 250, 200), (255, 216, 80), (220, 150, 20)), s(78), s(178)), etoile)
    eclat(im, (66, 70, 84, 112), 200)
    eclat(im, (88, 52, 116, 62), 200)
    return im.resize((TAILLE, TAILLE), Image.LANCZOS)


def gemme():
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    haut, ceinture, bas = 46, 100, 222
    forme = masque(lambda d: d.polygon([(s(80), s(haut)), (s(176), s(haut)), (s(222), s(ceinture)),
                                        (s(128), s(bas)), (s(34), s(ceinture))], fill=255))
    contour(im, forme, s(8))
    facettes = [
        ([(80, haut), (176, haut), (156, ceinture), (100, ceinture)], (150, 255, 170)),
        ([(80, haut), (100, ceinture), (34, ceinture)], (90, 230, 130)),
        ([(176, haut), (222, ceinture), (156, ceinture)], (40, 170, 90)),
        ([(34, ceinture), (100, ceinture), (128, bas)], (40, 190, 100)),
        ([(100, ceinture), (156, ceinture), (128, bas)], (70, 220, 120)),
        ([(156, ceinture), (222, ceinture), (128, bas)], (20, 130, 70)),
    ]
    for pts, c in facettes:
        peindre(im, Image.new("RGBA", (N, N), c + (255,)), masque(lambda d, pts=pts: d.polygon([(s(x), s(y)) for x, y in pts], fill=255)))
    d = ImageDraw.Draw(im)
    for a, b in (((100, ceinture), (128, bas)), ((156, ceinture), (128, bas)), ((34, ceinture), (222, ceinture)),
                 ((80, haut), (100, ceinture)), ((176, haut), (156, ceinture))):
        d.line([(s(a[0]), s(a[1])), (s(b[0]), s(b[1]))], fill=(18, 90, 50, 200), width=s(2))
    eclat(im, (92, 54, 124, 62), 210)
    return im.resize((TAILLE, TAILLE), Image.LANCZOS)


def tout():
    return {**{"coffre-" + n: coffre(n) for n in TYPES}, "piece": piece(), "gemme": gemme()}


if __name__ == "__main__":
    SORTIE.mkdir(parents=True, exist_ok=True)
    for nom, image in tout().items():
        image.save(SORTIE / (nom + ".png"), optimize=True)
        print("ecrit", SORTIE / (nom + ".png"))
